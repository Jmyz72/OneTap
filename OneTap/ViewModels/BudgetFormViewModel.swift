import Foundation
@preconcurrency internal import CoreData
import Combine

@MainActor
class BudgetFormViewModel: ObservableObject, ViewModelProtocol {

    // MARK: - Form State

    @Published var amount: String = ""
    @Published var selectedCategory: Category?
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date())!.addingTimeInterval(-86400) // End of current month approx

    @Published var loadingState: LoadingState = .idle
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let budgetRepository: BudgetRepositoryProtocol
    private let budget: Budget?

    var isEditing: Bool { budget != nil }

    // MARK: - Init

    init(budgetRepository: BudgetRepositoryProtocol, budget: Budget? = nil) {
        self.budgetRepository = budgetRepository
        self.budget = budget

        if let budget = budget {
            loadBudget(budget)
        } else {
            setupDefaults()
        }
    }
    
    private func setupDefaults() {
        // Default to current month start/end
        let calendar = Calendar.current
        let now = Date()
        if let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
           let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth),
           let endOfMonth = calendar.date(byAdding: .day, value: -1, to: nextMonth) {
            self.startDate = startOfMonth
            self.endDate = endOfMonth
        }
    }

    // MARK: - Load

    private func loadBudget(_ budget: Budget) {
        self.amount = String(format: "%.2f", budget.amount)
        self.selectedCategory = budget.category
        self.startDate = budget.startDate ?? Date()
        self.endDate = budget.endDate ?? Date()
    }

    // MARK: - Validation

    var isValid: Bool {
        guard let amountValue = Double(amount), amountValue > 0 else { return false }
        guard selectedCategory != nil else { return false }
        guard startDate < endDate else { return false }
        return true
    }

    // MARK: - Save

    func saveBudget() async {
        guard isValid else { return }
        guard let amountValue = Double(amount) else { return }
        guard let category = selectedCategory else { return }

        loadingState = .loading
        do {
            if let budget = budget {
                // Update existing
                let dto = BudgetUpdateData(
                    amount: amountValue,
                    spent: nil,
                    startDate: startDate,
                    endDate: endDate
                )
                try budgetRepository.update(budget, with: dto)
                try budgetRepository.recalculateSpent(for: budget)
            } else {
                // Create new
                let dto = BudgetCreateData(
                    amount: amountValue,
                    categoryID: category.id!,
                    startDate: startDate,
                    endDate: endDate
                )
                let newBudget = try budgetRepository.create(dto)
                try budgetRepository.recalculateSpent(for: newBudget)
            }
            loadingState = .loaded
        } catch {
            loadingState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }
}
