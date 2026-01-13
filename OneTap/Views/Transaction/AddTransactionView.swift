//
//  AddTransactionView.swift
//  OneTap
//
//  REFACTORED: Now uses AddTransactionViewModel (MVVM pattern)
//

import SwiftUI
@preconcurrency internal import CoreData

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
    @State private var showingRecurringPicker = false
    @State private var showingRecurringConfigSheet = false

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
            .confirmationDialog("Recurring Frequency", isPresented: $showingRecurringPicker, titleVisibility: .visible) {
                ForEach(viewModel.frequencies, id: \.self) { freq in
                    Button(freq) {
                        viewModel.frequency = freq
                        viewModel.isRecurring = true
                        showingRecurringConfigSheet = true
                    }
                }
                if viewModel.isRecurring {
                    Button("Edit Configuration") {
                        showingRecurringConfigSheet = true
                    }
                    Button("Remove Recurring", role: .destructive) {
                        viewModel.isRecurring = false
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
            .sheet(isPresented: $showingRecurringConfigSheet) {
                RecurringConfigSheet(viewModel: viewModel)
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
            isRecurring: $viewModel.isRecurring,
            frequency: $viewModel.frequency,
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
            onRecurringTap: { showingRecurringPicker = true }
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

// MARK: - Recurring Configuration Sheet

private struct RecurringConfigSheet: View {
    @ObservedObject var viewModel: AddTransactionViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingEndDatePicker = false
    @State private var showingExecutionNumberInput = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Frequency & Interval
                        frequencySection

                        // Execution Configuration
                        executionSection

                        // Day Selection (Weekly/Monthly)
                        if viewModel.frequency == "Weekly" {
                            weekdaySection
                        } else if viewModel.frequency == "Monthly" {
                            monthDaySection
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Recurring Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingEndDatePicker) {
                endDatePickerSheet
            }
            .sheet(isPresented: $showingExecutionNumberInput) {
                executionNumberInputSheet
            }
        }
        .preferredColorScheme(.dark)
    }

    private var frequencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Repeat")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .textCase(.uppercase)

            VStack(spacing: 16) {
                // Daily Option
                repeatOptionRow(
                    isSelected: viewModel.frequency == "Daily",
                    title: "Every",
                    interval: $viewModel.interval,
                    unit: "Day(s)"
                ) {
                    viewModel.frequency = "Daily"
                }

                // Weekly Option
                repeatOptionRow(
                    isSelected: viewModel.frequency == "Weekly",
                    title: "Every",
                    interval: $viewModel.interval,
                    unit: "Week(s)"
                ) {
                    viewModel.frequency = "Weekly"
                }

                // Monthly Option
                repeatOptionRow(
                    isSelected: viewModel.frequency == "Monthly",
                    title: "Every",
                    interval: $viewModel.interval,
                    unit: "Month(s)"
                ) {
                    viewModel.frequency = "Monthly"
                }

                // Yearly Option
                repeatOptionRow(
                    isSelected: viewModel.frequency == "Yearly",
                    title: "Every",
                    interval: $viewModel.interval,
                    unit: "Year(s)"
                ) {
                    viewModel.frequency = "Yearly"
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var executionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Execution")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                // End Date
                Button {
                    if viewModel.hasEndDate {
                        showingEndDatePicker = true
                    } else {
                        viewModel.hasEndDate = true
                        if viewModel.endDate == nil {
                            viewModel.endDate = Calendar.current.date(byAdding: .year, value: 1, to: viewModel.transactionDate)
                        }
                        showingEndDatePicker = true
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("End Date")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppTheme.textPrimary)
                            Text("Optional end date")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        Spacer()
                        if viewModel.hasEndDate {
                            Text(viewModel.endDate.map { Formatters.date.string(from: $0) } ?? "Select")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.textSecondary)
                        } else {
                            Text("Never End")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.textTertiary)
                    }
                    .padding()
                }

                Divider().padding(.leading, 16)

                // Executions Number
                Button {
                    if viewModel.hasOccurrenceLimit {
                        showingExecutionNumberInput = true
                    } else {
                        viewModel.hasOccurrenceLimit = true
                        if viewModel.occurrenceLimitString.isEmpty {
                            viewModel.occurrenceLimitString = "12"
                        }
                        showingExecutionNumberInput = true
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Executions Number")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppTheme.textPrimary)
                            Text("Maximum number of executions")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        Spacer()
                        if viewModel.hasOccurrenceLimit {
                            Text(viewModel.occurrenceLimitString.isEmpty ? "Enter" : viewModel.occurrenceLimitString)
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.textSecondary)
                        } else {
                            Text("No limited")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.textTertiary)
                    }
                    .padding()
                }
            }
            .background(AppTheme.cardBackground)
            .cornerRadius(12)
        }
        .padding(.horizontal, 20)
    }

    private var weekdaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Days")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .textCase(.uppercase)

            HStack(spacing: 12) {
                ForEach([1, 2, 3, 4, 5, 6, 7], id: \.self) { weekday in
                    let isSelected = viewModel.selectedWeekdays.contains(weekday)
                    Button {
                        if isSelected {
                            viewModel.selectedWeekdays.remove(weekday)
                        } else {
                            viewModel.selectedWeekdays.insert(weekday)
                        }
                    } label: {
                        Text(weekdayShortName(weekday))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isSelected ? .white : AppTheme.textSecondary)
                            .frame(width: 40, height: 40)
                            .background(isSelected ? AppTheme.accent : AppTheme.secondaryBackground)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var monthDaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Day")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .textCase(.uppercase)

            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(1...31, id: \.self) { day in
                    dayButton(day)
                }
                dayButton(0, label: "Last")
            }
        }
        .padding(.horizontal, 20)
    }

    private func repeatOptionRow(
        isSelected: Bool,
        title: String,
        interval: Binding<Int>,
        unit: String,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? AppTheme.accent : AppTheme.textTertiary)

                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.textPrimary)

                if isSelected {
                    TextField("1", value: interval, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .frame(width: 40)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(AppTheme.background)
                        .cornerRadius(6)
                }

                Text(unit)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()
            }
        }
    }

    private func dayButton(_ day: Int, label: String? = nil) -> some View {
        let isSelected = viewModel.selectedMonthDay == day
        return Button {
            viewModel.selectedMonthDay = day
        } label: {
            Text(label ?? "\(day)")
                .font(.system(size: label != nil ? 10 : 14, weight: .medium))
                .foregroundColor(isSelected ? .white : AppTheme.textSecondary)
                .frame(width: 40, height: 40)
                .background(isSelected ? AppTheme.accent : AppTheme.secondaryBackground)
                .cornerRadius(8)
        }
    }

    private func weekdayShortName(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "S"
        case 2: return "M"
        case 3: return "T"
        case 4: return "W"
        case 5: return "T"
        case 6: return "F"
        case 7: return "S"
        default: return ""
        }
    }

    private var endDatePickerSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker(
                    "End Date",
                    selection: Binding(
                        get: { viewModel.endDate ?? Calendar.current.date(byAdding: .year, value: 1, to: viewModel.transactionDate)! },
                        set: { viewModel.endDate = $0 }
                    ),
                    in: viewModel.transactionDate...,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding()

                Button(role: .destructive) {
                    viewModel.hasEndDate = false
                    viewModel.endDate = nil
                    showingEndDatePicker = false
                } label: {
                    Text("Never End")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.expense)
                        .cornerRadius(12)
                }
                .padding(.horizontal)

                Spacer()
            }
            .background(AppTheme.backgroundSolid)
            .navigationTitle("End Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingEndDatePicker = false
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var executionNumberInputSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Maximum Executions")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)

                    Text("Specify how many times this recurring transaction should execute.")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.textSecondary)

                    TextField("Enter number", text: $viewModel.occurrenceLimitString)
                        .keyboardType(.numberPad)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                        .padding()
                        .background(AppTheme.cardBackground)
                        .cornerRadius(12)
                }
                .padding()

                Button(role: .destructive) {
                    viewModel.hasOccurrenceLimit = false
                    viewModel.occurrenceLimitString = ""
                    showingExecutionNumberInput = false
                } label: {
                    Text("No Limit")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.expense)
                        .cornerRadius(12)
                }
                .padding(.horizontal)

                Spacer()
            }
            .background(AppTheme.backgroundSolid)
            .navigationTitle("Executions Number")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingExecutionNumberInput = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    AddTransactionView()
        .environmentObject(DependencyContainer(persistenceController: .preview))
}
