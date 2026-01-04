//
//  ScanReceiptView.swift
//  OneTap
//
//  AI-powered receipt scanning view
//

import SwiftUI

struct ScanReceiptView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer()

                    // Camera Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        AppTheme.accent.opacity(0.2),
                                        AppTheme.accent.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 140, height: 140)

                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 60))
                            .foregroundColor(AppTheme.accent)
                    }

                    VStack(spacing: 12) {
                        Text("AI Receipt Scanner")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)

                        Text("Scan receipts and automatically extract transaction details with AI")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }

                    VStack(spacing: 16) {
                        FeatureItem(
                            icon: "doc.text.viewfinder",
                            title: "Smart Recognition",
                            description: "Automatically detect merchant, amount, and date"
                        )

                        FeatureItem(
                            icon: "sparkles",
                            title: "AI-Powered",
                            description: "Advanced AI categorizes your expenses"
                        )

                        FeatureItem(
                            icon: "square.and.arrow.down",
                            title: "Save Time",
                            description: "No more manual entry of transactions"
                        )
                    }
                    .padding(.horizontal, 32)

                    Spacer()

                    // Coming Soon Badge
                    Text("Coming Soon")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.accent, AppTheme.accent.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: AppTheme.accent.opacity(0.3), radius: 12, x: 0, y: 6)

                    Spacer()
                }
            }
            .navigationTitle("Scan Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct FeatureItem: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(AppTheme.accent)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)

                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()
        }
    }
}

#Preview {
    ScanReceiptView()
}
