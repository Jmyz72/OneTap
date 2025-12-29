//
//  MainTabView.swift
//  OneTap
//
//  Created by Jimmy Hew on 29/12/2025.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            TransactionsTab()
                .tabItem {
                    Label("Transactions", systemImage: "list.bullet")
                }
            
            OverviewTab()
                .tabItem {
                    Label("Overview", systemImage: "chart.pie.fill")
                }
            
            AssetsTab()
                .tabItem {
                    Label("Assets", systemImage: "chart.line.uptrend.xyaxis")
                }
            
            MoreTab()
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle")
                }
        }
    }
}

// MARK: - Transactions Tab
struct TransactionsTab: View {
    var body: some View {
        ContentView()
    }
}

// MARK: - Overview Tab (Placeholder for future analytics)
struct OverviewTab: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)
                
                Text("Overview")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Analytics and insights coming soon")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Overview")
        }
    }
}

// MARK: - Assets Tab (Placeholder for stocks, crypto, etc.)
struct AssetsTab: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                
                Text("Assets")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Track your stocks, crypto, and other assets")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .navigationTitle("Assets")
        }
    }
}

// MARK: - More Tab (Settings and additional features)
struct MoreTab: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Settings") {
                    NavigationLink(destination: Text("Settings")) {
                        Label("Preferences", systemImage: "gear")
                    }
                    
                    NavigationLink(destination: Text("Categories")) {
                        Label("Categories", systemImage: "folder.fill")
                    }
                }
                
                Section("Data") {
                    NavigationLink(destination: Text("Export")) {
                        Label("Export Data", systemImage: "square.and.arrow.up")
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("More")
        }
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
