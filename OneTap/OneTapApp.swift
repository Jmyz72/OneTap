//
//  OneTapApp.swift
//  OneTap
//
//  Created by Jimmy Hew on 29/12/2025.
//

import SwiftUI
internal import CoreData

@main
struct OneTapApp: App {
    @StateObject private var dependencyContainer = DependencyContainer()

    init() {
        // Register background tasks SYNCHRONOUSLY before app starts
        // This must happen before any scheduling attempts
        BackgroundTaskManager.shared.registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.managedObjectContext, dependencyContainer.persistenceController.container.viewContext)
                .environmentObject(dependencyContainer)
                .task {
                    // 1. Configure background task manager with service
                    BackgroundTaskManager.shared.configure(
                        with: dependencyContainer.recurringTransactionService
                    )

                    // 2. Process recurring transactions on app launch
                    do {
                        try await dependencyContainer.recurringTransactionService.processRecurringTransactions()
                    } catch {
                        print("Error processing recurring transactions: \(error)")
                    }

                    // 3. Schedule background processing (registration already done in init)
                    BackgroundTaskManager.shared.scheduleRecurringTransactionsProcessing()
                }
        }
    }
}
