//
//  AppShortcuts.swift
//  OneTap
//
//  Auto-registers app shortcuts for Shortcuts app
//

import AppIntents

@available(iOS 16.0, *)
struct AppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ImportTransactionIntent(),
            phrases: [
                "Import transaction in \(.applicationName)",
                "Add receipt to \(.applicationName)",
                "Scan receipt in \(.applicationName)"
            ],
            shortTitle: "Import Transaction",
            systemImageName: "camera.viewfinder"
        )
    }
}
