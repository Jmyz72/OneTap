//
//  AccountTransactionListViewModel.swift
//  OneTap
//
//  ViewModel for fetching transactions specific to an account.
//  Uses TransactionRepository to align with MVVM architecture.
//

import Foundation
import SwiftUI
@preconcurrency internal import CoreData
import Combine

@MainActor
class AccountTransactionListViewModel: ObservableObject, ViewModelProtocol {
    @Published var sectionedTransactions: [String: [Transaction]] = [:]
    @Published var sections: [String] = []
    @Published var selectedCategoryFilter: Category?
    @Published var selectedSubCategoryFilter: SubCategory?

    @Published var loadingState: LoadingState = .idle
    @Published var errorMessage: String?
    @Published var debugInfo: String = "Init..."

    private let account: Account
    private let transactionRepository: TransactionRepository
    private var cancellables = Set<AnyCancellable>()
    private var dataCancellable: AnyCancellable?

    init(account: Account, transactionRepository: TransactionRepository) {
        self.account = account
        self.transactionRepository = transactionRepository

        // Setup subscriptions. CombineLatest will fire once immediately upon subscription
        // with the initial nil values, which will trigger the first fetch.
        setupSubscriptions()
    }

    deinit {
        dataCancellable?.cancel()
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    private func setupSubscriptions() {
        Publishers.CombineLatest(
            $selectedCategoryFilter,
            $selectedSubCategoryFilter
        )
        // Ensure we don't block the init by performing any work here
        .sink { [weak self] category, subCategory in
            self?.fetchTransactions(
                category: category,
                subCategory: subCategory
            )
        }
        .store(in: &cancellables)
    }

    private func fetchTransactions(
        category: Category?,
        subCategory: SubCategory?
    ) {
        // Use MainActor.run to ensure we are on the main thread without the delay of DispatchQueue.main
        // since this class is already @MainActor.
        loadingState = .loading
        debugInfo += "\nFetch called"

        // Cancel previous subscription
        dataCancellable?.cancel()

        // Build predicates
        var predicates: [NSPredicate] = []
        predicates.append(NSPredicate(format: "account == %@", account))

        if let category = category {
            predicates.append(NSPredicate(format: "category == %@", category))
        }

        if let subCategory = subCategory {
            predicates.append(NSPredicate(format: "subCategory == %@", subCategory))
        }

        let finalPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

        // Use repository to get a publisher for live updates
        // REMOVED .receive(on: DispatchQueue.main) to ensure synchronous emission of initial value
        dataCancellable = transactionRepository.transactionsByDatePublisher(predicate: finalPredicate)
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.debugInfo += "\nOutput received"
            })
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.debugInfo += "\nError: \(error.localizedDescription)"
                    self?.handleError(error)
                    self?.loadingState = .loaded
                }
            } receiveValue: { [weak self] groupedTransactions in
                guard let self = self else { return }
                self.debugInfo += "\nSuccess: \(groupedTransactions.count) items"
                self.sectionedTransactions = groupedTransactions
                self.sections = groupedTransactions.keys.sorted(by: >)
                self.loadingState = .loaded
            }
    }
    
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
