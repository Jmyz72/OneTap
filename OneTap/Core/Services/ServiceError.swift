//
//  ServiceError.swift
//  OneTap
//
//  Service layer error definitions
//

import Foundation

enum ServiceError: LocalizedError {
    case entityNotFound
    case operationFailed(String)
    case validationFailed(String)
    case concurrencyError
    case balanceCalculationFailed

    var errorDescription: String? {
        switch self {
        case .entityNotFound:
            return "The requested item could not be found. Please try refreshing the screen."
        case .operationFailed(let message):
            return "We couldn't complete this action: \(message). Please try again."
        case .validationFailed(let message):
            return message
        case .concurrencyError:
            return "Multiple operations are conflicting. Please wait a moment and try again."
        case .balanceCalculationFailed:
            return "We couldn't update your account balance. Please check your connection and try again."
        }
    }
}

enum ValidationError: LocalizedError {
    case invalidAmount
    case missingAccount
    case missingCategory
    case missingDestinationAccount
    case invalidAccountName
    case duplicateAccount
    case emptyName
    case invalidCategoryName
    case invalidSplitItems
    case splitItemsMismatch(expected: Double, actual: Double)

    var errorDescription: String? {
        switch self {
        case .invalidAmount:
            return "Please enter an amount greater than $0"
        case .missingAccount:
            return "Please select an account before saving"
        case .missingCategory:
            return "Please select a category for this transaction"
        case .missingDestinationAccount:
            return "Please select a destination account for this transfer"
        case .invalidAccountName:
            return "Please enter a name for this account"
        case .duplicateAccount:
            return "An account with this name already exists. Please choose a different name."
        case .emptyName:
            return "Please enter a name"
        case .invalidCategoryName:
            return "Please enter a name for this category"
        case .invalidSplitItems:
            return "Split transaction must have at least one item with a valid amount"
        case .splitItemsMismatch(let expected, let actual):
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = SettingsManager.shared.currencyCode
            let expectedStr = formatter.string(from: NSNumber(value: expected)) ?? "$\(expected)"
            let actualStr = formatter.string(from: NSNumber(value: actual)) ?? "$\(actual)"
            return "Split items total (\(actualStr)) must equal transaction amount (\(expectedStr))"
        }
    }
}
