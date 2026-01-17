//
//  TransactionMiddleBar.swift
//  OneTap
//

import SwiftUI
@preconcurrency internal import CoreData

struct TransactionMiddleBar: View {
    @Binding var selectedCategory: Category?
    @Binding var selectedSubCategory: SubCategory?
    @Binding var selectedAccount: Account?
    @Binding var transactionDate: Date
    @Binding var merchant: String
    @Binding var splitItems: [SplitItemData]
    @Binding var note: String
    
    @Binding var isRecurring: Bool
    @Binding var frequency: String

    // Installment State
    @Binding var isInstallment: Bool
    let showInstallmentOption: Bool
    let installmentPayments: Int16
    let formattedInstallmentPayment: String

    // Exclusion State
    @Binding var excludeFromReports: Bool

    // Claim State
    @Binding var markAsClaim: Bool

    let selectedType: TransactionType

    // Actions
    let onSubCategoryTap: () -> Void
    let onAccountTap: () -> Void
    let onMerchantTap: () -> Void
    let onSplitTap: () -> Void
    let onNoteTap: () -> Void
    let onRecurringTap: () -> Void
    let onInstallmentTap: () -> Void
    let onExclusionTap: () -> Void
    let onClaimTap: () -> Void

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
                            text: merchant.isEmpty ? "Merchant" : "Merchant: \(merchant)",
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

                // Exclude from Reports Chip
                Button(action: onExclusionTap) {
                    chipView(
                        icon: "eye.slash",
                        text: "Exclude",
                        isActive: excludeFromReports
                    )
                }
                .disabled(markAsClaim || isInstallment)

                // Claim Chip (Expense only)
                if selectedType == .expense {
                    Button(action: onClaimTap) {
                        chipView(
                            icon: "checkmark.circle.fill",
                            text: "Claim",
                            isActive: markAsClaim
                        )
                    }
                }

                // Installment Chip (Credit accounts only)
                if showInstallmentOption {
                    Button(action: onInstallmentTap) {
                        chipView(
                            icon: "creditcard.trianglebadge.exclamationmark",
                            text: isInstallment ? "\(installmentPayments)x \(formattedInstallmentPayment)" : "Installment",
                            isActive: isInstallment
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

                // Recurring Chip (Last)
                Button(action: onRecurringTap) {
                    chipView(
                        icon: "repeat",
                        text: isRecurring ? "Recurring: \(frequency)" : "Recurring",
                        isActive: isRecurring
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
