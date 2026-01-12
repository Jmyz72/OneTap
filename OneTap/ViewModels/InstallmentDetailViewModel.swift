//
//  InstallmentDetailViewModel.swift
//  OneTap
//
//  ViewModel for installment plan detail view and management actions
//

import Foundation
import SwiftUI
import Combine
internal import CoreData

@MainActor
class InstallmentDetailViewModel: ObservableObject, ViewModelProtocol {
    // MARK: - Published State
    @Published var relatedTransactions: [Transaction] = []
    @Published var loadingState: LoadingState = .idle
    @Published var errorMessage: String?
    @Published var shouldDismiss = false

    // MARK: - Dependencies
    private let plan: RecurringTransaction
    private let transactionRepository: TransactionRepository
    private let recurringTransactionService: RecurringTransactionService
    private var cancellables = Set<AnyCancellable>()

    init(
        plan: RecurringTransaction,
        transactionRepository: TransactionRepository,
        recurringTransactionService: RecurringTransactionService
    ) {
        self.plan = plan
        self.transactionRepository = transactionRepository
        self.recurringTransactionService = recurringTransactionService

        fetchRelatedTransactions()
        observeChanges()
    }

    deinit {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    // MARK: - Data Fetching

    private func fetchRelatedTransactions() {
        guard let planID = plan.id else { return }

        let predicate = NSPredicate(format: "installmentPlanID == %@", planID as CVarArg)
        let sortDescriptors = [NSSortDescriptor(keyPath: \Transaction.date, ascending: false)]

        relatedTransactions = transactionRepository.fetch(
            predicate: predicate,
            sortDescriptors: sortDescriptors
        )
    }

    private func observeChanges() {
        // Observe transaction changes to refresh list
        NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange)
            .sink { [weak self] _ in
                self?.fetchRelatedTransactions()
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    func payOffEarly() async {
        loadingState = .loading

        do {
            _ = try await recurringTransactionService.payOffInstallmentEarly(plan: plan)
            loadingState = .loaded
            shouldDismiss = true
        } catch {
            loadingState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    func cancelPlan(refundAmount: Double?) async {
        loadingState = .loading

        do {
            _ = try await recurringTransactionService.cancelInstallmentPlan(
                plan: plan,
                refundAmount: refundAmount
            )
            loadingState = .loaded
            shouldDismiss = true
        } catch {
            loadingState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }
}
