//
//  AccountPickerSheet.swift
//  OneTap
//

import SwiftUI

struct AccountPickerSheet: View {
    let accounts: FetchedResults<Account>
    @Binding var selectedAccount: Account?
    var excludeId: UUID? = nil
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List(accounts.filter { $0.id != excludeId }) { account in
                Button {
                    selectedAccount = account
                    dismiss()
                } label: {
                    HStack {
                        AccountIconView(iconName: account.icon ?? "creditcard", color: account.typeEnum.color, size: 24)
                        Text(account.name ?? "Unknown").foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        if selectedAccount?.id == account.id { Image(systemName: "checkmark").foregroundColor(AppTheme.accent) }
                    }
                }
            }
            .navigationTitle("Select Account")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
