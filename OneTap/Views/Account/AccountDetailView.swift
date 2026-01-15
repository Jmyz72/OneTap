//
//  AccountDetailView.swift
//  OneTap
//
//  REFACTORED: Clean, modern account detail view with MVVM pattern
//

import SwiftUI
@preconcurrency internal import CoreData

struct AccountDetailView: View {
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.dismiss) var dismiss

    @ObservedObject var account: Account
    @State private var viewModel: AccountDetailViewModel?

    // UI State (view-only state)
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingGoalSheet = false

    var body: some View {
        Group {
            if let viewModel {
                ZStack {
                    AppTheme.background.ignoresSafeArea()

                    ScrollView {
                        VStack(spacing: 16) {
                            // Account Header (includes quick actions)
                            accountHeaderCard

                            // Transaction History
                            transactionHistorySection
                        }
                        .padding(16)
                    }
                }
                .navigationTitle(account.name ?? "Account")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button {
                                showingEditSheet = true
                            } label: {
                                Label("Edit Account", systemImage: "pencil")
                            }

                            Divider()

                            Button(role: .destructive) {
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete Account", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(AppTheme.textPrimary)
                        }
                    }
                }
                .toolbarBackground(AppTheme.backgroundSolid, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .sheet(isPresented: $showingEditSheet) {
                    NavigationStack {
                        AccountFormView(accountToEdit: account)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Cancel") {
                                        showingEditSheet = false
                                    }
                                }
                            }
                    }
                }
                .sheet(isPresented: $showingGoalSheet) {
                    SavingsGoalSheet(
                        account: account,
                        repository: container.savingsGoalRepository
                    )
                }
                .alert("Delete Account", isPresented: $showingDeleteAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete", role: .destructive) {
                        Task {
                            await viewModel.deleteAccount()
                        }
                    }
                } message: {
                    Text("Are you sure you want to delete this account? This action cannot be undone and all transactions will be removed.")
                }
                .alert("Error", isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )) {
                    Button("OK") {
                        viewModel.errorMessage = nil
                    }
                } message: {
                    if let error = viewModel.errorMessage {
                        Text(error)
                    }
                }
                .overlay {
                    if viewModel.loadingState.isLoading {
                        ZStack {
                            Color.black.opacity(0.4)
                                .ignoresSafeArea()

                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                        }
                    }
                }
                .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
                    if shouldDismiss {
                        dismiss()
                    }
                }
                .preferredColorScheme(.dark)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = container.makeAccountDetailViewModel(account: account)
            }
        }
    }

    // MARK: - Account Header (Compact Combined Card)

    private var accountHeaderCard: some View {
        VStack(spacing: 16) {
            // Top Row: Icon + Name | Balance
            HStack(alignment: .top, spacing: 12) {
                // Left: Icon + Account Info
                HStack(spacing: 12) {
                    AccountIconView(
                        iconName: account.icon ?? "creditcard.fill",
                        color: accountColor,
                        size: 28
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.name ?? "Account")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)

                        HStack(spacing: 6) {
                            Text(account.typeEnum.rawValue)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppTheme.textSecondary)

                            if account.isLiability {
                                Text("•")
                                    .font(.system(size: 10))
                                    .foregroundColor(AppTheme.textTertiary)

                                Text("Liability")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(AppTheme.expense)
                            }
                        }
                    }
                }

                Spacer()

                // Right: Balance
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Balance")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textTertiary)

                    Text(viewModel?.formatCurrency(account.balance) ?? "")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(balanceColor)
                }
            }

            // Quick Actions Row
            HStack(spacing: 8) {
                CompactActionButton(
                    icon: "plus",
                    title: "Add",
                    color: AppTheme.income
                ) {
                    // TODO: Add transaction
                }

                CompactActionButton(
                    icon: account.savingsGoal != nil ? "target" : "scope",
                    title: "Goal",
                    color: goalButtonColor
                ) {
                    showingGoalSheet = true
                }

                CompactActionButton(
                    icon: "chart.bar.fill",
                    title: "Stats",
                    color: AppTheme.secondaryAccent
                ) {
                    // TODO: Show stats
                }
            }

            // Savings Goal Progress (if set)
            if let goal = account.savingsGoal {
                VStack(spacing: 6) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(AppTheme.secondaryBackground)
                                .frame(height: 6)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(goalProgressColor(goal.progress))
                                .frame(width: geometry.size.width * goal.progressClamped, height: 6)
                        }
                    }
                    .frame(height: 6)

                    HStack {
                        Text(goal.name ?? "Goal")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.textTertiary)

                        Spacer()

                        Text(goal.progressSummary)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(goalProgressColor(goal.progress))
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    // MARK: - Quick Actions (kept for compatibility but now using compact version above)

    private var quickActionsCard: some View {
        EmptyView() // No longer used - actions integrated into header
    }

    private var goalButtonColor: Color {
        guard let goal = account.savingsGoal else { return AppTheme.accent }
        if goal.isComplete {
            return AppTheme.income
        } else if goal.progress >= 0.7 {
            return .orange
        }
        return AppTheme.accent
    }

    private func goalProgressColor(_ progress: Double) -> Color {
        if progress >= 1.0 {
            return AppTheme.income
        } else if progress >= 0.7 {
            return .orange
        }
        return AppTheme.accent
    }

    // MARK: - Transaction History

    private var transactionHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Transactions")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                NavigationLink(destination:
                    ScrollView {
                        AccountTransactionList(account: account)
                            .padding()
                    }
                    .background(AppTheme.background.ignoresSafeArea())
                    .navigationTitle(account.name ?? "Transactions")
                    .navigationBarTitleDisplayMode(.inline)
                ) {
                    Text("See All")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.accent)
                }
            }
            .padding(.horizontal, 4)

            AccountTransactionList(account: account)
        }
    }

    // MARK: - Helpers

    private var accountColor: Color {
        return account.typeEnum.color
    }

    private var balanceColor: Color {
        if account.isLiability {
            return AppTheme.expense
        }
        return account.balance >= 0 ? AppTheme.income : AppTheme.expense
    }
}

// MARK: - Detail Row

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
        }
    }
}

// MARK: - Compact Action Button

private struct CompactActionButton: View {
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

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let fetchRequest: NSFetchRequest<Account> = Account.fetchRequest()
    let account = (try? context.fetch(fetchRequest).first) ?? Account(context: context)

    return NavigationStack {
        AccountDetailView(account: account)
            .environmentObject(DependencyContainer(persistenceController: .preview))
    }
}
