//
//  EditInstallmentPlanView.swift
//  OneTap
//
//  View for editing existing installment plans
//

import SwiftUI
@preconcurrency internal import CoreData

struct EditInstallmentPlanView: View {
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.dismiss) private var dismiss

    let plan: RecurringTransaction
    @State private var viewModel: EditInstallmentPlanViewModel?

    var body: some View {
        Group {
            if let viewModel {
                NavigationStack {
                    EditInstallmentPlanContent(viewModel: viewModel, dismiss: dismiss)
                }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = container.makeEditInstallmentPlanViewModel(plan: plan)
            }
        }
    }
}

// MARK: - Content View

private struct EditInstallmentPlanContent: View {
    @ObservedObject var viewModel: EditInstallmentPlanViewModel
    let dismiss: DismissAction

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    VStack(spacing: 8) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.blue, Color.purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("Edit Installment Plan")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)

                        Text("Update payment schedule and details")
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

                            // Total amount is read-only for edit
                            FormField(label: "Total Amount", icon: "dollarsign.circle.fill") {
                                Text(viewModel.totalAmountString)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(AppTheme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }

                        // Payment Configuration
                        FormSection(title: "Payment Configuration") {
                            FormField(label: "Number of Payments", icon: "number.circle.fill") {
                                Stepper("\(viewModel.numberOfPayments) payments", value: $viewModel.numberOfPayments, in: 2...60)
                                    .font(.system(size: 16, weight: .medium))
                            }

                            // Calculated monthly payment
                            if viewModel.totalAmount > 0 {
                                HStack {
                                    Label("Per Payment", systemImage: "calendar.circle.fill")
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
                        }

                        // Payment Cycle
                        FormSection(title: "Payment Cycle") {
                            // Cycle Type Picker
                            FormField(label: "Cycle Type", icon: "arrow.triangle.2.circlepath") {
                                Picker("Cycle Type", selection: $viewModel.paymentCycleType) {
                                    ForEach(PaymentCycleType.allCases) { type in
                                        Label(type.displayName, systemImage: type.icon).tag(type)
                                    }
                                }
                                .pickerStyle(.menu)
                            }

                            // Description
                            Text(viewModel.paymentCycleType.description)
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textSecondary)

                            Divider()

                            // Type-specific configuration
                            switch viewModel.paymentCycleType {
                            case .monthlyFixed:
                                FormField(label: "Billing Day", icon: "calendar") {
                                    Picker("Billing Day", selection: $viewModel.billingDay) {
                                        ForEach(1...28, id: \.self) { day in
                                            Text("\(day)").tag(Int16(day))
                                        }
                                        Text("Last day of month").tag(Int16(0))
                                    }
                                    .pickerStyle(.menu)
                                }

                            case .weekly:
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "info.circle.fill")
                                        Text("Weekly Payments")
                                    }
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.blue)

                                    Text("Payment due every 7 days from start date")
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                                .padding(8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)

                            case .biweekly:
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "info.circle.fill")
                                        Text("Bi-Weekly Payments")
                                    }
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.blue)

                                    Text("Payment due every 14 days from start date")
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                                .padding(8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)

                            case .rolling:
                                FormField(label: "Custom Cycle Duration (days)", icon: "clock") {
                                    TextField("Enter number of days", text: $viewModel.customRollingDaysString)
                                        .keyboardType(.numberPad)
                                        .textFieldStyle(.roundedBorder)
                                }

                                Text("Enter any number between 1-365 days")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.textTertiary)
                                    .italic()

                            case .consolidated:
                                Toggle(isOn: $viewModel.useAccountBillingDates) {
                                    Label("Use account billing dates", systemImage: "creditcard")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .toggleStyle(SwitchToggleStyle(tint: .blue))

                                if viewModel.useAccountBillingDates {
                                    if let account = viewModel.selectedAccount {
                                        HStack {
                                            Text("Billing Day:")
                                                .font(.system(size: 14))
                                                .foregroundColor(AppTheme.textSecondary)
                                            Spacer()
                                            Text("\(account.billingDate)")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(AppTheme.textPrimary)
                                        }
                                        HStack {
                                            Text("Due Day:")
                                                .font(.system(size: 14))
                                                .foregroundColor(AppTheme.textSecondary)
                                            Spacer()
                                            Text("\(account.dueDate)")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(AppTheme.textPrimary)
                                        }
                                    }
                                } else {
                                    FormField(label: "Billing Day", icon: "calendar") {
                                        Picker("Billing Day", selection: $viewModel.customBillingDay) {
                                            ForEach(1...28, id: \.self) { day in
                                                Text("\(day)").tag(Int16(day))
                                            }
                                        }
                                        .pickerStyle(.menu)
                                    }

                                    FormField(label: "Due Day", icon: "calendar.badge.exclamationmark") {
                                        Picker("Due Day", selection: $viewModel.customDueDay) {
                                            ForEach(1...28, id: \.self) { day in
                                                Text("\(day)").tag(Int16(day))
                                            }
                                        }
                                        .pickerStyle(.menu)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "info.circle.fill")
                                        Text("Consolidated Billing")
                                    }
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.blue)

                                    Text("Changes will apply to remaining payments")
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                                .padding(8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }
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

                                if viewModel.totalAmount > 0 && viewModel.annualInterestRate > 0 {
                                    VStack(spacing: 8) {
                                        Divider()

                                        HStack {
                                            Text("Principal Amount")
                                                .font(.system(size: 13))
                                                .foregroundColor(AppTheme.textSecondary)
                                            Spacer()
                                            Text(viewModel.totalAmountString)
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
                Button("Save") {
                    Task {
                        await viewModel.updateInstallmentPlan()
                        if viewModel.loadingState == .loaded {
                            dismiss()
                        }
                    }
                }
                .disabled(!viewModel.isValid)
                .fontWeight(.bold)
            }
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

// MARK: - Supporting Views (reused from AddInstallmentPlanView)

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

#Preview {
    let container = PersistenceController.preview.container
    let context = container.viewContext

    let account = Account(context: context)
    account.name = "Credit Card"
    account.currency = "MYR"

    let plan = RecurringTransaction(context: context)
    plan.id = UUID()
    plan.title = "iPhone 15 Pro"
    plan.merchant = "Apple Store"
    plan.amount = 100
    plan.totalAmount = 1200
    plan.isInstallment = true
    plan.isActive = true
    plan.occurrenceLimit = 12
    plan.occurrencesCount = 3
    plan.account = account
    plan.paymentCycleType = "monthlyFixed"
    plan.monthlyDay = 15

    return EditInstallmentPlanView(plan: plan)
        .environmentObject(DependencyContainer(persistenceController: .preview))
}
