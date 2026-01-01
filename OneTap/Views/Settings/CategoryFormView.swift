//
//  CategoryFormView.swift
//  OneTap
//
//  REFACTORED: Now uses CategoryFormViewModel (MVVM pattern)
//

import SwiftUI
import CoreData

struct CategoryFormView: View {
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel: CategoryFormViewModel

    // Sheet State for Subcategory (view-only UI state)
    @State private var showingSubSheet = false
    @State private var tempSubName = ""
    @State private var tempSubIcon = "tag.fill"

    init(categoryToEdit: Category? = nil) {
        // Create temporary container and ViewModel
        let tempContainer = DependencyContainer()
        _viewModel = StateObject(wrappedValue: tempContainer.makeCategoryFormViewModel(category: categoryToEdit))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Category Name", text: $viewModel.name)

                    Picker("Type", selection: $viewModel.type) {
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
                                .foregroundColor(viewModel.selectedIcon == iconName ? Color(hex: viewModel.selectedColorHex) : .gray)
                                .background(viewModel.selectedIcon == iconName ? Color(hex: viewModel.selectedColorHex).opacity(0.15) : Color.clear)
                                .cornerRadius(8)
                                .onTapGesture {
                                    viewModel.selectedIcon = iconName
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
                                        .stroke(Color.white, lineWidth: viewModel.selectedColorHex == colorHex ? 3 : 0)
                                )
                                .onTapGesture {
                                    viewModel.selectedColorHex = colorHex
                                }
                                .frame(width: 44, height: 44)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Subcategories") {
                    ForEach(viewModel.subCategories) { sub in
                        Button {
                            startEditingSub(sub)
                        } label: {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: viewModel.selectedColorHex).opacity(0.1))
                                        .frame(width: 32, height: 32)

                                    Image(systemName: sub.icon ?? "tag.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(hex: viewModel.selectedColorHex))
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
                                viewModel.deleteSubCategory(sub)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }

                    Button {
                        startAddingSub()
                    } label: {
                        Label("Add Subcategory", systemImage: "plus.circle.fill")
                            .foregroundColor(AppTheme.accent)
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
                    onSave: saveSubCategory,
                    onDelete: viewModel.editingSubCategory != nil ? {
                        if let sub = viewModel.editingSubCategory {
                            viewModel.deleteSubCategory(sub)
                            showingSubSheet = false
                        }
                    } : nil
                )
            }
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
        }
    }

    // MARK: - Subcategory Helpers

    private func startAddingSub() {
        viewModel.editingSubCategory = nil
        tempSubName = ""
        tempSubIcon = "tag.fill"
        showingSubSheet = true
    }

    private func startEditingSub(_ sub: SubCategory) {
        viewModel.editingSubCategory = sub
        tempSubName = sub.name ?? ""
        tempSubIcon = sub.icon ?? "tag.fill"
        showingSubSheet = true
    }

    private func saveSubCategory() {
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
