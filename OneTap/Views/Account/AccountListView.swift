//
//  AccountListView.swift
//  OneTap
//
//  REFACTORED: Now uses AccountListViewModel (MVVM pattern)
//

import SwiftUI
internal import CoreData

struct AccountListView: View {
    @EnvironmentObject private var container: DependencyContainer
    @ObservedObject var settings = SettingsManager.shared

    @State private var viewModel: AccountListViewModel?

    // UI State (view-only state)
    @State private var showingAddAccount = false
    @State private var accountToEdit: Account?

    var body: some View {
        Group {
            if let viewModel {
                List {
                    // Net Worth Card (Header)
                    Section {
                        netWorthCard(viewModel: viewModel)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .padding(.bottom, 10)
                    }

                    // Accounts Sections
                    if viewModel.accounts.isEmpty {
                        Section {
                            emptyStateView
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    } else {
                        ForEach(AccountGroup.allCases) { group in
                            let groupAccounts = viewModel.groupedAccounts[group] ?? []

                            if !groupAccounts.isEmpty {
                                Section(header:
                                    Text(group.rawValue)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(AppTheme.textSecondary)
                                        .textCase(.uppercase)
                                        .padding(.leading, 4)
                                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 0))
                                ) {
                                    ForEach(groupAccounts) { account in
                                        ZStack {
                                            NavigationLink(destination: AccountDetailView(account: account)) {
                                                EmptyView()
                                            }
                                            .opacity(0)

                                            AccountRow(account: account)
                                                .drawingGroup()
                                        }
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 12, trailing: 20))
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                Task {
                                                    await viewModel.deleteAccount(account)
                                                }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }

                                            Button {
                                                accountToEdit = account
                                            } label: {
                                                Label("Edit", systemImage: "pencil")
                                            }
                                            .tint(.blue)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .background(AppTheme.background.ignoresSafeArea())
                .scrollContentBackground(.hidden)
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
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Accounts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddAccount = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppTheme.accent)
                }
            }
        }
        .toolbarBackground(AppTheme.background, for: .navigationBar)
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
        .preferredColorScheme(.dark)
        .onAppear {
            // Initialize ViewModel from injected container
            if viewModel == nil {
                viewModel = container.makeAccountListViewModel()
            }
        }
    }

    private func netWorthCard(viewModel: AccountListViewModel) -> some View {
        VStack(spacing: 16) {
            // Net Worth
            VStack(spacing: 8) {
                Text("Net Worth")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)

                Text(viewModel.formatCurrency(viewModel.netWorth))
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
            }

            Divider()
                .background(Color.white.opacity(0.1))

            // Assets & Liabilities
            HStack(spacing: 40) {
                VStack(spacing: 6) {
                    Text("Assets")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)

                    Text(viewModel.formatCurrency(viewModel.totalAssets))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.income)
                }

                VStack(spacing: 6) {
                    Text("Liabilities")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)

                    Text(viewModel.formatCurrency(viewModel.totalLiabilities))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.expense)
                }
            }
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [
                    AppTheme.cardBackground,
                    AppTheme.secondaryBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "building.columns")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.textTertiary)

            Text("No Accounts Yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)

            Text("Add your first account to start tracking your finances")
                .font(.system(size: 15))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                showingAddAccount = true
            } label: {
                Text("Add Account")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(AppTheme.accent)
                    .cornerRadius(12)
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

#Preview {
    NavigationStack {
        AccountListView()
            .environmentObject(DependencyContainer(persistenceController: .preview))
    }
}
