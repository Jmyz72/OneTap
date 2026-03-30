//
//  Persistence.swift
//  OneTap
//
//  Created by Jimmy Hew on 29/12/2025.
//

import Combine
@preconcurrency internal import CoreData

class PersistenceController {
    static let shared = PersistenceController()

    /// Flag indicating if migration failed and recovery is needed
    @Published var migrationFailed = false
    private var pendingStoreDescription: NSPersistentStoreDescription?

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Seed default categories
        Category.seedDefaults(context: viewContext)
        try? viewContext.save()
        
        // Fetch categories for later use
        let categoryFetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        let categories = (try? viewContext.fetch(categoryFetchRequest)) ?? []
        
        let foodCategory = categories.first(where: { $0.name == "Food & Drinks" })
        let transportCategory = categories.first(where: { $0.name == "Transport" })
        let salaryCategory = categories.first(where: { $0.name == "Salary" })
        
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
        let t1 = Transaction(context: viewContext)
        t1.id = UUID()
        t1.title = "Nasi Lemak"
        t1.amount = 12.50
        t1.date = Calendar.current.date(bySettingHour: 8, minute: 30, second: 0, of: Date())
        t1.type = TransactionType.expense.rawValue
        t1.account = checkingAccount
        t1.category = foodCategory
        t1.createdAt = Date()
        t1.updatedAt = Date()
        
        let t2 = Transaction(context: viewContext)
        t2.id = UUID()
        t2.title = "Petrol"
        t2.amount = 80.00
        t2.date = Calendar.current.date(bySettingHour: 18, minute: 15, second: 0, of: Date().addingTimeInterval(-86400))
        t2.type = TransactionType.expense.rawValue
        t2.account = creditCard
        t2.category = transportCategory
        t2.createdAt = Date()
        t2.updatedAt = Date()
        
