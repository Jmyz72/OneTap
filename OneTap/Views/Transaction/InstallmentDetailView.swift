//
//  InstallmentDetailView.swift
//  OneTap
//
//  Detail view for installment plans with management actions
//

import SwiftUI

struct InstallmentDetailView: View {
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.dismiss) private var dismiss

    let plan: RecurringTransaction

    @State private var viewModel: InstallmentDetailViewModel?
    @State private var showEarlyPayoffAlert = false
    @State private var showCancelAlert = false
    @State private var showCancelOptions = false

    var body: some View {
        Group {
            if let viewModel {
                ScrollView {
                    VStack(spacing: 24) {
                        // Plan Card
                        InstallmentPlanCard(plan: plan)
                            .padding(.horizontal)

                        // Payment History
                        if !viewModel.relatedTransactions.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Payment History")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(AppTheme.textPrimary)
                                    .padding(.horizontal)

                                VStack(spacing: 0) {
                                    ForEach(viewModel.relatedTransactions, id: \.id) { transaction in
                                        VStack(spacing: 0) {
                                            TransactionRow(transaction: transaction)
                                            if transaction != viewModel.relatedTransactions.last {
                                                Divider()
                                                    .padding(.leading, 80)
                                            }
                                        }
                                    }
                                }
                                .background(AppTheme.card)
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                        }

                        // Actions (only for active plans)
                        if plan.isActive {
                            VStack(spacing: 12) {
                                // Early Payoff Button
                                Button {
                                    showEarlyPayoffAlert = true
                                } label: {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18, weight: .semibold))
                                        Text("Pay Off Early")
                                            .font(.system(size: 16, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.green, Color.green.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(12)
                                }

                                // Cancel Plan Button
                                Button {
                                    showCancelOptions = true
                                } label: {
                                    HStack {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 18, weight: .semibold))
                                        Text("Cancel Plan")
                                            .font(.system(size: 16, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.red, Color.red.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                .navigationTitle(plan.title ?? "Installment Plan")
                .navigationBarTitleDisplayMode(.inline)
                .alert("Pay Off Early", isPresented: $showEarlyPayoffAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("Pay Off") {
                        Task {
                            await viewModel.payOffEarly()
                        }
                    }
                } message: {
                    let remaining = formattedAmount(plan.remainingAmount)
                    Text("Pay off the remaining balance of \(remaining) now? This will complete the installment plan.")
                }
                .confirmationDialog("Cancel Installment Plan", isPresented: $showCancelOptions, titleVisibility: .visible) {
                    Button("Cancel Without Refund", role: .destructive) {
                        Task {
                            await viewModel.cancelPlan(refundAmount: 0)
                        }
                    }
                    Button("Cancel With Full Refund") {
                        Task {
                            await viewModel.cancelPlan(refundAmount: nil)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Choose how to cancel this installment plan:")
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
                .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
                    if shouldDismiss {
                        dismiss()
                    }
                }
            } else {
                ProgressView()
                    .onAppear {
                        if viewModel == nil {
                            viewModel = container.makeInstallmentDetailViewModel(plan: plan)
                        }
                    }
            }
        }
    }

    // MARK: - Helper Methods

    private func formattedAmount(_ amount: Double) -> String {
        let code = plan.account?.currency ?? SettingsManager.shared.currencyCode
        let formatter = Formatters.currencyFormatter(for: code)
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

#Preview {
    NavigationStack {
        InstallmentDetailView(plan: {
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
            plan.nextRunDate = Date().addingTimeInterval(86400 * 5)
            plan.account = account

            return plan
        }())
    }
    .environmentObject(DependencyContainer(persistenceController: .preview))
}
