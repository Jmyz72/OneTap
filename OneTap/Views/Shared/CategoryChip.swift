//
//  CategoryChip.swift
//  OneTap
//
//  Created by Jimmy Hew on 30/12/2025.
//

import SwiftUI

struct CategoryChip: View {
    let category: Category
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? category.colorView : category.colorView.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: category.iconName)
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? .white : category.colorView)
                }
                
                Text(category.name ?? "")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
            }
            .frame(width: 80)
            .padding(.vertical, 12)
            .background(isSelected ? AppTheme.tertiaryBackground : Color.clear)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? category.colorView.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
    }
}
