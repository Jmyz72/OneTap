//
//  AccountNetWorthCard.swift
//  OneTap
//
//  Created by Jimmy Hew on 04/01/2026.
//

import SwiftUI

struct AccountNetWorthCard: View {
    @ObservedObject var viewModel: AccountListViewModel

    var body: some View {
        VStack(spacing: 20) {
            // Net Worth
            VStack(spacing: 8) {
                Text("Net Worth")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)

                Text(viewModel.formatCurrency(viewModel.netWorth))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .gradientForeground(
                        LinearGradient(
                            colors: [AppTheme.accent, AppTheme.accent.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }

            // Assets & Liabilities
            HStack(spacing: 16) {
                FinancialStatCard(
                    title: "Assets",
                    amount: viewModel.formatCurrency(viewModel.totalAssets),
                    color: AppTheme.income,
                    icon: "arrow.up.circle.fill"
                )

                FinancialStatCard(
                    title: "Liabilities",
                    amount: viewModel.formatCurrency(viewModel.totalLiabilities),
                    color: AppTheme.expense,
                    icon: "arrow.down.circle.fill"
                )
            }
        }
        .padding(28)
        .background(
            ZStack {
                AppTheme.cardBackground

                // Subtle glow
                LinearGradient(
                    colors: [
                        AppTheme.accent.opacity(0.08),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 8)
    }
}

// MARK: - Financial Stat Card

private struct FinancialStatCard: View {
    let title: String
    let amount: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)

            Text(amount)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppTheme.secondaryBackground)
        .cornerRadius(16)
    }
}