        let t3 = Transaction(context: viewContext)
        t3.id = UUID()
        t3.title = "Salary December"
        t3.amount = 6500.00
        t3.date = Date().addingTimeInterval(-86400 * 5)
        t3.type = TransactionType.income.rawValue
        t3.account = checkingAccount
        t3.category = salaryCategory
        t3.createdAt = Date()
        t3.updatedAt = Date()

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer
    private var contextSaveObserver: NSObjectProtocol?

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "OneTap")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Enable lightweight migration
        if let description = container.persistentStoreDescriptions.first {
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true

            // Add file protection for security (data encrypted when device is locked)
            description.setOption(
                FileProtectionType.complete as NSObject,
                forKey: NSPersistentStoreFileProtectionKey
            )
        }
        
        container.loadPersistentStores(completionHandler: { [weak self] (storeDescription, error) in
            if let error = error as NSError? {
                // Migration or loading failed - handle gracefully
                // Common codes: 134140 (migration), 134110 (incompatible store)
                if error.code == 134140 || error.code == 134110 || error.domain == NSCocoaErrorDomain {
                    print("Database migration/loading failed: \(error.localizedDescription)")

                    // Store the description for later recovery
                    self?.pendingStoreDescription = storeDescription
                    self?.migrationFailed = true

                    // Notify the UI through MigrationErrorHandler
                    if let url = storeDescription.url {
                        Task { @MainActor in
                            MigrationErrorHandler.shared.handleMigrationFailure(error: error, storeURL: url)
                        }
                    }

                    // Attempt automatic backup before any destructive action
                    if let url = storeDescription.url {
                        self?.createBackup(of: url)
                    }
                } else {
                    // Non-migration errors - log but don't crash
                    print("Persistent store error: \(error), \(error.userInfo)")
                }
            }
        })

        // Configure view context to automatically merge and refresh changes from background contexts
        container.viewContext.automaticallyMergesChangesFromParent = true

        // CRITICAL FIX: Ensure objects are refreshed when background contexts save
        // This ensures Transaction.balanceAfter updates are immediately visible in the UI
        contextSaveObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            // Only handle saves from background contexts, not the view context itself
            guard let context = notification.object as? NSManagedObjectContext,
                  context !== self.container.viewContext,
                  context.persistentStoreCoordinator === self.container.persistentStoreCoordinator else {
                return
            }

            // Extract updated object IDs before entering perform block to avoid capturing non-Sendable Notification
            let updatedObjectIDs: [NSManagedObjectID] = (notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject>)?
                .map { $0.objectID } ?? []

            // Merge changes into view context
            self.container.viewContext.perform {
                // Refresh updated objects to ensure UI shows latest values
                for objectID in updatedObjectIDs {
                    // Get the object in the view context and refresh it
                    if let viewContextObject = try? self.container.viewContext.existingObject(with: objectID) {
                        self.container.viewContext.refresh(viewContextObject, mergeChanges: true)
                    }
                }

                if !updatedObjectIDs.isEmpty {
                    // CRITICAL: Process pending changes to trigger .NSManagedObjectContextObjectsDidChange
                    // This ensures Combine publishers and observers are notified
                    self.container.viewContext.processPendingChanges()
                }
            }
        }
        
        // Seed categories if empty
        seedCategoriesIfEmpty()
    }

    deinit {
        if let observer = contextSaveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func seedCategoriesIfEmpty() {
        let context = container.viewContext
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.fetchLimit = 1

        do {
            let count = try context.count(for: request)
            if count == 0 {
                Category.seedDefaults(context: context)
                try context.save()
            }
        } catch {
            print("Error with categories: \(error)")
        }
    }
    
    func deleteAllData() async throws {
        // Use viewContext directly for simplicity and immediate UI updates for this rare action
        // or use performBackgroundTask but ensure strict saving
        
        await container.viewContext.perform {
            // Entities to delete (order matters less for cascade, but good practice)
            let entities = ["Budget", "TransactionItem", "Transaction", "Account", "SubCategory", "Category"]
            
            for entityName in entities {
                let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
                if let objects = try? self.container.viewContext.fetch(fetchRequest) {
                    for object in objects {
                        self.container.viewContext.delete(object)
                    }
                }
            }
            
            // Save deletion
            try? self.container.viewContext.save()
            
            // Re-seed default categories
            Category.seedDefaults(context: self.container.viewContext)
            try? self.container.viewContext.save()
        }
    }

    // NOTE: Balance recalculation logic has been moved to BalanceService
    // for better separation of concerns and testability.
    // Use DependencyContainer.balanceService.recalculateBalances() instead.

    // MARK: - Migration Recovery

    /// Creates a backup of the database before destructive operations
    private func createBackup(of storeURL: URL) {
        let fileManager = FileManager.default
        let backupURL = storeURL.deletingLastPathComponent()
            .appendingPathComponent("OneTap_backup_\(Date().timeIntervalSince1970).sqlite")

        do {
            // Backup the main store file
            if fileManager.fileExists(atPath: storeURL.path) {
                try fileManager.copyItem(at: storeURL, to: backupURL)
                print("Database backup created at: \(backupURL.path)")
            }

            // Also backup WAL and SHM files if they exist
            let walURL = storeURL.appendingPathExtension("wal")
            let shmURL = storeURL.appendingPathExtension("shm")

            if fileManager.fileExists(atPath: walURL.path) {
                try fileManager.copyItem(at: walURL, to: backupURL.appendingPathExtension("wal"))
            }
            if fileManager.fileExists(atPath: shmURL.path) {
                try fileManager.copyItem(at: shmURL, to: backupURL.appendingPathExtension("shm"))
            }
        } catch {
            print("Failed to create backup: \(error.localizedDescription)")
        }
    }

    /// Resets the database by destroying and recreating the persistent store
    /// Call this after user confirms they want to reset their data
    func resetDatabaseAfterMigrationFailure() {
        guard let storeDescription = pendingStoreDescription,
              let url = storeDescription.url else {
            print("No pending store description to reset")
            return
        }

        do {
            // Destroy the incompatible store
            try container.persistentStoreCoordinator.destroyPersistentStore(
                at: url,
                ofType: storeDescription.type,
                options: nil
            )
            print("Persistent store destroyed for recovery")

            // Retry loading the store
            container.loadPersistentStores { [weak self] _, retryError in
                if let retryError = retryError {
                    print("Failed to recreate store after reset: \(retryError.localizedDescription)")
                } else {
                    print("Store successfully recreated")
                    self?.migrationFailed = false
                    self?.pendingStoreDescription = nil

                    // Re-seed default categories
                    self?.seedCategoriesIfEmpty()

                    Task { @MainActor in
                        MigrationErrorHandler.shared.reset()
                    }
                }
            }
        } catch {
            print("Failed to destroy persistent store during reset: \(error.localizedDescription)")
        }
    }
}
