//
//  AccountFormView.swift
//  OneTap
//
//  REFACTORED: Now uses AccountFormViewModel (MVVM pattern)
//

import SwiftUI
import CoreData

struct AccountFormView: View {
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.dismiss) private var dismiss

    // Optional binding to dismiss the parent sheet
    var rootIsPresented: Binding<Bool>?

    @StateObject private var viewModel: AccountFormViewModel

    let currencies = SettingsManager.shared.availableCurrencies
    let days = Array(1...31)

    init(template: AccountTemplate? = nil, accountToEdit: Account? = nil, rootIsPresented: Binding<Bool>? = nil) {
        self.rootIsPresented = rootIsPresented
        // Create temporary container and ViewModel
        let tempContainer = DependencyContainer()
        _viewModel = StateObject(wrappedValue: tempContainer.makeAccountFormViewModel(account: accountToEdit, template: template))
    }

    var body: some View {
        Form {
            Section(header: Text("Details")) {
                // Icon Preview
                HStack {
                    Spacer()
                    AccountIconView(iconName: viewModel.icon, color: viewModel.type.color, size: 40)
                    Spacer()
                }
                .padding(.vertical, 8)

                TextField("Account Name", text: $viewModel.name)
                TextField("Institution (Optional)", text: $viewModel.institution)
                Picker("Type", selection: $viewModel.type) {
                    ForEach(AccountType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                Picker("Currency", selection: $viewModel.currency) {
                    ForEach(currencies, id: \.self) { code in
                        Text(code).tag(code)
                    }
                }
            }

            Section(header: Text("Financials")) {
                HStack {
                    Text(viewModel.currency)
                        .foregroundStyle(.secondary)
                    TextField("Current Balance", text: $viewModel.balance)
                        .keyboardType(.decimalPad)
                }

                if viewModel.type == .creditCard || viewModel.type == .bnpl {
                    HStack {
                        Text(viewModel.currency)
                            .foregroundStyle(.secondary)
                        TextField("Credit Limit", text: $viewModel.creditLimit)
                            .keyboardType(.decimalPad)
                    }

                    Picker("Billing Cycle Date", selection: $viewModel.billingDay) {
                        ForEach(days, id: \.self) { day in
                            Text("Day \(day)").tag(day)
                        }
                    }

                    Picker("Payment Due Date", selection: $viewModel.dueDay) {
                        ForEach(days, id: \.self) { day in
                            Text("Day \(day)").tag(day)
                        }
                    }
                }
            }

            Section(header: Text("Card Info")) {
                Toggle("Have Card?", isOn: $viewModel.hasCard)

                if viewModel.hasCard {
                    TextField("Last 4 Digits", text: $viewModel.lastFourDigits)
                        .keyboardType(.numberPad)
                        .onChange(of: viewModel.lastFourDigits) { oldValue, newValue in
                            if newValue.count > 4 {
                                viewModel.lastFourDigits = String(newValue.prefix(4))
                            }
                        }
                }
            }
        }
        .navigationTitle(viewModel.isEditing ? "Edit Account" : (viewModel.template != nil ? "Add \(viewModel.template!.name)" : "Add Account"))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        await viewModel.saveAccount()
                    }
                }
                .disabled(!viewModel.isValid || viewModel.loadingState.isLoading)
            }
        }
        .onChange(of: viewModel.type) { _, newType in
            viewModel.typeChanged(to: newType)
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
                // If root binding is provided (Add Account flow), dismiss parent sheet
                if let rootIsPresented = rootIsPresented {
                    rootIsPresented.wrappedValue = false
                } else {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AccountFormView()
            .environmentObject(DependencyContainer(persistenceController: .preview))
    }
}
