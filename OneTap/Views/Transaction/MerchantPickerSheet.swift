//
//  MerchantPickerSheet.swift
//  OneTap
//
//  Merchant picker with recent chips and search functionality
//

import SwiftUI

// Protocol for view models that support merchant picking
protocol MerchantPickerViewModel: ObservableObject {
    var merchant: String { get set }
    var recentMerchants: [String] { get }
    var merchantSuggestions: [String] { get }
    func updateMerchantSuggestions()
    func fetchAllMerchants() -> [String]
}

struct MerchantPickerSheet<ViewModel: MerchantPickerViewModel>: View {
    @ObservedObject var viewModel: ViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var allMerchants: [String] = []

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Recent Merchants Chips (shown when not searching)
                    if searchText.isEmpty && !viewModel.recentMerchants.isEmpty {
                        recentMerchantsSection
                    }

                    // Search Results / All Merchants List
                    merchantListSection
                }
            }
            .navigationTitle("Merchant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .searchable(text: $searchText, prompt: "Search or add merchant")
            .onChange(of: searchText) { _, newValue in
                // Temporarily set merchant to trigger updateMerchantSuggestions
                let originalMerchant = viewModel.merchant
                viewModel.merchant = newValue
                viewModel.updateMerchantSuggestions()
                viewModel.merchant = originalMerchant
            }
            .onAppear {
                // Load all merchants for browsing
                allMerchants = viewModel.fetchAllMerchants()
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }

    // MARK: - Recent Merchants Section

    private var recentMerchantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.recentMerchants, id: \.self) { merchant in
                        MerchantChip(merchant: merchant) {
                            viewModel.merchant = merchant
                            dismiss()
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Merchant List Section

    private var merchantListSection: some View {
        Group {
            if searchText.isEmpty {
                // Show all merchants when not searching
                ScrollView {
                    VStack(spacing: 0) {
                        if allMerchants.isEmpty {
                            emptyStateView
                        } else {
                            ForEach(allMerchants, id: \.self) { merchant in
                                merchantRow(merchant)
                            }
                        }
                    }
                }
            } else {
                // Show search results
                ScrollView {
                    VStack(spacing: 0) {
                        if viewModel.merchantSuggestions.isEmpty {
                            // Allow adding new merchant
                            addNewMerchantRow
                        } else {
                            ForEach(viewModel.merchantSuggestions, id: \.self) { merchant in
                                merchantRow(merchant)
                            }

                            // Also show option to add the exact search text
                            if !viewModel.merchantSuggestions.contains(searchText) {
                                Divider()
                                    .padding(.leading, 20)
                                addNewMerchantRow
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Merchant Row

    private func merchantRow(_ merchant: String) -> some View {
        Button {
            viewModel.merchant = merchant
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.accent)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.accent.opacity(0.15))
                    .cornerRadius(8)

                Text(merchant)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(AppTheme.background)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add New Merchant Row

    private var addNewMerchantRow: some View {
        Button {
            viewModel.merchant = searchText
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.income)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.income.opacity(0.15))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Add \"\(searchText)\"")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)

                    Text("Add as new merchant")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(AppTheme.background)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "building.2")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.textTertiary)

            Text("No merchants yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)

            Text("Merchants you add will appear here")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Merchant Chip Component

private struct MerchantChip: View {
    let merchant: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.accent)

                Text(merchant)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(AppTheme.cardBackground)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(AppTheme.accent.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @StateObject private var container = DependencyContainer(persistenceController: .preview)
        @State private var viewModel: AddTransactionViewModel?

        var body: some View {
            Group {
                if let viewModel {
                    MerchantPickerSheet(viewModel: viewModel)
                } else {
                    ProgressView()
                        .onAppear {
                            viewModel = container.makeAddTransactionViewModel()
                        }
                }
            }
        }
    }

    return PreviewWrapper()
}
