//
//  OCRImportView.swift
//  OneTap
//
//  Confirmation screen for OCR-imported transactions
//

import SwiftUI

struct OCRImportView: View {
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.dismiss) private var dismiss

    let screenshot: UIImage
    @State private var viewModel: OCRImportViewModel?

    var body: some View {
        Group {
            if let viewModel {
                OCRImportContent(viewModel: viewModel, screenshot: screenshot)
            } else {
                ProgressView("Analyzing screenshot...")
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = container.makeOCRImportViewModel()

                Task {
                    await viewModel?.processScreenshot(screenshot)
                }
            }
        }
    }
}

private struct OCRImportContent: View {
    @ObservedObject var viewModel: OCRImportViewModel
    @Environment(\.dismiss) private var dismiss

    let screenshot: UIImage

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Screenshot Preview
                        screenshotPreview

                        // Confidence Badge
                        if let extracted = viewModel.extractedData {
                            confidenceBadge(extracted.confidence)
                        }

                        // Editable Fields
                        formFields
                    }
                    .padding()
                }
            }
            .navigationTitle("Confirm Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.saveTransaction()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.loadingState.isLoading)
                }
            }
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
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
                if shouldDismiss {
                    dismiss()
                }
            }
        }
    }

    private var screenshotPreview: some View {
        Image(uiImage: screenshot)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 200)
            .cornerRadius(12)
            .shadow(radius: 4)
    }

    private func confidenceBadge(_ confidence: TransactionExtractionService.ExtractedTransaction.ConfidenceLevel) -> some View {
        HStack(spacing: 8) {
            Image(systemName: confidence == .high ? "checkmark.circle.fill" : confidence == .medium ? "exclamationmark.circle.fill" : "questionmark.circle.fill")

            Text(confidence == .high ? "High Confidence" : confidence == .medium ? "Medium Confidence" : "Low Confidence - Please Review")
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(confidence == .high ? .green : confidence == .medium ? .orange : .red)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            (confidence == .high ? Color.green : confidence == .medium ? Color.orange : Color.red)
                .opacity(0.1)
        )
        .cornerRadius(20)
    }

    private var formFields: some View {
        VStack(spacing: 16) {
            // Amount
            VStack(alignment: .leading, spacing: 8) {
                Text("Amount")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.textPrimary)

                TextField("0.00", text: $viewModel.amount)
                    .keyboardType(.decimalPad)
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding()
                    .background(AppTheme.cardBackground)
                    .cornerRadius(12)
            }

            // Merchant
            VStack(alignment: .leading, spacing: 8) {
                Text("Merchant")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.textPrimary)

                TextField("Merchant name", text: $viewModel.merchant)
                    .padding()
                    .background(AppTheme.cardBackground)
                    .cornerRadius(12)
            }

            // Account Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Account")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.textPrimary)

                Picker("Account", selection: $viewModel.selectedAccount) {
                    ForEach(viewModel.accounts, id: \.objectID) { account in
                        Text(account.name ?? "Unknown")
                            .tag(account as Account?)
                    }
                }
                .pickerStyle(.menu)
                .padding()
                .background(AppTheme.cardBackground)
                .cornerRadius(12)
            }

            // Category Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.textPrimary)

                Picker("Category", selection: $viewModel.selectedCategory) {
                    ForEach(viewModel.categories, id: \.objectID) { category in
                        Text(category.name ?? "Unknown")
                            .tag(category as Category?)
                    }
                }
                .pickerStyle(.menu)
                .padding()
                .background(AppTheme.cardBackground)
                .cornerRadius(12)
            }

            // Split Items Section (if extracted from receipt)
            if viewModel.hasSplitItems {
                splitItemsSection
            }

            // Date Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Date")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.textPrimary)

                DatePicker("Date", selection: $viewModel.transactionDate, displayedComponents: [.date])
                    .datePickerStyle(.compact)
                    .padding()
                    .background(AppTheme.cardBackground)
                    .cornerRadius(12)
            }

            // Notes
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.textPrimary)

                TextEditor(text: $viewModel.note)
                    .frame(height: 100)
                    .padding(8)
                    .background(AppTheme.cardBackground)
                    .cornerRadius(12)
            }
        }
    }

    private var splitItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Line Items")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                // Total amount from line items
                if !viewModel.splitItems.isEmpty {
                    Text("Total: RM \(String(format: "%.2f", totalSplitItemAmount))")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            VStack(spacing: 8) {
                ForEach(Array(viewModel.splitItems.enumerated()), id: \.element.id) { index, item in
                    SplitItemRow(
                        item: item,
                        index: index,
                        categories: viewModel.categories,
                        onUpdate: { updatedItem in
                            viewModel.updateSplitItem(at: index, with: updatedItem)
                        },
                        onDelete: {
                            viewModel.removeSplitItem(at: index)
                        }
                    )
                }
            }

            // Add Item Button
            Button(action: {
                viewModel.addSplitItem()
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Item")
                        .font(.subheadline)
                }
                .foregroundColor(AppTheme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppTheme.cardBackground)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.accent.opacity(0.3), lineWidth: 1)
        )
    }

    private var totalSplitItemAmount: Double {
        viewModel.splitItems.reduce(0.0) { $0 + $1.amount }
    }
}

// MARK: - Split Item Row

private struct SplitItemRow: View {
    let item: SplitItemData
    let index: Int
    let categories: [Category]
    let onUpdate: (SplitItemData) -> Void
    let onDelete: () -> Void

    @State private var title: String
    @State private var amount: String
    @State private var selectedCategory: Category?

    init(
        item: SplitItemData,
        index: Int,
        categories: [Category],
        onUpdate: @escaping (SplitItemData) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.item = item
        self.index = index
        self.categories = categories
        self.onUpdate = onUpdate
        self.onDelete = onDelete

        _title = State(initialValue: item.title)
        _amount = State(initialValue: String(format: "%.2f", item.amount))
        _selectedCategory = State(initialValue: item.category)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("Item name", text: $title)
                    .font(.subheadline)
                    .onChange(of: title) { _, newValue in
                        updateItem()
                    }

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            HStack {
                TextField("0.00", text: $amount)
                    .keyboardType(.decimalPad)
                    .font(.caption)
                    .frame(maxWidth: 100)
                    .onChange(of: amount) { _, newValue in
                        updateItem()
                    }

                Picker("Category", selection: $selectedCategory) {
                    ForEach(categories, id: \.objectID) { category in
                        Text(category.name ?? "Unknown")
                            .tag(category as Category?)
                    }
                }
                .pickerStyle(.menu)
                .font(.caption)
                .onChange(of: selectedCategory) { _, newValue in
                    updateItem()
                }
            }
        }
        .padding(12)
        .background(AppTheme.background)
        .cornerRadius(8)
    }

    private func updateItem() {
        let amountValue = Double(amount) ?? 0.0
        let updatedItem = SplitItemData(
            title: title,
            amount: amountValue,
            category: selectedCategory,
            subCategory: nil
        )
        onUpdate(updatedItem)
    }
}

#Preview {
    OCRImportView(screenshot: UIImage(systemName: "photo")!)
        .environmentObject(DependencyContainer(persistenceController: .preview))
}
