//
//  AccountRow.swift
//  OneTap
//
//  Created by Jimmy Hew on 29/12/2025.
//

import SwiftUI

struct AccountRow: View {
    @ObservedObject var account: Account
    
    var body: some View {
        HStack(spacing: 16) {
            // Account Icon with enhanced styling
            ZStack {
                // Gradient background for icon
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                accountColor.opacity(0.25),
                                accountColor.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle()
                            .stroke(accountColor.opacity(0.4), lineWidth: 1.5)
                    )
                    .shadow(color: accountColor.opacity(0.3), radius: 10, x: 0, y: 5)

                Image(systemName: account.icon ?? "creditcard.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accountColor, accountColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            // Account Info
            VStack(alignment: .leading, spacing: 6) {
                Text(account.name ?? "Unknown Account")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)

                Text(account.typeEnum.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(accountColor.opacity(0.9))
            }

            Spacer()

            // Balance with gradient
            VStack(alignment: .trailing, spacing: 6) {
                Text(formattedBalance)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .gradientForeground(balanceGradient)
                    .shadow(color: accountColor.opacity(0.2), radius: 4, x: 0, y: 2)

                if account.isLiability {
                    Text("Liability")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            AppTheme.expenseGradient
                                .cornerRadius(8)
                        )
                        .shadow(color: AppTheme.expense.opacity(0.3), radius: 4, x: 0, y: 2)
                }
            }
        }
        .padding(20)
        .background(
            ZStack {
                AppTheme.cardGradient

                // Subtle accent glow
                LinearGradient(
                    colors: [
                        accountColor.opacity(0.06),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        )
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            accountColor.opacity(0.1),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 10)
        .shadow(color: accountColor.opacity(0.15), radius: 15, x: 0, y: 8)
    }
    
    private var accountColor: Color {
        return account.typeEnum.color
    }

    private var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = account.currency ?? SettingsManager.shared.currencyCode
        return formatter.string(from: NSNumber(value: account.balance)) ?? "$0.00"
    }

    private var balanceColor: Color {
        if account.isLiability {
            return AppTheme.textPrimary
        }
        return AppTheme.textPrimary
    }

    private var balanceGradient: LinearGradient {
        if account.isLiability {
            return LinearGradient(
                colors: [AppTheme.expense, AppTheme.expense.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        return LinearGradient(
            colors: [
                account.balance >= 0 ? AppTheme.income : AppTheme.expense,
                account.balance >= 0 ? AppTheme.income.opacity(0.8) : AppTheme.expense.opacity(0.8)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}