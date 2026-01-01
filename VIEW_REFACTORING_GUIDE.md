# View Refactoring Guide - MVVM Pattern

## Complete Example: AddTransactionView

**AddTransactionView has been fully refactored** to demonstrate the MVVM pattern. Use it as a template for refactoring the remaining 8 views.

---

## What Changed in AddTransactionView

### ✅ BEFORE (Direct Core Data Access)
```swift
struct AddTransactionView: View {
    @Environment(\.managedObjectContext) private var viewContext  // ❌ Direct Core Data
    @State private var amountString = "0"  // ❌ State in View
    @State private var selectedType: TransactionType = .expense
    // ... 8 more @State properties

    private func saveTransaction() {
        let transaction = Transaction(context: viewContext)  // ❌ Creating entity directly
        // ... 50 lines of save logic
        try viewContext.save()  // ❌ Direct save
        PersistenceController.shared.recalculateBalances(...)  // ❌ Direct service call
    }
}
```

### ✅ AFTER (Clean MVVM)
```swift
struct AddTransactionView: View {
    @EnvironmentObject private var container: DependencyContainer  // ✅ DI Container
    @StateObject private var viewModel: AddTransactionViewModel  // ✅ ViewModel owns state

    // ✅ Keep @FetchRequest ONLY for UI display in pickers/grids
    @FetchRequest(...) private var categories: FetchedResults<Category>
    @FetchRequest(...) private var accounts: FetchedResults<Account>

    var body: some View {
        // ✅ All bindings go to viewModel
        TextField("Amount", text: $viewModel.amountString)

        CustomKeypad(
            value: $viewModel.amountString,
            onDone: {
                Task {
                    await viewModel.saveTransaction()  // ✅ ViewModel handles logic
                }
            }
        )

        // ✅ Error handling
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) { ... }

        // ✅ Loading overlay
        .overlay {
            if viewModel.loadingState.isLoading {
                ProgressView()
            }
        }

        // ✅ Auto-dismiss on success
        .onChange(of: viewModel.loadingState) { _, newState in
            if newState == .loaded {
                dismiss()
            }
        }
    }
}
```

---

## Key Changes Breakdown

### 1. Dependency Injection
```swift
// OLD
@Environment(\.managedObjectContext) private var viewContext

// NEW
@EnvironmentObject private var container: DependencyContainer
@StateObject private var viewModel: AddTransactionViewModel

init() {
    let tempContainer = DependencyContainer()
    _viewModel = StateObject(wrappedValue: tempContainer.makeAddTransactionViewModel())
}
```

### 2. State Management
```swift
// OLD - State scattered in View
@State private var amountString = "0"
@State private var selectedType: TransactionType = .expense
@State private var selectedCategory: Category?
// ... 8 more @State properties

// NEW - State centralized in ViewModel
// All bindings now use: $viewModel.amountString, $viewModel.selectedType, etc.
```

### 3. Business Logic Moved to ViewModel
```swift
// OLD - 60+ lines of save logic in View
private func saveTransaction() {
    let transaction = Transaction(context: viewContext)
    transaction.id = UUID()
    // ... manual entity setup
    if selectedType == .transfer {
        // ... dual transaction logic
    }
    try viewContext.save()
    PersistenceController.shared.recalculateBalances(...)
}

// NEW - 1 line in View, logic in ViewModel
Task {
    await viewModel.saveTransaction()
}
```

### 4. Error Handling
```swift
// OLD - No error handling
} catch { print("Error saving: \(error)") }

// NEW - User-facing error alerts
.alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
    Button("OK") { viewModel.errorMessage = nil }
} message: {
    if let error = viewModel.errorMessage {
        Text(error)
    }
}
```

### 5. Loading States
```swift
// NEW - Loading overlay
.overlay {
    if viewModel.loadingState.isLoading {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            ProgressView().scaleEffect(1.5).tint(.white)
        }
    }
}
```

### 6. Auto-Dismiss on Success
```swift
// NEW - Reactive dismiss
.onChange(of: viewModel.loadingState) { _, newState in
    if newState == .loaded {
        dismiss()
    }
}
```

---

## Refactoring Pattern for Other Views

### 📝 Step-by-Step Template

#### 1. Add Dependencies
```swift
struct YourView: View {
    @EnvironmentObject private var container: DependencyContainer
    @StateObject private var viewModel: YourViewModel
    @Environment(\.dismiss) private var dismiss  // If needed

    init() {
        let tempContainer = DependencyContainer()
        _viewModel = StateObject(wrappedValue: tempContainer.makeYourViewModel())
    }
```

#### 2. Keep Minimal @FetchRequest (UI Display Only)
```swift
// ONLY if you need to display lists/pickers
@FetchRequest(sortDescriptors: [...]) private var categories: FetchedResults<Category>
```

#### 3. Remove All @State for Data
```swift
// DELETE these
@State private var name = ""
@State private var balance = ""
@State private var selectedItem: Item?

// REPLACE with ViewModel bindings
TextField("Name", text: $viewModel.name)
TextField("Balance", text: $viewModel.balance)
Picker("Item", selection: $viewModel.selectedItem) { ... }
```

#### 4. Replace Direct Core Data with ViewModel Methods
```swift
// OLD
Button("Save") {
    let entity = Entity(context: viewContext)
    entity.property = value
    try? viewContext.save()
}

// NEW
Button("Save") {
    Task {
        await viewModel.save()
    }
}
.disabled(!viewModel.isValid)  // ViewModel validates
```

#### 5. Add Error & Loading UI
```swift
.alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
    Button("OK") { viewModel.errorMessage = nil }
} message: {
    if let error = viewModel.errorMessage {
        Text(error)
    }
}
.overlay {
    if viewModel.loadingState.isLoading {
        ProgressView()
    }
}
```

