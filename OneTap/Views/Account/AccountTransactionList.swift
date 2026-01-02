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
                    ForEach(viewModel.transactions) { transaction in
                        VStack(spacing: 0) {
                            NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                                TransactionRow(transaction: transaction)
                            }
                            .buttonStyle(.plain)
                            
                            if transaction != viewModel.transactions.last {
                                Divider()
                                    .background(Color.white.opacity(0.05))
                                    .padding(.leading, 68)
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
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = container.makeAccountTransactionListViewModel(account: account)
            }
        }
    }
}