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
@preconcurrency internal import CoreData

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
    
    // Recurring State
    @Published var isRecurring = false
    @Published var frequency = "Monthly"
    @Published var interval = 1
    @Published var hasOccurrenceLimit = false
    @Published var occurrenceLimitString = ""
    @Published var hasEndDate = false
    @Published var endDate: Date?
    @Published var selectedWeekdays: Set<Int> = [] // 1=Sunday, 2=Monday, etc.
    @Published var selectedMonthDay: Int = 1 // 0=Last Day, 1-31=Specific day
    let frequencies = ["Daily", "Weekly", "Monthly", "Yearly"]

    // Installment State (for credit accounts)
    @Published var isInstallment = false
    @Published var installmentPayments: Int16 = 3
    @Published var installmentBillingDay: Int16 = 1
    let installmentOptions: [Int16] = [3, 6, 9, 12, 18, 24]

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
    private let recurringTransactionRepository: RecurringTransactionRepository
    private let recurringTransactionService: RecurringTransactionService
    private let transferService: TransferService
    private let balanceService: BalanceService
    private let validationService: ValidationService
    private var cancellables = Set<AnyCancellable>()

    init(
        transactionRepository: TransactionRepository,
        accountRepository: AccountRepository,
        categoryRepository: CategoryRepository,
        recurringTransactionRepository: RecurringTransactionRepository,
        recurringTransactionService: RecurringTransactionService,
        transferService: TransferService,
        balanceService: BalanceService,
        validationService: ValidationService
    ) {
        self.transactionRepository = transactionRepository
        self.accountRepository = accountRepository
        self.categoryRepository = categoryRepository
        self.recurringTransactionRepository = recurringTransactionRepository
        self.recurringTransactionService = recurringTransactionService
        self.transferService = transferService
        self.balanceService = balanceService
        self.validationService = validationService

        observeData()
        setupDefaults()
    }

    deinit {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
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

            // Validate split transaction totals
            if !splitItems.isEmpty {
                let splitTotal = splitItems.reduce(0) { $0 + $1.amount }
                let expectedAmount = Double(amountString) ?? 0

                // Ensure split items have positive amounts
                guard splitItems.allSatisfy({ $0.amount > 0 }) else {
                    throw ValidationError.invalidAmount
                }
                // Ensure at least one split item exists
                guard !splitItems.isEmpty else {
                    throw ValidationError.invalidSplitItems
                }
                // Split total becomes the transaction amount
                guard splitTotal > 0 else {
                    throw ValidationError.invalidAmount
                }

                // CRITICAL: Ensure split items sum equals the expected transaction amount
                // Allow 0.01 tolerance for floating point precision
                guard abs(splitTotal - expectedAmount) < 0.01 else {
                    throw ValidationError.splitItemsMismatch(expected: expectedAmount, actual: splitTotal)
                }
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
            } else if isInstallment && showInstallmentOption {
                // Create installment plan for credit account purchases
                guard let category = selectedCategory else {
                    throw ValidationError.missingCategory
                }

                _ = try await recurringTransactionService.createInstallmentPlan(
                    title: title.isEmpty ? (category.name ?? "Installment") : title,
                    totalAmount: totalAmount,
                    numberOfPayments: installmentPayments,
                    account: account,
                    category: category,
                    subCategory: selectedSubCategory,
                    merchant: merchant.isEmpty ? nil : merchant,
                    notes: note.isEmpty ? nil : note,
                    firstPaymentImmediate: true,
                    billingDay: installmentBillingDay,
                    annualInterestRate: 0 // No interest for simple installments
                )
            } else {
                // Regular transaction or split transaction
                let transactionTitle: String
                if !splitItems.isEmpty {
                    transactionTitle = "Split Transaction (\(splitItems.count) Items)"
                } else {
                    transactionTitle = title
                }

                if isRecurring {
                    // Prepare weekly days string
                    let weeklyDaysString: String? = frequency == "Weekly" && !selectedWeekdays.isEmpty
                        ? selectedWeekdays.sorted().map { String($0) }.joined(separator: ",")
                        : nil

                    // Prepare monthly day
                    let monthlyDayValue: Int? = frequency == "Monthly" ? selectedMonthDay : nil

                    // Create Recurring Template
                    let recurring = try recurringTransactionRepository.createRecurring(
                        amount: totalAmount,
                        frequency: frequency,
                        startDate: transactionDate,
                        type: selectedType,
                        account: account,
                        category: splitItems.isEmpty ? selectedCategory : splitItems.first?.category,
                        subCategory: splitItems.isEmpty ? selectedSubCategory : nil,
                        title: transactionTitle.isEmpty ? nil : transactionTitle,
                        merchant: merchant.isEmpty ? nil : merchant,
                        notes: note.isEmpty ? nil : note,
                        toAccount: nil,
                        occurrenceLimit: occurrenceLimit,
                        endDate: hasEndDate ? endDate : nil,
                        interval: interval,
                        weeklyDays: weeklyDaysString,
                        monthlyDay: monthlyDayValue
                    )

                    // Add split items to template if any
                    if !splitItems.isEmpty {
                        try recurringTransactionRepository.addSplitItems(splitItems, to: recurring)
                    }

                    try recurringTransactionRepository.save()

                    // Process recurring transactions to create any due instances
                    // (This will create the first transaction if startDate <= today)
                    try await recurringTransactionService.processRecurringTransactions()
                } else {
                    // Create one-time transaction
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
                    // Note: Budget spent is now calculated dynamically, no update needed here
                }
            }

            finishLoading()

        } catch let error as ValidationError {
            handleError(error)
        } catch {
            handleError(error)
        }
    }
}
