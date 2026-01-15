//
//  BudgetRow.swift
//  OneTap
//
//  Reusable budget row component for displaying category/subcategory budgets
//

import SwiftUI

struct BudgetRow: View {
    let icon: String
    let iconColor: Color
    let name: String
    let spent: Double
    let budgetAmount: Double?
    let hasChevron: Bool

    init(
        icon: String,
        iconColor: Color,
        name: String,
        spent: Double,
        budgetAmount: Double?,
        hasChevron: Bool = false
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.name = name
        self.spent = spent
        self.budgetAmount = budgetAmount
        self.hasChevron = hasChevron
    }

    private var progress: Double? {
        guard let budget = budgetAmount, budget > 0 else { return nil }
        return spent / budget
    }

    private var progressPercentage: Int? {
        guard let progress = progress else { return nil }
        return Int(progress * 100)
    }

    private var isExceeded: Bool {
        guard let budget = budgetAmount else { return false }
        return spent > budget
    }

    private var isNearLimit: Bool {
        guard let progress = progress else { return false }
        return progress >= 0.8 && !isExceeded
    }

    private var statusColor: Color {
        guard budgetAmount != nil else { return AppTheme.textSecondary }
        if isExceeded {
            return AppTheme.expense
        } else if isNearLimit {
            return .orange
        } else {
            return AppTheme.income
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(iconColor)
                }

                // Name and status
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)

                    if budgetAmount == nil {
                        Text("Tap to set budget")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textTertiary)
                    }
                }

                Spacer()

                // Amount display
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(formattedSpent)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)

                        Text("/")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.textTertiary)

                        Text(formattedBudget)
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.textSecondary)
                    }

                    if let percentage = progressPercentage {
                        Text("\(percentage)%")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(statusColor)
                    }
                }

                // Chevron for expandable rows
                if hasChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.textTertiary)
                }
            }

            // Progress bar
            if budgetAmount != nil {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppTheme.secondaryBackground)
                            .frame(height: 8)

                        // Progress
                        RoundedRectangle(cornerRadius: 4)
                            .fill(statusColor)
                            .frame(width: min(geometry.size.width * (progress ?? 0), geometry.size.width), height: 8)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(AppTheme.cardBackground)
    }

    // MARK: - Formatting

    private var formattedSpent: String {
        formatCurrency(spent)
    }

    private var formattedBudget: String {
        guard let budget = budgetAmount else { return "--" }
        return formatCurrency(budget)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let currencyCode = SettingsManager.shared.currencyCode
        let formatter = Formatters.currencyFormatter(for: currencyCode)
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Convenience Initializers

extension BudgetRow {
    /// Initialize from CategorySpendingSummary
    init(summary: CategorySpendingSummary, hasChevron: Bool = false) {
        self.icon = summary.category.icon ?? "questionmark.circle.fill"
        self.iconColor = summary.category.colorView
        self.name = summary.category.name ?? "Unknown"
        self.spent = summary.spent
        self.budgetAmount = summary.budget?.amount
        self.hasChevron = hasChevron
    }

    /// Initialize from SubCategorySpendingSummary
    init(summary: SubCategorySpendingSummary) {
        self.icon = summary.subCategory.icon ?? summary.subCategory.category?.icon ?? "tag.fill"
        self.iconColor = summary.subCategory.category?.colorView ?? AppTheme.accent
        self.name = summary.subCategory.name ?? "Unknown"
        self.spent = summary.spent
        self.budgetAmount = summary.budget?.amount
        self.hasChevron = false
    }
}

#Preview {
    VStack(spacing: 0) {
        BudgetRow(
            icon: "cart.fill",
            iconColor: .blue,
            name: "Shopping",
            spent: 380,
            budgetAmount: 400,
            hasChevron: true
        )

        Divider()

        BudgetRow(
            icon: "fork.knife",
            iconColor: .orange,
            name: "Food",
            spent: 450,
            budgetAmount: 500,
            hasChevron: true
        )

        Divider()

        BudgetRow(
            icon: "lightbulb.fill",
            iconColor: .yellow,
            name: "Utilities",
            spent: 50,
            budgetAmount: nil,
            hasChevron: false
        )

        Divider()

        BudgetRow(
            icon: "gamecontroller.fill",
            iconColor: .purple,
            name: "Entertainment",
            spent: 120,
            budgetAmount: 100,
            hasChevron: false
        )
    }
    .background(AppTheme.background)
}
