//
//  PaymentCycleType.swift
//  OneTap
//
//  Payment cycle type enums for installment plans
//

import Foundation

enum PaymentCycleType: String, CaseIterable, Identifiable {
    case monthlyFixed = "monthlyFixed"
    case weekly = "weekly"
    case biweekly = "biweekly"
    case rolling = "rolling"
    case consolidated = "consolidated"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .monthlyFixed: return "Monthly Fixed Day"
        case .weekly: return "Weekly"
        case .biweekly: return "Bi-Weekly"
        case .rolling: return "Custom Rolling Cycle"
        case .consolidated: return "Consolidated Billing"
        }
    }

    var description: String {
        switch self {
        case .monthlyFixed:
            return "Due on the same day each month"
        case .weekly:
            return "Due every 7 days"
        case .biweekly:
            return "Due every 14 days"
        case .rolling:
            return "Due every N days (custom)"
        case .consolidated:
            return "Follows credit card billing cycle"
        }
    }

    var icon: String {
        switch self {
        case .monthlyFixed: return "calendar"
        case .weekly: return "7.circle.fill"
        case .biweekly: return "14.circle.fill"
        case .rolling: return "arrow.clockwise"
        case .consolidated: return "creditcard"
        }
    }
}
