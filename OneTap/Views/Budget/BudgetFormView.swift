import SwiftUI
@preconcurrency internal import CoreData

struct BudgetFormView: View {
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: BudgetFormViewModel?

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)],
        predicate: NSPredicate(format: "type == %@", TransactionType.expense.rawValue)
    ) private var categories: FetchedResults<Category>

    var body: some View {
        Group {
            if let viewModel {
                BudgetFormContent(viewModel: viewModel, categories: Array(categories), dismiss: dismiss)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = container.makeBudgetFormViewModel()
            }
        }
    }
}

// MARK: - Content View

private struct BudgetFormContent: View {
    @ObservedObject var viewModel: BudgetFormViewModel
    let categories: [Category]
    let dismiss: DismissAction

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    Picker("Category", selection: $viewModel.selectedCategory) {
                        Text("Select Category").tag(nil as Category?)
                        ForEach(categories, id: \.objectID) { category in
                            categoryRow(for: category)
                                .tag(category as Category?)
                        }
                    }
                }

                Section("Amount") {
                    TextField("Budget Amount", text: $viewModel.amount)
                        .keyboardType(.decimalPad)
                }

                Section("Period") {
                    DatePicker("Start Date", selection: $viewModel.startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $viewModel.endDate, displayedComponents: .date)
                }
            }
            .navigationTitle(viewModel.isEditing ? "Edit Budget" : "New Budget")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.saveBudget()
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.loadingState.isLoading)
                }
            }
            .onChange(of: viewModel.loadingState) { oldValue, newState in
                if newState == .loaded {
                    dismiss()
                }
            }
        }
    }

    @ViewBuilder
    private func categoryRow(for category: Category) -> some View {
        HStack {
            Image(systemName: category.icon ?? "tag.fill")
                .foregroundColor(category.colorView)
            Text(category.name ?? "Unknown")
        }
    }
}
