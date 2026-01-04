//
//  MainTabView.swift
//  OneTap
//
//  Created by Jimmy Hew on 29/12/2025.
//

import SwiftUI
internal import CoreData

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var previousTab = 0
    @State private var showingScanReceipt = false

    var body: some View {
        TabView(selection: $selectedTab) {
            TransactionsTab()
                .tabItem {
                    Label("Transactions", systemImage: "list.bullet.rectangle.fill")
                }
                .tag(0)

            AccountsTab()
                .tabItem {
                    Label("Accounts", systemImage: "building.columns.fill")
                }
                .tag(1)

            // Add Tab (Acts as a button)
            Color.clear
                .tabItem {
                    Label("Add", systemImage: "plus.circle.fill")
                }
                .tag(2)

            HomeTab()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(3)

            AnalyticsTab()
                .tabItem {
                    Label("Analytics", systemImage: "chart.bar.fill")
                }
                .tag(4)
        }
        .accentColor(AppTheme.accent)
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == 2 {
                // If "Add" tab is tapped, show sheet and revert tab
                showingScanReceipt = true
                selectedTab = oldValue
            } else {
                // Otherwise update the tracker
                previousTab = newValue
            }
        }
        .sheet(isPresented: $showingScanReceipt) {
            ScanReceiptView()
        }
        .preferredColorScheme(.dark)
        .onAppear {
            setupTabBarAppearance()
        }
    }

    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Transactions Tab
struct TransactionsTab: View {
    var body: some View {
        TransactionListView()
    }
}

// MARK: - Accounts Tab
struct AccountsTab: View {
    var body: some View {
        NavigationStack {
            AccountListView()
        }
    }
}

// MARK: - Home Tab
struct HomeTab: View {
    var body: some View {
        HomeView()
    }
}

// MARK: - Analytics Tab
struct AnalyticsTab: View {
    var body: some View {
        AnalyticsView()
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(DependencyContainer(persistenceController: .preview))
}