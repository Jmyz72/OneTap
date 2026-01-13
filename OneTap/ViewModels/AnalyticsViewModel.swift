//
//  AnalyticsViewModel.swift
//  OneTap
//
//  ViewModel for analytics and insights
//

import Foundation
import SwiftUI
import Combine
internal import CoreData

@MainActor
class AnalyticsViewModel: ObservableObject, ViewModelProtocol {

    // MARK: - Published State

    @Published var selectedPeriod: TimePeriod = .thisMonth
    @Published var totalIncome: Double = 0
    @Published var totalExpense: Double = 0
    @Published var netAmount: Double = 0
    @Published var categoryBreakdown: [CategoryData] = []
    @Published var topCategories: [CategoryData] = []
    @Published var monthlyTrends: [MonthData] = []

    @Published var loadingState: LoadingState = .idle
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let transactionRepository: TransactionRepository
    private var cancellables = Set<AnyCancellable>()

    init(transactionRepository: TransactionRepository) {
        self.transactionRepository = transactionRepository
        setupObservers()
        Task {
            await refreshAnalytics()
        }
    }

    deinit {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    // MARK: - Computed Properties

    var formattedIncome: String {
        formatCurrency(totalIncome)
    }

    var formattedExpense: String {
        formatCurrency(totalExpense)
    }

    var formattedNet: String {
        formatCurrency(netAmount)
    }

    var hasData: Bool {
        totalIncome > 0 || totalExpense > 0
    }

    // MARK: - Setup

    private func setupObservers() {
        // Refresh when transactions change
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.refreshAnalytics()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    func refreshAnalytics() async {
        loadingState = .loading

        do {
            let (startDate, endDate) = selectedPeriod.dateRange

            // Fetch all transactions in the period
            let predicate = NSPredicate(
                format: "date >= %@ AND date <= %@",
                startDate as NSDate,
                endDate as NSDate
            )
            let sortDescriptors = [NSSortDescriptor(keyPath: \Transaction.date, ascending: false)]
            let transactions = transactionRepository.fetch(predicate: predicate, sortDescriptors: sortDescriptors)

            // Calculate totals
            calculateTotals(from: transactions)

            // Calculate category breakdown
            calculateCategoryBreakdown(from: transactions)

            // Calculate monthly trends (for year view)
            if selectedPeriod == .thisYear {
                calculateMonthlyTrends(from: transactions)
            }

            loadingState = .loaded
        } catch {
            loadingState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    func selectPeriod(_ period: TimePeriod) async {
        selectedPeriod = period
        await refreshAnalytics()
    }

    // MARK: - Private Helpers

    private func calculateTotals(from transactions: [Transaction]) {
        var income: Double = 0
        var expense: Double = 0

        for transaction in transactions {
            switch transaction.typeEnum {
            case .income:
                income += transaction.amount
            case .expense:
                expense += transaction.amount
            case .transfer, .adjustment:
                break // Don't count transfers/adjustments in income/expense totals
            }
        }

        totalIncome = income
        totalExpense = expense
        netAmount = income - expense
    }

    private func calculateCategoryBreakdown(from transactions: [Transaction]) {
        // Group expenses by category
        let expenseTransactions = transactions.filter { $0.typeEnum == .expense }

        var categoryTotals: [String: (category: Category?, amount: Double)] = [:]

        for transaction in expenseTransactions {
            let categoryName = transaction.category?.name ?? "Uncategorized"
            let existing = categoryTotals[categoryName]
            categoryTotals[categoryName] = (
                category: transaction.category ?? existing?.category,
                amount: (existing?.amount ?? 0) + transaction.amount
            )
        }

        // Convert to CategoryData and sort by amount
        let breakdown = categoryTotals.map { name, data in
            CategoryData(
                name: name,
                amount: data.amount,
                percentage: totalExpense > 0 ? (data.amount / totalExpense) * 100 : 0,
                color: data.category?.colorView ?? .gray,
                icon: data.category?.iconName ?? "tag.fill"
            )
        }
        .sorted { $0.amount > $1.amount }

        categoryBreakdown = breakdown
        topCategories = Array(breakdown.prefix(5))
    }

    private func calculateMonthlyTrends(from transactions: [Transaction]) {
        let calendar = Calendar.current
        var monthlyData: [String: (income: Double, expense: Double)] = [:]

        for transaction in transactions {
            guard let date = transaction.date else { continue }
            let monthKey = Formatters.monthYear.string(from: date)

            var existing = monthlyData[monthKey] ?? (income: 0, expense: 0)

            switch transaction.typeEnum {
            case .income:
                existing.income += transaction.amount
            case .expense:
                existing.expense += transaction.amount
            case .transfer, .adjustment:
                break
            }

            monthlyData[monthKey] = existing
        }

        // Convert to MonthData and sort
        let trends = monthlyData.map { monthKey, data in
            MonthData(
                month: monthKey,
                income: data.income,
                expense: data.expense,
                net: data.income - data.expense
            )
        }
        .sorted { $0.month < $1.month }

        monthlyTrends = trends
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = Formatters.currencyFormatter(for: SettingsManager.shared.currencyCode)
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Supporting Types

enum TimePeriod: String, CaseIterable {
    case thisMonth = "This Month"
    case lastMonth = "Last Month"
    case thisYear = "This Year"
    case last30Days = "Last 30 Days"
    case last90Days = "Last 90 Days"

    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .thisMonth:
            let components = calendar.dateComponents([.year, .month], from: now)
            let start = calendar.date(from: components)!
            let end = calendar.date(byAdding: .month, value: 1, to: start)!
                .addingTimeInterval(-1)
            return (start, end)

        case .lastMonth:
            let components = calendar.dateComponents([.year, .month], from: now)
            let thisMonthStart = calendar.date(from: components)!
            let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: thisMonthStart)!
            let lastMonthEnd = thisMonthStart.addingTimeInterval(-1)
            return (lastMonthStart, lastMonthEnd)

        case .thisYear:
            let components = calendar.dateComponents([.year], from: now)
            let start = calendar.date(from: components)!
            let end = calendar.date(byAdding: .year, value: 1, to: start)!
                .addingTimeInterval(-1)
            return (start, end)

        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -30, to: now)!
            return (start, now)

        case .last90Days:
            let start = calendar.date(byAdding: .day, value: -90, to: now)!
            return (start, now)
        }
    }
}

struct CategoryData: Identifiable {
    let id = UUID()
    let name: String
    let amount: Double
    let percentage: Double
    let color: Color
    let icon: String

    var formattedAmount: String {
        let formatter = Formatters.currencyFormatter(for: SettingsManager.shared.currencyCode)
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

struct MonthData: Identifiable {
    let id = UUID()
    let month: String
    let income: Double
    let expense: Double
    let net: Double
}
