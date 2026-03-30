//
//  Constants.swift
//  OneTap
//
//  Centralized constants to eliminate magic numbers throughout the codebase
//

import Foundation

enum Constants {
    // MARK: - Tolerance
    /// Tolerance values for floating-point comparisons
    enum Tolerance {
        /// Standard tolerance for comparing currency amounts (e.g., checking if amounts match)
        static let floatingPoint: Double = 0.01

        /// Tolerance for balance comparisons
        static let balance: Double = 0.001
    }

    // MARK: - Currency
    /// Currency-related constants
    enum Currency {
        /// Number of cents per dollar (for input conversion)
        static let centsPerDollar: Double = 100.0

        /// Default currency code if none specified
        static let defaultCode: String = "MYR"
    }

    // MARK: - Debounce
    /// Debounce delays for various operations
    enum Debounce {
        /// Delay for search input debouncing
        static let search: TimeInterval = 0.3

        /// Delay for context save notifications
        static let contextSave: TimeInterval = 0.5

        /// Delay for merchant suggestions
        static let merchantSuggestions: TimeInterval = 0.2
    }

    // MARK: - Installment
    /// Installment plan options
    enum Installment {
        /// Available installment payment options
        static let options: [Int16] = [3, 6, 9, 12, 18, 24]

        /// Default billing day
        static let defaultBillingDay: Int16 = 1

        /// Default number of payments
        static let defaultPayments: Int16 = 3
    }

    // MARK: - Pagination
    /// Pagination and limit constants
    enum Pagination {
        /// Default limit for recent transactions
        static let recentTransactions: Int = 5

        /// Default limit for recent merchants
        static let recentMerchants: Int = 5

        /// Default limit for pending recurring transactions
        static let pendingRecurring: Int = 10

        /// Default limit for upcoming recurring transactions
        static let upcomingRecurring: Int = 5
    }

    // MARK: - Time
    /// Time-related constants
    enum Time {
        /// Seconds in a day
        static let secondsPerDay: TimeInterval = 86400

        /// Days in a week for upcoming transactions
        static let daysInWeek: Int = 7
    }

    // MARK: - UI
    /// UI-related constants
    enum UI {
        /// Animation duration for standard transitions
        static let animationDuration: TimeInterval = 0.3

        /// Corner radius for cards
        static let cardCornerRadius: CGFloat = 12.0

        /// Standard padding
        static let standardPadding: CGFloat = 16.0
    }
}
