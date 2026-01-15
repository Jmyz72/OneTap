import SwiftUI
@preconcurrency internal import CoreData

struct BudgetListView: View {
    @EnvironmentObject private var container: DependencyContainer
    @State private var viewModel: BudgetListViewModel?
    @State private var showingAddBudget = false

    var body: some View {
        Group {
            if let viewModel {
                List {
                    if viewModel.activeBudgets.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(viewModel.activeBudgets, id: \.id) { budget in
                            BudgetRow(budget: budget)
                        }
                        .onDelete { offsets in
                            Task {
                                for index in offsets {
                                    await viewModel.deleteBudget(viewModel.activeBudgets[index])
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Budgets")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingAddBudget = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showingAddBudget) {
                    BudgetFormView()
                }
                .alert("Error", isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )) {
                    Button("OK") {
                        viewModel.errorMessage = nil
                    }
                } message: {
                    if let error = viewModel.errorMessage {
                        Text(error)
                    }
                }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = container.makeBudgetListViewModel()
            }
            
            // Refresh calculations when view appears
            Task {
                await viewModel?.recalculateAll()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.textTertiary)

            Text("No Budgets Yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)

            Text("Create a budget to track your spending")
                .font(.system(size: 15))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                showingAddBudget = true
            } label: {
                Text("Create Budget")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(AppTheme.accent)
                    .cornerRadius(12)
            }
        }
        .padding()
        .listRowSeparator(.hidden)
    }
}

struct BudgetRow: View {
    @ObservedObject var budget: Budget

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: budget.category?.icon ?? "tag.fill")
                    .foregroundColor(budget.category?.colorView ?? .gray)

                Text(budget.category?.name ?? "Unknown")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                Text(budget.formattedRemaining)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(budget.isExceeded ? AppTheme.expense : AppTheme.textSecondary)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)

                    Rectangle()
                        .fill(budget.statusColor)
                        .frame(width: min(geometry.size.width, geometry.size.width * CGFloat(budget.progress / 100)), height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)

            HStack {
                Text("\(budget.formattedSpent) of \(budget.formattedAmount)")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.textSecondary)

                Spacer()

                Text("\(Int(budget.progress))%")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(budget.statusColor)
            }
        }
        .padding(.vertical, 8)
    }
}
