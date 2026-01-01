//
//  DEVELOPMENT_GUIDE.md
//  OneTap
//
//  Quick Reference for Developers
//

# OneTap Development Guide

## Architecture Overview
OneTap uses **MVVM + Repository + Dependency Injection**.
- **Do not** put logic in Views.
- **Do not** use `@FetchRequest` for complex data logic (use Repositories).
- **Do not** instantiate ViewModels directly (use `DependencyContainer`).

## Quick Start Checklist

### Adding a New Feature
1. **Define Entity**: Add to `.xcdatamodeld`.
2. **Create Model**: Add extension in `Models/`.
3. **Create Repository**: Add `[Feature]Repository.swift` in `Core/Repositories`.
4. **Register in DI**: Add to `DependencyContainer.swift`.
5. **Create ViewModel**: Add `[Feature]ViewModel.swift`.
6. **Create View**: Add `[Feature]View.swift` and inject ViewModel.

## Common Tasks

### 1. Creating a New View with MVVM

**Step 1: Define the ViewModel**
```swift
class MyFeatureViewModel: ObservableObject {
    @Published var items: [Item] = []
    private let repository: MyFeatureRepository
    
    init(repository: MyFeatureRepository) {
        self.repository = repository
        loadData()
    }
    
    func loadData() {
        items = repository.fetchAll()
    }
}
```

**Step 2: Add Factory Method to DependencyContainer**
```swift
// Core/DI/DependencyContainer.swift
func makeMyFeatureViewModel() -> MyFeatureViewModel {
    MyFeatureViewModel(repository: myFeatureRepository)
}
```

**Step 3: Create the View**
```swift
struct MyFeatureView: View {
    @EnvironmentObject private var container: DependencyContainer
    @StateObject private var viewModel: MyFeatureViewModel
    
    init() {
        // Use a temporary container for initialization if needed, 
        // but typically the parent view creates the VM or we use the container
        let tempContainer = DependencyContainer()
        _viewModel = StateObject(wrappedValue: tempContainer.makeMyFeatureViewModel())
    }
    
    var body: some View {
        List(viewModel.items) { item in
            Text(item.name)
        }
    }
}
```

### 2. Fetching Data (Repository Pattern)

**Do not** use `NSFetchRequest` directly in ViewModels. Use the Repository.

```swift
// TransactionRepository.swift
func fetchTransactions(category: Category?) -> [Transaction] {
    var predicate: NSPredicate?
    if let category = category {
        predicate = NSPredicate(format: "category == %@", category)
    }
    return fetch(predicate: predicate, sortDescriptors: [...])
}
```

### 3. Saving Data

Delegate to the ViewModel, which calls the Repository.

```swift
// ViewModel
func save() async {
    loadingState = .loading
    do {
        try await repository.create(...)
        loadingState = .loaded
    } catch {
        errorMessage = error.localizedDescription
    }
}

// View
Button("Save") {
    Task {
        await viewModel.save()
    }
}
```

### 4. Handling Dependencies

Use `DependencyContainer` to access services.

```swift
// Inside DependencyContainer
let balanceService: BalanceService
let transferService: TransferService

init() {
    self.balanceService = BalanceService(...)
    self.transferService = TransferService(..., balanceService: balanceService)
}
```

## Naming Conventions

- **Views**: `[Feature]View` (e.g., `AccountListView`)
- **ViewModels**: `[Feature]ViewModel` (e.g., `AccountListViewModel`)
- **Repositories**: `[Entity]Repository` (e.g., `AccountRepository`)
- **Services**: `[Action]Service` (e.g., `TransferService`)

## Testing with Previews

Use the `preview` static property on `DependencyContainer` (or `PersistenceController`) if available, or create a mock container.

```swift
#Preview {
    let container = DependencyContainer(persistenceController: .preview)
    return MyView()
        .environmentObject(container)
}
```

## Code Style

- **Imports**: Import `SwiftUI` only in Views. Import `CoreData` in Repositories/Models.
- **Access Control**: Use `private` for internal ViewModel properties.
- **Concurrency**: Use `async/await` for long-running operations.

## Debugging

- **Core Data**: Enable `-com.apple.CoreData.SQLDebug 1` scheme argument to see SQL queries.
- **Dependency Graph**: Check `DependencyContainer` init to trace dependency chains.