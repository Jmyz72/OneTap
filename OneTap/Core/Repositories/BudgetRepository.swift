import Foundation
@preconcurrency internal import CoreData
import Combine

protocol BudgetRepositoryProtocol {
    // CRUD
    func create(_ dto: BudgetCreateData) throws -> Budget
    func fetch(id: UUID) throws -> Budget
    func fetchAll() throws -> [Budget]
    func fetchActive() throws -> [Budget]
    func update(_ budget: Budget, with dto: BudgetUpdateData) throws
    func delete(_ budget: Budget) throws
    func save() throws

    // Queries
    func fetchBudget(for category: Category) throws -> Budget?
    func fetchBudget(for subCategory: SubCategory) throws -> Budget?
    func fetchSubCategoryBudgets(for category: Category) throws -> [Budget]

    // Calculations
    func calculateSpent(for category: Category, subCategory: SubCategory?, in month: Date) throws -> Double
    func calculateMinimumAmount(for category: Category) throws -> Double

    // Summaries
    func getCategorySpendingSummaries(for month: Date) throws -> [CategorySpendingSummary]
    func getSubCategorySpendingSummaries(for category: Category, in month: Date) throws -> [SubCategorySpendingSummary]

    // Publisher
    var budgetsPublisher: AnyPublisher<[Budget], Never> { get }
}

class BudgetRepository: BaseRepository, BudgetRepositoryProtocol {
    typealias Entity = Budget

    let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    deinit {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    // MARK: - Helper Methods

    private func fetch(predicate: NSPredicate? = nil, sortDescriptors: [NSSortDescriptor] = []) throws -> [Budget] {
        let request = NSFetchRequest<Budget>(entityName: "Budget")
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors

        do {
            return try context.fetch(request)
        } catch {
            throw RepositoryError.fetchFailed(error.localizedDescription)
        }
    }

    /// Get start and end of a given month
    private func monthBoundaries(for date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        let startOfMonth = calendar.date(from: components)!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: startOfMonth)!
        return (startOfMonth, endOfMonth)
    }

    // MARK: - Create

    func create(_ dto: BudgetCreateData) throws -> Budget {
        // Check if budget already exists for this category/subcategory
        let categoryRequest = Category.fetchRequest()
        categoryRequest.predicate = NSPredicate(format: "id == %@", dto.categoryID as CVarArg)
        guard let category = try context.fetch(categoryRequest).first else {
            throw RepositoryError.entityNotFound
        }

        var subCategory: SubCategory?
        if let subCategoryID = dto.subCategoryID {
            let subRequest = SubCategory.fetchRequest()
            subRequest.predicate = NSPredicate(format: "id == %@", subCategoryID as CVarArg)
            subCategory = try context.fetch(subRequest).first
            if subCategory == nil {
                throw RepositoryError.entityNotFound
            }

            // Check if budget already exists for this subcategory
            if try fetchBudget(for: subCategory!) != nil {
                throw RepositoryError.duplicateEntity
            }
        } else {
            // Check if budget already exists for this category (without subcategory)
            if try fetchBudget(for: category) != nil {
                throw RepositoryError.duplicateEntity
            }
        }

        let budget = Budget(context: context)
        budget.id = UUID()
        budget.amount = dto.amount
        budget.isActive = true
        budget.createdAt = Date()
        budget.updatedAt = Date()
        budget.category = category
        budget.subCategory = subCategory

        try context.save()
        return budget
    }

    // MARK: - Fetch

    func fetch(id: UUID) throws -> Budget {
        let predicate = NSPredicate(format: "id == %@", id as CVarArg)
        guard let budget = try fetch(predicate: predicate).first else {
            throw RepositoryError.entityNotFound
        }
        return budget
    }

    func fetchAll() throws -> [Budget] {
        let sortDescriptors = [NSSortDescriptor(keyPath: \Budget.createdAt, ascending: false)]
        return try fetch(sortDescriptors: sortDescriptors)
    }

    func fetchActive() throws -> [Budget] {
        let predicate = NSPredicate(format: "isActive == YES")
        let sortDescriptors = [NSSortDescriptor(keyPath: \Budget.createdAt, ascending: false)]
        return try fetch(predicate: predicate, sortDescriptors: sortDescriptors)
    }

    func fetchBudget(for category: Category) throws -> Budget? {
        // Fetch category-level budget (subCategory is nil)
        let predicate = NSPredicate(format: "category == %@ AND subCategory == nil AND isActive == YES", category)
        return try fetch(predicate: predicate).first
    }

    func fetchBudget(for subCategory: SubCategory) throws -> Budget? {
        let predicate = NSPredicate(format: "subCategory == %@ AND isActive == YES", subCategory)
        return try fetch(predicate: predicate).first
    }

