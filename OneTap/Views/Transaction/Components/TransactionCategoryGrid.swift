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
    
    var body: some View {
        ScrollView {
            // Filter locally
            let filteredCategories = categories.filter { $0.typeEnum == selectedType }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                ForEach(filteredCategories, id: \.self) { category in
                    CategoryGridItem(category: category, isSelected: selectedCategory?.id == category.id)
                        .onTapGesture {
                            selectedCategory = category
                        }
                }
            }
            .padding()
        }
    }
}

private struct CategoryGridItem: View {
    let category: Category
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isSelected ? category.colorView : category.colorView.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: category.iconName)
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? .white : category.colorView)
            }
            
            Text(category.name ?? "")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
                .lineLimit(1)
        }
    }
}
