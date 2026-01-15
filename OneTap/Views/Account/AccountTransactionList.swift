//
//  AccountTransactionList.swift
//  OneTap
//
//  Created by Jimmy Hew on 30/12/2025.
//

import SwiftUI
@preconcurrency internal import CoreData

struct AccountTransactionList: View {
    let account: Account
    @EnvironmentObject private var container: DependencyContainer
    @State private var viewModel: AccountTransactionListViewModel?
    @State private var showingAddTransaction = false

    var body: some View {
        Group {
            if let viewModel = viewModel {
                TransactionListContent(
                    viewModel: viewModel,
                    showingAddTransaction: $showingAddTransaction
                )
            } else {
                VStack {
                    ProgressView()
                    Text("Initializing list...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = container.makeAccountTransactionListViewModel(account: account)
            }
        }
        .sheet(isPresented: $showingAddTransaction) {
            AddTransactionView()
        }
    }
}

// MARK: - Content View with ObservedObject

private struct TransactionListContent: View {
    @ObservedObject var viewModel: AccountTransactionListViewModel
    @Binding var showingAddTransaction: Bool

    var body: some View {
        VStack(spacing: 0) {
            // DEBUG: State Info (Hidden in production, useful now)
            // Text("State: \(viewModel.loadingState == .loading ? "Loading" : "Loaded") Items: \(viewModel.sections.count)")
            //    .font(.caption2)
            //    .foregroundColor(.gray)

            if viewModel.sections.isEmpty {
                if viewModel.loadingState.isLoading {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("Loading transactions...")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding(30)
                } else {
                    // Empty state
                    EmptyTransactionsView(showingAddTransaction: $showingAddTransaction)
                }
            } else {
                ForEach(viewModel.sections, id: \.self) { sectionKey in
                    // Section Header
                    HStack {
                        Text(sectionKey)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(AppTheme.textSecondary)
                            .textCase(.uppercase)

                        Spacer()

                        Text(viewModel.calculateSectionTotal(for: sectionKey))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textTertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AppTheme.secondaryBackground.opacity(0.3))

                    if let transactions = viewModel.sectionedTransactions[sectionKey] {
                        ForEach(transactions, id: \.objectID) { transaction in
                            VStack(spacing: 0) {
                                NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                                    AccountTransactionRow(transaction: transaction)
                                }
                                .buttonStyle(.plain)

                                // Show divider only if it's not the last item in the section
                                if transaction != transactions.last {
                                    Divider()
                                        .background(Color.white.opacity(0.05))
                                        .padding(.leading, 68)
                                }
                            }
                        }
                    }
                }
            }
        }
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - Empty State

private struct EmptyTransactionsView: View {
    @Binding var showingAddTransaction: Bool

    var body: some View {
        VStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(AppTheme.secondaryBackground)
                    .frame(width: 80, height: 80)

                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 36))
                    .foregroundColor(AppTheme.textTertiary)
            }

            // Message
            VStack(spacing: 8) {
                Text("No Transactions Yet")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)

                Text("Get started by adding your first transaction")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Action Button
            Button {
                showingAddTransaction = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))

                    Text("Add Transaction")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(AppTheme.accent)
                .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 40)
    }
}
