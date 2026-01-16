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

    // State for OCR import deep linking
    @State private var ocrImportScreenshot: UIImage?
    @State private var showingOCRImport = false

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
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .sheet(isPresented: $showingOCRImport) {
                    if let screenshot = ocrImportScreenshot {
                        OCRImportView(screenshot: screenshot)
                    }
                }
        }
    }

    // MARK: - Deep Link Handling

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "onetap",
              url.host == "import-transaction" else {
            return
        }

        // Extract base64 image data from URL
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let imageBase64 = components?.queryItems?.first(where: { $0.name == "image" })?.value,
              let imageData = Data(base64Encoded: imageBase64),
              let image = UIImage(data: imageData) else {
            return
        }

        // Show OCR import screen
        ocrImportScreenshot = image
        showingOCRImport = true
    }
}
