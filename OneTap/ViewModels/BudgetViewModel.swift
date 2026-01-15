//
//  BudgetViewModel.swift
//  OneTap
//
//  Unified ViewModel for budget management
//

import Foundation
import SwiftUI
import Combine
@preconcurrency internal import CoreData

@MainActor
class BudgetViewModel: ObservableObject, ViewModelProtocol {
    // MARK: - Published State

    @Published var categorySummaries: [CategorySpendingSummary] = []
    @Published var selectedCategory: Category?
    @Published var subCategorySummaries: [SubCategorySpendingSummary] = []
    @Published var editContext: BudgetEditContext?

    @Published var currentMonth: Date = Date()
    @Published var totalBudgeted: Double = 0
    @Published var totalSpent: Double = 0

    @Published var loadingState: LoadingState = .idle
    @Published var errorMessage: String?

    // Numpad state
    @Published var amountString: String = "0"

    // MARK: - Dependencies

    private let budgetService: BudgetServiceProtocol
    private let budgetRepository: BudgetRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var overallProgress: Double {
        guard totalBudgeted > 0 else { return 0 }
        return totalSpent / totalBudgeted
    }

    var formattedTotalBudgeted: String {
        formatCurrency(totalBudgeted)
    }

    var formattedTotalSpent: String {
        formatCurrency(totalSpent)
    }

    var monthDisplayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }

    var canSaveBudget: Bool {
        guard let amount = Double(amountString), amount > 0 else { return false }
        guard let context = editContext else { return false }

        // Check minimum constraint for category budgets
        if context.hasMinimumConstraint && amount < context.minimumAmount {
            return false
        }

        return true
    }

    var minimumAmountMessage: String? {
        guard let context = editContext, context.hasMinimumConstraint else { return nil }
        return "Minimum: \(formatCurrency(context.minimumAmount)) (sum of subcategory budgets)"
    }

    // MARK: - Initialization

    init(
        budgetService: BudgetServiceProtocol,
        budgetRepository: BudgetRepositoryProtocol
    ) {
        self.budgetService = budgetService
        self.budgetRepository = budgetRepository

        observeBudgetChanges()
    }

    deinit {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    // MARK: - Observation

    private func observeBudgetChanges() {
        budgetRepository.budgetsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.loadData()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Loading

    func loadData() async {
        startLoading()

        do {
            categorySummaries = try await budgetService.getCategorySpendingSummaries(for: currentMonth)
            let totals = try await budgetService.getMonthlyTotals(for: currentMonth)
            totalBudgeted = totals.totalBudgeted
            totalSpent = totals.totalSpent

            // If a category is selected, reload its subcategories
            if let category = selectedCategory {
                subCategorySummaries = try await budgetService.getSubCategorySpendingSummaries(for: category, in: currentMonth)
            }

            finishLoading()
        } catch {
            handleError(error)
        }
    }

    // MARK: - Month Navigation

    func previousMonth() {
        let calendar = Calendar.current
        if let newMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = newMonth
            Task {
                await loadData()
            }
        }
    }

    func nextMonth() {
        let calendar = Calendar.current
        if let newMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = newMonth
            Task {
                await loadData()
            }
        }
    }

    // MARK: - Category Selection

    func selectCategory(_ category: Category) async {
        selectedCategory = category

        do {
            subCategorySummaries = try await budgetService.getSubCategorySpendingSummaries(for: category, in: currentMonth)
        } catch {
            handleError(error)
        }
    }

    func deselectCategory() {
        selectedCategory = nil
        subCategorySummaries = []
    }

    // MARK: - Budget Editing

    func startEditing(category: Category, subCategory: SubCategory? = nil) async {
        do {
            editContext = try await budgetService.getEditContext(for: category, subCategory: subCategory, in: currentMonth)

            // Pre-fill amount if budget exists
            if let amount = editContext?.currentBudget?.amount, amount > 0 {
                amountString = String(format: "%.0f", amount)
            } else {
                amountString = "0"
            }
        } catch {
            handleError(error)
        }
    }

    func cancelEditing() {
        editContext = nil
        amountString = "0"
    }

    func saveBudget() async {
        guard let context = editContext,
              let amount = Double(amountString),
              amount > 0 else { return }

        startLoading()

        do {
            _ = try await budgetService.saveBudget(
                amount: amount,
                for: context.category,
                subCategory: context.subCategory
            )

            // Clear edit context
            editContext = nil
            amountString = "0"

            // Reload data
            await loadData()

        } catch {
            handleError(error)
        }
    }

    func deleteBudget() async {
        guard let context = editContext,
              let budget = context.currentBudget else { return }

        startLoading()

        do {
            try await budgetService.deleteBudget(budget)

            // Clear edit context
            editContext = nil
            amountString = "0"

            // Reload data
            await loadData()

        } catch {
            handleError(error)
        }
    }

    // MARK: - Helpers

    private func formatCurrency(_ amount: Double) -> String {
        let currencyCode = SettingsManager.shared.currencyCode
        let formatter = Formatters.currencyFormatter(for: currencyCode)
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }

    /// Check if a category has subcategories (for determining tap behavior)
    func hasSubCategories(_ category: Category) -> Bool {
        guard let subs = category.subCategories?.allObjects as? [SubCategory] else {
            return false
        }
        return !subs.isEmpty
    }

    /// Get summary for a specific category
    func getSummary(for category: Category) -> CategorySpendingSummary? {
        categorySummaries.first { $0.category.id == category.id }
    }
}
