//
//  AccountViewModel.swift
//  OneTap
//
//  Created by Jimmy Hew on 29/12/2025.
//

import Foundation
import CoreData
import SwiftUI
import Combine

class AccountViewModel: ObservableObject {
    @Published var accounts: [Account] = []
    
    private let viewContext: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
        fetchAccounts()
    }
    
    func fetchAccounts() {
        let request = NSFetchRequest<Account>(entityName: "Account")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Account.name, ascending: true)]
        
        do {
            accounts = try viewContext.fetch(request)
        } catch {
            print("Error fetching accounts: \(error)")
        }
    }
    
    func addAccount(name: String, type: AccountType, balance: Double, currency: String, icon: String) {
        let newAccount = Account(context: viewContext)
        newAccount.id = UUID()
        newAccount.name = name
        newAccount.type = type.rawValue
        newAccount.balance = balance
        newAccount.currency = currency
        newAccount.icon = icon
        newAccount.createdAt = Date()
        
        saveContext()
        fetchAccounts()
    }
    
    func updateAccount(_ account: Account, name: String, type: AccountType, balance: Double, currency: String, icon: String) {
        account.name = name
        account.type = type.rawValue
        account.balance = balance
        account.currency = currency
        account.icon = icon
        
        saveContext()
        fetchAccounts()
    }
    
    func deleteAccount(_ account: Account) {
        viewContext.delete(account)
        saveContext()
        fetchAccounts()
    }
    
    func totalAssets() -> Double {
        accounts.filter { !$0.isLiability }.reduce(0) { $0 + $1.balance }
    }
    
    func totalLiabilities() -> Double {
        accounts.filter { $0.isLiability }.reduce(0) { $0 + abs($1.balance) }
    }
    
    func netWorth() -> Double {
        totalAssets() - totalLiabilities()
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
}