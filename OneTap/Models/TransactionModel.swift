//
//  TransactionModel.swift
//  OneTap
//
//  Created by Jimmy Hew on 29/12/2025.
//

import Foundation

/// Categories for transactions
enum TransactionCategory: String, CaseIterable, Identifiable {
    case food = "Food"
    case transport = "Transport"
    case entertainment = "Entertainment"
    case shopping = "Shopping"
    case bills = "Bills"
    case health = "Health"
    case salary = "Salary"
    case investment = "Investment"
    case other = "Other"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .transport: return "car.fill"
        case .entertainment: return "film.fill"
        case .shopping: return "cart.fill"
        case .bills: return "doc.text.fill"
        case .health: return "heart.fill"
        case .salary: return "dollarsign.circle.fill"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

/// Type of transaction (expense or income)
enum TransactionType: String, CaseIterable {
    case expense = "Expense"
    case income = "Income"
}

/// Extension to make Transaction entity more usable
extension Transaction {
    var categoryEnum: TransactionCategory? {
        guard let category = category else { return nil }
        return TransactionCategory(rawValue: category)
    }
    
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    var formattedDate: String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    var isExpense: Bool {
        amount >= 0
    }
}
