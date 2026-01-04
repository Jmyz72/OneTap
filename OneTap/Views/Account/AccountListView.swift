//
//  AccountListView.swift
//  OneTap
//
//  REFACTORED: Clean, modern design with MVVM pattern
//

import SwiftUI
internal import CoreData

struct AccountListView: View {
    @EnvironmentObject private var container: DependencyContainer
    @State private var viewModel: AccountListViewModel?

    var body: some View {
        Group {
            if let viewModel {
                AccountListContent(viewModel: viewModel)
            } else {
                ProgressView()
                    .onAppear {
                        if viewModel == nil {
                            viewModel = container.makeAccountListViewModel()
                        }
                    }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = container.makeAccountListViewModel()
            }
        }
    }
}

private struct AccountListContent: View {
    @ObservedObject var viewModel: AccountListViewModel
    @ObservedObject var settings = SettingsManager.shared

    // UI State (view-only state)
    @State private var showingAddAccount = false
    @State private var accountToEdit: Account?

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Net Worth Overview
                    netWorthCard

                    // Accounts List
                    if viewModel.accounts.isEmpty {
                        emptyStateView
                            .padding(.top, 40)
                    } else {
                        accountsSection
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 16)
            }
        }
        .navigationTitle("Accounts")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        showingAddAccount = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(AppTheme.accent)
                    }

                    ProfileButton()
                }
            }
        }
        .toolbarBackground(AppTheme.backgroundSolid, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showingAddAccount) {
            AddAccountView(isPresented: $showingAddAccount)
        }
        .sheet(item: $accountToEdit) { account in
            NavigationStack {
                AccountFormView(accountToEdit: account)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                accountToEdit = nil
                            }
                        }
                    }
            }
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
        .preferredColorScheme(.dark)
    }

    // MARK: - Net Worth Card

    private var netWorthCard: some View {
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

    // MARK: - Accounts Section

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(AccountGroup.allCases) { group in
                if let groupAccounts = viewModel.groupedAccounts[group], !groupAccounts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        // Group Header
                        HStack {
                            Text(group.rawValue)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppTheme.textSecondary)
                                .textCase(.uppercase)

                            Spacer()

                            Text("\(groupAccounts.count)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(AppTheme.textTertiary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppTheme.secondaryBackground)
                                .cornerRadius(6)
                        }
                        .padding(.horizontal, 4)

                        // Group Accounts
                        ForEach(groupAccounts) { account in
                            NavigationLink(destination: AccountDetailView(account: account)) {
                                AccountRow(account: account)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    accountToEdit = account
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.deleteAccount(account)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(AppTheme.secondaryBackground)
                    .frame(width: 100, height: 100)

                Image(systemName: "building.columns")
                    .font(.system(size: 44))
                    .foregroundColor(AppTheme.textTertiary)
            }

            VStack(spacing: 12) {
                Text("No Accounts Yet")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)

                Text("Add your first account to start tracking your finances")
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button {
                showingAddAccount = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Account")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(AppTheme.accent)
                .cornerRadius(14)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
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

#Preview {
    NavigationStack {
        AccountListView()
            .environmentObject(DependencyContainer(persistenceController: .preview))
    }
}
