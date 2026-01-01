//
//  TransactionListViewModel.swift
//  OneTap
//
//  ViewModel for transaction list with filtering and search
//  Replaces logic from TransactionListView.swift FilteredTransactionList (lines 119-174)
//

import Foundation
import SwiftUI
import Combine

@MainActor
class TransactionListViewModel: ObservableObject, ViewModelProtocol {
    // MARK: - Published State
    @Published var sectionedTransactions: [String: [Transaction]] = [:]
    @Published var sections: [String] = []
    @Published var searchText = ""
    @Published var selectedDateFilter: DateFilter = .all
    @Published var selectedCategoryFilter: Category?

    @Published var loadingState: LoadingState = .idle
    @Published var errorMessage: String?

    // MARK: - Date Filter Enum
    enum DateFilter: String, CaseIterable, Identifiable {
        case all = "All Time"
        case thisMonth = "This Month"
        case lastMonth = "Last Month"
        case thisYear = "This Year"

        var id: String { rawValue }

        var dateRange: (start: Date, end: Date)? {
            let calendar = Calendar.current
            let now = Date()

            switch self {
            case .all:
                return nil
            case .thisMonth:
                guard let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
                      let end = calendar.date(byAdding: .month, value: 1, to: start) else { return nil }
                return (start, end)
            case .lastMonth:
                guard let startOfThisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
                      let start = calendar.date(byAdding: .month, value: -1, to: startOfThisMonth) else { return nil }
                return (start, startOfThisMonth)
            case .thisYear:
                guard let start = calendar.date(from: calendar.dateComponents([.year], from: now)),
                      let end = calendar.date(byAdding: .year, value: 1, to: start) else { return nil }
                return (start, end)
            }
        }
    }

    // MARK: - Dependencies
    private let transactionRepository: TransactionRepository
    private var cancellables = Set<AnyCancellable>()

    init(transactionRepository: TransactionRepository) {
        self.transactionRepository = transactionRepository
        setupSubscriptions()
    }

    // MARK: - Subscriptions

    private func setupSubscriptions() {
        Publishers.CombineLatest3(
            $searchText,
            $selectedDateFilter,
            $selectedCategoryFilter
        )
        .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
        .sink { [weak self] searchText, dateFilter, category in
            self?.fetchTransactions(
                searchText: searchText,
                dateFilter: dateFilter,
                category: category
            )
        }
        .store(in: &cancellables)
    }

    // MARK: - Data Fetching

    private func fetchTransactions(
        searchText: String,
        dateFilter: DateFilter,
        category: Category?
    ) {
        loadingState = .loading

        // Build predicates
        var predicates: [NSPredicate] = []

        // Search predicate
        if !searchText.isEmpty {
            let titlePredicate = NSPredicate(format: "title CONTAINS[cd] %@", searchText)
            let merchantPredicate = NSPredicate(format: "merchant CONTAINS[cd] %@", searchText)
            predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: [titlePredicate, merchantPredicate]))
        }

        // Category predicate
        if let category = category {
            predicates.append(NSPredicate(format: "category == %@", category))
        }

        // Date predicate
        if let (startDate, endDate) = dateFilter.dateRange {
            predicates.append(NSPredicate(format: "date >= %@ AND date < %@", startDate as NSDate, endDate as NSDate))
        }

        let finalPredicate = predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        let sortDescriptors = [NSSortDescriptor(keyPath: \Transaction.date, ascending: false)]

        let transactions = transactionRepository.fetch(predicate: finalPredicate, sortDescriptors: sortDescriptors)
        processSections(transactions)
        loadingState = .loaded
    }

    private func processSections(_ transactions: [Transaction]) {
        let grouped = Dictionary(grouping: transactions) { transaction in
            guard let date = transaction.date else { return "" }
            return Formatters.date.string(from: date)
        }

        sectionedTransactions = grouped
        sections = grouped.keys.sorted(by: >)
    }

    // MARK: - Helpers

    func calculateSectionTotal(for section: String) -> String {
        let transactions = sectionedTransactions[section] ?? []
        let total = transactions.reduce(0.0) { sum, transaction in
            switch transaction.typeEnum {
            case .expense:
                return sum - transaction.amount
            case .income:
                return sum + transaction.amount
            default:
                return sum
            }
        }

        let formatter = Formatters.currencyFormatter(for: SettingsManager.shared.currencyCode)
        return formatter.string(from: NSNumber(value: total)) ?? "$0.00"
    }
}
