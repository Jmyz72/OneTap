//
//  TransactionRepository.swift
//  OneTap
//
//  Repository for Transaction entity CRUD and queries
//

import Foundation
import CoreData
import Combine

class TransactionRepository: BaseRepository {
    typealias Entity = Transaction

    let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - Publishers

    func transactionsPublisher(for accountID: NSManagedObjectID, from date: Date?) -> AnyPublisher<[Transaction], Error> {
        let subject = PassthroughSubject<[Transaction], Error>()

        // Observe Core Data changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: context)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if let account = self.findByID(accountID) as? Account {
                    let transactions = self.fetchTransactions(
                        for: account,
                        from: date,
                        to: nil,
                        sortAscending: false
                    )
                    subject.send(transactions)
                }
            }
            .store(in: &cancellables)

        // Send initial value
        if let account = findByID(accountID) as? Account {
            let transactions = fetchTransactions(for: account, from: date, to: nil, sortAscending: false)
            subject.send(transactions)
        }

        return subject.eraseToAnyPublisher()
    }

    func transactionsByDatePublisher(predicate: NSPredicate?) -> AnyPublisher<[String: [Transaction]], Error> {
        let subject = PassthroughSubject<[String: [Transaction]], Error>()

        // Observe Core Data changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: context)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let transactions = self.fetch(predicate: predicate, sortDescriptors: [
                    NSSortDescriptor(keyPath: \Transaction.date, ascending: false)
                ])
                let grouped = Dictionary(grouping: transactions) { transaction in
                    guard let date = transaction.date else { return "" }
                    return Formatters.date.string(from: date)
                }
                subject.send(grouped)
            }
            .store(in: &cancellables)

        // Send initial value
        let transactions = fetch(predicate: predicate, sortDescriptors: [
            NSSortDescriptor(keyPath: \Transaction.date, ascending: false)
        ])
        let grouped = Dictionary(grouping: transactions) { transaction in
            guard let date = transaction.date else { return "" }
            return Formatters.date.string(from: date)
        }
        subject.send(grouped)

        return subject.eraseToAnyPublisher()
    }

    // MARK: - CRUD Operations

    func createTransaction(
        title: String,
        amount: Double,
        type: TransactionType,
        date: Date,
        account: Account,
        category: Category?,
        subCategory: SubCategory?,
        notes: String?
    ) throws -> Transaction {
        let transaction = Transaction(context: context)
        transaction.id = UUID()
        transaction.title = title
        transaction.amount = amount
        transaction.type = type.rawValue
        transaction.date = date
        transaction.account = account
        transaction.category = category
        transaction.subCategory = subCategory
        transaction.notes = notes
        transaction.createdAt = Date()
        transaction.updatedAt = Date()
        transaction.balanceAfter = 0 // Will be calculated by BalanceService

        return transaction
    }

    func updateTransaction(_ transaction: Transaction, with data: TransactionUpdateData) throws {
        if let title = data.title {
            transaction.title = title
        }
        if let amount = data.amount {
            transaction.amount = amount
        }
        if let date = data.date {
            transaction.date = date
        }
        if let type = data.type {
            transaction.type = type.rawValue
        }
        if let account = data.account {
            transaction.account = account
        }
        if let category = data.category {
            transaction.category = category
        }
        if let subCategory = data.subCategory {
            transaction.subCategory = subCategory
        }
        if let notes = data.notes {
            transaction.notes = notes
        }

        transaction.updatedAt = Date()
    }

    func deleteTransaction(_ transaction: Transaction, cascade: Bool = true) throws {
        context.delete(transaction)
    }

    // MARK: - Specialized Queries

    func fetchTransactions(
        for account: Account,
        from startDate: Date?,
        to endDate: Date?,
        sortAscending: Bool
    ) -> [Transaction] {
        var predicates: [NSPredicate] = [
            NSPredicate(format: "account == %@", account)
        ]

        if let startDate = startDate {
            predicates.append(NSPredicate(format: "date >= %@", startDate as NSDate))
        }

        if let endDate = endDate {
            predicates.append(NSPredicate(format: "date < %@", endDate as NSDate))
        }

        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        let sortDescriptors = [NSSortDescriptor(keyPath: \Transaction.date, ascending: sortAscending)]

        return fetch(predicate: compoundPredicate, sortDescriptors: sortDescriptors)
    }

    func fetch(predicate: NSPredicate?, sortDescriptors: [NSSortDescriptor]) -> [Transaction] {
        let request = NSFetchRequest<Transaction>(entityName: "Transaction")
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors

        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching transactions: \(error)")
            return []
        }
    }

    func fetchRelatedTransaction(for transactionID: UUID) -> Transaction? {
        let request = NSFetchRequest<Transaction>(entityName: "Transaction")
        request.predicate = NSPredicate(format: "relatedTransactionID == %@", transactionID as CVarArg)
        request.fetchLimit = 2

        do {
            let results = try context.fetch(request)
            // Return the one that doesn't have this ID
            return results.first(where: { $0.id != transactionID })
        } catch {
            print("Error fetching related transaction: \(error)")
            return nil
        }
    }

    // MARK: - Split Items Management

    func addSplitItems(_ items: [SplitItemData], to transaction: Transaction) throws {
        for item in items {
            let transactionItem = TransactionItem(context: context)
            transactionItem.id = UUID()
            transactionItem.title = item.title
            transactionItem.amount = item.amount
            transactionItem.category = item.category
            transactionItem.subCategory = item.subCategory
            transactionItem.transaction = transaction
        }
    }

    func clearSplitItems(for transaction: Transaction) throws {
        if let items = transaction.items as? Set<TransactionItem> {
            for item in items {
                context.delete(item)
            }
        }
    }
}
