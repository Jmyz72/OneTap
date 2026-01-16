//
//  EditTransactionView.swift
//  OneTap
//
//  REFACTORED: Now uses EditTransactionViewModel (MVVM pattern)
//

import SwiftUI
@preconcurrency internal import CoreData

struct EditTransactionView: View {
    @EnvironmentObject private var container: DependencyContainer
    let transaction: Transaction
    @State private var viewModel: EditTransactionViewModel?

    var body: some View {
        Group {
            if let viewModel {
                EditTransactionContent(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = container.makeEditTransactionViewModel(transaction: transaction)
            }
        }
    }
}

// MARK: - Content View

private struct EditTransactionContent: View {
    @ObservedObject var viewModel: EditTransactionViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingDatePicker = false
    @State private var showingAccountPicker = false
    @State private var categoryForSubcategoryPicker: Category?
    @State private var showingNoteInput = false
    @State private var showingMerchantInput = false
    @State private var showingSplitSheet = false
    @State private var showingRecurringPicker = false

    @FocusState private var focusedField: TransactionDetailsInput.Field?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                mainContent
            }
            .sheet(isPresented: $showingDatePicker) {
                EditDatePickerSheet(date: $viewModel.transactionDate, isPresented: $showingDatePicker)
            }
            .sheet(isPresented: $showingAccountPicker) {
                AccountPickerSheet(
                    accounts: viewModel.accounts,
                    selectedAccount: $viewModel.selectedAccount
                )
            }
            .sheet(isPresented: $showingSplitSheet) {
                SplitTransactionSheet(
                    items: $viewModel.splitItems,
                    currencyCode: viewModel.selectedAccount?.currency ?? SettingsManager.shared.currencyCode,
                    categories: viewModel.categories
                )
            }
            .sheet(item: $categoryForSubcategoryPicker) { category in
                SubCategoryPickerSheet(
                    category: category,
                    selectedSubCategory: $viewModel.selectedSubCategory
                )
            }
            .alert("Add Note", isPresented: $showingNoteInput) {
                TextField("Note", text: $viewModel.note)
                Button("Done") { }
            }
            .alert("Add Merchant", isPresented: $showingMerchantInput) {
                TextField("Merchant Name", text: $viewModel.merchant)
                Button("Done") { }
            }
            .confirmationDialog("Recurring Frequency", isPresented: $showingRecurringPicker, titleVisibility: .visible) {
                ForEach(viewModel.frequencies, id: \.self) { freq in
                    Button(freq) {
                        viewModel.frequency = freq
                        viewModel.isRecurring = true
                    }
                }
                if viewModel.isRecurring {
                    Button("Remove Recurring", role: .destructive) {
                        viewModel.isRecurring = false
                    }
                }
                Button("Cancel", role: .cancel) { }
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
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: viewModel.selectedCategory) { _, _ in
                viewModel.categoryChanged()
            }
            .onChange(of: viewModel.loadingState) { _, newState in
                if newState == .loaded {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Subviews

    private var mainContent: some View {
        ZStack {
            // Background Layer
            if focusedField != nil {
                VStack(spacing: 0) {
                    TransactionTypePicker(selectedType: $viewModel.selectedType)
                    categoryGridView
                    Spacer()
                    middleBarView
                    Spacer().frame(height: 100)
                }
                .opacity(0.3)
                .allowsHitTesting(false)
            }

            // Interactive Layer
            VStack(spacing: 0) {
                if focusedField == nil {
                    TransactionTypePicker(selectedType: $viewModel.selectedType)
                    categoryGridView
                    Spacer()
                    middleBarView
                } else {
                    Spacer()
                }

                TransactionDetailsInput(
                    title: $viewModel.title,
                    transactionDate: $viewModel.transactionDate,
                    onDateTap: { showingDatePicker = true },
                    focusedField: $focusedField
                )

                TransactionAmountDisplay(
                    amountString: viewModel.amountString,
                    selectedAccount: viewModel.selectedAccount,
                    splitItems: viewModel.splitItems,
                    selectedType: viewModel.selectedType
                )

                if focusedField == nil {
                    CustomKeypad(
                        value: $viewModel.amountString,
                        onDone: {
                            Task {
                                await viewModel.saveChanges()
                            }
                        },
                        onAddItem: viewModel.selectedType == .expense ? {
                            viewModel.addSplitItem()
                        } : nil
                    )
                    .padding(.bottom, 10)
                }
            }
        }
    }
    
    private var categoryGridView: some View {
        TransactionCategoryGrid(
            categories: viewModel.categories,
            selectedType: viewModel.selectedType,
            selectedCategory: $viewModel.selectedCategory,
            onCategoryTapped: { category in
                // Show subcategory sheet if category has subcategories
                if let subcategories = category.subCategories?.allObjects as? [SubCategory],
                   !subcategories.isEmpty {
                        categoryForSubcategoryPicker = category
                }
            }
        )
    }
    
    private var middleBarView: some View {
        TransactionMiddleBar(
            selectedCategory: $viewModel.selectedCategory,
            selectedSubCategory: $viewModel.selectedSubCategory,
            selectedAccount: $viewModel.selectedAccount,
            transactionDate: $viewModel.transactionDate,
            merchant: $viewModel.merchant,
            splitItems: $viewModel.splitItems,
            note: $viewModel.note,
            isRecurring: $viewModel.isRecurring,
            frequency: $viewModel.frequency,
            isInstallment: $viewModel.isInstallment,
            showInstallmentOption: viewModel.showInstallmentOption,
            installmentPayments: viewModel.installmentPayments,
            formattedInstallmentPayment: viewModel.formattedInstallmentPayment,
            excludeFromReports: $viewModel.excludeFromReports,
            markAsClaim: $viewModel.markAsClaim,
            selectedType: viewModel.selectedType,
            onSubCategoryTap: {
                if let category = viewModel.selectedCategory {
                    categoryForSubcategoryPicker = category
                }
            },
            onAccountTap: { showingAccountPicker = true },
            onMerchantTap: { showingMerchantInput = true },
            onSplitTap: { showingSplitSheet = true },
            onNoteTap: { showingNoteInput = true },
            onRecurringTap: { showingRecurringPicker = true },
            onInstallmentTap: { },
            onExclusionTap: { viewModel.excludeFromReports.toggle() },
            onClaimTap: { viewModel.markAsClaim.toggle() }
        )
    }

}

// MARK: - Helper Views

struct EditDatePickerSheet: View {
    @Binding var date: Date
    @Binding var isPresented: Bool

    var body: some View {
        VStack {
            DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.graphical)
                .padding()
            Button("Done") { isPresented = false }
                .buttonStyle(.borderedProminent)
                .padding()
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let fetchRequest: NSFetchRequest<Transaction> = Transaction.fetchRequest()
    let transaction = (try? context.fetch(fetchRequest).first) ?? Transaction(context: context)

    return EditTransactionView(transaction: transaction)
        .environmentObject(DependencyContainer(persistenceController: .preview))
}
