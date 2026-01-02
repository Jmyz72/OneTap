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

    // MARK: - Services
    let balanceService: BalanceService
    let transferService: TransferService
    let validationService: ValidationService

    init(persistenceController: PersistenceController? = nil) {
        let pc = persistenceController ?? PersistenceController.shared
        self.persistenceController = pc

        // Initialize repositories
        let context = pc.container.viewContext
        self.transactionRepository = TransactionRepository(context: context)
        self.accountRepository = AccountRepository(context: context)
        self.categoryRepository = CategoryRepository(context: context)

        // Initialize services
        self.balanceService = BalanceService(container: pc.container)
        self.transferService = TransferService(
            transactionRepository: transactionRepository,
            balanceService: balanceService
        )
        self.validationService = ValidationService()
    }

    // MARK: - ViewModel Factories

    func makeAddTransactionViewModel() -> AddTransactionViewModel {
        AddTransactionViewModel(
            transactionRepository: transactionRepository,
            accountRepository: accountRepository,
            categoryRepository: categoryRepository,
            transferService: transferService,
            balanceService: balanceService,
            validationService: validationService
        )
    }

    func makeEditTransactionViewModel(transaction: Transaction) -> EditTransactionViewModel {
        EditTransactionViewModel(
            transaction: transaction,
            transactionRepository: transactionRepository,
            accountRepository: accountRepository,
            categoryRepository: categoryRepository,
            transferService: transferService,
            balanceService: balanceService
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
}
