//
//  AccountTransactionList.swift
//  OneTap
//
//  Created by Jimmy Hew on 30/12/2025.
//

import SwiftUI
internal import CoreData

struct AccountTransactionList: View {
    let account: Account
    @EnvironmentObject private var container: DependencyContainer
    @State private var viewModel: AccountTransactionListViewModel?

    var body: some View {
        Group {
            if let viewModel = viewModel {
                VStack(spacing: 0) {
                    if viewModel.sections.isEmpty {
                        if viewModel.loadingState.isLoading {
                            ProgressView()
                                .padding(30)
                        } else {
                            // Empty state or filtered out
                            Text("No transactions")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.textSecondary)
                                .padding(20)
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
                                ForEach(transactions) { transaction in
                                    VStack(spacing: 0) {
                                        NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                                            TransactionRow(transaction: transaction)
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
            } else {
                ProgressView()
                    .onAppear {
                        if viewModel == nil {
                            viewModel = container.makeAccountTransactionListViewModel(account: account)
                        }
                    }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = container.makeAccountTransactionListViewModel(account: account)
            }
        }
    }
}