import Foundation
@preconcurrency internal import CoreData

// MARK: - Budget Status

enum BudgetStatus {
    case ok
    case nearLimit
    case exceeded
    case noBudget
}

// MARK: - Protocol

@MainActor
protocol BudgetServiceProtocol {
    /// Get all category spending summaries for a month
    func getCategorySpendingSummaries(for month: Date) async throws -> [CategorySpendingSummary]

    /// Get subcategory summaries for a specific category
    func getSubCategorySpendingSummaries(for category: Category, in month: Date) async throws -> [SubCategorySpendingSummary]

    /// Create or update a budget
    func saveBudget(amount: Double, for category: Category, subCategory: SubCategory?) async throws -> Budget

    /// Delete a budget
    func deleteBudget(_ budget: Budget) async throws

    /// Get the minimum amount for a category budget (sum of subcategory budgets)
    func getMinimumAmount(for category: Category) async throws -> Double

    /// Get edit context for numpad sheet
    func getEditContext(for category: Category, subCategory: SubCategory?, in month: Date) async throws -> BudgetEditContext

    /// Calculate totals for the month
    func getMonthlyTotals(for month: Date) async throws -> (totalBudgeted: Double, totalSpent: Double)
}

// MARK: - Implementation

@MainActor
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

    func getCategorySpendingSummaries(for month: Date) async throws -> [CategorySpendingSummary] {
        return try budgetRepository.getCategorySpendingSummaries(for: month)
    }

    func getSubCategorySpendingSummaries(for category: Category, in month: Date) async throws -> [SubCategorySpendingSummary] {
        return try budgetRepository.getSubCategorySpendingSummaries(for: category, in: month)
    }

    func saveBudget(amount: Double, for category: Category, subCategory: SubCategory?) async throws -> Budget {
        // Check if budget exists
        if let subCategory = subCategory {
            if let existingBudget = try budgetRepository.fetchBudget(for: subCategory) {
                // Update existing
                try budgetRepository.update(existingBudget, with: BudgetUpdateData(amount: amount, isActive: true))
                return existingBudget
            }
        } else {
            if let existingBudget = try budgetRepository.fetchBudget(for: category) {
                // Validate minimum amount
                let minimumAmount = try budgetRepository.calculateMinimumAmount(for: category)
                if amount < minimumAmount {
                    throw RepositoryError.validationFailed("Budget must be at least \(formatCurrency(minimumAmount)) (sum of subcategory budgets)")
                }
                // Update existing
                try budgetRepository.update(existingBudget, with: BudgetUpdateData(amount: amount, isActive: true))
                return existingBudget
            }
        }

        // Create new budget
        guard let categoryID = category.id else {
            throw RepositoryError.invalidData("Category ID not found")
        }

        let dto = BudgetCreateData(
            amount: amount,
            categoryID: categoryID,
            subCategoryID: subCategory?.id
        )

        return try budgetRepository.create(dto)
    }

    func deleteBudget(_ budget: Budget) async throws {
        try budgetRepository.delete(budget)
    }

    func getMinimumAmount(for category: Category) async throws -> Double {
        return try budgetRepository.calculateMinimumAmount(for: category)
    }

    func getEditContext(for category: Category, subCategory: SubCategory?, in month: Date) async throws -> BudgetEditContext {
        let spent = try budgetRepository.calculateSpent(for: category, subCategory: subCategory, in: month)

        var currentBudget: Budget?
        var minimumAmount: Double = 0

        if let subCategory = subCategory {
            currentBudget = try budgetRepository.fetchBudget(for: subCategory)
        } else {
            currentBudget = try budgetRepository.fetchBudget(for: category)
            minimumAmount = try budgetRepository.calculateMinimumAmount(for: category)
        }

        return BudgetEditContext(
            category: category,
            subCategory: subCategory,
            currentBudget: currentBudget,
            currentSpent: spent,
            minimumAmount: minimumAmount
        )
    }

    func getMonthlyTotals(for month: Date) async throws -> (totalBudgeted: Double, totalSpent: Double) {
        let summaries = try budgetRepository.getCategorySpendingSummaries(for: month)

        let totalBudgeted = summaries.compactMap { $0.budget?.amount }.reduce(0, +)
        let totalSpent = summaries.map { $0.spent }.reduce(0, +)

        return (totalBudgeted, totalSpent)
    }

    // MARK: - Helpers

    private func formatCurrency(_ amount: Double) -> String {
        let currencyCode = SettingsManager.shared.currencyCode
        let formatter = Formatters.currencyFormatter(for: currencyCode)
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}
