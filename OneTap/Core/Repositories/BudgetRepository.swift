import Foundation
@preconcurrency internal import CoreData
import Combine

protocol BudgetRepositoryProtocol {
    func create(_ dto: BudgetCreateData) throws -> Budget
    func fetch(id: UUID) throws -> Budget
    func fetchAll() throws -> [Budget]
    func fetchActive(for category: Category, on date: Date) throws -> Budget?
    func update(_ budget: Budget, with dto: BudgetUpdateData) throws
    func delete(_ budget: Budget) throws
    func recalculateSpent(for budget: Budget) throws

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

    // MARK: - Create

    func create(_ dto: BudgetCreateData) throws -> Budget {
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

    // MARK: - Fetch

    func fetch(id: UUID) throws -> Budget {
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

    func fetchActive(for category: Category, on date: Date) throws -> Budget? {
        let predicate = NSPredicate(
            format: "category == %@ AND startDate <= %@ AND endDate >= %@",
            category, date as NSDate, date as NSDate
        )
        return try fetch(predicate: predicate).first
    }

    // MARK: - Update

    func update(_ budget: Budget, with dto: BudgetUpdateData) throws {
        if let amount = dto.amount {
            budget.amount = amount
        }
        if let spent = dto.spent {
            budget.spent = spent
        }
        if let startDate = dto.startDate {
            budget.startDate = startDate
        }
        if let endDate = dto.endDate {
            budget.endDate = endDate
        }

        budget.updatedAt = Date()

        try context.save()
    }

    // MARK: - Delete

    func delete(_ budget: Budget) throws {
        context.delete(budget)
        try context.save()
    }

    // MARK: - Business Logic

    func recalculateSpent(for budget: Budget) throws {
        guard let category = budget.category,
              let startDate = budget.startDate,
              let endDate = budget.endDate else {
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

        budget.spent = totalSpent
        budget.updatedAt = Date()

        try context.save()
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
