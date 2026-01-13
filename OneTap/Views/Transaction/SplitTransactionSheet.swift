//
//  SplitTransactionSheet.swift
//  OneTap
//
//  Created by Jimmy Hew on 31/12/2025.
//

import SwiftUI
@preconcurrency internal import CoreData

struct SplitTransactionSheet: View {
    @Binding var items: [SplitItemData]
    var currencyCode: String
    var categories: [Category]

    @Environment(\.dismiss) private var dismiss
    @State private var editingItemIndex: Int?
    @State private var showingItemEdit = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Status
                VStack(spacing: 8) {
                    HStack {
                        Text("Total Amount")
                            .foregroundColor(AppTheme.textSecondary)
                        Spacer()
                        Text(format(currentTotal))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    .padding()
                }
                .background(AppTheme.secondaryBackground)
                
                if items.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "basket")
                            .font(.system(size: 50))
                            .foregroundColor(AppTheme.textTertiary)
                        Text("No items added yet")
                            .foregroundColor(AppTheme.textSecondary)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            Button(action: {
                                editingItemIndex = index
                                showingItemEdit = true
                            }) {
                                HStack {
                                    Image(systemName: item.category?.iconName ?? "tag")
                                        .foregroundColor(item.category?.colorView ?? .gray)

                                    VStack(alignment: .leading) {
                                        Text(item.title.isEmpty ? (item.category?.name ?? "Item") : item.title)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(AppTheme.textPrimary)

                                        HStack(spacing: 4) {
                                            if let catName = item.category?.name {
                                                Text(catName)
                                                    .font(.caption)
                                                    .foregroundColor(AppTheme.textSecondary)

                                                if let subCatName = item.subCategory?.name {
                                                    Text("•")
                                                        .font(.caption)
                                                        .foregroundColor(AppTheme.textSecondary)
                                                    Text(subCatName)
                                                        .font(.caption)
                                                        .foregroundColor(AppTheme.textSecondary)
                                                }
                                            }
                                        }
                                    }

                                    Spacer()

                                    Text(format(item.amount))
                                        .foregroundColor(AppTheme.textPrimary)

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.textTertiary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteItem)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(AppTheme.background)
            .navigationTitle("Current Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingItemEdit) {
                if let index = editingItemIndex {
                    SplitItemEditView(
                        item: $items[index],
                        categories: categories
                    )
                }
            }
        }
    }
    
    private var currentTotal: Double {
        items.reduce(0) { $0 + $1.amount }
    }
    
    private func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSNumber(value: value)) ?? ""
    }
    
    private func deleteItem(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }
}