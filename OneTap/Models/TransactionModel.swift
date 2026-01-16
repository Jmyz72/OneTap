//
//  TransactionModel.swift
//  OneTap
//

import Foundation
import SwiftUI
@preconcurrency internal import CoreData

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
        guard let planID = installmentPlanID else { return nil }

        // Try to get plan from relationship first
        var plan = recurringTransaction

        // If relationship is nil, fetch it directly
        if plan == nil || plan?.id != planID {
            guard let context = managedObjectContext else { return nil }
            let request: NSFetchRequest<RecurringTransaction> = RecurringTransaction.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", planID as CVarArg)
            request.fetchLimit = 1
            plan = try? context.fetch(request).first
        }

        guard let validPlan = plan else { return nil }

        let number = installmentNumber
        guard number > 0 else { return nil }

        let limit = validPlan.occurrenceLimit
        return "Payment \(number)/\(limit)"
    }

    /// Returns formatted installment detail (e.g., "3 of 12 • $900 remaining")
    var installmentDetail: String? {
        guard let planID = installmentPlanID else { return nil }

        // Try to get plan from relationship first
        var plan = recurringTransaction

        // If relationship is nil, fetch it directly
        if plan == nil || plan?.id != planID {
            guard let context = managedObjectContext else { return nil }
            let request: NSFetchRequest<RecurringTransaction> = RecurringTransaction.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", planID as CVarArg)
            request.fetchLimit = 1
            plan = try? context.fetch(request).first
        }

        guard let validPlan = plan else { return nil }

        let remaining = validPlan.remainingAmount
        let code = account?.currency ?? SettingsManager.shared.currencyCode
        let formatter = Formatters.currencyFormatter(for: code)
        let remainingStr = formatter.string(from: NSNumber(value: remaining)) ?? "$0"

        return "\(validPlan.formattedProgress) • \(remainingStr) remaining"
    }

    // MARK: - Claim Helpers

    /// Returns the claim associated with this transaction, if any
    var claim: Claim? {
        guard let transactionID = id, let context = managedObjectContext else { return nil }

        let request: NSFetchRequest<Claim> = Claim.fetchRequest()
        request.predicate = NSPredicate(format: "originalTransactionID == %@", transactionID as CVarArg)
        request.fetchLimit = 1

        return try? context.fetch(request).first
    }

    /// Returns true if this transaction has a pending claim
    var hasPendingClaim: Bool {
        guard let claim = claim else { return false }
        return claim.statusEnum == .pending
    }

    /// Returns true if this transaction has a settled claim
    var hasSettledClaim: Bool {
        guard let claim = claim else { return false }
        return claim.statusEnum == .settled
    }
}

extension TransactionItem {
    var formattedAmount: String {
        let code = transaction?.account?.currency ?? SettingsManager.shared.currencyCode
        let formatter = Formatters.currencyFormatter(for: code)
        
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}
