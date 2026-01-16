//
//  EditInstallmentPlanViewModel.swift
//  OneTap
//
//  ViewModel for editing existing installment plans
//

import Foundation
import SwiftUI
import Combine
@preconcurrency internal import CoreData

@MainActor
class EditInstallmentPlanViewModel: ObservableObject, ViewModelProtocol {
    // MARK: - Published State
    @Published var title = ""
    @Published var merchant = ""
    @Published var totalAmountString = ""
    @Published var numberOfPayments: Int16 = 12
    @Published var billingDay: Int16 = 1
    @Published var notes = ""

    // Interest support
    @Published var hasInterest = false
    @Published var aprPercentage = ""

    // Payment Cycle Type
    @Published var paymentCycleType: PaymentCycleType = .monthlyFixed
    @Published var customRollingDaysString: String = "30"
    @Published var useAccountBillingDates: Bool = true
    @Published var customBillingDay: Int16 = 1
    @Published var customDueDay: Int16 = 10

    @Published var accounts: [Account] = []
    @Published var expenseCategories: [Category] = []

    @Published var loadingState: LoadingState = .idle
    @Published var errorMessage: String?

    // MARK: - Properties
    let plan: RecurringTransaction
    var selectedAccount: Account? { plan.account }
    var selectedCategory: Category? { plan.category }

    // MARK: - Dependencies
    private let recurringTransactionService: RecurringTransactionService
    private let accountRepository: AccountRepository
    private let categoryRepository: CategoryRepository
    private let validationService: ValidationService
    private var cancellables = Set<AnyCancellable>()

    init(
        plan: RecurringTransaction,
        recurringTransactionService: RecurringTransactionService,
        accountRepository: AccountRepository,
        categoryRepository: CategoryRepository,
        validationService: ValidationService
    ) {
        self.plan = plan
        self.recurringTransactionService = recurringTransactionService
        self.accountRepository = accountRepository
        self.categoryRepository = categoryRepository
        self.validationService = validationService

        setupData()
        loadPlanData()
    }

