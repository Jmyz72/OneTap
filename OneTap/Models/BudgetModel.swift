import Foundation
import SwiftUI
internal import CoreData

extension Budget {
    // Computed property for progress percentage
    var progress: Double {
        guard amount > 0 else { return 0 }
        return (spent / amount) * 100
    }

    // Check if budget is exceeded
    var isExceeded: Bool {
        return spent > amount
    }

    // Remaining amount
    var remaining: Double {
        return max(0, amount - spent)
    }

    // Warning threshold (80%)
    var isNearLimit: Bool {
        return progress >= 80 && !isExceeded
    }

    // Formatted amounts
    var formattedAmount: String {
        let currencyCode = SettingsManager.shared.currencyCode
        let formatter = Formatters.currencyFormatter(for: currencyCode)
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }

    var formattedSpent: String {
        let currencyCode = SettingsManager.shared.currencyCode
        let formatter = Formatters.currencyFormatter(for: currencyCode)
        return formatter.string(from: NSNumber(value: spent)) ?? "$0.00"
    }

    var formattedRemaining: String {
        let currencyCode = SettingsManager.shared.currencyCode
        let formatter = Formatters.currencyFormatter(for: currencyCode)
        return formatter.string(from: NSNumber(value: remaining)) ?? "$0.00"
    }
    
    // Status color
    var statusColor: Color {
        if isExceeded {
            return AppTheme.expense // Red
        } else if isNearLimit {
            return .orange
        } else {
            return AppTheme.income // Green
        }
    }
}
