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
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: AddTransactionViewModel?

    // UI State for Sheets/Pickers (view-only state)
    @State private var showingDatePicker = false
    @State private var showingAccountPicker = false
    @State private var showingToAccountPicker = false
    @State private var showingSubCategoryPicker = false
    @State private var showingNoteInput = false
    @State private var showingSplitSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    ZStack {
                        AppTheme.background.ignoresSafeArea()
                        mainContent(viewModel: viewModel)
                    }
                    .sheet(isPresented: $showingDatePicker) {
                        datePickerSheet
                    }
                    .sheet(isPresented: $showingAccountPicker) {
                        AccountPickerSheet(accounts: viewModel.accounts, selectedAccount: Binding(
                            get: { viewModel.selectedAccount },
                            set: { viewModel.selectedAccount = $0 }
                        ))
                    }
                    .sheet(isPresented: $showingToAccountPicker) {
                        AccountPickerSheet(accounts: viewModel.accounts, selectedAccount: Binding(
                            get: { viewModel.toAccount },
                            set: { viewModel.toAccount = $0 }
                        ), excludeId: viewModel.selectedAccount?.id)
                    }
                    .sheet(isPresented: $showingSplitSheet) {
                        splitSheetView(viewModel: viewModel)
                    }
                    .confirmationDialog("Select Subcategory", isPresented: $showingSubCategoryPicker, titleVisibility: .visible) {
                        subcategoryButtons(viewModel: viewModel)
                    }
                    .alert("Add Note", isPresented: $showingNoteInput) {
                        TextField("Note", text: Binding(
                            get: { viewModel.note },
                            set: { viewModel.note = $0 }
                        ))
                        Button("Done") { }
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
                } else {
                    ProgressView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                // Initialize ViewModel from injected container
                if viewModel == nil {
                    viewModel = container.makeAddTransactionViewModel()
                }
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func mainContent(viewModel: AddTransactionViewModel) -> some View {
        VStack(spacing: 0) {
            TransactionTypePicker(selectedType: Binding(
                get: { viewModel.selectedType },
                set: { viewModel.selectedType = $0 }
            ))

            topSelectionView(viewModel: viewModel)

            Spacer()

            TransactionMiddleBar(
                selectedCategory: Binding(
                    get: { viewModel.selectedCategory },
                    set: { viewModel.selectedCategory = $0 }
                ),
                selectedSubCategory: Binding(
                    get: { viewModel.selectedSubCategory },
                    set: { viewModel.selectedSubCategory = $0 }
                ),
                selectedAccount: Binding(
                    get: { viewModel.selectedAccount },
                    set: { viewModel.selectedAccount = $0 }
                ),
                transactionDate: Binding(
                    get: { viewModel.transactionDate },
                    set: { viewModel.transactionDate = $0 }
                ),
                splitItems: Binding(
                    get: { viewModel.splitItems },
                    set: { viewModel.splitItems = $0 }
                ),
                note: Binding(
                    get: { viewModel.note },
                    set: { viewModel.note = $0 }
                ),
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

            keypadSection(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private func topSelectionView(viewModel: AddTransactionViewModel) -> some View {
        if viewModel.selectedType == .transfer {
            TransactionTransferSelector(
                selectedAccount: viewModel.selectedAccount,
                toAccount: viewModel.toAccount,
                onSelectFrom: { showingAccountPicker = true },
                onSelectTo: { showingToAccountPicker = true }
            )
        } else {
            TransactionCategoryGrid(
                categories: viewModel.categories,
                selectedType: viewModel.selectedType,
                selectedCategory: Binding(
                    get: { viewModel.selectedCategory },
                    set: { viewModel.selectedCategory = $0 }
                )
            )
        }
    }

    private func keypadSection(viewModel: AddTransactionViewModel) -> some View {
        VStack {
            CustomKeypad(
                value: Binding(
                    get: { viewModel.amountString },
                    set: { viewModel.amountString = $0 }
                ),
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
    private func subcategoryButtons(viewModel: AddTransactionViewModel) -> some View {
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
            DatePicker("Date", selection: Binding(
                get: { viewModel?.transactionDate ?? Date() },
                set: { viewModel?.transactionDate = $0 }
            ), displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.graphical)
                .padding()
            Button("Done") { showingDatePicker = false }
                .buttonStyle(.borderedProminent)
                .padding()
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private func splitSheetView(viewModel: AddTransactionViewModel) -> some View {
        SplitTransactionSheet(
            items: Binding(
                get: { viewModel.splitItems },
                set: { viewModel.splitItems = $0 }
            ),
            currencyCode: viewModel.selectedAccount?.currency ?? SettingsManager.shared.currencyCode
        )
    }
}

#Preview {
    AddTransactionView()
        .environmentObject(DependencyContainer(persistenceController: .preview))
}
