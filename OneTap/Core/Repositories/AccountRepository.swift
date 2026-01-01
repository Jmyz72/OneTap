//
//  AccountRepository.swift
//  OneTap
//
//  Repository for Account entity CRUD and queries
//

import Foundation
import CoreData
import Combine

class AccountRepository: BaseRepository {
    typealias Entity = Account

    let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - Publishers

    func accountsPublisher() -> AnyPublisher<[Account], Error> {
        let subject = PassthroughSubject<[Account], Error>()

        // Observe Core Data changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: context)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let accounts = self.fetchAccounts(group: nil)
                subject.send(accounts)
            }
            .store(in: &cancellables)

        // Send initial value
        let accounts = fetchAccounts(group: nil)
        subject.send(accounts)

        return subject.eraseToAnyPublisher()
    }

    func accountPublisher(for id: NSManagedObjectID) -> AnyPublisher<Account, Error> {
        let subject = PassthroughSubject<Account, Error>()

        // Observe Core Data changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: context)
            .sink { [weak self] _ in
                guard let self = self,
                      let account = self.findByID(id) else { return }
                subject.send(account)
            }
            .store(in: &cancellables)

        // Send initial value
        if let account = findByID(id) {
            subject.send(account)
        }

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

    func deleteAccount(_ account: Account) throws {
        // Core Data cascade rules will handle transaction deletion
        context.delete(account)
    }

    // MARK: - Queries

    func fetchAccounts(group: AccountGroup?) -> [Account] {
        let request = NSFetchRequest<Account>(entityName: "Account")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Account.name, ascending: true)]

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
