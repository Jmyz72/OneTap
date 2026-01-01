# OneTap Project Structure

```
📦 OneTap/
│
├── 📱 OneTapApp.swift                    # App entry point, DI Container setup
│
├── 📁 Models/                            # Domain models & Core Data extensions
│   ├── TransactionModel.swift           # Transaction categories & enums
│   ├── AccountModel.swift               # Account types & logic
│   ├── CategoryModel.swift              # Category entity extensions
│   └── SubCategoryModel.swift
│
├── 📁 ViewModels/                        # Presentation Logic (MVVM)
│   ├── TransactionListViewModel.swift   # Filtering & Search logic
│   ├── AddTransactionViewModel.swift    # Form validation & saving
│   ├── AccountListViewModel.swift
│   ├── AccountFormViewModel.swift
│   └── ... (One per major view)
│
├── 📁 Views/                             # User interface (SwiftUI)
│   ├── MainTabView.swift                # Root navigation
│   │
│   ├── 📁 Transaction/                  # Transaction feature
│   │   ├── AddTransactionView.swift
│   │   ├── TransactionListView.swift
│   │   ├── EditTransactionView.swift
│   │   └── ...
│   │
│   ├── 📁 Account/                      # Account feature
│   │   ├── AccountListView.swift
│   │   ├── AccountFormView.swift
│   │   └── ...
│   │
│   ├── 📁 Settings/                     # Settings & Metadata
│   │   ├── CategoryListView.swift
│   │   └── ...
│   │
│   └── 📁 Shared/                       # Reusable UI components
│       ├── TransactionRow.swift
│       ├── AccountRow.swift
│       └── ...
│
├── 📁 Core/                              # Core Application Logic
│   ├── 📁 DI/                           # Dependency Injection
│   │   └── DependencyContainer.swift    # ViewModel Factory & Service Holder
│   │
│   ├── 📁 Data/                         # Data Layer
│   │   └── Persistence.swift            # Core Data Stack
│   │
│   ├── 📁 Repositories/                 # Data Access Layer
│   │   ├── TransactionRepository.swift
│   │   ├── AccountRepository.swift
│   │   ├── CategoryRepository.swift
│   │   └── BaseRepository.swift
│   │
│   ├── 📁 Services/                     # Business Logic Layer
│   │   ├── BalanceService.swift         # Running balance calculation
│   │   ├── TransferService.swift        # Account transfers
│   │   └── ValidationService.swift
│   │
│   ├── 📁 Extensions/                   # Swift extensions
│   │   └── FormattersExtension.swift
│   │
│   └── 📁 Theme/                        # Design System
│       ├── AppTheme.swift
│       └── IconLibrary.swift
│
├── 📁 OneTap.xcdatamodeld/              # Core Data Schema
└── 📁 Assets.xcassets/                   # Images & Colors
```

## Module Responsibilities

| Module | Responsibility |
|--------|----------------|
| **Views** | Display UI, observe ViewModel, capture user input. Passive. |
| **ViewModels** | Manage UI state (`@Published`), handle user actions, call Services/Repositories. |
| **Repositories** | CRUD operations on Core Data entities. Hide `NSFetchRequest` details. |
| **Services** | Complex business rules (e.g., Transfer logic, Balance updates). |
| **DependencyContainer** | Creates and holds singletons (Repositories, Services). Acts as a Factory. |

## Feature Status

### 🟢 Phase 1: Foundation (COMPLETE)
- ✅ Transaction Tracking (Add, Edit, Delete)
- ✅ Category Management
- ✅ Core Data Persistence
- ✅ MVVM Architecture

### 🟢 Phase 2: Account Management (COMPLETE)
- ✅ Multiple Accounts (Checking, Cash, Credit)
- ✅ Transfers between accounts
- ✅ Running Balance calculation

### 🔵 Phase 3: Budget Tracking (PLANNED)
- [ ] Budget Models
- [ ] Budget Repositories
- [ ] Budget vs Actual Views

### 🟡 Phase 4: Asset Management (PLANNED)
- [ ] Stock/Crypto tracking
- [ ] Asset Portfolio Views

### 🟠 Phase 5: Analytics (PLANNED)
- [ ] Charts and Graphs
- [ ] Spending Trends

## Key Files Reference

| File | Purpose |
|------|---------|
| `DependencyContainer.swift` | **Start here.** Shows all available services and repositories. |
| `TransactionRepository.swift` | Example of how data is fetched. |
| `TransactionListViewModel.swift` | Example of clean presentation logic. |
| `AddTransactionView.swift` | Example of a refactored MVVM View. |