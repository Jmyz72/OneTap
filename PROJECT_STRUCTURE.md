# OneTap Project Structure

```
📦 OneTap/
│
├── 📱 OneTapApp.swift                    # App entry point
│
├── 📁 Models/                            # Data models & business logic
│   └── TransactionModel.swift           # Transaction categories & extensions
│
├── 📁 Views/                             # User interface
│   ├── MainTabView.swift                # 4-tab navigation (root)
│   ├── ContentView.swift                # Transaction list screen
│   │
│   ├── 📁 Transaction/                  # Transaction feature
│   │   ├── AddTransactionView.swift    # Create new transaction
│   │   └── TransactionListView.swift   # Reusable transaction list
│   │
│   └── 📁 Shared/                       # Reusable UI components
│       └── TransactionRow.swift         # Transaction list item
│
├── 📁 Core/                              # Core functionality
│   ├── 📁 Data/                         # Data layer
│   │   └── Persistence.swift            # Core Data stack
│   │
│   └── 📁 Extensions/                   # Swift extensions
│       └── FormattersExtension.swift    # Formatters (currency, dates)
│
├── 📁 OneTap.xcdatamodeld/              # Core Data model
│   └── OneTap.xcdatamodel/
│       └── contents                      # Transaction entity
│
└── 📁 Assets.xcassets/                   # Images & colors
    ├── AccentColor.colorset/
    └── AppIcon.appiconset/
```

## Tab Structure

```
MainTabView
├── 📊 Transactions Tab → ContentView
│   └── Shows all transactions
│
├── 📈 Overview Tab (Placeholder)
│   └── Future: Analytics & insights
│
├── 💰 Assets Tab (Placeholder)
│   └── Future: Stocks, crypto, real estate
│
└── ⋯ More Tab (Placeholder)
    └── Future: Settings, export, preferences
```

## Data Flow

```
User Input
    ↓
SwiftUI View (@State, @Binding)
    ↓
Core Data Context (via @Environment)
    ↓
PersistenceController
    ↓
SQLite Database
    ↓
@FetchRequest (automatic updates)
    ↓
UI Updates
```

## Feature Expansion Plan

### 🟢 Phase 1: Foundation (COMPLETE)
- ✅ Transaction tracking
- ✅ Categories with icons
- ✅ Add/Delete transactions
- ✅ Clean architecture
- ✅ Core Data setup
- ✅ Tab navigation structure

### 🔵 Phase 2: Enhanced Transactions
Add to `/Views/Transaction/`:
- [ ] `TransactionDetailView.swift` - View/edit individual transactions
- [ ] `TransactionFilterView.swift` - Filter by category/date
- [ ] `RecurringTransactionView.swift` - Setup recurring transactions

### 🟡 Phase 3: Budget Tracking
Create `/Views/Budget/`:
- [ ] `BudgetListView.swift` - View all budgets
- [ ] `AddBudgetView.swift` - Create new budget
- [ ] `BudgetDetailView.swift` - Budget progress & insights
- [ ] Create `BudgetModel.swift` in `/Models/`
- [ ] Add Budget entity to Core Data

### 🟠 Phase 4: Asset Management
Create `/Views/Asset/`:
- [ ] `AssetListView.swift` - View all assets
- [ ] `AddAssetView.swift` - Add stock/crypto/property
- [ ] `AssetDetailView.swift` - Asset performance
- [ ] Create `AssetModel.swift` in `/Models/`
- [ ] Add Asset entity to Core Data

### 🟣 Phase 5: Analytics & Overview
Update `OverviewTab` with:
- [ ] `DashboardView.swift` - Financial overview
- [ ] `ChartViews.swift` - Spending charts
- [ ] `InsightsView.swift` - AI-powered insights
- [ ] Create `/Core/Analytics/` folder

### 🔴 Phase 6: Advanced Features
- [ ] Multiple accounts support
- [ ] Data export/import
- [ ] Receipt scanning
- [ ] Cloud sync (optional)
- [ ] Widgets

## When to Add New Folders

| Add Folder | When You Need... |
|------------|------------------|
| `/Models/AssetModel.swift` | Stock/crypto tracking |
| `/Models/BudgetModel.swift` | Budget management |
| `/Models/AccountModel.swift` | Multiple bank accounts |
| `/Views/Budget/` | Budget-related views |
| `/Views/Asset/` | Asset-related views |
| `/Views/Reports/` | Reports & analytics |
| `/Core/Services/` | Business logic services |
| `/Core/Networking/` | API integrations |
| `/Core/Utilities/` | Helper functions |

## Key Files Reference

| File | Purpose |
|------|---------|
| `OneTapApp.swift` | App entry, Core Data setup |
| `MainTabView.swift` | Root navigation |
| `ContentView.swift` | Main transactions screen |
| `AddTransactionView.swift` | Add transaction form |
| `TransactionRow.swift` | Reusable list item |
| `TransactionModel.swift` | Categories & extensions |
| `Persistence.swift` | Core Data management |
| `FormattersExtension.swift` | Shared formatters |

## Documentation Files

- `README.md` - Project overview & features
- `ARCHITECTURE.md` - Detailed architecture explanation
- `DEVELOPMENT_GUIDE.md` - Quick reference for developers
- `PROJECT_STRUCTURE.md` - This file

---

**Last Updated:** December 29, 2025
**Version:** 1.0.0
