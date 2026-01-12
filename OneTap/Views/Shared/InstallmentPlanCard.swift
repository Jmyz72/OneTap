//
//  InstallmentPlanCard.swift
//  OneTap
//
//  Reusable card component for displaying installment plan information
//

import SwiftUI

struct InstallmentPlanCard: View {
    let plan: RecurringTransaction

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Title and Status
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.title ?? "Installment Plan")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)

                    if let merchant = plan.merchant, !merchant.isEmpty {
                        Text(merchant)
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }

                Spacer()

                // Status badge
                statusBadge
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(plan.formattedProgress)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)

                    Spacer()

                    Text("\(Int(plan.progressPercentage * 100))%")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(progressColor)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 8)

                        // Progress
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [progressColor, progressColor.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * plan.progressPercentage, height: 8)
                    }
                }
                .frame(height: 8)
            }

            // Financial Details
            HStack(spacing: 16) {
                // Monthly payment
                VStack(alignment: .leading, spacing: 2) {
                    Text("Monthly")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textTertiary)

                    Text(formattedAmount(plan.amount))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                }

                Divider()
                    .frame(height: 30)

                // Remaining amount
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remaining")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textTertiary)

                    Text(formattedAmount(plan.remainingAmount))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color.orange)
                }

                Spacer()

                // Next payment date (if active)
                if plan.isActive, let nextDate = plan.nextRunDate {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Next Payment")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.textTertiary)

                        Text(formatDate(nextDate))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Computed Properties

    private var statusBadge: some View {
        Text(plan.statusText)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(statusColor)
            )
    }

    private var statusColor: Color {
        switch plan.statusColor {
        case "green": return .green
        case "blue": return .blue
        case "gray": return .gray
        default: return .blue
        }
    }

    private var progressColor: Color {
        let progress = plan.progressPercentage
        if progress >= 0.75 { return .green }
        if progress >= 0.5 { return .blue }
        if progress >= 0.25 { return .orange }
        return .red
    }

    // MARK: - Helper Methods

    private func formattedAmount(_ amount: Double) -> String {
        let code = plan.account?.currency ?? SettingsManager.shared.currencyCode
        let formatter = Formatters.currencyFormatter(for: code)
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

#Preview {
    VStack(spacing: 16) {
        // Active installment - 25% complete
        InstallmentPlanCard(plan: {
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

        // Almost complete installment - 83% complete
        InstallmentPlanCard(plan: {
            let container = PersistenceController.preview.container
            let context = container.viewContext

            let account = Account(context: context)
            account.name = "Credit Card"
            account.currency = "MYR"

            let plan = RecurringTransaction(context: context)
            plan.id = UUID()
            plan.title = "Laptop"
            plan.merchant = "Tech Store"
            plan.amount = 150
            plan.totalAmount = 1800
            plan.isInstallment = true
            plan.isActive = true
            plan.occurrenceLimit = 12
            plan.occurrencesCount = 10
            plan.nextRunDate = Date().addingTimeInterval(86400 * 15)
            plan.account = account

            return plan
        }())
    }
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}
