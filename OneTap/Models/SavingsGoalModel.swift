//
//  SavingsGoalModel.swift
//  OneTap
//
//  Extensions for SavingsGoal entity with computed properties
//

import Foundation
@preconcurrency internal import CoreData

extension SavingsGoal {

    // MARK: - Progress Tracking

    /// Progress as a value from 0.0 to 1.0+ (can exceed 1.0 if target reached)
    var progress: Double {
        guard targetAmount > 0, let account = account else { return 0 }
        return account.balance / targetAmount
    }

    /// Progress clamped between 0 and 1 for UI display
    var progressClamped: Double {
        min(max(progress, 0), 1)
    }

    /// Progress as percentage (0-100+)
    var progressPercentage: Int {
        Int(progress * 100)
    }

    /// Amount remaining to reach target
    var amountRemaining: Double {
        guard let account = account else { return targetAmount }
        return max(0, targetAmount - account.balance)
    }

    /// Whether the savings goal has been reached
    var isComplete: Bool {
        guard let account = account else { return false }
        return account.balance >= targetAmount
    }

    // MARK: - Monthly Contribution Calculation

    /// Number of months remaining until target date
    var monthsRemaining: Int? {
        guard let targetDate = targetDate, targetDate > Date() else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month], from: Date(), to: targetDate)
        return max(1, components.month ?? 1)
    }

    /// Monthly contribution needed to reach goal by target date
    var monthlyContributionNeeded: Double? {
        guard let months = monthsRemaining, months > 0, amountRemaining > 0 else { return nil }
        return amountRemaining / Double(months)
    }

    // MARK: - Formatted Strings

    /// Formatted target amount using account's currency
    var formattedTargetAmount: String {
        let currencyCode = account?.currency ?? SettingsManager.shared.currencyCode
        let formatter = Formatters.currencyFormatter(for: currencyCode)
        return formatter.string(from: NSNumber(value: targetAmount)) ?? "$0"
    }

    /// Formatted amount remaining
    var formattedAmountRemaining: String {
        let currencyCode = account?.currency ?? SettingsManager.shared.currencyCode
        let formatter = Formatters.currencyFormatter(for: currencyCode)
        return formatter.string(from: NSNumber(value: amountRemaining)) ?? "$0"
    }

    /// Formatted monthly contribution needed
    var formattedMonthlyNeeded: String? {
        guard let monthly = monthlyContributionNeeded else { return nil }
        let currencyCode = account?.currency ?? SettingsManager.shared.currencyCode
        let formatter = Formatters.currencyFormatter(for: currencyCode)
        return formatter.string(from: NSNumber(value: monthly))
    }

    /// Formatted target date
    var formattedTargetDate: String? {
        guard let date = targetDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }

    /// Short progress string for account row (e.g., "35% of $10,000")
    var progressSummary: String {
        "\(progressPercentage)% of \(formattedTargetAmount)"
    }
}
