//
//  AccountFormViewModel.swift
//  OneTap
//
//  ViewModel for creating/editing accounts
//  Replaces logic from AccountFormView.swift (lines 147-225)
//

import Foundation
import SwiftUI
import Combine

@MainActor
class AccountFormViewModel: ObservableObject, ViewModelProtocol {
    // MARK: - Published State
    @Published var name = ""
    @Published var institution = ""
    @Published var type: AccountType = .checking
    @Published var balance = ""
    @Published var creditLimit = ""
    @Published var currency: String
    @Published var billingDay = 1
    @Published var dueDay = 1
    @Published var icon = "creditcard.fill"
    @Published var hasCard = false
    @Published var lastFourDigits = ""

    @Published var loadingState: LoadingState = .idle
    @Published var errorMessage: String?

    // MARK: - Dependencies
    private let account: Account?
    private let template: AccountTemplate?
    private let accountRepository: AccountRepository
    private let transactionRepository: TransactionRepository
    private let balanceService: BalanceService

    var isEditing: Bool { account != nil }

    init(
        account: Account? = nil,
        template: AccountTemplate? = nil,
        accountRepository: AccountRepository,
        transactionRepository: TransactionRepository,
        balanceService: BalanceService
    ) {
        self.account = account
        self.template = template
        self.accountRepository = accountRepository
        self.transactionRepository = transactionRepository
        self.balanceService = balanceService

        self.currency = SettingsManager.shared.currencyCode

        loadInitialValues()
    }

    // MARK: - Computed Properties

    var isValid: Bool {
        !name.isEmpty && !balance.isEmpty
    }

    var isCreditAccount: Bool {
        type == .creditCard || type == .bnpl
    }

    // MARK: - Lifecycle

    private func loadInitialValues() {
        if let account = account {
            // Edit mode
            name = account.name ?? ""
            institution = account.institution ?? ""
            type = account.typeEnum
            currency = account.currency ?? SettingsManager.shared.currencyCode
            balance = String(format: "%.2f", account.balance)
            creditLimit = String(format: "%.2f", account.creditLimit)
            billingDay = account.billingDay > 0 ? account.billingDay : 1
            dueDay = account.dueDay > 0 ? account.dueDay : 1
            icon = account.icon ?? type.icon
            lastFourDigits = account.lastFourDigits ?? ""
            hasCard = !lastFourDigits.isEmpty
        } else if let template = template {
            // Template mode
            name = template.name
            institution = template.institution
            type = template.type
            icon = template.displayIcon
        } else {
            // New account mode
            icon = type.icon
        }
    }

    // MARK: - Actions

    func updateIconForType() {
        // Update icon when type changes (unless user set a custom icon)
        if template == nil && (icon.isEmpty || icon == AccountType.allCases.first(where: { $0.icon == icon })?.icon) {
            icon = type.icon
        }
    }

    func saveAccount() async {
        startLoading()

        do {
            let balanceValue = Double(balance) ?? 0.0
            let creditLimitValue = Double(creditLimit) ?? 0.0

            if let existingAccount = account {
                // UPDATE EXISTING ACCOUNT
                let updateData = AccountUpdateData(
                    name: name,
                    institution: institution.isEmpty ? nil : institution,
                    type: type,
                    currency: currency,
                    creditLimit: isCreditAccount ? creditLimitValue : nil,
                    icon: icon,
                    billingDay: isCreditAccount ? billingDay : nil,
                    dueDay: isCreditAccount ? dueDay : nil,
                    lastFourDigits: hasCard ? lastFourDigits : nil
                )

                try accountRepository.updateAccount(existingAccount, with: updateData)

                // Check if balance was manually edited
                if abs(balanceValue - existingAccount.balance) > 0.01 {
                    // Create balance adjustment transaction
                    _ = try transactionRepository.createTransaction(
                        title: "Balance Adjustment",
                        amount: balanceValue,
                        type: .adjustment,
                        date: Date(),
                        account: existingAccount,
                        category: nil,
                        subCategory: nil,
                        notes: nil
                    )

                    try transactionRepository.save()
                    try await balanceService.recalculateBalances(for: existingAccount.objectID, from: nil)
                }

                try accountRepository.save()

            } else {
                // CREATE NEW ACCOUNT
                let newAccount = try accountRepository.createAccount(
                    name: name,
                    type: type,
                    currency: currency,
                    icon: icon,
                    initialBalance: balanceValue
                )

                // Set additional properties
                if !institution.isEmpty {
                    newAccount.institution = institution
                }

                if isCreditAccount {
                    newAccount.creditLimit = creditLimitValue
                    newAccount.billingDate = Int16(billingDay)
                    newAccount.dueDate = Int16(dueDay)
                }

                if hasCard {
                    newAccount.lastFourDigits = lastFourDigits
                }

                try accountRepository.save()

                // Create opening balance transaction if non-zero
                if balanceValue != 0 {
                    _ = try transactionRepository.createTransaction(
                        title: "Opening Balance",
                        amount: balanceValue,
                        type: .adjustment,
                        date: newAccount.createdAt ?? Date(),
                        account: newAccount,
                        category: nil,
                        subCategory: nil,
                        notes: nil
                    )

                    try transactionRepository.save()
                }
            }

            finishLoading()

        } catch {
            handleError(error)
        }
    }
}
