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

    var rootIsPresented: Binding<Bool>?
    let template: AccountTemplate?
    let accountToEdit: Account?

    @State private var viewModel: AccountFormViewModel?

    init(template: AccountTemplate? = nil, accountToEdit: Account? = nil, rootIsPresented: Binding<Bool>? = nil) {
        self.rootIsPresented = rootIsPresented
        self.template = template
        self.accountToEdit = accountToEdit
    }

    var body: some View {
        Group {
            if let viewModel {
                AccountFormContent(
                    viewModel: viewModel,
                    rootIsPresented: rootIsPresented,
                    dismiss: _dismiss
                )
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
}

struct AccountFormContent: View {
    @ObservedObject var viewModel: AccountFormViewModel
    var rootIsPresented: Binding<Bool>?
    @Environment(\.dismiss) var dismiss // This environment value is local to this view, but we can also pass the parent's if needed, or just use this one.

    let currencies = SettingsManager.shared.availableCurrencies
    let days = Array(1...31)

    var body: some View {
        Form {
            detailsSection
            financialsSection
            cardInfoSection
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
        .onChange(of: viewModel.loadingState) { _, newState in
            if newState == .loaded {
                if let rootIsPresented = rootIsPresented {
                    rootIsPresented.wrappedValue = false
                } else {
                    dismiss()
                }
            }
        }
    }

    @ViewBuilder
    private var detailsSection: some View {
        Section(header: Text("Details")) {
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
    }

    @ViewBuilder
    private var financialsSection: some View {
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
    }

    @ViewBuilder
    private var cardInfoSection: some View {
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
}

#Preview {
    NavigationStack {
        AccountFormView()
            .environmentObject(DependencyContainer(persistenceController: .preview))
    }
}
