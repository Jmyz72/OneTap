//
//  AddTransactionViewModel.swift
//  OneTap
//
//  ViewModel for adding new transactions
//  Replaces logic from AddTransactionView.swift (lines 201-263)
//

import Foundation
import SwiftUI
import Combine
internal import CoreData

@MainActor
class AddTransactionViewModel: ObservableObject, ViewModelProtocol {
    // MARK: - Published State
    @Published var amountString = "0"
    @Published var selectedType: TransactionType = .expense
    @Published var selectedCategory: Category?
    @Published var selectedSubCategory: SubCategory?
    @Published var selectedAccount: Account?
    @Published var toAccount: Account?
    @Published var transactionDate = Date()
    @Published var title = ""
    @Published var merchant = ""
    @Published var note = ""
    @Published var splitItems: [SplitItemData] = []

    // Data from repositories
    @Published var categories: [Category] = []
    @Published var accounts: [Account] = []
    @Published var merchantSuggestions: [String] = []

    @Published var loadingState: LoadingState = .idle
    @Published var errorMessage: String?

    // MARK: - Dependencies
    private let transactionRepository: TransactionRepository
    private let accountRepository: AccountRepository
    private let categoryRepository: CategoryRepository
    private let transferService: TransferService
    private let balanceService: BalanceService
    private let validationService: ValidationService
    private var cancellables = Set<AnyCancellable>()

    init(
        transactionRepository: TransactionRepository,
        accountRepository: AccountRepository,
        categoryRepository: CategoryRepository,
        transferService: TransferService,
        balanceService: BalanceService,
        validationService: ValidationService
    ) {
        self.transactionRepository = transactionRepository
        self.accountRepository = accountRepository
        self.categoryRepository = categoryRepository
        self.transferService = transferService
        self.balanceService = balanceService
        self.validationService = validationService

        observeData()
        setupDefaults()
    }

    // MARK: - Computed Properties

    var isValid: Bool {
        guard let amount = Double(amountString), amount > 0 else { return false }

        if splitItems.isEmpty {
            if selectedType == .transfer {
                return selectedAccount != nil && toAccount != nil
            } else {
                return selectedAccount != nil && selectedCategory != nil
            }
        }

        return selectedAccount != nil
    }

    var totalAmount: Double {
        if splitItems.isEmpty {
            return Double(amountString) ?? 0
        } else {
            return splitItems.reduce(0) { $0 + $1.amount } + (Double(amountString) ?? 0)
        }
    }

    // MARK: - Observation

    private func observeData() {
        // Observe accounts
        accountRepository.accountsPublisher()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] accounts in
                    self?.accounts = accounts
                    // Set default account if none selected
                    if self?.selectedAccount == nil {
                        self?.selectedAccount = accounts.first
                    }
                }
            )
            .store(in: &cancellables)

        // Observe categories
        categoryRepository.categoriesPublisher(type: nil)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] categories in
                    guard let self = self else { return }
                    self.categories = categories
                    // Don't auto-select category - let user choose
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Actions

    private func setupDefaults() {
        // Initial fetch to set defaults
        accounts = accountRepository.fetchAccounts(group: nil)
        categories = categoryRepository.fetchCategories(type: nil)

        // Auto-select first account (helpful default)
        if selectedAccount == nil {
            selectedAccount = accounts.first
        }
        // Don't auto-select category - let user choose
    }

    func typeChanged(to newType: TransactionType) {
        if newType != .transfer {
            // Clear selections when switching types - let user choose
            selectedCategory = nil
            selectedSubCategory = nil
            splitItems = []
        }
    }

    func categoryChanged() {
        selectedSubCategory = nil
    }

    func updateMerchantSuggestions() {
        merchantSuggestions = transactionRepository.fetchUniqueMerchants(matching: merchant)
    }

    func addSplitItem() {
        guard let amount = Double(amountString), amount > 0, let category = selectedCategory else {
            return
        }

        let title = note.isEmpty ? (category.name ?? "") : note
        let item = SplitItemData(
            title: title,
            amount: amount,
            category: category,
            subCategory: selectedSubCategory
        )

        splitItems.append(item)
        amountString = "0"
        note = ""

        // Haptic feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func saveTransaction() async {
        startLoading()

        do {
            // Add final item to split if needed
            if !splitItems.isEmpty, let amount = Double(amountString), amount > 0, let category = selectedCategory {
                let lastItem = SplitItemData(
                    title: note.isEmpty ? (category.name ?? "") : note,
                    amount: amount,
                    category: category,
                    subCategory: selectedSubCategory
                )
                splitItems.append(lastItem)
            }

            // Validation
            try validationService.validateTransaction(
                amount: totalAmount,
                type: selectedType,
                account: selectedAccount,
                category: selectedCategory,
                toAccount: toAccount
            )

            guard let account = selectedAccount else {
                throw ValidationError.missingAccount
            }

            // Handle transfer separately
            if selectedType == .transfer, let destAccount = toAccount {
                _ = try await transferService.createTransfer(
                    amount: totalAmount,
                    date: transactionDate,
                    from: account,
                    to: destAccount,
                    notes: note.isEmpty ? nil : note
                )
            } else {
                // Regular transaction or split transaction
                let transactionTitle = splitItems.isEmpty
                    ? (title.isEmpty ? (selectedCategory?.name ?? "Transaction") : title)
                    : "Split Transaction (\(splitItems.count) Items)"

                let transaction = try transactionRepository.createTransaction(
                    title: transactionTitle,
                    amount: totalAmount,
                    type: selectedType,
                    date: transactionDate,
                    account: account,
                    category: splitItems.isEmpty ? selectedCategory : splitItems.first?.category,
                    subCategory: splitItems.isEmpty ? selectedSubCategory : nil,
                    merchant: merchant.isEmpty ? nil : merchant,
                    notes: note.isEmpty ? nil : note
                )

                // Add split items if any
                if !splitItems.isEmpty {
                    try transactionRepository.addSplitItems(splitItems, to: transaction)
                }

                try transactionRepository.save()

                // Recalculate balance
                try await balanceService.recalculateBalances(for: account.objectID, from: transactionDate)
            }

            finishLoading()

        } catch let error as ValidationError {
            handleError(error)
        } catch {
            handleError(error)
        }
    }
}
