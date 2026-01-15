//
//  BudgetModel.swift
//  OneTap
//

import Foundation
import SwiftUI
@preconcurrency internal import CoreData

// MARK: - Budget Extension

extension Budget {
    /// Display name for the budget (category or subcategory name)
    var displayName: String {
        if let subCategory = subCategory {
            return subCategory.name ?? "Unknown"
        }
        return category?.name ?? "Unknown"
    }

    /// Icon for the budget (from subcategory or category)
    var displayIcon: String {
        if let subCategory = subCategory, let icon = subCategory.icon {
            return icon
        }
        return category?.icon ?? "questionmark.circle.fill"
    }

    /// Color for the budget (from category)
    var displayColor: Color {
        category?.colorView ?? AppTheme.accent
    }

    /// Whether this is a subcategory-level budget
    var isSubCategoryBudget: Bool {
        subCategory != nil
    }

    /// Formatted budget amount
    var formattedAmount: String {
        let currencyCode = SettingsManager.shared.currencyCode
        let formatter = Formatters.currencyFormatter(for: currencyCode)
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

// MARK: - Budget Summary (for display with calculated spent)

/// Represents a budget with its calculated spending for a specific month
struct BudgetSummary: Identifiable {
    let id: UUID
    let budget: Budget
    let spent: Double
    let month: Date

    init(budget: Budget, spent: Double, month: Date = Date()) {
        self.id = budget.id ?? UUID()
        self.budget = budget
        self.spent = spent
        self.month = month
    }

    // MARK: - Computed Properties

    var amount: Double {
        budget.amount
    }

    var remaining: Double {
        max(0, amount - spent)
    }

    /// Progress as percentage (0-100+)
    var progress: Double {
        guard amount > 0 else { return 0 }
        return (spent / amount) * 100
    }

    /// Progress as fraction (0.0-1.0+) for progress bars
    var progressFraction: Double {
        guard amount > 0 else { return 0 }
        return spent / amount
    }

    var isExceeded: Bool {
        spent > amount
    }

    var isNearLimit: Bool {
        progress >= 80 && !isExceeded
    }

    var status: BudgetStatus {
        if isExceeded {
            return .exceeded
        } else if isNearLimit {
            return .nearLimit
        } else {
            return .ok
        }
    }

    var statusColor: Color {
        switch status {
        case .exceeded:
            return AppTheme.expense
        case .nearLimit:
            return .orange
        case .ok:
            return AppTheme.income
        case .noBudget:
            return AppTheme.textSecondary
        }
    }

    // MARK: - Formatted Strings

    var formattedAmount: String {
        let currencyCode = SettingsManager.shared.currencyCode
        let formatter = Formatters.currencyFormatter(for: currencyCode)
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }

    var formattedSpent: String {
        let currencyCode = SettingsManager.shared.currencyCode
        let formatter = Formatters.currencyFormatter(for: currencyCode)
        return formatter.string(from: NSNumber(value: spent)) ?? "$0.00"
    }

    var formattedRemaining: String {
        let currencyCode = SettingsManager.shared.currencyCode
        let formatter = Formatters.currencyFormatter(for: currencyCode)
        return formatter.string(from: NSNumber(value: remaining)) ?? "$0.00"
    }

    // MARK: - Display Properties (delegated to Budget)

    var displayName: String {
        budget.displayName
    }

    var displayIcon: String {
        budget.displayIcon
    }

    var displayColor: Color {
        budget.displayColor
    }

    var isSubCategoryBudget: Bool {
        budget.isSubCategoryBudget
    }

    var category: Category? {
        budget.category
    }

    var subCategory: SubCategory? {
        budget.subCategory
    }
}

// MARK: - Category Spending Summary (for categories without budget)

/// Represents spending for a category that may or may not have a budget
struct CategorySpendingSummary: Identifiable {
    let id: UUID
    let category: Category
    let spent: Double
    let budget: Budget?
    let subCategorySummaries: [SubCategorySpendingSummary]
    let month: Date

    var amount: Double? {
        budget?.amount
    }

    var hasBudget: Bool {
        budget != nil
    }

    var hasSubCategories: Bool {
        !subCategorySummaries.isEmpty
    }

    /// Sum of subcategory budgets (minimum for category budget)
    var subCategoryBudgetTotal: Double {
        subCategorySummaries.compactMap { $0.budget?.amount }.reduce(0, +)
    }

    var progress: Double? {
        guard let amount = amount, amount > 0 else { return nil }
        return (spent / amount) * 100
    }

    var progressFraction: Double? {
        guard let amount = amount, amount > 0 else { return nil }
        return spent / amount
    }

    var isExceeded: Bool {
        guard let amount = amount else { return false }
        return spent > amount
    }

    var isNearLimit: Bool {
        guard let progress = progress else { return false }
        return progress >= 80 && !isExceeded
    }

    var statusColor: Color {
        guard hasBudget else { return AppTheme.textSecondary }
        if isExceeded {
            return AppTheme.expense
        } else if isNearLimit {
            return .orange
        } else {
            return AppTheme.income
        }
    }

    // Formatted strings
    var formattedSpent: String {
        let currencyCode = SettingsManager.shared.currencyCode
        let formatter = Formatters.currencyFormatter(for: currencyCode)
        return formatter.string(from: NSNumber(value: spent)) ?? "$0.00"
    }

    var formattedAmount: String? {
        guard let amount = amount else { return nil }
        let currencyCode = SettingsManager.shared.currencyCode
        let formatter = Formatters.currencyFormatter(for: currencyCode)
        return formatter.string(from: NSNumber(value: amount))
    }
}

// MARK: - SubCategory Spending Summary

struct SubCategorySpendingSummary: Identifiable {
    let id: UUID
    let subCategory: SubCategory
    let spent: Double
    let budget: Budget?
    let month: Date

    var amount: Double? {
        budget?.amount
    }

    var hasBudget: Bool {
        budget != nil
    }

    var progress: Double? {
        guard let amount = amount, amount > 0 else { return nil }
        return (spent / amount) * 100
    }

    var progressFraction: Double? {
        guard let amount = amount, amount > 0 else { return nil }
        return spent / amount
    }

    var isExceeded: Bool {
        guard let amount = amount else { return false }
        return spent > amount
    }

    var isNearLimit: Bool {
        guard let progress = progress else { return false }
        return progress >= 80 && !isExceeded
    }

    var statusColor: Color {
        guard hasBudget else { return AppTheme.textSecondary }
        if isExceeded {
            return AppTheme.expense
        } else if isNearLimit {
            return .orange
        } else {
            return AppTheme.income
        }
    }

    // Formatted strings
    var formattedSpent: String {
        let currencyCode = SettingsManager.shared.currencyCode
        let formatter = Formatters.currencyFormatter(for: currencyCode)
        return formatter.string(from: NSNumber(value: spent)) ?? "$0.00"
    }

    var formattedAmount: String? {
        guard let amount = amount else { return nil }
        let currencyCode = SettingsManager.shared.currencyCode
        let formatter = Formatters.currencyFormatter(for: currencyCode)
        return formatter.string(from: NSNumber(value: amount))
    }
}

// MARK: - Budget Edit Context

/// Context for editing a budget via numpad sheet
struct BudgetEditContext: Identifiable, Equatable {
    let id = UUID()

    static func == (lhs: BudgetEditContext, rhs: BudgetEditContext) -> Bool {
        lhs.id == rhs.id
    }
    let category: Category
    let subCategory: SubCategory?
    let currentBudget: Budget?
    let currentSpent: Double
    let minimumAmount: Double  // Sum of subcategory budgets (for category budgets)

    var isEditing: Bool {
        currentBudget != nil
    }

    var displayName: String {
        if let subCategory = subCategory {
            return subCategory.name ?? "Unknown"
        }
        return category.name ?? "Unknown"
    }

    var displayIcon: String {
        if let subCategory = subCategory, let icon = subCategory.icon {
            return icon
        }
        return category.icon ?? "questionmark.circle.fill"
    }

    var displayColor: Color {
        category.colorView
    }

    var currentAmount: Double {
        currentBudget?.amount ?? 0
    }

    var hasMinimumConstraint: Bool {
        subCategory == nil && minimumAmount > 0
    }
}
