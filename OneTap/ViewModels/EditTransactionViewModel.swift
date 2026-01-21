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
@preconcurrency internal import CoreData

@MainActor
class EditTransactionViewModel: ObservableObject, ViewModelProtocol, MerchantPickerViewModel, RecurringPickerViewModel {
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
    @Published var adjustments: [AdjustmentData] = []

    // Recurring State
    @Published var isRecurring = false
    @Published var frequency = "Monthly"
    @Published var interval = 1
    @Published var hasOccurrenceLimit = false
    @Published var occurrenceLimitString = ""
    @Published var hasEndDate = false
    @Published var endDate: Date?
    @Published var selectedWeekdays: Set<Int> = []
    @Published var selectedMonthDay: Int = 1
    @Published var requiresConfirmation = false
    let frequencies = ["Daily", "Weekly", "Monthly", "Yearly"]

    // Installment State (for credit accounts)
    @Published var isInstallment = false
    @Published var installmentPayments: Int16 = 3
    @Published var installmentBillingDay: Int16 = 1
    let installmentOptions: [Int16] = [3, 6, 9, 12, 18, 24]

    // Exclusion State
    @Published var excludeFromReports: Bool

    // Claim State
    @Published var markAsClaim = false

    // Data from repositories
    @Published var categories: [Category] = []
    @Published var accounts: [Account] = []
    @Published var merchantSuggestions: [String] = []
    @Published var recentMerchants: [String] = []

    @Published var loadingState: LoadingState = .idle
    @Published var errorMessage: String?

    // MARK: - Dependencies
    private let transaction: Transaction
    private let transactionRepository: TransactionRepository
    private let accountRepository: AccountRepository
    private let categoryRepository: CategoryRepository
    private let claimRepository: ClaimRepository
    private let transferService: TransferService
    private let balanceService: BalanceService
    private let claimService: ClaimService
    private var cancellables = Set<AnyCancellable>()

    // Track existing claim for deletion handling
    private var existingClaim: Claim?

    init(
        transaction: Transaction,
        transactionRepository: TransactionRepository,
        accountRepository: AccountRepository,
        categoryRepository: CategoryRepository,
        claimRepository: ClaimRepository,
        transferService: TransferService,
        balanceService: BalanceService,
        claimService: ClaimService
    ) {
        self.transaction = transaction
        self.transactionRepository = transactionRepository
        self.accountRepository = accountRepository
        self.categoryRepository = categoryRepository
        self.claimRepository = claimRepository
        self.transferService = transferService
        self.balanceService = balanceService
        self.claimService = claimService

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
        self.excludeFromReports = transaction.excludeFromReports

        // Load existing claim if any
        if let transactionID = transaction.id {
            self.existingClaim = claimRepository.fetchClaim(for: transactionID)
            self.markAsClaim = existingClaim != nil
        }

        // Load data
        loadData()
        observeData()

        // Load split items and adjustments
        loadSplitItems()
        loadAdjustments()

        // Load related transaction if transfer
        if transaction.typeEnum == .transfer,
           let relatedID = transaction.relatedTransactionID,
           let linked = transactionRepository.fetchRelatedTransaction(for: relatedID) {
            self.toAccount = linked.account
        }
    }

    // MARK: - Computed Properties

    var isValid: Bool {
        // Convert cents to dollars
        guard let cents = Double(amountString) else { return false }
        let amount = cents / 100.0

        // Allow zero amounts
        guard amount >= 0 else { return false }
        guard selectedAccount != nil else { return false }

        if selectedType == .transfer {
            return toAccount != nil
        } else {
            return selectedCategory != nil
        }
    }

    var totalAmount: Double {
        if splitItems.isEmpty {
            // Convert cents to dollars
            let cents = Double(amountString) ?? 0
            return cents / 100.0
        } else {
            // When split items exist, use their sum as the transaction amount
            return splitItems.reduce(0) { $0 + $1.amount }
        }
    }

    var occurrenceLimit: Int? {
        guard hasOccurrenceLimit, let limit = Int(occurrenceLimitString), limit > 0 else {
            return nil
        }
        return limit
    }

    /// Shows installment option only for credit accounts (Credit Card, BNPL)
    var showInstallmentOption: Bool {
        guard let account = selectedAccount else { return false }
        return account.isLiability && selectedType == .expense
    }

    /// Monthly payment amount for installment
    var installmentMonthlyPayment: Double {
        guard installmentPayments > 0 else { return 0 }
        return totalAmount / Double(installmentPayments)
    }

