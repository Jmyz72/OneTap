//
//  AdjustmentsSheet.swift
//  OneTap
//
//  Sheet for adding/editing transaction adjustments (tax, service charge, discount, rounding)
//

import SwiftUI

struct AdjustmentsSheet: View {
    @Binding var adjustments: [AdjustmentData]
    let currencyCode: String
    @Environment(\.dismiss) private var dismiss

    @State private var showingAddSheet = false
    @State private var editingAdjustment: AdjustmentData?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    if adjustments.isEmpty {
                        emptyState
                    } else {
                        adjustmentsList
                    }

                    addButton
                }
            }
            .navigationTitle("Adjustments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddAdjustmentSheet(currencyCode: currencyCode) { newAdjustment in
                    adjustments.append(newAdjustment)
                }
            }
            .sheet(item: $editingAdjustment) { adjustment in
                EditAdjustmentSheet(
                    adjustment: adjustment,
                    currencyCode: currencyCode
                ) { updatedAdjustment in
                    if let index = adjustments.firstIndex(where: { $0.id == adjustment.id }) {
                        adjustments[index] = updatedAdjustment
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "plusminus.circle")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.textTertiary)

            Text("No Adjustments")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)

            Text("Add tax, service charge, discounts, or rounding adjustments")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    private var adjustmentsList: some View {
        List {
            ForEach(adjustments) { adjustment in
                adjustmentRow(adjustment)
                    .listRowBackground(AppTheme.cardBackground)
                    .listRowSeparator(.hidden)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingAdjustment = adjustment
                    }
            }
            .onDelete(perform: deleteAdjustments)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func adjustmentRow(_ adjustment: AdjustmentData) -> some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: adjustment.type.icon)
                .font(.system(size: 16))
                .foregroundColor(adjustment.type.color)
                .frame(width: 32, height: 32)
                .background(adjustment.type.color.opacity(0.15))
                .cornerRadius(8)

            // Label
            VStack(alignment: .leading, spacing: 2) {
                Text(adjustment.label ?? adjustment.type.displayName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)

                if let percentage = adjustment.percentage, percentage > 0 {
                    Text("\(Int(percentage))%")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            Spacer()

            // Amount
            Text(formattedAmount(adjustment))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(adjustment.type.isNegative ? Color(hex: "51CF66") : AppTheme.textPrimary)

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textTertiary)
        }
        .padding(.vertical, 8)
    }

    private var addButton: some View {
        Button {
            showingAddSheet = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                Text("Add Adjustment")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppTheme.accent)
            .cornerRadius(12)
        }
        .padding()
    }

    private func formattedAmount(_ adjustment: AdjustmentData) -> String {
        let prefix = adjustment.type.isNegative ? "-" : "+"
        let formatter = Formatters.currencyFormatter(for: currencyCode)
        let amountStr = formatter.string(from: NSNumber(value: adjustment.amount)) ?? "0"
        return "\(prefix)\(amountStr)"
    }

    private func deleteAdjustments(at offsets: IndexSet) {
        adjustments.remove(atOffsets: offsets)
    }
}

// MARK: - Add Adjustment Sheet

private struct AddAdjustmentSheet: View {
    let currencyCode: String
    let onAdd: (AdjustmentData) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: AdjustmentType = .tax
    @State private var amountString = ""
    @State private var label = ""
    @State private var percentageString = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Type Selection
                        typeSection

                        // Amount Input
                        amountSection

                        // Label Input
                        labelSection

                        // Percentage Input (optional)
                        percentageSection
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Add Adjustment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addAdjustment()
                    }
                    .fontWeight(.semibold)
                    .disabled(amountString.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Type")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .textCase(.uppercase)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(AdjustmentType.allCases, id: \.self) { type in
                        Button {
                            selectedType = type
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 14))
                                Text(type.displayName)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(selectedType == type ? type.color.opacity(0.2) : AppTheme.secondaryBackground)
                            .foregroundColor(selectedType == type ? type.color : AppTheme.textSecondary)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(selectedType == type ? type.color : Color.clear, lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Amount")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .textCase(.uppercase)

            HStack {
                Text(currencySymbol)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.textSecondary)

                TextField("0.00", text: $amountString)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding()
            .background(AppTheme.cardBackground)
            .cornerRadius(12)
        }
        .padding(.horizontal, 20)
    }

    private var labelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Label (Optional)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .textCase(.uppercase)

            TextField("e.g., SST 6%, Member Discount", text: $label)
                .font(.system(size: 16))
                .foregroundColor(AppTheme.textPrimary)
                .padding()
                .background(AppTheme.cardBackground)
                .cornerRadius(12)
        }
        .padding(.horizontal, 20)
    }

    private var percentageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Percentage (Optional)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .textCase(.uppercase)

            HStack {
                TextField("e.g., 6", text: $percentageString)
                    .keyboardType(.numberPad)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.textPrimary)

                Text("%")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
            }
            .padding()
            .background(AppTheme.cardBackground)
            .cornerRadius(12)
        }
        .padding(.horizontal, 20)
    }

    private var currencySymbol: String {
        let formatter = Formatters.currencyFormatter(for: currencyCode)
        return formatter.currencySymbol ?? "$"
    }

    private func addAdjustment() {
        guard let amount = Double(amountString), amount > 0 else { return }

        let percentage = Double(percentageString)

        let adjustment = AdjustmentData(
            type: selectedType,
            amount: amount,
            label: label.isEmpty ? nil : label,
            percentage: percentage
        )

        onAdd(adjustment)
        dismiss()
    }
}

