//
//  EditTransactionView.swift
//  OneTap
//
//  REFACTORED: Now uses EditTransactionViewModel (MVVM pattern)
//

import SwiftUI
internal import CoreData

struct EditTransactionView: View {
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.dismiss) private var dismiss

    let transaction: Transaction
    @State private var viewModel: EditTransactionViewModel?

    @State private var showingDatePicker = false
    @State private var showingAccountPicker = false
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
                        EditDatePickerSheet(date: Binding(
                            get: { viewModel.transactionDate },
                            set: { viewModel.transactionDate = $0 }
                        ), isPresented: $showingDatePicker)
                    }
                    .sheet(isPresented: $showingAccountPicker) {
                        AccountPickerSheet(accounts: viewModel.accounts, selectedAccount: Binding(
                            get: { viewModel.selectedAccount },
                            set: { viewModel.selectedAccount = $0 }
                        ))
                    }
                    .sheet(isPresented: $showingSplitSheet) {
                        SplitTransactionSheet(
                            items: Binding(
                                get: { viewModel.splitItems },
                                set: { viewModel.splitItems = $0 }
                            ),
                            currencyCode: viewModel.selectedAccount?.currency ?? SettingsManager.shared.currencyCode
                        )
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
                        if let error = viewModel.errorMessage { Text(error) }
                    }
                    // MVVM: Loading overlay
                    .overlay {
                        if viewModel.loadingState.isLoading {
                            ZStack {
                                Color.black.opacity(0.4).ignoresSafeArea()
                                ProgressView().scaleEffect(1.5).tint(.white)
                            }
                        }
                    }
                    .onChange(of: viewModel.selectedCategory) { _, _ in
                        viewModel.categoryChanged()
                    }
                    .onChange(of: viewModel.loadingState) { _, newState in
                        if newState == .loaded { dismiss() }
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
                if viewModel == nil {
                    viewModel = container.makeEditTransactionViewModel(transaction: transaction)
                }
            }
        }
    }

    @ViewBuilder
    private func mainContent(viewModel: EditTransactionViewModel) -> some View {
        VStack(spacing: 0) {
            TransactionTypePicker(selectedType: Binding(
                get: { viewModel.selectedType },
                set: { viewModel.selectedType = $0 }
            ))

            TransactionCategoryGrid(
                categories: viewModel.categories,
                selectedType: viewModel.selectedType,
                selectedCategory: Binding(
                    get: { viewModel.selectedCategory },
                    set: { viewModel.selectedCategory = $0 }
                )
            )

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

            CustomKeypad(
                value: Binding(
                    get: { viewModel.amountString },
                    set: { viewModel.amountString = $0 }
                ),
                onDone: { Task { await viewModel.saveChanges() } },
                onAddItem: nil
            )
            .padding(.bottom, 10)
        }
    }

    @ViewBuilder
    private func subcategoryButtons(viewModel: EditTransactionViewModel) -> some View {
        if let category = viewModel.selectedCategory,
           let subs = category.subCategories?.allObjects as? [SubCategory] {
            ForEach(subs.sorted { $0.order < $1.order }) { sub in
                Button(sub.name ?? "Unnamed") { viewModel.selectedSubCategory = sub }
            }
            Button("None") { viewModel.selectedSubCategory = nil }
        }
    }
}

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