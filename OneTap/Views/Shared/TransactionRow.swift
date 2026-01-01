//
//  TransactionRow.swift
//  OneTap
//

import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 16) {
            // Category Icon
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: categoryIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(categoryColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.title ?? "Unknown Transaction")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                
                HStack(spacing: 4) {
                    if let account = transaction.account {
                        Text(account.name ?? "Unknown Account")
                    }
                    
                    if transaction.merchant != nil {
                        Text("•")
                        Text(transaction.merchant!)
                    }
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.formattedAmount)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(amountColor)
                
                Text(Formatters.shortDate.string(from: transaction.date ?? Date()))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.textTertiary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
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
        case .adjustment: return AppTheme.textSecondary // Neutral for adjustments
        }
    }
}
