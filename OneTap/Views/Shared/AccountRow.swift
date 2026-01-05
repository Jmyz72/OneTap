//
//  AccountRow.swift
//  OneTap
//
//  REFACTORED: Clean, modern account row design
//

import SwiftUI

struct AccountRow: View {
    @ObservedObject var account: Account

    var body: some View {
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

                HStack(spacing: 6) {
                    Text(account.typeEnum.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)

                    if account.isLiability {
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textTertiary)

                        Text("Liability")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.expense)
                    }
                }
            }

            Spacer()

            // Balance
            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedBalance)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(balanceColor)
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
}
