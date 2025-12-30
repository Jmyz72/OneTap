//
//  AccountDetailView.swift
//  OneTap
//
//  Created by Jimmy Hew on 29/12/2025.
//

import SwiftUI
import CoreData

struct AccountDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    
    @ObservedObject var account: Account
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Account Header Card
                accountHeaderCard
                
                // Quick Stats
                quickStatsCard
                
                // Recent Transactions
                recentTransactionsSection
            }
            .padding(20)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(account.name ?? "Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.textPrimary)
                }
            }
        }
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                AccountFormView(accountToEdit: account)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showingEditSheet = false
                            }
                        }
                    }
            }
        }
        .alert("Delete Account", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("Are you sure you want to delete this account? This action cannot be undone.")
        }
        .preferredColorScheme(.dark)
    }
    
    private var accountHeaderCard: some View {
        VStack(spacing: 24) {
            // Icon
            AccountIconView(
                iconName: account.icon ?? "creditcard.fill",
                color: accountColor,
                size: 36
            )
            .shadow(color: accountColor.opacity(0.5), radius: 10)
            
            // Balance
            VStack(spacing: 8) {
                Text(account.name ?? "Unknown Account")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                
                Text(account.typeEnum.rawValue)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(AppTheme.secondaryBackground)
                    .cornerRadius(20)
                
                Text(formatCurrency(account.balance))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(balanceColor)
                    .padding(.top, 12)
                
                if account.isLiability {
                    Text("Liability Account")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.expense)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(AppTheme.expense.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppTheme.expense.opacity(0.3), lineWidth: 1)
                        )
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
        .background(
            ZStack {
                AppTheme.cardBackground
                // Subtle gradient overlay
                LinearGradient(
                    colors: [accountColor.opacity(0.1), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .cornerRadius(32)
        .overlay(
            RoundedRectangle(cornerRadius: 32)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 10)
    }
    
    private var quickStatsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                StatRow(title: "Currency", value: account.currency ?? SettingsManager.shared.currencyCode, isLast: false)
                StatRow(title: "Type", value: account.typeEnum.rawValue, isLast: false)
                
                if account.typeEnum == .creditCard || account.typeEnum == .bnpl {
                    if account.billingDay > 0 {
                        StatRow(title: "Billing Cycle", value: "Day \(account.billingDay)", isLast: false)
                    }
                    if account.dueDay > 0 {
                        StatRow(title: "Payment Due", value: "Day \(account.dueDay)", isLast: false)
                    }
                }
                
                StatRow(title: "Created", value: formatDate(account.createdAt), isLast: true)
            }
            .background(AppTheme.cardBackground)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
        }
    }
    
    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activity")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
                .padding(.leading, 4)
            
            if let transactions = account.transactions?.allObjects as? [Transaction], !transactions.isEmpty {
                VStack(spacing: 12) {
                    ForEach(transactions.prefix(5)) { transaction in
                        TransactionRow(transaction: transaction)
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.textTertiary)
                    
                    Text("No transactions yet")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(AppTheme.cardBackground.opacity(0.5))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
            }
        }
    }
    
    private var accountColor: Color {
        return account.typeEnum.color
    }
    
    private var balanceColor: Color {
        if account.isLiability {
            return AppTheme.expense
        }
        return account.balance >= 0 ? AppTheme.income : AppTheme.expense
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = account.currency ?? SettingsManager.shared.currencyCode
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func deleteAccount() {
        viewContext.delete(account)
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error deleting account: \(error)")
        }
    }
}

struct StatRow: View {
    let title: String
    let value: String
    let isLast: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.textSecondary)
                
                Spacer()
                
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(16)
            
            if !isLast {
                Divider()
                    .background(Color.white.opacity(0.05))
                    .padding(.leading, 16)
            }
        }
    }
}
