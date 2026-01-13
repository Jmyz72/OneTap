//
//  AddRecurringTransactionView.swift
//  OneTap
//
//  View for adding new recurring transactions
//

import SwiftUI

struct AddRecurringTransactionView: View {
    @EnvironmentObject private var container: DependencyContainer
    @State private var viewModel: AddRecurringTransactionViewModel?

    var body: some View {
        Group {
            if let viewModel {
                AddRecurringTransactionContent(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = container.makeAddRecurringTransactionViewModel()
            }
        }
    }
}

private struct AddRecurringTransactionContent: View {
    @ObservedObject var viewModel: AddRecurringTransactionViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingDatePicker = false
    @State private var showingEndDatePicker = false
    @State private var showingExecutionNumberInput = false
    @State private var showingAccountPicker = false
    @State private var categoryForSubcategoryPicker: Category?
    @State private var showingSplitSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Type Picker
                        typeSection

                        // Amount & Category
                        amountCategorySection

                        // Account
                        accountSection

                        // Optional Details
                        optionalDetailsSection

                        // Split Items Section
                        if viewModel.selectedType == .expense {
                            splitItemsSection
                        }

                        // EXECUTION SECTION
                        executionSection

                        // REPEAT SECTION
                        repeatSection
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("New Recurring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.saveRecurringTransaction()
                        }
                    }
                    .disabled(!viewModel.isValid)
                }
            }
            .sheet(isPresented: $showingDatePicker) {
                datePickerSheet
            }
            .sheet(isPresented: $showingEndDatePicker) {
                endDatePickerSheet
            }
            .sheet(isPresented: $showingExecutionNumberInput) {
                executionNumberInputSheet
            }
            .sheet(isPresented: $showingAccountPicker) {
                AccountPickerSheet(
                    accounts: viewModel.accounts,
                    selectedAccount: $viewModel.selectedAccount
                )
            }
            .sheet(item: $categoryForSubcategoryPicker) { category in
                SubCategoryPickerSheet(
                    category: category,
                    selectedSubCategory: $viewModel.selectedSubCategory
                )
            }
            .sheet(isPresented: $showingSplitSheet) {
                SplitTransactionSheet(
                    items: $viewModel.splitItems,
                    currencyCode: viewModel.selectedAccount?.currency ?? SettingsManager.shared.currencyCode,
                    categories: viewModel.categories
                )
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
                        Color.black.opacity(0.4).ignoresSafeArea()
                        ProgressView().scaleEffect(1.5).tint(.white)
                    }
                }
            }
            .onChange(of: viewModel.loadingState) { _, newState in
                if newState == .loaded {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Sections

    private var typeSection: some View {
        HStack(spacing: 16) {
            typeButton(.expense)
            typeButton(.income)
        }
        .padding(.horizontal, 20)
    }

    private func typeButton(_ type: TransactionType) -> some View {
        Button {
            viewModel.selectedType = type
        } label: {
            Text(type.rawValue)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(viewModel.selectedType == type ? .white : AppTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(viewModel.selectedType == type ? AppTheme.accent : AppTheme.cardBackground)
                .cornerRadius(10)
        }
    }

    private var amountCategorySection: some View {
        VStack(spacing: 16) {
            // Amount
            VStack(alignment: .leading, spacing: 8) {
                Text("Amount")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
                TextField("0.00", text: $viewModel.amountString)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                    .padding()
                    .background(AppTheme.cardBackground)
                    .cornerRadius(12)
            }

            // Category
            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)

                TransactionCategoryGrid(
                    categories: viewModel.categories,
                    selectedType: viewModel.selectedType,
                    selectedCategory: $viewModel.selectedCategory,
                    onCategoryTapped: { category in
                        viewModel.selectedCategory = category
                        if let subs = category.subCategories as? Set<SubCategory>, !subs.isEmpty {
                            categoryForSubcategoryPicker = category
                        }
                    }
                )
            }

            // Subcategory
            if let category = viewModel.selectedCategory,
               let subs = category.subCategories as? Set<SubCategory>,
               !subs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Subcategory")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)

                    Button {
                        categoryForSubcategoryPicker = category
                    } label: {
                        HStack {
                            Text(viewModel.selectedSubCategory?.name ?? "None")
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(AppTheme.textTertiary)
                        }
                        .padding()
                        .background(AppTheme.cardBackground)
                        .cornerRadius(12)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Execution Section
    private var executionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Execution")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                // Start Date
                Button {
                    showingDatePicker = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Start Date")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppTheme.textPrimary)
                            Text("Including the start day.")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(viewModel.startDate, style: .date)
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.textSecondary)
                            Text(viewModel.startDate, style: .time)
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textTertiary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.textTertiary)
                    }
                    .padding()
                }

                Divider().padding(.leading, 16)

                // End Date
                Button {
                    if viewModel.hasEndDate {
                        showingEndDatePicker = true
                    } else {
                        viewModel.hasEndDate = true
                        if viewModel.endDate == nil {
                            viewModel.endDate = Calendar.current.date(byAdding: .year, value: 1, to: viewModel.startDate)
                        }
                        showingEndDatePicker = true
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("End Date")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppTheme.textPrimary)
                            Text("You can also select a specific time.")
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

                Divider().padding(.leading, 16)

                // Requires Confirmation Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Requires Confirmation")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppTheme.textPrimary)
                        Text("Manually approve each transaction")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Spacer()
                    Toggle("", isOn: $viewModel.requiresConfirmation)
                        .labelsHidden()
                }
                .padding()
            }
            .background(AppTheme.cardBackground)
            .cornerRadius(12)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Repeat Section
    private var repeatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Repeat")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .textCase(.uppercase)

            VStack(spacing: 16) {
                // Daily Option
                repeatOptionRow(
                    isSelected: viewModel.frequency == "Daily",
                    icon: "checkmark.circle.fill",
                    title: "Every",
                    interval: $viewModel.interval,
                    unit: "Day(s)"
                ) {
                    viewModel.frequency = "Daily"
                }

                // Weekly Option
                VStack(spacing: 0) {
                    repeatOptionRow(
                        isSelected: viewModel.frequency == "Weekly",
                        icon: "checkmark.circle.fill",
                        title: "Every",
                        interval: $viewModel.interval,
                        unit: "Week(s)"
                    ) {
                        viewModel.frequency = "Weekly"
                    }

                    if viewModel.frequency == "Weekly" {
                        weekdaySelector
                            .padding(.top, 12)
                    }
                }

                // Monthly Option
                VStack(spacing: 0) {
                    repeatOptionRow(
                        isSelected: viewModel.frequency == "Monthly",
                        icon: "checkmark.circle.fill",
                        title: "Every",
                        interval: $viewModel.interval,
                        unit: "Month(s)"
                    ) {
                        viewModel.frequency = "Monthly"
                    }

                    if viewModel.frequency == "Monthly" {
                        monthDaySelector
                            .padding(.top, 12)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Account")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)

            Button {
                showingAccountPicker = true
            } label: {
                HStack {
                    if let account = viewModel.selectedAccount {
                        Image(systemName: account.icon ?? "questionmark.circle")
                            .foregroundColor(AppTheme.accent)
                        Text(account.name ?? "Account")
                            .foregroundColor(AppTheme.textPrimary)
                    } else {
                        Text("Select Account")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(AppTheme.textTertiary)
                }
                .padding()
                .background(AppTheme.cardBackground)
                .cornerRadius(12)
            }
        }
        .padding(.horizontal, 20)
    }

    private var optionalDetailsSection: some View {
        VStack(spacing: 12) {
            // Title
            TextField("Description (optional)", text: $viewModel.title)
                .font(.system(size: 16))
                .foregroundColor(AppTheme.textPrimary)
                .padding()
                .background(AppTheme.cardBackground)
                .cornerRadius(12)

            // Merchant
            TextField("Merchant (optional)", text: $viewModel.merchant)
                .font(.system(size: 16))
                .foregroundColor(AppTheme.textPrimary)
                .padding()
                .background(AppTheme.cardBackground)
                .cornerRadius(12)

            // Note
            TextField("Note (optional)", text: $viewModel.note)
                .font(.system(size: 16))
                .foregroundColor(AppTheme.textPrimary)
                .padding()
                .background(AppTheme.cardBackground)
                .cornerRadius(12)
        }
        .padding(.horizontal, 20)
    }

    private var splitItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Split Items")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)
                    .textCase(.uppercase)

                Spacer()

                Button {
                    showingSplitSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Manage")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
                }
            }

            if !viewModel.splitItems.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(viewModel.splitItems.enumerated()), id: \.offset) { index, item in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppTheme.textPrimary)

                                Text(item.category?.name ?? "")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.textSecondary)
                            }

                            Spacer()

                            Text(Formatters.currencyFormatter(for: viewModel.selectedAccount?.currency ?? SettingsManager.shared.currencyCode).string(from: NSNumber(value: item.amount)) ?? "")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppTheme.expense)
                        }
                        .padding()
                        .background(AppTheme.cardBackground)
                        .cornerRadius(12)
                    }

                    // Total
                    HStack {
                        Text("Total")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)

                        Spacer()

                        Text(Formatters.currencyFormatter(for: viewModel.selectedAccount?.currency ?? SettingsManager.shared.currencyCode).string(from: NSNumber(value: viewModel.totalAmount)) ?? "")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppTheme.accent)
                    }
                    .padding()
                    .background(AppTheme.secondaryBackground)
                    .cornerRadius(12)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Helper Views

    private func repeatOptionRow(
        isSelected: Bool,
        icon: String,
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

                if isSelected {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.textTertiary)
                }
            }
        }
    }

    private var weekdaySelector: some View {
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
        .padding(.horizontal)
    }

    private var monthDaySelector: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(1...31, id: \.self) { day in
                dayButton(day)
            }
            dayButton(0, label: "Last Day")
        }
        .padding(.horizontal)
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

    private var datePickerSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker(
                    "Start Date",
                    selection: $viewModel.startDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .padding()

                Spacer()
            }
            .background(AppTheme.backgroundSolid)
            .navigationTitle("Start Date & Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingDatePicker = false
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var endDatePickerSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker(
                    "End Date",
                    selection: Binding(
                        get: { viewModel.endDate ?? Calendar.current.date(byAdding: .year, value: 1, to: viewModel.startDate)! },
                        set: { viewModel.endDate = $0 }
                    ),
                    in: viewModel.startDate...,
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
    AddRecurringTransactionView()
        .environmentObject(DependencyContainer(persistenceController: .preview))
}
