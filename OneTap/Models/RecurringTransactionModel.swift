//
//  RecurringTransactionModel.swift
//  OneTap
//
//  Model extensions for RecurringTransaction entity
//

import Foundation
@preconcurrency internal import CoreData

extension RecurringTransaction {

    // MARK: - Installment Helpers

    /// Returns true if this is an installment plan
    var isInstallmentPlan: Bool {
        return isInstallment
    }

    /// Returns total original amount for installment (e.g., $1200 laptop)
    var installmentTotalAmount: Double {
        return totalAmount
    }

    /// Returns whether first payment should be immediate
    var shouldPayFirstImmediately: Bool {
        return firstPaymentImmediate
    }

    /// Number of installments remaining
    var remainingInstallments: Int16 {
        let limit = occurrenceLimit
        return max(0, limit - occurrencesCount)
    }

    /// Total amount paid so far (accounts for interest if applicable)
    var paidAmount: Double {
        if hasInterest && interestRate > 0 {
            // With interest: Sum of all payments made so far
            return amount * Double(occurrencesCount)
        } else {
            // No interest: Simple multiplication
            return amount * Double(occurrencesCount)
        }
    }

    /// Remaining amount to pay (accounts for interest if applicable)
    var remainingAmount: Double {
        if hasInterest && interestRate > 0 {
            // With interest: Total cost including interest minus what's been paid
            let totalCost = calculateTotalCostWithInterest()
            return totalCost - paidAmount
        } else {
            // No interest: Simple subtraction
            return installmentTotalAmount - paidAmount
        }
    }

    /// Progress percentage (0.0 to 1.0)
    var progressPercentage: Double {
        guard installmentTotalAmount > 0 else { return 0 }
        return paidAmount / installmentTotalAmount
    }

    /// Formatted progress string (e.g., "3/12 payments")
    var formattedProgress: String {
        let limit = occurrenceLimit
        return "\(occurrencesCount)/\(limit) payments"
    }

    /// Formatted installment display (e.g., "$100 × 12 months")
    var formattedInstallmentDisplay: String {
        let limit = occurrenceLimit
        let formatter = Formatters.currencyFormatter(for: "MYR") // Default currency
        let amountStr = formatter.string(from: NSNumber(value: amount)) ?? "$0"
        return "\(amountStr) × \(limit) months"
    }

    /// Status text for UI
    var statusText: String {
        if !isActive {
            return "Inactive"
        }
        let limit = occurrenceLimit
        if limit > 0 && occurrencesCount >= limit {
            return "Completed"
        }
        return "Active"
    }

    /// Color for status
    var statusColor: String {
        if !isActive { return "gray" }
        let limit = occurrenceLimit
        if limit > 0 && occurrencesCount >= limit { return "green" }
        return "blue"
    }

    // MARK: - Interest Calculations

    /// Calculates monthly payment with interest using amortization formula
    /// Formula: M = P * (r * (1 + r)^n) / ((1 + r)^n - 1)
    /// - Parameters:
    ///   - principal: Total principal amount (e.g., $1200)
    ///   - apr: Annual percentage rate as decimal (e.g., 0.15 for 15%)
    ///   - months: Number of monthly payments
    /// - Returns: Monthly payment amount
    static func calculateMonthlyPayment(principal: Double, apr: Double, months: Int16) -> Double {
        guard principal > 0, months > 0 else { return 0 }

        // No interest case
        if apr <= 0 {
            return principal / Double(months)
        }

        // Calculate monthly interest rate
        let monthlyRate = apr / 12.0
        let n = Double(months)

        // Amortization formula: M = P * (r * (1 + r)^n) / ((1 + r)^n - 1)
        let onePlusR = 1.0 + monthlyRate
        let numerator = principal * (monthlyRate * pow(onePlusR, n))
        let denominator = pow(onePlusR, n) - 1.0

        return numerator / denominator
    }

    /// Total cost of installment including all interest charges
    func calculateTotalCostWithInterest() -> Double {
        if !hasInterest || interestRate <= 0 {
            return installmentTotalAmount
        }

        // Total cost = monthly payment × number of payments
        let monthlyPayment = Self.calculateMonthlyPayment(
            principal: installmentTotalAmount,
            apr: interestRate,
            months: occurrenceLimit
        )
        return monthlyPayment * Double(occurrenceLimit)
    }

    /// Total interest charges over the life of the installment
    var totalInterestCharges: Double {
        if !hasInterest || interestRate <= 0 {
            return 0
        }
        return calculateTotalCostWithInterest() - installmentTotalAmount
    }

    /// Formatted display of APR (e.g., "15.0% APR")
    var formattedAPR: String {
        if !hasInterest || interestRate <= 0 {
            return "0% APR"
        }
        let percentage = interestRate * 100.0
        return String(format: "%.1f%% APR", percentage)
    }

    /// Formatted display of total interest (e.g., "+$90.00 interest")
    var formattedTotalInterest: String? {
        guard hasInterest, interestRate > 0 else { return nil }

        let interest = totalInterestCharges
        guard interest > 0 else { return nil }

        let formatter = Formatters.currencyFormatter(for: account?.currency ?? "USD")
        let interestStr = formatter.string(from: NSNumber(value: interest)) ?? "\(interest)"
        return "+\(interestStr) interest"
    }

    // MARK: - General Helpers

    /// Transaction type enum
    var typeEnum: TransactionType {
        return TransactionType(rawValue: type ?? "Expense") ?? .expense
    }

    /// Formatted amount with currency symbol and +/- prefix
    var formattedAmount: String {
        let currencyCode = account?.currency ?? SettingsManager.shared.currencyCode
        let formatter = Formatters.currencyFormatter(for: currencyCode)
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"

        switch typeEnum {
        case .expense:
            return "-\(formatted)"
        case .income:
            return "+\(formatted)"
        case .transfer:
            return formatted
        case .adjustment:
            return formatted
        }
    }
}
