//
//  SavingsGoalSheet.swift
//  OneTap
//
//  Sheet for setting/editing savings goal for an account
//

import SwiftUI
@preconcurrency internal import CoreData

struct SavingsGoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var account: Account

    let repository: SavingsGoalRepositoryProtocol

    // Form state
    @State private var name: String = ""
    @State private var targetAmountString: String = ""
    @State private var hasTargetDate: Bool = false
    @State private var targetDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

    @State private var errorMessage: String?
    @State private var showingDeleteConfirmation = false

    private var existingGoal: SavingsGoal? {
        account.savingsGoal
    }

    private var isEditing: Bool {
        existingGoal != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Goal Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("GOAL NAME")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppTheme.textSecondary)

                            TextField("e.g., Emergency Fund", text: $name)
                                .font(.system(size: 16))
                                .padding()
                                .background(AppTheme.cardBackground)
                                .cornerRadius(12)
                        }

                        // Target Amount
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TARGET AMOUNT")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppTheme.textSecondary)

                            HStack {
                                Text(currencySymbol)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(AppTheme.textSecondary)

                                TextField("10,000", text: $targetAmountString)
                                    .font(.system(size: 24, weight: .bold))
                                    .keyboardType(.decimalPad)
                            }
                            .padding()
                            .background(AppTheme.cardBackground)
                            .cornerRadius(12)
                        }

                        // Target Date (Optional)
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(isOn: $hasTargetDate) {
                                Text("SET TARGET DATE")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            .tint(AppTheme.accent)

                            if hasTargetDate {
                                DatePicker(
                                    "Target Date",
                                    selection: $targetDate,
                                    in: Date()...,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.graphical)
                                .padding()
                                .background(AppTheme.cardBackground)
                                .cornerRadius(12)
                            }
                        }

                        // Current Progress (if editing)
                        if let goal = existingGoal {
                            VStack(spacing: 12) {
                                Divider()

                                HStack {
                                    Text("Current Progress")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(AppTheme.textSecondary)

                                    Spacer()

                                    Text("\(goal.progressPercentage)%")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(progressColor(for: goal.progress))
                                }

                                // Progress bar
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(AppTheme.secondaryBackground)
                                            .frame(height: 8)

                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(progressColor(for: goal.progress))
                                            .frame(width: geometry.size.width * goal.progressClamped, height: 8)
                                    }
                                }
                                .frame(height: 8)

                                HStack {
                                    Text(formatCurrency(account.balance))
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.textSecondary)

                                    Spacer()

                                    Text(goal.formattedTargetAmount)
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                            }
                            .padding()
                            .background(AppTheme.cardBackground)
                            .cornerRadius(12)
                        }

                        // Delete Button (if editing)
                        if isEditing {
                            Button(role: .destructive) {
                                showingDeleteConfirmation = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Remove Goal")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppTheme.expense)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppTheme.expense.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(isEditing ? "Edit Goal" : "Set Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveGoal()
                    }
                    .disabled(!isValid)
                }
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
            .alert("Remove Goal?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    deleteGoal()
                }
            } message: {
                Text("This will remove the savings goal from this account.")
            }
            .onAppear {
                loadExistingGoal()
            }
        }
    }

    // MARK: - Validation

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Double(targetAmountString.replacingOccurrences(of: ",", with: "")) ?? 0) > 0
    }

    // MARK: - Actions

    private func loadExistingGoal() {
        guard let goal = existingGoal else { return }
        name = goal.name ?? ""
        targetAmountString = String(format: "%.0f", goal.targetAmount)
        hasTargetDate = goal.targetDate != nil
        if let date = goal.targetDate {
            targetDate = date
        }
    }

    private func saveGoal() {
        let amount = Double(targetAmountString.replacingOccurrences(of: ",", with: "")) ?? 0

        do {
            if let existingGoal = existingGoal {
                // Update existing
                let dto = SavingsGoalUpdateData(
                    name: name.trimmingCharacters(in: .whitespaces),
                    targetAmount: amount,
                    targetDate: hasTargetDate ? targetDate : nil
                )
                try repository.update(existingGoal, with: dto)
            } else {
                // Create new
                let dto = SavingsGoalCreateData(
                    name: name.trimmingCharacters(in: .whitespaces),
                    targetAmount: amount,
                    targetDate: hasTargetDate ? targetDate : nil,
                    accountID: account.objectID
                )
                _ = try repository.create(dto)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteGoal() {
        guard let goal = existingGoal else { return }
        do {
            try repository.delete(goal)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private var currencySymbol: String {
        let code = account.currency ?? SettingsManager.shared.currencyCode
        let locale = Locale(identifier: Locale.identifier(fromComponents: [NSLocale.Key.currencyCode.rawValue: code]))
        return locale.currencySymbol ?? "$"
    }

    private func formatCurrency(_ amount: Double) -> String {
        let code = account.currency ?? SettingsManager.shared.currencyCode
        return Formatters.currencyFormatter(for: code).string(from: NSNumber(value: amount)) ?? "$0"
    }

    private func progressColor(for progress: Double) -> Color {
        if progress >= 1.0 {
            return AppTheme.income
        } else if progress >= 0.7 {
            return .orange
        } else {
            return AppTheme.accent
        }
    }
}
