//
//  AddRecurringTransactionViewModel.swift
//  OneTap
//
//  ViewModel for adding new recurring transactions
//

import Foundation
import SwiftUI
import Combine
@preconcurrency internal import CoreData

@MainActor
class AddRecurringTransactionViewModel: ObservableObject, ViewModelProtocol {
    // MARK: - Published State
    @Published var amountString = "0"
    @Published var selectedType: TransactionType = .expense
    @Published var selectedCategory: Category?
    @Published var selectedSubCategory: SubCategory?
    @Published var selectedAccount: Account?
    @Published var startDate = Date()
    @Published var title = ""
    @Published var merchant = ""
    @Published var note = ""
    @Published var splitItems: [SplitItemData] = []

    // Recurring-specific
    @Published var frequency = "Monthly"
    @Published var interval = 1
    @Published var hasOccurrenceLimit = false
    @Published var occurrenceLimitString = ""
    @Published var hasEndDate = false
    @Published var endDate: Date?
    @Published var selectedWeekdays: Set<Int> = [] // 1=Sunday, 2=Monday, etc.
    @Published var selectedMonthDay: Int = 1 // 0=Last Day, 1-31=Specific day
    @Published var requiresConfirmation = false // User must approve each transaction
    let frequencies = ["Daily", "Weekly", "Monthly", "Yearly"]

    // Data from repositories
    @Published var categories: [Category] = []
    @Published var accounts: [Account] = []

    @Published var loadingState: LoadingState = .idle
    @Published var errorMessage: String?

    // MARK: - Dependencies
    private let recurringTransactionRepository: RecurringTransactionRepository
    private let accountRepository: AccountRepository
    private let categoryRepository: CategoryRepository
    private let recurringTransactionService: RecurringTransactionService
    private let validationService: ValidationService
    private var cancellables = Set<AnyCancellable>()

    init(
        recurringTransactionRepository: RecurringTransactionRepository,
        accountRepository: AccountRepository,
        categoryRepository: CategoryRepository,
        recurringTransactionService: RecurringTransactionService,
        validationService: ValidationService
    ) {
        self.recurringTransactionRepository = recurringTransactionRepository
        self.accountRepository = accountRepository
        self.categoryRepository = categoryRepository
        self.recurringTransactionService = recurringTransactionService
        self.validationService = validationService

        observeData()
        setupDefaults()
    }

    // MARK: - Computed Properties

    var isValid: Bool {
        // If we have split items, amount can be zero
        if splitItems.isEmpty {
            guard let amount = Double(amountString), amount > 0 else {
                return false
            }
            return selectedAccount != nil && selectedCategory != nil
        }

        // With split items, we only need account
        return selectedAccount != nil
    }

    var totalAmount: Double {
        if splitItems.isEmpty {
            return Double(amountString) ?? 0
        } else {
            return splitItems.reduce(0) { $0 + $1.amount } + (Double(amountString) ?? 0)
        }
    }

    var occurrenceLimit: Int? {
        guard hasOccurrenceLimit, let limit = Int(occurrenceLimitString), limit > 0 else {
            return nil
        }
        return limit
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

    private func setupDefaults() {
        // Set default account to first one when loaded
        $accounts
            .compactMap { $0.first }
            .first()
            .assign(to: &$selectedAccount)

        // Update categories based on selected type
        $selectedType
            .sink { [weak self] type in
                guard let self = self else { return }
                let filtered = self.categories.filter { $0.typeEnum == type }
                if let current = self.selectedCategory,
                   !filtered.contains(where: { $0.id == current.id }) {
                    self.selectedCategory = filtered.first
                }
            }
            .store(in: &cancellables)

        // Clear subcategory when category changes
        $selectedCategory
            .sink { [weak self] _ in
                self?.selectedSubCategory = nil
            }
            .store(in: &cancellables)

        // Set default values based on frequency
        $frequency
            .sink { [weak self] frequency in
                guard let self = self else { return }
                switch frequency {
                case "Weekly":
                    // Default to today's weekday if none selected
                    if self.selectedWeekdays.isEmpty {
                        let weekday = Calendar.current.component(.weekday, from: Date())
                        self.selectedWeekdays = [weekday]
                    }
                case "Monthly":
                    // Default to today's day of month
                    let day = Calendar.current.component(.day, from: Date())
                    self.selectedMonthDay = day
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Split Items Management

    func addSplitItem() {
        guard let amount = Double(amountString), amount > 0, let category = selectedCategory else {
            return
        }

        let item = SplitItemData(
            title: note.isEmpty ? (category.name ?? "") : note,
            amount: amount,
            category: category,
            subCategory: selectedSubCategory
        )

        splitItems.append(item)
        amountString = "0"
        note = ""
        selectedSubCategory = nil
    }

    func removeSplitItem(at index: Int) {
        guard index < splitItems.count else { return }
        splitItems.remove(at: index)
    }

    // MARK: - Actions

    func saveRecurringTransaction() async {
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

            guard let account = selectedAccount else {
                throw ValidationError.missingAccount
            }

            // Validate category if no split items
            if splitItems.isEmpty {
                guard selectedCategory != nil else {
                    throw ValidationError.missingCategory
                }
            }

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
                startDate: startDate,
                type: selectedType,
                account: account,
                category: splitItems.isEmpty ? selectedCategory : splitItems.first?.category,
                subCategory: splitItems.isEmpty ? selectedSubCategory : nil,
                title: title.isEmpty ? nil : title,
                merchant: merchant.isEmpty ? nil : merchant,
                notes: note.isEmpty ? nil : note,
                toAccount: nil,
                occurrenceLimit: occurrenceLimit,
                endDate: hasEndDate ? endDate : nil,
                interval: interval,
                weeklyDays: weeklyDaysString,
                monthlyDay: monthlyDayValue
            )

            // Set confirmation requirement
            recurring.requiresConfirmation = requiresConfirmation

            // Add split items if present
            if !splitItems.isEmpty {
                try recurringTransactionRepository.addSplitItems(splitItems, to: recurring)
            }

            try recurringTransactionRepository.save()

            // Process recurring transactions to create any due instances
            try await recurringTransactionService.processRecurringTransactions()

            finishLoading()

        } catch let error as ValidationError {
            handleError(error)
        } catch {
            handleError(error)
        }
    }
}
