//
//  TransactionAdjustmentModel.swift
//  OneTap
//
//  Model extensions for TransactionAdjustment entity
//

import Foundation
import SwiftUI

// MARK: - Adjustment Type Enum

enum AdjustmentType: String, CaseIterable, Identifiable {
    case tax = "tax"
    case serviceCharge = "serviceCharge"
    case discount = "discount"
    case rounding = "rounding"
    case other = "other"

    var id: String { rawValue }

    /// Display name for UI
    var displayName: String {
        switch self {
        case .tax: return "Tax"
        case .serviceCharge: return "Service Charge"
        case .discount: return "Discount"
        case .rounding: return "Rounding"
        case .other: return "Other"
        }
    }

    /// SF Symbol icon for this adjustment type
    var icon: String {
        switch self {
        case .tax: return "percent"
        case .serviceCharge: return "person.fill"
        case .discount: return "tag.fill"
        case .rounding: return "plusminus"
        case .other: return "ellipsis.circle"
        }
    }

    /// Whether this adjustment type typically reduces the total (negative)
    var isNegative: Bool {
        self == .discount
    }

    /// Color for UI representation
    var color: Color {
        switch self {
        case .tax: return .orange
        case .serviceCharge: return .blue
        case .discount: return .green
        case .rounding: return .gray
        case .other: return .secondary
        }
    }
}

// MARK: - TransactionAdjustment Extension

extension TransactionAdjustment {
    /// Typed accessor for adjustment type
    var typeEnum: AdjustmentType {
        get {
            guard let typeString = type, let value = AdjustmentType(rawValue: typeString) else {
                return .other
            }
            return value
        }
        set {
            type = newValue.rawValue
        }
    }

    /// Formatted amount with currency
    var formattedAmount: String {
        let code = transaction?.account?.currency ?? SettingsManager.shared.currencyCode
        let formatter = Formatters.currencyFormatter(for: code)

        // Discounts are shown as negative
        let prefix = typeEnum.isNegative ? "-" : ""
        let formatted = formatter.string(from: NSNumber(value: abs(amount))) ?? "$0.00"

        return "\(prefix)\(formatted)"
    }

    /// Display label - uses custom label if provided, otherwise uses type display name with percentage
    var displayLabel: String {
        if let customLabel = label, !customLabel.isEmpty {
            return customLabel
        }

        if percentage > 0 {
            return "\(typeEnum.displayName) \(Int(percentage))%"
        }

        return typeEnum.displayName
    }
}

// MARK: - Transaction Extension for Adjustments

extension Transaction {
    /// Array of adjustments sorted by type
    var adjustmentsArray: [TransactionAdjustment] {
        let set = adjustments as? Set<TransactionAdjustment> ?? []

        // Sort order: tax, serviceCharge, discount, rounding, other
        let typeOrder: [AdjustmentType] = [.tax, .serviceCharge, .discount, .rounding, .other]

        return set.sorted { adj1, adj2 in
            let index1 = typeOrder.firstIndex(of: adj1.typeEnum) ?? typeOrder.count
            let index2 = typeOrder.firstIndex(of: adj2.typeEnum) ?? typeOrder.count
            return index1 < index2
        }
    }

    /// Whether this transaction has any adjustments
    var hasAdjustments: Bool {
        let set = adjustments as? Set<TransactionAdjustment> ?? []
        return !set.isEmpty
    }

    /// Total adjustments amount (positive amounts add, discounts subtract)
    var totalAdjustmentsAmount: Double {
        adjustmentsArray.reduce(0) { total, adjustment in
            if adjustment.typeEnum.isNegative {
                return total - abs(adjustment.amount)
            } else {
                return total + adjustment.amount
            }
        }
    }

    /// Subtotal before adjustments (items only)
    var subtotalBeforeAdjustments: Double {
        if !itemsArray.isEmpty {
            return itemsArray.reduce(0) { $0 + $1.amount }
        }
        // For single-item transactions, calculate from total minus adjustments
        return amount - totalAdjustmentsAmount
    }
}
