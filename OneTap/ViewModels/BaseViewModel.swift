//
//  BaseViewModel.swift
//  OneTap
//
//  Base ViewModel types and protocols
//

import Foundation
import SwiftUI

// MARK: - Loading State

enum LoadingState: Equatable {
    case idle
    case loading
    case loaded
    case error(String)

    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }

    var errorMessage: String? {
        if case .error(let message) = self {
            return message
        }
        return nil
    }
}

// MARK: - Base ViewModel Protocol

protocol ViewModelProtocol: ObservableObject {
    var loadingState: LoadingState { get set }
    var errorMessage: String? { get set }

    func handleError(_ error: Error)
    func startLoading()
    func finishLoading()
}

// MARK: - Default Implementations

extension ViewModelProtocol {
    func handleError(_ error: Error) {
        loadingState = .error(error.localizedDescription)
        errorMessage = error.localizedDescription
    }

    func startLoading() {
        loadingState = .loading
        errorMessage = nil
    }

    func finishLoading() {
        loadingState = .loaded
    }

    // MARK: - Currency Formatting

    /// Formats a currency amount using the specified or default currency code
    /// - Parameters:
    ///   - amount: The amount to format
    ///   - currencyCode: Optional currency code. If nil, uses SettingsManager.shared.currencyCode
    /// - Returns: Formatted currency string (e.g., "RM1,234.56")
    func formatCurrency(_ amount: Double, currencyCode: String? = nil) -> String {
        let code = currencyCode ?? SettingsManager.shared.currencyCode
        let formatter = Formatters.currencyFormatter(for: code)
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}
