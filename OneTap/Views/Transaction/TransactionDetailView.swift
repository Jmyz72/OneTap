//
//  TransactionDetailView.swift
//  OneTap
//
//  REFACTORED: Now uses TransactionDetailViewModel (MVVM pattern)
//

import SwiftUI
import CoreData

struct TransactionDetailView: View {
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.dismiss) private var dismiss

    let transaction: Transaction
    @StateObject private var viewModel: TransactionDetailViewModel

    // UI State (view-only state)
    @State private var showingEditSheet = false

    init(transaction: Transaction) {
        self.transaction = transaction
        // Create temporary container and ViewModel
        let tempContainer = DependencyContainer()
        _viewModel = StateObject(wrappedValue: tempContainer.makeTransactionDetailViewModel(transaction: transaction))
    }

    var body: some View {
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

                        if let merchant = transaction.merchant {
                            Divider().padding(.leading, 50)
                            DetailRow(label: "Merchant", value: merchant, icon: "cart.fill", color: .purple)
                        }
                    }
                    .modernCardStyle()
                    .padding(.horizontal)

                    // Split Items Section (if any)
                    if !transaction.itemsArray.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Split Items")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(AppTheme.textSecondary)
                                .padding(.horizontal)

                            VStack(spacing: 0) {
                                ForEach(transaction.itemsArray) { item in
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

                    // Delete Button
                    Button {
                        Task {
                            await viewModel.deleteTransaction()
                        }
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
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
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
        .onChange(of: viewModel.loadingState) { _, newState in
            if newState == .loaded {
                dismiss()
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

struct DetailRow: View {
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
