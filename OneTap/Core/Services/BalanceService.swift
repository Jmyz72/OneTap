//
//  BalanceService.swift
//  OneTap
//
//  Service for account balance calculation and recalculation
//  Extracted from PersistenceController for better separation of concerns
//

import Foundation
@preconcurrency internal import CoreData

protocol BalanceServiceProtocol {
    func recalculateBalances(for accountID: NSManagedObjectID, from date: Date?) async throws
    func recalculateBalances(for accounts: [NSManagedObjectID], from date: Date?) async throws
}

class BalanceService: BalanceServiceProtocol {
    private let container: NSPersistentContainer

    // Thread-safe locking mechanism to prevent concurrent balance recalculations for the same account
    private var accountLocks: [NSManagedObjectID: DispatchSemaphore] = [:]
    private let locksQueue = DispatchQueue(label: "com.onetap.balanceservice.locks", attributes: .concurrent)

    init(container: NSPersistentContainer) {
        self.container = container
    }

    // MARK: - Public API

    /// Recalculate balances for a single account
    /// - Parameters:
    ///   - accountID: The NSManagedObjectID of the account
    ///   - date: Optional starting date for optimization. If nil, recalculates all transactions
    func recalculateBalances(for accountID: NSManagedObjectID, from date: Date?) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            container.performBackgroundTask { [weak self] context in
                guard let self = self else {
                    continuation.resume(throwing: ServiceError.operationFailed("Service deallocated"))
                    return
                }

                // Acquire lock for this account to prevent concurrent recalculations
                let semaphore = self.getSemaphore(for: accountID)
                semaphore.wait()
                defer { semaphore.signal() }

                do {
                    try self.performRecalculation(for: accountID, from: date, in: context)
                    continuation.resume(returning: ())
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
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            container.performBackgroundTask { [weak self] context in
                guard let self = self else {
                    continuation.resume(throwing: ServiceError.operationFailed("Service deallocated"))
                    return
                }

                do {
                    for accountID in accounts {
                        try self.performRecalculation(for: accountID, from: date, in: context)
                    }
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Private Implementation

    /// Thread-safe method to get or create a semaphore for an account
    /// - Parameter accountID: The account's managed object ID
    /// - Returns: DispatchSemaphore for the specified account
    private func getSemaphore(for accountID: NSManagedObjectID) -> DispatchSemaphore {
        return locksQueue.sync(flags: .barrier) { () -> DispatchSemaphore in
            if let existingSemaphore = accountLocks[accountID] {
                return existingSemaphore
            }
            let newSemaphore = DispatchSemaphore(value: 1)
            accountLocks[accountID] = newSemaphore
            return newSemaphore
        }
    }

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

        var startingBalance: Double

        // OPTIMIZATION: If a date is provided, find the starting state from the previous transaction
        if let fromDate = date {
            let previousRequest: NSFetchRequest<Transaction> = Transaction.fetchRequest()
            previousRequest.predicate = NSPredicate(format: "account == %@ AND date < %@", account, fromDate as NSDate)
            previousRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Transaction.date, ascending: false)]
            previousRequest.fetchLimit = 1

            do {
                if let lastTransaction = try context.fetch(previousRequest).first {
                    // Use the balance after the last transaction before this date
                    startingBalance = lastTransaction.balanceAfter
                } else {
                    // No previous transaction - check if account has any transactions at all
                    let anyTransactionRequest: NSFetchRequest<Transaction> = Transaction.fetchRequest()
                    anyTransactionRequest.predicate = NSPredicate(format: "account == %@", account)
                    anyTransactionRequest.fetchLimit = 1

                    if try context.fetch(anyTransactionRequest).isEmpty {
                        // No transactions at all - use account's current balance as opening balance
                        startingBalance = account.balance
                    } else {
                        // Transactions exist but all are after fromDate - start from 0.00
                        // The first transaction (by date) should be an opening balance adjustment that sets the correct balance
                        startingBalance = 0.0
                    }
                }

                // Only fetch transactions to update from this date onwards
                request.predicate = NSPredicate(format: "account == %@ AND date >= %@", account, fromDate as NSDate)
            } catch {
                throw ServiceError.operationFailed("Error fetching previous transaction: \(error.localizedDescription)")
            }
        } else {
            // No date provided, recalculate everything from scratch
            // Start from 0.00 - the first transaction (opening balance adjustment) will set the correct balance
            startingBalance = 0.0
            request.predicate = NSPredicate(format: "account == %@", account)
        }

        do {
            let transactions = try context.fetch(request)

            // If there are no transactions from this date onwards, update account to starting balance
            if transactions.isEmpty {
                // Update account balance to starting balance (e.g., after deleting the last transaction)
                if account.balance != startingBalance {
                    account.balance = startingBalance
                }
                if context.hasChanges {
                    try context.save()
                }
                return
            }

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
            // Transfer transactions can be either outgoing or incoming
            // Check the title to determine direction:
            // "Transfer to X" = outgoing (decreases balance)
            // "Transfer from X" = incoming (increases balance)
            if let title = transaction.title, title.hasPrefix("Transfer from") {
                // Incoming transfer - increases balance
                return balance + amount
            } else {
                // Outgoing transfer - decreases balance
                return balance - amount
            }
        }
    }
}
