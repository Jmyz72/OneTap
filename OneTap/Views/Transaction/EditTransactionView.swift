//
//  EditTransactionView.swift
//  OneTap
//
//  REFACTORED: Now uses EditTransactionViewModel (MVVM pattern)
//

import SwiftUI
import CoreData

struct EditTransactionView: View {
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.dismiss) private var dismiss

    let transaction: Transaction
    @StateObject private var viewModel: EditTransactionViewModel

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
    @State private var showingSubCategoryPicker = false
    @State private var showingNoteInput = false
    @State private var showingSplitSheet = false

    init(transaction: Transaction) {
        self.transaction = transaction
        // Create temporary container and ViewModel
        let tempContainer = DependencyContainer()
        _viewModel = StateObject(wrappedValue: tempContainer.makeEditTransactionViewModel(transaction: transaction))
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
            .onChange(of: viewModel.selectedCategory) { _, _ in
                viewModel.categoryChanged()
            }
            .sheet(isPresented: $showingDatePicker) {
                datePickerSheet
            }
            .sheet(isPresented: $showingAccountPicker) {
                AccountPickerSheet(accounts: accounts, selectedAccount: $viewModel.selectedAccount)
            }
            .sheet(isPresented: $showingSplitSheet) {
                SplitTransactionSheet(
                    items: $viewModel.splitItems,
                    currencyCode: viewModel.selectedAccount?.currency ?? SettingsManager.shared.currencyCode
                )
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
            // 1. Type Segment Control
            TransactionTypePicker(selectedType: $viewModel.selectedType)

            // 2. Category Grid
            TransactionCategoryGrid(
                categories: categories,
                selectedType: viewModel.selectedType,
                selectedCategory: $viewModel.selectedCategory
            )

            Spacer()

            // 3. Middle Bar
            middleBar

            // 4. Amount Display
            TransactionAmountDisplay(
                amountString: viewModel.amountString,
                selectedAccount: viewModel.selectedAccount,
                splitItems: viewModel.splitItems,
                selectedType: viewModel.selectedType
            )

            // 5. Keypad
            CustomKeypad(
                value: $viewModel.amountString,
                onDone: {
                    Task {
                        await viewModel.saveChanges()
                    }
                },
                onAddItem: nil // Edit view doesn't support adding items via keypad currently
            )
            .padding(.bottom, 10)
        }
    }

    private var middleBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // SubCategory Chip
                if let category = viewModel.selectedCategory, let subs = category.subCategories, subs.count > 0 {
                    Button { showingSubCategoryPicker = true } label: {
                        chipView(
                            icon: "arrow.turn.down.right",
                            text: viewModel.selectedSubCategory?.name ?? "Subcategory",
                            isActive: viewModel.selectedSubCategory != nil
                        )
                    }
                }

                // Account Chip
                Button { showingAccountPicker = true } label: {
                    chipView(
                        icon: "creditcard.fill",
                        text: viewModel.selectedAccount?.name ?? "Select Account",
                        isActive: viewModel.selectedAccount != nil
                    )
                }

                // Date Chip
                Button { showingDatePicker = true } label: {
                    chipView(
                        icon: "calendar",
                        text: Formatters.shortDate.string(from: viewModel.transactionDate),
                        isActive: true
                    )
                }

                // Split Chip (Only for Expenses)
                if viewModel.selectedType == .expense {
                    Button { showingSplitSheet = true } label: {
                        chipView(
                            icon: "scissors",
                            text: viewModel.splitItems.isEmpty ? "Split" : "\(viewModel.splitItems.count) Items",
                            isActive: !viewModel.splitItems.isEmpty
                        )
                    }
                    .disabled((Double(viewModel.amountString) ?? 0) == 0)
                }

                // Note Chip
                Button { showingNoteInput = true } label: {
                    chipView(
                        icon: "note.text",
                        text: viewModel.note.isEmpty ? "Add Note" : "Note Added",
                        isActive: !viewModel.note.isEmpty
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(AppTheme.secondaryBackground.opacity(0.5))
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
    private var subcategoryButtons: some View {
        if let category = viewModel.selectedCategory, let subs = category.subCategories?.allObjects as? [SubCategory] {
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

    private func chipView(icon: String, text: String, isActive: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(text)
                .font(.system(size: 13, weight: .medium))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isActive ? AppTheme.accent.opacity(0.2) : AppTheme.secondaryBackground)
        .foregroundColor(isActive ? AppTheme.accent : AppTheme.textSecondary)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isActive ? AppTheme.accent : Color.clear, lineWidth: 1)
        )
    }
}

#Preview {
    // Create sample transaction for preview
    let context = PersistenceController.preview.container.viewContext
    let fetchRequest: NSFetchRequest<Transaction> = Transaction.fetchRequest()
    let transaction = (try? context.fetch(fetchRequest).first) ?? Transaction(context: context)

    return EditTransactionView(transaction: transaction)
        .environmentObject(DependencyContainer(persistenceController: .preview))
}
