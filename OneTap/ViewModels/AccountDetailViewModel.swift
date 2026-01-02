//
//  AccountDetailViewModel.swift
//  OneTap
//
//  ViewModel for account detail view
//

import Foundation
import SwiftUI
import Combine
internal import CoreData

@MainActor
class AccountDetailViewModel: ObservableObject, ViewModelProtocol {
    // MARK: - Published State
    @Published var transactions: [Transaction] = []
    @Published var loadingState: LoadingState = .idle
    @Published var errorMessage: String?
    @Published var shouldDismiss = false

    // MARK: - Dependencies
    private let account: Account
    private let accountRepository: AccountRepository
    private let transactionRepository: TransactionRepository
    private var cancellables = Set<AnyCancellable>()

    init(
        account: Account,
        accountRepository: AccountRepository,
        transactionRepository: TransactionRepository
    ) {
        self.account = account
        self.accountRepository = accountRepository
        self.transactionRepository = transactionRepository

        setupSubscriptions()
    }

    // MARK: - Subscriptions

    private func setupSubscriptions() {
        transactionRepository.transactionsPublisher(for: account.objectID, from: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleError(error)
                }
            } receiveValue: { [weak self] transactions in
                self?.transactions = transactions
                self?.loadingState = .loaded
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    func deleteAccount() async {
        startLoading()

        do {
            // Delete account (cascade deletes transactions)
            try accountRepository.deleteAccount(account)
            try accountRepository.save()

            finishLoading()
            shouldDismiss = true

        } catch {
            handleError(error)
        }
    }

    // MARK: - Formatting

    func formatBalance() -> String {
        let formatter = Formatters.currencyFormatter(for: account.currency ?? SettingsManager.shared.currencyCode)
        return formatter.string(from: NSNumber(value: account.balance)) ?? "$0.00"
    }

    func formatCurrency(_ amount: Double) -> String {
        let formatter = Formatters.currencyFormatter(for: account.currency ?? SettingsManager.shared.currencyCode)
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }

    func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "N/A" }
        return Formatters.date.string(from: date)
    }
}
