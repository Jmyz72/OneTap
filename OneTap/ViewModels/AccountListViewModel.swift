//
//  AccountListViewModel.swift
//  OneTap
//
//  ViewModel for account list and net worth display
//  Replaces logic from AccountListView.swift (lines 222-248)
//

import Foundation
import SwiftUI
import Combine

@MainActor
class AccountListViewModel: ObservableObject, ViewModelProtocol {
    // MARK: - Published State
    @Published var accounts: [Account] = []
    @Published var groupedAccounts: [AccountGroup: [Account]] = [:]
    @Published var totalAssets: Double = 0
    @Published var totalLiabilities: Double = 0
    @Published var netWorth: Double = 0

    @Published var loadingState: LoadingState = .idle
    @Published var errorMessage: String?

    // MARK: - Dependencies
    private let accountRepository: AccountRepository
    private var cancellables = Set<AnyCancellable>()

    init(accountRepository: AccountRepository) {
        self.accountRepository = accountRepository
        setupSubscriptions()
    }

    deinit {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    // MARK: - Subscriptions

    private func setupSubscriptions() {
        accountRepository.accountsPublisher()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.loadingState = .error(error.localizedDescription)
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] accounts in
                self?.accounts = accounts
                self?.updateGroupedAccounts()
                self?.calculateTotals()
                self?.loadingState = .loaded
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Processing

    private func updateGroupedAccounts() {
        groupedAccounts = Dictionary(grouping: accounts) { $0.group }
    }

    private func calculateTotals() {
        totalAssets = accounts
            .filter { !$0.isLiability }
            .reduce(0) { $0 + $1.balance }

        totalLiabilities = accounts
            .filter { $0.isLiability }
            .reduce(0) { $0 + abs($1.balance) }

        netWorth = totalAssets - totalLiabilities
    }

    // MARK: - Actions

    func fetchAccounts() {
        loadingState = .loading
        // Publisher will trigger update
    }

    func deleteAccount(_ account: Account) async {
        do {
            try accountRepository.deleteAccount(account)
            try accountRepository.save()
        } catch {
            errorMessage = "Failed to delete account: \(error.localizedDescription)"
        }
    }

    // MARK: - Formatting

    func formatCurrency(_ value: Double) -> String {
        let formatter = Formatters.currencyFormatter(for: SettingsManager.shared.currencyCode)
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }

    func formatAccountBalance(_ account: Account) -> String {
        let formatter = Formatters.currencyFormatter(for: account.currency ?? SettingsManager.shared.currencyCode)
        return formatter.string(from: NSNumber(value: account.balance)) ?? "$0.00"
    }
}
