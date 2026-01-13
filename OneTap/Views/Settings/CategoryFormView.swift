//
//  CategoryFormView.swift
//  OneTap
//
//  REFACTORED: Now uses CategoryFormViewModel (MVVM pattern)
//

import SwiftUI
@preconcurrency internal import CoreData

struct CategoryFormView: View {
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.dismiss) private var dismiss

    let categoryToEdit: Category?
    @State private var viewModel: CategoryFormViewModel?

    // Sheet State for Subcategory (view-only UI state)
    @State private var showingSubSheet = false
    @State private var tempSubName = ""
    @State private var tempSubIcon = "tag.fill"

    init(categoryToEdit: Category? = nil) {
        self.categoryToEdit = categoryToEdit
    }

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    Form {
                        Section("Details") {
                            TextField("Category Name", text: Binding(
                                get: { viewModel.name },
                                set: { viewModel.name = $0 }
                            ))

                            Picker("Type", selection: Binding(
                                get: { viewModel.type },
                                set: { viewModel.type = $0 }
                            )) {
                                Text("Expense").tag(TransactionType.expense)
                                Text("Income").tag(TransactionType.income)
                            }
                            .pickerStyle(.segmented)
                            .disabled(viewModel.isEditing)
                        }

                        Section("Icon") {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                                ForEach(IconLibrary.icons, id: \.self) { iconName in
                                    Image(systemName: iconName)
                                        .font(.system(size: 24))
                                        .frame(width: 44, height: 44)
                                        .foregroundColor(viewModel.icon == iconName ? Color(hex: viewModel.color) : .gray)
                                        .background(viewModel.icon == iconName ? Color(hex: viewModel.color).opacity(0.15) : Color.clear)
                                        .cornerRadius(8)
                                        .onTapGesture {
                                            viewModel.icon = iconName
                                        }
                                }
                            }
                            .padding(.vertical, 8)
                        }

                        Section("Color") {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                                ForEach(IconLibrary.colors, id: \.self) { colorHex in
                                    Circle()
                                        .fill(Color(hex: colorHex))
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: viewModel.color == colorHex ? 3 : 0)
                                        )
                                        .onTapGesture {
                                            viewModel.color = colorHex
                                        }
                                        .frame(width: 44, height: 44)
                                }
                            }
                            .padding(.vertical, 8)
                        }

                        Section {
                            ForEach(viewModel.subCategories, id: \.objectID) { sub in
                                Button {
                                    startEditingSub(sub, viewModel: viewModel)
                                } label: {
                                    HStack {
                                        ZStack {
                                            Circle()
                                                .fill(Color(hex: viewModel.color).opacity(0.1))
                                                .frame(width: 32, height: 32)

                                            Image(systemName: sub.icon ?? "tag.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(Color(hex: viewModel.color))
                                        }

                                        Text(sub.name ?? "Unnamed")
                                            .foregroundColor(AppTheme.textPrimary)

                                        Spacer()

                                        Image(systemName: "pencil")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task {
                                            await viewModel.deleteSubCategory(sub)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            .onMove { from, to in
                                Task {
                                    await viewModel.moveSubCategory(from: from, to: to)
                                }
                            }

                            Button {
                                startAddingSub(viewModel: viewModel)
                            } label: {
                                Label("Add Subcategory", systemImage: "plus.circle.fill")
                                    .foregroundColor(AppTheme.accent)
                            }
                        } header: {
                            HStack {
                                Text("Subcategories")
                                Spacer()
                                Text("Drag to reorder")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)
                                    .textCase(.none)
                            }
                        }
                        .headerProminence(.increased)
                    }
                    .navigationTitle(viewModel.isEditing ? "Edit Category" : "New Category")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { dismiss() }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                Task {
                                    await viewModel.saveCategory()
                                }
                            }
                            .disabled(!viewModel.isValid || viewModel.loadingState.isLoading)
                        }
                    }
                    .sheet(isPresented: $showingSubSheet) {
                        SubCategoryFormView(
                            name: $tempSubName,
                            icon: $tempSubIcon,
                            onSave: { saveSubCategory(viewModel: viewModel) },
                            onDelete: viewModel.editingSubCategory != nil ? {
                                if let sub = viewModel.editingSubCategory {
                                    Task {
                                        await viewModel.deleteSubCategory(sub)
                                        showingSubSheet = false
                                    }
                                }
                            } : nil
                        )
                    }
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
                    // MVVM: Loading overlay
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
                    // MVVM: Auto-dismiss on success
                    .onChange(of: viewModel.loadingState) { _, newState in
                        if newState == .loaded {
                            dismiss()
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = container.makeCategoryFormViewModel(category: categoryToEdit)
                }
            }
        }
    }

    // MARK: - Subcategory Helpers

    private func startAddingSub(viewModel: CategoryFormViewModel) {
        viewModel.editingSubCategory = nil
        tempSubName = ""
        tempSubIcon = "tag.fill"
        showingSubSheet = true
    }

    private func startEditingSub(_ sub: SubCategory, viewModel: CategoryFormViewModel) {
        viewModel.editingSubCategory = sub
        tempSubName = sub.name ?? ""
        tempSubIcon = sub.icon ?? "tag.fill"
        showingSubSheet = true
    }

    private func saveSubCategory(viewModel: CategoryFormViewModel) {
        viewModel.saveSubCategory(name: tempSubName, icon: tempSubIcon)
        showingSubSheet = false
    }
}

#Preview {
    NavigationStack {
        CategoryFormView()
            .environmentObject(DependencyContainer(persistenceController: .preview))
    }
}
