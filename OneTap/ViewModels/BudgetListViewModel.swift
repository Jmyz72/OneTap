import Foundation
import Combine
@preconcurrency internal import CoreData
import SwiftUI

@MainActor
class BudgetListViewModel: ObservableObject, ViewModelProtocol {

    // MARK: - Published Properties

    @Published var budgets: [Budget] = []
    @Published var selectedPeriod: BudgetPeriod = .current

    @Published var loadingState: LoadingState = .idle
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let budgetRepository: BudgetRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(budgetRepository: BudgetRepositoryProtocol) {
        self.budgetRepository = budgetRepository
        observeBudgets()
    }

    // MARK: - Observation

    private func observeBudgets() {
        budgetRepository.budgetsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] budgets in
                self?.budgets = budgets
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    func deleteBudget(_ budget: Budget) async {
        loadingState = .loading
        do {
            try budgetRepository.delete(budget)
            loadingState = .loaded
        } catch {
            loadingState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    func recalculateAll() async {
        loadingState = .loading
        do {
            for budget in budgets {
                try budgetRepository.recalculateSpent(for: budget)
            }
            loadingState = .loaded
        } catch {
            loadingState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Computed Properties

    var activeBudgets: [Budget] {
        let now = Date()
        return budgets.filter { budget in
            guard let start = budget.startDate, let end = budget.endDate else { return false }
            return start <= now && now <= end
        }
    }

    var exceedingBudgets: [Budget] {
        activeBudgets.filter { $0.isExceeded }
    }
}

enum BudgetPeriod {
    case current
    case past
    case future
}
