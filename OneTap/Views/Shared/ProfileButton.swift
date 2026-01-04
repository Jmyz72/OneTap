//
//  ProfileButton.swift
//  OneTap
//
//  Reusable profile/settings button for navigation bar
//

import SwiftUI

struct ProfileButton: View {
    @State private var showingSettings = false

    var body: some View {
        Button {
            showingSettings = true
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.accent, AppTheme.accent.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)

                Image(systemName: "person.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
            }
        }
    }
}
