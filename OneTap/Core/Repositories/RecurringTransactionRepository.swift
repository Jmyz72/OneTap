//
//  RecurringTransactionRepository.swift
//  OneTap
//

import Foundation
internal import CoreData
import Combine

class RecurringTransactionRepository: BaseRepository {
    typealias Entity = RecurringTransaction

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

    func recurringTransactionsPublisher() -> AnyPublisher<[RecurringTransaction], Error> {
        let request: NSFetchRequest<RecurringTransaction> = RecurringTransaction.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \RecurringTransaction.startDate, ascending: false)]
        
        let initial = (try? context.fetch(request)) ?? []
        let subject = CurrentValueSubject<[RecurringTransaction], Error>(initial)
        
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave, object: context)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let updated = (try? self.context.fetch(request)) ?? []
                subject.send(updated)
            }
            .store(in: &cancellables)
            
        return subject.eraseToAnyPublisher()
    }

    // MARK: - CRUD Operations

    func createRecurring(
        amount: Double,
        frequency: String,
        startDate: Date,
        type: TransactionType,
        account: Account,
        category: Category?,
        subCategory: SubCategory?,
        title: String?,
        merchant: String?,
        notes: String?,
        toAccount: Account? = nil,
        occurrenceLimit: Int? = nil,
        endDate: Date? = nil,
        interval: Int = 1,
        weeklyDays: String? = nil,
        monthlyDay: Int? = nil
    ) throws -> RecurringTransaction {
        let recurring = RecurringTransaction(context: context)
        recurring.id = UUID()
        recurring.amount = amount
        recurring.frequency = frequency
        recurring.startDate = startDate
        recurring.nextRunDate = startDate
        recurring.type = type.rawValue
        recurring.account = account
        recurring.category = category
        recurring.subCategory = subCategory
        recurring.title = title
        recurring.merchant = merchant
        recurring.notes = notes
        recurring.toAccount = toAccount
        recurring.isActive = true
        recurring.createdAt = Date()
        recurring.updatedAt = Date()
        recurring.interval = Int16(interval)
        recurring.endDate = endDate
        recurring.weeklyDays = weeklyDays

        if let limit = occurrenceLimit {
            recurring.occurrenceLimit = Int16(limit)
        }

        if let day = monthlyDay {
            recurring.monthlyDay = Int16(day)
        }

        return recurring
    }

    // MARK: - Fetch Operations

    func fetch(predicate: NSPredicate? = nil, sortDescriptors: [NSSortDescriptor] = []) -> [RecurringTransaction] {
        let request: NSFetchRequest<RecurringTransaction> = RecurringTransaction.fetchRequest()
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors

        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching recurring transactions: \(error)")
            return []
        }
    }

    func save() throws {
        if context.hasChanges {
            try context.save()
        }
    }

    func delete(_ recurring: RecurringTransaction) throws {
        context.delete(recurring)
        try save()
    }

    // MARK: - Split Items Management

    func addSplitItems(_ items: [SplitItemData], to recurring: RecurringTransaction) throws {
        for item in items {
            let recurringItem = RecurringTransactionItem(context: context)
            recurringItem.id = UUID()
            recurringItem.title = item.title
            recurringItem.amount = item.amount
            recurringItem.category = item.category
            recurringItem.subCategory = item.subCategory
            recurringItem.recurringTransaction = recurring
        }
    }

    func clearSplitItems(for recurring: RecurringTransaction) throws {
        if let items = recurring.items as? Set<RecurringTransactionItem> {
            for item in items {
                context.delete(item)
            }
        }
    }
}