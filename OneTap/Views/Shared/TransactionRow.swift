//
//  TransactionRow.swift
//  OneTap
//
//  Created by Jimmy Hew on 29/12/2025.
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
                    .frame(width: 48, height: 48)
                
                if let categoryEnum = transaction.categoryEnum {
                    Image(systemName: categoryEnum.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(categoryColor)
                }
            }
            
            // Transaction Details
            VStack(alignment: .leading, spacing: 6) {
                Text(transaction.title ?? "Unknown")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(transaction.category ?? "")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                    
                    if let merchant = transaction.merchant, !merchant.isEmpty {
                        Circle()
                            .fill(AppTheme.textTertiary)
                            .frame(width: 3, height: 3)
                        
                        Text(merchant)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
                
                Text(formatDate(transaction.date))
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textTertiary)
            }
            
            Spacer()
            
            // Amount
            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.formattedAmount)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(amountColor)
                
                if let account = transaction.account {
                    Text(account.name ?? "")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(AppTheme.tertiaryBackground)
                        .cornerRadius(6)
                }
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
    
    private var categoryColor: Color {
        guard let categoryEnum = transaction.categoryEnum else {
            return .gray
        }
        
        switch categoryEnum {
        case .food: return .orange
        case .transport: return .blue
        case .entertainment: return .purple
        case .shopping: return .pink
        case .bills: return .red
        case .health: return .green
        case .salary: return AppTheme.income
        case .investment: return .indigo
        case .other: return .gray
        }
    }
    
    private var amountColor: Color {
        // Negative amounts are expenses (red), positive are income (green)
        return transaction.amount < 0 ? AppTheme.expense : AppTheme.income
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}