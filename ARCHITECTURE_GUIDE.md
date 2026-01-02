# OneTap Architecture Guide

This guide provides a comprehensive overview of OneTap's architecture, design patterns, and technical decisions.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Design Patterns](#design-patterns)
- [Layer Breakdown](#layer-breakdown)
- [Data Flow](#data-flow)
- [Core Systems](#core-systems)
- [Dependency Injection](#dependency-injection)
- [Threading & Concurrency](#threading--concurrency)
- [Error Handling](#error-handling)
- [Best Practices](#best-practices)

---

## Architecture Overview

OneTap follows a **MVVM (Model-View-ViewModel)** architecture with additional layers for better separation of concerns.

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         VIEW LAYER                           │
│  (SwiftUI Views - User Interface & Interaction)             │
│  - AccountListView, TransactionListView, etc.               │
└────────────────────────┬────────────────────────────────────┘
                         │ Binding, State
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                      VIEWMODEL LAYER                         │
│  (State Management & Presentation Logic)                    │
│  - AccountListViewModel, TransactionListViewModel, etc.     │
└────────────────────────┬────────────────────────────────────┘
                         │ Service Calls
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                       SERVICE LAYER                          │
│  (Business Logic & Coordination)                            │
│  - BalanceService, TransferService, ValidationService       │
└────────────────────────┬────────────────────────────────────┘
                         │ Repository Calls
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                     REPOSITORY LAYER                         │
│  (Data Access Abstraction)                                  │
│  - AccountRepository, TransactionRepository, etc.           │
└────────────────────────┬────────────────────────────────────┘
                         │ Core Data Operations
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                        DATA LAYER                            │
│  (Core Data - Persistence)                                  │
│  - Account, Transaction, Category entities                  │
└─────────────────────────────────────────────────────────────┘
```

### Key Principles

1. **Separation of Concerns** - Each layer has a single, well-defined responsibility
2. **Dependency Inversion** - Higher layers depend on abstractions, not concrete implementations
3. **Unidirectional Data Flow** - Data flows down, events flow up
4. **Testability** - All layers are independently testable
5. **Scalability** - Easy to add new features without breaking existing code

---

## Design Patterns

### 1. MVVM (Model-View-ViewModel)

**Purpose:** Separates UI from business logic

**Implementation:**
```swift
// View - SwiftUI
struct AccountListView: View {
    @State private var viewModel: AccountListViewModel?

    var body: some View {
        if let viewModel {
            List {
                ForEach(viewModel.accounts) { account in
                    AccountRow(account: account)
                }
            }
        }
    }
}

// ViewModel - State & Presentation Logic
@MainActor
class AccountListViewModel: BaseViewModel {
    @Published var accounts: [Account] = []

    func loadAccounts() {
        // Fetch from repository
    }
}

// Model - Core Data Entity
class Account: NSManagedObject {
    @NSManaged var name: String?
    @NSManaged var balance: Double
}
```

### 2. Repository Pattern

**Purpose:** Abstracts data access logic

**Implementation:**
```swift
// Protocol defines interface
protocol AccountRepositoryProtocol {
    func create(_ dto: AccountCreateData) async throws -> Account
    func fetch(id: UUID) async throws -> Account
    func update(_ account: Account, with dto: AccountUpdateData) async throws
    func delete(_ account: Account) async throws
}

// Concrete implementation
class AccountRepository: BaseRepository<Account>, AccountRepositoryProtocol {
    func create(_ dto: AccountCreateData) async throws -> Account {
        return try await performBackgroundTask { context in
            let account = Account(context: context)
            account.id = UUID()
            account.name = dto.name
            // ... configure account
            try context.save()
            return account
        }
    }
}
```

### 3. Dependency Injection

**Purpose:** Loose coupling and testability

**Implementation:**
```swift
// Container manages all dependencies
class DependencyContainer: ObservableObject {
    let persistenceController: PersistenceController

    private lazy var accountRepository: AccountRepositoryProtocol = {
        AccountRepository(context: persistenceController.container.viewContext)
    }()

    func makeAccountListViewModel() -> AccountListViewModel {
        AccountListViewModel(accountRepository: accountRepository)
    }
}

// App provides container to all views
@main
struct OneTapApp: App {
    @StateObject private var container = DependencyContainer()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(container)
        }
    }
}
```

### 4. Service Layer Pattern

**Purpose:** Encapsulates complex business logic

**Implementation:**
```swift
protocol BalanceServiceProtocol {
    func recalculateBalances(
        for accountIDs: [NSManagedObjectID],
        from date: Date?
    ) async throws
}

class BalanceService: BalanceServiceProtocol {
    private let transactionRepository: TransactionRepositoryProtocol

    func recalculateBalances(
        for accountIDs: [NSManagedObjectID],
        from date: Date?
    ) async throws {
        // Complex multi-step calculation
        // 1. Fetch transactions
        // 2. Calculate running balances
        // 3. Update all transactions
        // 4. Commit to database
    }
}
```

### 5. DTO (Data Transfer Object)

**Purpose:** Safe data transfer between layers

**Implementation:**
```swift
struct AccountCreateData {
    let name: String
    let type: AccountType
    let currency: String
    let initialBalance: Double
}

struct TransactionUpdateData {
    let title: String?
    let amount: Double?
    let date: Date?
    let categoryID: UUID?
}
```

---

## Layer Breakdown

### View Layer (`OneTap/Views/`)

**Responsibility:** User interface and user interaction

**Structure:**
```
Views/
├── Account/
│   ├── AccountListView.swift       - List all accounts
│   ├── AccountDetailView.swift     - Show account details
│   ├── AccountFormView.swift       - Add/Edit account
│   └── Components/                 - Reusable account UI
├── Transaction/
│   ├── TransactionListView.swift   - List transactions
│   ├── AddTransactionView.swift    - Add new transaction
│   ├── EditTransactionView.swift   - Edit transaction
│   └── Components/                 - Reusable transaction UI
├── Settings/
│   ├── CategoryListView.swift      - Manage categories
│   └── CategoryFormView.swift      - Edit category
├── Shared/                         - Shared components
└── MainTabView.swift               - Root navigation
```

**Key Characteristics:**
- **SwiftUI only** - No UIKit
- **Declarative** - Describes what to show, not how
- **Minimal logic** - Only presentation logic
- **Stateless** - State managed by ViewModels

**Example Pattern:**
```swift
struct AccountListView: View {
    @EnvironmentObject private var container: DependencyContainer
    @State private var viewModel: AccountListViewModel?

    var body: some View {
        Group {
            if let viewModel {
                // UI content using viewModel properties
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = container.makeAccountListViewModel()
            }
        }
    }
}
```

### ViewModel Layer (`OneTap/ViewModels/`)

**Responsibility:** State management and presentation logic

**Structure:**
```
ViewModels/
├── BaseViewModel.swift              - Base protocol & shared logic
├── AccountListViewModel.swift       - Account list state
├── AccountDetailViewModel.swift     - Account detail state
├── AddTransactionViewModel.swift    - Transaction form state
├── TransactionListViewModel.swift   - Transaction list state
└── ...
```

**Key Characteristics:**
- **@MainActor** - All ViewModels run on main thread
- **@Published properties** - Observable state changes
- **Async/await** - Modern concurrency
- **Error handling** - Consistent error propagation

**Base Protocol:**
```swift
@MainActor
protocol ViewModelProtocol: ObservableObject {
    var loadingState: LoadingState { get set }
    var errorMessage: String? { get set }

    func handleError(_ error: Error)
    func startLoading()
    func finishLoading()
}

enum LoadingState: Equatable {
    case idle
    case loading
    case loaded
    case error(String)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}
```

**Example Implementation:**
```swift
@MainActor
class AccountListViewModel: BaseViewModel {
    // Published state
    @Published var accounts: [Account] = []
    @Published var netWorth: Double = 0
    @Published var totalAssets: Double = 0
    @Published var totalLiabilities: Double = 0

    // Dependencies
    private let accountRepository: AccountRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()

    init(accountRepository: AccountRepositoryProtocol) {
        self.accountRepository = accountRepository
        super.init()
        observeAccounts()
    }

    private func observeAccounts() {
        accountRepository.accountsPublisher
            .sink { [weak self] accounts in
                self?.accounts = accounts
                self?.calculateTotals()
            }
            .store(in: &cancellables)
    }

    func deleteAccount(_ account: Account) async {
        startLoading()
        do {
            try await accountRepository.delete(account)
            finishLoading()
        } catch {
            handleError(error)
        }
    }
}
```

### Service Layer (`OneTap/Core/Services/`)

**Responsibility:** Complex business logic and orchestration

**Structure:**
```
Services/
├── BalanceService.swift         - Balance calculations
├── TransferService.swift        - Transfer operations
├── ValidationService.swift      - Input validation
└── Protocols/
    ├── BalanceServiceProtocol.swift
    ├── TransferServiceProtocol.swift
    └── ValidationServiceProtocol.swift
```

**When to Use Services:**
- Operation spans multiple repositories
- Complex business rules
- Multi-step transactions
- Background processing

**Example:**
```swift
protocol TransferServiceProtocol {
    func createTransfer(
        from sourceAccount: Account,
        to destinationAccount: Account,
        amount: Double,
        date: Date
    ) async throws -> (Transaction, Transaction)
}

class TransferService: TransferServiceProtocol {
    private let transactionRepository: TransactionRepositoryProtocol
    private let balanceService: BalanceServiceProtocol

    func createTransfer(
        from sourceAccount: Account,
        to destinationAccount: Account,
        amount: Double,
        date: Date
    ) async throws -> (Transaction, Transaction) {
        // Step 1: Validate transfer
        guard sourceAccount != destinationAccount else {
            throw ServiceError.validationFailed("Cannot transfer to same account")
        }

        // Step 2: Create expense transaction
        let expenseDTO = TransactionCreateData(
            title: "Transfer to \(destinationAccount.name ?? "")",
            amount: amount,
            type: .transfer,
            // ...
        )
        let expense = try await transactionRepository.create(expenseDTO, in: sourceAccount)

        // Step 3: Create income transaction
        let incomeDTO = TransactionCreateData(
            title: "Transfer from \(sourceAccount.name ?? "")",
            amount: amount,
            type: .income,
            // ...
        )
        let income = try await transactionRepository.create(incomeDTO, in: destinationAccount)

        // Step 4: Link transactions
        expense.relatedTransactionID = income.id
        income.relatedTransactionID = expense.id

        // Step 5: Recalculate balances
        try await balanceService.recalculateBalances(
            for: [sourceAccount.objectID, destinationAccount.objectID],
            from: date
        )

        return (expense, income)
    }
}
```

### Repository Layer (`OneTap/Core/Repositories/`)

**Responsibility:** Data access abstraction

**Structure:**
```
Repositories/
├── BaseRepository.swift            - Base CRUD operations
├── AccountRepository.swift         - Account data access
├── TransactionRepository.swift     - Transaction data access
├── CategoryRepository.swift        - Category data access
├── DTOs/
│   └── RepositoryDTOs.swift       - Data transfer objects
└── Protocols/
    ├── AccountRepositoryProtocol.swift
    └── TransactionRepositoryProtocol.swift
```

**Base Repository:**
```swift
class BaseRepository<T: NSManagedObject> {
    let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func performBackgroundTask<Result>(
        _ block: @escaping (NSManagedObjectContext) throws -> Result
    ) async throws -> Result {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let result = try block(self.context)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetch(predicate: NSPredicate? = nil, sortDescriptors: [NSSortDescriptor] = []) throws -> [T] {
        let request = T.fetchRequest()
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        return try context.fetch(request) as! [T]
    }
}
```

**Publishers for Reactive Updates:**
```swift
extension AccountRepository {
    var accountsPublisher: AnyPublisher<[Account], Never> {
        NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange)
            .compactMap { [weak self] _ in
                try? self?.fetchAll()
            }
            .prepend(try! fetchAll())
            .eraseToAnyPublisher()
    }
}
```

### Data Layer (`OneTap/Core/Data/`)

**Responsibility:** Core Data persistence

**Key Files:**
- `Persistence.swift` - Core Data stack
- `OneTap.xcdatamodeld` - Data model

**Core Data Stack:**
```swift
class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "OneTap")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        // Enable automatic migration
        let description = container.persistentStoreDescriptions.first
        description?.shouldMigrateStoreAutomatically = true
        description?.shouldInferMappingModelAutomatically = true

        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext

        // Seed preview data
        seedPreviewData(context: context)

        return controller
    }()
}
```

---

## Data Flow

### User Interaction Flow

```
1. USER TAPS "Add Account" BUTTON
   ↓
2. View captures tap → shows AccountFormView
   ↓
3. AccountFormView initializes AccountFormViewModel
   ↓
4. User fills form → ViewModel updates @Published properties
   ↓
5. User taps "Save"
   ↓
6. ViewModel.saveAccount() called
   ↓
7. ViewModel calls AccountRepository.create(dto)
   ↓
8. Repository creates Account entity in Core Data
   ↓
9. Core Data saves changes
   ↓
10. Repository publisher emits update
   ↓
11. AccountListViewModel receives update via Combine
   ↓
12. AccountListViewModel.accounts updates
   ↓
13. SwiftUI re-renders AccountListView
   ↓
14. User sees new account in list
```

### Balance Recalculation Flow

```
1. TRANSACTION CREATED/UPDATED/DELETED
   ↓
2. ViewModel calls BalanceService.recalculateBalances()
   ↓
3. BalanceService fetches all transactions for account
   ↓
4. Service calculates running balances
   ↓
5. Service updates balanceAfter on each transaction
   ↓
6. Service updates account.balance with final value
   ↓
7. Core Data saves changes on background thread
   ↓
8. Changes merge to main context
   ↓
9. UI updates reactively
```

---

## Core Systems

### 1. Balance Tracking System

**Critical Feature:** Every transaction stores its `balanceAfter` value

**Why It Matters:**
- Fast account balance queries (no calculation needed)
- Historical balance tracking
- Balance validation

**Implementation:**
```swift
// Transaction entity
class Transaction: NSManagedObject {
    @NSManaged var balanceAfter: Double  // Critical field!
}

// Balance calculation
class BalanceService {
    func recalculateBalances(for accountID: NSManagedObjectID, from date: Date?) async throws {
        try await performBackgroundTask { context in
            let account = context.object(with: accountID) as! Account

            // Fetch transactions sorted by date
            let transactions = try fetchTransactions(for: account, from: date, context: context)

            // Get starting balance
            var runningBalance = getStartingBalance(for: account, before: date)

            // Calculate balances
            for transaction in transactions {
                runningBalance += transaction.impactOnBalance
                transaction.balanceAfter = runningBalance
            }

            // Update account balance
            account.balance = runningBalance

            try context.save()
        }
    }

    private func impactOnBalance(for transaction: Transaction) -> Double {
        switch transaction.typeEnum {
        case .expense, .transfer:
            return -transaction.amount
        case .income:
            return transaction.amount
        case .adjustment:
            return transaction.amount
        }
    }
}
```

### 2. Transfer System

**Implementation:**
```swift
// Creates TWO linked transactions
func createTransfer(...) async throws -> (Transaction, Transaction) {
    // Transaction 1: Expense from source
    let expense = Transaction(...)
    expense.type = TransactionType.transfer.rawValue
    expense.amount = amount
    expense.account = sourceAccount

    // Transaction 2: Income to destination
    let income = Transaction(...)
    income.type = TransactionType.income.rawValue
    income.amount = amount
    income.account = destinationAccount

    // Link them
    expense.relatedTransactionID = income.id
    income.relatedTransactionID = expense.id

    return (expense, income)
}
```

**Deletion Handling:**
```swift
func deleteTransfer(_ transaction: Transaction) async throws {
    guard transaction.typeEnum == .transfer else {
        throw ServiceError.validationFailed("Not a transfer")
    }

    // Find and delete related transaction
    if let relatedID = transaction.relatedTransactionID {
        let related = try await fetchTransaction(id: relatedID)
        try await delete(related)
    }

    // Delete original transaction
    try await delete(transaction)
}
```

### 3. Category System

**Features:**
- User-editable categories
- Subcategories with icon inheritance
- Default seeding on first launch

**Default Categories:**
```swift
static func seedDefaults(context: NSManagedObjectContext) {
    let categories = [
        ("Food & Drinks", "fork.knife", "#FF6B6B", TransactionType.expense, ["Groceries", "Restaurants", "Coffee"]),
        ("Transport", "car.fill", "#4ECDC4", TransactionType.expense, ["Fuel", "Public Transit", "Parking"]),
        // ... more categories
    ]

    for (name, icon, color, type, subs) in categories {
        let category = Category(context: context)
        category.id = UUID()
        category.name = name
        category.icon = icon
        category.color = color
        category.type = type.rawValue

        // Create subcategories
        for (index, subName) in subs.enumerated() {
            let sub = SubCategory(context: context)
            sub.id = UUID()
            sub.name = subName
            sub.order = Int16(index)
            sub.category = category
        }
    }
}
```

### 4. Split Transaction System

**Concept:** One payment, multiple categories

**Implementation:**
```swift
// Parent transaction
let transaction = Transaction(...)
transaction.title = "Breakfast at Cafe"
transaction.amount = 25.00  // Total

// Split items
let foodItem = TransactionItem(...)
foodItem.title = "Food"
foodItem.amount = 20.00
foodItem.category = foodCategory
foodItem.transaction = transaction

let drinkItem = TransactionItem(...)
drinkItem.title = "Coffee"
drinkItem.amount = 5.00
drinkItem.category = drinkCategory
drinkItem.transaction = transaction

// Validation
assert(foodItem.amount + drinkItem.amount == transaction.amount)
```

---

## Dependency Injection

### DependencyContainer Pattern

**Purpose:** Centralized dependency creation and management

**Full Implementation:**
```swift
class DependencyContainer: ObservableObject {
    // MARK: - Core Dependencies

    let persistenceController: PersistenceController

    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }

    // MARK: - Repositories (Lazy)

    private lazy var accountRepository: AccountRepositoryProtocol = {
        AccountRepository(context: persistenceController.container.viewContext)
    }()

    private lazy var transactionRepository: TransactionRepositoryProtocol = {
        TransactionRepository(context: persistenceController.container.viewContext)
    }()

    private lazy var categoryRepository: CategoryRepositoryProtocol = {
        CategoryRepository(context: persistenceController.container.viewContext)
    }()

    // MARK: - Services (Lazy)

    private lazy var balanceService: BalanceServiceProtocol = {
        BalanceService(
            transactionRepository: transactionRepository,
            persistenceController: persistenceController
        )
    }()

    private lazy var transferService: TransferServiceProtocol = {
        TransferService(
            transactionRepository: transactionRepository,
            balanceService: balanceService
        )
    }()

    private lazy var validationService: ValidationServiceProtocol = {
        ValidationService()
    }()

    // MARK: - ViewModel Factories

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

    func makeAddTransactionViewModel() -> AddTransactionViewModel {
        AddTransactionViewModel(
            transactionRepository: transactionRepository,
            balanceService: balanceService,
            validationService: validationService
        )
    }

    // ... more factory methods
}
```

**Usage in App:**
```swift
@main
struct OneTapApp: App {
    @StateObject private var container = DependencyContainer()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(container)
                .environment(\.managedObjectContext, container.persistenceController.container.viewContext)
        }
    }
}
```

**Usage in Views:**
```swift
struct AccountListView: View {
    @EnvironmentObject private var container: DependencyContainer
    @State private var viewModel: AccountListViewModel?

