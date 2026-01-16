//
//  ClaimModel.swift
//  OneTap
//
//  Model extensions for Claim entity
//

import Foundation
@preconcurrency internal import CoreData
import SwiftUI

enum ClaimStatus: String, CaseIterable {
    case pending
    case settled
}

extension Claim {
    var statusEnum: ClaimStatus {
        get { ClaimStatus(rawValue: status ?? "pending") ?? .pending }
        set { status = newValue.rawValue }
    }

    var isSettled: Bool {
        statusEnum == .settled
    }

    var formattedAmount: String {
        let formatter = Formatters.currencyFormatter(for: account?.currency ?? "USD")
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }

    var formattedSubmittedDate: String {
        guard let date = submittedDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    var formattedSettledDate: String? {
        guard let date = settledDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    static func seedDefaults(context: NSManagedObjectContext) {
        // Seed sample claims if needed for testing
    }
}
