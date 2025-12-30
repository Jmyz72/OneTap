//
//  Persistence.swift
//  OneTap
//
//  Created by Jimmy Hew on 29/12/2025.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample accounts
        let checkingAccount = Account(context: viewContext)
        checkingAccount.id = UUID()
        checkingAccount.name = "Maybank Checking"
        checkingAccount.type = AccountType.checking.rawValue
        checkingAccount.balance = 5240.75
        checkingAccount.currency = "MYR"
        checkingAccount.icon = AccountType.checking.icon
        checkingAccount.createdAt = Date()
        
        let savingsAccount = Account(context: viewContext)
        savingsAccount.id = UUID()
        savingsAccount.name = "ASB Savings"
        savingsAccount.type = AccountType.savings.rawValue
        savingsAccount.balance = 15000.00
        savingsAccount.currency = "MYR"
        savingsAccount.icon = AccountType.savings.icon
        savingsAccount.createdAt = Date()
        
        let creditCard = Account(context: viewContext)
        creditCard.id = UUID()
        creditCard.name = "CIMB Travel"
        creditCard.type = AccountType.creditCard.rawValue
        creditCard.balance = -1250.50
        creditCard.currency = "MYR"
        creditCard.icon = AccountType.creditCard.icon
        creditCard.createdAt = Date()
        
        // Create sample transactions
        let sampleData: [(title: String, amount: Double, category: TransactionCategory, merchant: String, daysAgo: Int, account: Account?)] = [
            ("Dinner at Pavilion", -85.43, .food, "Dining Co", 0, checkingAccount),
            ("Monthly Salary", 4500.00, .salary, "Corporate HQ", 1, checkingAccount),
            ("Grab to Office", -15.20, .transport, "Grab", 2, creditCard),
            ("Netflix Subscription", -55.00, .entertainment, "Netflix", 3, creditCard),
            ("Uniqlo Shopping", -199.99, .shopping, "Uniqlo", 4, creditCard),
            ("TNB Bill", -120.50, .bills, "TNB", 5, checkingAccount),
            ("Gym Membership", -150.00, .health, "Celebrity Fitness", 7, checkingAccount),
            ("Tealive", -7.75, .food, "Tealive", 8, creditCard),
            ("Dividends", 125.00, .investment, "Maybank", 10, savingsAccount),
            ("Gas Station", -90.00, .transport, "Petronas", 12, checkingAccount)
        ]
        
        for data in sampleData {
            let newTransaction = Transaction(context: viewContext)
            newTransaction.id = UUID()
            newTransaction.title = data.title
            newTransaction.amount = data.amount
            newTransaction.category = data.category.rawValue
            newTransaction.date = Calendar.current.date(byAdding: .day, value: -data.daysAgo, to: Date())
            newTransaction.merchant = data.merchant
            newTransaction.account = data.account
        }
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "OneTap")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
