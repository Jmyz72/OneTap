//
//  AccountRow.swift
//  OneTap
//
//  REFACTORED: Clean, modern account row design
//

import SwiftUI

struct AccountRow: View {
    @ObservedObject var account: Account

    private var savingsGoal: SavingsGoal? {
        account.savingsGoal
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Account Icon
                AccountIconView(
                    iconName: account.icon ?? "creditcard.fill",
                    color: accountColor,
                    size: 24
                )

                // Account Info
                VStack(alignment: .leading, spacing: 5) {
                    Text(account.name ?? "Unknown Account")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)

                    Text(account.typeEnum.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                // Balance
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formattedBalance)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(balanceColor)
                }
            }

            // Savings Goal Progress Bar
            if let goal = savingsGoal {
                VStack(spacing: 6) {
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(AppTheme.secondaryBackground)
                                .frame(height: 6)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(goalProgressColor(goal.progress))
                                .frame(width: geometry.size.width * goal.progressClamped, height: 6)
                        }
                    }
                    .frame(height: 6)

                    // Progress text
                    HStack {
                        Text(goal.name ?? "Goal")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.textTertiary)

                        Spacer()

                        Text(goal.progressSummary)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(goalProgressColor(goal.progress))
                    }
                }
                .padding(.top, 12)
            }
        }
        .padding(18)
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    private var accountColor: Color {
        return account.typeEnum.color
    }

    private var formattedBalance: String {
        let formatter = Formatters.currencyFormatter(for: account.currency ?? SettingsManager.shared.currencyCode)
        return formatter.string(from: NSNumber(value: account.balance)) ?? "$0.00"
    }

    private var balanceColor: Color {
        if account.isLiability {
            return AppTheme.expense
        }
        return account.balance >= 0 ? AppTheme.income : AppTheme.expense
    }

    private func goalProgressColor(_ progress: Double) -> Color {
        if progress >= 1.0 {
            return AppTheme.income
        } else if progress >= 0.7 {
            return .orange
        } else {
            return AppTheme.accent
        }
    }
}