#### 6. Add Auto-Dismiss (For Forms)
```swift
.onChange(of: viewModel.loadingState) { _, newState in
    if newState == .loaded {
        dismiss()
    }
}
```

---

## Remaining Views to Refactor (8 files)

### Priority 1 - Forms (Similar to AddTransactionView)
1. **EditTransactionView.swift**
   - ViewModel: `EditTransactionViewModel` ✅ (already created)
   - Pattern: Identical to AddTransactionView
   - Changes: Replace save logic with `await viewModel.saveChanges()`

2. **AccountFormView.swift**
   - ViewModel: `AccountFormViewModel` ✅
   - Pattern: Form with validation
   - Changes: Replace account creation/update with `await viewModel.saveAccount()`

3. **CategoryFormView.swift**
   - ViewModel: `CategoryFormViewModel` ✅
   - Pattern: Simple form
   - Changes: Replace category save with `await viewModel.saveCategory()`

### Priority 2 - Lists (Simpler)
4. **AccountListView.swift**
   - ViewModel: `AccountListViewModel` ✅
   - Pattern: List with calculations
   - Changes: Bind to `viewModel.accounts`, `viewModel.netWorth`, etc.

5. **TransactionListView.swift**
   - ViewModel: `TransactionListViewModel` ✅
   - Pattern: List with filtering
   - Changes: Bind to `viewModel.sectionedTransactions`, filters

6. **CategoryListView.swift**
   - ViewModel: `CategoryListViewModel` ✅
   - Pattern: List with reordering
   - Changes: Use `await viewModel.moveExpenseCategories()`, etc.

### Priority 3 - Details (Simplest)
7. **TransactionDetailView.swift**
   - ViewModel: `TransactionDetailViewModel` ✅
   - Pattern: Display + delete
   - Changes: Replace delete logic with `await viewModel.deleteTransaction()`

8. **AccountDetailView.swift**
   - ViewModel: `AccountDetailViewModel` ✅
   - Pattern: Display + delete
   - Changes: Replace delete logic with `await viewModel.deleteAccount()`

---

## Quick Reference: Common Replacements

### State Bindings
```swift
// OLD                          → NEW
$amountString                   → $viewModel.amountString
$selectedType                   → $viewModel.selectedType
$selectedCategory               → $viewModel.selectedCategory
```

### Computed Properties
```swift
// OLD
var isValid: Bool {
    !name.isEmpty && !balance.isEmpty
}

// NEW
// (Already in ViewModel, just use it)
.disabled(!viewModel.isValid)
```

### Save Operations
```swift
// OLD
do {
    try viewContext.save()
    dismiss()
} catch {
    print("Error: \(error)")
}

// NEW
Task {
    await viewModel.save()
}
// Auto-dismiss handled by .onChange(of: viewModel.loadingState)
```

### Delete Operations
```swift
// OLD
viewContext.delete(entity)
try? viewContext.save()

// NEW
Task {
    await viewModel.deleteItem(item)
}
```

---

## Benefits You'll Get

### Before Refactoring
- ❌ 200+ line view files with mixed concerns
- ❌ No error handling UI
- ❌ No loading states
- ❌ Can't test business logic
- ❌ Direct Core Data coupling

### After Refactoring
- ✅ 50-100 line view files (UI only)
- ✅ Consistent error alerts
- ✅ Professional loading overlays
- ✅ Testable ViewModels
- ✅ Clean separation of concerns

---

## Testing the Refactored View

1. **Build the project** - Should compile without errors
2. **Test transaction creation:**
   - Simple expense ✅
   - Simple income ✅
   - Transfer between accounts ✅
   - Split transaction ✅
3. **Test validation:**
   - Try saving with $0 amount (should show error)
   - Try transfer without destination (should show error)
4. **Test loading state:**
   - Should see progress indicator during save
   - Should auto-dismiss on success
5. **Test error handling:**
   - If save fails, should show error alert

---

## Common Pitfalls to Avoid

### ❌ DON'T: Create entities directly in View
```swift
// WRONG
let transaction = Transaction(context: viewContext)
```

### ✅ DO: Call ViewModel methods
```swift
// CORRECT
await viewModel.saveTransaction()
```

### ❌ DON'T: Mix @State and ViewModel properties
```swift
// WRONG - Confusing
@State private var name = ""
// ... and also ...
$viewModel.balance
```

### ✅ DO: Use ViewModel for all data state
```swift
// CORRECT - Consistent
$viewModel.name
$viewModel.balance
$viewModel.selectedItem
```

### ❌ DON'T: Call services directly from View
```swift
// WRONG
PersistenceController.shared.recalculateBalances(...)
```

### ✅ DO: Let ViewModel orchestrate services
```swift
// CORRECT
await viewModel.saveTransaction()
// ViewModel internally calls balanceService
```

---

## Estimated Time per View

- **Forms (EditTransaction, AccountForm, CategoryForm):** 20-30 min each
- **Lists (AccountList, TransactionList, CategoryList):** 15-20 min each
- **Details (TransactionDetail, AccountDetail):** 10-15 min each

**Total:** ~2-3 hours to refactor all 8 remaining views

---

## Need Help?

Refer back to **AddTransactionView.swift** - it's your complete reference implementation showing:
- ✅ How to inject DependencyContainer
- ✅ How to create ViewModel
- ✅ How to bind UI to ViewModel
- ✅ How to handle async operations
- ✅ How to show errors
- ✅ How to show loading states
- ✅ How to auto-dismiss on success

Copy the pattern, adapt the specifics, and you're done! 🚀
