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
                    Label("Transactions", systemImage: "list.bullet")
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
        // Use a slightly lighter dark for the tab bar to distinguish it from the deep black background
        appearance.backgroundColor = UIColor(AppTheme.secondaryBackground)
        
        // Remove the top line separator for a cleaner look
        appearance.shadowImage = UIImage()
        appearance.shadowColor = .clear
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Transactions Tab
struct TransactionsTab: View {
    var body: some View {
        NavigationStack {
            TransactionListView()
        }
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
                        .font(.system(size: 80))
                        .foregroundStyle(AppTheme.accentGradient)
                    
                    Text("Overview")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
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
    @ObservedObject var settings = SettingsManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Settings Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Settings")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(.horizontal, 8)
                        
                        VStack(spacing: 0) {
                            NavigationLink(destination: CurrencySelectionView()) {
                                MoreRowContent(icon: "banknote.fill", title: "Currency", subtitle: settings.currencyCode, color: AppTheme.accent, isLast: false)
                            }
                            
                            MoreRow(icon: "gear", title: "Preferences", color: .blue, isLast: false)
                            MoreRow(icon: "folder.fill", title: "Categories", color: .orange, isLast: false)
                            MoreRow(icon: "bell.fill", title: "Notifications", color: .purple, isLast: true)
                        }
                        .modernCardStyle()
                    }
                    
                    // Data Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Data")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(.horizontal, 8)
                        
                        VStack(spacing: 0) {
                            MoreRow(icon: "square.and.arrow.up", title: "Export Data", color: .green, isLast: false)
                            MoreRow(icon: "square.and.arrow.down", title: "Import Data", color: .teal, isLast: false)
                            MoreRow(icon: "arrow.triangle.2.circlepath", title: "Backup & Sync", color: .indigo, isLast: true)
                        }
                        .modernCardStyle()
                    }
                    
                    // About Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(.horizontal, 8)
                        
                        VStack(spacing: 0) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 22))
                                    .foregroundColor(.cyan)
                                    .frame(width: 36)
                                
                                Text("Version")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(AppTheme.textPrimary)
                                
                                Spacer()
                                
                                Text("1.0.0")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            .padding(16)
                        }
                        .modernCardStyle()
                    }
                }
                .padding(20)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

// Helper view for row content to be reused in Button or NavigationLink
struct MoreRowContent: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    let color: Color
    let isLast: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                    .frame(width: 32)
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
                
                Spacer()
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textTertiary)
            }
            .padding(16)
            
            if !isLast {
                Divider()
                    .background(Color.white.opacity(0.05))
                    .padding(.leading, 64)
            }
        }
    }
}

struct MoreRow: View {
    let icon: String
    let title: String
    let color: Color
    let isLast: Bool
    
    var body: some View {
        Button {
            // Action will be added later
        } label: {
            MoreRowContent(icon: icon, title: title, color: color, isLast: isLast)
        }
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}