//
//  RecurringTransactionService.swift
//  OneTap
//

import Foundation
internal import CoreData

class RecurringTransactionService {
    private let context: NSManagedObjectContext
    private let transactionRepository: TransactionRepository
    private let balanceService: BalanceService

    init(context: NSManagedObjectContext, transactionRepository: TransactionRepository, balanceService: BalanceService) {
        self.context = context
        self.transactionRepository = transactionRepository
        self.balanceService = balanceService
    }

    /// Processes all active recurring transactions and generates missing occurrences
    func processRecurringTransactions() async throws {
        let request: NSFetchRequest<RecurringTransaction> = RecurringTransaction.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        
        let recurringOnes = try context.fetch(request)
        let now = Date()
        
        for recurring in recurringOnes {
            try await processSingleRecurring(recurring, until: now)
        }
        
        if context.hasChanges {
            try context.save()
        }
    }

    private func processSingleRecurring(_ recurring: RecurringTransaction, until date: Date) async throws {
        guard var nextDate = recurring.nextRunDate, nextDate <= date else { return }

        // Check if end date is set and we're past it
        if let endDate = recurring.endDate, nextDate > endDate {
            recurring.isActive = false
            return
        }

        let account = recurring.account
        var accountsToUpdate: Set<NSManagedObjectID> = []
        if let accID = account?.objectID { accountsToUpdate.insert(accID) }

        while nextDate <= date {
            // Check if end date is set and we're past it
            if let endDate = recurring.endDate, nextDate > endDate {
                recurring.isActive = false
                break
            }

            // Check limits for installments
            if recurring.occurrenceLimit > 0 && recurring.occurrencesCount >= recurring.occurrenceLimit {
                recurring.isActive = false
                break
            }

            // Generate actual transaction
            let transaction = try transactionRepository.createTransaction(
                title: recurring.title ?? "",
                amount: recurring.amount,
                type: TransactionType(rawValue: recurring.type ?? "Expense") ?? .expense,
                date: nextDate,
                account: account!,
                category: recurring.category,
                subCategory: recurring.subCategory,
                merchant: recurring.merchant,
                notes: recurring.notes
            )

            transaction.recurringTransaction = recurring

            // Handle split items
            if let templateItems = recurring.items as? Set<RecurringTransactionItem> {
                for item in templateItems {
                    let splitItem = TransactionItem(context: context)
                    splitItem.id = UUID()
                    splitItem.title = item.title
                    splitItem.amount = item.amount
                    splitItem.category = item.category
                    splitItem.subCategory = item.subCategory
                    splitItem.transaction = transaction
                }
            }

            recurring.occurrencesCount += 1
            recurring.lastRunDate = nextDate

            // Calculate next date based on frequency
            if let calculatedNext = calculateNextDate(for: recurring, from: nextDate) {
                nextDate = calculatedNext
                recurring.nextRunDate = nextDate
            } else {
                recurring.isActive = false
                break
            }

            // Check if we hit limit after update
            if recurring.occurrenceLimit > 0 && recurring.occurrencesCount >= recurring.occurrenceLimit {
                recurring.isActive = false
                break
            }
        }

        // Recalculate balances for affected accounts
        if !accountsToUpdate.isEmpty {
            try await balanceService.recalculateBalances(for: Array(accountsToUpdate), from: recurring.startDate ?? Date())
        }
    }

    private func calculateNextDate(for recurring: RecurringTransaction, from date: Date) -> Date? {
        let calendar = Calendar.current
        let interval = Int(recurring.interval)
        let frequency = recurring.frequency ?? "Monthly"

        // Get the time components from the original start date to preserve the time
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: recurring.startDate ?? date)

        switch frequency {
        case "Daily":
            return calendar.date(byAdding: .day, value: interval, to: date)

        case "Weekly":
            // For weekly, we need to find the next occurrence on a selected weekday
            guard let weeklyDaysString = recurring.weeklyDays,
                  !weeklyDaysString.isEmpty else {
                // If no specific days selected, just add weeks
                return calendar.date(byAdding: .weekOfYear, value: interval, to: date)
            }

            let selectedDays = weeklyDaysString.split(separator: ",").compactMap { Int($0) }.sorted()
            guard !selectedDays.isEmpty else {
                return calendar.date(byAdding: .weekOfYear, value: interval, to: date)
            }

            // Get current weekday (1=Sunday, 2=Monday, etc.)
            let currentWeekday = calendar.component(.weekday, from: date)

            // Find next selected day in the same week
            for day in selectedDays {
                if day > currentWeekday {
                    let daysToAdd = day - currentWeekday
                    if let nextDate = calendar.date(byAdding: .day, value: daysToAdd, to: date) {
                        // Preserve the time from start date
                        var components = calendar.dateComponents([.year, .month, .day], from: nextDate)
                        components.hour = timeComponents.hour
                        components.minute = timeComponents.minute
                        components.second = timeComponents.second
                        return calendar.date(from: components)
                    }
                }
            }

            // No more days this week, go to first selected day in next interval of weeks
            let firstSelectedDay = selectedDays[0]
            let daysToAdd = (7 * interval) - currentWeekday + firstSelectedDay
            if let nextDate = calendar.date(byAdding: .day, value: daysToAdd, to: date) {
                // Preserve the time from start date
                var components = calendar.dateComponents([.year, .month, .day], from: nextDate)
                components.hour = timeComponents.hour
                components.minute = timeComponents.minute
                components.second = timeComponents.second
                return calendar.date(from: components)
            }
            return nil

        case "Monthly":
            // For monthly, we need to generate on a specific day of the month
            let monthlyDay = Int(recurring.monthlyDay)

            if monthlyDay == 0 {
                // Last day of month
                guard let nextMonth = calendar.date(byAdding: .month, value: interval, to: date) else {
                    return nil
                }

                // Get the range of days in that month
                let range = calendar.range(of: .day, in: .month, for: nextMonth)
                let lastDay = range?.count ?? 28

                var components = calendar.dateComponents([.year, .month], from: nextMonth)
                components.day = lastDay
                components.hour = timeComponents.hour
                components.minute = timeComponents.minute
                components.second = timeComponents.second
                return calendar.date(from: components)
            } else {
                // Specific day of month (1-31)
                guard let nextMonth = calendar.date(byAdding: .month, value: interval, to: date) else {
                    return nil
                }

                var components = calendar.dateComponents([.year, .month], from: nextMonth)

                // Get the range of days in that month
                let range = calendar.range(of: .day, in: .month, for: nextMonth)
                let daysInMonth = range?.count ?? 28

                // Use the specified day, or last day if the month doesn't have that many days
                components.day = min(monthlyDay, daysInMonth)
                components.hour = timeComponents.hour
                components.minute = timeComponents.minute
                components.second = timeComponents.second
                return calendar.date(from: components)
            }

        case "Yearly":
            return calendar.date(byAdding: .year, value: interval, to: date)

        default:
            return nil
        }
    }
}
