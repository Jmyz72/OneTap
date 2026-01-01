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
                
                // Credit Card Visualization (if available)
                if let last4 = account.lastFourDigits, !last4.isEmpty {
                    creditCardView(last4: last4)
                }
                
                // Quick Stats
                quickStatsCard
                
                // Transactions Header
                HStack {
                    Text("History")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                }
                
                // Transaction List
                AccountTransactionList(account: account)
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
    
    private func creditCardView(last4: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    // Custom Chip View
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.9, green: 0.8, blue: 0.5), // Gold light
                                    Color(red: 0.7, green: 0.6, blue: 0.3)  // Gold dark
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 30)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.black.opacity(0.2), lineWidth: 1)
                        )
                        .overlay(
                            // Chip lines
                            HStack(spacing: 0) {
                                Divider().background(Color.black.opacity(0.2))
                                Spacer()
                                Divider().background(Color.black.opacity(0.2))
                            }
                            .padding(.horizontal, 10)
                        )
                        .overlay(
                            // Chip lines vertical
                            VStack(spacing: 0) {
                                Divider().background(Color.black.opacity(0.2))
                                Spacer()
                                Divider().background(Color.black.opacity(0.2))
                            }
                            .padding(.vertical, 8)
                        )
                    
                    Spacer()
                    
                    Image(systemName: "wave.3.right")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("••••")
                    Text("••••")
                    Text("••••")
                    Text(last4)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                }
                .foregroundColor(.white.opacity(0.9))
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CARD HOLDER")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                        Text(account.name?.uppercased() ?? "NAME")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    if account.typeEnum == .creditCard {
                        // Assuming generic Visa/Mastercard style logo if specific asset not known
                        // Just text for now or simple circle
                        Circle()
                            .fill(Color.white.opacity(0.8))
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .fill(Color.white.opacity(0.6))
                                    .frame(width: 20, height: 20)
                                    .offset(x: -12)
                            )
                    }
                }
            }
        }
        .padding(24)
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [accountColor.opacity(0.8), accountColor.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .shadow(color: accountColor.opacity(0.3), radius: 10, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
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