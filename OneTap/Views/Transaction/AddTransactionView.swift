//
//  AddTransactionView.swift
//  OneTap
//
//  Created by Jimmy Hew on 29/12/2025.
//

import SwiftUI
import CoreData

struct AddTransactionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Account.name, ascending: true)],
        animation: .default)
    private var accounts: FetchedResults<Account>
    
    @State private var title: String = ""
    @State private var amount: String = ""
    @State private var category: TransactionCategory = .food
    @State private var date: Date = Date()
    @State private var merchant: String = ""
    @State private var isExpense: Bool = true
    @State private var selectedAccount: Account?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Type Selector
                    HStack(spacing: 12) {
                        TypeButton(
                            title: "Expense",
                            icon: "arrow.up.circle.fill",
                            color: AppTheme.expense,
                            isSelected: isExpense
                        ) {
                            isExpense = true
                        }
                        
                        TypeButton(
                            title: "Income",
                            icon: "arrow.down.circle.fill",
                            color: AppTheme.income,
                            isSelected: !isExpense
                        ) {
                            isExpense = false
                        }
                    }
                    
                    // Amount Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Amount")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                        
                        HStack {
                            Text("$")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(AppTheme.textPrimary)
                            
                            TextField("0.00", text: $amount)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(isExpense ? AppTheme.expense : AppTheme.income)
                                .keyboardType(.decimalPad)
                        }
                        .padding(16)
                        .background(AppTheme.secondaryBackground)
                        .cornerRadius(12)
                    }
                    
                    // Title Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                        
                        TextField("e.g., Grocery shopping", text: $title)
                            .textFieldStyle(ModernTextFieldStyle())
                    }
                    
                    // Category Selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(TransactionCategory.allCases) { cat in
                                    CategoryButton(
                                        category: cat,
                                        isSelected: category == cat
                                    ) {
                                        category = cat
                                    }
                                }
                            }
                        }
                    }
                    
                    // Account Selector (if accounts exist)
                    if !accounts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Account")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppTheme.textSecondary)
                            
                            Menu {
                                Button("None") {
                                    selectedAccount = nil
                                }
                                ForEach(accounts) { account in
                                    Button(account.name ?? "Unknown") {
                                        selectedAccount = account
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedAccount?.name ?? "Select account (optional)")
                                        .foregroundColor(selectedAccount == nil ? AppTheme.textTertiary : AppTheme.textPrimary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 14))
                                        .foregroundColor(AppTheme.textTertiary)
                                }
                                .padding(16)
                                .background(AppTheme.secondaryBackground)
                                .cornerRadius(12)
                            }
                        }
                    }
                    
                    // Date Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                        
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .padding(16)
                            .background(AppTheme.secondaryBackground)
                            .cornerRadius(12)
                    }
                    
                    // Merchant Input (Optional)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Merchant (Optional)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                        
                        TextField("e.g., Whole Foods", text: $merchant)
                            .textFieldStyle(ModernTextFieldStyle())
                    }
                }
                .padding(20)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("New Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.textSecondary)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTransaction()
                    }
                    .foregroundColor(AppTheme.accent)
                    .fontWeight(.semibold)
                    .disabled(title.isEmpty || amount.isEmpty)
                }
            }
            .toolbarBackground(AppTheme.secondaryBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
    
    private func saveTransaction() {
        guard !title.isEmpty, let amountValue = Double(amount) else { return }
        
        withAnimation {
            let newTransaction = Transaction(context: viewContext)
            newTransaction.id = UUID()
            newTransaction.title = title
            // Store expense as negative, income as positive
            newTransaction.amount = isExpense ? -amountValue : amountValue
            newTransaction.category = category.rawValue
            newTransaction.date = date
            newTransaction.merchant = merchant.isEmpty ? nil : merchant
            newTransaction.account = selectedAccount
            
            do {
                try viewContext.save()
                dismiss()
            } catch {
                let nsError = error as NSError
                print("Error saving transaction: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct TypeButton: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : AppTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? color : AppTheme.secondaryBackground)
            .cornerRadius(12)
        }
    }
}

struct CategoryButton: View {
    let category: TransactionCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : AppTheme.textSecondary)
                
                Text(category.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white : AppTheme.textSecondary)
            }
            .frame(width: 90, height: 80)
            .background(isSelected ? categoryColor : AppTheme.secondaryBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? categoryColor : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
            )
        }
    }
    
    private var categoryColor: Color {
        switch category {
        case .food: return .orange
        case .transport: return .blue
        case .entertainment: return .purple
        case .shopping: return .pink
        case .bills: return .red
        case .health: return .green
        case .salary: return AppTheme.income
        case .investment: return .indigo
        case .other: return .gray
        }
    }
}

struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(16)
            .background(AppTheme.secondaryBackground)
            .cornerRadius(12)
            .foregroundColor(AppTheme.textPrimary)
    }
}

#Preview {
    AddTransactionView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}