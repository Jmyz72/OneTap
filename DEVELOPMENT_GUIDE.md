//
//  DEVELOPMENT_GUIDE.md
//  OneTap
//
//  Quick Reference for Developers
//

# OneTap Development Guide

## Quick Start Checklist

### Adding a New Transaction Category
1. Add case to `TransactionCategory` enum in `Models/TransactionModel.swift`
2. Add icon mapping in `icon` computed property
3. Add color case in `TransactionRow.swift` → `categoryColor`

### Adding a New Feature Module (e.g., Budget Tracking)

**1. Create Model**
```swift
// Models/BudgetModel.swift
enum BudgetPeriod: String, CaseIterable {
    case monthly = "Monthly"
    case yearly = "Yearly"
}

extension Budget {
    var remainingAmount: Double {
        amount - spentAmount
    }
}
```

**2. Update Core Data Model**
- Open `OneTap.xcdatamodeld/OneTap.xcdatamodel/contents`
- Add new entity with attributes
- Regenerate if needed

**3. Create Views Folder**
```
Views/Budget/
├── BudgetListView.swift
├── AddBudgetView.swift
└── BudgetDetailView.swift
```

**4. Create Shared Components (if needed)**
```
Views/Shared/
└── BudgetRow.swift
```

**5. Update MainTabView**
```swift
BudgetTab()
    .tabItem {
        Label("Budget", systemImage: "chart.bar.fill")
    }
```

### Adding a New View

**Template:**
```swift
//
//  MyNewView.swift
//  OneTap
//
//  Created by [Your Name] on [Date].
//

import SwiftUI

struct MyNewView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var myState: String = ""
    
    var body: some View {
        NavigationStack {
            // Your UI here
        }
        .navigationTitle("Title")
    }
}

#Preview {
    MyNewView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
```

## Common Tasks

### Fetching Transactions
```swift
@FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Transaction.date, ascending: false)],
    animation: .default
)
private var transactions: FetchedResults<Transaction>
```

### Fetching with Filter
```swift
@FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Transaction.date, ascending: false)],
    predicate: NSPredicate(format: "category == %@", "Food"),
    animation: .default
)
private var foodTransactions: FetchedResults<Transaction>
```

### Saving Data
```swift
let newTransaction = Transaction(context: viewContext)
newTransaction.id = UUID()
newTransaction.title = "Coffee"
newTransaction.amount = 5.50
// ... set other properties

do {
    try viewContext.save()
} catch {
    print("Error: \(error)")
}
```

### Deleting Data
```swift
viewContext.delete(transaction)

do {
    try viewContext.save()
} catch {
    print("Error: \(error)")
}
```

## Formatting Helpers

### Currency
```swift
// Use Transaction extension
transaction.formattedAmount  // "$123.45"

// Or use Formatters
Formatters.currency.string(from: NSNumber(value: amount))
```

### Dates
```swift
// Use Transaction extension
transaction.formattedDate  // "Jan 15, 2025"

// Or use Formatters
Formatters.date.string(from: date)
Formatters.shortDate.string(from: date)
Formatters.monthYear.string(from: date)
```

## Working with Categories

### Get Category Enum
```swift
if let category = transaction.categoryEnum {
    Image(systemName: category.icon)
    Text(category.rawValue)
}
```

### Filter by Category
```swift
let predicate = NSPredicate(
    format: "category == %@", 
    TransactionCategory.food.rawValue
)
```

## Color Coding

### By Category
See `TransactionRow.swift` → `categoryColor` for the mapping

### By Type (Income/Expense)
```swift
.foregroundStyle(transaction.amount >= 0 ? .red : .green)
```

## Testing with Preview Data

### Using Preview Controller
```swift
#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
```

### Creating Custom Preview Data
```swift
@MainActor
static let customPreview: PersistenceController = {
    let result = PersistenceController(inMemory: true)
    let viewContext = result.container.viewContext
    
    // Add your custom data here
    
    try? viewContext.save()
    return result
}()
```

## Common Patterns

### Modal Sheet
```swift
@State private var showingSheet = false

Button("Show") {
    showingSheet = true
}
.sheet(isPresented: $showingSheet) {
    MyView()
}
```

### Navigation
```swift
NavigationLink(destination: DetailView(transaction: transaction)) {
    TransactionRow(transaction: transaction)
}
```

### Conditional View
```swift
Group {
    if items.isEmpty {
        EmptyStateView()
    } else {
        ListView()
    }
}
```

## Environment Values

### Available in All Views
```swift
@Environment(\.managedObjectContext) private var viewContext
@Environment(\.dismiss) private var dismiss
@Environment(\.colorScheme) private var colorScheme
```

## File Naming Conventions

- Views: `[Feature]View.swift` (e.g., `AddTransactionView.swift`)
- Models: `[Feature]Model.swift` (e.g., `TransactionModel.swift`)
- Rows/Components: `[Feature]Row.swift` (e.g., `TransactionRow.swift`)
- Extensions: `[Type]Extension.swift` (e.g., `FormattersExtension.swift`)

## Code Style

### SwiftUI View Hierarchy
```swift
var body: some View {
    NavigationStack {
        List {
            ForEach(items) { item in
                ItemRow(item: item)
            }
        }
        .navigationTitle("Title")
        .toolbar {
            // toolbar items
        }
    }
}
```

### Extracting Subviews
When `body` gets complex:
```swift
var body: some View {
    NavigationStack {
        mainContent
            .navigationTitle("Title")
    }
}

private var mainContent: some View {
    List {
        // content
    }
}
```

## Debugging Tips

### Print Core Data Objects
```swift
print(transaction)
print("Title: \(transaction.title ?? "nil")")
```

### Check Save Errors
```swift
do {
    try viewContext.save()
} catch {
    print("Save error: \(error)")
    print("Details: \(error.localizedDescription)")
}
```

### Preview Crashes
- Check Core Data model matches entity usage
- Verify preview data is valid
- Check for force-unwrapped optionals

## Performance Tips

### Lazy Loading
```swift
List {
    LazyVStack {
        // For custom layouts
    }
}
```

### Limit Fetch Results
```swift
@FetchRequest(
    sortDescriptors: [...],
    animation: .default
)
private var transactions: FetchedResults<Transaction>

var limitedTransactions: [Transaction] {
    Array(transactions.prefix(100))
}
```

### Background Context for Heavy Operations
```swift
let backgroundContext = persistenceController.container.newBackgroundContext()
backgroundContext.perform {
    // Heavy work here
    try? backgroundContext.save()
}
```

## Next Steps for New Features

### 1. Assets/Portfolio Tracking
- Create `Asset` entity
- Create `AssetModel.swift`
- Create views in `Views/Asset/`
- Add to `AssetsTab` in `MainTabView`

### 2. Budget Management
- Create `Budget` entity
- Create `BudgetModel.swift`
- Create views in `Views/Budget/`
- Add progress indicators

### 3. Analytics/Overview
- Create calculation utilities
- Create chart views
- Add to `OverviewTab`
- Consider using Swift Charts

### 4. Settings
- Create `SettingsView.swift`
- Add UserDefaults for preferences
- Update `MoreTab`

## Resources

- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Core Data Documentation](https://developer.apple.com/documentation/coredata)
- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)

## Getting Help

1. Check `ARCHITECTURE.md` for design decisions
2. Review similar existing features
3. Check SwiftUI documentation
4. Test with preview data first

---

Happy coding! 🚀
