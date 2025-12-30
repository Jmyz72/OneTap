//
//  AccountListView.swift
//  OneTap
//
//  Created by Jimmy Hew on 29/12/2025.
//

import SwiftUI
import CoreData

struct AccountListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var settings = SettingsManager.shared
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Account.name, ascending: true)],
        animation: .default)
    private var accounts: FetchedResults<Account>
    
    @State private var showingAddAccount = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Net Worth Card
                netWorthCard
                
                // Accounts Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Your Accounts")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                        
                        Spacer()
                        
                        Text("\(accounts.count)")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding(.horizontal, 20)
                    
                    if accounts.isEmpty {
                        emptyStateView
                    } else {
                        accountsList
                    }
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Accounts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddAccount = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppTheme.accent)
                }
            }
        }
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showingAddAccount) {
            AddAccountView()
        }
        .preferredColorScheme(.dark)
    }
    
    private var netWorthCard: some View {
        VStack(spacing: 16) {
            // Net Worth
            VStack(spacing: 8) {
                Text("Net Worth")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
                
                Text(formatCurrency(netWorth))
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Assets & Liabilities
            HStack(spacing: 40) {
                VStack(spacing: 6) {
                    Text("Assets")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                    
                    Text(formatCurrency(totalAssets))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.income)
                }
                
                VStack(spacing: 6) {
                    Text("Liabilities")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                    
                    Text(formatCurrency(totalLiabilities))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.expense)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [
                    AppTheme.cardBackground,
                    AppTheme.secondaryBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 20)
    }
    
    private var accountsList: some View {
        VStack(spacing: 24) {
            ForEach(AccountGroup.allCases) { group in
                let groupAccounts = accounts.filter { $0.group == group }
                
                if !groupAccounts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(group.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.textSecondary)
                            .textCase(.uppercase)
                            .padding(.leading, 4)
                        
                        VStack(spacing: 12) {
                            ForEach(groupAccounts) { account in
                                NavigationLink {
                                    AccountDetailView(account: account)
                                } label: {
                                    AccountRow(account: account)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "building.columns")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.textTertiary)
            
            Text("No Accounts Yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
            
            Text("Add your first account to start tracking your finances")
                .font(.system(size: 15))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                showingAddAccount = true
            } label: {
                Text("Add Account")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(AppTheme.accent)
                    .cornerRadius(12)
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var totalAssets: Double {
        accounts.filter { !$0.isLiability }.reduce(0) { $0 + $1.balance }
    }
    
    private var totalLiabilities: Double {
        accounts.filter { $0.isLiability }.reduce(0) { $0 + abs($1.balance) }
    }
    
    private var netWorth: Double {
        totalAssets - totalLiabilities
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = settings.currencyCode // Use selected currency
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}
