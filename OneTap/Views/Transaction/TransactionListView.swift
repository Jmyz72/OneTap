//
//  TransactionListView.swift
//  OneTap
//
//  REFACTORED: Now uses TransactionListViewModel (MVVM pattern)
//

import SwiftUI
import CoreData

struct TransactionListView: View {
    @EnvironmentObject private var container: DependencyContainer

    @StateObject private var viewModel: TransactionListViewModel

    // UI State (view-only state)
    @State private var showingAddTransaction = false

    // Keep @FetchRequest only for category picker UI
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)],
        animation: .default
    ) private var categories: FetchedResults<Category>

    init() {
        // Create temporary container and ViewModel
        let tempContainer = DependencyContainer()
        _viewModel = StateObject(wrappedValue: tempContainer.makeTransactionListViewModel())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Filter Status Bar
                    if viewModel.selectedCategoryFilter != nil || viewModel.selectedDateFilter != .all {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                if viewModel.selectedDateFilter != .all {
                                    FilterChip(text: viewModel.selectedDateFilter.rawValue, icon: "calendar") {
                                        viewModel.selectedDateFilter = .all
                                    }
                                }
                                if let category = viewModel.selectedCategoryFilter {
                                    FilterChip(text: category.name ?? "Category", icon: category.iconName) {
                                        viewModel.selectedCategoryFilter = nil
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }
                        .background(AppTheme.secondaryBackground)
                    }

                    FilteredTransactionList(
                        viewModel: viewModel,
                        onAddTap: { showingAddTransaction = true }
                    )
                }
            }
            .navigationTitle("Transactions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Menu {
                            Picker("Date Range", selection: $viewModel.selectedDateFilter) {
                                ForEach(DateFilter.allCases) { filter in
                                    Text(filter.rawValue).tag(filter)
                                }
                            }

                            Divider()

                            if !categories.isEmpty {
                                Menu("Category") {
                                    Button("All Categories") {
                                        viewModel.selectedCategoryFilter = nil
                                    }
                                    ForEach(categories) { category in
                                        Button(category.name ?? "Unknown") {
                                            viewModel.selectedCategoryFilter = category
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 20))
                                .foregroundColor((viewModel.selectedDateFilter != .all || viewModel.selectedCategoryFilter != nil) ? AppTheme.accent : AppTheme.textPrimary)
                        }

                        Button(action: { showingAddTransaction = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(AppTheme.accent)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddTransaction) {
                AddTransactionView()
            }
            .searchable(text: $viewModel.searchText, prompt: "Search transactions")
            // MVVM: Error handling
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
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
                    ForEach(viewModel.sortedSectionKeys, id: \.self) { sectionKey in
                        if let transactions = viewModel.sectionedTransactions[sectionKey] {
                            dateHeader(for: sectionKey, transactions: transactions)

                            ForEach(transactions) { transaction in
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
                .padding(.bottom, 20)
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

            Text(calculateTotal(for: transactions))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(AppTheme.background)
    }

    private func calculateTotal(for transactions: [Transaction]) -> String {
        let total = transactions.reduce(0.0) { sum, t in
            if t.typeEnum == .expense {
                return sum - t.amount
            } else if t.typeEnum == .income {
                return sum + t.amount
            }
            return sum
        }

        let formatter = Formatters.currencyFormatter(for: SettingsManager.shared.currencyCode)
        return formatter.string(from: NSNumber(value: total)) ?? "$0.00"
    }
}

struct FilterChip: View {
    let text: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))

                Text(text)
                    .font(.system(size: 13, weight: .medium))

                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .padding(4)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(AppTheme.accent)
            .foregroundColor(.black)
            .cornerRadius(20)
        }
    }
}

// DateFilter enum moved to shared location or ViewModel
enum DateFilter: String, CaseIterable, Identifiable {
    case all = "All Time"
    case thisMonth = "This Month"
    case lastMonth = "Last Month"
    case thisYear = "This Year"

    var id: String { rawValue }
}

#Preview {
    NavigationStack {
        TransactionListView()
            .environmentObject(DependencyContainer(persistenceController: .preview))
    }
}
