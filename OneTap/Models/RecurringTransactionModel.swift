//
//  RecurringTransactionModel.swift
//  OneTap
//
//  Model extensions for RecurringTransaction entity
//

import Foundation
internal import CoreData

extension RecurringTransaction {

    // MARK: - Installment Helpers

    /// Returns true if this is an installment plan
    var isInstallmentPlan: Bool {
        return isInstallment
    }

    /// Returns total original amount for installment (e.g., $1200 laptop)
    var installmentTotalAmount: Double {
        return totalAmount ?? 0.0
    }

    /// Returns whether first payment should be immediate
    var shouldPayFirstImmediately: Bool {
        return firstPaymentImmediate ?? true
    }

    /// Number of installments remaining
    var remainingInstallments: Int16 {
        let limit = occurrenceLimit ?? 0
        return max(0, limit - occurrencesCount)
    }

    /// Total amount paid so far
    var paidAmount: Double {
        return amount * Double(occurrencesCount)
    }

    /// Remaining amount to pay
    var remainingAmount: Double {
        return installmentTotalAmount - paidAmount
    }

    /// Progress percentage (0.0 to 1.0)
    var progressPercentage: Double {
        guard installmentTotalAmount > 0 else { return 0 }
        return paidAmount / installmentTotalAmount
    }

    /// Formatted progress string (e.g., "3/12 payments")
    var formattedProgress: String {
        let limit = occurrenceLimit ?? 0
        return "\(occurrencesCount)/\(limit) payments"
    }

    /// Formatted installment display (e.g., "$100 × 12 months")
    var formattedInstallmentDisplay: String {
        let limit = occurrenceLimit ?? 0
        let formatter = Formatters.currencyFormatter(for: "MYR") // Default currency
        let amountStr = formatter.string(from: NSNumber(value: amount)) ?? "$0"
        return "\(amountStr) × \(limit) months"
    }

    /// Status text for UI
    var statusText: String {
        if !isActive {
            return "Inactive"
        }
        let limit = occurrenceLimit ?? 0
        if limit > 0 && occurrencesCount >= limit {
            return "Completed"
        }
        return "Active"
    }

    /// Color for status
    var statusColor: String {
        if !isActive { return "gray" }
        let limit = occurrenceLimit ?? 0
        if limit > 0 && occurrencesCount >= limit { return "green" }
        return "blue"
    }
}
