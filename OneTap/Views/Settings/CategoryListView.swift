//
//  CategoryListView.swift
//  OneTap
//
//  REFACTORED: Now uses CategoryListViewModel (MVVM pattern)
//

import SwiftUI
internal import CoreData

struct CategoryListView: View {
    @EnvironmentObject private var container: DependencyContainer

    @State private var viewModel: CategoryListViewModel?

    // UI State (view-only state)
    @State private var showingAddSheet = false
    @State private var editingCategory: Category?

    var body: some View {
        Group {
            if let viewModel {
                List {
                    Section("Expenses") {
                        ForEach(viewModel.expenseCategories) { category in
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
                        ForEach(viewModel.incomeCategories) { category in
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
        Button {
            editingCategory = category
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(category.colorView.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: category.iconName)
                        .font(.system(size: 14))
                        .foregroundColor(category.colorView)
                }

                Text(category.name ?? "Unnamed")
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()
            }
        }
    }
}

#Preview {
    NavigationStack {
        CategoryListView()
            .environmentObject(DependencyContainer(persistenceController: .preview))
    }
}
