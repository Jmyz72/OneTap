//
//  SplitItemEditView.swift
//  OneTap
//
//  View for editing individual split transaction items
//

import SwiftUI
@preconcurrency internal import CoreData

struct SplitItemEditView: View {
    @Binding var item: SplitItemData
    let categories: [Category]

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var amount: String
    @State private var selectedCategory: Category?
    @State private var selectedSubCategory: SubCategory?
    @State private var showingSubCategoryPicker = false

    init(item: Binding<SplitItemData>, categories: [Category]) {
        self._item = item
        self.categories = categories

        // Initialize state from item
        _title = State(initialValue: item.wrappedValue.title)
        _amount = State(initialValue: String(format: "%.2f", item.wrappedValue.amount))
        _selectedCategory = State(initialValue: item.wrappedValue.category)
        _selectedSubCategory = State(initialValue: item.wrappedValue.subCategory)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item Details") {
                    TextField("Title", text: $title)

                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            HStack {
                                Image(systemName: category.iconName)
                                    .foregroundColor(category.colorView)
                                Text(category.name ?? "Unknown")
                            }
                            .tag(category as Category?)
                        }
                    }

                    if let category = selectedCategory,
                       let subcategories = category.subCategories?.allObjects as? [SubCategory],
                       !subcategories.isEmpty {
                        Button(action: {
                            showingSubCategoryPicker = true
                        }) {
                            HStack {
                                Text("Subcategory")
                                    .foregroundColor(AppTheme.textPrimary)
                                Spacer()
                                if let subCat = selectedSubCategory {
                                    Text(subCat.name ?? "None")
                                        .foregroundColor(AppTheme.textSecondary)
                                } else {
                                    Text("None")
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textTertiary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(!isValid)
                }
            }
            .confirmationDialog("Select Subcategory", isPresented: $showingSubCategoryPicker, titleVisibility: .visible) {
                subcategoryButtons
            }
            .onChange(of: selectedCategory) { _, newCategory in
                // Reset subcategory if category changed
                if newCategory?.id != item.category?.id {
                    selectedSubCategory = nil
                }
            }
        }
    }

    @ViewBuilder
    private var subcategoryButtons: some View {
        if let category = selectedCategory,
           let subs = category.subCategories?.allObjects as? [SubCategory] {
            ForEach(subs.sorted { $0.order < $1.order }) { sub in
                Button(sub.name ?? "Unnamed") {
                    selectedSubCategory = sub
                }
            }
            Button("None") {
                selectedSubCategory = nil
            }
        }
    }

    private var isValid: Bool {
        guard let amountValue = Double(amount), amountValue > 0 else {
            return false
        }
        return selectedCategory != nil && !title.isEmpty
    }

    private func saveChanges() {
        guard let amountValue = Double(amount), amountValue > 0, let category = selectedCategory else {
            return
        }

        // Update the bound item properties
        item.title = title
        item.amount = amountValue
        item.category = category
        item.subCategory = selectedSubCategory

        dismiss()
    }
}
