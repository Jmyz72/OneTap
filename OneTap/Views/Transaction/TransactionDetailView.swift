//
//  TransactionDetailView.swift
//  OneTap
//
//  REFACTORED: Now uses TransactionDetailViewModel (MVVM pattern)
//

import SwiftUI
@preconcurrency internal import CoreData

struct TransactionDetailView: View {
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.dismiss) private var dismiss

    let transaction: Transaction
    @State private var viewModel: TransactionDetailViewModel?

    // UI State (view-only state)
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        Group {
            if let viewModel {
                ZStack {
                    AppTheme.background.ignoresSafeArea()

                    ScrollView {
                        VStack(spacing: 24) {
                            // Header with Category Icon and Amount
                            VStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(transaction.category?.colorView.opacity(0.15) ?? AppTheme.accent.opacity(0.15))
                                        .frame(width: 80, height: 80)

                                    Image(systemName: transaction.category?.iconName ?? "questionmark.circle.fill")
                                        .font(.system(size: 32, weight: .bold))
                                        .foregroundColor(transaction.category?.colorView ?? AppTheme.accent)
                                }

                                Text(transaction.title ?? "Unknown")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(AppTheme.textPrimary)

                                Text(transaction.formattedAmount)
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundColor(amountColor)
                            }
                            .padding(.top, 20)

                            // Main Info Card
                            VStack(spacing: 0) {
                                DetailRow(
                                    label: "Category",
                                    value: (transaction.category?.name ?? "None") + (transaction.subCategory != nil ? " - \(transaction.subCategory!.name!)" : ""),
                                    icon: "grid",
                                    color: .orange
                                )
                                Divider().padding(.leading, 50)
                                DetailRow(label: "Account", value: transaction.account?.name ?? "None", icon: "creditcard.fill", color: .blue)
                                Divider().padding(.leading, 50)
                                DetailRow(label: "Date & Time", value: Formatters.dateTime.string(from: transaction.date ?? Date()), icon: "calendar", color: .red)
                                Divider().padding(.leading, 50)
                                DetailRow(label: "Balance After", value: transaction.formattedBalanceAfter, icon: "equal.circle.fill", color: .green)

                                if let merchant = transaction.merchant {
                                    Divider().padding(.leading, 50)
                                    DetailRow(label: "Merchant", value: merchant, icon: "cart.fill", color: .purple)
                                }
                            }
                            .modernCardStyle()
                            .padding(.horizontal)

                            // Installment Info Section (if part of installment plan)
                            if transaction.isPartOfInstallment, let plan = transaction.recurringTransaction {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Installment Plan")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(AppTheme.textSecondary)
                                        .padding(.horizontal)

                                    NavigationLink(destination: InstallmentDetailView(plan: plan)) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "creditcard.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(.purple)
                                                .frame(width: 36, height: 36)
                                                .background(Color.purple.opacity(0.15))
                                                .cornerRadius(8)

                                            VStack(alignment: .leading, spacing: 4) {
                                                if let label = transaction.installmentLabel {
                                                    Text(label)
                                                        .font(.system(size: 15, weight: .semibold))
                                                        .foregroundColor(AppTheme.textPrimary)
                                                }
                                                if let detail = transaction.installmentDetail {
                                                    Text(detail)
                                                        .font(.system(size: 13))
                                                        .foregroundColor(AppTheme.textSecondary)
                                                }
                                            }

                                            Spacer()

                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(AppTheme.textTertiary)
                                        }
                                        .padding()
                                        .modernCardStyle()
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal)
                                }
                            }

                            // Linked Transfer Section (if transfer type)
                            if transaction.typeEnum == .transfer, transaction.relatedTransactionID != nil {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Linked Transfer")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(AppTheme.textSecondary)
                                        .padding(.horizontal)

                                    HStack(spacing: 12) {
                                        Image(systemName: "arrow.left.arrow.right")
                                            .font(.system(size: 20))
                                            .foregroundColor(.blue)
                                            .frame(width: 36, height: 36)
                                            .background(Color.blue.opacity(0.15))
                                            .cornerRadius(8)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Transfer Transaction")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(AppTheme.textPrimary)
                                            Text("This transaction is part of a transfer")
                                                .font(.system(size: 13))
                                                .foregroundColor(AppTheme.textSecondary)
                                        }

                                        Spacer()
                                    }
                                    .padding()
                                    .modernCardStyle()
                                    .padding(.horizontal)
                                }
                            }

                            // Split Items Section (if any)
                            if !transaction.itemsArray.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Split Items")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(AppTheme.textSecondary)
                                        .padding(.horizontal)

                                    VStack(spacing: 0) {
                                        ForEach(transaction.itemsArray, id: \.objectID) { item in
                                            HStack {
                                                Image(systemName: item.category?.iconName ?? "tag.fill")
                                                    .foregroundColor(item.category?.colorView ?? AppTheme.accent)
                                                    .frame(width: 30)

                                                Text(item.title ?? "Item")
                                                    .foregroundColor(AppTheme.textPrimary)

                                                Spacer()

                                                Text(item.formattedAmount)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(AppTheme.textPrimary)
                                            }
                                            .padding()

                                            if item != transaction.itemsArray.last {
                                                Divider().padding(.leading, 46)
                                            }
                                        }
                                    }
                                    .modernCardStyle()
                                    .padding(.horizontal)
                                }
                            }

                            // Notes Section
                            if let notes = transaction.notes, !notes.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Notes")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(AppTheme.textSecondary)
                                        .padding(.horizontal)

                                    Text(notes)
                                        .font(.system(size: 15))
                                        .foregroundColor(AppTheme.textPrimary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding()
                                        .modernCardStyle()
                                        .padding(.horizontal)
                                }
                            }

                            // Adjustment Reason Section
                            if transaction.typeEnum == .adjustment, let reason = transaction.adjustmentReason, !reason.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Adjustment Reason")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(AppTheme.textSecondary)
                                        .padding(.horizontal)

                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: "doc.text.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(.blue)
                                            .frame(width: 30)

                                        Text(reason)
                                            .font(.system(size: 15))
                                            .foregroundColor(AppTheme.textPrimary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .modernCardStyle()
                                    .padding(.horizontal)
                                }
                            }

                            // Metadata Footer (timestamps)
                            if transaction.createdAt != nil || transaction.updatedAt != nil {
                                VStack(alignment: .leading, spacing: 4) {
                                    if let created = transaction.createdAt {
                                        Text("Created \(Formatters.dateTime.string(from: created))")
                                            .font(.system(size: 12))
                                            .foregroundColor(AppTheme.textTertiary)
                                    }
                                    if let updated = transaction.updatedAt,
                                       let created = transaction.createdAt,
                                       updated.timeIntervalSince(created) > 60 {
                                        Text("Modified \(Formatters.dateTime.string(from: updated))")
                                            .font(.system(size: 12))
                                            .foregroundColor(AppTheme.textTertiary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                            }

                            // Delete Button
                            Button {
                                showingDeleteConfirmation = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Delete Transaction")
                                }
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(AppTheme.expense)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppTheme.expense.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppTheme.expense.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .disabled(viewModel.loadingState.isLoading)
                            .padding(.horizontal)
                            .padding(.top, 20)
                            .padding(.bottom, 40)
                        }
                    }
                }
                .navigationTitle("Details")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Edit") {
                            showingEditSheet = true
                        }
                    }
                }
                .sheet(isPresented: $showingEditSheet) {
                    EditTransactionView(transaction: transaction)
                }
                // MVVM: Error handling
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
                // Delete confirmation
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
                // MVVM: Loading overlay
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
                // MVVM: Auto-dismiss on success (after delete)
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

    private var amountColor: Color {
        switch transaction.typeEnum {
        case .expense: return AppTheme.expense
        case .income: return AppTheme.income
        case .transfer: return AppTheme.textPrimary
        case .adjustment: return AppTheme.textSecondary
        }
    }
}

private struct DetailRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 24)

            Text(label)
                .font(.system(size: 15))
                .foregroundColor(AppTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
        }
        .padding(16)
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
