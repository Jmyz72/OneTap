//
//  TransactionDetailView.swift
//  OneTap
//
//  REFACTORED: Dark themed receipt design
//

import SwiftUI
@preconcurrency internal import CoreData

struct TransactionDetailView: View {
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var transaction: Transaction
    @State private var viewModel: TransactionDetailViewModel?

    // UI State
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        Group {
            if let viewModel {
                ZStack {
                    // Dark Background
                    Color.black
                        .ignoresSafeArea()

                    ScrollView {
                        VStack(spacing: 0) {
                            // Receipt Paper
                            VStack(spacing: 0) {
                                // Top tear edge
                                receiptTearEdge()

                                VStack(spacing: 0) {
                                    // Header
                                    receiptHeader()

                                    dottedLine()

                                    // Transaction Info
                                    transactionInfo()

                                    dottedLine()

                                    // Items Section
                                    itemsSection()

                                    dottedLine()

                                    // Total Section
                                    totalSection()

                                    dottedLine()

                                    // Footer
                                    receiptFooter()
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 20)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "1A1A1A"), Color(hex: "151515")],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )

                                // Bottom tear edge
                                receiptTearEdge()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 30)
                            .shadow(color: Color.white.opacity(0.05), radius: 20, x: 0, y: 8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                            )
                        }
                        .padding(.bottom, 40)
                    }
                }
                .navigationTitle("Receipt")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button {
                                showingEditSheet = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }

                            Divider()

                            Button(role: .destructive) {
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(AppTheme.accent)
                        }
                    }
                }
                .sheet(isPresented: $showingEditSheet) {
                    EditTransactionView(transaction: transaction)
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
                .alert("Delete Transaction", isPresented: $showingDeleteConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete", role: .destructive) {
                        Task {
                            await viewModel.deleteTransaction()
                        }
                    }
                } message: {
                    Text("Are you sure you want to delete this transaction? This cannot be undone.")
                }
                .overlay {
                    if viewModel.loadingState.isLoading {
                        ZStack {
                            Color.black.opacity(0.6)
                                .ignoresSafeArea()
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                        }
                    }
                }
                .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
                    if shouldDismiss {
                        dismiss()
                    }
                }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = container.makeTransactionDetailViewModel(transaction: transaction)
            }
        }
    }

    // MARK: - Receipt Components

    private func receiptTearEdge() -> some View {
        HStack(spacing: 0) {
            ForEach(0..<30, id: \.self) { _ in
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 12, height: 12)
                }
            }
        }
        .frame(height: 6)
        .background(
            LinearGradient(
                colors: [Color(hex: "1A1A1A"), Color(hex: "151515")],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    private func receiptHeader() -> some View {
        VStack(spacing: 8) {
            // Title (prioritize title over merchant for clarity)
            if let title = transaction.title, !title.isEmpty {
                Text(title.uppercased())
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
            }

            // Merchant (show if different from title or if title is empty)
            if let merchant = transaction.merchant, !merchant.isEmpty,
               merchant != transaction.title {
                Text(merchant.uppercased())
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.gray)
                    .padding(.top, 2)
            }

            // Account Name
            if let accountName = transaction.account?.name {
                Text(accountName.uppercased())
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.8))
                    .padding(.top, 4)
            }

            // Scanned Receipt Badge
            if isFromOCR {
                HStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text("SCANNED RECEIPT")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(0.5)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(AppTheme.scanned)
                )
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 12)
    }

    private func transactionInfo() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            receiptRow(label: "DATE", value: Formatters.dateOnly.string(from: transaction.date ?? Date()))
            receiptRow(label: "TIME", value: Formatters.timeOnly.string(from: transaction.date ?? Date()))

            if let id = transaction.id?.uuidString.prefix(8) {
                receiptRow(label: "TRANS #", value: String(id).uppercased())
            }

            receiptRow(label: "TYPE", value: transaction.typeEnum.rawValue.uppercased())
        }
        .padding(.vertical, 12)
    }

    private func itemsSection() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !transaction.itemsArray.isEmpty {
                // Split transaction items
                VStack(alignment: .leading, spacing: 8) {
                    Text("ITEMS")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                        .padding(.bottom, 6)

                    ForEach(transaction.itemsArray, id: \.objectID) { item in
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title ?? "Item")
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(.white)

                                // Show subcategory if exists, otherwise show main category
                                if let subCategory = item.subCategory?.name {
                                    Text(subCategory)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.gray)
                                } else if let category = item.category?.name {
                                    Text(category)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.gray)
                                }
                            }

                            Spacer()

                            Text(item.formattedAmount)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.vertical, 12)
            } else {
                // Single item transaction
                VStack(alignment: .leading, spacing: 8) {
                    Text("DESCRIPTION")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                        .padding(.bottom, 6)

                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            // Show category name
                            Text(transaction.category?.name ?? "Uncategorized")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(.white)

                            // Show subcategory if available
                            if let subCategory = transaction.subCategory?.name {
                                Text(subCategory)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.gray)
                            }
                        }

                        Spacer()

                        Text(transaction.formattedAmount)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
                .padding(.vertical, 12)
            }

            // Notes if present
            if let notes = transaction.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NOTES")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    Text(notes)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 12)
            }

            // Adjustment Reason if present
            if let adjustmentReason = transaction.adjustmentReason, !adjustmentReason.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ADJUSTMENT REASON")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    Text(adjustmentReason)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 12)
            }
        }
    }

    private func totalSection() -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("TOTAL")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                Spacer()

                Text(transaction.formattedAmount)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(amountColor)
            }

            HStack {
                Text("BALANCE AFTER")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)

                Spacer()

                Text(transaction.formattedBalanceAfter)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.vertical, 12)
    }

    private func receiptFooter() -> some View {
        VStack(spacing: 8) {
            // All badges centered together
            HStack(spacing: 12) {
                // Type badge
                TransactionTypeBadge(type: transaction.typeEnum)

                if transaction.recurringTransaction != nil {
                    receiptBadge(icon: "repeat", text: "RECURRING", color: AppTheme.recurring)
                }

                if transaction.isPartOfInstallment, let label = transaction.installmentLabel {
                    receiptBadge(icon: "creditcard.fill", text: label.uppercased(), color: AppTheme.installment)
                }

                if transaction.hasPendingClaim {
                    receiptBadge(icon: "checkmark.circle.fill", text: "CLAIM PENDING", color: AppTheme.claimPending)
                }

                if transaction.hasSettledClaim {
                    receiptBadge(icon: "checkmark.circle.fill", text: "CLAIM SETTLED", color: AppTheme.claimSettled)
                }

                if transaction.excludeFromReports {
                    receiptBadge(icon: "eye.slash", text: "EXCLUDED", color: AppTheme.excluded)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)

            if transaction.recurringTransaction != nil || transaction.isPartOfInstallment || transaction.excludeFromReports || transaction.hasPendingClaim || transaction.hasSettledClaim {
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.vertical, 4)
            }

            // Timestamps
            VStack(spacing: 3) {
                if let created = transaction.createdAt {
                    Text("CREATED: \(Formatters.dateTime.string(from: created).uppercased())")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.gray)
                }

                if let updated = transaction.updatedAt,
                   let created = transaction.createdAt,
                   updated.timeIntervalSince(created) > 60 {
                    Text("MODIFIED: \(Formatters.dateTime.string(from: updated).uppercased())")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }

            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.vertical, 8)

            // Thank you message
            Text("THANK YOU")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundColor(.white)

            Text("OneTap Finance")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.gray)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Helper Views

    private func receiptRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.gray)

            Spacer()

            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
        }
    }

    private func dottedLine() -> some View {
        GeometryReader { geometry in
            Path { path in
                let dashLength: CGFloat = 4
                let gapLength: CGFloat = 3
                var x: CGFloat = 0

                while x < geometry.size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: min(x + dashLength, geometry.size.width), y: 0))
                    x += dashLength + gapLength
                }
            }
            .stroke(Color.white.opacity(0.2), lineWidth: 1)
        }
        .frame(height: 1)
    }

    private func receiptBadge(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text(text)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.8))
        .cornerRadius(4)
    }

    private var amountColor: Color {
        switch transaction.typeEnum {
        case .expense: return Color(hex: "FF6B6B")  // Soft red
        case .income: return Color(hex: "51CF66")   // Soft green
        case .transfer: return Color(hex: "4DABF7") // Soft blue
        case .adjustment: return Color(hex: "FFD43B") // Soft yellow
        }
    }

    private var isFromOCR: Bool {
        // Use KVC to check isFromOCR until Core Data entity is updated
        (transaction.value(forKey: "isFromOCR") as? Bool) ?? false
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let fetchRequest: NSFetchRequest<Transaction> = Transaction.fetchRequest()
    let transaction = (try? context.fetch(fetchRequest).first) ?? Transaction(context: context)

    return NavigationStack {
        TransactionDetailView(transaction: transaction)
            .environmentObject(DependencyContainer(persistenceController: .preview))
    }
}
