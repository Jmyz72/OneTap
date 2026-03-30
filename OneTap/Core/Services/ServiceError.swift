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
    case networkError(String)
    case migrationFailed(underlyingError: Error)

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
        case .networkError(let message):
            return "Network error: \(message). Please check your connection and try again."
        case .migrationFailed:
            return "Database migration failed. Your data may need to be reset to continue using the app."
        }
    }
}

// MARK: - Migration Error Handler

/// Handles Core Data migration failures with user-facing recovery options
/// This is a singleton that communicates migration errors to the UI
@MainActor
final class MigrationErrorHandler: ObservableObject {
    static let shared = MigrationErrorHandler()

    @Published var showRecoveryDialog = false
    @Published var migrationError: Error?
    @Published var storeURL: URL?

    private init() {}

    /// Called when a migration error is detected
    /// - Parameters:
    ///   - error: The underlying migration error
    ///   - url: The URL of the persistent store that failed
    func handleMigrationFailure(error: Error, storeURL: URL) {
        self.migrationError = error
        self.storeURL = storeURL
        self.showRecoveryDialog = true

        // Log the error for debugging
        print("Migration error detected: \(error.localizedDescription)")
        print("Store URL: \(storeURL)")
    }

    /// Resets the error state after user has made a decision
    func reset() {
        showRecoveryDialog = false
        migrationError = nil
        storeURL = nil
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