    /// Formatted monthly payment for display
    var formattedInstallmentPayment: String {
        let code = selectedAccount?.currency ?? SettingsManager.shared.currencyCode
        let formatter = Formatters.currencyFormatter(for: code)
        return formatter.string(from: NSNumber(value: installmentMonthlyPayment)) ?? "$0"
    }

    // MARK: - Data Loading

    private func loadData() {
        // Initial fetch
        accounts = accountRepository.fetchAccounts(group: nil)
        categories = categoryRepository.fetchCategories(type: nil)
        recentMerchants = transactionRepository.fetchRecentMerchants(limit: 5)
    }

    private func observeData() {
        // Observe accounts
        accountRepository.accountsPublisher()
            .removeDuplicates()
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
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] categories in
                    self?.categories = categories
                }
            )
            .store(in: &cancellables)

        // Auto-toggle exclude when claim is toggled
        $markAsClaim
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] isClaim in
                guard let self = self else { return }
                // Only modify if not controlled by installment
                if !self.isInstallment {
                    if isClaim {
                        // When marking as claim, automatically exclude from reports
                        self.excludeFromReports = true
                    } else {
                        // When unmarking claim, automatically uncheck exclude
                        self.excludeFromReports = false
                    }
                }
            }
            .store(in: &cancellables)

        // Auto-toggle exclude when installment is toggled (takes priority over claim)
        $isInstallment
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] isInstallment in
                guard let self = self else { return }
                if isInstallment {
                    // When marking as installment, automatically exclude from reports
                    self.excludeFromReports = true
                } else {
                    // When unmarking installment, check if claim is active
                    if !self.markAsClaim {
                        // Only uncheck if claim is also inactive
                        self.excludeFromReports = false
                    }
                }
            }
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

    private func loadAdjustments() {
        let adjustmentItems = transaction.adjustmentsArray
        if !adjustmentItems.isEmpty {
            adjustments = adjustmentItems.map { adj in
                AdjustmentData(
                    type: adj.typeEnum,
                    amount: adj.amount,
                    label: adj.label,
                    percentage: adj.percentage > 0 ? adj.percentage : nil
                )
            }
        }
    }

    private static func formatAmount(_ amount: Double) -> String {
        // Convert dollars to cents for input
        let cents = Int(amount * 100)
        return String(cents)
    }

    // MARK: - Actions

    func categoryChanged() {
        selectedSubCategory = nil
    }

    func updateMerchantSuggestions() {
        merchantSuggestions = transactionRepository.fetchUniqueMerchants(matching: merchant)
    }

    func fetchAllMerchants() -> [String] {
        return transactionRepository.fetchUniqueMerchants(matching: "")
    }

    func addSplitItem() {
        guard let cents = Double(amountString), let category = selectedCategory else {
            return
        }

        // Convert cents to dollars
        let amount = cents / 100.0
        guard amount >= 0 else { return }

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
            guard let cents = Double(amountString), let newAccount = selectedAccount else {
                throw ValidationError.invalidAmount
            }

            // Convert cents to dollars
            let newAmount = cents / 100.0

            let oldDate = transaction.date ?? Date()
            let oldAccount = transaction.account

            // Add final split item if needed
            if !splitItems.isEmpty, newAmount >= 0, let category = selectedCategory {
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
            // Use the user's entered title regardless of split items
            let transactionTitle: String = title

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
                notes: note.isEmpty ? nil : note,
                excludeFromReports: excludeFromReports
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
                    notes: nil,
                    excludeFromReports: excludeFromReports
                )
                try transactionRepository.updateTransaction(linkedTransaction, with: linkedData)
            }

            // Update split items (delete old, create new)
            try transactionRepository.clearSplitItems(for: transaction)
            if !splitItems.isEmpty {
                try transactionRepository.addSplitItems(splitItems, to: transaction)
            }

            // Update adjustments (delete old, create new)
            try transactionRepository.clearAdjustments(for: transaction)
            if !adjustments.isEmpty {
                try transactionRepository.addAdjustments(adjustments, to: transaction)
            }

            try transactionRepository.save()

            // Handle claim changes
            if markAsClaim && existingClaim == nil && selectedType == .expense {
                // Create new claim
                _ = try claimService.createClaim(from: transaction)
            } else if !markAsClaim && existingClaim != nil {
                // Delete existing claim (only if not settled)
                if let claim = existingClaim, !claim.isSettled {
                    try claimService.deleteClaim(claim)
                }
            }

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
