//
//  AddTransactionView.swift
//  OneTap
//
//  REFACTORED: Now uses AddTransactionViewModel (MVVM pattern)
//

import SwiftUI
import CoreData

struct AddTransactionView: View {
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel: AddTransactionViewModel

    // Keep @FetchRequest only for UI display in pickers/grids
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)],
        animation: .default
    ) private var categories: FetchedResults<Category>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Account.name, ascending: true)],
        animation: .default
    ) private var accounts: FetchedResults<Account>

    // UI State for Sheets/Pickers (view-only state)
    @State private var showingDatePicker = false
    @State private var showingAccountPicker = false
    @State private var showingToAccountPicker = false
    @State private var showingSubCategoryPicker = false
    @State private var showingNoteInput = false
    @State private var showingSplitSheet = false

    init() {
        // Note: container is injected via @EnvironmentObject, but we can't access it in init
        // So we create a temporary ViewModel that will be replaced on appear
        let tempContainer = DependencyContainer()
        _viewModel = StateObject(wrappedValue: tempContainer.makeAddTransactionViewModel())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                mainContent
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                // Setup defaults with fetched data
                viewModel.setupDefaults(accounts: Array(accounts), categories: Array(categories))
            }
            .onChange(of: viewModel.selectedType) { _, newValue in
                viewModel.typeChanged(to: newValue, categories: Array(categories))
            }
            .onChange(of: viewModel.selectedCategory) { _, _ in
                viewModel.categoryChanged()
            }
            .sheet(isPresented: $showingDatePicker) {
                datePickerSheet
            }
            .sheet(isPresented: $showingAccountPicker) {
                AccountPickerSheet(accounts: accounts, selectedAccount: $viewModel.selectedAccount)
            }
            .sheet(isPresented: $showingToAccountPicker) {
                AccountPickerSheet(accounts: accounts, selectedAccount: $viewModel.toAccount, excludeId: viewModel.selectedAccount?.id)
            }
            .sheet(isPresented: $showingSplitSheet) {
                splitSheetView
            }
            .confirmationDialog("Select Subcategory", isPresented: $showingSubCategoryPicker, titleVisibility: .visible) {
                subcategoryButtons
            }
            .alert("Add Note", isPresented: $showingNoteInput) {
                TextField("Note", text: $viewModel.note)
                Button("Done") { }
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
            // MVVM: Auto-dismiss on success
            .onChange(of: viewModel.loadingState) { _, newState in
                if newState == .loaded {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            TransactionTypePicker(selectedType: $viewModel.selectedType)

            topSelectionView

            Spacer()

            TransactionMiddleBar(
                selectedCategory: $viewModel.selectedCategory,
                selectedSubCategory: $viewModel.selectedSubCategory,
                selectedAccount: $viewModel.selectedAccount,
                transactionDate: $viewModel.transactionDate,
                splitItems: $viewModel.splitItems,
                note: $viewModel.note,
                selectedType: viewModel.selectedType,
                onSubCategoryTap: { showingSubCategoryPicker = true },
                onAccountTap: { showingAccountPicker = true },
                onDateTap: { showingDatePicker = true },
                onSplitTap: { showingSplitSheet = true },
                onNoteTap: { showingNoteInput = true }
            )

            TransactionAmountDisplay(
                amountString: viewModel.amountString,
                selectedAccount: viewModel.selectedAccount,
                splitItems: viewModel.splitItems,
                selectedType: viewModel.selectedType
            )

            keypadSection
        }
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
        } else {
            TransactionCategoryGrid(
                categories: categories,
                selectedType: viewModel.selectedType,
                selectedCategory: $viewModel.selectedCategory
            )
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

    @ViewBuilder
    private var subcategoryButtons: some View {
        if let category = viewModel.selectedCategory,
           let subs = category.subCategories?.allObjects as? [SubCategory] {
            ForEach(subs.sorted { $0.order < $1.order }) { sub in
                Button(sub.name ?? "Unnamed") {
                    viewModel.selectedSubCategory = sub
                }
            }
            Button("None") {
                viewModel.selectedSubCategory = nil
            }
        }
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
            currencyCode: viewModel.selectedAccount?.currency ?? SettingsManager.shared.currencyCode
        )
    }
}

#Preview {
    AddTransactionView()
        .environmentObject(DependencyContainer(persistenceController: .preview))
}
