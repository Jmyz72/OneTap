//
//  AddInstallmentPlanView.swift
//  OneTap
//
//  View for creating new installment plans
//

import SwiftUI
@preconcurrency internal import CoreData

struct AddInstallmentPlanView: View {
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: AddInstallmentPlanViewModel?

    var body: some View {
        Group {
            if let viewModel {
                NavigationStack {
                    AddInstallmentPlanContent(viewModel: viewModel, dismiss: dismiss)
                }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = container.makeAddInstallmentPlanViewModel()
            }
        }
    }
}

// MARK: - Content View

private struct AddInstallmentPlanContent: View {
    @ObservedObject var viewModel: AddInstallmentPlanViewModel
    let dismiss: DismissAction

    @State private var showAccountPicker = false
    @State private var showCategoryPicker = false

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    VStack(spacing: 8) {
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.orange, Color.red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("New Installment Plan")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)

                        Text("Split a purchase into monthly payments")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    // Form Fields
                    VStack(spacing: 16) {
                        // Purchase Details
                        FormSection(title: "Purchase Details") {
                            FormField(label: "Item Name", icon: "tag.fill") {
                                TextField("e.g., iPhone 15 Pro", text: $viewModel.title)
                                    .textFieldStyle(.roundedBorder)
                            }

                            FormField(label: "Merchant (Optional)", icon: "bag.fill") {
                                TextField("e.g., Apple Store", text: $viewModel.merchant)
                                    .textFieldStyle(.roundedBorder)
                            }

                            FormField(label: "Total Amount", icon: "dollarsign.circle.fill") {
                                TextField("0.00", text: $viewModel.totalAmountString)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }

                        // Payment Configuration
                        FormSection(title: "Payment Configuration") {
                            FormField(label: "Number of Payments", icon: "number.circle.fill") {
                                Stepper("\(viewModel.numberOfPayments) months", value: $viewModel.numberOfPayments, in: 2...60)
                                    .font(.system(size: 16, weight: .medium))
                            }

                            // Calculated monthly payment
                            if viewModel.totalAmount > 0 {
                                HStack {
                                    Label("Monthly Payment", systemImage: "calendar.circle.fill")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(AppTheme.textSecondary)

                                    Spacer()

                                    Text(viewModel.formattedMonthlyPayment)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.orange)
                                }
                                .padding()
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(12)
                            }

                            FormField(label: "Billing Day", icon: "calendar.badge.clock") {
                                Picker("Billing Day", selection: $viewModel.billingDay) {
                                    ForEach(1...28, id: \.self) { day in
                                        Text("\(day)").tag(Int16(day))
                                    }
                                    Text("Last day of month").tag(Int16(0))
                                }
                                .pickerStyle(.menu)
                            }

                            Toggle(isOn: $viewModel.firstPaymentImmediate) {
                                Label("Pay first installment now", systemImage: "bolt.fill")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .orange))
                        }

                        // Interest & APR
                        FormSection(title: "Interest (Optional)") {
                            Toggle(isOn: $viewModel.hasInterest) {
                                Label("This plan has interest", systemImage: "percent")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .purple))

                            if viewModel.hasInterest {
                                FormField(label: "APR (Annual Percentage Rate)", icon: "percent") {
                                    HStack {
                                        TextField("e.g., 15.0", text: $viewModel.aprPercentage)
                                            .keyboardType(.decimalPad)
                                            .textFieldStyle(.roundedBorder)

                                        Text("%")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(AppTheme.textSecondary)
                                    }
                                }

                                // Interest breakdown
                                if viewModel.totalAmount > 0 && viewModel.annualInterestRate > 0 {
                                    VStack(spacing: 8) {
                                        Divider()

                                        HStack {
                                            Text("Principal Amount")
                                                .font(.system(size: 13))
                                                .foregroundColor(AppTheme.textSecondary)
                                            Spacer()
                                            Text(viewModel.formattedMonthlyPayment)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(AppTheme.textPrimary)
                                        }

                                        HStack {
                                            Text("Total Interest")
                                                .font(.system(size: 13))
                                                .foregroundColor(.purple)
                                            Spacer()
                                            if let interestText = viewModel.formattedTotalInterest {
                                                Text(interestText)
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundColor(.purple)
                                            }
                                        }

                                        Divider()

                                        HStack {
                                            Text("Total Cost")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(AppTheme.textPrimary)
                                            Spacer()
                                            Text(viewModel.formattedTotalCost)
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.purple)
                                        }
                                    }
                                    .padding()
                                    .background(Color.purple.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                        }

                        // Account & Category
                        FormSection(title: "Account & Category") {
                            Button {
                                showAccountPicker = true
                            } label: {
                                HStack {
                                    Label("Account", systemImage: "banknote.fill")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(AppTheme.textSecondary)

                                    Spacer()

                                    if let account = viewModel.selectedAccount {
                                        Text(account.name ?? "Unknown")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(AppTheme.textPrimary)
                                    } else {
                                        Text("Select")
                                            .foregroundColor(.gray)
                                    }

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.gray)
                                }
                            }
                            .buttonStyle(.plain)

                            Button {
                                showCategoryPicker = true
                            } label: {
                                HStack {
                                    Label("Category", systemImage: "square.grid.2x2.fill")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(AppTheme.textSecondary)

                                    Spacer()

                                    if let category = viewModel.selectedCategory {
                                        Text(category.name ?? "Unknown")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(AppTheme.textPrimary)
                                    } else {
                                        Text("Select")
                                            .foregroundColor(.gray)
                                    }

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.gray)
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        // Notes
                        FormSection(title: "Notes (Optional)") {
                            TextEditor(text: $viewModel.notes)
                                .frame(height: 80)
                                .padding(8)
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    Task {
                        await viewModel.createInstallmentPlan()
                        if viewModel.loadingState == .loaded {
                            dismiss()
                        }
                    }
                }
                .disabled(!viewModel.isValid)
                .fontWeight(.bold)
            }
        }
        .sheet(isPresented: $showAccountPicker) {
            AccountPickerSheet(
                accounts: viewModel.accounts,
                selectedAccount: $viewModel.selectedAccount
            )
        }
        .sheet(isPresented: $showCategoryPicker) {
            CategoryPickerSheet(
                categories: viewModel.expenseCategories,
                selectedCategory: $viewModel.selectedCategory
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
            Text(viewModel.errorMessage ?? "")
        }
    }
}

// MARK: - Supporting Views

private struct FormSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(AppTheme.textTertiary)
                .textCase(.uppercase)
                .padding(.leading, 4)

            VStack(spacing: 12) {
                content()
            }
            .padding(16)
            .background(AppTheme.cardBackground)
            .cornerRadius(12)
        }
    }
}

private struct FormField<Content: View>: View {
    let label: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)

            content()
        }
    }
}

private struct CategoryPickerSheet: View {
    let categories: [Category]
    @Binding var selectedCategory: Category?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(categories, id: \.id) { category in
                Button {
                    selectedCategory = category
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: category.icon ?? "tag.fill")
                            .foregroundColor(Color(hex: category.color ?? "#000000"))

                        Text(category.name ?? "Unknown")
                            .foregroundColor(AppTheme.textPrimary)

                        Spacer()

                        if selectedCategory?.id == category.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Select Category")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    AddInstallmentPlanView()
        .environmentObject(DependencyContainer(persistenceController: .preview))
}
