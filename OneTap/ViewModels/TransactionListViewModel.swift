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
    @Published var selectedMonth: Date = {
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
    }()

    @Published var loadingState: LoadingState = .idle
    @Published var errorMessage: String?

    // MARK: - Dependencies
    private let transactionRepository: TransactionRepository
    private var cancellables = Set<AnyCancellable>()
    private var dataCancellable: AnyCancellable?

    init(transactionRepository: TransactionRepository) {
        self.transactionRepository = transactionRepository
        setupSubscriptions()
    }

    // MARK: - Subscriptions

    private func setupSubscriptions() {
        Publishers.CombineLatest(
            $searchText,
            $selectedMonth
        )
        .sink { [weak self] searchText, selectedMonth in
            self?.fetchTransactions(
                searchText: searchText,
                selectedMonth: selectedMonth
            )
        }
        .store(in: &cancellables)
    }

    // MARK: - Data Fetching

    private func fetchTransactions(
        searchText: String,
        selectedMonth: Date
    ) {
        loadingState = .loading

        // Cancel previous subscription
        dataCancellable?.cancel()

        // Build predicates
        var predicates: [NSPredicate] = []

        // Search predicate
        if !searchText.isEmpty {
            let titlePredicate = NSPredicate(format: "title CONTAINS[cd] %@", searchText)
            let merchantPredicate = NSPredicate(format: "merchant CONTAINS[cd] %@", searchText)
            predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: [titlePredicate, merchantPredicate]))
        }

        // Date predicate for selected month
        let calendar = Calendar.current
        if let startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth)),
           let endDate = calendar.date(byAdding: .month, value: 1, to: startDate) {
            predicates.append(NSPredicate(format: "date >= %@ AND date < %@", startDate as NSDate, endDate as NSDate))
        }

        let finalPredicate = predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

        // Subscribe to live updates
        dataCancellable = transactionRepository.transactionsByDatePublisher(predicate: finalPredicate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleError(error)
                }
            } receiveValue: { [weak self] groupedTransactions in
                self?.sectionedTransactions = groupedTransactions
                self?.sections = groupedTransactions.keys.sorted(by: >)
                self?.loadingState = .loaded
            }
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

    // MARK: - Month Navigation

    var selectedMonthFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonth)
    }

    func goToPreviousMonth() {
        let calendar = Calendar.current
        if let newMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) {
            selectedMonth = newMonth
        }
    }

    func goToNextMonth() {
        let calendar = Calendar.current
        if let newMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) {
            selectedMonth = newMonth
        }
    }
}
