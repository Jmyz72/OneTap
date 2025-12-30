//
//  AccountFormView.swift
//  OneTap
//
//  Created by Jimmy Hew on 29/12/2025.
//

import SwiftUI
import CoreData

struct AccountFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // Optional template to pre-fill data
    var template: AccountTemplate?
    // Optional account to edit
    var accountToEdit: Account?
    
    @State private var name: String = ""
    @State private var institution: String = ""
    @State private var type: AccountType = .checking
    @State private var balance: String = ""
    @State private var creditLimit: String = ""
    @State private var currency: String = SettingsManager.shared.currencyCode
    @State private var billingDay: Int = 1
    @State private var dueDay: Int = 1
    @State private var icon: String = "creditcard.fill"
    
    let currencies = SettingsManager.shared.availableCurrencies
    let days = Array(1...31)
    
    var body: some View {
        Form {
            Section(header: Text("Details")) {
                // Icon Preview
                HStack {
                    Spacer()
                    AccountIconView(iconName: icon, color: type.color, size: 40)
                    Spacer()
                }
                .padding(.vertical, 8)
                
                TextField("Account Name", text: $name)
                TextField("Institution (Optional)", text: $institution)
                Picker("Type", selection: $type) {
                    ForEach(AccountType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                Picker("Currency", selection: $currency) {
                    ForEach(currencies, id: \.self) { code in
                        Text(code).tag(code)
                    }
                }
            }
            
            Section(header: Text("Financials")) {
                HStack {
                    Text(currency)
                        .foregroundStyle(.secondary)
                    TextField("Current Balance", text: $balance)
                        .keyboardType(.decimalPad)
                }
                
                if type == .creditCard || type == .bnpl {
                    HStack {
                        Text(currency)
                            .foregroundStyle(.secondary)
                        TextField("Credit Limit", text: $creditLimit)
                            .keyboardType(.decimalPad)
                    }
                    
                    Picker("Billing Cycle Date", selection: $billingDay) {
                        ForEach(days, id: \.self) { day in
                            Text("Day \(day)").tag(day)
                        }
                    }
                    
                    Picker("Payment Due Date", selection: $dueDay) {
                        ForEach(days, id: \.self) { day in
                            Text("Day \(day)").tag(day)
                        }
                    }
                }
            }
        }
        .navigationTitle(accountToEdit != nil ? "Edit Account" : (template != nil ? "Add \(template!.name)" : "Add Account"))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveAccount()
                }
                .disabled(name.isEmpty || balance.isEmpty)
            }
        }
        .onAppear {
            if let account = accountToEdit {
                name = account.name ?? ""
                institution = account.institution ?? ""
                type = account.typeEnum
                currency = account.currency ?? SettingsManager.shared.currencyCode
                balance = String(format: "%.2f", account.balance)
                creditLimit = String(format: "%.2f", account.creditLimit)
                billingDay = account.billingDay > 0 ? account.billingDay : 1
                dueDay = account.dueDay > 0 ? account.dueDay : 1
                icon = account.icon ?? type.icon
            } else if let template = template {
                name = template.name
                institution = template.institution
                type = template.type
                icon = template.displayIcon
            } else {
                // Manual add
                icon = type.icon
            }
        }
        .onChange(of: type) { oldType, newType in
            // Only update icon if it was a default system icon, preserve custom image if set
            if template == nil && UIImage(named: icon) == nil {
                 icon = newType.icon
            }
        }
    }
    
    private func saveAccount() {
        let account = accountToEdit ?? Account(context: viewContext)
        
        if accountToEdit == nil {
            account.id = UUID()
            account.createdAt = Date()
        }
        
        account.name = name
        account.institution = institution
        account.type = type.rawValue
        account.currency = currency
        account.balance = Double(balance) ?? 0.0
        account.creditLimit = Double(creditLimit) ?? 0.0
        account.icon = icon
        
        if type == .creditCard || type == .bnpl {
            account.billingDay = billingDay
            account.dueDay = dueDay
        } else {
            // Reset if changing type away from credit
            account.billingDay = 0
            account.dueDay = 0
        }
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving account: \(error)")
        }
    }
}
