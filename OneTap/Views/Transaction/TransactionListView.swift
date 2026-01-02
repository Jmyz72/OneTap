//
//  TransactionListView.swift
//  OneTap
//
//  REFACTORED: Now uses TransactionListViewModel (MVVM pattern)
//

import SwiftUI
internal import CoreData

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

    // Keep @FetchRequest only for category picker UI
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)],
        animation: .default
    ) private var categories: FetchedResults<Category>

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Filter Status Bar
                if viewModel.selectedCategoryFilter != nil || viewModel.selectedSubCategoryFilter != nil || viewModel.selectedDateFilter != .all {
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
                                    viewModel.selectedSubCategoryFilter = nil
                                }
                            }
                            if let subCategory = viewModel.selectedSubCategoryFilter {
                                FilterChip(text: subCategory.name ?? "Subcategory", icon: subCategory.displayIcon) {
                                    viewModel.selectedSubCategoryFilter = nil
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
                        Picker("Date Range", selection: Binding(
                            get: { viewModel.selectedDateFilter },
                            set: { viewModel.selectedDateFilter = $0 }
                        )) {
                            ForEach(DateFilter.allCases) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }

                        Divider()

                        if !categories.isEmpty {
                            Menu("Category") {
                                Button("All Categories") {
                                    viewModel.selectedCategoryFilter = nil
                                    viewModel.selectedSubCategoryFilter = nil
                                }
                                ForEach(categories) { category in
                                    Button(category.name ?? "Unknown") {
                                        viewModel.selectedCategoryFilter = category
                                        viewModel.selectedSubCategoryFilter = nil
                                    }
                                }
                            }
                        }

                        if let category = viewModel.selectedCategoryFilter,
                           let subcategories = category.subCategories?.allObjects as? [SubCategory],
                           !subcategories.isEmpty {
                            Menu("Subcategory") {
                                Button("All Subcategories") {
                                    viewModel.selectedSubCategoryFilter = nil
                                }
                                ForEach(subcategories.sorted { $0.order < $1.order }) { subCategory in
                                    Button(subCategory.name ?? "Unknown") {
                                        viewModel.selectedSubCategoryFilter = subCategory
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 20))
                            .foregroundColor((viewModel.selectedDateFilter != .all || viewModel.selectedCategoryFilter != nil || viewModel.selectedSubCategoryFilter != nil) ? AppTheme.accent : AppTheme.textPrimary)
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