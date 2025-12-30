//
//  AccountRow.swift
//  OneTap
//
//  Created by Jimmy Hew on 29/12/2025.
//

import SwiftUI

struct AccountRow: View {
    let account: Account
    
    var body: some View {
        HStack(spacing: 16) {
            // Account Icon
            AccountIconView(
                iconName: account.icon ?? "creditcard.fill",
                color: accountColor,
                size: 24
            )
            
            // Account Info
            VStack(alignment: .leading, spacing: 6) {
                Text(account.name ?? "Unknown Account")
                    .font(.system(size: 17, weight: .bold))
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
                
                if account.isLiability {
                    Text("Liability")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.expense)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.expense.opacity(0.1))
                        .cornerRadius(6)
                }
            }
        }
        .padding(20)
        .background(AppTheme.cardBackground)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
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
            return AppTheme.textPrimary // Liabilities are just white until negative/paid off logic is refined, or expense red.
        }
        return AppTheme.textPrimary // Keep balance neutral or positive green? Let's go neutral white for cleaner look, only income/expense flow colored.
    }
}