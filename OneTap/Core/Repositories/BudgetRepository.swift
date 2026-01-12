import Foundation
internal import CoreData
import Combine

protocol BudgetRepositoryProtocol {
    func create(_ dto: BudgetCreateData) async throws -> Budget
    func fetch(id: UUID) async throws -> Budget
    func fetchAll() throws -> [Budget]
    func fetchActive(for category: Category, on date: Date) async throws -> Budget?
    func update(_ budget: Budget, with dto: BudgetUpdateData) async throws
    func delete(_ budget: Budget) async throws
    func recalculateSpent(for budget: Budget) async throws

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

    private func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        let taskContext = PersistenceController.shared.container.newBackgroundContext()
        taskContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        return try await taskContext.perform {
            try block(taskContext)
        }
    }

    // MARK: - Create

    func create(_ dto: BudgetCreateData) async throws -> Budget {
        return try await performBackgroundTask { context in
            let budget = Budget(context: context)
            budget.id = UUID()
            budget.amount = dto.amount
            budget.spent = 0
            budget.startDate = dto.startDate
            budget.endDate = dto.endDate
            budget.createdAt = Date()
            budget.updatedAt = Date()

            // Fetch and set category
            let categoryRequest = Category.fetchRequest()
            categoryRequest.predicate = NSPredicate(format: "id == %@", dto.categoryID as CVarArg)
            guard let category = try context.fetch(categoryRequest).first else {
                throw RepositoryError.entityNotFound
            }
            budget.category = category

            try context.save()
            return budget
        }
    }

    // MARK: - Fetch

    func fetch(id: UUID) async throws -> Budget {
        let predicate = NSPredicate(format: "id == %@", id as CVarArg)
        guard let budget = try fetch(predicate: predicate).first else {
            throw RepositoryError.entityNotFound
        }
        return budget
    }

    func fetchAll() throws -> [Budget] {
        let sortDescriptors = [NSSortDescriptor(keyPath: \Budget.startDate, ascending: false)]
        return try fetch(sortDescriptors: sortDescriptors)
    }

    func fetchActive(for category: Category, on date: Date) async throws -> Budget? {
        let predicate = NSPredicate(
            format: "category == %@ AND startDate <= %@ AND endDate >= %@",
            category, date as NSDate, date as NSDate
        )
        return try fetch(predicate: predicate).first
    }

    // MARK: - Update

    func update(_ budget: Budget, with dto: BudgetUpdateData) async throws {
        return try await performBackgroundTask { context in
            guard let budgetInContext = context.object(with: budget.objectID) as? Budget else {
                throw RepositoryError.entityNotFound
            }

            if let amount = dto.amount {
                budgetInContext.amount = amount
            }
            if let spent = dto.spent {
                budgetInContext.spent = spent
            }
            if let startDate = dto.startDate {
                budgetInContext.startDate = startDate
            }
            if let endDate = dto.endDate {
                budgetInContext.endDate = endDate
            }

            budgetInContext.updatedAt = Date()

            try context.save()
        }
    }

    // MARK: - Delete

    func delete(_ budget: Budget) async throws {
        return try await performBackgroundTask { context in
            guard let budgetInContext = context.object(with: budget.objectID) as? Budget else {
                throw RepositoryError.entityNotFound
            }
            context.delete(budgetInContext)
            try context.save()
        }
    }

    // MARK: - Business Logic

    func recalculateSpent(for budget: Budget) async throws {
        return try await performBackgroundTask { context in
            guard let budgetInContext = context.object(with: budget.objectID) as? Budget,
                  let category = budgetInContext.category,
                  let startDate = budgetInContext.startDate,
                  let endDate = budgetInContext.endDate else {
                throw RepositoryError.entityNotFound
            }

            // Fetch all transactions for this category in the budget period
            let transactionRequest = Transaction.fetchRequest()
            transactionRequest.predicate = NSPredicate(
                format: "category == %@ AND date >= %@ AND date <= %@",
                category,
                startDate as NSDate,
                endDate as NSDate
            )

            let transactions = try context.fetch(transactionRequest)

            // Calculate total spent (Expenses only)
            let totalSpent = transactions
                .filter { $0.type == TransactionType.expense.rawValue }
                .reduce(0.0) { $0 + $1.amount }

            budgetInContext.spent = totalSpent
            budgetInContext.updatedAt = Date()

            try context.save()
        }
    }

    // MARK: - Publisher

    var budgetsPublisher: AnyPublisher<[Budget], Never> {
        NotificationCenter.default
            .publisher(for: .NSManagedObjectContextObjectsDidChange)
            .compactMap { [weak self] _ in
                try? self?.fetchAll()
            }
            .prepend(try! fetchAll())
            .eraseToAnyPublisher()
    }
}