// MARK: - Edit Adjustment Sheet

private struct EditAdjustmentSheet: View {
    let adjustment: AdjustmentData
    let currencyCode: String
    let onUpdate: (AdjustmentData) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: AdjustmentType
    @State private var amountString: String
    @State private var label: String
    @State private var percentageString: String

    init(adjustment: AdjustmentData, currencyCode: String, onUpdate: @escaping (AdjustmentData) -> Void) {
        self.adjustment = adjustment
        self.currencyCode = currencyCode
        self.onUpdate = onUpdate

        _selectedType = State(initialValue: adjustment.type)
        _amountString = State(initialValue: String(format: "%.2f", adjustment.amount))
        _label = State(initialValue: adjustment.label ?? "")
        _percentageString = State(initialValue: adjustment.percentage.map { String(Int($0)) } ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Type Selection
                        typeSection

                        // Amount Input
                        amountSection

                        // Label Input
                        labelSection

                        // Percentage Input (optional)
                        percentageSection
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Edit Adjustment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAdjustment()
                    }
                    .fontWeight(.semibold)
                    .disabled(amountString.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Type")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .textCase(.uppercase)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(AdjustmentType.allCases, id: \.self) { type in
                        Button {
                            selectedType = type
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 14))
                                Text(type.displayName)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(selectedType == type ? type.color.opacity(0.2) : AppTheme.secondaryBackground)
                            .foregroundColor(selectedType == type ? type.color : AppTheme.textSecondary)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(selectedType == type ? type.color : Color.clear, lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Amount")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .textCase(.uppercase)

            HStack {
                Text(currencySymbol)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.textSecondary)

                TextField("0.00", text: $amountString)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding()
            .background(AppTheme.cardBackground)
            .cornerRadius(12)
        }
        .padding(.horizontal, 20)
    }

    private var labelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Label (Optional)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .textCase(.uppercase)

            TextField("e.g., SST 6%, Member Discount", text: $label)
                .font(.system(size: 16))
                .foregroundColor(AppTheme.textPrimary)
                .padding()
                .background(AppTheme.cardBackground)
                .cornerRadius(12)
        }
        .padding(.horizontal, 20)
    }

    private var percentageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Percentage (Optional)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .textCase(.uppercase)

            HStack {
                TextField("e.g., 6", text: $percentageString)
                    .keyboardType(.numberPad)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.textPrimary)

                Text("%")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
            }
            .padding()
            .background(AppTheme.cardBackground)
            .cornerRadius(12)
        }
        .padding(.horizontal, 20)
    }

    private var currencySymbol: String {
        let formatter = Formatters.currencyFormatter(for: currencyCode)
        return formatter.currencySymbol ?? "$"
    }

    private func saveAdjustment() {
        guard let amount = Double(amountString), amount > 0 else { return }

        let percentage = Double(percentageString)

        var updatedAdjustment = adjustment
        updatedAdjustment.type = selectedType
        updatedAdjustment.amount = amount
        updatedAdjustment.label = label.isEmpty ? nil : label
        updatedAdjustment.percentage = percentage

        onUpdate(updatedAdjustment)
        dismiss()
    }
}

#Preview {
    AdjustmentsSheet(
        adjustments: .constant([
            AdjustmentData(type: .tax, amount: 0.95, label: "SST 6%", percentage: 6),
            AdjustmentData(type: .rounding, amount: 0.01, label: nil, percentage: nil)
        ]),
        currencyCode: "MYR"
    )
}
