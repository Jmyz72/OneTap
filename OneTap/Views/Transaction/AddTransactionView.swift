//
//  AddTransactionView.swift
//  OneTap
//
//  Created by Jimmy Hew on 29/12/2025.
//

import SwiftUI

struct AddTransactionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String = ""
    @State private var amount: String = ""
    @State private var category: TransactionCategory = .food
    @State private var date: Date = Date()
    @State private var merchant: String = ""
    @State private var isExpense: Bool = true
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $isExpense) {
                        Text("Expense").tag(true)
                        Text("Income").tag(false)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("Transaction Details")) {
                    TextField("Title", text: $title)
                    
                    HStack {
                        Text("$")
                            .foregroundStyle(.secondary)
                        TextField("Amount", text: $amount)
                            .keyboardType(.decimalPad)
                    }
                    
                    Picker("Category", selection: $category) {
                        ForEach(TransactionCategory.allCases) { cat in
                            HStack {
                                Image(systemName: cat.icon)
                                Text(cat.rawValue)
                            }
                            .tag(cat)
                        }
                    }
                    
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                
                Section(header: Text("Optional")) {
                    TextField("Merchant", text: $merchant)
                }
            }
            .navigationTitle("New Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTransaction()
                    }
                    .disabled(title.isEmpty || amount.isEmpty)
                }
            }
        }
    }
    
    private func saveTransaction() {
        guard !title.isEmpty, let amountValue = Double(amount) else { return }
        
        withAnimation {
            let newTransaction = Transaction(context: viewContext)
            newTransaction.id = UUID()
            newTransaction.title = title
            // Store expense as positive, income as negative (for color coding)
            newTransaction.amount = isExpense ? amountValue : -amountValue
            newTransaction.category = category.rawValue
            newTransaction.date = date
            newTransaction.merchant = merchant.isEmpty ? nil : merchant
            
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

#Preview {
    AddTransactionView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
