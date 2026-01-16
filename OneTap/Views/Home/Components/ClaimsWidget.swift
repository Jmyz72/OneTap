//
//  ClaimsWidget.swift
//  OneTap
//
//  Widget for displaying pending claims on Home dashboard
//

import SwiftUI

struct ClaimsWidget: View {
    let pendingClaims: [Claim]
    let onTap: () -> Void

    private var totalAmount: Double {
        pendingClaims.reduce(0.0) { $0 + $1.amount }
    }

    private var formattedTotal: String {
        let formatter = Formatters.currencyFormatter(for: SettingsManager.shared.currencyCode)
        return formatter.string(from: NSNumber(value: totalAmount)) ?? "$0"
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 12) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(AppTheme.accent.opacity(0.2))
                                .frame(width: 44, height: 44)

                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(AppTheme.accent)
                        }

                        // Info
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pending Claims")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AppTheme.textPrimary)

                            Text("\(pendingClaims.count) claim\(pendingClaims.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Amount
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formattedTotal)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.textPrimary)

                        Text("to reimburse")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .background(AppTheme.cardBackground)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}
