//
//  PendingRecurringRepository.swift
//  OneTap
//
//  Repository for managing pending recurring transactions
//

import Foundation
@preconcurrency internal import CoreData
import Combine

class PendingRecurringRepository: BaseRepository {
    typealias Entity = PendingRecurringTransaction

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

    func pendingTransactionsPublisher() -> AnyPublisher<[PendingRecurringTransaction], Error> {
        let request: NSFetchRequest<PendingRecurringTransaction> = PendingRecurringTransaction.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PendingRecurringTransaction.scheduledDate, ascending: true)]

        let initial = (try? context.fetch(request)) ?? []
        let subject = CurrentValueSubject<[PendingRecurringTransaction], Error>(initial)

        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] notification in
                guard let self = self else { return }

                // Accept saves from any context with same persistent store
                guard let savedContext = notification.object as? NSManagedObjectContext,
                      savedContext.persistentStoreCoordinator === self.context.persistentStoreCoordinator else {
                    return
                }

                // Check if PendingRecurringTransaction was changed
                let inserted = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
                let updated = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? []
                let deleted = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? []

                let hasChanges = (inserted.union(updated).union(deleted))
                    .contains { $0 is PendingRecurringTransaction }

                guard hasChanges else { return }

                let fetched = (try? self.context.fetch(request)) ?? []
                subject.send(fetched)
            }
            .store(in: &cancellables)

        return subject.eraseToAnyPublisher()
    }

    // MARK: - CRUD Operations

    func createPending(
        from recurring: RecurringTransaction,
        scheduledDate: Date
    ) throws -> PendingRecurringTransaction {
        let pending = PendingRecurringTransaction(context: context)
        pending.id = UUID()
        pending.amount = recurring.amount
        pending.type = recurring.type
        pending.title = recurring.title
        pending.merchant = recurring.merchant
        pending.notes = recurring.notes
        pending.scheduledDate = scheduledDate
        pending.createdAt = Date()
        pending.account = recurring.account
        pending.category = recurring.category
        pending.subCategory = recurring.subCategory
        pending.toAccount = recurring.toAccount
        pending.recurringTransaction = recurring

        return pending
    }

    // MARK: - Fetch Operations

    func fetch(predicate: NSPredicate? = nil, sortDescriptors: [NSSortDescriptor] = []) -> [PendingRecurringTransaction] {
        let request: NSFetchRequest<PendingRecurringTransaction> = PendingRecurringTransaction.fetchRequest()
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors

        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching pending recurring transactions: \(error)")
            return []
        }
    }

    func fetchUpcoming(limit: Int = 10) -> [PendingRecurringTransaction] {
        let sortDescriptors = [NSSortDescriptor(keyPath: \PendingRecurringTransaction.scheduledDate, ascending: true)]
        let all = fetch(sortDescriptors: sortDescriptors)
        return Array(all.prefix(limit))
    }

    func fetchOverdue() -> [PendingRecurringTransaction] {
        let predicate = NSPredicate(format: "scheduledDate < %@", Date() as NSDate)
        return fetch(predicate: predicate)
    }

    func save() throws {
        if context.hasChanges {
            try context.save()
        }
    }

    func delete(_ pending: PendingRecurringTransaction) throws {
        context.delete(pending)
        try save()
    }

    // MARK: - Approval

    func approve(_ pending: PendingRecurringTransaction) throws -> Transaction {
        // This will be called by RecurringTransactionService to create the actual transaction
        // For now, just mark as handled by deleting
        let transaction = Transaction(context: context)
        transaction.id = UUID()
        transaction.amount = pending.amount
        transaction.type = pending.type
        transaction.title = pending.title
        transaction.merchant = pending.merchant
        transaction.notes = pending.notes
        transaction.date = pending.scheduledDate ?? Date()
        transaction.account = pending.account
        transaction.category = pending.category
        transaction.subCategory = pending.subCategory
        transaction.createdAt = Date()
        transaction.updatedAt = Date()
        transaction.recurringTransaction = pending.recurringTransaction

        // Delete the pending transaction
        context.delete(pending)

        return transaction
    }
}
