//
//  AccountFormView.swift
//  OneTap
//
//  REFACTORED: Now uses AccountFormViewModel (MVVM pattern)
//

import SwiftUI
internal import CoreData

struct AccountFormView: View {
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.dismiss) private var dismiss

    // Optional binding to dismiss the parent sheet
    var rootIsPresented: Binding<Bool>?

    let template: AccountTemplate?
    let accountToEdit: Account?

    @State private var viewModel: AccountFormViewModel?

    let currencies = SettingsManager.shared.availableCurrencies
    let days = Array(1...31)

    init(template: AccountTemplate? = nil, accountToEdit: Account? = nil, rootIsPresented: Binding<Bool>? = nil) {
        self.rootIsPresented = rootIsPresented
        self.template = template
        self.accountToEdit = accountToEdit
    }

    var body: some View {
        Group {
            if let viewModel {
                Form {
                    detailsSection(viewModel: viewModel)
                    financialsSection(viewModel: viewModel)
                    cardInfoSection(viewModel: viewModel)
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
                .onChange(of: viewModel.type) { _, _ in
                    viewModel.updateIconForType()
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
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = container.makeAccountFormViewModel(account: accountToEdit, template: template)
            }
        }
    }

    @ViewBuilder
    private func detailsSection(viewModel: AccountFormViewModel) -> some View {
        Section(header: Text("Details")) {
            // Icon Preview
            HStack {
                Spacer()
                AccountIconView(iconName: viewModel.icon, color: viewModel.type.color, size: 40)
                Spacer()
            }
            .padding(.vertical, 8)

            TextField("Account Name", text: Binding(
                get: { viewModel.name },
                set: { viewModel.name = $0 }
            ))
            TextField("Institution (Optional)", text: Binding(
                get: { viewModel.institution },
                set: { viewModel.institution = $0 }
            ))
            Picker("Type", selection: Binding(
                get: { viewModel.type },
                set: { viewModel.type = $0 }
            )) {
                ForEach(AccountType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            Picker("Currency", selection: Binding(
                get: { viewModel.currency },
                set: { viewModel.currency = $0 }
            )) {
                ForEach(currencies, id: \.self) { code in
                    Text(code).tag(code)
                }
            }
        }
    }

    @ViewBuilder
    private func financialsSection(viewModel: AccountFormViewModel) -> some View {
        Section(header: Text("Financials")) {
            HStack {
                Text(viewModel.currency)
                    .foregroundStyle(.secondary)
                TextField("Current Balance", text: Binding(
                    get: { viewModel.balance },
                    set: { viewModel.balance = $0 }
                ))
                    .keyboardType(.decimalPad)
            }

            if viewModel.type == .creditCard || viewModel.type == .bnpl {
                HStack {
                    Text(viewModel.currency)
                        .foregroundStyle(.secondary)
                    TextField("Credit Limit", text: Binding(
                        get: { viewModel.creditLimit },
                        set: { viewModel.creditLimit = $0 }
                    ))
                        .keyboardType(.decimalPad)
                }

                Picker("Billing Cycle Date", selection: Binding(
                    get: { viewModel.billingDay },
                    set: { viewModel.billingDay = $0 }
                )) {
                    ForEach(days, id: \.self) { day in
                        Text("Day \(day)").tag(day)
                    }
                }

                Picker("Payment Due Date", selection: Binding(
                    get: { viewModel.dueDay },
                    set: { viewModel.dueDay = $0 }
                )) {
                    ForEach(days, id: \.self) { day in
                        Text("Day \(day)").tag(day)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cardInfoSection(viewModel: AccountFormViewModel) -> some View {
        Section(header: Text("Card Info")) {
            Toggle("Have Card?", isOn: Binding(
                get: { viewModel.hasCard },
                set: { viewModel.hasCard = $0 }
            ))

            if viewModel.hasCard {
                TextField("Last 4 Digits", text: Binding(
                    get: { viewModel.lastFourDigits },
                    set: { viewModel.lastFourDigits = $0 }
                ))
                    .keyboardType(.numberPad)
                    .onChange(of: viewModel.lastFourDigits) { oldValue, newValue in
                        if newValue.count > 4 {
                            viewModel.lastFourDigits = String(newValue.prefix(4))
                        }
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
