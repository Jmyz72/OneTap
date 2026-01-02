# OneTap Project Context

## 1. Project Overview
OneTap is a native iOS personal finance application built with **SwiftUI** and **Core Data**. It focuses on simplicity ("one tap" experience) for tracking expenses, income, and (future) assets.

*   **Type:** iOS App (Swift)
*   **Minimum Target:** iOS 16+
*   **Key Frameworks:** SwiftUI, Core Data
*   **State Management:** `@State` (local), `@Environment` (global), `@FetchRequest` (data)

## 2. Architecture
The project follows a robust **MVVM + Repository** architecture.

*   **Views:** Passive UI components in `Views/`. They observe `ViewModels` and delegate logic.
*   **ViewModels:** `ObservableObject` classes in `ViewModels/` that manage UI state and interact with Repositories.
*   **Models:** Core Data entities (`OneTap.xcdatamodeld`) + Swift extensions/enums in `Models/`.
*   **Data Layer:** `Repositories/` abstract Core Data. `Services/` handle complex logic.
*   **Data Flow:** User Action → ViewModel → Repository/Service → Core Data Context.

## 3. Directory Structure
*   `OneTapApp.swift`: Entry point, injects `DependencyContainer`.
*   `Models/`: Domain models (`TransactionModel`, `AccountModel`).
*   `ViewModels/`: Presentation logic (`TransactionListViewModel`, `AccountFormViewModel`).
*   `Views/`:
    *   `MainTabView.swift`: Root navigation.
    *   `Transaction/`: Feature views (`TransactionListView`, `AddTransactionView`).
    *   `Account/`: Account management (`AccountListView`, `AccountFormView`).
*   `Core/`:
    *   `DI/`: Dependency Injection (`DependencyContainer`).
    *   `Repositories/`: Data access (`TransactionRepository`, `AccountRepository`).
    *   `Services/`: Business logic (`BalanceService`, `TransferService`).

## 4. Development Guide

### Building and Running
*   **IDE:** Xcode
*   **Run:** `Cmd + R` (Run), `Cmd + B` (Build).
*   **Preview:** SwiftUI Previews are enabled for all views.

### Common Tasks
*   **Adding a Transaction:**
    ```swift
    // In ViewModel
    func saveTransaction() {
        let transaction = Transaction(context: context)
        // ... set properties
        repository.add(transaction)
    }
    ```
*   **Fetching Data:**
    ```swift
    // In ViewModel
    repository.transactionsPublisher
        .assign(to: &$transactions)
    ```

### Conventions
*   **Naming:** `[Feature]View.swift`, `[Feature]Model.swift`.
*   **Style:** Clean SwiftUI, one view per file, use `NavigationStack`.
*   **Colors:** Use `TransactionCategory` enum for consistent category colors.

## 5. Roadmap
The project has completed **Phase 1 (Foundation)** and **Phase 2 (Accounts)**.
*   **Current:** Refactoring to MVVM+Repository, implementing Budgeting.
*   **Upcoming:**
    *   Phase 3: Budget Tracking.
    *   Phase 4: Asset Management (Stocks, Crypto).
    *   Phase 5: Analytics/Overview.

## 6. Key Documentation
Refer to these files for deep dives:
*   `ARCHITECTURE.md`: Detailed architectural decisions.
*   `DEVELOPMENT_GUIDE.md`: Code snippets and "How-to" for developers.
*   `PROJECT_STRUCTURE.md`: Detailed file tree and folder purpose.
