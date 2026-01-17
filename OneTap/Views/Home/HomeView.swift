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
    @State private var showingClaimsList = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Today Header
                        todayHeaderSection

                        // Hero Card - Net Worth Summary
                        heroCardSection

                        // Quick Actions
                        quickActionsSection

                        // Today's Activity
                        todayActivitySection

                        // Needs Attention (combined alerts + approvals)
                        if viewModel.hasAlerts || viewModel.hasPendingRecurring {
                            needsAttentionSection
                        }

                        // Pending Claims
                        if !viewModel.pendingClaims.isEmpty {
                            claimsSection
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
            .sheet(isPresented: $showingClaimsList) {
                ClaimsListView()
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

    // MARK: - Hero Card

    private var heroCardSection: some View {
        VStack(spacing: 0) {
            // Main Balance Display
            VStack(spacing: 8) {
                Text("NET WORTH")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundColor(AppTheme.textSecondary)

                Text(viewModel.formattedNetWorth)
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .gradientForeground(
                        LinearGradient(
                            colors: [AppTheme.accent, AppTheme.secondaryAccent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: AppTheme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            // Breakdown
            HStack(spacing: 0) {
                // Assets
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.income)

                        Text("Assets")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                    }

                    Text(viewModel.formattedTotalAssets)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                }
                .frame(maxWidth: .infinity)

                // Divider
                Rectangle()
                    .fill(AppTheme.textTertiary.opacity(0.2))
                    .frame(width: 1, height: 32)

                // Liabilities
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.expense)

                        Text("Liabilities")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                    }

                    Text(viewModel.formattedTotalLiabilities)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [
                        AppTheme.cardBackground,
                        AppTheme.secondaryBackground
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Accent glow
                LinearGradient(
                    colors: [
                        AppTheme.accent.opacity(0.1),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        .shadow(color: AppTheme.accent.opacity(0.15), radius: 15, x: 0, y: 5)
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
        .padding(16)
        .background(
            ZStack {
                AppTheme.cardGradient

                // Subtle glow
                LinearGradient(
                    colors: [AppTheme.expense.opacity(0.05), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.glassGradient, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
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
                // Budget Alerts (non-swipeable)
                ForEach(viewModel.budgetAlerts) { alert in
                    AttentionItemRow(
                        icon: alert.icon,
                        title: alert.budget.category?.name ?? "Budget",
                        subtitle: alert.message,
                        color: alert.color
                    )
                }

                // Pending Approvals (swipeable - must be in List)
                if !viewModel.pendingRecurringTransactions.isEmpty {
                    List {
                        ForEach(viewModel.pendingRecurringTransactions, id: \.objectID) { pending in
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue)
                                    .frame(width: 28, height: 28)
                                    .background(Color.blue.opacity(0.15))
                                    .cornerRadius(6)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Approve: \(pending.displayTitle)")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(AppTheme.textPrimary)

                                    Text(pending.formattedScheduledDate)
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.textSecondary)
                                }

                                Spacer()

                                // Swipe hint
                                HStack(spacing: 2) {
                                    Image(systemName: "chevron.left")
                                    Image(systemName: "chevron.left")
                                }
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(AppTheme.textTertiary.opacity(0.5))
                            }
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            .listRowSeparator(.hidden)
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
                    .listStyle(.plain)
                    .frame(height: CGFloat(viewModel.pendingRecurringTransactions.count) * 50)
                    .scrollDisabled(true)
                    .environment(\.defaultMinListRowHeight, 0)
                }
            }
        }
        .padding(16)
        .background(
            ZStack {
                AppTheme.cardGradient
                LinearGradient(
                    colors: [Color.orange.opacity(0.05), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.glassGradient, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
    }

    // MARK: - Pending Claims

    private var claimsSection: some View {
        ClaimsWidget(
            pendingClaims: viewModel.pendingClaims,
            onTap: { showingClaimsList = true }
        )
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
        .padding(16)
        .background(
            ZStack {
                AppTheme.cardGradient
                LinearGradient(
                    colors: [AppTheme.accent.opacity(0.05), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.glassGradient, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
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
        .padding(16)
        .background(
            ZStack {
                AppTheme.cardGradient
                LinearGradient(
                    colors: [AppTheme.income.opacity(0.05), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.glassGradient, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
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
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)

            Text(amount)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(color)
                .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            ZStack {
                AppTheme.secondaryBackground

                // Color accent
                LinearGradient(
                    colors: [color.opacity(0.08), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
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
