//
//  BackgroundTaskManager.swift
//  OneTap
//
//  Manages background task scheduling for recurring transaction processing
//

import Foundation
import BackgroundTasks

@MainActor
class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()

    // Background task identifier - must match Info.plist
    private let taskIdentifier = "xxx.OneTap.processRecurringTransactions"

    private var recurringTransactionService: RecurringTransactionService?

    private init() {}

    /// Register background tasks - call this in application(_:didFinishLaunchingWithOptions:)
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let self = self else {
                task.setTaskCompleted(success: false)
                return
            }

            self.handleRecurringTransactionsProcessing(task: task as! BGProcessingTask)
        }
    }

    /// Schedule the next background processing task
    func scheduleRecurringTransactionsProcessing() {
        let request = BGProcessingTaskRequest(identifier: taskIdentifier)

        // Run once per day
        request.earliestBeginDate = Calendar.current.date(
            byAdding: .hour,
            value: 24,
            to: Date()
        )

        // Allow running on battery
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false

        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Scheduled recurring transactions background task")
        } catch {
            print("❌ Failed to schedule background task: \(error.localizedDescription)")
        }
    }

    /// Cancel all scheduled background tasks
    func cancelAllBackgroundTasks() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
    }

    /// Inject the recurring transaction service
    func configure(with service: RecurringTransactionService) {
        self.recurringTransactionService = service
    }

    // MARK: - Private

    private func handleRecurringTransactionsProcessing(task: BGProcessingTask) {
        // Schedule the next run
        scheduleRecurringTransactionsProcessing()

        // Create a task for async work
        let processingTask = Task {
            do {
                guard let service = recurringTransactionService else {
                    print("❌ RecurringTransactionService not configured")
                    return false
                }

                try await service.processRecurringTransactions()
                print("✅ Background processing completed successfully")
                return true
            } catch {
                print("❌ Background processing failed: \(error.localizedDescription)")
                return false
            }
        }

        // Handle task expiration
        task.expirationHandler = {
            processingTask.cancel()
        }

        // Wait for completion
        Task {
            let success = await processingTask.value
            task.setTaskCompleted(success: success)
        }
    }
}
