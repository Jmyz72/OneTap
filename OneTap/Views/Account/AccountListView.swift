//
//  AccountListView.swift
//  OneTap
//
//  REFACTORED: Clean, modern design with MVVM pattern
//

import SwiftUI
internal import CoreData

struct AccountListView: View {
    @EnvironmentObject private var container: DependencyContainer
    @State private var viewModel: AccountListViewModel?

    var body: some View {
        Group {
            if let viewModel {
                AccountListContent(viewModel: viewModel)
            } else {
                ProgressView()
                    .onAppear {
                        if viewModel == nil {
                            viewModel = container.makeAccountListViewModel()
                        }
                    }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = container.makeAccountListViewModel()
            }
        }
    }
}

private struct AccountListContent: View {
    @ObservedObject var viewModel: AccountListViewModel
    @ObservedObject var settings = SettingsManager.shared

    // UI State (view-only state)
    @State private var showingAddAccount = false
    @State private var accountToEdit: Account?

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Net Worth Overview
                    AccountNetWorthCard(viewModel: viewModel)

                    // Accounts List
                    if viewModel.accounts.isEmpty {
                        AccountEmptyState(showingAddAccount: $showingAddAccount)
                            .padding(.top, 40)
                    } else {
                        AccountGroupList(viewModel: viewModel, accountToEdit: $accountToEdit)
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 16)
            }
        }
        .navigationTitle("Accounts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        showingAddAccount = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(AppTheme.accent)
                    }

                    ProfileButton()
                }
            }
        }
        .toolbarBackground(AppTheme.backgroundSolid, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showingAddAccount) {
            AddAccountView(isPresented: $showingAddAccount)
        }
        .sheet(item: $accountToEdit) { account in
            NavigationStack {
                AccountFormView(accountToEdit: account)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                accountToEdit = nil
                            }
                        }
                    }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .overlay {
            if viewModel.loadingState.isLoading {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    NavigationStack {
        AccountListView()
            .environmentObject(DependencyContainer(persistenceController: .preview))
    }
}