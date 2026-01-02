//
//  TransactionCategoryGrid.swift
//  OneTap
//

import SwiftUI
internal import CoreData

struct TransactionCategoryGrid: View {
    let categories: [Category]
    let selectedType: TransactionType
    @Binding var selectedCategory: Category?
    var onCategoryTapped: ((Category) -> Void)? = nil

    var body: some View {
        ScrollView {
            // Filter locally
            let filteredCategories = categories.filter { $0.typeEnum == selectedType }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                ForEach(filteredCategories, id: \.self) { category in
                    CategoryGridItem(category: category, isSelected: selectedCategory?.id == category.id)
                        .onTapGesture {
                            // Haptic feedback
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            selectedCategory = category
                            // Notify parent about tap (fires even if already selected)
                            onCategoryTapped?(category)
                        }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}

private struct CategoryGridItem: View {
    let category: Category
    let isSelected: Bool
    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Background circle with gradient
                Circle()
                    .fill(
                        isSelected ?
                        LinearGradient(
                            colors: [
                                category.colorView,
                                category.colorView.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [
                                category.colorView.opacity(0.15),
                                category.colorView.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(
                                isSelected ?
                                category.colorView.opacity(0.5) :
                                category.colorView.opacity(0.2),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .shadow(
                        color: isSelected ? category.colorView.opacity(0.4) : Color.black.opacity(0.2),
                        radius: isSelected ? 10 : 5,
                        x: 0,
                        y: isSelected ? 5 : 2
                    )

                Image(systemName: category.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        isSelected ?
                        LinearGradient(
                            colors: [Color.white, Color.white.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [category.colorView, category.colorView.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(
                        color: isSelected ? Color.black.opacity(0.3) : Color.clear,
                        radius: 2,
                        x: 0,
                        y: 1
                    )
            }
            .scaleEffect(isSelected ? 1.08 : (isPressed ? 0.9 : 1.0))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)

            Text(category.name ?? "")
                .font(.system(size: 9, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}
