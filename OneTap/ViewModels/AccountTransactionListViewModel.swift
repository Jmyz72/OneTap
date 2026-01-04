//
//  AccountTransactionListViewModel.swift
//  OneTap
//
//  ViewModel for fetching transactions specific to an account.
//  Uses TransactionRepository to align with MVVM architecture.
//

import Foundation
import SwiftUI
internal import CoreData
import Combine

@MainActor
class AccountTransactionListViewModel: ObservableObject, ViewModelProtocol {
    @Published var sectionedTransactions: [String: [Transaction]] = [:]
    @Published var sections: [String] = []
    @Published var selectedCategoryFilter: Category?
    @Published var selectedSubCategoryFilter: SubCategory?

    @Published var loadingState: LoadingState = .idle
    @Published var errorMessage: String?

    private let account: Account
    private let transactionRepository: TransactionRepository
    private var cancellables = Set<AnyCancellable>()
    private var dataCancellable: AnyCancellable?

    init(account: Account, transactionRepository: TransactionRepository) {
        self.account = account
        self.transactionRepository = transactionRepository
        setupSubscriptions()
    }

    private func setupSubscriptions() {
        Publishers.CombineLatest(
            $selectedCategoryFilter,
            $selectedSubCategoryFilter
        )
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
        loadingState = .loading

        // Cancel previous subscription
        dataCancellable?.cancel()

        // Build predicates
        var predicates: [NSPredicate] = []
        
        if let accountID = account.id {
            predicates.append(NSPredicate(format: "account.id == %@", accountID as CVarArg))
        } else {
            predicates.append(NSPredicate(format: "account == %@", account))
        }

        if let category = category {
            predicates.append(NSPredicate(format: "category == %@", category))
        }

        if let subCategory = subCategory {
            predicates.append(NSPredicate(format: "subCategory == %@", subCategory))
        }

        let finalPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

        // Use repository to get a publisher for live updates
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
