//
//  TransactionAmountDisplay.swift
//  OneTap
//

import SwiftUI
@preconcurrency internal import CoreData

struct TransactionAmountDisplay: View {
    let amountString: String
    let selectedAccount: Account?
    let splitItems: [SplitItemData]
    let selectedType: TransactionType
    
    var body: some View {
        VStack(spacing: 4) {
            if !splitItems.isEmpty {
                 Text("Total: \(totalWithPendingText)")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }
            
            HStack(spacing: 4) {
                Text(selectedAccount?.currency ?? SettingsManager.shared.currencyCode)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.bottom, 6)

                Text(formattedAmount)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(amountColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(AppTheme.background)
    }
    
    // Convert cents string to dollars for display
    private var formattedAmount: String {
        let cents = Double(amountString) ?? 0
        let dollars = cents / 100.0
        return String(format: "%.2f", dollars)
    }

    private var currentTotal: Double {
        splitItems.reduce(0) { $0 + $1.amount }
    }

    private var totalWithPendingText: String {
        let cents = Double(amountString) ?? 0
        let pending = cents / 100.0
        let total = currentTotal + pending
        let code = selectedAccount?.currency ?? SettingsManager.shared.currencyCode
        return Formatters.currencyFormatter(for: code).string(from: NSNumber(value: total)) ?? ""
    }

    private var amountColor: Color {
        switch selectedType {
        case .expense: return AppTheme.expense
        case .income: return AppTheme.income
        case .transfer: return AppTheme.textPrimary
        case .adjustment: return AppTheme.textSecondary
        }
    }
}
