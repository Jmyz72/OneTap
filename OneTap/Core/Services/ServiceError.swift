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
            return "Entity not found"
        case .operationFailed(let message):
            return "Operation failed: \(message)"
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .concurrencyError:
            return "Concurrency error occurred"
        case .balanceCalculationFailed:
            return "Failed to calculate balance"
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

    var errorDescription: String? {
        switch self {
        case .invalidAmount:
            return "Amount must be greater than 0"
        case .missingAccount:
            return "Please select an account"
        case .missingCategory:
            return "Please select a category"
        case .missingDestinationAccount:
            return "Please select a destination account for transfer"
        case .invalidAccountName:
            return "Account name cannot be empty"
        case .duplicateAccount:
            return "An account with this name already exists"
        case .emptyName:
            return "Name cannot be empty"
        case .invalidCategoryName:
            return "Category name cannot be empty"
        }
    }
}
