//
//  BudgetNumpadSheet.swift
//  OneTap
//
//  Bottom sheet with numpad for editing budget amounts
//

import SwiftUI

struct BudgetNumpadSheet: View {
    @ObservedObject var viewModel: BudgetViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Header with category info
                    if let context = viewModel.editContext {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(context.displayColor.opacity(0.15))
                                    .frame(width: 60, height: 60)

                                Image(systemName: context.displayIcon)
                                    .font(.system(size: 24))
                                    .foregroundColor(context.displayColor)
                            }

                            Text(context.displayName)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(AppTheme.textPrimary)

                            Text("Current spent: \(formatCurrency(context.currentSpent))")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .padding(.top, 20)
                    }

                    // Amount display
                    VStack(spacing: 8) {
                        Text(formattedAmount)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal)

                        // Minimum amount warning
                        if let message = viewModel.minimumAmountMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(message)
                                    .font(.system(size: 12))
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal)
                        }
                    }

                    Spacer()

                    // Numpad
                    BudgetKeypad(value: $viewModel.amountString)

                    // Action buttons
                    HStack(spacing: 16) {
                        Button {
                            viewModel.cancelEditing()
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(AppTheme.secondaryBackground)
                                .cornerRadius(12)
                        }

                        Button {
                            Task {
                                await viewModel.saveBudget()
                                dismiss()
                            }
                        } label: {
                            Text("Save")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(viewModel.canSaveBudget ? AppTheme.accent : AppTheme.accent.opacity(0.5))
                                .cornerRadius(12)
                        }
                        .disabled(!viewModel.canSaveBudget)
                    }
                    .padding(.horizontal)

                    // Delete button (only if editing existing budget)
                    if viewModel.editContext?.isEditing == true {
                        Button {
                            Task {
                                await viewModel.deleteBudget()
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Remove Budget")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.expense)
                        }
                        .padding(.bottom, 20)
                    } else {
                        Spacer().frame(height: 20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        viewModel.cancelEditing()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Formatting

    private var formattedAmount: String {
        let currencyCode = SettingsManager.shared.currencyCode
        guard let amount = Double(viewModel.amountString) else {
            return Formatters.currencyFormatter(for: currencyCode).string(from: 0) ?? "$0"
        }
        return Formatters.currencyFormatter(for: currencyCode).string(from: NSNumber(value: amount)) ?? "$0"
    }

    private func formatCurrency(_ amount: Double) -> String {
        let currencyCode = SettingsManager.shared.currencyCode
        return Formatters.currencyFormatter(for: currencyCode).string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Budget Keypad

private struct BudgetKeypad: View {
    @Binding var value: String

    private let buttons: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "⌫"]
    ]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(buttons, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(row, id: \.self) { button in
                        Button {
                            handleTap(button)
                        } label: {
                            Text(button)
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(AppTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                                .background(AppTheme.secondaryBackground)
                                .cornerRadius(12)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private func handleTap(_ button: String) {
        switch button {
        case "⌫":
            if !value.isEmpty && value != "0" {
                value.removeLast()
                if value.isEmpty {
                    value = "0"
                }
            }
        case ".":
            if !value.contains(".") {
                value += "."
            }
        default:
            if value == "0" {
                value = button
            } else {
                // Limit to reasonable length
                if value.count < 12 {
                    value += button
                }
            }
        }

        // Haptic feedback
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

#Preview {
    Text("Preview")
        .sheet(isPresented: .constant(true)) {
            BudgetNumpadSheet(viewModel: BudgetViewModel(
                budgetService: PreviewBudgetService(),
                budgetRepository: PreviewBudgetRepository()
            ))
        }
}

// MARK: - Preview Helpers

@MainActor
private class PreviewBudgetService: BudgetServiceProtocol {
    func getCategorySpendingSummaries(for month: Date) async throws -> [CategorySpendingSummary] { [] }
    func getSubCategorySpendingSummaries(for category: Category, in month: Date) async throws -> [SubCategorySpendingSummary] { [] }
    func saveBudget(amount: Double, for category: Category, subCategory: SubCategory?) async throws -> Budget {
        fatalError("Preview only")
    }
    func deleteBudget(_ budget: Budget) async throws {}
    func getMinimumAmount(for category: Category) async throws -> Double { 0 }
    func getEditContext(for category: Category, subCategory: SubCategory?, in month: Date) async throws -> BudgetEditContext {
        fatalError("Preview only")
    }
    func getMonthlyTotals(for month: Date) async throws -> (totalBudgeted: Double, totalSpent: Double) { (0, 0) }
}

private class PreviewBudgetRepository: BudgetRepositoryProtocol {
    func create(_ dto: BudgetCreateData) throws -> Budget { fatalError("Preview only") }
    func fetch(id: UUID) throws -> Budget { fatalError("Preview only") }
    func fetchAll() throws -> [Budget] { [] }
    func fetchActive() throws -> [Budget] { [] }
    func update(_ budget: Budget, with dto: BudgetUpdateData) throws {}
    func delete(_ budget: Budget) throws {}
    func save() throws {}
    func fetchBudget(for category: Category) throws -> Budget? { nil }
    func fetchBudget(for subCategory: SubCategory) throws -> Budget? { nil }
    func fetchSubCategoryBudgets(for category: Category) throws -> [Budget] { [] }
    func calculateSpent(for category: Category, subCategory: SubCategory?, in month: Date) throws -> Double { 0 }
    func calculateMinimumAmount(for category: Category) throws -> Double { 0 }
    func getCategorySpendingSummaries(for month: Date) throws -> [CategorySpendingSummary] { [] }
    func getSubCategorySpendingSummaries(for category: Category, in month: Date) throws -> [SubCategorySpendingSummary] { [] }
    var budgetsPublisher: AnyPublisher<[Budget], Never> {
        Just([]).eraseToAnyPublisher()
    }
}

import Combine
