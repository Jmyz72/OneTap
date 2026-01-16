//
//  ClaimsListView.swift
//  OneTap
//
//  View for displaying and managing pending claims
//

import SwiftUI
@preconcurrency internal import CoreData

struct ClaimsListView: View {
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: ClaimsListViewModel?

    var body: some View {
        Group {
            if let viewModel {
                ClaimsContent(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = container.makeClaimsListViewModel()
            }
        }
    }
}

private struct ClaimsContent: View {
    @ObservedObject var viewModel: ClaimsListViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                if viewModel.filteredClaims.isEmpty {
                    emptyState
                } else {
                    claimsList
                }
            }
            .navigationTitle("Claims")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !viewModel.filteredClaims.isEmpty {
                        Button(viewModel.isSelectMode ? "Done" : "Select") {
                            viewModel.isSelectMode.toggle()
                            if !viewModel.isSelectMode {
                                viewModel.deselectAll()
                            }
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingSettlementSheet) {
                SettlementSheet(viewModel: viewModel)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Pending Claims")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Mark expenses as claims to track reimbursements")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private var claimsList: some View {
        VStack(spacing: 0) {
            // Account filter
            if viewModel.accounts.count > 1 {
                accountFilterPicker
            }

            // Claims list
            List {
                ForEach(viewModel.filteredClaims, id: \.objectID) { claim in
                    ClaimRow(
                        claim: claim,
                        isSelected: viewModel.selectedClaimIDs.contains(claim.objectID),
                        isSelectMode: viewModel.isSelectMode,
                        onTap: {
                            if viewModel.isSelectMode {
                                viewModel.toggleSelection(claim)
                            }
                        }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Task {
                                await viewModel.deleteClaim(claim)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)

            // Settlement bar
            if viewModel.isSelectMode && viewModel.canSettle {
                settlementBar
            }
        }
    }

    private var accountFilterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // All accounts chip
                Button(action: { viewModel.selectedAccount = nil }) {
                    Text("All Accounts")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(viewModel.selectedAccount == nil ? AppTheme.accent : AppTheme.cardBackground)
                        .foregroundColor(viewModel.selectedAccount == nil ? .white : AppTheme.textPrimary)
                        .cornerRadius(20)
                }

                // Account chips
                ForEach(viewModel.accounts, id: \.objectID) { account in
                    Button(action: { viewModel.selectedAccount = account }) {
                        Text(account.name ?? "Account")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(viewModel.selectedAccount == account ? AppTheme.accent : AppTheme.cardBackground)
                            .foregroundColor(viewModel.selectedAccount == account ? .white : AppTheme.textPrimary)
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(AppTheme.background)
    }

    private var settlementBar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(viewModel.selectedClaimIDs.count) Selected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(viewModel.formattedTotalSelected)
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Spacer()

                Button(action: { viewModel.startSettlement() }) {
                    Text("Settle Claims")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(AppTheme.accent)
                        .cornerRadius(12)
                }
            }
            .padding()
            .background(AppTheme.cardBackground)
        }
    }
}

struct ClaimRow: View {
    let claim: Claim
    let isSelected: Bool
    let isSelectMode: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Selection indicator
                if isSelectMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? AppTheme.accent : .gray)
                        .font(.title3)
                }

                // Category icon
                if let category = claim.category {
                    ZStack {
                        Circle()
                            .fill(category.colorView.opacity(0.2))
                            .frame(width: 40, height: 40)

                        Image(systemName: category.iconName)
                            .foregroundColor(category.colorView)
                    }
                }

                // Details
                VStack(alignment: .leading, spacing: 4) {
                    Text(claim.category?.name ?? "Uncategorized")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.textPrimary)

                    HStack(spacing: 8) {
                        Text(claim.account?.name ?? "Unknown")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(claim.submittedDate ?? Date(), style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Amount
                Text(claim.formattedAmount)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

struct SettlementSheet: View {
    @ObservedObject var viewModel: ClaimsListViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Claims Selected")
                        Spacer()
                        Text("\(viewModel.selectedClaimIDs.count)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Total Claimed")
                        Spacer()
                        Text(viewModel.formattedTotalSelected)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Reimbursement") {
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("0.00", text: $viewModel.settlementAmount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    Picker("Deposit To", selection: $viewModel.settlementAccount) {
                        ForEach(viewModel.accounts, id: \.objectID) { account in
                            Text(account.name ?? "Unknown")
                                .tag(account as Account?)
                        }
                    }
                }

                Section {
                    Button("Confirm Settlement") {
                        Task {
                            await viewModel.confirmSettlement()
                            dismiss()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(AppTheme.accent)
                }
            }
            .navigationTitle("Settle Claims")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    ClaimsListView()
        .environmentObject(DependencyContainer(persistenceController: .preview))
}
