//
//  HomeView.swift
//  OneTap
//
//  Home dashboard with shortcuts and summaries
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var container: DependencyContainer
    @State private var viewModel: HomeViewModel?
    @State private var showingAddTransaction = false
    @State private var showingAddAccount = false
    @State private var showingScanReceipt = false

    var body: some View {
        Group {
            if let viewModel {
                HomeContent(
                    viewModel: viewModel,
                    showingAddTransaction: $showingAddTransaction,
                    showingAddAccount: $showingAddAccount,
                    showingScanReceipt: $showingScanReceipt
                )
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = container.makeHomeViewModel()
            }
        }
        .sheet(isPresented: $showingAddTransaction) {
            AddTransactionView()
        }
        .sheet(isPresented: $showingAddAccount) {
            AddAccountView(isPresented: $showingAddAccount)
        }
        .sheet(isPresented: $showingScanReceipt) {
            ScanReceiptView()
        }
    }
}

// MARK: - Content View

private struct HomeContent: View {
    @ObservedObject var viewModel: HomeViewModel
    @Binding var showingAddTransaction: Bool
    @Binding var showingAddAccount: Bool
    @Binding var showingScanReceipt: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Greeting and refresh button
                        headerSection

                        // Quick Actions Shortcuts
                        quickActionsSection

                        // Account Summary
                        accountSummarySection

                        // This Month Overview
                        monthlyOverviewSection

                        // Budget Alerts
                        if viewModel.hasAlerts {
                            budgetAlertsSection
                        }

                        // Pending Approvals
                        if viewModel.hasPendingRecurring {
                            pendingApprovalsSection
                        }

                        // Upcoming Recurring
                        if viewModel.hasUpcomingRecurring {
                            upcomingRecurringSection
                        }

                        // Recent Transactions
                        if !viewModel.recentTransactions.isEmpty {
                            recentTransactionsSection
                        }
                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 16)
                }
                .refreshable {
                    await viewModel.refreshData()
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ProfileButton()
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)

                Text("Here's your financial overview")
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                QuickActionCard(
                    title: "Add Transaction",
                    icon: "plus.circle.fill",
                    color: AppTheme.accent
                ) {
                    showingAddTransaction = true
                }

                QuickActionCard(
                    title: "Add Account",
                    icon: "building.columns.fill",
                    color: .blue
                ) {
                    showingAddAccount = true
                }

                QuickActionCard(
                    title: "Scan Receipt",
                    icon: "camera.viewfinder",
                    color: .purple
                ) {
                    showingScanReceipt = true
                }

                NavigationLink(destination: AnalyticsView()) {
                    QuickActionCardLink(
                        title: "Analytics",
                        icon: "chart.bar.fill",
                        color: .orange
                    )
                }
            }
        }
    }

    // MARK: - Account Summary

    private var accountSummarySection: some View {
        VStack(spacing: 12) {
            // Total Balance Card
            SummaryCard(
                title: "Net Worth",
                amount: viewModel.formattedTotalBalance,
                color: viewModel.totalBalance >= 0 ? AppTheme.income : AppTheme.expense,
                icon: "dollarsign.circle.fill"
            )

            HStack(spacing: 12) {
                // Assets
                SummaryCard(
                    title: "Assets",
                    amount: viewModel.formattedTotalAssets,
                    color: .blue,
                    icon: "arrow.up.circle.fill",
                    compact: true
                )

                // Liabilities
                SummaryCard(
                    title: "Liabilities",
                    amount: viewModel.formattedTotalLiabilities,
                    color: .red,
                    icon: "arrow.down.circle.fill",
                    compact: true
                )
            }
        }
    }

    // MARK: - Monthly Overview

    private var monthlyOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Month")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)

            VStack(spacing: 12) {
                // Income
                MonthlyRow(
                    title: "Income",
                    amount: viewModel.formattedMonthlyIncome,
                    color: AppTheme.income,
                    icon: "arrow.down.circle.fill"
                )

                Divider()

                // Expense
                MonthlyRow(
                    title: "Expenses",
                    amount: viewModel.formattedMonthlyExpense,
                    color: AppTheme.expense,
                    icon: "arrow.up.circle.fill"
                )

                Divider()

                // Net
                MonthlyRow(
                    title: "Net",
                    amount: formatCurrency(viewModel.monthlyIncome - viewModel.monthlyExpense),
                    color: (viewModel.monthlyIncome - viewModel.monthlyExpense) >= 0 ? AppTheme.income : AppTheme.expense,
                    icon: "equal.circle.fill"
                )
            }
            .padding(16)
            .background(AppTheme.cardBackground)
            .cornerRadius(12)
        }
    }

    // MARK: - Budget Alerts

    private var budgetAlertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Budget Alerts")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)

            VStack(spacing: 12) {
                ForEach(viewModel.budgetAlerts) { alert in
                    HStack(spacing: 12) {
                        Image(systemName: alert.icon)
                            .font(.system(size: 20))
                            .foregroundColor(alert.color)
                            .frame(width: 36, height: 36)
                            .background(alert.color.opacity(0.15))
                            .cornerRadius(8)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(alert.budget.category?.name ?? "Budget")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(AppTheme.textPrimary)

                            Text(alert.message)
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.textSecondary)
                        }

                        Spacer()
                    }
                    .padding(12)
                    .background(alert.color.opacity(0.05))
                    .cornerRadius(10)
                }
            }
        }
    }

    // MARK: - Pending Approvals

    private var pendingApprovalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pending Approvals")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)

            VStack(spacing: 12) {
                ForEach(viewModel.pendingRecurringTransactions, id: \.objectID) { pending in
                    PendingRecurringRow(pending: pending, viewModel: viewModel)
                }
            }
            .padding(16)
            .background(AppTheme.cardBackground)
            .cornerRadius(12)
        }
    }

    // MARK: - Upcoming Recurring

    private var upcomingRecurringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming Payments")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)

                Spacer()

                NavigationLink(destination: RecurringTransactionsListView()) {
                    Text("View All")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.accent)
                }
            }

            VStack(spacing: 12) {
                ForEach(viewModel.upcomingRecurring, id: \.objectID) { recurring in
                    UpcomingRecurringRow(recurring: recurring)
                }
            }
            .padding(16)
            .background(AppTheme.cardBackground)
            .cornerRadius(12)
        }
    }

    // MARK: - Recent Transactions

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Transactions")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)

                Spacer()

                NavigationLink(destination: TransactionListView()) {
                    Text("View All")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.accent)
                }
            }

            VStack(spacing: 12) {
                ForEach(viewModel.recentTransactions, id: \.objectID) { transaction in
                    NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                        RecentTransactionRow(transaction: transaction)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(AppTheme.cardBackground)
            .cornerRadius(12)
        }
    }

    // MARK: - Helpers

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = Formatters.currencyFormatter(for: SettingsManager.shared.currencyCode)
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Quick Action Card

