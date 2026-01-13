//
//  EditRecurringTransactionViewModel.swift
//  OneTap
//
//  ViewModel for editing existing recurring transactions
//

import Foundation
import SwiftUI
import Combine
@preconcurrency internal import CoreData

@MainActor
class EditRecurringTransactionViewModel: ObservableObject, ViewModelProtocol {
    // MARK: - Published State
    @Published var amountString: String
    @Published var selectedType: TransactionType
    @Published var selectedCategory: Category?
    @Published var selectedSubCategory: SubCategory?
    @Published var selectedAccount: Account?
    @Published var startDate: Date
    @Published var title: String
    @Published var merchant: String
    @Published var note: String

    // Recurring-specific
    @Published var frequency: String
    @Published var interval: Int
    @Published var hasOccurrenceLimit: Bool
    @Published var occurrenceLimitString: String
    @Published var hasEndDate: Bool
    @Published var endDate: Date?
    @Published var selectedWeekdays: Set<Int> = [] // 1=Sunday, 2=Monday, etc.
    @Published var selectedMonthDay: Int = 1 // 0=Last Day, 1-31=Specific day
    @Published var isActive: Bool
    let frequencies = ["Daily", "Weekly", "Monthly", "Yearly"]

    // Data from repositories
    @Published var categories: [Category] = []
    @Published var accounts: [Account] = []

    @Published var loadingState: LoadingState = .idle
    @Published var errorMessage: String?

    // MARK: - Dependencies
    private let recurring: RecurringTransaction
    private let recurringTransactionRepository: RecurringTransactionRepository
    private let accountRepository: AccountRepository
    private let categoryRepository: CategoryRepository
    private let validationService: ValidationService
    private var cancellables = Set<AnyCancellable>()

    init(
        recurring: RecurringTransaction,
        recurringTransactionRepository: RecurringTransactionRepository,
        accountRepository: AccountRepository,
        categoryRepository: CategoryRepository,
        validationService: ValidationService
    ) {
        self.recurring = recurring
        self.recurringTransactionRepository = recurringTransactionRepository
        self.accountRepository = accountRepository
        self.categoryRepository = categoryRepository
        self.validationService = validationService

        // Initialize from existing recurring transaction
        self.amountString = String(recurring.amount)
        self.selectedType = TransactionType(rawValue: recurring.type ?? "Expense") ?? .expense
        self.selectedCategory = recurring.category
        self.selectedSubCategory = recurring.subCategory
        self.selectedAccount = recurring.account
        self.startDate = recurring.startDate ?? Date()
        self.title = recurring.title ?? ""
        self.merchant = recurring.merchant ?? ""
        self.note = recurring.notes ?? ""
        self.frequency = recurring.frequency ?? "Monthly"
        self.isActive = recurring.isActive
        self.interval = Int(recurring.interval)

        let limit = recurring.occurrenceLimit
        self.hasOccurrenceLimit = limit > 0
        self.occurrenceLimitString = limit > 0 ? String(limit) : ""

        self.hasEndDate = recurring.endDate != nil
        self.endDate = recurring.endDate

        // Parse weekly days
        if let weeklyDaysString = recurring.weeklyDays, !weeklyDaysString.isEmpty {
            self.selectedWeekdays = Set(weeklyDaysString.split(separator: ",").compactMap { Int($0) })
        }

        // Parse monthly day
        self.selectedMonthDay = Int(recurring.monthlyDay)

        observeData()
        setupObservations()
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

    private func setupObservations() {
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
    }

    // MARK: - Actions

    func saveChanges() async {
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

            // Update recurring transaction
            recurring.amount = amount
            recurring.type = selectedType.rawValue
            recurring.category = category
            recurring.subCategory = selectedSubCategory
            recurring.account = account
            recurring.startDate = startDate
            recurring.title = title.isEmpty ? nil : title
            recurring.merchant = merchant.isEmpty ? nil : merchant
            recurring.notes = note.isEmpty ? nil : note
            recurring.frequency = frequency
            recurring.interval = Int16(interval)
            recurring.isActive = isActive
            recurring.occurrenceLimit = Int16(occurrenceLimit ?? 0)
            recurring.endDate = hasEndDate ? endDate : nil
            recurring.weeklyDays = weeklyDaysString
            recurring.monthlyDay = frequency == "Monthly" ? Int16(selectedMonthDay) : 0
            recurring.updatedAt = Date()

            try recurringTransactionRepository.save()

            finishLoading()

        } catch let error as ValidationError {
            handleError(error)
        } catch {
            handleError(error)
        }
    }
}
