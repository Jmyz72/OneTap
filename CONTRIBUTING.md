# Contributing to OneTap

Thank you for your interest in contributing to OneTap! This document provides guidelines and standards for contributing to the project.

## Table of Contents

- [Getting Started](#getting-started)
- [Code Standards](#code-standards)
- [Git Workflow](#git-workflow)
- [Pull Request Process](#pull-request-process)
- [Code Review Guidelines](#code-review-guidelines)

---

## Getting Started

### Prerequisites

1. Read all documentation:
   - [BUILD_GUIDE.md](BUILD_GUIDE.md) - Project setup
   - [ARCHITECTURE_GUIDE.md](ARCHITECTURE_GUIDE.md) - Architecture overview
   - [FEATURE_IMPLEMENTATION_GUIDE.md](FEATURE_IMPLEMENTATION_GUIDE.md) - Implementation patterns

2. Set up your development environment:
   ```bash
   # Clone the repository
   git clone <repository-url>
   cd OneTap

   # Ensure it builds
   xcodebuild -project OneTap.xcodeproj -scheme OneTap build
   ```

3. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

---

## Code Standards

### Swift Style Guide

Follow the [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/).

#### Naming Conventions

```swift
// ✅ DO: Use clear, descriptive names
class AccountRepository: BaseRepository<Account> { }
func calculateRunningBalance(for account: Account) -> Double { }
var isAccountActive: Bool { }

// ❌ DON'T: Use abbreviations or unclear names
class AcctRepo { }
func calcBal() -> Double { }
var act: Bool { }
```

#### File Organization

```swift
// File structure should follow this order:

// 1. Imports
import Foundation
import Combine

// 2. Type Definition
class MyViewModel: BaseViewModel {

    // 3. MARK: - Properties (grouped by access level)

    // MARK: - Published Properties
    @Published var items: [Item] = []

    // MARK: - Private Properties
    private let repository: MyRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()

    // 4. MARK: - Initialization
    init(repository: MyRepositoryProtocol) {
        self.repository = repository
        super.init()
    }

    // 5. MARK: - Public Methods
    func loadItems() async { }

    // 6. MARK: - Private Methods
    private func observeItems() { }
}

// 7. MARK: - Extensions
extension MyViewModel {
    // Related functionality
}
```

### SwiftUI Best Practices

#### View Structure

```swift
// ✅ DO: Extract complex views into computed properties or separate files
struct AccountListView: View {
    var body: some View {
        List {
            headerSection
            accountsSection
        }
    }

    private var headerSection: some View {
        // Complex header UI
    }

    private var accountsSection: some View {
        // Complex accounts UI
    }
}

// ❌ DON'T: Put everything in body
struct AccountListView: View {
    var body: some View {
        List {
            // 200 lines of inline code...
        }
    }
}
```

#### State Management

```swift
// ✅ DO: Use appropriate property wrappers
struct MyView: View {
    @EnvironmentObject private var container: DependencyContainer  // Injected dependencies
    @State private var viewModel: MyViewModel?                      // ViewModel
    @State private var showingSheet = false                         // View-only state
}

// ❌ DON'T: Mix state management
struct MyView: View {
    @StateObject var viewModel: MyViewModel  // Should be @State with optional
    @State var repository: MyRepository      // Should be in ViewModel
}
```

### MVVM Pattern

#### ViewModel Guidelines

```swift
// ✅ DO: Keep ViewModels focused and testable
@MainActor
class AccountListViewModel: BaseViewModel {
    @Published var accounts: [Account] = []

    private let accountRepository: AccountRepositoryProtocol

    init(accountRepository: AccountRepositoryProtocol) {
        self.accountRepository = accountRepository
        super.init()
    }

    func loadAccounts() async {
        // Simple, testable logic
    }
}

// ❌ DON'T: Put UI logic in ViewModels
@MainActor
class BadViewModel: BaseViewModel {
    var navigationTitle: String { "Accounts" }  // UI concern
    var buttonColor: Color { .blue }            // UI concern

    func presentSheet() { }  // View concern
}
```

### Core Data Best Practices

#### Thread Safety

```swift
// ✅ DO: Use background contexts for heavy operations
func importData() async throws {
    try await performBackgroundTask { context in
        // Heavy work on background thread
        let objects = parseCSV()
        for obj in objects {
            createEntity(obj, context: context)
        }
        try context.save()
    }
}

// ❌ DON'T: Block main thread
func importDataBad() {
    for obj in parseCSV() {  // Blocks UI!
        createEntity(obj, context: viewContext)
    }
    try! viewContext.save()
}
```

#### Managed Object Handling

```swift
// ✅ DO: Pass ObjectIDs across threads
Task.detached {
    let accountID = account.objectID
    let bgContext = container.newBackgroundContext()
    let bgAccount = bgContext.object(with: accountID) as! Account
    // Work with bgAccount
}

// ❌ DON'T: Pass managed objects across threads
Task.detached {
    account.balance = 100  // CRASH! Wrong thread
}
```

### Error Handling

```swift
// ✅ DO: Use specific, localized errors
enum ValidationError: LocalizedError {
    case emptyField(String)
    case invalidAmount

    var errorDescription: String? {
        switch self {
        case .emptyField(let field):
            return "\(field) cannot be empty."
        case .invalidAmount:
            return "Please enter a valid amount."
        }
    }
}

// ✅ DO: Handle errors gracefully in ViewModels
func saveData() async {
    startLoading()
    do {
        try await repository.save(data)
        finishLoading()
    } catch {
        handleError(error)  // Shows user-friendly message
    }
}

// ❌ DON'T: Ignore errors or use force-try
func saveDataBad() {
    try! repository.save(data)  // Will crash on error
}

// ❌ DON'T: Use empty catch blocks
do {
    try riskyOperation()
} catch {
    // Silent failure - bad!
}
```

### Async/Await

```swift
// ✅ DO: Use async/await for asynchronous operations
func fetchData() async throws -> [Item] {
    let items = try await repository.fetchAll()
    return items
}

// ✅ DO: Run parallel operations concurrently
func fetchAllData() async throws {
    async let accounts = accountRepository.fetchAll()
    async let transactions = transactionRepository.fetchAll()

    let (a, t) = try await (accounts, transactions)
    // Process results
}

// ❌ DON'T: Use completion handlers
func fetchDataOld(completion: @escaping (Result<[Item], Error>) -> Void) {
    // Old pattern, avoid
}

// ❌ DON'T: Run sequential operations when they could be parallel
func fetchAllDataSlow() async throws {
    let accounts = try await accountRepository.fetchAll()
    let transactions = try await transactionRepository.fetchAll()
    // Slower - operations run sequentially
}
```

### Comments and Documentation

```swift
// ✅ DO: Document public APIs and complex logic
/// Recalculates running balances for all transactions in an account.
///
/// This method:
/// 1. Fetches all transactions sorted by date
/// 2. Calculates cumulative balance for each transaction
/// 3. Updates the `balanceAfter` field
/// 4. Saves changes to Core Data
///
/// - Parameters:
///   - accountID: The managed object ID of the account
///   - date: Optional start date (recalculates from this date forward)
/// - Throws: `ServiceError.balanceCalculationFailed` if operation fails
func recalculateBalances(for accountID: NSManagedObjectID, from date: Date?) async throws {
    // Implementation
}

// ✅ DO: Explain non-obvious code
// Calculate balance impact based on transaction type
// Expenses and transfers decrease balance, income increases it
var balanceImpact: Double {
    switch typeEnum {
    case .expense, .transfer: return -amount
    case .income, .adjustment: return amount
    }
}

// ❌ DON'T: State the obvious
// Set the name
account.name = "My Account"

// ❌ DON'T: Leave commented-out code
// let oldValue = calculateOldWay()  // Remove this!
let newValue = calculateNewWay()
```

### Testing

```swift
// ✅ DO: Write unit tests for ViewModels
@MainActor
class AccountListViewModelTests: XCTestCase {
    var sut: AccountListViewModel!
    var mockRepository: MockAccountRepository!

    override func setUp() {
        mockRepository = MockAccountRepository()
        sut = AccountListViewModel(accountRepository: mockRepository)
    }

    func testLoadAccounts_Success() async {
        // Given
        mockRepository.accountsToReturn = [Account(), Account()]

        // When
        await sut.loadAccounts()

        // Then
        XCTAssertEqual(sut.accounts.count, 2)
        XCTAssertNil(sut.errorMessage)
    }
}

// ✅ DO: Test error cases
func testLoadAccounts_Failure() async {
    // Given
    mockRepository.shouldFail = true

    // When
    await sut.loadAccounts()

    // Then
    XCTAssertNotNil(sut.errorMessage)
}
```

---

## Git Workflow

### Branch Naming

Use descriptive branch names with prefixes:

```bash
feature/budget-tracking
bugfix/balance-calculation
refactor/repository-layer
docs/architecture-guide
```

### Commit Messages

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code refactoring
- `docs`: Documentation changes
- `test`: Adding tests
- `chore`: Maintenance tasks

**Examples:**

```bash
# Good commit messages
git commit -m "feat(budgets): add monthly budget tracking

- Add Budget Core Data entity
- Create BudgetRepository and BudgetService
- Implement BudgetListView and BudgetFormView
- Add budget progress indicators

Closes #123"

git commit -m "fix(balance): correct transfer balance calculation

Previously, transfers weren't updating both account balances.
Now properly recalculates balances for source and destination.

Fixes #456"

git commit -m "refactor(viewmodels): extract common loading state

Moved loading state management to BaseViewModel to reduce
duplication across all ViewModels."

# Bad commit messages
git commit -m "updates"
git commit -m "fix bug"
git commit -m "WIP"
```

### Commit Frequency

- Commit logical units of work
- Don't commit broken code to main branches
- Squash "fix typo" or "oops" commits before merging

---

## Pull Request Process

### Before Creating a PR

1. **Ensure code compiles:**
   ```bash
   xcodebuild -project OneTap.xcodeproj -scheme OneTap build
   ```

2. **Run tests (when available):**
   ```bash
   xcodebuild test -project OneTap.xcodeproj -scheme OneTap
   ```

3. **Format code:**
   - Use consistent indentation (4 spaces)
   - Remove trailing whitespace
   - Organize imports alphabetically

4. **Update documentation:**
   - Add/update inline comments
   - Update CLAUDE.md if patterns changed
   - Update relevant guide files

### PR Template

```markdown
## Description
Brief description of what this PR does.

## Type of Change
- [ ] New feature
- [ ] Bug fix
- [ ] Refactoring
- [ ] Documentation
- [ ] Other (specify)

## Changes Made
- Added BudgetRepository for budget data access
- Created BudgetListViewModel for state management
- Implemented BudgetListView and BudgetFormView
- Updated DependencyContainer with budget factories

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] Manual testing completed
- [ ] All tests passing

## Screenshots (if applicable)
[Add screenshots of UI changes]

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No new warnings introduced
- [ ] Branch up to date with main

## Related Issues
Closes #123
Related to #456
```

### PR Size Guidelines

- **Small PRs** (< 200 lines): Ideal, quick to review
- **Medium PRs** (200-500 lines): Acceptable
- **Large PRs** (> 500 lines): Break into smaller PRs if possible

If a large PR is unavoidable:
- Clearly document the changes
- Provide a detailed description
- Consider breaking into multiple commits with clear messages

---

## Code Review Guidelines

### For Authors

**Before Requesting Review:**
- [ ] Self-review your code
- [ ] Check for typos and formatting
- [ ] Verify all tests pass
- [ ] Update documentation
- [ ] Add inline comments for complex logic

**During Review:**
- Respond to all comments
- Ask questions if feedback is unclear
- Make requested changes promptly
- Re-request review after changes

### For Reviewers

**What to Look For:**

1. **Architecture Compliance:**
   - Follows MVVM pattern
   - Proper layer separation
   - Dependency injection used correctly

2. **Code Quality:**
   - Readable and maintainable
   - No code smells (long functions, god objects, etc.)
   - Appropriate use of Swift features

3. **Error Handling:**
   - All errors handled gracefully
   - User-friendly error messages
   - No force-unwrapping in production code

4. **Performance:**
   - No blocking operations on main thread
   - Efficient Core Data usage
   - No retain cycles or memory leaks

5. **Testing:**
   - Unit tests for new logic
   - Edge cases covered
   - Error cases tested

**How to Give Feedback:**

```markdown
# ✅ Good Feedback: Specific and constructive
This function blocks the main thread. Consider using `performBackgroundTask`
to run this on a background context. Example:

```swift
try await performBackgroundTask { context in
    // Heavy work here
}
```

# ❌ Bad Feedback: Vague or negative
This code is bad. Rewrite it.
```

**Approval Criteria:**
- ✅ Code meets standards
- ✅ Tests pass and cover new code
- ✅ Documentation updated
- ✅ No major architectural concerns
- ✅ Performance acceptable

---

## Code Quality Tools

### SwiftLint (Recommended)

Install SwiftLint for automated style checking:

```bash
brew install swiftlint

# Run in project directory
swiftlint
```

Create `.swiftlint.yml` in project root:

```yaml
disabled_rules:
  - trailing_whitespace
  - line_length

opt_in_rules:
  - empty_count
  - force_unwrapping

excluded:
  - Pods
  - DerivedData

line_length:
  warning: 120
  error: 200
```

### Xcode Build Settings

Recommended warnings to enable:

- Treat Warnings as Errors (in CI only)
- Unused Variables
- Unused Functions
- Unused Parameters
- Implicit Retain of 'self'

---

## Documentation Standards

### Inline Documentation

Use Swift's documentation comments:

```swift
/// Calculates the running balance for an account.
///
/// This method processes all transactions chronologically and updates
/// the `balanceAfter` field for each transaction.
///
/// - Parameters:
///   - account: The account to calculate balances for
///   - startDate: Optional date to start calculation from
/// - Returns: The final account balance
/// - Throws: `ServiceError.balanceCalculationFailed` if calculation fails
func calculateBalance(for account: Account, from startDate: Date?) async throws -> Double {
    // Implementation
}
```

### File Headers

Every file should include:

```swift
//
//  AccountListViewModel.swift
//  OneTap
//
//  Created by [Author] on [Date].
//

import Foundation
```

### README Updates

When adding major features, update appropriate documentation:

- CLAUDE.md - Project-specific patterns
- ARCHITECTURE_GUIDE.md - Architecture changes
- FEATURE_IMPLEMENTATION_GUIDE.md - New patterns

---

## Performance Guidelines

### Core Data Performance

```swift
// ✅ DO: Use predicates to filter data
let predicate = NSPredicate(format: "account == %@", account)
let transactions = try repository.fetch(predicate: predicate)

// ❌ DON'T: Fetch everything and filter in code
let allTransactions = try repository.fetchAll()
let filtered = allTransactions.filter { $0.account == account }

// ✅ DO: Use batch operations
context.perform {
    for item in items {
        // Process item
    }
    try context.save()
}

// ❌ DON'T: Save after each item
for item in items {
    // Process item
    try context.save()  // Slow!
}
```

### Memory Management

```swift
// ✅ DO: Use weak self in closures
repository.publisher
    .sink { [weak self] items in
        self?.items = items
    }
    .store(in: &cancellables)

// ❌ DON'T: Create retain cycles
repository.publisher
    .sink { items in
        self.items = items  // Retain cycle!
    }
    .store(in: &cancellables)

// ✅ DO: Cancel subscriptions
deinit {
    cancellables.forEach { $0.cancel() }
}
```

### UI Performance

```swift
// ✅ DO: Use lazy stacks for large lists
LazyVStack {
    ForEach(items) { item in
        ItemRow(item: item)
    }
}

// ❌ DON'T: Use regular stacks for large lists
VStack {  // Loads all items at once!
    ForEach(thousandsOfItems) { item in
        ItemRow(item: item)
    }
}
```

---

## Security Guidelines

### Never Commit Secrets

```bash
# Add to .gitignore
.env
Secrets.swift
*.key
*.pem
```

### Sensitive Data

- Don't log sensitive user data
- Use Keychain for sensitive storage
- Encrypt data at rest when necessary

---

## Questions?

If you have questions about contributing:

1. Check the documentation in this repository
2. Review existing code for patterns
3. Open a GitHub Discussion
4. Contact the maintainers

---

**Thank you for contributing to OneTap!**

Last Updated: 2026-01-02