    deinit {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    // MARK: - Computed Properties

    var totalAmount: Double {
        Double(totalAmountString) ?? 0
    }

    var annualInterestRate: Double {
        guard hasInterest else { return 0 }
        let percentage = Double(aprPercentage) ?? 0
        return percentage / 100.0
    }

    var customRollingDays: Int16 {
        Int16(customRollingDaysString) ?? 30
    }

    var effectiveBillingDay: Int16 {
        if paymentCycleType == .consolidated {
            return useAccountBillingDates ? (selectedAccount?.billingDate ?? 1) : customBillingDay
        }
        return billingDay
    }

    var effectiveDueDay: Int16 {
        if paymentCycleType == .consolidated {
            return useAccountBillingDates ? (selectedAccount?.dueDate ?? 10) : customDueDay
        }
        return 0
    }

    var monthlyPayment: Double {
        guard numberOfPayments > 0 else { return 0 }
        guard totalAmount > 0 else { return 0 }

        if hasInterest && annualInterestRate > 0 {
            return RecurringTransaction.calculateMonthlyPayment(
                principal: totalAmount,
                apr: annualInterestRate,
                months: numberOfPayments
            )
        } else {
            return totalAmount / Double(numberOfPayments)
        }
    }

    var totalCostWithInterest: Double {
        return monthlyPayment * Double(numberOfPayments)
    }

    var totalInterestCharges: Double {
        return totalCostWithInterest - totalAmount
    }

    var formattedMonthlyPayment: String {
        let code = selectedAccount?.currency ?? SettingsManager.shared.currencyCode
        let formatter = Formatters.currencyFormatter(for: code)
        return formatter.string(from: NSNumber(value: monthlyPayment)) ?? "$0"
    }

    var formattedTotalCost: String {
        let code = selectedAccount?.currency ?? SettingsManager.shared.currencyCode
        let formatter = Formatters.currencyFormatter(for: code)
        return formatter.string(from: NSNumber(value: totalCostWithInterest)) ?? "$0"
    }

    var formattedTotalInterest: String? {
        guard hasInterest && annualInterestRate > 0 else { return nil }
        let code = selectedAccount?.currency ?? SettingsManager.shared.currencyCode
        let formatter = Formatters.currencyFormatter(for: code)
        if let formatted = formatter.string(from: NSNumber(value: totalInterestCharges)) {
            return "+\(formatted) interest"
        }
        return nil
    }

    var isValid: Bool {
        !title.isEmpty &&
        totalAmount > 0 &&
        numberOfPayments > 1
    }

    // MARK: - Setup

    private func setupData() {
        // Load accounts
        accountRepository.accountsPublisher()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] accounts in
                    self?.accounts = accounts
                }
            )
            .store(in: &cancellables)

        // Load expense categories
        categoryRepository.categoriesPublisher(type: .expense)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] categories in
                    self?.expenseCategories = categories
                }
            )
            .store(in: &cancellables)

        // Initial fetch
        accounts = accountRepository.fetchAccounts(group: nil)
        expenseCategories = categoryRepository.fetchCategories(type: .expense)
    }

    private func loadPlanData() {
        // Load basic fields
        title = plan.title ?? ""
        merchant = plan.merchant ?? ""
        notes = plan.notes ?? ""
        totalAmountString = String(format: "%.2f", plan.totalAmount)
        numberOfPayments = plan.occurrenceLimit

        // Load interest data
        hasInterest = plan.hasInterest
        if hasInterest {
            aprPercentage = String(format: "%.1f", plan.interestRate * 100)
        }

        // Load payment cycle type
        paymentCycleType = plan.paymentCycleTypeEnum

        switch paymentCycleType {
        case .monthlyFixed:
            billingDay = plan.monthlyDay

        case .weekly, .biweekly:
            // Fixed values, no additional config needed
            break

        case .rolling:
            customRollingDaysString = String(plan.rollingCycleDays)

        case .consolidated:
            if plan.overrideBillingDay > 0 {
                useAccountBillingDates = false
                customBillingDay = plan.overrideBillingDay
                customDueDay = plan.overrideDueDay
            } else {
                useAccountBillingDates = true
            }
        }
    }

    // MARK: - Actions

    private func validateCycleConfiguration() throws {
        switch paymentCycleType {
        case .monthlyFixed:
            guard billingDay >= 0 && billingDay <= 31 else {
                throw ServiceError.validationFailed("Billing day must be between 1 and 31")
            }

        case .weekly, .biweekly:
            break

        case .rolling:
            guard customRollingDays >= 1 && customRollingDays <= 365 else {
                throw ServiceError.validationFailed("Rolling cycle days must be between 1 and 365")
            }

        case .consolidated:
            if !useAccountBillingDates {
                guard customBillingDay >= 1 && customBillingDay <= 31 else {
                    throw ServiceError.validationFailed("Billing day must be between 1 and 31")
                }
                guard customDueDay >= 1 && customDueDay <= 31 else {
                    throw ServiceError.validationFailed("Due day must be between 1 and 31")
                }
            } else {
                guard let account = selectedAccount else {
                    throw ValidationError.missingAccount
                }
                guard account.billingDate > 0, account.dueDate > 0 else {
                    throw ServiceError.validationFailed(
                        "Selected account must have billing and due dates configured. " +
                        "Please update account settings or use custom dates."
                    )
                }
            }
        }
    }

    func updateInstallmentPlan() async {
        loadingState = .loading

        do {
            guard totalAmount > 0 else {
                throw ValidationError.invalidAmount
            }

            guard numberOfPayments > 1 else {
                throw ServiceError.validationFailed("Number of payments must be at least 2")
            }

            // Validate cycle-specific configuration
            try validateCycleConfiguration()

            // Update installment plan
            try await recurringTransactionService.updateInstallmentPlan(
                plan,
                title: title,
                merchant: merchant.isEmpty ? nil : merchant,
                notes: notes.isEmpty ? nil : notes,
                paymentCycleType: paymentCycleType,
                monthlyFixedDay: paymentCycleType == .monthlyFixed ? billingDay : nil,
                rollingCycleDays: paymentCycleType == .rolling ? customRollingDays : nil,
                overrideBillingDay: paymentCycleType == .consolidated && !useAccountBillingDates ? customBillingDay : nil,
                overrideDueDay: paymentCycleType == .consolidated && !useAccountBillingDates ? customDueDay : nil,
                numberOfPayments: numberOfPayments,
                annualInterestRate: annualInterestRate
            )

            loadingState = .loaded
        } catch {
            loadingState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }
}
