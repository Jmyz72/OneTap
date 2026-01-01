# OneTap - Personal Finance iOS App

A modern, scalable SwiftUI-based personal finance tracking app using **MVVM** and **Core Data**.

## 🏗️ Project Structure

The project follows a clean **MVVM + Repository** architecture:

```
OneTap/
├── ViewModels/               # Presentation Logic
├── Views/                    # SwiftUI Views
├── Core/
│   ├── Repositories/         # Data Access Layer
│   ├── Services/             # Business Logic (Balance, Transfers)
│   └── DI/                   # Dependency Injection
└── Models/                   # Domain Models
```

## ✨ Features

### Transaction Management
- ✅ Add, Edit, Delete Transactions
- ✅ Split Transactions (Multiple categories per transaction)
- ✅ Search and Filter (Date, Category, Text)
- ✅ Recurring Transactions (Foundation laid)

### Account Management
- ✅ Multiple Accounts (Checking, Savings, Credit Card, Cash)
- ✅ **Transfers** between accounts
- ✅ **Running Balance** tracking
- ✅ Account Grouping (Liquid, Credit, etc.)

### Organization
- ✅ Custom Categories with Icons and Colors
- ✅ Sub-categories support

### UI/UX
- ✅ Modern SwiftUI Interface
- ✅ Dark Mode Support
- ✅ Haptic Feedback
- ✅ Native iOS Look & Feel

## 🔮 Roadmap

### Phase 3: Budgeting (Next)
- [ ] Monthly Budgets per Category
- [ ] Progress Bars and Alerts

### Phase 4: Assets
- [ ] Stock and Crypto tracking
- [ ] Net Worth History

### Phase 5: Analytics
- [ ] Visual Charts (Swift Charts)
- [ ] Monthly Reports

## 🚀 Getting Started

1. Open `OneTap.xcodeproj` in Xcode.
2. Select a simulator (iOS 16+).
3. Run (⌘R).

## 🛠 Tech Stack

- **Language**: Swift 5
- **UI Framework**: SwiftUI
- **Persistence**: Core Data
- **Architecture**: MVVM + Repository + Dependency Injection
- **Concurrency**: Swift Async/Await