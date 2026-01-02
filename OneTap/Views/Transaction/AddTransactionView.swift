//
//  AddTransactionView.swift
//  OneTap
//
//  REFACTORED: Now uses AddTransactionViewModel (MVVM pattern)
//

import SwiftUI
internal import CoreData

struct AddTransactionView: View {
    @EnvironmentObject private var container: DependencyContainer
    @State private var viewModel: AddTransactionViewModel?

    var body: some View {
        Group {
            if let viewModel {
                AddTransactionContent(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = container.makeAddTransactionViewModel()
            }
        }
    }
}

// MARK: - Content View

private struct AddTransactionContent: View {
    @ObservedObject var viewModel: AddTransactionViewModel
    @Environment(\.dismiss) private var dismiss

    // UI State for Sheets/Pickers (view-only state)
    @State private var showingDatePicker = false
    @State private var showingAccountPicker = false
    @State private var showingToAccountPicker = false
    @State private var categoryForSubcategoryPicker: Category?
    @State private var showingNoteInput = false
    @State private var showingMerchantInput = false
    @State private var showingSplitSheet = false

    @FocusState private var focusedField: TransactionDetailsInput.Field?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                mainContent
            }
            .sheet(isPresented: $showingDatePicker) {
                datePickerSheet
            }
            .sheet(isPresented: $showingAccountPicker) {
                AccountPickerSheet(
                    accounts: viewModel.accounts,
                    selectedAccount: $viewModel.selectedAccount
                )
            }
            .sheet(isPresented: $showingToAccountPicker) {
                AccountPickerSheet(
                    accounts: viewModel.accounts,
                    selectedAccount: $viewModel.toAccount,
                    excludeId: viewModel.selectedAccount?.id
                )
            }
            .sheet(isPresented: $showingSplitSheet) {
                splitSheetView
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
            .onChange(of: viewModel.selectedType) { _, newValue in
                viewModel.typeChanged(to: newValue)
            }
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
            // Background Layer (Visible when editing title)
            if focusedField != nil {
                VStack(spacing: 0) {
                    TransactionTypePicker(selectedType: $viewModel.selectedType)
                    topSelectionView
                    Spacer()
                    middleBarView
                    // Push the middle bar up to its normal position approx
                    Spacer().frame(height: 100) // Estimate height of input + amount
                }
                .opacity(0.3)
                .allowsHitTesting(false)
            }

            // Interactive Foreground Layer
            VStack(spacing: 0) {
                if focusedField == nil {
                    TransactionTypePicker(selectedType: $viewModel.selectedType)

                    topSelectionView
                        .animation(.easeInOut(duration: 0.3), value: viewModel.selectedType)

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
                    keypadSection
                }
            }
        }
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
            selectedType: viewModel.selectedType,
            onSubCategoryTap: {
                if let category = viewModel.selectedCategory {
                    categoryForSubcategoryPicker = category
                }
            },
            onAccountTap: { showingAccountPicker = true },
            onMerchantTap: { showingMerchantInput = true },
            onSplitTap: { showingSplitSheet = true },
            onNoteTap: { showingNoteInput = true }
        )
    }

    @ViewBuilder
    private var topSelectionView: some View {
        if viewModel.selectedType == .transfer {
            TransactionTransferSelector(
                selectedAccount: viewModel.selectedAccount,
                toAccount: viewModel.toAccount,
                onSelectFrom: { showingAccountPicker = true },
                onSelectTo: { showingToAccountPicker = true }
            )
            .id("transfer")
            .transition(.opacity)
        } else {
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
            .id("category-\(viewModel.selectedType.rawValue)")
            .transition(.opacity)
        }
    }

    private var keypadSection: some View {
        VStack {
            CustomKeypad(
                value: $viewModel.amountString,
                onDone: {
                    Task {
                        await viewModel.saveTransaction()
                    }
                },
                onAddItem: viewModel.selectedType == .expense ? {
                    viewModel.addSplitItem()
                } : nil
            )
        }
        .padding(.bottom, 10)
    }

    private var datePickerSheet: some View {
        VStack {
            DatePicker("Date", selection: $viewModel.transactionDate, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.graphical)
                .padding()
            Button("Done") { showingDatePicker = false }
                .buttonStyle(.borderedProminent)
                .padding()
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private var splitSheetView: some View {
        SplitTransactionSheet(
            items: $viewModel.splitItems,
            currencyCode: viewModel.selectedAccount?.currency ?? SettingsManager.shared.currencyCode,
            categories: viewModel.categories
        )
    }
}

#Preview {
    AddTransactionView()
        .environmentObject(DependencyContainer(persistenceController: .preview))
}
