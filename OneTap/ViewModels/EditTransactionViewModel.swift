//
//  EditTransactionViewModel.swift
//  OneTap
//
//  ViewModel for editing existing transactions
//  Replaces logic from EditTransactionView.swift (lines 224-329)
//

import Foundation
import SwiftUI
import Combine
internal import CoreData

@MainActor
class EditTransactionViewModel: ObservableObject, ViewModelProtocol {
    // MARK: - Published State
    @Published var amountString: String
    @Published var selectedType: TransactionType
    @Published var selectedCategory: Category?
    @Published var selectedSubCategory: SubCategory?
    @Published var selectedAccount: Account?
    @Published var toAccount: Account?
    @Published var transactionDate: Date
    @Published var title: String
    @Published var merchant: String
    @Published var note: String
    @Published var splitItems: [SplitItemData] = []
    
    // Recurring State
    @Published var isRecurring = false
    @Published var frequency = "Monthly"

    // Data from repositories
    @Published var categories: [Category] = []
    @Published var accounts: [Account] = []
    @Published var merchantSuggestions: [String] = []

    @Published var loadingState: LoadingState = .idle
    @Published var errorMessage: String?

    // MARK: - Dependencies
    private let transaction: Transaction
    private let transactionRepository: TransactionRepository
    private let accountRepository: AccountRepository
    private let categoryRepository: CategoryRepository
    private let transferService: TransferService
    private let balanceService: BalanceService
    private var cancellables = Set<AnyCancellable>()

    init(
        transaction: Transaction,
        transactionRepository: TransactionRepository,
        accountRepository: AccountRepository,
        categoryRepository: CategoryRepository,
        transferService: TransferService,
        balanceService: BalanceService
    ) {
        self.transaction = transaction
        self.transactionRepository = transactionRepository
        self.accountRepository = accountRepository
        self.categoryRepository = categoryRepository
        self.transferService = transferService
        self.balanceService = balanceService

        // Initialize state from transaction
        self.amountString = Self.formatAmount(transaction.amount)
        self.selectedType = transaction.typeEnum
        self.selectedCategory = transaction.category
        self.selectedSubCategory = transaction.subCategory
        self.selectedAccount = transaction.account
        self.transactionDate = transaction.date ?? Date()
        self.title = transaction.title ?? ""
        self.merchant = transaction.merchant ?? ""
        self.note = transaction.notes ?? ""

        // Load data
        loadData()
        observeData()

        // Load split items
        loadSplitItems()

        // Load related transaction if transfer
        if transaction.typeEnum == .transfer,
           let relatedID = transaction.relatedTransactionID,
           let linked = transactionRepository.fetchRelatedTransaction(for: relatedID) {
            self.toAccount = linked.account
        }
    }

    // MARK: - Computed Properties

    var isValid: Bool {
        guard let amount = Double(amountString), amount > 0 else { return false }
        guard selectedAccount != nil else { return false }

        if selectedType == .transfer {
            return toAccount != nil
        } else {
            return selectedCategory != nil
        }
    }

    var totalAmount: Double {
        if splitItems.isEmpty {
            return Double(amountString) ?? 0
        } else {
            return splitItems.reduce(0) { $0 + $1.amount } + (Double(amountString) ?? 0)
        }
    }

    // MARK: - Data Loading

    private func loadData() {
        // Initial fetch
        accounts = accountRepository.fetchAccounts(group: nil)
        categories = categoryRepository.fetchCategories(type: nil)
    }

    private func observeData() {
        // Observe accounts
        accountRepository.accountsPublisher()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] accounts in
                    self?.accounts = accounts
                }
            )
            .store(in: &cancellables)

        // Observe categories
        categoryRepository.categoriesPublisher(type: nil)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] categories in
                    self?.categories = categories
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Private Helpers

    private func loadSplitItems() {
        let items = transaction.itemsArray
        if !items.isEmpty {
            splitItems = items.map { item in
                SplitItemData(
                    title: item.title ?? "",
                    amount: item.amount,
                    category: item.category,
                    subCategory: item.subCategory
                )
            }
        }
    }

    private static func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ""
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
    }

    // MARK: - Actions

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

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func saveChanges() async {
        startLoading()

        do {
            guard let newAmount = Double(amountString), let newAccount = selectedAccount else {
                throw ValidationError.invalidAmount
            }

            let oldDate = transaction.date ?? Date()
            let oldAccount = transaction.account

            // Add final split item if needed
            if !splitItems.isEmpty, newAmount > 0, let category = selectedCategory {
                let lastItem = SplitItemData(
                    title: note.isEmpty ? (category.name ?? "") : note,
                    amount: newAmount,
                    category: category,
                    subCategory: selectedSubCategory
                )
                splitItems.append(lastItem)
            }

            // Calculate new total
            let finalAmount = splitItems.isEmpty ? newAmount : splitItems.reduce(0) { $0 + $1.amount }

            // Prepare title
            let transactionTitle: String
            if !splitItems.isEmpty {
                transactionTitle = "Split Transaction (\(splitItems.count) Items)"
            } else {
                transactionTitle = title
            }

            // Update main transaction
            let updateData = TransactionUpdateData(
                title: transactionTitle,
                amount: finalAmount,
                date: transactionDate,
                type: selectedType,
                account: newAccount,
                category: splitItems.isEmpty ? selectedCategory : splitItems.first?.category,
                subCategory: splitItems.isEmpty ? selectedSubCategory : nil,
                merchant: merchant.isEmpty ? nil : merchant,
                notes: note.isEmpty ? nil : note
            )

            try transactionRepository.updateTransaction(transaction, with: updateData)

            // Handle linked transaction for transfers
            if let relatedID = transaction.relatedTransactionID,
               let linkedTransaction = transactionRepository.fetchRelatedTransaction(for: relatedID) {
                let linkedData = TransactionUpdateData(
                    title: nil,
                    amount: finalAmount,
                    date: transactionDate,
                    type: nil,
                    account: toAccount,
                    category: nil,
                    subCategory: nil,
                    merchant: nil,
                    notes: nil
                )
                try transactionRepository.updateTransaction(linkedTransaction, with: linkedData)
            }

            // Update split items (delete old, create new)
            try transactionRepository.clearSplitItems(for: transaction)
            if !splitItems.isEmpty {
                try transactionRepository.addSplitItems(splitItems, to: transaction)
            }

            try transactionRepository.save()

            // Recalculate balances
            let earliestDate = min(oldDate, transactionDate)
            var accountsToRecalculate: [NSManagedObjectID] = []

            if let oldAcc = oldAccount {
                accountsToRecalculate.append(oldAcc.objectID)
            }
            if newAccount != oldAccount {
                accountsToRecalculate.append(newAccount.objectID)
            }
            if let destAcc = toAccount, destAcc != newAccount && destAcc != oldAccount {
                accountsToRecalculate.append(destAcc.objectID)
            }

            try await balanceService.recalculateBalances(for: accountsToRecalculate, from: earliestDate)

            finishLoading()

        } catch {
            handleError(error)
        }
    }
}
