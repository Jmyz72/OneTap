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
        // Register background tasks
        Task { @MainActor in
            BackgroundTaskManager.shared.registerBackgroundTasks()
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.managedObjectContext, dependencyContainer.persistenceController.container.viewContext)
                .environmentObject(dependencyContainer)
                .task {
                    // Configure background task manager
                    BackgroundTaskManager.shared.configure(
                        with: dependencyContainer.recurringTransactionService
                    )

                    // Process recurring transactions on app launch
                    do {
                        try await dependencyContainer.recurringTransactionService.processRecurringTransactions()
                    } catch {
                        print("Error processing recurring transactions: \(error)")
                    }

                    // Schedule background processing
                    BackgroundTaskManager.shared.scheduleRecurringTransactionsProcessing()
                }
        }
    }
}
