//
//  SubCategoryPickerSheet.swift
//  OneTap
//
//  Bottom sheet for selecting transaction subcategories
//

import SwiftUI
internal import CoreData

struct SubCategoryPickerSheet: View {
    let category: Category
    @Binding var selectedSubCategory: SubCategory?
    @Environment(\.dismiss) private var dismiss

    private var subcategories: [SubCategory] {
        (category.subCategories?.allObjects as? [SubCategory])?.sorted { $0.order < $1.order } ?? []
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                categoryHeader

                // Subcategories Grid
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                        // Skip option
                        skipButton

                        // Subcategory options
                        ForEach(subcategories, id: \.objectID) { subcategory in
                            subcategoryButton(subcategory)
                        }
                    }
                    .padding()
                }
            }
            .background(AppTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Select Subcategory")
                        .font(.headline)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Subviews

    private var categoryHeader: some View {
        HStack(spacing: 12) {
            // Category icon
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
                    .frame(width: 50, height: 50)

                Image(systemName: category.iconName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [category.colorView, category.colorView.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(category.name ?? "Category")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)

                Text("\(subcategories.count) subcategories")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()
        }
        .padding()
        .background(AppTheme.secondaryBackground)
    }

    private var skipButton: some View {
        Button(action: {
            selectedSubCategory = nil
            dismiss()
        }) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.secondaryBackground)
                        .frame(width: 70, height: 70)
                        .overlay(
                            Circle()
                                .stroke(
                                    selectedSubCategory == nil ? category.colorView : AppTheme.textTertiary.opacity(0.3),
                                    lineWidth: selectedSubCategory == nil ? 2 : 1
                                )
                        )

                    Image(systemName: "xmark")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(selectedSubCategory == nil ? category.colorView : AppTheme.textTertiary)
                }

                Text("None")
                    .font(.system(size: 13, weight: selectedSubCategory == nil ? .semibold : .medium))
                    .foregroundColor(selectedSubCategory == nil ? category.colorView : AppTheme.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(.plain)
    }

    private func subcategoryButton(_ subcategory: SubCategory) -> some View {
        Button(action: {
            selectedSubCategory = subcategory
            dismiss()
        }) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            selectedSubCategory?.id == subcategory.id
                                ? LinearGradient(
                                    colors: [category.colorView, category.colorView.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [
                                        category.colorView.opacity(0.1),
                                        category.colorView.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .frame(width: 70, height: 70)
                        .overlay(
                            Circle()
                                .stroke(
                                    selectedSubCategory?.id == subcategory.id
                                        ? category.colorView.opacity(0.5)
                                        : category.colorView.opacity(0.2),
                                    lineWidth: selectedSubCategory?.id == subcategory.id ? 2 : 1
                                )
                        )
                        .shadow(
                            color: selectedSubCategory?.id == subcategory.id
                                ? category.colorView.opacity(0.3)
                                : Color.clear,
                            radius: 8,
                            x: 0,
                            y: 4
                        )

                    Image(systemName: subcategory.displayIcon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(
                            selectedSubCategory?.id == subcategory.id
                                ? LinearGradient(
                                    colors: [Color.white, Color.white.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [category.colorView, category.colorView.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                }

                Text(subcategory.name ?? "")
                    .font(.system(size: 13, weight: selectedSubCategory?.id == subcategory.id ? .semibold : .medium))
                    .foregroundColor(
                        selectedSubCategory?.id == subcategory.id
                            ? category.colorView
                            : AppTheme.textSecondary
                    )
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let category = Category(context: context)
    category.name = "Food & Drinks"
    category.icon = "fork.knife"
    category.color = "#FF9500"

    let sub1 = SubCategory(context: context)
    sub1.name = "Groceries"
    sub1.icon = "cart.fill"
    sub1.order = 0
    sub1.category = category

    let sub2 = SubCategory(context: context)
    sub2.name = "Restaurants"
    sub2.icon = "fork.knife"
    sub2.order = 1
    sub2.category = category

    return SubCategoryPickerSheet(category: category, selectedSubCategory: .constant(nil))
}
