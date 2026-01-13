//
//  AnalyticsView.swift
//  OneTap
//
//  Analytics and insights view with charts and breakdowns
//

import SwiftUI

struct AnalyticsView: View {
    @EnvironmentObject private var container: DependencyContainer
    @State private var viewModel: AnalyticsViewModel?

    var body: some View {
        Group {
            if let viewModel {
                AnalyticsContent(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = container.makeAnalyticsViewModel()
            }
        }
    }
}

// MARK: - Content View

private struct AnalyticsContent: View {
    @ObservedObject var viewModel: AnalyticsViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Time Period Selector
                        periodSelector

                        if viewModel.hasData {
                            // Overview Cards
                            overviewSection

                            // Category Breakdown
                            if !viewModel.categoryBreakdown.isEmpty {
                                categoryBreakdownSection
                            }

                            // Top Categories
                            if !viewModel.topCategories.isEmpty {
                                topCategoriesSection
                            }

                            // Monthly Trends (only for year view)
                            if viewModel.selectedPeriod == .thisYear && !viewModel.monthlyTrends.isEmpty {
                                monthlyTrendsSection
                            }
                        } else {
                            emptyStateView
                        }
                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 16)
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

    // MARK: - Period Selector

    private var periodSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TimePeriod.allCases, id: \.self) { period in
                    Button {
                        Task {
                            await viewModel.selectPeriod(period)
                        }
                    } label: {
                        Text(period.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(viewModel.selectedPeriod == period ? .white : AppTheme.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                viewModel.selectedPeriod == period ?
                                    AppTheme.accent : AppTheme.cardBackground
                            )
                            .cornerRadius(10)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Overview Section

    private var overviewSection: some View {
        VStack(spacing: 12) {
            // Income Card
            overviewCard(
                title: "Income",
                amount: viewModel.formattedIncome,
                color: AppTheme.income,
                icon: "arrow.down.circle.fill"
            )

            // Expense Card
            overviewCard(
                title: "Expenses",
                amount: viewModel.formattedExpense,
                color: AppTheme.expense,
                icon: "arrow.up.circle.fill"
            )

            // Net Amount Card
            overviewCard(
                title: "Net",
                amount: viewModel.formattedNet,
                color: viewModel.netAmount >= 0 ? AppTheme.income : AppTheme.expense,
                icon: viewModel.netAmount >= 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
            )
        }
    }

    private func overviewCard(title: String, amount: String, color: Color, icon: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(color)
                .frame(width: 48, height: 48)
                .background(color.opacity(0.1))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textSecondary)

                Text(amount)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
            }

            Spacer()
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Category Breakdown

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spending by Category")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)

            VStack(spacing: 12) {
                ForEach(viewModel.categoryBreakdown) { categoryData in
                    categoryBreakdownRow(categoryData)
                }
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
    }

    private func categoryBreakdownRow(_ data: CategoryData) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: data.icon)
                    .foregroundColor(data.color)
                    .frame(width: 24)

                Text(data.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(data.formattedAmount)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)

                    Text(String(format: "%.1f%%", data.percentage))
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                        .cornerRadius(3)

                    Rectangle()
                        .fill(data.color)
                        .frame(width: geometry.size.width * CGFloat(data.percentage / 100), height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Top Categories

    private var topCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top 5 Categories")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)

            VStack(spacing: 12) {
                ForEach(Array(viewModel.topCategories.enumerated()), id: \.element.id) { index, categoryData in
                    HStack {
                        // Rank badge
                        Text("\(index + 1)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(categoryData.color)
                            )

                        Image(systemName: categoryData.icon)
                            .foregroundColor(categoryData.color)
                            .frame(width: 24)

                        Text(categoryData.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppTheme.textPrimary)

                        Spacer()

                        Text(categoryData.formattedAmount)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    .padding(.vertical, 8)

                    if index < viewModel.topCategories.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Monthly Trends

    private var monthlyTrendsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Monthly Trends")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)

            VStack(spacing: 16) {
                ForEach(viewModel.monthlyTrends) { monthData in
                    monthlyTrendRow(monthData)
                }
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
    }

    private func monthlyTrendRow(_ data: MonthData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(data.month)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)

            HStack(spacing: 12) {
                // Income bar
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Circle()
                            .fill(AppTheme.income)
                            .frame(width: 8, height: 8)
                        Text("Income")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textSecondary)
                    }

                    GeometryReader { geometry in
                        let maxAmount = max(data.income, data.expense)
                        let width = maxAmount > 0 ? geometry.size.width * CGFloat(data.income / maxAmount) : 0

                        HStack(spacing: 4) {
                            Rectangle()
                                .fill(AppTheme.income)
                                .frame(width: max(width, 2), height: 20)
                                .cornerRadius(4)

                            Text(formatCurrency(data.income))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.textPrimary)

                            Spacer()
                        }
                    }
                    .frame(height: 20)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                // Expense bar
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Circle()
                            .fill(AppTheme.expense)
                            .frame(width: 8, height: 8)
                        Text("Expenses")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textSecondary)
                    }

                    GeometryReader { geometry in
                        let maxAmount = max(data.income, data.expense)
                        let width = maxAmount > 0 ? geometry.size.width * CGFloat(data.expense / maxAmount) : 0

                        HStack(spacing: 4) {
                            Rectangle()
                                .fill(AppTheme.expense)
                                .frame(width: max(width, 2), height: 20)
                                .cornerRadius(4)

                            Text(formatCurrency(data.expense))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.textPrimary)

                            Spacer()
                        }
                    }
                    .frame(height: 20)
                }

                Spacer()
            }

            // Net amount
            HStack {
                Text("Net:")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.textSecondary)

                Text(formatCurrency(data.net))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(data.net >= 0 ? AppTheme.income : AppTheme.expense)

                Spacer()
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.textTertiary)

            Text("No Data Available")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)

            Text("Add transactions to see your spending analytics")
                .font(.system(size: 15))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 60)
    }

    // MARK: - Helpers

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = Formatters.currencyFormatter(for: SettingsManager.shared.currencyCode)
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

#Preview {
    AnalyticsView()
        .environmentObject(DependencyContainer(persistenceController: .preview))
}
