//
//  InstallmentPlansListView.swift
//  OneTap
//
//  View for managing installment plans in Settings
//

internal import CoreData
import SwiftUI

struct InstallmentPlansListView: View {
    @EnvironmentObject private var container: DependencyContainer
    @State private var viewModel: RecurringTransactionsListViewModel?

    var body: some View {
        Group {
            if let viewModel {
                InstallmentPlansContent(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = container.makeRecurringTransactionsListViewModel(showInstallments: true)
            }
        }
    }
}

private struct InstallmentPlansContent: View {
    @ObservedObject var viewModel: RecurringTransactionsListViewModel
    @State private var showingAddInstallment = false

    var body: some View {
        Group {
            if viewModel.isEmpty {
                ContentUnavailableView(
                    "No Installment Plans",
                    systemImage: "creditcard.fill",
                    description: Text("Installment plans for purchases will appear here.")
                )
            } else {
                List {
                    ForEach(viewModel.recurringTransactions, id: \.objectID) { recurring in
                        InstallmentPlanRow(recurring: recurring) {
                            viewModel.toggleActive(recurring)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.delete(recurring)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Installments")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddInstallment = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddInstallment) {
            AddInstallmentPlanView()
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
    }
}

private struct InstallmentPlanRow: View {
    @ObservedObject var recurring: RecurringTransaction
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((recurring.category?.colorView ?? .gray).opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: recurring.category?.iconName ?? "creditcard.fill")
                    .foregroundColor(recurring.category?.colorView ?? .orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(recurring.title ?? recurring.category?.name ?? "Installment")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)

                HStack(spacing: 4) {
                    Text(recurring.formattedProgress)
                    Text("•")
                    Text(recurring.formattedInstallmentDisplay)
                }
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatAmount(recurring.installmentTotalAmount))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)

                Toggle("", isOn: Binding(
                    get: { recurring.isActive },
                    set: { _ in onToggle() }
                ))
                .labelsHidden()
                .scaleEffect(0.8)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = recurring.account?.currency ?? "MYR"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

#Preview {
    NavigationStack {
        InstallmentPlansListView()
            .environmentObject(DependencyContainer(persistenceController: .preview))
    }
}
