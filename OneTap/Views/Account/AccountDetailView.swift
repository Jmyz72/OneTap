//
//  AccountDetailView.swift
//  OneTap
//
//  REFACTORED: Clean, modern account detail view with MVVM pattern
//

import SwiftUI
internal import CoreData

struct AccountDetailView: View {
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.dismiss) var dismiss

    let account: Account
    @State private var viewModel: AccountDetailViewModel?

    // UI State (view-only state)
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false

    var body: some View {
        Group {
            if let viewModel {
                ZStack {
                    AppTheme.background.ignoresSafeArea()

                    ScrollView {
                        VStack(spacing: 24) {
                            // Account Header
                            accountHeaderCard

                            // Quick Actions
                            quickActionsCard

                            // Transaction History
                            transactionHistorySection
                        }
                        .padding(16)
                        .padding(.top, 8)
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
                .onChange(of: viewModel.loadingState) { _, newState in
                    if newState == .loaded {
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

    // MARK: - Account Header

    private var accountHeaderCard: some View {
        VStack(spacing: 24) {
            // Icon & Type
            VStack(spacing: 12) {
                AccountIconView(
                    iconName: account.icon ?? "creditcard.fill",
                    color: accountColor,
                    size: 36
                )

                Text(account.typeEnum.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(AppTheme.secondaryBackground)
                    .cornerRadius(12)
            }

            // Balance
            VStack(spacing: 8) {
                Text("Current Balance")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)

                Text(viewModel?.formatCurrency(account.balance) ?? "")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(balanceColor)

                if account.isLiability {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))

                        Text("Liability Account")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(AppTheme.expense)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(AppTheme.expense.opacity(0.1))
                    .cornerRadius(10)
                }
            }

            // Account Details
            if account.currency != nil || account.lastFourDigits != nil {
                Divider()
                    .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    if let currency = account.currency {
                        DetailRow(label: "Currency", value: currency)
                    }

                    if let last4 = account.lastFourDigits, !last4.isEmpty {
                        DetailRow(label: "Last 4 Digits", value: "•••• \(last4)")
                    }

                    if account.billingDay > 0 {
                        DetailRow(label: "Billing Day", value: "Day \(account.billingDay)")
                    }

                    if account.dueDay > 0 {
                        DetailRow(label: "Payment Due", value: "Day \(account.dueDay)")
                    }
                }
            }
        }
        .padding(28)
        .background(AppTheme.cardBackground)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 8)
    }

    // MARK: - Quick Actions

    private var quickActionsCard: some View {
        HStack(spacing: 12) {
            QuickActionButton(
                icon: "plus.circle.fill",
                title: "Add",
                color: AppTheme.income
            ) {
                // TODO: Add transaction
            }

            QuickActionButton(
                icon: "arrow.left.arrow.right.circle.fill",
                title: "Transfer",
                color: AppTheme.accent
            ) {
                // TODO: Transfer
            }

            QuickActionButton(
                icon: "chart.bar.fill",
                title: "Stats",
                color: AppTheme.secondaryAccent
            ) {
                // TODO: Show stats
            }
        }
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

// MARK: - Quick Action Button

private struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(AppTheme.cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
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
