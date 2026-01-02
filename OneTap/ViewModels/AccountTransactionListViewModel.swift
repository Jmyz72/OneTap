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
    @Published var transactions: [Transaction] = []
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

        // Use repository to get a publisher for live updates
        dataCancellable = transactionRepository.transactionsPublisher(for: account.objectID, from: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleError(error)
                }
            } receiveValue: { [weak self] transactions in
                guard let self = self else { return }

                // Apply filters in memory using objectID comparison for Core Data objects
                var filtered = transactions

                if let category = category {
                    filtered = filtered.filter { transaction in
                        guard let transactionCategory = transaction.category else { return false }
                        return transactionCategory.objectID == category.objectID
                    }
                }

                if let subCategory = subCategory {
                    filtered = filtered.filter { transaction in
                        guard let transactionSubCategory = transaction.subCategory else { return false }
                        return transactionSubCategory.objectID == subCategory.objectID
                    }
                }

                self.transactions = filtered
                self.loadingState = .loaded
            }
    }
}
