//
//  RecurringTransactionsListViewModel.swift
//  OneTap
//
//  ViewModel for listing and managing recurring transactions
//

import Foundation
import Combine
@preconcurrency internal import CoreData

@MainActor
class RecurringTransactionsListViewModel: ObservableObject {
    @Published var recurringTransactions: [RecurringTransaction] = []
    @Published var errorMessage: String?

    private let repository: RecurringTransactionRepository
    private let showInstallments: Bool
    private var cancellables = Set<AnyCancellable>()

    init(repository: RecurringTransactionRepository, showInstallments: Bool = false) {
        self.repository = repository
        self.showInstallments = showInstallments
        observeRecurringTransactions()
    }

    private func observeRecurringTransactions() {
        repository.recurringTransactionsPublisher()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = "Failed to load recurring transactions: \(error.localizedDescription)"
                    }
                },
                receiveValue: { [weak self] transactions in
                    guard let self = self else { return }
                    // Filter based on showInstallments flag
                    if self.showInstallments {
                        // Show only installments
                        self.recurringTransactions = transactions.filter { $0.isInstallment }
                    } else {
                        // Show only regular recurring (exclude installments)
                        self.recurringTransactions = transactions.filter { !$0.isInstallment }
                    }
                }
            )
            .store(in: &cancellables)
    }

    func delete(_ recurring: RecurringTransaction) {
        do {
            try repository.delete(recurring)
        } catch {
            errorMessage = "Failed to delete recurring transaction: \(error.localizedDescription)"
        }
    }

    func toggleActive(_ recurring: RecurringTransaction) {
        recurring.isActive.toggle()
        do {
            try repository.save()
        } catch {
            // Revert on failure
            recurring.isActive.toggle()
            errorMessage = "Failed to update recurring transaction: \(error.localizedDescription)"
        }
    }

    var isEmpty: Bool {
        recurringTransactions.isEmpty
    }
}
