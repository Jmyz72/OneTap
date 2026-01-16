//
//  TransactionDetailViewModel.swift
//  OneTap
//
//  ViewModel for transaction detail view
//  Replaces logic from TransactionDetailView.swift (lines 166-219)
//

import Foundation
import SwiftUI
@preconcurrency internal import CoreData
import Combine

@MainActor
class TransactionDetailViewModel: ObservableObject, ViewModelProtocol {
    // MARK: - Published State
    @Published var loadingState: LoadingState = .idle
    @Published var errorMessage: String?
    @Published var shouldDismiss = false

    // MARK: - Dependencies
    private let transaction: Transaction
    private let transactionRepository: TransactionRepository
    private let balanceService: BalanceService

    init(
        transaction: Transaction,
        transactionRepository: TransactionRepository,
        balanceService: BalanceService
    ) {
        self.transaction = transaction
        self.transactionRepository = transactionRepository
        self.balanceService = balanceService
    }

    // MARK: - Computed Properties

    var amountColor: Color {
        switch transaction.typeEnum {
        case .expense:
            return AppTheme.expense
        case .income:
            return AppTheme.income
        case .transfer:
            return AppTheme.textPrimary
        case .adjustment:
            return AppTheme.textSecondary
        }
    }

    // MARK: - Actions

    func deleteTransaction() async {
        startLoading()

        do {
            let currentAccount = transaction.account
            let transactionDate = transaction.date
            var relatedAccount: Account? = nil

            // Handle linked transaction (transfers)
            if let relatedID = transaction.relatedTransactionID,
               let linkedTransaction = transactionRepository.fetchRelatedTransaction(for: relatedID) {
                relatedAccount = linkedTransaction.account
                try transactionRepository.deleteTransaction(linkedTransaction, cascade: false)
            }

            // Delete main transaction (cascade deletes split items)
            try transactionRepository.deleteTransaction(transaction, cascade: true)
            try transactionRepository.save()

            // Dismiss immediately after delete to avoid rendering deleted object
            shouldDismiss = true

            // Recalculate balances (view will dismiss while this runs)
            var accountsToRecalculate: [NSManagedObjectID] = []
            if let account = currentAccount {
                accountsToRecalculate.append(account.objectID)
            }
            if let account = relatedAccount, account != currentAccount {
                accountsToRecalculate.append(account.objectID)
            }

            try await balanceService.recalculateBalances(for: accountsToRecalculate, from: transactionDate)

            // Finish loading after everything completes
            finishLoading()

        } catch {
            handleError(error)
        }
    }
}
