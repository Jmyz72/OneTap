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
    private let exchangeRateService: ExchangeRateService
    private var cancellables = Set<AnyCancellable>()
    private var calculateTotalsTask: Task<Void, Never>?

    init(accountRepository: AccountRepository, exchangeRateService: ExchangeRateService) {
        self.accountRepository = accountRepository
        self.exchangeRateService = exchangeRateService
        setupSubscriptions()
    }

    deinit {
        calculateTotalsTask?.cancel()
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
        let baseCurrency = SettingsManager.shared.currencyCode

        // Cancel any in-flight calculation to prevent race conditions
        calculateTotalsTask?.cancel()

        // Capture accounts for use in task
        let currentAccounts = accounts

        // Use a Task to handle async currency conversion
        calculateTotalsTask = Task {
            var assets: Double = 0
            var liabilities: Double = 0

            for account in currentAccounts {
                // Check for cancellation between iterations
                guard !Task.isCancelled else { return }

                let accountCurrency = account.currency ?? baseCurrency
                let balance = account.balance

                // Convert to base currency if different
                let convertedBalance = await exchangeRateService.convertToBase(
                    amount: abs(balance),
                    fromCurrency: accountCurrency,
                    baseCurrency: baseCurrency
                )

                if account.isLiability {
                    liabilities += convertedBalance
                } else {
                    assets += convertedBalance
                }
            }

            // Only update state if not cancelled
            guard !Task.isCancelled else { return }
            totalAssets = assets
            totalLiabilities = liabilities
            netWorth = assets - liabilities
        }
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

    // Note: formatCurrency is provided by ViewModelProtocol extension

    func formatAccountBalance(_ account: Account) -> String {
        let formatter = Formatters.currencyFormatter(for: account.currency ?? SettingsManager.shared.currencyCode)
        return formatter.string(from: NSNumber(value: account.balance)) ?? "$0.00"
    }
}
