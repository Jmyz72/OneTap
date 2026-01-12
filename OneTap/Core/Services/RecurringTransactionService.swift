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

        guard let account = recurring.account else {
            throw ServiceError.operationFailed("Account not found for recurring transaction")
        }

        var accountsToUpdate: Set<NSManagedObjectID> = []
        accountsToUpdate.insert(account.objectID)

        // Safety limit to prevent infinite loops
        var iterationCount = 0
        let maxIterations = 365 // Maximum iterations per recurring transaction (e.g., daily for a year)

        while nextDate <= date && iterationCount < maxIterations {
            iterationCount += 1

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
                account: account,
                category: recurring.category,
                subCategory: recurring.subCategory,
                merchant: recurring.merchant,
                notes: recurring.notes
            )

            transaction.recurringTransaction = recurring

            // For installments, set installment tracking fields
            if recurring.isInstallment {
                transaction.installmentPlanID = recurring.id
                transaction.installmentNumber = recurring.occurrencesCount + 1
            }

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

        // Log warning if we hit max iterations (potential infinite loop detected)
        if iterationCount >= maxIterations {
            print("⚠️ Warning: Hit max iteration limit (\(maxIterations)) for recurring transaction \(recurring.id?.uuidString ?? "unknown"). This may indicate a calculation error.")
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

            if monthlyDay == 0 || monthlyDay > 28 {
                // Last day of month OR day 29-31 (use last-day-of-month logic)
                // CRITICAL FIX: For dates like "monthly on 31st", always use last day
                // to avoid drift (Feb 28 → March 28 → April 28 bug)

                var monthsToAdd = interval
                var components = calendar.dateComponents([.year, .month, .day], from: date)

                // Add the specified number of months
                components.month = (components.month ?? 1) + monthsToAdd

                // Get first day of target month
                components.day = 1
                guard let firstOfMonth = calendar.date(from: components) else {
                    return nil
                }

                // Get last day of that month
                let range = calendar.range(of: .day, in: .month, for: firstOfMonth)
                let lastDay = range?.count ?? 28

                // Set to either the requested day (if <= lastDay) or last day
                if monthlyDay == 0 {
                    components.day = lastDay  // Explicitly "last day"
                } else {
                    components.day = min(monthlyDay, lastDay)  // Day 29-31
                }

                components.hour = timeComponents.hour
                components.minute = timeComponents.minute
                components.second = timeComponents.second
                return calendar.date(from: components)
            } else {
                // Day 1-28: safe to use standard month addition
                guard let nextMonth = calendar.date(byAdding: .month, value: interval, to: date) else {
                    return nil
                }

                var components = calendar.dateComponents([.year, .month], from: nextMonth)
                components.day = monthlyDay
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

    // MARK: - Installment Creation

    /// Creates an installment plan with optional immediate first payment
    /// - Parameters:
    ///   - title: Purchase description (e.g., "iPhone 15 Pro")
    ///   - totalAmount: Total purchase amount (e.g., $1200)
    ///   - numberOfPayments: Number of installments (e.g., 12)
    ///   - account: Account to charge
    ///   - category: Category for transactions
    ///   - subCategory: Optional subcategory
    ///   - merchant: Optional merchant name
    ///   - notes: Optional notes
    ///   - firstPaymentImmediate: If true, creates first payment today
    ///   - billingDay: Day of month for recurring payments (1-31, 0 = last day)
    ///   - startDate: Date when installment plan begins (used if firstPaymentImmediate = false)
    ///   - annualInterestRate: Optional APR as decimal (e.g., 0.15 for 15% APR). Defaults to 0 (no interest)
    /// - Returns: Tuple of (RecurringTransaction plan, Optional first Transaction)
    func createInstallmentPlan(
        title: String,
        totalAmount: Double,
        numberOfPayments: Int16,
        account: Account,
        category: Category?,
        subCategory: SubCategory?,
        merchant: String?,
        notes: String?,
        firstPaymentImmediate: Bool,
        billingDay: Int16,
        startDate: Date = Date(),
        annualInterestRate: Double = 0.0
    ) async throws -> (RecurringTransaction, Transaction?) {

        guard numberOfPayments > 0 else {
            throw ServiceError.operationFailed("Number of payments must be greater than 0")
        }

        // Calculate monthly payment with or without interest
        let paymentAmount: Double
        let hasInterest = annualInterestRate > 0

        if hasInterest {
            // Use amortization formula for interest-bearing installments
            paymentAmount = RecurringTransaction.calculateMonthlyPayment(
                principal: totalAmount,
                apr: annualInterestRate,
                months: numberOfPayments
            )
        } else {
            // Simple division for 0% APR
            paymentAmount = totalAmount / Double(numberOfPayments)
        }

        let now = Date()

        // Create RecurringTransaction (the installment plan)
        let plan = RecurringTransaction(context: context)
        plan.id = UUID()
        plan.title = title
        plan.amount = paymentAmount
        plan.totalAmount = totalAmount
        plan.type = TransactionType.expense.rawValue
        plan.frequency = "Monthly"
        plan.interval = 1
        plan.isActive = true
        plan.isInstallment = true
        plan.hasInterest = hasInterest
        plan.interestRate = annualInterestRate
        plan.firstPaymentImmediate = firstPaymentImmediate
        plan.occurrenceLimit = numberOfPayments
        plan.occurrencesCount = 0
        plan.monthlyDay = billingDay
        plan.account = account
        plan.category = category
        plan.subCategory = subCategory
        plan.merchant = merchant
        plan.notes = notes
        plan.createdAt = now
        plan.updatedAt = now

        var firstTransaction: Transaction? = nil

        if firstPaymentImmediate {
            // Type 1: Pay first installment NOW
            plan.startDate = now
            plan.occurrencesCount = 1

            // Create first payment immediately
            firstTransaction = try transactionRepository.createTransaction(
                title: title,
                amount: paymentAmount,
                type: .expense,
                date: now,
                account: account,
                category: category,
                subCategory: subCategory,
                merchant: merchant,
                notes: notes
            )

            firstTransaction?.recurringTransaction = plan
            firstTransaction?.installmentPlanID = plan.id
            firstTransaction?.installmentNumber = 1

            // Calculate next billing date
            let nextBillingDate = calculateNextBillingDate(from: now, billingDay: billingDay)
            plan.nextRunDate = nextBillingDate
            plan.lastRunDate = now

        } else {
            // Type 2: First payment on next billing date
            let nextBillingDate = calculateNextBillingDate(from: startDate, billingDay: billingDay)
            plan.startDate = nextBillingDate
            plan.nextRunDate = nextBillingDate
        }

        try context.save()

        // Recalculate balances if first payment was made
        if let transaction = firstTransaction {
            try await balanceService.recalculateBalances(for: account.objectID, from: transaction.date ?? now)
        }

        return (plan, firstTransaction)
    }

    /// Calculates the next billing date based on billing day
    /// CRITICAL FIX: Properly handles day 29-31 to avoid drift across months
    private func calculateNextBillingDate(from date: Date, billingDay: Int16) -> Date {
        let calendar = Calendar.current
        let day = Int(billingDay)

        // Get current month's billing date
        var components = calendar.dateComponents([.year, .month], from: date)
        components.hour = 0
        components.minute = 0
        components.second = 0

        if day == 0 || day > 28 {
            // Last day of month OR day 29-31 (use last-day logic)
            guard let currentMonthDate = calendar.date(from: components) else {
                return date
            }

            let range = calendar.range(of: .day, in: .month, for: currentMonthDate)
            let lastDay = range?.count ?? 28

            if day == 0 {
                components.day = lastDay  // Explicitly last day
            } else {
                components.day = min(day, lastDay)  // Day 29-31
            }
        } else {
            // Day 1-28: safe to use directly
            components.day = day
        }

        guard let billingDate = calendar.date(from: components) else {
            return date
        }

        // If billing date is today or in the past, move to next month
        if billingDate <= date {
            // CRITICAL FIX: Don't just add 1 month to the date
            // Instead, increment month and recalculate the correct day
            var nextComponents = calendar.dateComponents([.year, .month], from: billingDate)
            nextComponents.month = (nextComponents.month ?? 1) + 1
            nextComponents.day = 1  // First of next month
            nextComponents.hour = 0
            nextComponents.minute = 0
            nextComponents.second = 0

            guard let firstOfNextMonth = calendar.date(from: nextComponents) else {
                return date
            }

            // Get last day of next month
            let range = calendar.range(of: .day, in: .month, for: firstOfNextMonth)
            let lastDay = range?.count ?? 28

            // Apply the same day logic
            if day == 0 {
                nextComponents.day = lastDay
            } else if day > 28 {
                nextComponents.day = min(day, lastDay)
            } else {
                nextComponents.day = day
            }

            return calendar.date(from: nextComponents) ?? billingDate
        }

        return billingDate
    }

    // MARK: - Installment Management

    /// Pay off remaining installment balance early
    /// - Parameters:
    ///   - plan: The installment plan to pay off
    ///   - date: Date of the payoff transaction
    /// - Returns: Transaction for the payoff amount
    func payOffInstallmentEarly(plan: RecurringTransaction, date: Date = Date()) async throws -> Transaction {
        guard plan.isInstallment else {
            throw ServiceError.operationFailed("This is not an installment plan")
        }

        guard plan.isActive else {
            throw ServiceError.operationFailed("This installment plan is already inactive")
        }

        guard let account = plan.account else {
            throw ServiceError.operationFailed("Account not found for installment plan")
        }

        let remainingAmount = plan.remainingAmount
        guard remainingAmount > 0 else {
            throw ServiceError.operationFailed("No remaining balance to pay off")
        }

        // Create final payoff transaction
        let payoffTransaction = try transactionRepository.createTransaction(
            title: "\(plan.title ?? "Installment") - Early Payoff",
            amount: remainingAmount,
            type: .expense,
            date: date,
            account: account,
            category: plan.category,
            subCategory: plan.subCategory,
            merchant: plan.merchant,
            notes: "Early payoff of installment plan"
        )

        payoffTransaction.recurringTransaction = plan
        payoffTransaction.installmentPlanID = plan.id
        payoffTransaction.installmentNumber = plan.occurrencesCount + 1

        // Mark plan as completed
        plan.isActive = false
        plan.occurrencesCount = plan.occurrenceLimit
        plan.lastRunDate = date
        plan.updatedAt = Date()

        try context.save()

        // Recalculate balance
        try await balanceService.recalculateBalances(for: account.objectID, from: date)

        return payoffTransaction
    }

    /// Cancel an installment plan (e.g., item returned)
    /// - Parameters:
    ///   - plan: The installment plan to cancel
    ///   - refundAmount: Optional amount to refund (0 = no refund, nil = full refund of paid amount)
    ///   - date: Date of cancellation
    /// - Returns: Optional refund transaction if refundAmount > 0
    func cancelInstallmentPlan(
        plan: RecurringTransaction,
        refundAmount: Double? = nil,
        date: Date = Date()
    ) async throws -> Transaction? {
        guard plan.isInstallment else {
            throw ServiceError.operationFailed("This is not an installment plan")
        }

        guard let account = plan.account else {
            throw ServiceError.operationFailed("Account not found for installment plan")
        }

        // Deactivate the plan
        plan.isActive = false
        plan.updatedAt = Date()

        var refundTransaction: Transaction? = nil

        // Handle refund if requested
        if let refund = refundAmount, refund > 0 {
            // Create refund transaction (income to account)
            refundTransaction = try transactionRepository.createTransaction(
                title: "\(plan.title ?? "Installment") - Refund",
                amount: refund,
                type: .income,
                date: date,
                account: account,
                category: plan.category,
                subCategory: plan.subCategory,
                merchant: plan.merchant,
                notes: "Refund from cancelled installment plan"
            )

            refundTransaction?.recurringTransaction = plan
        } else if refundAmount == nil {
            // Full refund of all paid amounts
            let paidAmount = plan.paidAmount
            if paidAmount > 0 {
                refundTransaction = try transactionRepository.createTransaction(
                    title: "\(plan.title ?? "Installment") - Full Refund",
                    amount: paidAmount,
                    type: .income,
                    date: date,
                    account: account,
                    category: plan.category,
                    subCategory: plan.subCategory,
                    merchant: plan.merchant,
                    notes: "Full refund from cancelled installment plan"
                )

                refundTransaction?.recurringTransaction = plan
            }
        }

        try context.save()

        // Recalculate balance if refund was issued
        if refundTransaction != nil {
            try await balanceService.recalculateBalances(for: account.objectID, from: date)
        }

        return refundTransaction
    }

    /// Fetch all active installment plans
    func fetchActiveInstallmentPlans() throws -> [RecurringTransaction] {
        let request: NSFetchRequest<RecurringTransaction> = RecurringTransaction.fetchRequest()
        request.predicate = NSPredicate(format: "isInstallment == YES AND isActive == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \RecurringTransaction.startDate, ascending: false)]

        return try context.fetch(request)
    }

    /// Fetch all installment plans (active and inactive)
    func fetchAllInstallmentPlans() throws -> [RecurringTransaction] {
        let request: NSFetchRequest<RecurringTransaction> = RecurringTransaction.fetchRequest()
        request.predicate = NSPredicate(format: "isInstallment == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \RecurringTransaction.startDate, ascending: false)]

        return try context.fetch(request)
    }
}
