//
//  DependencyContainer.swift
//  OneTap
//
//  Dependency Injection container
//  Manages all repositories, services, and ViewModel factories
//

import Foundation
import SwiftUI
internal import CoreData
import Combine

@MainActor
final class DependencyContainer: ObservableObject {
    nonisolated let objectWillChange = ObservableObjectPublisher()

    // MARK: - Core Data
    let persistenceController: PersistenceController

    // MARK: - Repositories
    let transactionRepository: TransactionRepository
    let accountRepository: AccountRepository
    let categoryRepository: CategoryRepository
    let recurringTransactionRepository: RecurringTransactionRepository
    let budgetRepository: BudgetRepository
    let pendingRecurringRepository: PendingRecurringRepository
    let savingsGoalRepository: SavingsGoalRepository
    let claimRepository: ClaimRepository

    // MARK: - Services
    let balanceService: BalanceService
    let transferService: TransferService
    let validationService: ValidationService
    let recurringTransactionService: RecurringTransactionService
    let budgetService: BudgetService
    let claimService: ClaimService
    let ocrService: OCRService
    let transactionExtractionService: TransactionExtractionService
    let categoryMatchingService: CategoryMatchingService

    init(persistenceController: PersistenceController? = nil) {
        let pc = persistenceController ?? PersistenceController.shared
        self.persistenceController = pc

        // Initialize repositories
        let context = pc.container.viewContext
        self.transactionRepository = TransactionRepository(context: context)
        self.accountRepository = AccountRepository(context: context)
        self.categoryRepository = CategoryRepository(context: context)
        self.recurringTransactionRepository = RecurringTransactionRepository(context: context)
        self.budgetRepository = BudgetRepository(context: context)
        self.pendingRecurringRepository = PendingRecurringRepository(context: context)
        self.savingsGoalRepository = SavingsGoalRepository(context: context)
        self.claimRepository = ClaimRepository(context: context)

        // Initialize services
        self.balanceService = BalanceService(container: pc.container)
        self.transferService = TransferService(
            transactionRepository: transactionRepository,
            balanceService: balanceService
        )
        self.validationService = ValidationService()
        self.recurringTransactionService = RecurringTransactionService(
            context: context,
            transactionRepository: transactionRepository,
            balanceService: balanceService,
            pendingRecurringRepository: pendingRecurringRepository
        )
        self.budgetService = BudgetService(
            budgetRepository: budgetRepository,
            context: context
        )
        self.claimService = ClaimService(
            claimRepository: claimRepository,
            transactionRepository: transactionRepository,
            balanceService: balanceService
        )
        self.ocrService = OCRService()
        self.transactionExtractionService = TransactionExtractionService()
        self.categoryMatchingService = CategoryMatchingService(categoryRepository: categoryRepository)
    }

    // MARK: - ViewModel Factories

    func makeAddTransactionViewModel() -> AddTransactionViewModel {
        AddTransactionViewModel(
            transactionRepository: transactionRepository,
            accountRepository: accountRepository,
            categoryRepository: categoryRepository,
            recurringTransactionRepository: recurringTransactionRepository,
            recurringTransactionService: recurringTransactionService,
            transferService: transferService,
            balanceService: balanceService,
            validationService: validationService,
            claimService: claimService
        )
    }

    func makeBudgetViewModel() -> BudgetViewModel {
        BudgetViewModel(
            budgetService: budgetService,
            budgetRepository: budgetRepository
        )
    }

    func makeEditTransactionViewModel(transaction: Transaction) -> EditTransactionViewModel {
        EditTransactionViewModel(
            transaction: transaction,
            transactionRepository: transactionRepository,
            accountRepository: accountRepository,
            categoryRepository: categoryRepository,
            claimRepository: claimRepository,
            transferService: transferService,
            balanceService: balanceService,
            claimService: claimService
        )
    }

    func makeAccountFormViewModel(account: Account? = nil, template: AccountTemplate? = nil) -> AccountFormViewModel {
        AccountFormViewModel(
            account: account,
            template: template,
            accountRepository: accountRepository,
            transactionRepository: transactionRepository,
            balanceService: balanceService
        )
    }

    func makeAccountListViewModel() -> AccountListViewModel {
        AccountListViewModel(accountRepository: accountRepository)
    }

    func makeAccountDetailViewModel(account: Account) -> AccountDetailViewModel {
        AccountDetailViewModel(
            account: account,
            accountRepository: accountRepository,
            transactionRepository: transactionRepository
        )
    }

    func makeAccountTransactionListViewModel(account: Account) -> AccountTransactionListViewModel {
        AccountTransactionListViewModel(
            account: account,
            transactionRepository: transactionRepository
        )
    }

    func makeTransactionListViewModel() -> TransactionListViewModel {
        TransactionListViewModel(transactionRepository: transactionRepository)
    }

    func makeTransactionDetailViewModel(transaction: Transaction) -> TransactionDetailViewModel {
        TransactionDetailViewModel(
            transaction: transaction,
            transactionRepository: transactionRepository,
            balanceService: balanceService
        )
    }

    func makeCategoryListViewModel() -> CategoryListViewModel {
        CategoryListViewModel(categoryRepository: categoryRepository)
    }

    func makeCategoryFormViewModel(category: Category? = nil) -> CategoryFormViewModel {
        CategoryFormViewModel(
            category: category,
            categoryRepository: categoryRepository
        )
    }
    
    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(persistenceController: persistenceController)
    }
    
    func makeRecurringTransactionsListViewModel() -> RecurringTransactionsListViewModel {
        RecurringTransactionsListViewModel(repository: recurringTransactionRepository)
    }

    func makeInstallmentDetailViewModel(plan: RecurringTransaction) -> InstallmentDetailViewModel {
        InstallmentDetailViewModel(
            plan: plan,
            transactionRepository: transactionRepository,
            recurringTransactionService: recurringTransactionService
        )
    }

    func makeAddInstallmentPlanViewModel() -> AddInstallmentPlanViewModel {
        AddInstallmentPlanViewModel(
            recurringTransactionService: recurringTransactionService,
            accountRepository: accountRepository,
            categoryRepository: categoryRepository,
            validationService: validationService
        )
    }

    func makeAnalyticsViewModel() -> AnalyticsViewModel {
        AnalyticsViewModel(transactionRepository: transactionRepository)
    }

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(
            accountRepository: accountRepository,
            transactionRepository: transactionRepository,
            budgetRepository: budgetRepository,
            recurringTransactionRepository: recurringTransactionRepository,
            pendingRecurringRepository: pendingRecurringRepository,
            claimRepository: claimRepository,
            balanceService: balanceService
        )
    }

    func makeClaimsListViewModel() -> ClaimsListViewModel {
        ClaimsListViewModel(
            claimRepository: claimRepository,
            claimService: claimService,
            accountRepository: accountRepository
        )
    }

    func makeOCRImportViewModel() -> OCRImportViewModel {
        OCRImportViewModel(
            ocrService: ocrService,
            extractionService: transactionExtractionService,
            categoryMatchingService: categoryMatchingService,
            transactionRepository: transactionRepository,
            accountRepository: accountRepository,
            categoryRepository: categoryRepository,
            balanceService: balanceService,
            validationService: validationService
        )
    }
}
