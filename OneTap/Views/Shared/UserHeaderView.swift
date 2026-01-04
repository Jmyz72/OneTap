//
//  UserHeaderView.swift
//  OneTap
//
//  User profile header shown at the top of the app
//

import SwiftUI

struct UserHeaderView: View {
    @EnvironmentObject private var container: DependencyContainer
    @State private var showingSettings = false

    var body: some View {
        HStack(spacing: 12) {
            // Profile Avatar
            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppTheme.accent, AppTheme.accent.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                )
                .shadow(color: AppTheme.accent.opacity(0.3), radius: 8, x: 0, y: 4)

            // User Info
            VStack(alignment: .leading, spacing: 2) {
                Text("Welcome back")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)

                Text("User")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
            }

            Spacer()

            // Settings Button
            Button {
                showingSettings = true
            } label: {
                ZStack {
                    Circle()
                        .fill(AppTheme.cardBackground)
                        .frame(width: 40, height: 40)

                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(AppTheme.secondaryBackground)
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
            }
        }
    }
}

#Preview {
    UserHeaderView()
        .environmentObject(DependencyContainer(persistenceController: .preview))
        .background(AppTheme.background)
}
