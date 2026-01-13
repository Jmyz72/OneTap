//
//  CategoryListView.swift
//  OneTap
//
//  REFACTORED: Now uses CategoryListViewModel (MVVM pattern)
//

import SwiftUI
@preconcurrency internal import CoreData

struct CategoryListView: View {
    @EnvironmentObject private var container: DependencyContainer

    @State private var viewModel: CategoryListViewModel?

    // UI State (view-only state)
    @State private var showingAddSheet = false
    @State private var editingCategory: Category?
    @State private var expandedCategories: Set<UUID> = []

    var body: some View {
        Group {
            if let viewModel {
                List {
                    Section("Expenses") {
                        if viewModel.expenseCategories.isEmpty {
                            Text("No expense categories")
                                .foregroundColor(AppTheme.textSecondary)
                                .font(.caption)
                        }
                        ForEach(viewModel.expenseCategories, id: \.objectID) { category in
                            categoryRow(category)
                        }
                        .onMove { source, destination in
                            Task {
                                await viewModel.moveExpenseCategories(from: source, to: destination)
                            }
                        }
                        .onDelete { offsets in
                            Task {
                                await viewModel.deleteExpenseCategories(at: offsets)
                            }
                        }
                    }

                    Section("Income") {
                        if viewModel.incomeCategories.isEmpty {
                            Text("No income categories")
                                .foregroundColor(AppTheme.textSecondary)
                                .font(.caption)
                        }
                        ForEach(viewModel.incomeCategories, id: \.objectID) { category in
                            categoryRow(category)
                        }
                        .onMove { source, destination in
                            Task {
                                await viewModel.moveIncomeCategories(from: source, to: destination)
                            }
                        }
                        .onDelete { offsets in
                            Task {
                                await viewModel.deleteIncomeCategories(at: offsets)
                            }
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(role: .destructive) {
                                Task { await viewModel.resetCategories() }
                            } label: {
                                Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingAddSheet = true }) {
                            Image(systemName: "plus")
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
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
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Categories")
        .sheet(isPresented: $showingAddSheet) {
            CategoryFormView()
        }
        .sheet(item: $editingCategory) { category in
            CategoryFormView(categoryToEdit: category)
        }
        .onAppear {
            // Initialize ViewModel from injected container
            if viewModel == nil {
                viewModel = container.makeCategoryListViewModel()
            }
        }
    }

    private func categoryRow(_ category: Category) -> some View {
        let isExpanded = expandedCategories.contains(category.id ?? UUID())
        let subcategories = (category.subCategories?.allObjects as? [SubCategory])?.sorted { $0.order < $1.order } ?? []
        let hasSubcategories = !subcategories.isEmpty

        return VStack(spacing: 0) {
            // Main Category Row
            Button {
                if hasSubcategories {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        if isExpanded {
                            expandedCategories.remove(category.id ?? UUID())
                        } else {
                            expandedCategories.insert(category.id ?? UUID())
                        }
                    }
                } else {
                    editingCategory = category
                }
            } label: {
                HStack(spacing: 12) {
                    // Category Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        category.colorView.opacity(0.2),
                                        category.colorView.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(category.colorView.opacity(0.3), lineWidth: 1)
                            )

                        Image(systemName: category.iconName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [category.colorView, category.colorView.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.name ?? "Unnamed")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)

                        if hasSubcategories {
                            Text("\(subcategories.count) subcategories")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }

                    Spacer()

                    // Expand/Edit Icon
                    if hasSubcategories {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.textTertiary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    } else {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(category.colorView.opacity(0.6))
                    }
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Subcategories Dropdown
            if isExpanded && hasSubcategories {
                VStack(spacing: 0) {
                    ForEach(subcategories, id: \.objectID) { subCategory in
                        subcategoryRow(subCategory, parentCategory: category)
                    }

                    // Edit Category Button
                    Button {
                        editingCategory = category
                    } label: {
                        HStack {
                            Image(systemName: "pencil.line")
                                .font(.system(size: 14))
                                .foregroundColor(category.colorView)

                            Text("Edit \(category.name ?? "Category")")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppTheme.textSecondary)

                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .padding(.leading, 52)
                        .background(AppTheme.secondaryBackground.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func subcategoryRow(_ subCategory: SubCategory, parentCategory: Category) -> some View {
        HStack(spacing: 12) {
            // Indent indicator
            Rectangle()
                .fill(parentCategory.colorView.opacity(0.3))
                .frame(width: 3)
                .padding(.leading, 20)

            // Subcategory Icon
            ZStack {
                Circle()
                    .fill(parentCategory.colorView.opacity(0.1))
                    .frame(width: 28, height: 28)

                Image(systemName: subCategory.displayIcon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(parentCategory.colorView.opacity(0.8))
            }

            Text(subCategory.name ?? "Unnamed")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.leading, 8)
        .background(AppTheme.secondaryBackground.opacity(0.3))
    }
}

#Preview {
    NavigationStack {
        CategoryListView()
            .environmentObject(DependencyContainer(persistenceController: .preview))
    }
}
