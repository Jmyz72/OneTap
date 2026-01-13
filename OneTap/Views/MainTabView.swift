//
//  MainTabView.swift
//  OneTap
//
//  Created by Jimmy Hew on 29/12/2025.
//

import SwiftUI
@preconcurrency internal import CoreData

struct MainTabView: View {
    @State private var selectedTab = 2 // Start on Home (center tab)

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

            HomeTab()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(2)

            BudgetsTab()
                .tabItem {
                    Label("Budgets", systemImage: "chart.bar.fill")
                }
                .tag(3)

            AnalyticsTab()
                .tabItem {
                    Label("Analytics", systemImage: "chart.xyaxis.line")
                }
                .tag(4)
        }
        .accentColor(AppTheme.accent)
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

// MARK: - Budgets Tab
struct BudgetsTab: View {
    var body: some View {
        NavigationStack {
            BudgetListView()
        }
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