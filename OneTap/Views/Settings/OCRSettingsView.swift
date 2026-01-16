//
//  OCRSettingsView.swift
//  OneTap
//
//  Settings screen for OCR screenshot import feature
//

import SwiftUI

struct OCRSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingInstructions = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Screenshot Import", systemImage: "camera.viewfinder")
                            .font(.headline)

                        Text("Quickly import transactions by taking screenshots with Back Tap gesture")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    Button(action: openShortcutsApp) {
                        HStack {
                            Image(systemName: "plus.app")
                                .foregroundColor(.white)
                                .font(.title3)
                                .frame(width: 32, height: 32)
                                .background(AppTheme.accent)
                                .cornerRadius(8)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Add to Shortcuts")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppTheme.textPrimary)

                                Text("Open Shortcuts app to configure")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "arrow.right")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Setup")
                }

                Section {
                    Button(action: { showingInstructions = true }) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(AppTheme.accent)

                            Text("View Setup Instructions")
                                .foregroundColor(AppTheme.textPrimary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Help")
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        FeatureRow(
                            icon: "camera.viewfinder",
                            title: "Payment Receipts",
                            description: "QR payment confirmations"
                        )

                        FeatureRow(
                            icon: "doc.text",
                            title: "Store Receipts",
                            description: "Itemized purchase receipts"
                        )

                        FeatureRow(
                            icon: "creditcard",
                            title: "Credit Card Statements",
                            description: "Transaction history screenshots"
                        )
                    }
                } header: {
                    Text("Supported Screenshots")
                }
            }
            .navigationTitle("Screenshot Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingInstructions) {
                SetupInstructionsView()
            }
        }
    }

    // MARK: - Actions

    private func openShortcutsApp() {
        // Open Shortcuts app
        // The shortcut is automatically available thanks to AppShortcuts registration
        if let url = URL(string: "shortcuts://") {
            UIApplication.shared.open(url)
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct SetupInstructionsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 60))
                            .foregroundColor(AppTheme.accent)

                        Text("Back Tap Setup")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Configure double-tap gesture to import transactions")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top)

                    // Step 1
                    InstructionStep(
                        number: 1,
                        title: "Open Shortcuts App",
                        description: "Tap the 'Add to Shortcuts' button above to open the Shortcuts app. You'll see 'Import Transaction from Screenshot' shortcut available.",
                        icon: "plus.app.fill"
                    )

                    // Step 2
                    InstructionStep(
                        number: 2,
                        title: "Configure Back Tap",
                        description: "Open iOS Settings → Accessibility → Touch → Back Tap → Double Tap",
                        icon: "gearshape.fill"
                    )

                    // Step 3
                    InstructionStep(
                        number: 3,
                        title: "Select the Shortcut",
                        description: "Scroll down and select 'Import Transaction from Screenshot' from the list",
                        icon: "checkmark.circle.fill"
                    )

                    // Step 4
                    InstructionStep(
                        number: 4,
                        title: "Start Using",
                        description: "Double-tap the back of your phone when viewing a receipt to import it",
                        icon: "sparkles"
                    )

                    // Tips
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tips for Best Results")
                            .font(.headline)

                        TipRow(icon: "checkmark", text: "Ensure text is clear and readable")
                        TipRow(icon: "checkmark", text: "Make sure amount and merchant are visible")
                        TipRow(icon: "checkmark", text: "Works best with English and Malay text")
                        TipRow(icon: "checkmark", text: "Use good lighting for physical receipts")
                    }
                    .padding()
                    .background(AppTheme.cardBackground)
                    .cornerRadius(12)
                }
                .padding()
            }
            .background(AppTheme.background)
            .navigationTitle("Setup Instructions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct InstructionStep: View {
    let number: Int
    let title: String
    let description: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Number badge
            ZStack {
                Circle()
                    .fill(AppTheme.accent)
                    .frame(width: 32, height: 32)

                Text("\(number)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundColor(AppTheme.accent)

                    Text(title)
                        .font(.headline)
                }

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .font(.caption)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    OCRSettingsView()
}
