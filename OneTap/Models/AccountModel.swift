//
//  AccountModel.swift
//  OneTap
//
//  Created by Jimmy Hew on 29/12/2025.
//

import Foundation
import SwiftUI
import CoreData

enum AccountType: String, CaseIterable, Identifiable {
    case checking = "Checking"
    case savings = "Savings"
    case creditCard = "Credit Card"
    case bnpl = "Buy Now Pay Later"
    case investment = "Investment"
    case cash = "Cash"
    case other = "Other"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .checking: return "banknote"
        case .savings: return "building.columns"
        case .creditCard: return "creditcard"
        case .bnpl: return "clock.arrow.circlepath"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .cash: return "dollarsign.circle"
        case .other: return "questionmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .checking: return .blue
        case .savings: return .green
        case .creditCard: return .orange
        case .bnpl: return .purple
        case .investment: return .indigo
        case .cash: return .gray
        case .other: return .secondary
        }
    }
}

enum AccountGroup: String, CaseIterable, Identifiable {
    case funding = "Funding Accounts"
    case credit = "Credit Accounts"
    case financial = "Financial Accounts"
    
    var id: String { rawValue }
}

extension Account {
    var typeEnum: AccountType {
        get {
            guard let typeString = type, let value = AccountType(rawValue: typeString) else {
                return .other
            }
            return value
        }
        set {
            type = newValue.rawValue
        }
    }
    
    var group: AccountGroup {
        switch typeEnum {
        // Updated: Savings accounts are now considered Funding Accounts
        case .checking, .savings, .cash, .other:
            return .funding
        case .creditCard, .bnpl:
            return .credit
        case .investment:
            return .financial
        }
    }
    
    var isLiability: Bool {
        return typeEnum == .creditCard || typeEnum == .bnpl
    }
    
    // Helper formatted balance
    var formattedBalance: String {
        return Formatters.currency.string(from: NSNumber(value: balance)) ?? "$0.00"
    }
    
    // Helpers for billing and due dates (Core Data uses Int16)
    var billingDay: Int {
        get { Int(billingDate) }
        set { billingDate = Int16(newValue) }
    }
    
    var dueDay: Int {
        get { Int(dueDate) }
        set { dueDate = Int16(newValue) }
    }
}
