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
class AddTransactionViewModel: ObservableObject, ViewModelProtocol, MerchantPickerViewModel, RecurringPickerViewModel {
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
    @Published var requiresConfirmation = false
    let frequencies = ["Daily", "Weekly", "Monthly", "Yearly"]

    // Installment State (for credit accounts)
    @Published var isInstallment = false
    @Published var installmentPayments: Int16 = 3
    @Published var installmentBillingDay: Int16 = 1
    let installmentOptions: [Int16] = [3, 6, 9, 12, 18, 24]

    // Exclusion State
    @Published var excludeFromReports = false

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
    private let transactionRepository: TransactionRepository
    private let accountRepository: AccountRepository
    private let categoryRepository: CategoryRepository
    private let recurringTransactionRepository: RecurringTransactionRepository
    private let recurringTransactionService: RecurringTransactionService
    private let transferService: TransferService
    private let balanceService: BalanceService
    private let validationService: ValidationService
    private let claimService: ClaimService
    private var cancellables = Set<AnyCancellable>()

    init(
        transactionRepository: TransactionRepository,
        accountRepository: AccountRepository,
        categoryRepository: CategoryRepository,
        recurringTransactionRepository: RecurringTransactionRepository,
        recurringTransactionService: RecurringTransactionService,
        transferService: TransferService,
        balanceService: BalanceService,
        validationService: ValidationService,
        claimService: ClaimService
    ) {
        self.transactionRepository = transactionRepository
        self.accountRepository = accountRepository
        self.categoryRepository = categoryRepository
        self.recurringTransactionRepository = recurringTransactionRepository
        self.recurringTransactionService = recurringTransactionService
        self.transferService = transferService
        self.balanceService = balanceService
        self.validationService = validationService
        self.claimService = claimService

        observeData()
        setupDefaults()
    }

    deinit {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    // MARK: - Computed Properties

    var isValid: Bool {
        // Convert cents to dollars
        guard let cents = Double(amountString) else { return false }
        let amount = cents / 100.0

        // Allow zero amounts
        guard amount >= 0 else { return false }

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

        // Auto-toggle exclude when claim is toggled
        $markAsClaim
            .sink { [weak self] isClaim in
                guard let self = self else { return }
                if isClaim {
                    // When marking as claim, automatically exclude from reports
                    self.excludeFromReports = true
                } else {
                    // When unmarking claim, automatically uncheck exclude
                    self.excludeFromReports = false
                }
            }
            .store(in: &cancellables)

        // Auto-toggle exclude when installment is toggled
        $isInstallment
            .sink { [weak self] isInstallment in
                guard let self = self else { return }
                if isInstallment {
                    // When marking as installment, automatically exclude from reports
                    self.excludeFromReports = true
                } else {
                    // When unmarking installment, automatically uncheck exclude
                    self.excludeFromReports = false
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    private func setupDefaults() {
        // Initial fetch to set defaults
        accounts = accountRepository.fetchAccounts(group: nil)
        categories = categoryRepository.fetchCategories(type: nil)
        recentMerchants = transactionRepository.fetchRecentMerchants(limit: 5)

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

        // Haptic feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func saveTransaction() async {
        startLoading()

        do {
            // Add final item to split if needed
            if !splitItems.isEmpty, let cents = Double(amountString), let category = selectedCategory {
                let amount = cents / 100.0
                if amount >= 0 {
                    let lastItem = SplitItemData(
                        title: note.isEmpty ? (category.name ?? "") : note,
                        amount: amount,
                        category: category,
                        subCategory: selectedSubCategory
                    )
                    splitItems.append(lastItem)
                }
            }

            // Validate split transaction totals
            if !splitItems.isEmpty {
                let splitTotal = splitItems.reduce(0) { $0 + $1.amount }
                let cents = Double(amountString) ?? 0
                let expectedAmount = cents / 100.0

                // Ensure split items have valid amounts
                guard splitItems.allSatisfy({ $0.amount >= 0 }) else {
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

                // CRITICAL: If user entered an amount, ensure split items sum matches it
                // Allow 0.01 tolerance for floating point precision
                // If expectedAmount is 0, split items define the total (no validation needed)
                if expectedAmount > 0 {
                    guard abs(splitTotal - expectedAmount) < 0.01 else {
                        throw ValidationError.splitItemsMismatch(expected: expectedAmount, actual: splitTotal)
                    }
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
                    paymentCycleType: .monthlyFixed,
                    monthlyFixedDay: installmentBillingDay,
                    annualInterestRate: 0 // No interest for simple installments
                )
            } else {
                // Regular transaction or split transaction
                // Use the user's entered title regardless of split items
                let transactionTitle: String = title

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
                        monthlyDay: monthlyDayValue,
                        requiresConfirmation: requiresConfirmation
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
                        notes: note.isEmpty ? nil : note,
                        excludeFromReports: excludeFromReports
                    )

                    // Add split items if any
                    if !splitItems.isEmpty {
                        try transactionRepository.addSplitItems(splitItems, to: transaction)
                    }

                    try transactionRepository.save()

                    // Create claim if marked as claim (only for expenses)
                    if markAsClaim && selectedType == .expense {
                        _ = try claimService.createClaim(from: transaction)
                    }

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
