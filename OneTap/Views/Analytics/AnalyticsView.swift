//
//  AnalyticsView.swift
//  OneTap
//
//  Analytics and insights view with charts
//

import SwiftUI

struct AnalyticsView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Spending by Category Chart Placeholder
                        chartPlaceholder(
                            title: "Spending by Category",
                            icon: "chart.pie.fill",
                            description: "Visual breakdown of your expenses by category"
                        )

                        // Monthly Trend Chart Placeholder
                        chartPlaceholder(
                            title: "Monthly Trends",
                            icon: "chart.line.uptrend.xyaxis",
                            description: "Track your income and expenses over time"
                        )

                        // Top Categories Placeholder
                        chartPlaceholder(
                            title: "Top Categories",
                            icon: "chart.bar.fill",
                            description: "See where you spend the most"
                        )

                        // Cash Flow Placeholder
                        chartPlaceholder(
                            title: "Cash Flow",
                            icon: "arrow.up.arrow.down.circle.fill",
                            description: "Monitor your income vs expenses"
                        )
                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ProfileButton()
                }
            }
        }
    }

    private func chartPlaceholder(title: String, icon: String, description: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(AppTheme.accent.opacity(0.6))

            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)

            Text(description)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Text("Coming Soon")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.accent)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(AppTheme.accent.opacity(0.1))
                .cornerRadius(8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    AnalyticsView()
}
