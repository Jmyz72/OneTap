//
//  TransactionRepository.swift
//  OneTap
//
//  Repository for Transaction entity CRUD and queries
//

import Foundation
@preconcurrency internal import CoreData
import Combine

class TransactionRepository: BaseRepository {
    typealias Entity = Transaction

    // MARK: - Configuration

    private enum Configuration {
        /// Maximum number of recent transactions to fetch for merchant autocomplete history
        static let merchantHistoryLimit = 500
        /// Maximum number of merchant suggestions to return in autocomplete
        static let merchantSuggestionLimit = 10
        /// Debounce delay in seconds for publisher updates to batch rapid changes
        static let publisherDebounceDelay = 0.3
    }

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

        // Create a trigger subject for debouncing
        let triggerSubject = PassthroughSubject<Void, Never>()

        // Observe view context changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: context)
            .sink { _ in
                triggerSubject.send()
            }
            .store(in: &cancellables)

        // Observe all context saves (view context + background contexts) to catch edits and balance recalculations
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] notification in
                guard let self = self else { return }

                // Handle saves from any context that shares the same persistent store
                guard let savedContext = notification.object as? NSManagedObjectContext,
                      savedContext.persistentStoreCoordinator === self.context.persistentStoreCoordinator else {
                    return
                }

                // Check if any Transaction objects were inserted, updated, or deleted
                let insertedObjects = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
                let updatedObjects = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? []
                let deletedObjects = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? []

                let hasTransactionChanges = (insertedObjects.union(updatedObjects).union(deletedObjects))
                    .contains { $0 is Transaction }

                if hasTransactionChanges {
                    triggerSubject.send()
                }
            }
            .store(in: &cancellables)

        // Debounce the triggers and refetch (delay batches rapid changes)
        triggerSubject
            .debounce(for: .seconds(Configuration.publisherDebounceDelay), scheduler: DispatchQueue.main)
            .sink { _ in
                refetchAndEmit()
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
        notes: String?,
        adjustmentReason: String? = nil,
        excludeFromReports: Bool = false,
        isFromOCR: Bool = false
    ) throws -> Transaction {
        // CRITICAL: Adjustment transactions must have a reason for audit trail
        if type == .adjustment {
            guard let reason = adjustmentReason, !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ServiceError.validationFailed(
                    "Adjustment transactions require a reason for the audit trail. " +
                    "Please explain why the balance is being adjusted."
                )
            }
        }

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
        transaction.adjustmentReason = adjustmentReason
        transaction.excludeFromReports = excludeFromReports
        transaction.setValue(isFromOCR, forKey: "isFromOCR")  // Set using KVC until Core Data entity is updated
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
        if let excludeFromReports = data.excludeFromReports {
            transaction.excludeFromReports = excludeFromReports
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

        // Prefetch relationships to avoid N+1 query problem
        request.relationshipKeyPathsForPrefetching = [
            "account",
            "category",
            "subCategory",
            "items",
            "recurringTransaction"
        ]

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
        // Performance: Only fetch recent transactions to extract unique merchants
        request.fetchLimit = Configuration.merchantHistoryLimit

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

            // Return limited number of suggestions for autocomplete
            return Array(merchants.prefix(Configuration.merchantSuggestionLimit))
        } catch {
            print("Error fetching merchants: \(error)")
            return []
        }
    }

    func fetchRecentMerchants(limit: Int = 5) -> [String] {
        let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        request.predicate = NSPredicate(format: "merchant != nil AND merchant != ''")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Transaction.date, ascending: false)]
        // Fetch enough to get diverse merchants after deduping
        request.fetchLimit = 100

        do {
            let transactions = try context.fetch(request)
            var seen = Set<String>()
            var uniqueMerchants: [String] = []

            for transaction in transactions {
                if let merchant = transaction.merchant,
                   !merchant.isEmpty,
                   !seen.contains(merchant) {
                    seen.insert(merchant)
                    uniqueMerchants.append(merchant)
                    if uniqueMerchants.count >= limit {
                        break
                    }
                }
            }

            return uniqueMerchants
        } catch {
            print("Error fetching recent merchants: \(error)")
            return []
        }
    }
}
