//
//  AddRecurringTransactionViewModel.swift
//  OneTap
//
//  ViewModel for adding new recurring transactions
//

import Foundation
import SwiftUI
import Combine
internal import CoreData

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

    // Recurring-specific
    @Published var frequency = "Monthly"
    @Published var interval = 1
    @Published var hasOccurrenceLimit = false
    @Published var occurrenceLimitString = ""
    @Published var hasEndDate = false
    @Published var endDate: Date?
    @Published var selectedWeekdays: Set<Int> = [] // 1=Sunday, 2=Monday, etc.
    @Published var selectedMonthDay: Int = 1 // 0=Last Day, 1-31=Specific day
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
        guard let amount = Double(amountString), amount > 0 else { return false }
        return selectedAccount != nil && selectedCategory != nil
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

    // MARK: - Actions

    func saveRecurringTransaction() async {
        startLoading()

        do {
            guard let amount = Double(amountString), amount > 0 else {
                throw ValidationError.invalidAmount
            }

            guard let account = selectedAccount else {
                throw ValidationError.missingAccount
            }

            guard let category = selectedCategory else {
                throw ValidationError.missingCategory
            }

            // Prepare weekly days string
            let weeklyDaysString: String? = frequency == "Weekly" && !selectedWeekdays.isEmpty
                ? selectedWeekdays.sorted().map { String($0) }.joined(separator: ",")
                : nil

            // Prepare monthly day
            let monthlyDayValue: Int? = frequency == "Monthly" ? selectedMonthDay : nil

            // Create Recurring Template
            _ = try recurringTransactionRepository.createRecurring(
                amount: amount,
                frequency: frequency,
                startDate: startDate,
                type: selectedType,
                account: account,
                category: category,
                subCategory: selectedSubCategory,
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
