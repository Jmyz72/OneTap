//
//  AccountTransactionList.swift
//  OneTap
//
//  Created by Jimmy Hew on 30/12/2025.
//

import SwiftUI
internal import CoreData

struct AccountTransactionList: View {
    @ObservedObject var account: Account
    
    @FetchRequest var transactions: FetchedResults<Transaction>
    
    init(account: Account) {
        self.account = account
        _transactions = FetchRequest(
            entity: Transaction.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \Transaction.date, ascending: false)],
            predicate: NSPredicate(format: "account == %@", account),
            animation: .default
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(transactions) { transaction in
                VStack(spacing: 0) {
                    NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                        HStack(spacing: 12) {
                            // Date
                            VStack(alignment: .center, spacing: 2) {
                                Text(day(from: transaction.date))
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(AppTheme.textPrimary)
                                Text(month(from: transaction.date))
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(AppTheme.textSecondary)
                                    .textCase(.uppercase)
                            }
                            .frame(width: 40)
                            
                            // Info
                            VStack(alignment: .leading, spacing: 4) {
                                Text(transaction.title ?? "Unknown")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(AppTheme.textPrimary)
                                    .lineLimit(1)
                                
                                Text(transaction.category?.name ?? "Uncategorized")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            
                            Spacer()
                            
                            // Amounts
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(transaction.formattedAmount)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(amountColor(for: transaction))
                                
                                Text("Bal: " + transaction.formattedBalanceAfter)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(AppTheme.textTertiary)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                    }
                    .buttonStyle(.plain)
                    
                    if transaction != transactions.last {
                        Divider()
                            .background(Color.white.opacity(0.05))
                            .padding(.leading, 68)
                    }
                }
            }
        }
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
    
    private func day(from date: Date?) -> String {
        guard let date = date else { return "--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd"
        return formatter.string(from: date)
    }
    
    private func month(from date: Date?) -> String {
        guard let date = date else { return "---" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
    
    private func amountColor(for transaction: Transaction) -> Color {
        switch transaction.typeEnum {
        case .expense: return AppTheme.expense
        case .income: return AppTheme.income
        case .transfer: return AppTheme.textPrimary
        case .adjustment: return AppTheme.textSecondary
        }
    }
}
