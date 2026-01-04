//
//  TransactionRow.swift
//  OneTap
//

import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction
    @State private var isPressed = false

    var body: some View {
        HStack(spacing: 16) {
            // Category Icon with Gradient Background
            ZStack {
                // Gradient background for icon
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                categoryColor.opacity(0.25),
                                categoryColor.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle()
                            .stroke(categoryColor.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: categoryColor.opacity(0.3), radius: 8, x: 0, y: 4)

                Image(systemName: categoryIcon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [categoryColor, categoryColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 5) {
                // Main Text: Category or SubCategory
                Text(mainDisplayJSON)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)

                // Sub Text: Title • Merchant • Account
                HStack(spacing: 4) {
                    if let title = transaction.title, !title.isEmpty {
                        Text(title)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    
                    if let title = transaction.title, !title.isEmpty, (transaction.merchant != nil || transaction.account != nil) {
                         Text("•")
                            .foregroundColor(AppTheme.textTertiary)
                    }

                    if let merchant = transaction.merchant, !merchant.isEmpty {
                        Text(merchant)
                            .foregroundColor(AppTheme.textSecondary)
                        
                        if transaction.account != nil {
                            Text("•")
                                .foregroundColor(AppTheme.textTertiary)
                        }
                    }

                    if let account = transaction.account {
                        Text(account.name ?? "Unknown Account")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                Text(transaction.formattedAmount)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .gradientForeground(amountGradient)
                    .shadow(color: amountColor.opacity(0.3), radius: 4, x: 0, y: 2)

                HStack(spacing: 4) {
                    if transaction.recurringTransaction != nil {
                        Image(systemName: "repeat")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(AppTheme.accent)
                    }

                    Text(Formatters.time.string(from: transaction.date ?? Date()))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.textTertiary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(AppTheme.secondaryBackground)
                .cornerRadius(8)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            ZStack {
                AppTheme.cardGradient

                // Subtle accent glow on the left edge
                LinearGradient(
                    colors: [
                        categoryColor.opacity(0.08),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        )
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 6)
        .shadow(color: categoryColor.opacity(0.1), radius: 8, x: 0, y: 4)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }
    
    private var mainDisplayJSON: String {
        if let sub = transaction.subCategory?.name {
            return sub
        }
        return transaction.category?.name ?? "Uncategorized"
    }
    
    private var categoryColor: Color {
        transaction.category?.colorView ?? AppTheme.accent
    }

    private var categoryIcon: String {
        transaction.category?.iconName ?? "questionmark.circle.fill"
    }

    private var amountColor: Color {
        switch transaction.typeEnum {
        case .expense: return AppTheme.expense
        case .income: return AppTheme.income
        case .transfer: return AppTheme.textPrimary
        case .adjustment: return AppTheme.textSecondary
        }
    }

    private var amountGradient: LinearGradient {
        switch transaction.typeEnum {
        case .expense: return AppTheme.expenseGradient
        case .income: return AppTheme.incomeGradient
        case .transfer: return AppTheme.blueGradient
        case .adjustment:
            return LinearGradient(
                colors: [AppTheme.textSecondary, AppTheme.textTertiary],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}
