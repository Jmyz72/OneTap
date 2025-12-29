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
        List {
            ForEach(transactions) { transaction in
                TransactionRow(transaction: transaction)
            }
            .onDelete(perform: deleteTransactions)
        }
    }
    
    private func deleteTransactions(offsets: IndexSet) {
        withAnimation {
            offsets.map { transactions[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Error deleting transaction: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}
