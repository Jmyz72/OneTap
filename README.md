# OneTap - Personal Finance iOS App

A modern SwiftUI-based personal finance tracking app with Core Data persistence.

## 🏗️ Project Structure

```
OneTap/
├── OneTapApp.swift              # App entry point with MainTabView
├── Models/                       # Data models and enums
│   └── TransactionModel.swift   # Transaction category enum and extensions
├── Views/                        # SwiftUI views
│   ├── MainTabView.swift        # Main tab navigation (4 tabs)
│   ├── ContentView.swift        # Transaction list screen
│   ├── Transaction/             # Transaction-related views
│   │   ├── AddTransactionView.swift
│   │   └── TransactionListView.swift
│   └── Shared/                  # Reusable components
│       └── TransactionRow.swift # Transaction list item view
├── Core/                         # Core functionality
│   ├── Data/                    # Data persistence
│   │   └── Persistence.swift   # Core Data stack
│   └── Extensions/              # Swift extensions
│       └── FormattersExtension.swift # Currency & date formatters
└── OneTap.xcdatamodeld/         # Core Data model
    └── OneTap.xcdatamodel/
        └── contents             # Transaction entity definition
```

## ✨ Current Features

### Transaction Management
- ✅ Add new transactions (expense/income)
- ✅ View transaction list (sorted by date)
- ✅ Delete transactions (swipe to delete)
- ✅ Transaction categories with icons and colors
- ✅ Optional merchant field
- ✅ Core Data persistence

### UI Components
- ✅ Tab-based navigation (4 tabs)
- ✅ Empty state handling
- ✅ Category icons and color coding
- ✅ Currency formatting
- ✅ Date formatting

### Transaction Categories
- Food 🍴
- Transport 🚗
- Entertainment 🎬
- Shopping 🛒
- Bills 📄
- Health ❤️
- Salary 💰
- Investment 📈
- Other ⋯

## 🔮 Future Features (Placeholders Created)

### Overview Tab
- [ ] Financial analytics dashboard
- [ ] Spending trends
- [ ] Income vs expenses charts
- [ ] Monthly/yearly summaries

### Assets Tab
- [ ] Stock portfolio tracking
- [ ] Cryptocurrency holdings
- [ ] Real estate tracking
- [ ] Other investment assets

### More Tab
- [ ] User preferences
- [ ] Category management
- [ ] Data export/import
- [ ] Currency settings
- [ ] Backup & restore

## 🎨 Design Principles

1. **Clean Architecture**: Organized folder structure for scalability
2. **Reusable Components**: Shared views and utilities
3. **Type Safety**: Enums for categories with compile-time checks
4. **Preview Support**: All views have SwiftUI previews
5. **Core Data**: Local persistence with proper error handling
6. **Modern SwiftUI**: NavigationStack, @FetchRequest, environment values

## 📱 Core Data Model

### Transaction Entity
- `id`: UUID (unique identifier)
- `title`: String (required)
- `amount`: Double (required, positive for expenses, negative for income)
- `category`: String (required)
- `date`: Date (required)
- `merchant`: String (optional)

## 🚀 Getting Started

1. Open `OneTap.xcodeproj` in Xcode
2. Select a simulator or device
3. Run the app (⌘R)
4. Use the "+" button to add transactions

## 📝 Notes

- All data is stored locally using Core Data
- No networking or authentication required
- Sample data is provided in preview mode
- The app follows Apple's Human Interface Guidelines
