//
//  TransferService.swift
//  OneTap
//
//  Service for handling transfer transactions between accounts
//  Manages dual-transaction creation, updates, and deletion atomically
//

import Foundation
internal import CoreData

protocol TransferServiceProtocol {
    func createTransfer(
        amount: Double,
        date: Date,
        from sourceAccount: Account,
        to destinationAccount: Account,
        notes: String?
    ) async throws -> (source: Transaction, destination: Transaction)

    func updateTransfer(
        sourceTransaction: Transaction,
        amount: Double,
        date: Date,
        destinationAccount: Account?
    ) async throws

    func deleteTransfer(sourceTransaction: Transaction) async throws
}

@MainActor
class TransferService: TransferServiceProtocol {
    private let transactionRepository: TransactionRepository
    private let balanceService: BalanceService

    init(transactionRepository: TransactionRepository, balanceService: BalanceService) {
        self.transactionRepository = transactionRepository
        self.balanceService = balanceService
    }

    // MARK: - Create Transfer

    /// Creates a transfer between two accounts with linked transactions
    /// - Parameters:
    ///   - amount: Transfer amount
    ///   - date: Transaction date
    ///   - sourceAccount: Account to transfer from
    ///   - destinationAccount: Account to transfer to
    ///   - notes: Optional notes
    /// - Returns: Tuple of (source transaction, destination transaction)
    func createTransfer(
        amount: Double,
        date: Date,
        from sourceAccount: Account,
        to destinationAccount: Account,
        notes: String?
    ) async throws -> (source: Transaction, destination: Transaction) {
        // Create linked ID for both transactions
        let linkID = UUID()

        // SOURCE TRANSACTION (Transfer type, debits source account)
        let sourceTransaction = try transactionRepository.createTransaction(
            title: "Transfer to \(destinationAccount.name ?? "Account")",
            amount: amount,
            type: .transfer,
            date: date,
            account: sourceAccount,
            category: nil,
            subCategory: nil,
            notes: notes
        )
        sourceTransaction.relatedTransactionID = linkID

        // DESTINATION TRANSACTION (Income type, credits destination account)
        let destTransaction = try transactionRepository.createTransaction(
            title: "Transfer from \(sourceAccount.name ?? "Account")",
            amount: amount,
            type: .income,
            date: date,
            account: destinationAccount,
            category: nil,
            subCategory: nil,
            notes: notes
        )
        destTransaction.relatedTransactionID = linkID

        // Save atomically
        try transactionRepository.save()

        // Recalculate balances on both accounts
        try await balanceService.recalculateBalances(
            for: [sourceAccount.objectID, destinationAccount.objectID],
            from: date
        )

        return (sourceTransaction, destTransaction)
    }

    // MARK: - Update Transfer

    /// Updates a transfer and its linked transaction
    /// - Parameters:
    ///   - sourceTransaction: The source (Transfer type) transaction
    ///   - amount: New amount
    ///   - date: New date
    ///   - destinationAccount: New destination account (if changing)
    func updateTransfer(
        sourceTransaction: Transaction,
        amount: Double,
        date: Date,
        destinationAccount: Account?
    ) async throws {
        guard let relatedID = sourceTransaction.relatedTransactionID,
              let linkedTransaction = transactionRepository.fetchRelatedTransaction(for: relatedID) else {
            throw ServiceError.entityNotFound
        }

        let oldDate = sourceTransaction.date ?? Date()
        let oldSourceAccount = sourceTransaction.account
        let oldDestAccount = linkedTransaction.account

        // Update source transaction
        try transactionRepository.updateTransaction(sourceTransaction, with: TransactionUpdateData(
            title: nil,
            amount: amount,
            date: date,
            type: nil,
            account: nil,
            category: nil,
            subCategory: nil,
            merchant: nil,
            notes: nil
        ))

        // Update linked transaction
        try transactionRepository.updateTransaction(linkedTransaction, with: TransactionUpdateData(
            title: nil,
            amount: amount,
            date: date,
            type: nil,
            account: destinationAccount,
            category: nil,
            subCategory: nil,
            merchant: nil,
            notes: nil
        ))

        // Update titles if destination changed
        if let newDestAccount = destinationAccount {
            sourceTransaction.title = "Transfer to \(newDestAccount.name ?? "Account")"
            if let sourceAccount = oldSourceAccount {
                linkedTransaction.title = "Transfer from \(sourceAccount.name ?? "Account")"
            }
        }

        try transactionRepository.save()

        // Recalculate balances on affected accounts
        let earliestDate = min(oldDate, date)
        var accountsToRecalculate: [NSManagedObjectID] = []

        if let acc = oldSourceAccount {
            accountsToRecalculate.append(acc.objectID)
        }
        if let acc = oldDestAccount, acc != oldSourceAccount {
            accountsToRecalculate.append(acc.objectID)
        }
        if let acc = destinationAccount, acc != oldDestAccount && acc != oldSourceAccount {
            accountsToRecalculate.append(acc.objectID)
        }

        try await balanceService.recalculateBalances(for: accountsToRecalculate, from: earliestDate)
    }

    // MARK: - Delete Transfer

    /// Deletes a transfer and its linked transaction
    /// - Parameter sourceTransaction: The source (Transfer type) transaction
    func deleteTransfer(sourceTransaction: Transaction) async throws {
        guard let relatedID = sourceTransaction.relatedTransactionID,
              let linkedTransaction = transactionRepository.fetchRelatedTransaction(for: relatedID) else {
            throw ServiceError.entityNotFound
        }

        let sourceAccount = sourceTransaction.account
        let destAccount = linkedTransaction.account
        let transactionDate = sourceTransaction.date

        // Delete both transactions
        try transactionRepository.deleteTransaction(linkedTransaction, cascade: false)
        try transactionRepository.deleteTransaction(sourceTransaction, cascade: false)
        try transactionRepository.save()

        // Recalculate balances
        var accountsToRecalculate: [NSManagedObjectID] = []
        if let acc = sourceAccount {
            accountsToRecalculate.append(acc.objectID)
        }
        if let acc = destAccount, acc != sourceAccount {
            accountsToRecalculate.append(acc.objectID)
        }

        try await balanceService.recalculateBalances(for: accountsToRecalculate, from: transactionDate)
    }
}