    var body: some View {
        // ...
        .onAppear {
            if viewModel == nil {
                viewModel = container.makeAccountListViewModel()
            }
        }
    }
}
```

---

## Threading & Concurrency

### Main Actor Pattern

**All ViewModels run on @MainActor:**
```swift
@MainActor
class AccountListViewModel: BaseViewModel {
    // All property updates happen on main thread
    @Published var accounts: [Account] = []

    func deleteAccount(_ account: Account) async {
        // This async function still runs on main thread
        // But can await background work
        try await accountRepository.delete(account)  // Background
    }
}
```

### Background Core Data Operations

```swift
func performBackgroundTask<Result>(
    _ block: @escaping (NSManagedObjectContext) throws -> Result
) async throws -> Result {
    return try await withCheckedThrowingContinuation { continuation in
        persistenceController.container.performBackgroundTask { context in
            do {
                let result = try block(context)
                try context.save()
                continuation.resume(returning: result)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
```

### Combine Integration

```swift
class AccountRepository {
    var accountsPublisher: AnyPublisher<[Account], Never> {
        NotificationCenter.default
            .publisher(for: .NSManagedObjectContextObjectsDidChange)
            .compactMap { [weak self] _ in
                try? self?.fetchAll()
            }
            .prepend(try! fetchAll())
            .eraseToAnyPublisher()
    }
}

class AccountListViewModel {
    private func observeAccounts() {
        accountRepository.accountsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] accounts in
                self?.accounts = accounts
            }
            .store(in: &cancellables)
    }
}
```

---

## Error Handling

### Error Types

```swift
// Service Layer Errors
enum ServiceError: LocalizedError {
    case entityNotFound
    case operationFailed(String)
    case validationFailed(String)
    case concurrencyError
    case balanceCalculationFailed

    var errorDescription: String? {
        switch self {
        case .entityNotFound:
            return "The requested item could not be found."
        case .operationFailed(let message):
            return "Operation failed: \(message)"
        case .validationFailed(let message):
            return message
        case .concurrencyError:
            return "A conflict occurred. Please try again."
        case .balanceCalculationFailed:
            return "Failed to calculate account balance."
        }
    }
}

// Validation Errors
enum ValidationError: LocalizedError {
    case emptyField(String)
    case invalidAmount
    case invalidDate
    case accountRequired
    case categoryRequired

    var errorDescription: String? {
        switch self {
        case .emptyField(let field):
            return "\(field) cannot be empty."
        case .invalidAmount:
            return "Please enter a valid amount."
        case .invalidDate:
            return "Please select a valid date."
        case .accountRequired:
            return "Please select an account."
        case .categoryRequired:
            return "Please select a category."
        }
    }
}

// Repository Errors
enum RepositoryError: LocalizedError {
    case fetchFailed
    case saveFailed
    case deleteFailed
    case entityNotFound

    var errorDescription: String? {
        switch self {
        case .fetchFailed:
            return "Failed to load data."
        case .saveFailed:
            return "Failed to save changes."
        case .deleteFailed:
            return "Failed to delete item."
        case .entityNotFound:
            return "Item not found."
        }
    }
}
```

### Error Handling Pattern

```swift
@MainActor
class AccountListViewModel: BaseViewModel {
    func deleteAccount(_ account: Account) async {
        startLoading()
        do {
            try await accountRepository.delete(account)
            finishLoading()
        } catch {
            handleError(error)
        }
    }
}

// Base implementation
extension BaseViewModel {
    func handleError(_ error: Error) {
        loadingState = .error(error.localizedDescription)
        errorMessage = error.localizedDescription
    }

    func startLoading() {
        loadingState = .loading
        errorMessage = nil
    }

    func finishLoading() {
        loadingState = .loaded
    }
}
```

### View Error Display

```swift
struct AccountListView: View {
    var body: some View {
        // ...
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
    }
}
```

---

## Best Practices

### 1. ViewModel Lifecycle

```swift
@MainActor
class MyViewModel: BaseViewModel {
    private var cancellables = Set<AnyCancellable>()

    init(repository: MyRepositoryProtocol) {
        super.init()
        observeData()
    }

    private func observeData() {
        repository.dataPublisher
            .sink { [weak self] data in
                self?.updateUI(data)
            }
            .store(in: &cancellables)
    }

    deinit {
        // Cancellables auto-cancel
        print("ViewModel deallocated")
    }
}
```

### 2. Core Data Best Practices

```swift
// ✅ DO: Use background contexts for heavy operations
func importData() async throws {
    try await performBackgroundTask { context in
        // Heavy work here
        let objects = parseCSV()
        for obj in objects {
            createEntity(obj, context: context)
        }
        try context.save()
    }
}

// ❌ DON'T: Block main thread
func importDataBad() {
    let objects = parseCSV()  // Blocks main thread!
    for obj in objects {
        createEntity(obj, context: viewContext)
    }
    try! viewContext.save()
}

// ✅ DO: Pass ObjectIDs across threads
let accountID = account.objectID
Task.detached {
    let bgContext = container.newBackgroundContext()
    let bgAccount = bgContext.object(with: accountID) as! Account
    // Work with bgAccount
}

// ❌ DON'T: Pass managed objects across threads
Task.detached {
    account.balance = 100  // CRASH! Wrong thread
}
```

### 3. State Management

```swift
// ✅ DO: Use @Published for observable state
@MainActor
class MyViewModel {
    @Published var items: [Item] = []
    @Published var selectedItem: Item?
}

// ✅ DO: Use @State for view-only UI state
struct MyView: View {
    @State private var showingSheet = false
    @State private var searchText = ""
}

// ❌ DON'T: Mix state responsibilities
@MainActor
class MyViewModel {
    @Published var showingSheet = false  // This is view state!
}
```

### 4. Async/Await Best Practices

```swift
// ✅ DO: Use structured concurrency
func saveData() async throws {
    async let saveAccount = accountRepository.save(account)
    async let saveTransactions = transactionRepository.saveAll(transactions)

    try await (saveAccount, saveTransactions)
}

// ✅ DO: Handle cancellation
func longRunningTask() async throws {
    for item in items {
        try Task.checkCancellation()
        await processItem(item)
    }
}

// ❌ DON'T: Use completion handlers
func saveDataOld(completion: @escaping (Result<Void, Error>) -> Void) {
    // Old style, avoid!
}
```

### 5. Memory Management

```swift
// ✅ DO: Use weak self in closures
class MyViewModel {
    func observeData() {
        repository.dataPublisher
            .sink { [weak self] data in
                self?.updateUI(data)
            }
            .store(in: &cancellables)
    }
}

// ✅ DO: Cancel subscriptions
class MyViewModel {
    private var cancellables = Set<AnyCancellable>()

    deinit {
        cancellables.forEach { $0.cancel() }
    }
}
```

---

## Testing Strategy

### Unit Testing

```swift
@MainActor
class AccountListViewModelTests: XCTestCase {
    var sut: AccountListViewModel!
    var mockRepository: MockAccountRepository!

    override func setUp() {
        mockRepository = MockAccountRepository()
        sut = AccountListViewModel(accountRepository: mockRepository)
    }

    func testLoadAccounts() async {
        // Given
        let expectedAccounts = [Account(), Account()]
        mockRepository.accountsToReturn = expectedAccounts

        // When
        await sut.loadAccounts()

        // Then
        XCTAssertEqual(sut.accounts.count, 2)
    }
}
```

### Integration Testing

```swift
class BalanceServiceIntegrationTests: XCTestCase {
    var persistenceController: PersistenceController!
    var balanceService: BalanceService!

    override func setUp() {
        persistenceController = PersistenceController(inMemory: true)
        let repository = TransactionRepository(context: persistenceController.container.viewContext)
        balanceService = BalanceService(
            transactionRepository: repository,
            persistenceController: persistenceController
        )
    }

    func testBalanceCalculation() async throws {
        // Create test data
        let account = createAccount(initialBalance: 100)
        createTransaction(account: account, amount: 50, type: .expense)

        // Recalculate
        try await balanceService.recalculateBalances(for: account.objectID, from: nil)

        // Assert
        XCTAssertEqual(account.balance, 50)
    }
}
```

---

**Last Updated:** 2026-01-02
**Version:** 1.0
**Author:** OneTap Development Team
