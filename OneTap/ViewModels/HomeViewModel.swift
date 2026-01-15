//
//  HomeViewModel.swift
//  OneTap
//
//  ViewModel for home dashboard with shortcuts and summaries
//

import Foundation
import SwiftUI
import Combine
@preconcurrency internal import CoreData

@MainActor
class HomeViewModel: ObservableObject, ViewModelProtocol {

    // MARK: - Published State

    @Published var totalBalance: Double = 0
    @Published var totalAssets: Double = 0
    @Published var totalLiabilities: Double = 0
    @Published var monthlyIncome: Double = 0
    @Published var monthlyExpense: Double = 0
    @Published var recentTransactions: [Transaction] = []
    @Published var budgetAlerts: [BudgetAlert] = []
    @Published var upcomingRecurring: [RecurringTransaction] = []
    @Published var pendingRecurringTransactions: [PendingRecurringTransaction] = []

    // Today's activity
    @Published var todayIncome: Double = 0
    @Published var todayExpense: Double = 0
    @Published var dueToday: [RecurringTransaction] = []

    // Savings goals
    @Published var savingsGoals: [SavingsGoal] = []

    @Published var loadingState: LoadingState = .idle
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let accountRepository: AccountRepository
    private let transactionRepository: TransactionRepository
    private let budgetRepository: BudgetRepository
    private let recurringTransactionRepository: RecurringTransactionRepository
    private let pendingRecurringRepository: PendingRecurringRepository
    private var cancellables = Set<AnyCancellable>()

    init(
        accountRepository: AccountRepository,
        transactionRepository: TransactionRepository,
        budgetRepository: BudgetRepository,
        recurringTransactionRepository: RecurringTransactionRepository,
        pendingRecurringRepository: PendingRecurringRepository
    ) {
        self.accountRepository = accountRepository
        self.transactionRepository = transactionRepository
        self.budgetRepository = budgetRepository
        self.recurringTransactionRepository = recurringTransactionRepository
        self.pendingRecurringRepository = pendingRecurringRepository

        setupObservers()
        Task {
            await refreshData()
        }
    }

    deinit {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    // MARK: - Computed Properties

    var formattedTotalBalance: String {
        formatCurrency(totalBalance)
    }

    var formattedTotalAssets: String {
        formatCurrency(totalAssets)
    }

    var formattedTotalLiabilities: String {
        formatCurrency(totalLiabilities)
    }

    var formattedMonthlyIncome: String {
        formatCurrency(monthlyIncome)
    }

    var formattedMonthlyExpense: String {
        formatCurrency(monthlyExpense)
    }

    var hasAlerts: Bool {
        !budgetAlerts.isEmpty
    }

    var hasUpcomingRecurring: Bool {
        !upcomingRecurring.isEmpty
    }

    // Today's activity formatted
    var formattedTodayExpense: String {
        formatCurrency(todayExpense)
    }

    var formattedTodayIncome: String {
        formatCurrency(todayIncome)
    }

    // Attention count (alerts + pending)
    var attentionCount: Int {
        budgetAlerts.count + pendingRecurringTransactions.count
    }

    // Upcoming total amount
    var formattedUpcomingTotal: String {
        let total = upcomingRecurring.reduce(0.0) { $0 + $1.amount }
        return formatCurrency(total)
    }

    // MARK: - Setup

    private func setupObservers() {
        // Refresh when data changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.refreshData()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    func refreshData() async {
        loadingState = .loading

        // Calculate account balances
        calculateAccountBalances()

        // Get this month's income and expenses
        calculateMonthlyTotals()

        // Get today's activity
        calculateTodayActivity()

        // Get recent transactions
        fetchRecentTransactions()

        // Check budget alerts
        checkBudgetAlerts()

        // Get upcoming recurring transactions
        fetchUpcomingRecurring()

        // Get due today
        fetchDueToday()

        // Get pending recurring transactions
        fetchPendingRecurring()

        // Get savings goals
        fetchSavingsGoals()

        loadingState = .loaded
    }

    // MARK: - Private Helpers

    private func calculateAccountBalances() {
        let accounts = accountRepository.fetchAccounts(group: nil, includeArchived: false)

        var assets: Double = 0
        var liabilities: Double = 0

        for account in accounts {
            if account.isLiability {
                // Credit cards, BNPL - negative balance means owed
                liabilities += abs(account.balance)
            } else {
                // Regular accounts - positive balance
                assets += account.balance
            }
        }

        totalAssets = assets
        totalLiabilities = liabilities
        totalBalance = assets - liabilities
    }

    private func calculateMonthlyTotals() {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        guard let startOfMonth = calendar.date(from: components),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            return
        }

        let predicate = NSPredicate(
            format: "date >= %@ AND date <= %@",
            startOfMonth as NSDate,
            endOfMonth as NSDate
        )
        let transactions = transactionRepository.fetch(
            predicate: predicate,
            sortDescriptors: [NSSortDescriptor(keyPath: \Transaction.date, ascending: false)]
        )

        var income: Double = 0
        var expense: Double = 0

        for transaction in transactions {
            switch transaction.typeEnum {
            case .income:
                income += transaction.amount
            case .expense:
                expense += transaction.amount
            case .transfer, .adjustment:
                break
            }
        }

        monthlyIncome = income
        monthlyExpense = expense
    }

