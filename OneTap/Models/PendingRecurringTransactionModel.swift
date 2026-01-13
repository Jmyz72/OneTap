//
//  PendingRecurringTransactionModel.swift
//  OneTap
//
//  Model extensions for PendingRecurringTransaction entity
//

import Foundation
internal import CoreData

extension PendingRecurringTransaction {

    // MARK: - Type Helpers

    /// Transaction type enum
    var typeEnum: TransactionType {
        return TransactionType(rawValue: type ?? "Expense") ?? .expense
    }

    // MARK: - Formatted Display

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

    /// Formatted scheduled date
    var formattedScheduledDate: String {
        return Formatters.date.string(from: scheduledDate ?? Date())
    }

    /// Display title
    var displayTitle: String {
        return title ?? "Recurring Payment"
    }

    /// Status text for UI
    var statusText: String {
        guard let scheduledDate = scheduledDate else { return "Pending" }

        let calendar = Calendar.current
        if calendar.isDateInToday(scheduledDate) {
            return "Due Today"
        } else if calendar.isDateInTomorrow(scheduledDate) {
            return "Due Tomorrow"
        } else if scheduledDate < Date() {
            return "Overdue"
        } else {
            return "Pending"
        }
    }

    /// Color for status
    var statusColor: String {
        guard let scheduledDate = scheduledDate else { return "blue" }

        if scheduledDate < Date() {
            return "red"  // Overdue
        } else if Calendar.current.isDateInToday(scheduledDate) {
            return "orange"  // Due today
        } else {
            return "blue"  // Future
        }
    }

    // MARK: - Days Until Due

    /// Number of days until the scheduled date
    var daysUntilDue: Int {
        guard let scheduledDate = scheduledDate else { return 0 }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: scheduledDate)
        return components.day ?? 0
    }
}
