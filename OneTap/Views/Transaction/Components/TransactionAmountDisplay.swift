//
//  TransactionAmountDisplay.swift
//  OneTap
//

import SwiftUI
internal import CoreData

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
                
                Text(amountString)
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
    
    private var currentTotal: Double {
        splitItems.reduce(0) { $0 + $1.amount }
    }
    
    private var totalWithPendingText: String {
        let pending = Double(amountString) ?? 0
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
