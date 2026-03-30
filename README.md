# OneTap

OneTap is a SwiftUI personal finance app built as an end-to-end iOS project for tracking accounts, transactions, budgets, recurring payments, and receipt imports.

This repository is the source code behind the app and is intended to show practical iOS engineering work rather than a small demo. The project includes Core Data persistence, dependency injection, feature-specific view models, background processing, and OCR-assisted transaction import flows.

## Highlights

- Track transactions across multiple account types, including checking, savings, cash, and credit cards
- Support transfers, split transactions, balance adjustments, and running account balances
- Manage recurring transactions and installment plans with background processing on app launch
- Organize spending with editable categories, subcategories, budgets, and claims tracking
- Import transactions from receipts and screenshots using OCR, image preprocessing, and extraction services
- View account summaries, home insights, budgets, and analytics in a tab-based SwiftUI app

## Technical Focus

- `SwiftUI` for the app UI
- `Core Data` for persistence and model relationships
- `MVVM` for presentation logic
- `Repository + Service` layers to separate data access from business logic
- `Dependency Injection` through a central `DependencyContainer`
- `async/await` and background task integration for recurring transaction processing
- `App Intents` support for transaction import shortcuts

## Architecture

The app is organized around feature-specific views and view models, backed by repositories and services:

```text
OneTap/
├── AppIntents/        # App shortcuts and import intents
├── Core/
│   ├── Data/          # Core Data stack and persistence setup
│   ├── DI/            # Dependency container and factories
│   ├── Repositories/  # Data access layer
│   ├── Services/      # Business logic and workflow services
│   ├── Settings/      # App-level preferences
│   └── Theme/         # Shared styling and icons
├── Models/            # Core Data model extensions and domain helpers
├── ViewModels/        # Presentation logic per feature
└── Views/             # SwiftUI screens for transactions, accounts, OCR, budgets, analytics, and settings
```

Two implementation details that drive the app design:

- Every transaction participates in account balance tracking, including recalculation after edits or transfers.
- Transfers are modeled as paired transactions, which keeps account history and balance updates explicit.

## Running The Project

### Requirements

- Xcode
- iOS Simulator

### Open and run

1. Open `OneTap.xcodeproj` in Xcode.
2. Select the `OneTap` scheme.
3. Build and run on an iPhone simulator.

### Command-line build

```bash
xcodebuild -project OneTap.xcodeproj -scheme OneTap -configuration Debug -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
```

## Notable Features In This Repository

### Transactions and balances

- Add, edit, delete, and inspect transactions
- Split transactions into multiple items
- Transfer money between accounts
- Recalculate running balances after changes

### Planning and tracking

- Budgets and budget list views
- Recurring transactions and installment plans
- Claims tracking support

### Receipt import

- Receipt scanning and screenshot import flows
- OCR preprocessing, extraction, validation, and learning services
- Category matching helpers for imported items

## Current Status

- The app builds successfully from the command line with the `OneTap` scheme.
- The repository currently does not include a dedicated automated test target.
- Some supporting docs in the repo were written during development and may be more detailed than a typical portfolio project.

## What This Project Demonstrates

- Building a non-trivial SwiftUI application with multiple feature areas
- Designing a layered architecture that can grow beyond a single screen or CRUD flow
- Managing Core Data relationships and background updates
- Handling app-level workflows such as recurring processing, receipt import, and migration recovery
