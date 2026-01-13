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
    private var cancellables = Set<AnyCancellable>()

    init(repository: RecurringTransactionRepository) {
        self.repository = repository
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
                    self?.recurringTransactions = transactions
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
