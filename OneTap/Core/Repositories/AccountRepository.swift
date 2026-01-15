//
//  AccountRepository.swift
//  OneTap
//
//  Repository for Account entity CRUD and queries
//

import Foundation
@preconcurrency internal import CoreData
import Combine

class AccountRepository: BaseRepository {
    typealias Entity = Account

    let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    deinit {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    // MARK: - Publishers

    func accountsPublisher() -> AnyPublisher<[Account], Error> {
        let initialAccounts = fetchAccounts(group: nil)
        let subject = CurrentValueSubject<[Account], Error>(initialAccounts)

        // Observe Core Data saves from any context
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] notification in
                guard let self = self else { return }

                // Accept saves from any context with same persistent store
                guard let savedContext = notification.object as? NSManagedObjectContext,
                      savedContext.persistentStoreCoordinator === self.context.persistentStoreCoordinator else {
                    return
                }

                // Check if Account was changed
                let inserted = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
                let updated = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? []
                let deleted = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? []

                let hasAccountChanges = (inserted.union(updated).union(deleted))
                    .contains { $0 is Account }

                guard hasAccountChanges else { return }

                self.context.perform {
                    let accounts = self.fetchAccounts(group: nil)
                    subject.send(accounts)
                }
            }
            .store(in: &cancellables)

        return subject.eraseToAnyPublisher()
    }

    func accountPublisher(for id: NSManagedObjectID) -> AnyPublisher<Account?, Error> {
        let initialAccount = findByID(id)
        let subject = CurrentValueSubject<Account?, Error>(initialAccount)

        // Observe Core Data saves from any context
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] notification in
                guard let self = self else { return }

                // Accept saves from any context with same persistent store
                guard let savedContext = notification.object as? NSManagedObjectContext,
                      savedContext.persistentStoreCoordinator === self.context.persistentStoreCoordinator else {
                    return
                }

                // Check if Account was changed
                let inserted = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
                let updated = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? []
                let deleted = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? []

                let hasAccountChanges = (inserted.union(updated).union(deleted))
                    .contains { $0 is Account }

                guard hasAccountChanges else { return }

                let account = self.findByID(id)
                subject.send(account)
            }
            .store(in: &cancellables)

        return subject.eraseToAnyPublisher()
    }

    // MARK: - CRUD Operations

    func createAccount(
        name: String,
        type: AccountType,
        currency: String,
        icon: String,
        initialBalance: Double
    ) throws -> Account {
        let account = Account(context: context)
        account.id = UUID()
        account.name = name
        account.type = type.rawValue
        account.balance = initialBalance
        account.currency = currency
        account.icon = icon
        account.createdAt = Date()

        return account
    }

    func updateAccount(_ account: Account, with data: AccountUpdateData) throws {
        if let name = data.name {
            account.name = name
        }
        if let institution = data.institution {
            account.institution = institution
        }
        if let type = data.type {
            account.type = type.rawValue
            // Update icon if type changed and icon wasn't manually set
            if account.icon == nil || account.icon == AccountType(rawValue: account.type ?? "")?.icon {
                account.icon = type.icon
            }
        }
        if let currency = data.currency {
            account.currency = currency
        }
        if let creditLimit = data.creditLimit {
            account.creditLimit = creditLimit
        }
        if let icon = data.icon {
            account.icon = icon
        }
        if let billingDay = data.billingDay {
            account.billingDate = Int16(billingDay)
        }
        if let dueDay = data.dueDay {
            account.dueDate = Int16(dueDay)
        }
        if let lastFourDigits = data.lastFourDigits {
            account.lastFourDigits = lastFourDigits
        }
    }

    /// Archives an account (soft delete - preserves transactions)
    func archiveAccount(_ account: Account) throws {
        account.isArchived = true
        // Note: Transactions are preserved
    }

    /// Unarchives an account (restores from archive)
    func unarchiveAccount(_ account: Account) throws {
        account.isArchived = false
    }

    /// Permanently deletes an account (WARNING: Cannot be undone)
    /// CRITICAL: This will orphan all transactions (deletionRule changed to Nullify)
    func deleteAccount(_ account: Account) throws {
        let transactionCount = account.transactions?.count ?? 0

        // Warn if account has transactions
        if transactionCount > 0 {
            throw ServiceError.validationFailed(
                "This account has \(transactionCount) transactions. " +
                "Deleting it will orphan all transaction history. " +
                "Consider archiving instead to preserve history."
            )
        }

        // Proceed with deletion if no transactions
        context.delete(account)
    }

    // MARK: - Queries

    func fetchAccounts(group: AccountGroup?, includeArchived: Bool = false) -> [Account] {
        let request = NSFetchRequest<Account>(entityName: "Account")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Account.name, ascending: true)]

        // CRITICAL: Filter out archived accounts by default
        if !includeArchived {
            request.predicate = NSPredicate(format: "isArchived == NO")
        }

        do {
            let accounts = try context.fetch(request)

            if let group = group {
                return accounts.filter { $0.group == group }
            }

            return accounts
        } catch {
            print("Error fetching accounts: \(error)")
            return []
        }
    }

    func fetchAccounts(predicate: NSPredicate?) -> [Account] {
        let request = NSFetchRequest<Account>(entityName: "Account")
        request.predicate = predicate
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Account.name, ascending: true)]

        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching accounts: \(error)")
            return []
        }
    }

    // MARK: - Calculations

    func calculateNetWorth() -> Double {
        calculateTotalAssets() - calculateTotalLiabilities()
    }

    func calculateTotalAssets() -> Double {
        let accounts = fetchAccounts(group: nil)
        return accounts
            .filter { !$0.isLiability }
            .reduce(0) { $0 + $1.balance }
    }

    func calculateTotalLiabilities() -> Double {
        let accounts = fetchAccounts(group: nil)
        return accounts
            .filter { $0.isLiability }
            .reduce(0) { $0 + abs($1.balance) }
    }
}
