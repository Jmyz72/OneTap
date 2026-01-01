# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

**Open Project:**
```bash
open OneTap.xcodeproj
```

Run in Xcode using ⌘R or build using ⌘B. The project requires iOS 16+ and uses SwiftUI.

**Testing with Preview Data:**
All SwiftUI views include `#Preview` blocks. Use `PersistenceController.preview` for sample data when creating previews.

## Core Architecture

### Data Layer - Core Data with Balance Tracking

OneTap uses Core Data with a critical feature: **running balance tracking**. Every transaction stores `balanceAfter` to maintain account balances.

**Key Entities:**
- **Transaction**: Stores financial transactions with `balanceAfter` field
- **TransactionItem**: Split transaction items (e.g., one breakfast payment split into food + drink)
- **Account**: Bank accounts, credit cards, cash (balance auto-updates via `balanceAfter`)
- **Category**: User-editable categories with icons and colors
- **SubCategory**: Optional sub-categorization

**Balance Recalculation:**
The `PersistenceController.recalculateBalances(for:from:)` method runs on a background thread to update running balances. Call this after modifying transactions that affect account balances.

```swift
// After creating/modifying a transaction
if let accountID = transaction.account?.objectID {
    PersistenceController.shared.recalculateBalances(for: accountID, from: transaction.date)
}
```

### Transaction Types

```swift
enum TransactionType {
    case expense    // Money out
    case income     // Money in
    case transfer   // Between accounts (creates paired transactions)
    case adjustment // Balance correction
}
```

**Transfer Logic:** A transfer creates TWO transactions:
1. Transfer (expense) from source account
2. Income to destination account
These are linked via `relatedTransactionID`.

### Category System

Categories are **user-editable** and seeded with defaults on first launch:
- Each category has: name, icon (SF Symbol), color (hex), type (expense/income)
- Modify via Settings → Categories
- Default categories are seeded in `Category.seedDefaults(context:)`

### Split Transactions

Transactions can optionally contain multiple `TransactionItem` entities:
- The transaction itself is the "parent" record shown in lists
- Items are hidden by default, shown only in detail view
- If no items exist, the transaction itself acts as a single item
- Item amounts should sum to transaction amount

## File Organization

```
OneTap/
├── Models/                    # Data models & Core Data extensions
│   ├── TransactionModel.swift # Transaction types & extensions
│   ├── CategoryModel.swift    # Category extensions & defaults
│   ├── AccountModel.swift     # Account types & extensions
│   └── SubCategoryModel.swift
├── Views/
│   ├── MainTabView.swift      # Root 4-tab navigation
│   ├── Transaction/           # Transaction feature views
│   ├── Account/               # Account management views
│   ├── Settings/              # Settings & category management
│   └── Shared/                # Reusable components
├── Core/
│   ├── Data/
│   │   └── Persistence.swift  # Core Data stack & balance recalculation
│   ├── Extensions/
│   │   └── FormattersExtension.swift # Currency & date formatters
│   ├── Theme/
│   │   └── IconLibrary.swift  # SF Symbol icon mappings
│   └── Settings/
│       └── SettingsManager.swift # UserDefaults wrapper
└── OneTap.xcdatamodeld/       # Core Data schema
```

## Key Patterns

### Currency Formatting

Always use `Formatters.currencyFormatter(for:)` which respects the account's currency or falls back to `SettingsManager.shared.currencyCode`.

```swift
// Transaction extension provides formatted amount
transaction.formattedAmount  // "-$12.50" or "+$100.00"

// Or format manually
let formatter = Formatters.currencyFormatter(for: currencyCode)
formatter.string(from: NSNumber(value: amount))
```

### Core Data Fetching

```swift
@FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Transaction.date, ascending: false)],
    predicate: NSPredicate(format: "account == %@", account),
    animation: .default
)
private var transactions: FetchedResults<Transaction>
```

### Adding a New Transaction

```swift
let newTransaction = Transaction(context: viewContext)
newTransaction.id = UUID()
newTransaction.title = "Coffee"
newTransaction.amount = 5.50
newTransaction.date = Date()
newTransaction.type = TransactionType.expense.rawValue
newTransaction.account = selectedAccount
newTransaction.category = selectedCategory
newTransaction.createdAt = Date()
newTransaction.updatedAt = Date()

try viewContext.save()

// Update running balances
if let accountID = selectedAccount.objectID {
    PersistenceController.shared.recalculateBalances(for: accountID, from: Date())
}
```

## Design Philosophy (from TransactionFeaturesGuide.md)

1. **One payment = one record**: Each transaction represents a single real-world payment
2. **Effortless and opinionated**: Defaults should "just work" without setup
3. **Details are optional**: Only title, amount, and date are required
4. **Categories are flexible**: User can add, rename, reorder, or hide categories
5. **Merchant is free-text**: Not forced, supports reuse/suggestions
6. **Split items are hidden**: Only shown when viewing transaction details

## Core Data Schema Evolution

The project uses **lightweight migration**:
```swift
description.shouldMigrateStoreAutomatically = true
description.shouldInferMappingModelAutomatically = true
```

When modifying Core Data entities:
1. Open `OneTap.xcdatamodeld` in Xcode
2. Editor → Add Model Version (for major changes)
3. Make changes to the new version
4. Set new version as current model
5. For simple changes (adding optional attributes), direct edits work with lightweight migration

**Development Recovery:** If migration fails, the app deletes and recreates the store (acceptable during development, see `Persistence.swift:116-135`).

## Common Tasks

### Adding a New View

Follow the established pattern:
```swift
import SwiftUI

struct MyNewView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            // UI here
        }
        .navigationTitle("Title")
    }
}

#Preview {
    MyNewView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
```

### Working with Account Groups

Accounts are organized into groups:
- **Funding Accounts**: checking, savings, cash, other
- **Credit Accounts**: creditCard, bnpl
- **Financial Accounts**: investment

Access via `account.group` property.

### Settings Management

Use `SettingsManager.shared` for user preferences:
```swift
SettingsManager.shared.currencyCode  // Default currency
```

## Important Gotchas

1. **Always recalculate balances** after modifying transactions
2. **Transfers create two transactions** - handle deletion carefully
3. **Categories are seeded once** - don't re-seed on every launch
4. **Transaction items are optional** - check for existence before accessing
5. **Credit card balances are negative** - display logic handles this via `isLiability`
6. **Date formatting varies by context** - use appropriate formatter from `Formatters`
7. **Preview data uses in-memory store** - changes don't persist between previews

## Future Expansion Areas

The architecture is designed for scalability. Planned features include:
- Analytics/Overview dashboard (charts, insights)
- Recurring transactions
- Budget tracking
- Data export/import
- Receipt scanning (PhotosUI)
- Cloud sync (CloudKit)
- Widgets (WidgetKit)
