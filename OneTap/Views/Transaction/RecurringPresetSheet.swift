//
//  RecurringPresetSheet.swift
//  OneTap
//
//  Quick preset options for recurring transactions
//

import SwiftUI

struct RecurringPresetSheet: View {
    @ObservedObject var viewModel: AddTransactionViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Current Selection (if already recurring)
                        if viewModel.isRecurring {
                            currentSelectionCard
                        }

                        // Quick Presets Section
                        quickPresetsSection

                        Divider()
                            .padding(.horizontal)

                        // Custom Configuration Button
                        customConfigButton

                        // Remove Recurring (if already set)
                        if viewModel.isRecurring {
                            removeRecurringButton
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Make Recurring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }

    // MARK: - Current Selection Card

    private var currentSelectionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppTheme.income)
                Text("Current Setup")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)
                    .textCase(.uppercase)
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recurringDescription)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)

                    Text("Starts: \(Formatters.date.string(from: viewModel.transactionDate))")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                NavigationLink(destination: RecurringConfigSheet(viewModel: viewModel)) {
                    Text("Edit")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.accent)
                }
            }
            .padding()
            .background(AppTheme.secondaryBackground)
            .cornerRadius(12)
        }
    }

    private var recurringDescription: String {
        let intervalText = viewModel.interval > 1 ? "\(viewModel.interval) " : ""
        let freqText = viewModel.frequency.lowercased()
        return "Every \(intervalText)\(freqText)"
    }

    // MARK: - Quick Presets Section

    private var quickPresetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Setup")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .textCase(.uppercase)

            VStack(spacing: 12) {
                PresetButton(
                    title: "Every Week",
                    subtitle: "Repeats weekly on \(currentWeekday)",
                    icon: "calendar",
                    isSelected: viewModel.isRecurring && viewModel.frequency == "Weekly" && viewModel.interval == 1
                ) {
                    setWeeklyPreset()
                }

                PresetButton(
                    title: "Every 2 Weeks",
                    subtitle: "Repeats bi-weekly on \(currentWeekday)",
                    icon: "calendar",
                    isSelected: viewModel.isRecurring && viewModel.frequency == "Weekly" && viewModel.interval == 2
                ) {
                    setBiWeeklyPreset()
                }

                PresetButton(
                    title: "Every Month",
                    subtitle: "Repeats monthly on day \(currentDay)",
                    icon: "calendar",
                    isSelected: viewModel.isRecurring && viewModel.frequency == "Monthly" && viewModel.interval == 1
                ) {
                    setMonthlyPreset()
                }

                PresetButton(
                    title: "Every Year",
                    subtitle: "Repeats annually on \(currentMonthDay)",
                    icon: "calendar",
                    isSelected: viewModel.isRecurring && viewModel.frequency == "Yearly" && viewModel.interval == 1
                ) {
                    setYearlyPreset()
                }
            }
        }
    }

    // MARK: - Custom Config Button

    private var customConfigButton: some View {
        NavigationLink(destination: RecurringConfigSheet(viewModel: viewModel)) {
            HStack {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Custom Configuration")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)

                    Text("Advanced settings and schedules")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.textTertiary)
            }
            .padding()
            .background(AppTheme.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Remove Recurring Button

    private var removeRecurringButton: some View {
        Button(role: .destructive) {
            viewModel.isRecurring = false
            viewModel.frequency = "Monthly"
            viewModel.interval = 1
            viewModel.hasEndDate = false
            viewModel.hasOccurrenceLimit = false
            viewModel.selectedWeekdays = []
            dismiss()
        } label: {
            HStack {
                Image(systemName: "xmark.circle.fill")
                Text("Remove Recurring")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppTheme.expense)
            .cornerRadius(12)
        }
    }

    // MARK: - Preset Actions

    private func setWeeklyPreset() {
        viewModel.frequency = "Weekly"
        viewModel.interval = 1
        viewModel.isRecurring = true

        // Set to current weekday
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: viewModel.transactionDate)
        viewModel.selectedWeekdays = [weekday]

        // Clear end date and occurrence limit
        viewModel.hasEndDate = false
        viewModel.hasOccurrenceLimit = false

        dismiss()
    }

    private func setBiWeeklyPreset() {
        viewModel.frequency = "Weekly"
        viewModel.interval = 2
        viewModel.isRecurring = true

        // Set to current weekday
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: viewModel.transactionDate)
        viewModel.selectedWeekdays = [weekday]

        viewModel.hasEndDate = false
        viewModel.hasOccurrenceLimit = false

        dismiss()
    }

    private func setMonthlyPreset() {
        viewModel.frequency = "Monthly"
        viewModel.interval = 1
        viewModel.isRecurring = true

        // Set to current day of month
        let calendar = Calendar.current
        let day = calendar.component(.day, from: viewModel.transactionDate)
        viewModel.selectedMonthDay = day

        viewModel.hasEndDate = false
        viewModel.hasOccurrenceLimit = false

        dismiss()
    }

    private func setYearlyPreset() {
        viewModel.frequency = "Yearly"
        viewModel.interval = 1
        viewModel.isRecurring = true

        viewModel.hasEndDate = false
        viewModel.hasOccurrenceLimit = false

        dismiss()
    }

    // MARK: - Date Formatting Helpers

    private var currentWeekday: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: viewModel.transactionDate)
    }

    private var currentDay: String {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: viewModel.transactionDate)
        return "\(day)"
    }

    private var currentMonthDay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: viewModel.transactionDate)
    }
}

// MARK: - Preset Button Component

private struct PresetButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? AppTheme.accent : AppTheme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(isSelected ? AppTheme.accent.opacity(0.15) : AppTheme.secondaryBackground)
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.accent)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(AppTheme.textTertiary)
                }
            }
            .padding()
            .background(isSelected ? AppTheme.accent.opacity(0.05) : AppTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppTheme.accent : Color.clear, lineWidth: 1.5)
            )
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @StateObject private var container = DependencyContainer(persistenceController: .preview)
        @State private var viewModel: AddTransactionViewModel?

        var body: some View {
            Group {
                if let viewModel {
                    RecurringPresetSheet(viewModel: viewModel)
                } else {
                    ProgressView()
                        .onAppear {
                            viewModel = container.makeAddTransactionViewModel()
                        }
                }
            }
        }
    }

    return PreviewWrapper()
}
