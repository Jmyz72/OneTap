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

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.managedObjectContext, dependencyContainer.persistenceController.container.viewContext)
                .environmentObject(dependencyContainer)
        }
    }
}
