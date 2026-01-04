//
//  HomeView.swift
//  OneTap
//
//  Main dashboard/home view
//

import SwiftUI
internal import CoreData

struct HomeView: View {
    @EnvironmentObject private var container: DependencyContainer
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Account.name, ascending: true)],
        animation: .default
    )
    private var accounts: FetchedResults<Account>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Transaction.date, ascending: false)],
        animation: .default
    )
    private var recentTransactions: FetchedResults<Transaction>

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Total Balance Card
                        totalBalanceCard

                        // Quick Stats
                        quickStatsSection

                        // Account Summary
                        accountSummarySection

                        // Recent Transactions
                        recentTransactionsSection
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ProfileButton()
                }
            }
        }
    }

    // MARK: - Total Balance Card

    private var totalBalanceCard: some View {
        VStack(spacing: 16) {
            Text("Total Balance")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)

            Text(formatTotalBalance())
                .font(.system(size: 42, weight: .black, design: .rounded))
                .gradientForeground(AppTheme.blueGradient)
                .shadow(color: AppTheme.accent.opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            ZStack {
                AppTheme.cardGradient

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
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 16, x: 0, y: 8)
        .padding(.horizontal, 20)
    }

    // MARK: - Quick Stats

    private var quickStatsSection: some View {
        HStack(spacing: 12) {
            // Income this month
            StatCard(
                title: "Income",
                value: "$0.00",
                icon: "arrow.down.circle.fill",
                color: AppTheme.income
            )

            // Expenses this month
            StatCard(
                title: "Expenses",
                value: "$0.00",
                icon: "arrow.up.circle.fill",
                color: AppTheme.expense
            )
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Account Summary

    private var accountSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Accounts")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                NavigationLink(destination: AccountListView()) {
                    Text("See All")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.accent)
                }
            }
            .padding(.horizontal, 20)

            if accounts.isEmpty {
                ContentUnavailableView(
                    "No Accounts",
                    systemImage: "building.columns",
                    description: Text("Add an account to get started")
                )
                .frame(height: 150)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(accounts.prefix(5)) { account in
                            AccountMiniCard(account: account)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    // MARK: - Recent Transactions

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Transactions")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                NavigationLink(destination: TransactionListView()) {
                    Text("See All")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.accent)
                }
            }
            .padding(.horizontal, 20)

            if recentTransactions.isEmpty {
                ContentUnavailableView(
                    "No Transactions",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Your transactions will appear here")
                )
                .frame(height: 150)
            } else {
                VStack(spacing: 12) {
                    ForEach(recentTransactions.prefix(5)) { transaction in
                        NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                            TransactionRow(transaction: transaction)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Helpers

    private func formatTotalBalance() -> String {
        let total = accounts.reduce(0.0) { sum, account in
            if account.isLiability {
                return sum - account.balance
            } else {
                return sum + account.balance
            }
        }

        let formatter = Formatters.currencyFormatter(for: SettingsManager.shared.currencyCode)
        return formatter.string(from: NSNumber(value: total)) ?? "$0.00"
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Account Mini Card

private struct AccountMiniCard: View {
    let account: Account

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: account.icon ?? "questionmark.circle")
                    .font(.system(size: 20))
                    .foregroundColor(AppTheme.accent)

                Spacer()
            }

            Text(account.name ?? "Account")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)

            Text(account.formattedBalance)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(account.isLiability ? AppTheme.expense : AppTheme.income)
        }
        .frame(width: 140)
        .padding(16)
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
    }
}

#Preview {
    HomeView()
        .environmentObject(DependencyContainer(persistenceController: .preview))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
