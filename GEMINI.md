# OneTap Project Context

## 1. Project Overview
OneTap is a native iOS personal finance application built with **SwiftUI** and **Core Data**. It focuses on simplicity ("one tap" experience) for tracking expenses, income, and (future) assets.

*   **Type:** iOS App (Swift)
*   **Minimum Target:** iOS 16+
*   **Key Frameworks:** SwiftUI, Core Data
*   **State Management:** `@State` (local), `@Environment` (global), `@FetchRequest` (data)

## 2. Architecture
The project follows a clean, modular architecture, described as "MVVM-Light".

*   **Views:** Passive UI components in `Views/`. No explicit separate ViewModel classes are used; Views interact directly with Core Data via `@FetchRequest`.
*   **Models:** Core Data entities (`OneTap.xcdatamodeld`) + Swift extensions/enums in `Models/`.
*   **Data Layer:** Managed by `PersistenceController` in `Core/Data/Persistence.swift`.
*   **Data Flow:** User Action → SwiftUI State → Core Data Context → Persistence Controller → SQLite.

## 3. Directory Structure
*   `OneTapApp.swift`: Entry point, sets up Core Data stack.
*   `Models/`: Domain models (e.g., `TransactionModel.swift` for categories).
*   `Views/`:
    *   `MainTabView.swift`: Root navigation (Transactions, Overview, Assets, More).
    *   `ContentView.swift`: Transaction list (main feature).
    *   `Transaction/`: Feature-specific views (`AddTransactionView`, `TransactionListView`).
    *   `Shared/`: Reusable components (`TransactionRow`).
*   `Core/`:
    *   `Data/Persistence.swift`: Core Data stack and preview data generation.
    *   `Extensions/`: Helpers (e.g., `FormattersExtension.swift`).

## 4. Development Guide

### Building and Running
*   **IDE:** Xcode
*   **Run:** `Cmd + R` (Run), `Cmd + B` (Build).
*   **Preview:** SwiftUI Previews are enabled for all views.

### Common Tasks
*   **Adding a Transaction:**
    ```swift
    let newTransaction = Transaction(context: viewContext)
    newTransaction.id = UUID()
    // ... set properties
    try? viewContext.save()
    ```
*   **Fetching Data:**
    ```swift
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Transaction.date, ascending: false)],
        animation: .default
    ) private var transactions: FetchedResults<Transaction>
    ```

### Conventions
*   **Naming:** `[Feature]View.swift`, `[Feature]Model.swift`.
*   **Style:** Clean SwiftUI, one view per file, use `NavigationStack`.
*   **Colors:** Use `TransactionCategory` enum for consistent category colors.

## 5. Roadmap
The project is currently in **Phase 1 (Foundation)**.
*   **Current:** Basic transaction tracking, categories, Core Data persistence.
*   **Upcoming:**
    *   Phase 2: Enhanced Transactions (Details, Filters).
    *   Phase 3: Budget Tracking.
    *   Phase 4: Asset Management (Stocks, Crypto).
    *   Phase 5: Analytics/Overview.

## 6. Key Documentation
Refer to these files for deep dives:
*   `ARCHITECTURE.md`: Detailed architectural decisions.
*   `DEVELOPMENT_GUIDE.md`: Code snippets and "How-to" for developers.
*   `PROJECT_STRUCTURE.md`: Detailed file tree and folder purpose.
