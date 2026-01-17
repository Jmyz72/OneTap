//
//  ScanReceiptView.swift
//  OneTap
//
//  Receipt history with quick scan access
//

import SwiftUI

struct ScanReceiptView: View {
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: ScanReceiptViewModel?
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var capturedImage: UIImage?
    @State private var showingOCRImport = false

    var body: some View {
        Group {
            if let viewModel {
                contentView(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = container.makeScanReceiptViewModel()
                viewModel?.loadRecentTransactions()
            }
        }
    }

    @ViewBuilder
    private func contentView(viewModel: ScanReceiptViewModel) -> some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                // Main content
                if viewModel.recentTransactions.isEmpty {
                    emptyStateView
                } else {
                    recentTransactionsList(viewModel: viewModel)
                }

                // Floating action button for quick scan
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        quickScanButton
                    }
                }
            }
            .navigationTitle("Receipt Scanner")
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
                } else {
                    // Reload transactions when returning from OCR import
                    viewModel.loadRecentTransactions()
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
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
                Text("No Receipts Yet")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)

                Text("Scan your first receipt to get started")
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
        }
    }

    // MARK: - Recent Transactions List

    private func recentTransactionsList(viewModel: ScanReceiptViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header with scan hint
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Transactions")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)

                    Text("Tap the + button to scan more receipts")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.textSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                // Transaction list
                VStack(spacing: 12) {
                    ForEach(viewModel.recentTransactions) { transaction in
                        NavigationLink {
                            TransactionDetailView(transaction: transaction)
                                .environmentObject(container)
                        } label: {
                            TransactionRow(transaction: transaction)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 100) // Space for floating button
        }
    }

    // MARK: - Floating Action Button

    private var quickScanButton: some View {
        Menu {
            Button {
                showingCamera = true
            } label: {
                Label("Take Photo", systemImage: "camera.fill")
            }

            Button {
                showingPhotoLibrary = true
            } label: {
                Label("Choose from Library", systemImage: "photo.fill")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(
                    LinearGradient(
                        colors: [AppTheme.accent, AppTheme.accent.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: AppTheme.accent.opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .padding(.trailing, 24)
        .padding(.bottom, 24)
    }
}

// MARK: - Feature Item

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

// MARK: - Preview

#Preview {
    ScanReceiptView()
        .environmentObject(DependencyContainer(persistenceController: .preview))
}
