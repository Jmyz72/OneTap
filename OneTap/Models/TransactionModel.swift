//
//  TransactionModel.swift
//  OneTap
//

import Foundation
import SwiftUI
internal import CoreData

enum TransactionType: String, CaseIterable, Identifiable {
    case expense = "Expense"
    case income = "Income"
    case transfer = "Transfer"
    case adjustment = "Adjustment"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .expense: return "arrow.up.right.circle.fill"
        case .income: return "arrow.down.left.circle.fill"
        case .transfer: return "arrow.left.and.right.circle.fill"
        case .adjustment: return "slider.horizontal.3"
        }
    }
    
    var color: Color {
        switch self {
        case .expense: return .red
        case .income: return .green
        case .transfer: return .blue
        case .adjustment: return .gray
        }
    }
}

extension Transaction {
    var typeEnum: TransactionType {
        get {
            guard let typeString = type, let value = TransactionType(rawValue: typeString) else {
                return .expense
            }
            return value
        }
        set {
            type = newValue.rawValue
        }
    }
    
    var itemsArray: [TransactionItem] {
        let set = items as? Set<TransactionItem> ?? []
        return set.sorted { $0.title ?? "" < $1.title ?? "" }
    }
    
    var formattedAmount: String {
        let code = account?.currency ?? SettingsManager.shared.currencyCode
        let formatter = Formatters.currencyFormatter(for: code)
        
        let prefix = typeEnum == .expense ? "-" : (typeEnum == .income ? "+" : "")
        let formatted = formatter.string(from: NSNumber(value: abs(amount))) ?? "$0.00"
        
        return "\(prefix)\(formatted)"
    }
    
    var formattedBalanceAfter: String {
        let code = account?.currency ?? SettingsManager.shared.currencyCode
        let formatter = Formatters.currencyFormatter(for: code)
        return formatter.string(from: NSNumber(value: balanceAfter)) ?? "$0.00"
    }
    
    @objc var daySectionIdentifier: String {
        guard let date = date else { return "" }
        return Formatters.date.string(from: date)
    }

    // MARK: - Installment Helpers

    /// Returns true if this transaction is part of an installment plan
    var isPartOfInstallment: Bool {
        return installmentPlanID != nil
    }

    /// Returns formatted installment label (e.g., "Payment 3/12")
    var installmentLabel: String? {
        guard let planID = installmentPlanID,
              let plan = recurringTransaction,
              plan.id == planID else {
            return nil
        }

        let number = installmentNumber ?? 0
        guard number > 0 else { return nil }

        let limit = plan.occurrenceLimit ?? 0
        return "Payment \(number)/\(limit)"
    }

    /// Returns formatted installment detail (e.g., "3 of 12 • $900 remaining")
    var installmentDetail: String? {
        guard let planID = installmentPlanID,
              let plan = recurringTransaction,
              plan.id == planID else {
            return nil
        }

        let remaining = plan.remainingAmount
        let code = account?.currency ?? SettingsManager.shared.currencyCode
        let formatter = Formatters.currencyFormatter(for: code)
        let remainingStr = formatter.string(from: NSNumber(value: remaining)) ?? "$0"

        return "\(plan.formattedProgress) • \(remainingStr) remaining"
    }
}

extension TransactionItem {
    var formattedAmount: String {
        let code = transaction?.account?.currency ?? SettingsManager.shared.currencyCode
        let formatter = Formatters.currencyFormatter(for: code)
        
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}
