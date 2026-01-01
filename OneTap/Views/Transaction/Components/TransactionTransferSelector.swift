//
//  TransactionTransferSelector.swift
//  OneTap
//

import SwiftUI

struct TransactionTransferSelector: View {
    let selectedAccount: Account?
    let toAccount: Account?
    let onSelectFrom: () -> Void
    let onSelectTo: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            transferAccountBox(title: "From", account: selectedAccount, action: onSelectFrom)
            Image(systemName: "arrow.down")
                .font(.title2)
                .foregroundColor(AppTheme.textTertiary)
            transferAccountBox(title: "To", account: toAccount, action: onSelectTo)
            Spacer()
        }
        .padding()
    }
    
    @ViewBuilder
    private func transferAccountBox(title: String, account: Account?, action: @escaping () -> Void) -> some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
            Text(account?.name ?? "Select Account")
                .font(.headline)
                .foregroundColor(account == nil && title == "To" ? AppTheme.expense : AppTheme.textPrimary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppTheme.secondaryBackground)
        .cornerRadius(12)
        .onTapGesture(perform: action)
    }
}
