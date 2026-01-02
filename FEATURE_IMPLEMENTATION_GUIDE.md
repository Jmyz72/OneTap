# OneTap Feature Implementation Guide

This guide provides step-by-step instructions for implementing new features in OneTap, following the established architecture patterns.

## Table of Contents

- [Before You Start](#before-you-start)
- [Feature Planning Checklist](#feature-planning-checklist)
- [Implementation Workflow](#implementation-workflow)
- [Example: Adding Budgets Feature](#example-adding-budgets-feature)
- [Example: Adding Tags to Transactions](#example-adding-tags-to-transactions)
- [Common Patterns](#common-patterns)
- [Testing Your Feature](#testing-your-feature)
- [Code Review Checklist](#code-review-checklist)

---

## Before You Start

### Read the Documentation

1. **BUILD_GUIDE.md** - Understand how to build and run the project
2. **ARCHITECTURE_GUIDE.md** - Understand the architecture layers
3. **CLAUDE.md** - Understand project-specific patterns

### Understand the Codebase

```bash
# Explore the structure
tree OneTap -L 2

# Read key files
- OneTap/Core/DI/DependencyContainer.swift
- OneTap/ViewModels/BaseViewModel.swift
- OneTap/Core/Repositories/BaseRepository.swift
```

### Set Up Your Environment

```bash
# Create a feature branch
git checkout -b feature/budget-tracking

# Ensure project builds
xcodebuild -project OneTap.xcodeproj -scheme OneTap build
```

---

## Feature Planning Checklist

Before writing code, answer these questions:

### 1. Data Model
- [ ] What entities do I need?
- [ ] What are the relationships?
- [ ] What validation rules apply?
- [ ] Do I need migration?

### 2. Business Logic
- [ ] What services do I need?
- [ ] What validation is required?
- [ ] Are there complex calculations?
- [ ] Do I need background processing?

### 3. User Interface
- [ ] What screens do I need?
- [ ] How does navigation work?
- [ ] What user interactions are needed?
- [ ] What error states exist?

### 4. Integration Points
- [ ] Does this affect existing features?
- [ ] Do I need to modify existing services?
- [ ] What repositories do I need to access?

---

## Implementation Workflow

Follow these steps for every feature:

```
1. DATA LAYER (Core Data Model)
   ↓
2. REPOSITORY LAYER (Data Access)
   ↓
3. SERVICE LAYER (Business Logic)
   ↓
4. VIEWMODEL LAYER (State Management)
   ↓
5. VIEW LAYER (User Interface)
   ↓
6. DEPENDENCY INJECTION (Wire Everything)
   ↓
7. TESTING (Verify Functionality)
```

---

## Example: Adding Budgets Feature

Let's implement a monthly budget tracking feature step by step.

### Step 1: Plan the Feature

**Requirements:**
- Users can set monthly budgets per category
- Track spending against budgets
- Show warnings when approaching limit
- Display budget progress visually

**Entities Needed:**
- `Budget` entity with amount, category, and time period

### Step 2: Update Core Data Model

**File:** `OneTap.xcdatamodeld`

1. **Add New Entity:**
   - Open `OneTap.xcdatamodeld` in Xcode
   - Click "+" to add entity named `Budget`

2. **Add Attributes:**
   ```
   Budget Entity:
   - id: UUID (required)
   - amount: Double (required)
   - spent: Double (required, default 0)
   - startDate: Date (required)
   - endDate: Date (required)
   - createdAt: Date (required)
   - updatedAt: Date (required)
   ```

3. **Add Relationships:**
   ```
   Budget → Category (To One, required)
   Category → budgets (To Many, optional)
   ```

4. **Create Model Version:**
   - Editor → Add Model Version
   - Name it: `OneTap 2`
   - Set as current model

### Step 3: Create Model Extension

**File:** `OneTap/Models/BudgetModel.swift`

```swift
import Foundation
import CoreData

extension Budget {
    // Computed property for progress percentage
    var progress: Double {
        guard amount > 0 else { return 0 }
        return (spent / amount) * 100
    }

    // Check if budget is exceeded
    var isExceeded: Bool {
        return spent > amount
    }

    // Remaining amount
    var remaining: Double {
        return max(0, amount - spent)
    }

    // Warning threshold (80%)
    var isNearLimit: Bool {
        return progress >= 80 && !isExceeded
    }

    // Formatted amounts
    var formattedAmount: String {
        let formatter = Formatters.currencyFormatter(for: category?.currencyCode ?? "USD")
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }

    var formattedSpent: String {
        let formatter = Formatters.currencyFormatter(for: category?.currencyCode ?? "USD")
        return formatter.string(from: NSNumber(value: spent)) ?? "$0.00"
    }

    var formattedRemaining: String {
        let formatter = Formatters.currencyFormatter(for: category?.currencyCode ?? "USD")
        return formatter.string(from: NSNumber(value: remaining)) ?? "$0.00"
    }
}
```

### Step 4: Create DTOs

**File:** `OneTap/Core/Repositories/DTOs/BudgetDTOs.swift`

```swift
import Foundation

struct BudgetCreateData {
    let amount: Double
    let categoryID: UUID
    let startDate: Date
    let endDate: Date
}

struct BudgetUpdateData {
    let amount: Double?
    let spent: Double?
    let startDate: Date?
    let endDate: Date?
}
```

### Step 5: Create Repository Protocol

**File:** `OneTap/Core/Repositories/Protocols/BudgetRepositoryProtocol.swift`

```swift
import Foundation
import Combine
import CoreData

protocol BudgetRepositoryProtocol {
    func create(_ dto: BudgetCreateData) async throws -> Budget
    func fetch(id: UUID) async throws -> Budget
    func fetchAll() throws -> [Budget]
    func fetchActive(for category: Category, on date: Date) async throws -> Budget?
    func update(_ budget: Budget, with dto: BudgetUpdateData) async throws
    func delete(_ budget: Budget) async throws
    func recalculateSpent(for budget: Budget) async throws

    var budgetsPublisher: AnyPublisher<[Budget], Never> { get }
}
```

### Step 6: Create Repository Implementation

**File:** `OneTap/Core/Repositories/BudgetRepository.swift`

```swift
import Foundation
import CoreData
import Combine

class BudgetRepository: BaseRepository<Budget>, BudgetRepositoryProtocol {

    // MARK: - Create

    func create(_ dto: BudgetCreateData) async throws -> Budget {
        return try await performBackgroundTask { context in
            let budget = Budget(context: context)
            budget.id = UUID()
            budget.amount = dto.amount
            budget.spent = 0
            budget.startDate = dto.startDate
            budget.endDate = dto.endDate
            budget.createdAt = Date()
            budget.updatedAt = Date()

            // Fetch and set category
            let categoryRequest = Category.fetchRequest()
            categoryRequest.predicate = NSPredicate(format: "id == %@", dto.categoryID as CVarArg)
            guard let category = try context.fetch(categoryRequest).first else {
                throw RepositoryError.entityNotFound
            }
            budget.category = category

            try context.save()
            return budget
        }
    }

    // MARK: - Fetch

    func fetch(id: UUID) async throws -> Budget {
        let predicate = NSPredicate(format: "id == %@", id as CVarArg)
        guard let budget = try fetch(predicate: predicate).first else {
            throw RepositoryError.entityNotFound
        }
        return budget
    }

    func fetchAll() throws -> [Budget] {
        let sortDescriptors = [NSSortDescriptor(keyPath: \Budget.startDate, ascending: false)]
        return try fetch(sortDescriptors: sortDescriptors)
    }

    func fetchActive(for category: Category, on date: Date) async throws -> Budget? {
        let predicate = NSPredicate(
            format: "category == %@ AND startDate <= %@ AND endDate >= %@",
            category, date as NSDate, date as NSDate
        )
        return try fetch(predicate: predicate).first
    }

    // MARK: - Update

    func update(_ budget: Budget, with dto: BudgetUpdateData) async throws {
        return try await performBackgroundTask { context in
            let budgetInContext = context.object(with: budget.objectID) as! Budget

            if let amount = dto.amount {
                budgetInContext.amount = amount
            }
            if let spent = dto.spent {
                budgetInContext.spent = spent
            }
            if let startDate = dto.startDate {
                budgetInContext.startDate = startDate
            }
            if let endDate = dto.endDate {
                budgetInContext.endDate = endDate
            }

            budgetInContext.updatedAt = Date()

            try context.save()
        }
    }

    // MARK: - Delete

    func delete(_ budget: Budget) async throws {
        return try await performBackgroundTask { context in
            let budgetInContext = context.object(with: budget.objectID) as! Budget
            context.delete(budgetInContext)
            try context.save()
        }
    }

    // MARK: - Business Logic

    func recalculateSpent(for budget: Budget) async throws {
        return try await performBackgroundTask { context in
            let budgetInContext = context.object(with: budget.objectID) as! Budget

            // Fetch all transactions for this category in the budget period
            let transactionRequest = Transaction.fetchRequest()
            transactionRequest.predicate = NSPredicate(
                format: "category == %@ AND date >= %@ AND date <= %@",
                budgetInContext.category!,
                budgetInContext.startDate! as NSDate,
                budgetInContext.endDate! as NSDate
            )

            let transactions = try context.fetch(transactionRequest)

            // Calculate total spent
            let totalSpent = transactions
                .filter { $0.type == TransactionType.expense.rawValue }
                .reduce(0.0) { $0 + $1.amount }

            budgetInContext.spent = totalSpent
            budgetInContext.updatedAt = Date()

            try context.save()
        }
    }

    // MARK: - Publisher

    var budgetsPublisher: AnyPublisher<[Budget], Never> {
        NotificationCenter.default
            .publisher(for: .NSManagedObjectContextObjectsDidChange)
            .compactMap { [weak self] _ in
                try? self?.fetchAll()
            }
            .prepend(try! fetchAll())
            .eraseToAnyPublisher()
    }
}
```

### Step 7: Create Service (Optional)

**File:** `OneTap/Core/Services/BudgetService.swift`

```swift
import Foundation

protocol BudgetServiceProtocol {
    func checkBudgetStatus(for transaction: Transaction) async throws -> BudgetStatus
    func updateBudgetsAfterTransaction(_ transaction: Transaction) async throws
}

enum BudgetStatus {
    case ok
    case nearLimit(Budget)
    case exceeded(Budget)
    case noBudget
}

class BudgetService: BudgetServiceProtocol {
    private let budgetRepository: BudgetRepositoryProtocol
    private let transactionRepository: TransactionRepositoryProtocol

    init(
        budgetRepository: BudgetRepositoryProtocol,
        transactionRepository: TransactionRepositoryProtocol
    ) {
        self.budgetRepository = budgetRepository
        self.transactionRepository = transactionRepository
    }

    func checkBudgetStatus(for transaction: Transaction) async throws -> BudgetStatus {
        guard let category = transaction.category else {
            return .noBudget
        }

        guard let budget = try await budgetRepository.fetchActive(for: category, on: transaction.date!) else {
            return .noBudget
        }

        // Recalculate to get latest spending
        try await budgetRepository.recalculateSpent(for: budget)

        if budget.isExceeded {
            return .exceeded(budget)
        } else if budget.isNearLimit {
            return .nearLimit(budget)
        } else {
            return .ok
        }
    }

    func updateBudgetsAfterTransaction(_ transaction: Transaction) async throws {
        guard let category = transaction.category else { return }

        if let budget = try await budgetRepository.fetchActive(for: category, on: transaction.date!) {
            try await budgetRepository.recalculateSpent(for: budget)
        }
    }
}
```

### Step 8: Create ViewModel

**File:** `OneTap/ViewModels/BudgetListViewModel.swift`

```swift
import Foundation
import Combine
import CoreData

@MainActor
class BudgetListViewModel: BaseViewModel {

    // MARK: - Published Properties

    @Published var budgets: [Budget] = []
    @Published var selectedPeriod: BudgetPeriod = .current

    // MARK: - Dependencies

    private let budgetRepository: BudgetRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(budgetRepository: BudgetRepositoryProtocol) {
        self.budgetRepository = budgetRepository
        super.init()
        observeBudgets()
    }

    // MARK: - Observation

    private func observeBudgets() {
        budgetRepository.budgetsPublisher
            .sink { [weak self] budgets in
                self?.budgets = budgets
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    func deleteBudget(_ budget: Budget) async {
        startLoading()
        do {
            try await budgetRepository.delete(budget)
            finishLoading()
        } catch {
            handleError(error)
        }
    }

    func recalculateAll() async {
        startLoading()
        do {
            for budget in budgets {
                try await budgetRepository.recalculateSpent(for: budget)
            }
            finishLoading()
        } catch {
            handleError(error)
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
```

### Step 9: Create Form ViewModel

**File:** `OneTap/ViewModels/BudgetFormViewModel.swift`

```swift
import Foundation
import CoreData

@MainActor
class BudgetFormViewModel: BaseViewModel {

    // MARK: - Form State

    @Published var amount: String = ""
    @Published var selectedCategory: Category?
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date())!

    // MARK: - Dependencies

    private let budgetRepository: BudgetRepositoryProtocol
    private let budget: Budget?

    var isEditing: Bool { budget != nil }

    // MARK: - Init

    init(budgetRepository: BudgetRepositoryProtocol, budget: Budget? = nil) {
        self.budgetRepository = budgetRepository
        self.budget = budget
        super.init()

        if let budget = budget {
            loadBudget(budget)
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

        startLoading()
        do {
            if let budget = budget {
                // Update existing
                let dto = BudgetUpdateData(
                    amount: amountValue,
                    spent: nil,
                    startDate: startDate,
                    endDate: endDate
                )
                try await budgetRepository.update(budget, with: dto)
            } else {
                // Create new
                let dto = BudgetCreateData(
                    amount: amountValue,
                    categoryID: category.id!,
                    startDate: startDate,
                    endDate: endDate
                )
                _ = try await budgetRepository.create(dto)
            }
            finishLoading()
        } catch {
            handleError(error)
        }
    }
}
```

### Step 10: Create Views

**File:** `OneTap/Views/Budget/BudgetListView.swift`

```swift
import SwiftUI
import CoreData

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
    }
}

struct BudgetRow: View {
    let budget: Budget

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: budget.category?.iconName ?? "tag.fill")
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
                        .fill(progressColor)
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
                    .foregroundColor(progressColor)
            }
        }
        .padding(.vertical, 8)
    }

    private var progressColor: Color {
        if budget.isExceeded {
            return AppTheme.expense
        } else if budget.isNearLimit {
            return .orange
        } else {
            return AppTheme.income
        }
    }
}
```

**File:** `OneTap/Views/Budget/BudgetFormView.swift`

```swift
import SwiftUI
import CoreData

struct BudgetFormView: View {
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: BudgetFormViewModel?

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)],
        predicate: NSPredicate(format: "type == %@", TransactionType.expense.rawValue)
    ) private var categories: FetchedResults<Category>

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    Form {
                        Section("Category") {
                            Picker("Category", selection: Binding(
                                get: { viewModel.selectedCategory },
                                set: { viewModel.selectedCategory = $0 }
                            )) {
                                Text("Select Category").tag(nil as Category?)
                                ForEach(categories, id: \.self) { category in
                                    HStack {
                                        Image(systemName: category.iconName)
                                        Text(category.name ?? "Unknown")
                                    }
                                    .tag(category as Category?)
                                }
                            }
                        }

                        Section("Amount") {
                            TextField("Budget Amount", text: Binding(
                                get: { viewModel.amount },
                                set: { viewModel.amount = $0 }
                            ))
                            .keyboardType(.decimalPad)
                        }

                        Section("Period") {
                            DatePicker("Start Date", selection: Binding(
                                get: { viewModel.startDate },
                                set: { viewModel.startDate = $0 }
                            ), displayedComponents: .date)

                            DatePicker("End Date", selection: Binding(
                                get: { viewModel.endDate },
                                set: { viewModel.endDate = $0 }
                            ), displayedComponents: .date)
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
                    .onChange(of: viewModel.loadingState) { _, newState in
                        if newState == .loaded {
                            dismiss()
                        }
                    }
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
}
```

### Step 11: Update DependencyContainer

**File:** `OneTap/Core/DI/DependencyContainer.swift`

```swift
class DependencyContainer: ObservableObject {
    // ... existing code ...

    // MARK: - Budget Repository

    private lazy var budgetRepository: BudgetRepositoryProtocol = {
        BudgetRepository(context: persistenceController.container.viewContext)
    }()

    // MARK: - Budget Service

    private lazy var budgetService: BudgetServiceProtocol = {
        BudgetService(
            budgetRepository: budgetRepository,
            transactionRepository: transactionRepository
        )
    }()

    // MARK: - Budget ViewModels

    func makeBudgetListViewModel() -> BudgetListViewModel {
        BudgetListViewModel(budgetRepository: budgetRepository)
    }

    func makeBudgetFormViewModel(budget: Budget? = nil) -> BudgetFormViewModel {
        BudgetFormViewModel(budgetRepository: budgetRepository, budget: budget)
    }
}
```

### Step 12: Add to Navigation

**File:** `OneTap/Views/MainTabView.swift`

Update MoreTab to include budget link:

```swift
NavigationLink(destination: BudgetListView()) {
    MoreRowContent(icon: "chart.bar.fill", title: "Budgets", color: .green)
}
```

### Step 13: Test the Feature

1. **Build and Run**
   ```bash
   xcodebuild -project OneTap.xcodeproj -scheme OneTap build
   ```

2. **Test CRUD Operations**
   - Create a budget
   - View budget list
   - Edit a budget
   - Delete a budget

3. **Test Business Logic**
   - Add transactions in budget category
   - Verify spent amount updates
   - Check progress bar accuracy
   - Test budget warnings

4. **Test Edge Cases**
   - Create budget with no category
   - Create budget with negative amount
   - Create budget with end date before start date
   - Delete category with active budget

---

## Example: Adding Tags to Transactions

### Quick Implementation (Simpler Feature)

#### Step 1: Update Core Data Model

Add `Tag` entity:
```
Tag:
- id: UUID
- name: String
- color: String
- createdAt: Date

Transaction → tags (To Many, optional)
Tag → transactions (To Many, optional)
```

#### Step 2: Create Tag Model Extension

**File:** `OneTap/Models/TagModel.swift`

```swift
extension Tag {
    var colorView: Color {
        Color(hex: color ?? "#999999")
    }
}
```

#### Step 3: Update TransactionRepository

Add tag management methods:

```swift
extension TransactionRepository {
    func addTag(_ tag: Tag, to transaction: Transaction) async throws {
        try await performBackgroundTask { context in
            let txn = context.object(with: transaction.objectID) as! Transaction
            let tagInContext = context.object(with: tag.objectID) as! Tag
            txn.addToTags(tagInContext)
            try context.save()
        }
    }

    func removeTag(_ tag: Tag, from transaction: Transaction) async throws {
        // Similar implementation
    }
}
```

#### Step 4: Update AddTransactionViewModel

```swift
@MainActor
class AddTransactionViewModel: BaseViewModel {
    // ... existing properties ...

    @Published var selectedTags: Set<Tag> = []

    func addTag(_ tag: Tag) {
        selectedTags.insert(tag)
    }

    func removeTag(_ tag: Tag) {
        selectedTags.remove(tag)
    }
}
```

#### Step 5: Update UI

Add tag picker to `AddTransactionView`:

```swift
Section("Tags") {
    TagPickerView(selectedTags: $viewModel.selectedTags)
}
```

---

## Common Patterns

### Pattern 1: Entity with Computed Properties

```swift
extension Account {
    var displayName: String {
        if let institution = institution, !institution.isEmpty {
            return "\(name ?? "Account") (\(institution))"
        }
        return name ?? "Unnamed Account"
    }

    var isLiability: Bool {
        group == .credit
    }

    var formattedBalance: String {
        let formatter = Formatters.currencyFormatter(for: currency ?? "USD")
        return formatter.string(from: NSNumber(value: balance)) ?? "$0.00"
    }
}
```

### Pattern 2: Repository with Publisher

```swift
class MyRepository: BaseRepository<MyEntity> {
    var entitiesPublisher: AnyPublisher<[MyEntity], Never> {
        NotificationCenter.default
            .publisher(for: .NSManagedObjectContextObjectsDidChange)
            .compactMap { [weak self] _ in
                try? self?.fetchAll()
            }
            .prepend(try! fetchAll())
            .eraseToAnyPublisher()
    }
}
```

### Pattern 3: Service with Complex Logic

```swift
class MyService {
    private let repository1: Repository1Protocol
    private let repository2: Repository2Protocol

    func performComplexOperation() async throws {
        // Step 1: Fetch data
        let data1 = try await repository1.fetchAll()
        let data2 = try await repository2.fetchAll()

        // Step 2: Process
        let results = processData(data1, data2)

        // Step 3: Save
        for result in results {
            try await repository1.save(result)
        }

        // Step 4: Notify
        NotificationCenter.default.post(name: .myOperationCompleted, object: nil)
    }
}
```

### Pattern 4: ViewModel with Form Validation

```swift
@MainActor
class MyFormViewModel: BaseViewModel {
    @Published var field1: String = ""
    @Published var field2: String = ""

    var isValid: Bool {
        !field1.isEmpty && !field2.isEmpty
    }

    var field1Error: String? {
        guard !field1.isEmpty else { return "Field 1 is required" }
        guard field1.count >= 3 else { return "Minimum 3 characters" }
        return nil
    }

    func save() async {
        guard isValid else { return }

        startLoading()
        do {
            // Save logic
            finishLoading()
        } catch {
            handleError(error)
        }
    }
}
```

### Pattern 5: View with Lazy ViewModel Init

```swift
struct MyView: View {
    @EnvironmentObject private var container: DependencyContainer
    @State private var viewModel: MyViewModel?

    var body: some View {
        Group {
            if let viewModel {
                // UI content
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = container.makeMyViewModel()
            }
        }
    }
}
```

---

## Testing Your Feature

### Unit Test Template

```swift
import XCTest
@testable import OneTap

@MainActor
class MyViewModelTests: XCTestCase {
    var sut: MyViewModel!
    var mockRepository: MockMyRepository!

    override func setUp() {
        super.setUp()
        mockRepository = MockMyRepository()
        sut = MyViewModel(repository: mockRepository)
    }

    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }

    func testLoadData() async {
        // Given
        let expectedData = [MyEntity(), MyEntity()]
        mockRepository.dataToReturn = expectedData

        // When
        await sut.loadData()

        // Then
        XCTAssertEqual(sut.data.count, 2)
        XCTAssertEqual(mockRepository.fetchCallCount, 1)
    }

    func testSaveData_Success() async {
        // Given
        sut.field1 = "Test"
        sut.field2 = "Data"

        // When
        await sut.save()

        // Then
        XCTAssertEqual(sut.loadingState, .loaded)
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(mockRepository.saveCallCount, 1)
    }

    func testSaveData_Failure() async {
        // Given
        sut.field1 = "Test"
        mockRepository.shouldFail = true

        // When
        await sut.save()

        // Then
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertEqual(mockRepository.saveCallCount, 1)
    }
}
```

### Integration Test Template

```swift
import XCTest
@testable import OneTap

class MyFeatureIntegrationTests: XCTestCase {
    var persistenceController: PersistenceController!
    var repository: MyRepository!
    var service: MyService!

    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        repository = MyRepository(context: persistenceController.container.viewContext)
        service = MyService(repository: repository)
    }

    func testEndToEndFlow() async throws {
        // Given: Create test data
        let account = createTestAccount()

        // When: Perform operation
        try await service.performOperation(on: account)

        // Then: Verify results
        let result = try await repository.fetch(id: account.id!)
        XCTAssertNotNil(result)
        XCTAssertEqual(result.someField, expectedValue)
    }
}
```

---

## Code Review Checklist

Before submitting your feature:

### Architecture
- [ ] Follows MVVM pattern
- [ ] Services contain business logic, not repositories
- [ ] ViewModels don't access Core Data directly
- [ ] Views are stateless (state in ViewModels)

### Code Quality
- [ ] No force unwraps (`!`) except in tests or previews
- [ ] Proper error handling (no empty `catch` blocks)
- [ ] All async functions use `async/await`, not completion handlers
- [ ] Thread safety: Core Data on correct threads

### Testing
- [ ] Unit tests for ViewModel logic
- [ ] Integration tests for complex flows
- [ ] Edge cases covered
- [ ] Error cases tested

### Performance
- [ ] No blocking operations on main thread
- [ ] Publishers properly managed (no retain cycles)
- [ ] Core Data fetch requests have predicates
- [ ] Batch operations use background contexts

### UI/UX
- [ ] Loading states shown during async operations
- [ ] Error messages user-friendly
- [ ] Empty states handled gracefully
- [ ] Navigation flows make sense

### Documentation
- [ ] Public methods documented
- [ ] Complex logic explained with comments
- [ ] CLAUDE.md updated if patterns changed

---

## Additional Resources

- **SwiftUI Documentation:** https://developer.apple.com/documentation/swiftui
- **Core Data Guide:** https://developer.apple.com/documentation/coredata
- **Combine Framework:** https://developer.apple.com/documentation/combine
- **Swift Concurrency:** https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html

---

**Last Updated:** 2026-01-02
**Version:** 1.0
