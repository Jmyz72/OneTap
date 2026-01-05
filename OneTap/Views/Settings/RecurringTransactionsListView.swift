//
//  RecurringTransactionsListView.swift
//  OneTap
//
//  View for managing recurring transactions in Settings
//

import SwiftUI

struct RecurringTransactionsListView: View {
    @EnvironmentObject private var container: DependencyContainer
    @State private var viewModel: RecurringTransactionsListViewModel?

    var body: some View {
        Group {
            if let viewModel {
                RecurringTransactionsContent(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = container.makeRecurringTransactionsListViewModel()
            }
        }
    }
}

private struct RecurringTransactionsContent: View {
    @ObservedObject var viewModel: RecurringTransactionsListViewModel
    @State private var showingAddRecurring = false

    var body: some View {
        Group {
            if viewModel.isEmpty {
                ContentUnavailableView(
                    "No Recurring Transactions",
                    systemImage: "repeat",
                    description: Text("Transactions you set to repeat will appear here.")
                )
            } else {
                List {
                    ForEach(viewModel.recurringTransactions, id: \.objectID) { recurring in
                        NavigationLink {
                            EditRecurringTransactionView(recurring: recurring)
                        } label: {
                            RecurringTransactionRow(recurring: recurring) {
                                viewModel.toggleActive(recurring)
                            }
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
        .navigationTitle("Recurring")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddRecurring = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddRecurring) {
            NavigationStack {
                AddRecurringTransactionView()
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
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
}

private struct RecurringTransactionRow: View {
    @ObservedObject var recurring: RecurringTransaction
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((recurring.category?.colorView ?? .gray).opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: recurring.category?.iconName ?? "questionmark")
                    .foregroundColor(recurring.category?.colorView ?? .gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recurring.title ?? recurring.category?.name ?? "Transaction")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
                
                HStack(spacing: 4) {
                    Text(recurring.frequency ?? "Monthly")
                    Text("•")
                    Text("Next: \(Formatters.shortDate.string(from: recurring.nextRunDate ?? Date()))")
                }
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatAmount(recurring.amount))
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
        RecurringTransactionsListView()
            .environmentObject(DependencyContainer(persistenceController: .preview))
    }
}
