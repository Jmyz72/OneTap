import Foundation
@preconcurrency internal import CoreData

protocol BudgetServiceProtocol {
    func checkBudgetStatus(for transactionID: NSManagedObjectID) async throws -> BudgetStatus
    func updateBudgetsAfterTransaction(_ transactionID: NSManagedObjectID) async throws
}

enum BudgetStatus {
    case ok
    case nearLimit(Budget)
    case exceeded(Budget)
    case noBudget
}

class BudgetService: BudgetServiceProtocol {
    private let budgetRepository: BudgetRepositoryProtocol
    private let context: NSManagedObjectContext

    init(
        budgetRepository: BudgetRepositoryProtocol,
        context: NSManagedObjectContext
    ) {
        self.budgetRepository = budgetRepository
        self.context = context
    }

    func checkBudgetStatus(for transactionID: NSManagedObjectID) async throws -> BudgetStatus {
        guard let transaction = try? context.existingObject(with: transactionID) as? Transaction else {
            return .noBudget
        }

        guard let category = transaction.category,
              let date = transaction.date else {
            return .noBudget
        }

        // Find active budget for this category and date
        guard let budget = try budgetRepository.fetchActive(for: category, on: date) else {
            return .noBudget
        }

        // Recalculate to get latest spending
        try budgetRepository.recalculateSpent(for: budget)

        if budget.isExceeded {
            return .exceeded(budget)
        } else if budget.isNearLimit {
            return .nearLimit(budget)
        } else {
            return .ok
        }
    }

    func updateBudgetsAfterTransaction(_ transactionID: NSManagedObjectID) async throws {
        guard let transaction = try? context.existingObject(with: transactionID) as? Transaction else {
            return
        }

        guard let category = transaction.category,
              let date = transaction.date else { return }

        if let budget = try budgetRepository.fetchActive(for: category, on: date) {
            try budgetRepository.recalculateSpent(for: budget)
        }
    }
}
