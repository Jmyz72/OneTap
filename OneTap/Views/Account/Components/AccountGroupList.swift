//
//  AccountGroupList.swift
//  OneTap
//
//  Created by Jimmy Hew on 04/01/2026.
//

import SwiftUI

struct AccountGroupList: View {
    @ObservedObject var viewModel: AccountListViewModel
    @Binding var accountToEdit: Account?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(AccountGroup.allCases) { group in
                if let groupAccounts = viewModel.groupedAccounts[group], !groupAccounts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        // Group Header
                        HStack {
                            Text(group.rawValue)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppTheme.textSecondary)
                                .textCase(.uppercase)
                            
                            Spacer()
                            
                            Text("\(groupAccounts.count)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(AppTheme.textTertiary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppTheme.secondaryBackground)
                                .cornerRadius(6)
                        }
                        .padding(.horizontal, 4)
                        
                        // Group Accounts
                        ForEach(groupAccounts, id: \.objectID) { account in
                            NavigationLink(destination: AccountDetailView(account: account)) {
                                AccountRow(account: account)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    accountToEdit = account
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.deleteAccount(account)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
