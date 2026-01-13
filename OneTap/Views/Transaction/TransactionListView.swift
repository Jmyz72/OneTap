//
//  TransactionListView.swift
//  OneTap
//
//  REFACTORED: Now uses TransactionListViewModel (MVVM pattern)
//

import SwiftUI
@preconcurrency internal import CoreData

struct TransactionListView: View {
    @EnvironmentObject private var container: DependencyContainer
    @State private var viewModel: TransactionListViewModel?

    var body: some View {
        NavigationStack {
            if let viewModel {
                TransactionListContent(viewModel: viewModel)
            } else {
                ProgressView()
                    .onAppear {
                        if viewModel == nil {
                            viewModel = container.makeTransactionListViewModel()
                        }
                    }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = container.makeTransactionListViewModel()
            }
        }
    }
}

private struct TransactionListContent: View {
    @ObservedObject var viewModel: TransactionListViewModel
    @State private var showingAddTransaction = false
    @State private var showingMonthPicker = false

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Month Selector Bar
                HStack {
                    Button(action: {
                        viewModel.goToPreviousMonth()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.secondaryBackground)
                            .cornerRadius(8)
                    }

                    Spacer()

                    Button(action: {
                        showingMonthPicker = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 14, weight: .semibold))
                            Text(viewModel.selectedMonthFormatted)
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(AppTheme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(AppTheme.secondaryBackground)
                        .cornerRadius(10)
                    }

                    Spacer()

                    Button(action: {
                        viewModel.goToNextMonth()
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.secondaryBackground)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(AppTheme.background)

                FilteredTransactionList(
                    viewModel: viewModel,
                    onAddTap: { showingAddTransaction = true }
                )
            }

            // Floating Action Button - Bottom Right
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { showingAddTransaction = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(width: 56, height: 56)
                            .background(
                                LinearGradient(
                                    colors: [AppTheme.accent, AppTheme.accent.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                            .shadow(color: AppTheme.accent.opacity(0.4), radius: 12, x: 0, y: 6)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("Transactions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ProfileButton()
            }
        }
        .sheet(isPresented: $showingAddTransaction) {
            AddTransactionView()
        }
        .sheet(isPresented: $showingMonthPicker) {
            MonthPickerSheet(selectedMonth: $viewModel.selectedMonth)
                .presentationDetents([.medium])
        }
        .searchable(text: Binding(
            get: { viewModel.searchText },
            set: { viewModel.searchText = $0 }
        ), prompt: "Search transactions")
        // MVVM: Error handling
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
    }
}

struct FilteredTransactionList: View {
    @ObservedObject var viewModel: TransactionListViewModel
    var onAddTap: () -> Void

    var body: some View {
        if viewModel.sectionedTransactions.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.sections, id: \.self) { sectionKey in
                        if let transactions = viewModel.sectionedTransactions[sectionKey] {
                            dateHeader(for: sectionKey, transactions: transactions)

                            ForEach(transactions, id: \.objectID) { transaction in
                                NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                                    TransactionRow(transaction: transaction)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .padding(.bottom, 90)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.textTertiary)

            Text("No transactions found")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)

            Button(action: onAddTap) {
                Text("Add Transaction")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppTheme.accent)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func dateHeader(for sectionKey: String, transactions: [Transaction]) -> some View {
        HStack {
            Text(sectionKey)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppTheme.textSecondary)
                .textCase(.uppercase)

            Spacer()

            Text(viewModel.calculateSectionTotal(for: sectionKey))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(AppTheme.background)
    }
}

// MARK: - Month Picker Sheet

struct MonthPickerSheet: View {
    @Binding var selectedMonth: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker(
                    "Select Month",
                    selection: $selectedMonth,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding()

                Spacer()
            }
            .background(AppTheme.background)
            .navigationTitle("Select Month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accent)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        TransactionListView()
            .environmentObject(DependencyContainer(persistenceController: .preview))
    }
}