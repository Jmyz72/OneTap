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
        
        // Create sample transactions
        let sampleData: [(title: String, amount: Double, category: TransactionCategory, merchant: String, daysAgo: Int)] = [
            ("Grocery Shopping", 85.43, .food, "Whole Foods", 0),
            ("Monthly Salary", -4500.00, .salary, "Company Inc", 1),
            ("Uber to Airport", 45.20, .transport, "Uber", 2),
            ("Netflix Subscription", 15.99, .entertainment, "Netflix", 3),
            ("New Headphones", 199.99, .shopping, "Amazon", 4),
            ("Electricity Bill", 120.50, .bills, "PG&E", 5),
            ("Gym Membership", 50.00, .health, "Fitness Center", 7),
            ("Coffee", 5.75, .food, "Starbucks", 8),
            ("Stock Dividend", -125.00, .investment, "Trading App", 10),
            ("Gas Station", 60.00, .transport, "Shell", 12)
        ]
        
        for data in sampleData {
            let newTransaction = Transaction(context: viewContext)
            newTransaction.id = UUID()
            newTransaction.title = data.title
            newTransaction.amount = data.amount
            newTransaction.category = data.category.rawValue
            newTransaction.date = Calendar.current.date(byAdding: .day, value: -data.daysAgo, to: Date())
            newTransaction.merchant = data.merchant
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
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