    func fetchSubCategoryBudgets(for category: Category) throws -> [Budget] {
        let predicate = NSPredicate(format: "category == %@ AND subCategory != nil AND isActive == YES", category)
        return try fetch(predicate: predicate)
    }

    // MARK: - Update

    func update(_ budget: Budget, with dto: BudgetUpdateData) throws {
        if let amount = dto.amount {
            // Validate minimum amount for category budgets
            if budget.subCategory == nil, let category = budget.category {
                let minimumAmount = try calculateMinimumAmount(for: category)
                if amount < minimumAmount {
                    throw RepositoryError.validationFailed("Budget amount cannot be less than sum of subcategory budgets (\(minimumAmount))")
                }
            }
            budget.amount = amount
        }
        if let isActive = dto.isActive {
            budget.isActive = isActive
        }

        budget.updatedAt = Date()
        try context.save()
    }

    // MARK: - Delete

    func delete(_ budget: Budget) throws {
        context.delete(budget)
        try context.save()
    }

    func save() throws {
        if context.hasChanges {
            try context.save()
        }
    }

    // MARK: - Calculations

    func calculateSpent(for category: Category, subCategory: SubCategory?, in month: Date) throws -> Double {
        let (startOfMonth, endOfMonth) = monthBoundaries(for: month)

        let transactionRequest = Transaction.fetchRequest()

        if let subCategory = subCategory {
            // SubCategory budget: only transactions with this specific subcategory
            transactionRequest.predicate = NSPredicate(
                format: "subCategory == %@ AND date >= %@ AND date <= %@ AND type == %@ AND excludeFromReports == NO",
                subCategory,
                startOfMonth as NSDate,
                endOfMonth as NSDate,
                TransactionType.expense.rawValue
            )
        } else {
            // Category budget: all transactions in this category (including all subcategories)
            transactionRequest.predicate = NSPredicate(
                format: "category == %@ AND date >= %@ AND date <= %@ AND type == %@ AND excludeFromReports == NO",
                category,
                startOfMonth as NSDate,
                endOfMonth as NSDate,
                TransactionType.expense.rawValue
            )
        }

        let transactions = try context.fetch(transactionRequest)
        return transactions.reduce(0.0) { $0 + $1.amount }
    }

    func calculateMinimumAmount(for category: Category) throws -> Double {
        let subBudgets = try fetchSubCategoryBudgets(for: category)
        return subBudgets.reduce(0.0) { $0 + $1.amount }
    }

    // MARK: - Summaries

    func getCategorySpendingSummaries(for month: Date) throws -> [CategorySpendingSummary] {
        // Get all expense categories
        let categoryRequest = Category.fetchRequest()
        categoryRequest.predicate = NSPredicate(format: "type == %@", TransactionType.expense.rawValue)
        categoryRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Category.order, ascending: true)]

        let categories = try context.fetch(categoryRequest)
        var summaries: [CategorySpendingSummary] = []

        for category in categories {
            let spent = try calculateSpent(for: category, subCategory: nil, in: month)
            let budget = try fetchBudget(for: category)
            let subSummaries = try getSubCategorySpendingSummaries(for: category, in: month)

            let summary = CategorySpendingSummary(
                id: category.id ?? UUID(),
                category: category,
                spent: spent,
                budget: budget,
                subCategorySummaries: subSummaries,
                month: month
            )
            summaries.append(summary)
        }

        return summaries
    }

    func getSubCategorySpendingSummaries(for category: Category, in month: Date) throws -> [SubCategorySpendingSummary] {
        guard let subCategories = category.subCategories?.allObjects as? [SubCategory] else {
            return []
        }

        var summaries: [SubCategorySpendingSummary] = []

        for subCategory in subCategories.sorted(by: { $0.order < $1.order }) {
            let spent = try calculateSpent(for: category, subCategory: subCategory, in: month)
            let budget = try fetchBudget(for: subCategory)

            let summary = SubCategorySpendingSummary(
                id: subCategory.id ?? UUID(),
                subCategory: subCategory,
                spent: spent,
                budget: budget,
                month: month
            )
            summaries.append(summary)
        }

        return summaries
    }

    // MARK: - Publisher

    var budgetsPublisher: AnyPublisher<[Budget], Never> {
        let initial = (try? fetchActive()) ?? []
        let subject = CurrentValueSubject<[Budget], Never>(initial)

        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] notification in
                guard let self = self else { return }

                guard let savedContext = notification.object as? NSManagedObjectContext,
                      savedContext.persistentStoreCoordinator === self.context.persistentStoreCoordinator else {
                    return
                }

                let inserted = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
                let updated = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? []
                let deleted = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? []

                let hasChanges = (inserted.union(updated).union(deleted))
                    .contains { $0 is Budget }

                guard hasChanges else { return }

                let budgets = (try? self.fetchActive()) ?? []
                subject.send(budgets)
            }
            .store(in: &cancellables)

        return subject.eraseToAnyPublisher()
    }
}
