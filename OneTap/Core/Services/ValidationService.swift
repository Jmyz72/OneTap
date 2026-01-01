//
//  ValidationService.swift
//  OneTap
//
//  Centralized validation logic for business rules
//

import Foundation

protocol ValidationServiceProtocol {
    func validateTransaction(
        amount: Double,
        type: TransactionType,
        account: Account?,
        category: Category?,
        toAccount: Account?
    ) throws

    func validateAccount(
        name: String,
        balance: Double,
        type: AccountType
    ) throws

    func validateCategory(name: String) throws
}

class ValidationService: ValidationServiceProtocol {
    // MARK: - Transaction Validation

    /// Validates transaction data before creation or update
    /// - Parameters:
    ///   - amount: Transaction amount
    ///   - type: Transaction type
    ///   - account: Source account
    ///   - category: Transaction category
    ///   - toAccount: Destination account (required for transfers)
    func validateTransaction(
        amount: Double,
        type: TransactionType,
        account: Account?,
        category: Category?,
        toAccount: Account?
    ) throws {
        // Validate amount
        guard amount > 0 else {
            throw ValidationError.invalidAmount
        }

        // Validate account
        guard account != nil else {
            throw ValidationError.missingAccount
        }

        // Type-specific validation
        switch type {
        case .transfer:
            // Transfers require destination account
            guard toAccount != nil else {
                throw ValidationError.missingDestinationAccount
            }

            // Cannot transfer to same account
            if account?.id == toAccount?.id {
                throw ServiceError.validationFailed("Cannot transfer to the same account")
            }

        case .expense, .income:
            // Regular transactions require category
            guard category != nil else {
                throw ValidationError.missingCategory
            }

        case .adjustment:
            // Adjustments don't require category
            break
        }
    }

    // MARK: - Account Validation

    /// Validates account data before creation or update
    /// - Parameters:
    ///   - name: Account name
    ///   - balance: Initial or current balance
    ///   - type: Account type
    func validateAccount(
        name: String,
        balance: Double,
        type: AccountType
    ) throws {
        // Validate name
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidAccountName
        }

        // Note: Balance can be negative for liability accounts (credit cards)
        // So we don't validate balance range here
    }

    // MARK: - Category Validation

    /// Validates category data before creation or update
    /// - Parameter name: Category name
    func validateCategory(name: String) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.emptyName
        }
    }
}
