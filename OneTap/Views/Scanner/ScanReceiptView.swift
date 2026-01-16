//
//  ScanReceiptView.swift
//  OneTap
//
//  Receipt scanning view with camera and photo library
//

import SwiftUI

struct ScanReceiptView: View {
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.dismiss) private var dismiss

    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var capturedImage: UIImage?
    @State private var showingOCRImport = false

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
                        Text("Receipt Scanner")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)

                        Text("Scan receipts and automatically extract transaction details")
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
                            title: "Smart Categorization",
                            description: "Automatically categorizes your expenses"
                        )

                        FeatureItem(
                            icon: "square.and.arrow.down",
                            title: "Save Time",
                            description: "No more manual entry of transactions"
                        )
                    }
                    .padding(.horizontal, 32)

                    Spacer()

                    // Scan Options
                    VStack(spacing: 16) {
                        // Take Photo Button
                        Button {
                            showingCamera = true
                        } label: {
                            HStack {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 18))
                                Text("Take Photo")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
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
                        }

                        // Choose from Library Button
                        Button {
                            showingPhotoLibrary = true
                        } label: {
                            HStack {
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 18))
                                Text("Choose from Library")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(AppTheme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.cardBackground)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppTheme.accent, lineWidth: 2)
                            )
                        }
                    }
                    .padding(.horizontal, 32)

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
            .sheet(isPresented: $showingCamera) {
                ImagePicker(image: $capturedImage, sourceType: .camera)
            }
            .sheet(isPresented: $showingPhotoLibrary) {
                ImagePicker(image: $capturedImage, sourceType: .photoLibrary)
            }
            .sheet(isPresented: $showingOCRImport) {
                if let image = capturedImage {
                    OCRImportView(screenshot: image)
                        .environmentObject(container)
                }
            }
            .onChange(of: capturedImage) { _, newImage in
                if newImage != nil {
                    showingOCRImport = true
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
