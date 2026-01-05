//
//  TransactionRepository.swift
//  OneTap
//
//  Repository for Transaction entity CRUD and queries
//

import Foundation
internal import CoreData
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
        let initialTransactions: [Transaction]
        if let account = (try? context.existingObject(with: accountID)) as? Account {
            initialTransactions = fetchTransactions(for: account, from: date, to: nil, sortAscending: false)
        } else {
            initialTransactions = []
        }
        
        let subject = CurrentValueSubject<[Transaction], Error>(initialTransactions)

        // Observe Core Data changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: context)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.context.perform {
                    if let account = (try? self.context.existingObject(with: accountID)) as? Account {
                        let transactions = self.fetchTransactions(
                            for: account,
                            from: date,
                            to: nil,
                            sortAscending: false
                        )
                        subject.send(transactions)
                    }
                }
            }
            .store(in: &cancellables)

        return subject.eraseToAnyPublisher()
    }

    func transactionsByDatePublisher(predicate: NSPredicate?) -> AnyPublisher<[String: [Transaction]], Error> {
        // Initial fetch
        let transactions = fetch(predicate: predicate, sortDescriptors: [
            NSSortDescriptor(keyPath: \Transaction.date, ascending: false)
        ])

        let grouped = Dictionary(grouping: transactions) { transaction in
            guard let date = transaction.date else { return "" }
            return Formatters.date.string(from: date)
        }

        let subject = CurrentValueSubject<[String: [Transaction]], Error>(grouped)

        // Helper to refetch and emit
        let refetchAndEmit: () -> Void = { [weak self, weak subject] in
            guard let self = self, let subject = subject else { return }
            self.context.perform {
                let transactions = self.fetch(predicate: predicate, sortDescriptors: [
                    NSSortDescriptor(keyPath: \Transaction.date, ascending: false)
                ])
                let grouped = Dictionary(grouping: transactions) { transaction in
                    guard let date = transaction.date else { return "" }
                    return Formatters.date.string(from: date)
                }
                subject.send(grouped)
            }
        }

        // Observe view context changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: context)
            .sink { _ in
                refetchAndEmit()
            }
            .store(in: &cancellables)

        // CRITICAL FIX: Also observe background context saves to catch balance recalculations
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] notification in
                guard let self = self else { return }

                // Only handle saves from background contexts, not the view context itself
                guard let savedContext = notification.object as? NSManagedObjectContext,
                      savedContext !== self.context,
                      savedContext.persistentStoreCoordinator === self.context.persistentStoreCoordinator else {
                    return
                }

                // Check if any Transaction objects were updated
                if let updatedObjects = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> {
                    let hasTransactionUpdates = updatedObjects.contains { $0 is Transaction }
                    if hasTransactionUpdates {
                        refetchAndEmit()
                    }
                }
            }
            .store(in: &cancellables)

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
        merchant: String? = nil,
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
        transaction.merchant = merchant
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
        if let merchant = data.merchant {
            transaction.merchant = merchant
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

    // MARK: - Merchant Autocomplete

    func fetchUniqueMerchants(matching searchText: String = "") -> [String] {
        let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        request.predicate = NSPredicate(format: "merchant != nil AND merchant != ''")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Transaction.date, ascending: false)]

        do {
            let transactions = try context.fetch(request)
            var uniqueMerchants = Set<String>()

            for transaction in transactions {
                if let merchant = transaction.merchant, !merchant.isEmpty {
                    uniqueMerchants.insert(merchant)
                }
            }

            var merchants = Array(uniqueMerchants).sorted()

            // Filter by search text if provided
            if !searchText.isEmpty {
                merchants = merchants.filter { $0.lowercased().contains(searchText.lowercased()) }
            }

            return Array(merchants.prefix(10)) // Limit to 10 suggestions
        } catch {
            print("Error fetching merchants: \(error)")
            return []
        }
    }
}
