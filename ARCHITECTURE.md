//
//  ARCHITECTURE.md
//  OneTap
//
//  Project Architecture Documentation
//

# OneTap Architecture Guide

## Overview
OneTap follows a robust **MVVM (Model-View-ViewModel)** architecture enhanced with **Repositories** and **Dependency Injection**. This structure ensures separation of concerns, testability, and scalability.

## Architecture Pattern

### MVVM + Repository
- **Views**: Passive SwiftUI views. They observe `ViewModels` and delegate user actions to them.
- **ViewModels**: `ObservableObject` classes that manage UI state, handle business logic, and interact with Repositories/Services.
- **Repositories**: Abstraction layer for Core Data. They handle CRUD operations and data fetching, returning standard Swift types or Combine publishers.
- **Services**: Encapsulate complex business logic (e.g., `BalanceService`, `TransferService`) that spans multiple entities.
- **Dependency Container**: A central factory that creates and injects dependencies (Repositories, Services, ViewModels).

## Folder Structure Explained

### `/Models` - Domain Models
Contains Core Data class extensions and pure Swift domain models.
- `TransactionModel.swift`: `TransactionCategory` enum, helpers.
- `AccountModel.swift`: `AccountType`, `AccountGroup`.

### `/ViewModels` - Presentation Logic
One ViewModel per major View (or feature).
- `TransactionListViewModel.swift`: Handles filtering, searching, and sectioning of transactions.
- `AddTransactionViewModel.swift`: Manages form state and validation for new transactions.
- `AccountFormViewModel.swift`: Logic for creating/editing accounts.

### `/Views` - User Interface
SwiftUI views organized by feature.
- **State**: Uses `@StateObject` for ViewModels injected via the DependencyContainer.
- **Bindings**: Binds directly to ViewModel published properties (e.g., `$viewModel.title`).

### `/Core` - Application Core

**DI/**
- `DependencyContainer.swift`: The single source of truth for dependencies. Creates Repositories and Services, and acts as a factory for ViewModels.

**Repositories/**
- `TransactionRepository.swift`: Fetches and persists transactions.
- `AccountRepository.swift`: Manages account entities.
- `BaseRepository.swift`: Common Core Data utilities.

**Services/**
- `BalanceService.swift`: Recalculates account balances.
- `TransferService.swift`: Handles logic for transfers (creating paired transactions).

## Data Flow

```
User Action (View)
    ↓
ViewModel Method (e.g., `saveTransaction()`)
    ↓
Service / Repository
    ↓
Core Data Context (PersistenceController)
    ↓
SQLite Database
```

### Data Updates (Reactive)
1. Repository observes Core Data context changes.
2. Repository publishes updated data via Combine `Publisher`.
3. ViewModel subscribes to Repository publisher.
4. ViewModel updates `@Published` properties.
5. View updates automatically.

## Design Patterns

### 1. Repository Pattern
- Hides `NSFetchRequest` and `NSPredicate` complexity from ViewModels.
- Allows for easier unit testing by mocking repositories.

### 2. Dependency Injection
- `DependencyContainer` is injected into the environment: `.environmentObject(dependencyContainer)`.
- Views request ViewModels from the container: `container.makeTransactionListViewModel()`.

### 3. Service Layer
- Logic that involves multiple repositories (like a Transfer affecting two accounts) lives in a Service (`TransferService`), not in the ViewModel.

## Core Data Model

**Transaction**
- `type`: Expense, Income, Transfer.
- `account`: Relationship to `Account`.
- `balanceAfter`: Snapshot of running balance.

**Account**
- `type`: Checking, Savings, Credit Card, etc.
- `currentBalance`: Cached balance (updated by `BalanceService`).

## Best Practices

### 1. No Logic in Views
- Avoid `@FetchRequest` for complex data.
- Do not call `viewContext.save()` directly in Views.
- Delegate all actions to the ViewModel.

### 2. ViewModels own the State
- Use `@Published` properties for form data.
- Handle validation and error messages in the ViewModel.

### 3. Centralized Navigation (Future)
- Currently using `NavigationStack`, but moving towards a Coordinator pattern if complexity grows.

## Scalability

This architecture supports:
- **Unit Testing**: ViewModels and Services can be tested in isolation.
- **Previews**: Easy to inject mock repositories/services for SwiftUI Previews.
- **Feature Isolation**: distinct folders for Views and ViewModels make adding new features (like Budgeting) structured.