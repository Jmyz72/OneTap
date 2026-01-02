//
//  TransactionMiddleBar.swift
//  OneTap
//

import SwiftUI
internal import CoreData

struct TransactionMiddleBar: View {
    @Binding var selectedCategory: Category?
    @Binding var selectedSubCategory: SubCategory?
    @Binding var selectedAccount: Account?
    @Binding var transactionDate: Date
    @Binding var merchant: String
    @Binding var splitItems: [SplitItemData]
    @Binding var note: String
    let selectedType: TransactionType
    
    // Actions
    let onSubCategoryTap: () -> Void
    let onAccountTap: () -> Void
    let onMerchantTap: () -> Void
    let onSplitTap: () -> Void
    let onNoteTap: () -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Account Chip
                Button(action: onAccountTap) {
                    chipView(
                        icon: "creditcard.fill",
                        text: selectedAccount?.name ?? "Select Account",
                        isActive: selectedAccount != nil
                    )
                }

                // Merchant Chip (Expense only)
                if selectedType == .expense {
                    Button(action: onMerchantTap) {
                        chipView(
                            icon: "mappin.and.ellipse",
                            text: merchant.isEmpty ? "Add Merchant" : merchant,
                            isActive: !merchant.isEmpty
                        )
                    }
                }

                // Split Chip (Expense only)
                if selectedType == .expense {
                    Button(action: onSplitTap) {
                        chipView(
                            icon: "basket.fill",
                            text: splitChipText,
                            isActive: !splitItems.isEmpty
                        )
                    }
                }

                // Subcategory Chip
                if let category = selectedCategory, let subs = category.subCategories, subs.count > 0 {
                    Button(action: onSubCategoryTap) {
                        chipView(
                            icon: "arrow.turn.down.right",
                            text: selectedSubCategory?.name ?? "Subcategory",
                            isActive: selectedSubCategory != nil
                        )
                    }
                }

                // Note Chip
                Button(action: onNoteTap) {
                    chipView(
                        icon: "note.text",
                        text: note.isEmpty ? "Add Note" : "Note Added",
                        isActive: !note.isEmpty
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(AppTheme.secondaryBackground.opacity(0.5))
    }
    
    private var currentTotal: Double {
        splitItems.reduce(0) { $0 + $1.amount }
    }
    
    private var splitChipText: String {
        if splitItems.isEmpty {
            return "Split"
        } else {
            let code = selectedAccount?.currency ?? SettingsManager.shared.currencyCode
            let amountStr = Formatters.currencyFormatter(for: code).string(from: NSNumber(value: currentTotal)) ?? ""
            return "\(splitItems.count) Items (\(amountStr))"
        }
    }
    
    private func chipView(icon: String, text: String, isActive: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12))
            Text(text).font(.system(size: 13, weight: .medium))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isActive ? AppTheme.accent.opacity(0.2) : AppTheme.secondaryBackground)
        .foregroundColor(isActive ? AppTheme.accent : AppTheme.textSecondary)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(isActive ? AppTheme.accent : Color.clear, lineWidth: 1))
    }
}
