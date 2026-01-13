//
//  AddInstallmentPlanViewModel.swift
//  OneTap
//
//  ViewModel for creating new installment plans
//

import Foundation
import SwiftUI
import Combine
@preconcurrency internal import CoreData

@MainActor
class AddInstallmentPlanViewModel: ObservableObject, ViewModelProtocol {
    // MARK: - Published State
    @Published var title = ""
    @Published var merchant = ""
    @Published var totalAmountString = ""
    @Published var numberOfPayments: Int16 = 12
    @Published var billingDay: Int16 = 1
    @Published var firstPaymentImmediate = true
    @Published var selectedAccount: Account?
    @Published var selectedCategory: Category?
    @Published var notes = ""

    // Interest support
    @Published var hasInterest = false
    @Published var aprPercentage = ""

    @Published var accounts: [Account] = []
    @Published var expenseCategories: [Category] = []

    @Published var loadingState: LoadingState = .idle
    @Published var errorMessage: String?

    // MARK: - Dependencies
    private let recurringTransactionService: RecurringTransactionService
    private let accountRepository: AccountRepository
    private let categoryRepository: CategoryRepository
    private let validationService: ValidationService
    private var cancellables = Set<AnyCancellable>()

    init(
        recurringTransactionService: RecurringTransactionService,
        accountRepository: AccountRepository,
        categoryRepository: CategoryRepository,
        validationService: ValidationService
    ) {
        self.recurringTransactionService = recurringTransactionService
        self.accountRepository = accountRepository
        self.categoryRepository = categoryRepository
        self.validationService = validationService

        setupData()
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
        return percentage / 100.0  // Convert percentage to decimal (15% -> 0.15)
    }

    var monthlyPayment: Double {
        guard numberOfPayments > 0 else { return 0 }
        guard totalAmount > 0 else { return 0 }

        if hasInterest && annualInterestRate > 0 {
            // Use amortization formula for interest-bearing installments
            return RecurringTransaction.calculateMonthlyPayment(
                principal: totalAmount,
                apr: annualInterestRate,
                months: numberOfPayments
            )
        } else {
            // Simple division for 0% APR
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
        numberOfPayments > 1 &&
        selectedAccount != nil &&
        selectedCategory != nil
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
                    if self?.selectedAccount == nil {
                        self?.selectedAccount = accounts.first
                    }
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
        selectedAccount = accounts.first
    }

    // MARK: - Actions

    func createInstallmentPlan() async {
        loadingState = .loading

        do {
            guard let account = selectedAccount else {
                throw ValidationError.missingAccount
            }

            guard let category = selectedCategory else {
                throw ValidationError.missingCategory
            }

            guard totalAmount > 0 else {
                throw ValidationError.invalidAmount
            }

            guard numberOfPayments > 1 else {
                throw ServiceError.validationFailed("Number of payments must be at least 2")
            }

            // Create installment plan
            _ = try await recurringTransactionService.createInstallmentPlan(
                title: title,
                totalAmount: totalAmount,
                numberOfPayments: numberOfPayments,
                account: account,
                category: category,
                subCategory: nil,
                merchant: merchant.isEmpty ? nil : merchant,
                notes: notes.isEmpty ? nil : notes,
                firstPaymentImmediate: firstPaymentImmediate,
                billingDay: billingDay,
                annualInterestRate: annualInterestRate
            )

            loadingState = .loaded
        } catch {
            loadingState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }
}
