//
//  OneTapApp.swift
//  OneTap
//
//  Created by Jimmy Hew on 29/12/2025.
//

import SwiftUI
import CoreData

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