private struct QuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(color)
                    .frame(width: 56, height: 56)
                    .background(color.opacity(0.15))
                    .cornerRadius(12)

                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.cardBackground)
            .cornerRadius(12)
        }
    }
}

private struct QuickActionCardLink: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(color)
                .frame(width: 56, height: 56)
                .background(color.opacity(0.15))
                .cornerRadius(12)

            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Summary Card

private struct SummaryCard: View {
    let title: String
    let amount: String
    let color: Color
    let icon: String
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: compact ? 24 : 32))
                .foregroundColor(color)
                .frame(width: compact ? 40 : 48, height: compact ? 40 : 48)
                .background(color.opacity(0.1))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: compact ? 12 : 14))
                    .foregroundColor(AppTheme.textSecondary)

                Text(amount)
                    .font(.system(size: compact ? 18 : 24, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
            }

            Spacer()
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Monthly Row

private struct MonthlyRow: View {
    let title: String
    let amount: String
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.1))
                .cornerRadius(8)

            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            Text(amount)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
    }
}

// MARK: - Upcoming Recurring Row

private struct UpcomingRecurringRow: View {
    let recurring: RecurringTransaction

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: recurring.category?.iconName ?? "arrow.clockwise")
                .foregroundColor(recurring.category?.colorView ?? .gray)
                .frame(width: 32, height: 32)
                .background(recurring.category?.colorView.opacity(0.15) ?? Color.gray.opacity(0.15))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(recurring.title ?? "Recurring Payment")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)

                if let nextDate = recurring.nextRunDate {
                    Text(Formatters.date.string(from: nextDate))
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            Spacer()

            Text(recurring.formattedAmount)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(recurring.typeEnum == .expense ? AppTheme.expense : AppTheme.income)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Pending Recurring Row

private struct PendingRecurringRow: View {
    let pending: PendingRecurringTransaction
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: pending.category?.iconName ?? "clock.fill")
                .foregroundColor(pending.category?.colorView ?? .orange)
                .frame(width: 32, height: 32)
                .background((pending.category?.colorView ?? .orange).opacity(0.15))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(pending.displayTitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)

                Text(pending.statusText)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(pending.formattedAmount)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(pending.typeEnum == .expense ? AppTheme.expense : AppTheme.income)

                Text(pending.formattedScheduledDate)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textTertiary)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                Task {
                    await viewModel.approvePendingTransaction(pending)
                }
            } label: {
                Label("Approve", systemImage: "checkmark.circle.fill")
            }
            .tint(.green)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button(role: .destructive) {
                Task {
                    await viewModel.rejectPendingTransaction(pending)
                }
            } label: {
                Label("Reject", systemImage: "xmark.circle.fill")
            }
        }
    }
}

// MARK: - Recent Transaction Row

private struct RecentTransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: transaction.category?.iconName ?? "questionmark.circle.fill")
                .foregroundColor(transaction.category?.colorView ?? .gray)
                .frame(width: 32, height: 32)
                .background(transaction.category?.colorView.opacity(0.15) ?? Color.gray.opacity(0.15))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.title ?? "Transaction")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)

                if let date = transaction.date {
                    Text(Formatters.date.string(from: date))
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            Spacer()

            Text(transaction.formattedAmount)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(transaction.typeEnum == .expense ? AppTheme.expense : AppTheme.income)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    HomeView()
        .environmentObject(DependencyContainer(persistenceController: .preview))
}
