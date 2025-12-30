//
//  TransactionListView.swift
//  OneTap
//
//  Created by Jimmy Hew on 29/12/2025.
//

import SwiftUI
import CoreData

struct TransactionListView: View {
    @FetchRequest private var transactions: FetchedResults<Transaction>
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingAddTransaction = false
    
    init(filterPredicate: NSPredicate? = nil) {
        let sortDescriptors = [NSSortDescriptor(keyPath: \Transaction.date, ascending: false)]
        
        if let predicate = filterPredicate {
            _transactions = FetchRequest<Transaction>(
                sortDescriptors: sortDescriptors,
                predicate: predicate,
                animation: .default
            )
        } else {
            _transactions = FetchRequest<Transaction>(
                sortDescriptors: sortDescriptors,
                animation: .default
            )
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if transactions.isEmpty {
                    emptyStateView
                } else {
                    transactionsList
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Transactions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddTransaction = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppTheme.accent)
                }
            }
        }
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showingAddTransaction) {
            AddTransactionView()
        }
        .preferredColorScheme(.dark)
    }
    
    private var transactionsList: some View {
        VStack(spacing: 12) {
            ForEach(transactions) { transaction in
                TransactionRow(transaction: transaction)
                    .contextMenu {
                        Button(role: .destructive) {
                            deleteTransaction(transaction)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.textTertiary)
            
            Text("No Transactions Yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
            
            Text("Add your first transaction to start tracking")
                .font(.system(size: 15))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                showingAddTransaction = true
            } label: {
                Text("Add Transaction")
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
    
    private func deleteTransaction(_ transaction: Transaction) {
        withAnimation {
            viewContext.delete(transaction)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Error deleting transaction: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}