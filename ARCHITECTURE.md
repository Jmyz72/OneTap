//
//  ARCHITECTURE.md
//  OneTap
//
//  Project Architecture Documentation
//

# OneTap Architecture Guide

## Overview
OneTap follows a clean, modular architecture designed for scalability and maintainability. This document outlines the structure and design decisions.

## Architecture Pattern

### MVVM-Light with SwiftUI
- **Views**: SwiftUI views (passive UI)
- **Models**: Core Data entities + Swift enums/structs
- **No explicit ViewModels**: Using SwiftUI's @FetchRequest and @State for simplicity
- **Data Layer**: Core Data managed by PersistenceController

## Folder Structure Explained

### `/Models` - Data Models
Contains domain models, enums, and Core Data entity extensions.

**Current:**
- `TransactionModel.swift`: Transaction categories, types, and extensions

**Future additions:**
- `AssetModel.swift`: Stock, crypto, real estate models
- `BudgetModel.swift`: Budget and goal models
- `AccountModel.swift`: Bank account models

### `/Views` - User Interface
All SwiftUI views organized by feature.

**Structure:**
```
Views/
├── MainTabView.swift           # Root tab navigation
├── ContentView.swift            # Transaction list (main screen)
├── Transaction/                 # Transaction feature
│   ├── AddTransactionView.swift
│   ├── TransactionListView.swift
│   └── (future) TransactionDetailView.swift
├── Shared/                      # Reusable components
│   └── TransactionRow.swift
└── (future) Assets/, Budget/, etc.
```

### `/Core` - Core Functionality
Fundamental app functionality not tied to specific features.

**Data/**
- `Persistence.swift`: Core Data stack management

**Extensions/**
- `FormattersExtension.swift`: Shared formatters

**Future additions:**
- `Core/Networking/`: API clients (if needed)
- `Core/Services/`: Business logic services
- `Core/Utilities/`: Helper functions

## Data Flow

```
User Action (View)
    ↓
SwiftUI State/Binding
    ↓
Core Data Context
    ↓
Persistence Controller
    ↓
SQLite Database
```

### Adding a Transaction Example:
1. User fills form in `AddTransactionView`
2. User taps "Save" button
3. View creates `Transaction` entity in Core Data context
4. Context saves to persistent store
5. `@FetchRequest` in `ContentView` automatically updates
6. UI refreshes with new transaction

## Core Data Model

### Current Entities

**Transaction**
- Stores all financial transactions
- Includes both income and expenses (distinguished by amount sign)
- Linked to categories via String (future: relationship)

### Future Entities

**Asset** (for stocks, crypto, etc.)
```
- id: UUID
- name: String
- type: String (stock, crypto, real estate)
- quantity: Double
- purchasePrice: Double
- currentPrice: Double
- purchaseDate: Date
```

**Budget**
```
- id: UUID
- category: String
- amount: Double
- period: String (monthly, yearly)
- startDate: Date
```

**Account** (for multiple bank accounts)
```
- id: UUID
- name: String
- type: String (checking, savings, credit)
- balance: Double
- currency: String
```

## Design Patterns

### 1. Repository Pattern (via Core Data)
- `PersistenceController` acts as repository
- Views fetch data via `@FetchRequest`
- No manual data synchronization needed

### 2. Dependency Injection
- Core Data context injected via `.environment(\.managedObjectContext)`
- Easy to swap for testing (see `preview` controller)

### 3. Reusable Components
- `TransactionRow`: Reusable list item
- `Formatters`: Centralized formatting logic

### 4. Type Safety
- `TransactionCategory` enum prevents typos
- Compile-time guarantees for categories

## View Composition

### Main Navigation Hierarchy
```
OneTapApp
└── MainTabView
    ├── TransactionsTab → ContentView
    │   └── TransactionListView
    │       └── TransactionRow (per transaction)
    ├── OverviewTab (placeholder)
    ├── AssetsTab (placeholder)
    └── MoreTab (placeholder)
```

## State Management

### Local State (@State)
Used for temporary UI state within a view:
- Form inputs in `AddTransactionView`
- Sheet presentation flags

### Environment State (@Environment)
Shared app-wide state:
- `\.managedObjectContext`: Core Data context
- `\.dismiss`: Modal dismissal

### Fetched Data (@FetchRequest)
Automatic Core Data queries:
- Keeps UI in sync with database
- Supports predicates and sorting

## Adding New Features

### Example: Adding Stock Portfolio

1. **Create Model**
```swift
// Models/AssetModel.swift
enum AssetType: String {
    case stock, crypto, realEstate
}

extension Asset {
    var typeEnum: AssetType? { ... }
    var totalValue: Double { quantity * currentPrice }
}
```

2. **Update Core Data Model**
Add `Asset` entity in `.xcdatamodeld`

3. **Create Views**
```
Views/Asset/
├── AssetListView.swift
├── AddAssetView.swift
└── AssetDetailView.swift
```

4. **Create Reusable Components**
```
Views/Shared/
└── AssetRow.swift
```

5. **Update Tab**
Replace placeholder in `MainTabView.swift`

## Best Practices

### 1. File Organization
- One view per file
- Group related files in folders
- Use descriptive names

### 2. SwiftUI Views
- Keep views small and focused
- Extract subviews for clarity
- Use view extensions for computed properties

### 3. Core Data
- Always handle save errors
- Use background contexts for heavy operations
- Test with preview data

### 4. Error Handling
- User-friendly error messages
- Graceful degradation
- Log errors for debugging

## Testing Strategy

### Preview Providers
- Every view has `#Preview`
- Use `PersistenceController.preview` for sample data

### Unit Tests (future)
- Test model logic
- Test formatters
- Test data transformations

### UI Tests (future)
- Test critical user flows
- Test transaction creation
- Test data persistence

## Performance Considerations

### Current Optimizations
- Batch predicates in `@FetchRequest`
- Lazy loading in `List`
- Minimal view updates with `@FetchRequest`

### Future Optimizations
- Pagination for large datasets
- Background context for imports
- Image caching (if adding receipts)
- Debouncing search queries

## Scalability Plan

### Phase 1: Foundation (Current)
✅ Basic transaction tracking
✅ Categories and organization
✅ Clean architecture

### Phase 2: Enhanced Features
- [ ] Multiple accounts
- [ ] Recurring transactions
- [ ] Budget tracking
- [ ] Search and filters

### Phase 3: Advanced Features
- [ ] Stock/crypto portfolio
- [ ] Charts and analytics
- [ ] Export/import
- [ ] Cloud sync (optional)

### Phase 4: Premium Features
- [ ] Advanced analytics
- [ ] Receipt scanning
- [ ] Bill reminders
- [ ] Financial insights

## Dependencies

### Current
- SwiftUI (iOS 16+)
- Core Data
- Foundation

### Potential Future Dependencies
- Charts framework (for analytics)
- PhotosUI (for receipt scanning)
- CloudKit (for sync)
- WidgetKit (for home screen widgets)

## Conclusion

This architecture provides:
- ✅ Clean separation of concerns
- ✅ Easy to add new features
- ✅ Testable components
- ✅ Scalable structure
- ✅ Type-safe design
- ✅ SwiftUI best practices

All future features can follow the established patterns without major refactoring.
