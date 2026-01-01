//
//  MainTabView.swift
//  OneTap
//
//  Created by Jimmy Hew on 29/12/2025.
//

import SwiftUI
import CoreData

struct MainTabView: View {
    var body: some View {
        TabView {
            TransactionsTab()
                .tabItem {
                    Label("Transactions", systemImage: "list.bullet.rectangle.fill")
                }
            
            AccountsTab()
                .tabItem {
                    Label("Accounts", systemImage: "building.columns.fill")
                }
            
            OverviewTab()
                .tabItem {
                    Label("Overview", systemImage: "chart.pie.fill")
                }
            
            MoreTab()
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle")
                }
        }
        .accentColor(AppTheme.accent)
        .preferredColorScheme(.dark)
        .onAppear {
            setupTabBarAppearance()
        }
    }
    
    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppTheme.secondaryBackground)
        
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

// MARK: - Overview Tab (Placeholder for future analytics)
struct OverviewTab: View {
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 70))
                        .foregroundColor(AppTheme.accent)
                    
                    Text("Overview")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text("Analytics and insights coming soon")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            .navigationTitle("Overview")
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

// MARK: - More Tab (Settings and additional features)
struct MoreTab: View {
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Settings Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Settings")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 0) {
                                MoreRow(icon: "gear", title: "Preferences", color: .blue)
                                Divider().padding(.leading, 60)
                                NavigationLink(destination: CategoryListView()) {
                                    MoreRowContent(icon: "folder.fill", title: "Categories", color: .orange)
                                }
                                Divider().padding(.leading, 60)
                                MoreRow(icon: "bell.fill", title: "Notifications", color: .purple)
                            }
                            .background(AppTheme.cardBackground)
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                        }
                        
                        // Data Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Data")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 0) {
                                MoreRow(icon: "square.and.arrow.up", title: "Export Data", color: .green)
                                Divider().padding(.leading, 60)
                                MoreRow(icon: "square.and.arrow.down", title: "Import Data", color: .teal)
                                Divider().padding(.leading, 60)
                                MoreRow(icon: "arrow.triangle.2.circlepath", title: "Backup & Sync", color: .indigo)
                            }
                            .background(AppTheme.cardBackground)
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                        }
                        
                        // About Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("About")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 0) {
                                HStack {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 22))
                                        .foregroundColor(.cyan)
                                        .frame(width: 36)
                                    
                                    Text("Version")
                                        .font(.system(size: 16))
                                        .foregroundColor(AppTheme.textPrimary)
                                    
                                    Spacer()
                                    
                                    Text("1.0.0")
                                        .font(.system(size: 15))
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                                .padding(16)
                            }
                            .background(AppTheme.cardBackground)
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("More")
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

struct MoreRow: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        Button {
            // Action will be added later
        } label: {
            MoreRowContent(icon: icon, title: title, color: color)
        }
    }
}

struct MoreRowContent: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)
                .frame(width: 36)
            
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(AppTheme.textPrimary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.textTertiary)
        }
        .padding(16)
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
