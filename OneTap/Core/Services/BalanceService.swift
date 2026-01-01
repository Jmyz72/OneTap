//
//  BalanceService.swift
//  OneTap
//
//  Service for account balance calculation and recalculation
//  Extracted from PersistenceController for better separation of concerns
//

import Foundation
import CoreData

protocol BalanceServiceProtocol {
    func recalculateBalances(for accountID: NSManagedObjectID, from date: Date?) async throws
    func recalculateBalances(for accounts: [NSManagedObjectID], from date: Date?) async throws
}

class BalanceService: BalanceServiceProtocol {
    private let container: NSPersistentContainer

    init(container: NSPersistentContainer) {
        self.container = container
    }

    // MARK: - Public API

    /// Recalculate balances for a single account
    /// - Parameters:
    ///   - accountID: The NSManagedObjectID of the account
    ///   - date: Optional starting date for optimization. If nil, recalculates all transactions
    func recalculateBalances(for accountID: NSManagedObjectID, from date: Date?) async throws {
        try await withCheckedThrowingContinuation { continuation in
            container.performBackgroundTask { context in
                do {
                    try self.performRecalculation(for: accountID, from: date, in: context)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Recalculate balances for multiple accounts
    /// - Parameters:
    ///   - accounts: Array of NSManagedObjectIDs for accounts
    ///   - date: Optional starting date for optimization
    func recalculateBalances(for accounts: [NSManagedObjectID], from date: Date?) async throws {
        try await withCheckedThrowingContinuation { continuation in
            container.performBackgroundTask { context in
                do {
                    for accountID in accounts {
                        try self.performRecalculation(for: accountID, from: date, in: context)
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Private Implementation

    /// Core balance recalculation logic
    /// Optimized: Runs on background thread to prevent UI freezing
    private func performRecalculation(
        for accountID: NSManagedObjectID,
        from date: Date?,
        in context: NSManagedObjectContext
    ) throws {
        guard let account = try? context.existingObject(with: accountID) as? Account else {
            throw ServiceError.entityNotFound
        }

        let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Transaction.date, ascending: true)]

        var startingBalance: Double = 0.0

        // OPTIMIZATION: If a date is provided, find the starting state from the previous transaction
        if let fromDate = date {
            let previousRequest: NSFetchRequest<Transaction> = Transaction.fetchRequest()
            previousRequest.predicate = NSPredicate(format: "account == %@ AND date < %@", account, fromDate as NSDate)
            previousRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Transaction.date, ascending: false)]
            previousRequest.fetchLimit = 1

            do {
                if let lastTransaction = try context.fetch(previousRequest).first {
                    startingBalance = lastTransaction.balanceAfter
                }
                // If no previous transaction, startingBalance remains 0.0

                // Only fetch transactions to update from this date onwards
                request.predicate = NSPredicate(format: "account == %@ AND date >= %@", account, fromDate as NSDate)
            } catch {
                throw ServiceError.operationFailed("Error fetching previous transaction: \(error.localizedDescription)")
            }
        } else {
            // No date provided, recalculate everything
            request.predicate = NSPredicate(format: "account == %@", account)
        }

        do {
            let transactions = try context.fetch(request)
            var runningBalance = startingBalance

            for transaction in transactions {
                runningBalance = applyTransaction(transaction, to: runningBalance)

                if transaction.balanceAfter != runningBalance {
                    transaction.balanceAfter = runningBalance
                }
            }

            if account.balance != runningBalance {
                account.balance = runningBalance
            }

            if context.hasChanges {
                try context.save()
            }

        } catch {
            throw ServiceError.balanceCalculationFailed
        }
    }

    /// Apply transaction to running balance based on transaction type
    /// - Parameters:
    ///   - transaction: The transaction to apply
    ///   - balance: Current running balance
    /// - Returns: Updated balance after applying transaction
    private func applyTransaction(_ transaction: Transaction, to balance: Double) -> Double {
        let amount = transaction.amount
        let type = transaction.typeEnum

        switch type {
        case .expense:
            // Expense decreases balance
            return balance - amount

        case .income:
            // Income increases balance
            return balance + amount

        case .adjustment:
            // Adjustment sets exact balance
            return amount

        case .transfer:
            // In our model, a Transfer transaction on this account means money leaving.
            // The incoming side is created as a separate 'Income' transaction on the other account.
            return balance - amount
        }
    }
}
