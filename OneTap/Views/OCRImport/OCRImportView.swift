//
//  OCRImportView.swift
//  OneTap
//
//  Confirmation screen for OCR-imported transactions
//  Styled as an editable receipt
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
                ZStack {
                    AppTheme.background.ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Analyzing receipt...")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
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
    @State private var showScreenshot = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Expandable Screenshot Preview
                        screenshotSection

                        // Receipt Card
                        receiptCard

                        // Account Selection (outside receipt)
                        accountSection

                        // Notes Section
                        notesSection
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
                    .foregroundColor(AppTheme.textSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await viewModel.saveTransaction()
                        }
                    } label: {
                        Text("Save")
                            .fontWeight(.semibold)
                    }
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

    // MARK: - Screenshot Section

    private var screenshotSection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showScreenshot.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "doc.viewfinder")
                        .font(.subheadline)
                    Text("Original Screenshot")
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: showScreenshot ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(AppTheme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppTheme.cardBackground)
                .cornerRadius(showScreenshot ? 12 : 12)
            }
            .buttonStyle(.plain)

            if showScreenshot {
                Image(uiImage: screenshot)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .cornerRadius(8)
                    .padding(12)
                    .background(AppTheme.cardBackground)
                    .cornerRadius(12)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }

    // MARK: - Receipt Card

    private var receiptCard: some View {
        VStack(spacing: 0) {
            // Receipt Header with zigzag edge
            receiptHeader

            // Receipt Body
            VStack(spacing: 16) {
                // Merchant Name (Editable)
                merchantSection

                receiptDivider

                // Date & Time
                dateSection

                receiptDivider

                // Line Items
                lineItemsSection

                // Adjustments (only show if exists)
                if viewModel.hasAdjustments {
                    receiptDivider
                    adjustmentsSection
                }

                receiptDivider

                // Total
                totalSection

                // Confidence indicator
                if let extracted = viewModel.extractedData {
                    confidenceIndicator(extracted.confidence)
                }
            }
            .padding(20)
            .background(Color.white)

            // Receipt Footer with zigzag edge
            receiptFooter
        }
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    private var receiptHeader: some View {
        ZigzagEdge(isTop: true)
            .fill(Color.white)
            .frame(height: 12)
    }

    private var receiptFooter: some View {
        ZigzagEdge(isTop: false)
            .fill(Color.white)
            .frame(height: 12)
    }

    private var receiptDivider: some View {
        HStack(spacing: 4) {
            ForEach(0..<30, id: \.self) { _ in
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 3, height: 3)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Merchant Section

    private var merchantSection: some View {
        VStack(spacing: 8) {
            Text("MERCHANT")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.gray)
                .tracking(1.5)

            TextField("Enter merchant name", text: $viewModel.merchant)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
        }
    }

    // MARK: - Date Section

    private var dateSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("DATE")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                    .tracking(1)

                DatePicker("", selection: $viewModel.transactionDate, displayedComponents: [.date])
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(.black)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("TIME")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                    .tracking(1)

                DatePicker("", selection: $viewModel.transactionDate, displayedComponents: [.hourAndMinute])
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(.black)
            }
        }
    }

    // MARK: - Line Items Section

    private var lineItemsSection: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("ITEMS")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                    .tracking(1)

                Spacer()

                Text("AMOUNT")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                    .tracking(1)
            }

            if viewModel.hasSplitItems {
                // Show line items
                ForEach(Array(viewModel.splitItems.enumerated()), id: \.element.id) { index, item in
                    ReceiptLineItemRow(
                        item: item,
                        categories: viewModel.categories,
                        onUpdate: { updatedItem in
                            viewModel.updateSplitItem(at: index, with: updatedItem)
                        },
                        onDelete: {
                            viewModel.removeSplitItem(at: index)
                        }
                    )
                }

                // Add item button
                Button {
                    viewModel.addSplitItem()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                            .font(.subheadline)
                        Text("Add Item")
                            .font(.subheadline)
                    }
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            } else {
                // Single item mode - show as one line item
                singleItemRow
            }
        }
    }

    private var singleItemRow: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    // Editable item title (not merchant - that's shown separately)
                    TextField("Item name", text: $viewModel.title)
                        .font(.subheadline)
                        .foregroundColor(.black)
                        .textFieldStyle(.plain)

                    // Category chip
                    if let category = viewModel.selectedCategory {
                        ReceiptCategoryChip(category: category, categories: viewModel.categories) { newCategory in
                            viewModel.selectedCategory = newCategory
                        }
                    }
                }

                Spacer()

                // Amount field
                HStack(spacing: 2) {
                    Text("RM")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    TextField("0.00", text: $viewModel.amount)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .textFieldStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Adjustments Section

    private var adjustmentsSection: some View {
        VStack(spacing: 8) {
            ForEach(viewModel.adjustments) { adjustment in
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: adjustment.type.icon)
                            .font(.caption)
                            .foregroundColor(.gray)

                        Text(adjustment.label ?? adjustment.type.displayName)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Text(formattedAdjustmentAmount(adjustment))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(adjustment.type.isNegative ? .green : .gray)
                }
            }
        }
    }

    private func formattedAdjustmentAmount(_ adjustment: AdjustmentData) -> String {
        let prefix = adjustment.type.isNegative ? "-" : ""
        return "\(prefix)RM \(String(format: "%.2f", adjustment.amount))"
    }

    // MARK: - Total Section

    private var totalSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("TOTAL")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.black)

                Spacer()

                HStack(spacing: 4) {
                    Text("RM")
                        .font(.headline)
                        .foregroundColor(.black)

                    if viewModel.hasSplitItems {
                        Text(String(format: "%.2f", totalAmount))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                    } else {
                        TextField("0.00", text: $viewModel.amount)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .textFieldStyle(.plain)
                    }
                }
            }

            // Show item count if multiple items
            if viewModel.hasSplitItems {
                Text("\(viewModel.splitItems.count) items")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }

    private var totalAmount: Double {
        if viewModel.hasSplitItems {
            return viewModel.splitItems.reduce(0) { $0 + $1.amount }
        } else {
            return Double(viewModel.amount) ?? 0
        }
    }

    private func confidenceIndicator(_ confidence: TransactionExtractionService.ExtractedTransaction.ConfidenceLevel) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(confidence == .high ? Color.green : confidence == .medium ? Color.orange : Color.red)
                .frame(width: 6, height: 6)

            Text(confidence == .high ? "High confidence" : confidence == .medium ? "Review suggested" : "Please verify")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(.top, 8)
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pay From")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.textPrimary)

            Menu {
                ForEach(viewModel.accounts, id: \.objectID) { account in
                    Button {
                        viewModel.selectedAccount = account
                    } label: {
                        HStack {
                            Text(account.name ?? "Unknown")
                            if viewModel.selectedAccount == account {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    if let account = viewModel.selectedAccount {
                        Image(systemName: account.icon ?? account.typeEnum.icon)
                            .font(.title3)
                            .foregroundColor(AppTheme.accent)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.name ?? "Unknown")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AppTheme.textPrimary)

                            Text("Balance: \(account.formattedBalance)")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    } else {
                        Text("Select Account")
                            .foregroundColor(AppTheme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .padding()
                .background(AppTheme.cardBackground)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes (Optional)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.textPrimary)

            TextField("Add a note...", text: $viewModel.note, axis: .vertical)
                .lineLimit(3...6)
                .padding()
                .background(AppTheme.cardBackground)
                .cornerRadius(12)
        }
    }
}

// MARK: - Receipt Line Item Row

private struct ReceiptLineItemRow: View {
    let item: SplitItemData
    let categories: [Category]
    let onUpdate: (SplitItemData) -> Void
    let onDelete: () -> Void

    @State private var title: String
    @State private var amount: String
    @State private var selectedCategory: Category?

    init(
        item: SplitItemData,
        categories: [Category],
        onUpdate: @escaping (SplitItemData) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.item = item
        self.categories = categories
        self.onUpdate = onUpdate
        self.onDelete = onDelete

        _title = State(initialValue: item.title)
        _amount = State(initialValue: String(format: "%.2f", item.amount))
        _selectedCategory = State(initialValue: item.category)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Item details
            VStack(alignment: .leading, spacing: 4) {
                TextField("Item name", text: $title)
                    .font(.subheadline)
                    .foregroundColor(.black)
                    .textFieldStyle(.plain)
                    .onChange(of: title) { _, _ in updateItem() }

                // Category chip
                ReceiptCategoryChip(category: selectedCategory, categories: categories) { newCategory in
                    selectedCategory = newCategory
                    updateItem()
                }
            }

            Spacer()

            // Amount and delete
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 2) {
                    Text("RM")
                        .font(.caption)
                        .foregroundColor(.gray)
                    TextField("0.00", text: $amount)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.black)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        .textFieldStyle(.plain)
                        .onChange(of: amount) { _, _ in updateItem() }
                }

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
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

// MARK: - Receipt Category Chip (Local - for receipt-style picker)

private struct ReceiptCategoryChip: View {
    let category: Category?
    let categories: [Category]
    let onSelect: (Category?) -> Void

    var body: some View {
        Menu {
            ForEach(categories, id: \.objectID) { cat in
                Button {
                    onSelect(cat)
                } label: {
                    HStack {
                        Image(systemName: cat.iconName)
                        Text(cat.name ?? "Unknown")
                        if category == cat {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                if let category = category {
                    Image(systemName: category.iconName)
                        .font(.caption2)
                    Text(category.name ?? "Category")
                        .font(.caption2)
                } else {
                    Image(systemName: "tag")
                        .font(.caption2)
                    Text("Select")
                        .font(.caption2)
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
            }
            .foregroundColor(.gray)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Zigzag Edge Shape

private struct ZigzagEdge: Shape {
    let isTop: Bool
    let zigzagWidth: CGFloat = 10
    let zigzagHeight: CGFloat = 6

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let numberOfZigzags = Int(rect.width / zigzagWidth)
        let actualZigzagWidth = rect.width / CGFloat(numberOfZigzags)

        if isTop {
            path.move(to: CGPoint(x: 0, y: rect.maxY))

            for i in 0..<numberOfZigzags {
                let x = CGFloat(i) * actualZigzagWidth
                let midX = x + actualZigzagWidth / 2
                let nextX = x + actualZigzagWidth

                path.addLine(to: CGPoint(x: midX, y: rect.minY))
                path.addLine(to: CGPoint(x: nextX, y: rect.maxY))
            }

            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: 0, y: rect.maxY))
        } else {
            path.move(to: CGPoint(x: 0, y: rect.minY))

            for i in 0..<numberOfZigzags {
                let x = CGFloat(i) * actualZigzagWidth
                let midX = x + actualZigzagWidth / 2
                let nextX = x + actualZigzagWidth

                path.addLine(to: CGPoint(x: midX, y: rect.maxY))
                path.addLine(to: CGPoint(x: nextX, y: rect.minY))
            }

            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: 0, y: rect.minY))
        }

        return path
    }
}

#Preview {
    OCRImportView(screenshot: UIImage(systemName: "photo")!)
        .environmentObject(DependencyContainer(persistenceController: .preview))
}
