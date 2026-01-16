//
//  SettingsView.swift
//  OneTap
//
//  Settings and preferences view
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var container: DependencyContainer
    @State private var viewModel: SettingsViewModel?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let viewModel {
                SettingsContent(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = container.makeSettingsViewModel()
            }
        }
    }
}

private struct SettingsContent: View {
    @EnvironmentObject private var container: DependencyContainer
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showingClearDataAlert = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
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
                            SettingsRow(icon: "gear", title: "Preferences", color: .blue)
                            Divider().padding(.leading, 60)
                            NavigationLink(destination: CategoryListView()) {
                                SettingsRowContent(icon: "folder.fill", title: "Categories", color: .orange)
                            }
                            Divider().padding(.leading, 60)

                            NavigationLink(destination: RecurringTransactionsListView()) {
                                SettingsRowContent(icon: "repeat", title: "Recurring", color: .purple)
                            }
                            Divider().padding(.leading, 60)

                            SettingsRow(icon: "bell.fill", title: "Notifications", color: .pink)
                        }
                        .background(AppTheme.cardBackground)
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }

                    // Features Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Features")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(.horizontal, 20)

                        VStack(spacing: 0) {
                            NavigationLink(destination: OCRSettingsView()) {
                                SettingsRowContent(icon: "camera.viewfinder", title: "Screenshot Import", color: .cyan)
                            }
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
                            SettingsRow(icon: "square.and.arrow.up", title: "Export Data", color: .green)
                            Divider().padding(.leading, 60)
                            SettingsRow(icon: "square.and.arrow.down", title: "Import Data", color: .teal)
                            Divider().padding(.leading, 60)
                            SettingsRow(icon: "arrow.triangle.2.circlepath", title: "Backup & Sync", color: .indigo)
                            Divider().padding(.leading, 60)
                            Button {
                                showingClearDataAlert = true
                            } label: {
                                SettingsRowContent(icon: "trash.fill", title: "Clear All Data", color: .red)
                            }
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
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .alert("Clear All Data", isPresented: $showingClearDataAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.clearAllData()
                }
            }
        } message: {
            Text("This will permanently delete all your accounts, transactions, and custom categories. This action cannot be undone.")
        }
        .overlay {
            if viewModel.loadingState.isLoading {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    ProgressView().scaleEffect(1.5).tint(.white)
                }
            }
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        Button {
            // Action will be added later
        } label: {
            SettingsRowContent(icon: icon, title: title, color: color)
        }
    }
}

struct SettingsRowContent: View {
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
    NavigationStack {
        SettingsView()
            .environmentObject(DependencyContainer(persistenceController: .preview))
    }
}
