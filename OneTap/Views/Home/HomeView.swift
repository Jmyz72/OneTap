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
                    VStack(spacing: 20) {
                        // Today Header
                        todayHeaderSection

                        // Quick Actions
                        quickActionsSection

                        // Today's Activity
                        todayActivitySection

                        // Needs Attention (combined alerts + approvals)
                        if viewModel.hasAlerts || viewModel.hasPendingRecurring {
                            needsAttentionSection
                        }

                        // This Week (upcoming payments)
                        if viewModel.hasUpcomingRecurring {
                            thisWeekSection
                        }

                        // Savings Goals Progress
                        savingsGoalsSection

                        // Insights (placeholder for future)
                        // insightsSection
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 16)
                }
                .refreshable {
                    await viewModel.refreshData()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ProfileButton()
                }
            }
        }
    }

    // MARK: - Today Header

    private var todayHeaderSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)

                Text(todayDateString)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()
        }
    }

    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }

    // MARK: - Quick Actions (Compact)

    private var quickActionsSection: some View {
        HStack(spacing: 8) {
            QuickActionButton(
                icon: "plus",
                title: "Add",
                color: AppTheme.income
            ) {
                showingAddTransaction = true
            }

            QuickActionButton(
                icon: "camera.viewfinder",
                title: "Scan",
                color: .purple
            ) {
                showingScanReceipt = true
            }

            QuickActionButton(
                icon: "arrow.left.arrow.right",
                title: "Transfer",
                color: AppTheme.accent
            ) {
                // TODO: Transfer
            }

            NavigationLink(destination: BudgetListView()) {
                QuickActionButtonLink(
                    icon: "chart.bar.fill",
                    title: "Budget",
                    color: .orange
                )
            }
        }
    }

    // MARK: - Today's Activity

    private var todayActivitySection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.accent)

                Text("Today's Activity")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()
            }

            HStack(spacing: 12) {
                // Spent Today
                TodayStatCard(
                    label: "Spent",
                    amount: viewModel.formattedTodayExpense,
                    color: AppTheme.expense
                )

                // Income Today
                TodayStatCard(
                    label: "Income",
                    amount: viewModel.formattedTodayIncome,
                    color: AppTheme.income
                )
            }

            // Due Today
            if !viewModel.dueToday.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Due Today")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)

                    ForEach(viewModel.dueToday, id: \.objectID) { recurring in
                        HStack(spacing: 8) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)

                            Text(recurring.title ?? "Payment")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.textPrimary)

                            Spacer()

                            Text(recurring.formattedAmount)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppTheme.expense)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Needs Attention

    private var needsAttentionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)

                Text("Needs Attention")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)

                Text("(\(viewModel.attentionCount))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.textTertiary)

                Spacer()
            }

            VStack(spacing: 8) {
                // Budget Alerts
                ForEach(viewModel.budgetAlerts) { alert in
                    AttentionItemRow(
                        icon: alert.icon,
                        title: alert.budget.category?.name ?? "Budget",
                        subtitle: alert.message,
                        color: alert.color
                    )
                }

                // Pending Approvals
                ForEach(viewModel.pendingRecurringTransactions, id: \.objectID) { pending in
                    AttentionItemRow(
                        icon: "checkmark.circle.fill",
                        title: "Approve: \(pending.displayTitle)",
                        subtitle: pending.formattedScheduledDate,
                        color: .blue
                    )
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
        }
        .padding(14)
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - This Week

    private var thisWeekSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.accent)

                Text("This Week")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                Text("\(viewModel.upcomingRecurring.count) payments · \(viewModel.formattedUpcomingTotal)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
            }

            VStack(spacing: 8) {
                ForEach(viewModel.upcomingRecurring.prefix(3), id: \.objectID) { recurring in
                    UpcomingPaymentRow(recurring: recurring)
                }

                if viewModel.upcomingRecurring.count > 3 {
                    NavigationLink(destination: RecurringTransactionsListView()) {
                        HStack {
                            Text("View all \(viewModel.upcomingRecurring.count) payments")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppTheme.accent)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppTheme.accent)
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding(14)
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Savings Goals

    private var savingsGoalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "target")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.income)

                Text("Savings Goals")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                NavigationLink(destination: AccountListView()) {
                    Text("View All")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.accent)
                }
            }

            if viewModel.savingsGoals.isEmpty {
                HStack {
                    Spacer()

                    VStack(spacing: 8) {
                        Image(systemName: "scope")
                            .font(.system(size: 32))
                            .foregroundColor(AppTheme.textTertiary)

                        Text("No goals set")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.textSecondary)

                        NavigationLink(destination: AccountListView()) {
                            Text("Set a goal")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppTheme.accent)
                        }
                    }
                    .padding(.vertical, 16)

                    Spacer()
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.savingsGoals, id: \.objectID) { goal in
                        GoalProgressRow(goal: goal)
                    }
                }
            }
        }
        .padding(14)
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Helpers

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = Formatters.currencyFormatter(for: SettingsManager.shared.currencyCode)
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Quick Action Button (Compact)

private struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(AppTheme.secondaryBackground)
            .cornerRadius(10)
        }
    }
}

private struct QuickActionButtonLink: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(AppTheme.secondaryBackground)
        .cornerRadius(10)
    }
}

// MARK: - Today Stat Card

private struct TodayStatCard: View {
    let label: String
    let amount: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)

            Text(amount)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.secondaryBackground)
        .cornerRadius(10)
    }
}

// MARK: - Attention Item Row

private struct AttentionItemRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.15))
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Upcoming Payment Row

private struct UpcomingPaymentRow: View {
    let recurring: RecurringTransaction

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: recurring.category?.iconName ?? "arrow.clockwise")
                .font(.system(size: 14))
                .foregroundColor(recurring.category?.colorView ?? .gray)
                .frame(width: 28, height: 28)
                .background((recurring.category?.colorView ?? .gray).opacity(0.15))
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 2) {
                Text(recurring.title ?? "Payment")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)

                if let date = recurring.nextRunDate {
                    Text(Formatters.date.string(from: date))
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            Spacer()

            Text(recurring.formattedAmount)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(recurring.typeEnum == .expense ? AppTheme.expense : AppTheme.income)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Goal Progress Row

private struct GoalProgressRow: View {
    let goal: SavingsGoal

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(goal.name ?? "Goal")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                Text(goal.progressSummary)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(progressColor)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppTheme.secondaryBackground)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(progressColor)
                        .frame(width: geometry.size.width * goal.progressClamped, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 4)
    }

    private var progressColor: Color {
        if goal.progress >= 1.0 {
            return AppTheme.income
        } else if goal.progress >= 0.7 {
            return .orange
        }
        return AppTheme.accent
    }
}

#Preview {
    HomeView()
        .environmentObject(DependencyContainer(persistenceController: .preview))
}