    private func fetchRecentTransactions() {
        let predicate: NSPredicate? = nil
        let sortDescriptors = [NSSortDescriptor(keyPath: \Transaction.date, ascending: false)]
        let allTransactions = transactionRepository.fetch(predicate: predicate, sortDescriptors: sortDescriptors)
        recentTransactions = Array(allTransactions.prefix(5))
    }

    private func calculateTodayActivity() {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return
        }

        let predicate = NSPredicate(
            format: "date >= %@ AND date < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        let transactions = transactionRepository.fetch(
            predicate: predicate,
            sortDescriptors: [NSSortDescriptor(keyPath: \Transaction.date, ascending: false)]
        )

        var income: Double = 0
        var expense: Double = 0

        for transaction in transactions {
            switch transaction.typeEnum {
            case .income:
                income += transaction.amount
            case .expense:
                expense += transaction.amount
            case .transfer, .adjustment:
                break
            }
        }

        todayIncome = income
        todayExpense = expense
    }

    private func fetchDueToday() {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return
        }

        let predicate = NSPredicate(
            format: "isActive == YES AND nextRunDate != nil AND nextRunDate >= %@ AND nextRunDate < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        let sortDescriptors = [NSSortDescriptor(keyPath: \RecurringTransaction.nextRunDate, ascending: true)]

        dueToday = recurringTransactionRepository.fetch(predicate: predicate, sortDescriptors: sortDescriptors)
    }

    private func fetchSavingsGoals() {
        let accounts = accountRepository.fetchAccounts(group: nil, includeArchived: false)
        savingsGoals = accounts.compactMap { $0.savingsGoal }
    }

    private func checkBudgetAlerts() {
        let budgets = (try? budgetRepository.fetchActive()) ?? []
        var alerts: [BudgetAlert] = []

        let now = Date()
        for budget in budgets {
            guard let category = budget.category else { continue }

            // Calculate spent for current month
            let spent: Double
            do {
                spent = try budgetRepository.calculateSpent(
                    for: category,
                    subCategory: budget.subCategory,
                    in: now
                )
            } catch {
                continue
            }

            let amount = budget.amount
            guard amount > 0 else { continue }

            let progress = (spent / amount) * 100
            let isExceeded = spent > amount
            let isNearLimit = progress >= 80 && !isExceeded

            // Check if exceeded or near limit
            if isExceeded {
                alerts.append(BudgetAlert(
                    budget: budget,
                    type: .exceeded,
                    message: "\(budget.displayName) exceeded by \(formatCurrency(spent - amount))"
                ))
            } else if isNearLimit {
                alerts.append(BudgetAlert(
                    budget: budget,
                    type: .warning,
                    message: "\(budget.displayName) at \(Int(progress))%"
                ))
            }
        }

        budgetAlerts = alerts
    }

    private func fetchUpcomingRecurring() {
        let calendar = Calendar.current
        let now = Date()
        guard let next7Days = calendar.date(byAdding: .day, value: 7, to: now) else {
            return
        }

        let predicate = NSPredicate(
            format: "isActive == YES AND nextRunDate != nil AND nextRunDate >= %@ AND nextRunDate <= %@",
            now as NSDate,
            next7Days as NSDate
        )
        let sortDescriptors = [NSSortDescriptor(keyPath: \RecurringTransaction.nextRunDate, ascending: true)]

        let recurring = recurringTransactionRepository.fetch(predicate: predicate, sortDescriptors: sortDescriptors)
        upcomingRecurring = Array(recurring.prefix(5))
    }

    private func fetchPendingRecurring() {
        let sortDescriptors = [NSSortDescriptor(keyPath: \PendingRecurringTransaction.scheduledDate, ascending: true)]
        let pending = pendingRecurringRepository.fetch(sortDescriptors: sortDescriptors)
        pendingRecurringTransactions = Array(pending.prefix(10))
    }

    var hasPendingRecurring: Bool {
        !pendingRecurringTransactions.isEmpty
    }

    func approvePendingTransaction(_ pending: PendingRecurringTransaction) async {
        do {
            _ = try pendingRecurringRepository.approve(pending)
            try pendingRecurringRepository.save()

            // Update recurring transaction occurrence count if it has one
            if let recurring = pending.recurringTransaction {
                recurring.occurrencesCount += 1
                recurring.lastRunDate = pending.scheduledDate
            }

            // Refresh data
            await refreshData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rejectPendingTransaction(_ pending: PendingRecurringTransaction) async {
        do {
            try pendingRecurringRepository.delete(pending)
            await refreshData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = Formatters.currencyFormatter(for: SettingsManager.shared.currencyCode)
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Supporting Types

struct BudgetAlert: Identifiable {
    let id = UUID()
    let budget: Budget
    let type: AlertType
    let message: String

    enum AlertType {
        case warning
        case exceeded
    }

    var color: Color {
        switch type {
        case .warning: return .orange
        case .exceeded: return .red
        }
    }

    var icon: String {
        switch type {
        case .warning: return "exclamationmark.triangle.fill"
        case .exceeded: return "xmark.circle.fill"
        }
    }
}
