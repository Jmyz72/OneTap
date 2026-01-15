//
//  BudgetListView.swift
//  OneTap
//
//  Main budget view with category list and detail states
//

import SwiftUI
@preconcurrency internal import CoreData

struct BudgetListView: View {
    @EnvironmentObject private var container: DependencyContainer
    @State private var viewModel: BudgetViewModel?

    var body: some View {
        Group {
            if let viewModel {
                BudgetContentView(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = container.makeBudgetViewModel()
            }
        }
    }
}

// MARK: - Content View

private struct BudgetContentView: View {
    @ObservedObject var viewModel: BudgetViewModel
    @State private var showingNumpad = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                if viewModel.selectedCategory != nil {
                    // State 2: Category Detail
                    categoryDetailView
                } else {
                    // State 1: Category List
                    categoryListView
                }
            }
            .navigationTitle("Budgets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    monthSelector
                }
            }
            .sheet(isPresented: $showingNumpad) {
                BudgetNumpadSheet(viewModel: viewModel)
            }
            .onChange(of: viewModel.editContext) { _, newContext in
                showingNumpad = newContext != nil
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
            .task {
                await viewModel.loadData()
            }
        }
    }

    // MARK: - Month Selector

    private var monthSelector: some View {
        HStack(spacing: 16) {
            Button {
                viewModel.previousMonth()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
            }

            Text(viewModel.monthDisplayString)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)

            Button {
                viewModel.nextMonth()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
            }
        }
    }

    // MARK: - State 1: Category List

    private var categoryListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Summary Card
                summaryCard

                // Category List
                VStack(spacing: 0) {
                    ForEach(viewModel.categorySummaries) { summary in
                        Button {
                            handleCategoryTap(summary)
                        } label: {
                            BudgetRow(
                                summary: summary,
                                hasChevron: viewModel.hasSubCategories(summary.category)
                            )
                        }
                        .buttonStyle(.plain)

                        if summary.id != viewModel.categorySummaries.last?.id {
                            Divider()
                                .padding(.leading, 68)
                        }
                    }
                }
                .background(AppTheme.cardBackground)
                .cornerRadius(16)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    // MARK: - State 2: Category Detail

    private var categoryDetailView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Back button header
                HStack {
                    Button {
                        viewModel.deselectCategory()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.accent)
                    }

                    Spacer()
                }
                .padding(.horizontal)

                if let category = viewModel.selectedCategory,
                   let summary = viewModel.getSummary(for: category) {

                    // Category total budget row
                    VStack(spacing: 0) {
                        Button {
                            Task {
                                await viewModel.startEditing(category: category)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                BudgetRow(
                                    summary: summary,
                                    hasChevron: false
                                )

                                // Show minimum constraint if applicable
                                if summary.subCategoryBudgetTotal > 0 {
                                    Text("Min budget: \(formatCurrency(summary.subCategoryBudgetTotal)) (from subcategories)")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.textTertiary)
                                        .padding(.horizontal, 16)
                                        .padding(.bottom, 12)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .background(AppTheme.cardBackground)
                    .cornerRadius(16)
                    .padding(.horizontal)

                    // Subcategories section
                    if !viewModel.subCategorySummaries.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SUBCATEGORIES")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppTheme.textTertiary)
                                .padding(.horizontal)

                            VStack(spacing: 0) {
                                ForEach(viewModel.subCategorySummaries) { subSummary in
                                    Button {
                                        Task {
                                            await viewModel.startEditing(
                                                category: category,
                                                subCategory: subSummary.subCategory
                                            )
                                        }
                                    } label: {
                                        BudgetRow(summary: subSummary)
                                    }
                                    .buttonStyle(.plain)

                                    if subSummary.id != viewModel.subCategorySummaries.last?.id {
                                        Divider()
                                            .padding(.leading, 68)
                                    }
                                }
                            }
                            .background(AppTheme.cardBackground)
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Budget")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)

                    Text(viewModel.formattedTotalBudgeted)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Spent")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)

                    Text(viewModel.formattedTotalSpent)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(overallStatusColor)
                }
            }

            // Overall progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppTheme.secondaryBackground)
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(overallStatusColor)
                        .frame(width: min(geometry.size.width * viewModel.overallProgress, geometry.size.width), height: 12)
                }
            }
            .frame(height: 12)

            // Percentage
            HStack {
                Spacer()
                Text("\(Int(viewModel.overallProgress * 100))%")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(overallStatusColor)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private var overallStatusColor: Color {
        let progress = viewModel.overallProgress
        if progress > 1 {
            return AppTheme.expense
        } else if progress >= 0.8 {
            return .orange
        } else {
            return AppTheme.income
        }
    }

    private func handleCategoryTap(_ summary: CategorySpendingSummary) {
        if viewModel.hasSubCategories(summary.category) {
            // Has subcategories - expand to detail view
            Task {
                await viewModel.selectCategory(summary.category)
            }
        } else {
            // No subcategories - open numpad directly
            Task {
                await viewModel.startEditing(category: summary.category)
            }
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let currencyCode = SettingsManager.shared.currencyCode
        return Formatters.currencyFormatter(for: currencyCode).string(from: NSNumber(value: amount)) ?? "$0"
    }
}

#Preview {
    BudgetListView()
        .environmentObject(DependencyContainer(persistenceController: .preview))
}
