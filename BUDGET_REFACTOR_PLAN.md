# Budget Feature Refactor Plan

## Overview

Refactor the budget system from period-based to monthly recurring budgets with hierarchical category support.

---

## Current vs New Design

### Current Implementation
- Budgets have explicit `startDate` and `endDate`
- User must manually create a budget for each period
- Only category-level (no subcategory support)
- Complex date range logic

### New Implementation
- Set budget once → applies every month automatically
- Hierarchical: Category and SubCategory level budgets
- SubCategory budgets roll up to parent Category budget
- Parent budget must be >= sum of child budgets

---

## Budget Hierarchy Rules

### Rule 1: Rollup Calculation
When subcategories have budgets, the parent category displays:
- **Spent**: Sum of all transactions in that category (including all subcategories)
- **Budget Amount**: Can be set independently OR derived from subcategory sum

### Rule 2: Parent Budget Constraint
When editing a parent (Category) budget:
- Cannot set amount less than the sum of its SubCategory budgets
- Example: If "Food" has subcategories "Groceries" ($200) and "Restaurants" ($150), the "Food" budget minimum is $350

### Rule 3: Spending Attribution
When a transaction is created:
- If transaction has SubCategory → counts toward SubCategory budget AND parent Category budget
- If transaction has only Category → counts toward Category budget only

### Visual Example
```
Food (Category)          Budget: $500    Spent: $320
├── Groceries (Sub)      Budget: $200    Spent: $180
├── Restaurants (Sub)    Budget: $150    Spent: $100
└── (Unallocated)        Budget: $150    Spent: $40
```

---

## Data Model Changes

### Current Budget Entity
```
Budget:
  - id: UUID
  - amount: Double
  - spent: Double
  - startDate: Date        ← REMOVE
  - endDate: Date          ← REMOVE
  - createdAt: Date
  - updatedAt: Date
  - category: Category
```

### New Budget Entity
```
Budget:
  - id: UUID
  - amount: Double
  - isActive: Boolean      ← ADD (default: true)
  - createdAt: Date
  - updatedAt: Date
  - category: Category
  - subCategory: SubCategory?  ← ADD (optional relationship)
```

**Note**: Remove `spent` from stored data - calculate dynamically for current month.

### Core Data Migration
- Lightweight migration should handle:
  - Removing `startDate`, `endDate`, `spent` attributes
  - Adding `isActive` attribute with default value
  - Adding optional `subCategory` relationship

---

## Repository Changes

### BudgetRepository Protocol (New)
```swift
protocol BudgetRepositoryProtocol {
    // CRUD
    func create(_ dto: BudgetCreateData) throws -> Budget
    func fetch(id: UUID) throws -> Budget
    func fetchAll() throws -> [Budget]
    func fetchActive() throws -> [Budget]
    func update(_ budget: Budget, with dto: BudgetUpdateData) throws
    func delete(_ budget: Budget) throws

    // Queries
    func fetchBudget(for category: Category) throws -> Budget?
    func fetchBudget(for subCategory: SubCategory) throws -> Budget?
    func fetchSubCategoryBudgets(for category: Category) throws -> [Budget]

    // Calculations
    func calculateSpent(for budget: Budget, in month: Date) throws -> Double
    func calculateMinimumAmount(for categoryBudget: Budget) throws -> Double

    // Publisher
    var budgetsPublisher: AnyPublisher<[Budget], Never> { get }
}
```

### Key Method Implementations

#### calculateSpent
```swift
func calculateSpent(for budget: Budget, in month: Date) throws -> Double {
    let calendar = Calendar.current
    let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
    let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: startOfMonth)!

    var predicate: NSPredicate
    if let subCategory = budget.subCategory {
        // SubCategory budget: only transactions with this subcategory
        predicate = NSPredicate(
            format: "subCategory == %@ AND date >= %@ AND date <= %@ AND type == %@",
            subCategory, startOfMonth, endOfMonth, TransactionType.expense.rawValue
        )
    } else {
        // Category budget: all transactions in this category
        predicate = NSPredicate(
            format: "category == %@ AND date >= %@ AND date <= %@ AND type == %@",
            budget.category!, startOfMonth, endOfMonth, TransactionType.expense.rawValue
        )
    }

    // Sum transaction amounts
    ...
}
```

#### calculateMinimumAmount
```swift
func calculateMinimumAmount(for categoryBudget: Budget) throws -> Double {
    guard budget.subCategory == nil else { return 0 } // Only for category-level

    let subBudgets = try fetchSubCategoryBudgets(for: budget.category!)
    return subBudgets.reduce(0) { $0 + $1.amount }
}
```

---

## DTO Changes

### BudgetCreateData (New)
```swift
struct BudgetCreateData {
    let amount: Double
    let categoryID: UUID
    let subCategoryID: UUID?  // nil = category-level budget
}
```

### BudgetUpdateData (New)
```swift
struct BudgetUpdateData {
    let amount: Double?
    let isActive: Bool?
}
```

---

## Service Changes

### BudgetService Protocol (New)
```swift
protocol BudgetServiceProtocol {
    /// Get budget status for a transaction (for alerts/warnings)
    func checkBudgetStatus(for transactionID: NSManagedObjectID) async throws -> BudgetStatus

    /// Get current month spending summary for all budgets
    func getCurrentMonthSummary() async throws -> [BudgetSummary]

    /// Validate budget amount against subcategory sum
    func validateBudgetAmount(_ amount: Double, for category: Category) throws -> Bool
}

struct BudgetSummary {
    let budget: Budget
    let spent: Double
    let remaining: Double
    let progress: Double  // 0.0 - 1.0+
    let status: BudgetStatus
}

enum BudgetStatus {
    case ok
    case nearLimit    // >= 80%
    case exceeded     // > 100%
    case noBudget
}
```

---

## ViewModel Changes

### BudgetListViewModel
```swift
@MainActor
class BudgetListViewModel: ObservableObject {
    @Published var budgetSummaries: [BudgetSummary] = []
    @Published var currentMonth: Date = Date()
    @Published var loadingState: LoadingState = .idle

    // Computed
    var categoryBudgets: [BudgetSummary]     // Top-level only
    var totalBudgeted: Double
    var totalSpent: Double
    var overallProgress: Double

    // Actions
    func loadBudgets() async
    func deleteBudget(_ budget: Budget) async
    func navigateToMonth(_ direction: Int)   // -1 = previous, +1 = next
}
```

### BudgetFormViewModel
```swift
@MainActor
class BudgetFormViewModel: ObservableObject {
    @Published var amount: String = ""
    @Published var selectedCategory: Category?
    @Published var selectedSubCategory: SubCategory?  // Optional
    @Published var loadingState: LoadingState = .idle
    @Published var errorMessage: String?

    // Computed
    var isEditing: Bool
    var availableSubCategories: [SubCategory]
    var minimumAmount: Double  // Sum of subcategory budgets
    var isValid: Bool

    // Actions
    func saveBudget() async
    func loadMinimumAmount() async
}
```

---

## View Changes

### Screen States

#### State 1: Category List (Default)
Shows all expense categories with their budget status.

```
┌─────────────────────────────────────┐
│  Budgets            January 2025  < > │
├─────────────────────────────────────┤
│  Total Budget: $2,500                │
│  Total Spent:  $1,820  ████████░░ 73%│
├─────────────────────────────────────┤
│  🍔 Food                    $450/$500│
│     ████████████████░░░░        90%  │
├─────────────────────────────────────┤
│  🚗 Transport               $120/$200│
│     ████████████░░░░░░░░        60%  │
├─────────────────────────────────────┤
│  🛒 Shopping                $380/$400│
│     ███████████████████░        95%  │
├─────────────────────────────────────┤
│  🎬 Entertainment           $50/$100 │
│     ██████████░░░░░░░░░░        50%  │
├─────────────────────────────────────┤
│  💡 Utilities               $0 / --  │  ← No budget set
│     (Tap to set budget)              │
└─────────────────────────────────────┘
```

#### State 2: Category Expanded (After tapping a category)
Shows the selected category AND all its subcategories.

```
┌─────────────────────────────────────┐
│  ← Food                 January 2025│
├─────────────────────────────────────┤
│  🍔 Food (Total)            $450/$500│
│     ████████████████████░       90%  │
│     Min budget: $350 (from subs)     │
├─────────────────────────────────────┤
│  SUBCATEGORIES                       │
├─────────────────────────────────────┤
│  🥗 Groceries               $280/$200│
│     ██████████████████████████ 140%  │  ← Over budget (red)
├─────────────────────────────────────┤
│  🍽️ Restaurants             $120/$150│
│     ████████████████░░░░        80%  │
├─────────────────────────────────────┤
│  ☕ Coffee                   $50/ -- │  ← No budget set
│     (Tap to set budget)              │
├─────────────────────────────────────┤
│  🍿 Snacks                   $0 / -- │
│     (Tap to set budget)              │
└─────────────────────────────────────┘
```

#### State 3: Numpad Sheet (After tapping any row)
Bottom sheet with numpad to set/edit budget amount.

```
┌─────────────────────────────────────┐
│                                     │
│  🍽️ Restaurants                     │
│  Current spent: $120                │
│                                     │
│  ┌─────────────────────────────┐   │
│  │         $ 150               │   │
│  └─────────────────────────────┘   │
│                                     │
│  ⚠️ Min: $0  (no sub-budgets)       │  ← Only show for categories
│                                     │
│  ┌─────┬─────┬─────┐               │
│  │  1  │  2  │  3  │               │
│  ├─────┼─────┼─────┤               │
│  │  4  │  5  │  6  │               │
│  ├─────┼─────┼─────┤               │
│  │  7  │  8  │  9  │               │
│  ├─────┼─────┼─────┤               │
│  │  .  │  0  │  ⌫  │               │
│  └─────┴─────┴─────┘               │
│                                     │
│  ┌─────────────┐ ┌─────────────┐   │
│  │   Cancel    │ │    Save     │   │
│  └─────────────┘ └─────────────┘   │
│                                     │
│  🗑️ Remove Budget                   │  ← Only if budget exists
└─────────────────────────────────────┘
```

---

### View Components

#### BudgetListView (Main Screen)
```swift
struct BudgetListView: View {
    @State private var selectedCategory: Category? = nil
    @State private var editingBudget: BudgetEditContext? = nil

    var body: some View {
        NavigationStack {
            if let category = selectedCategory {
                // State 2: Expanded category view
                BudgetCategoryDetailView(
                    category: category,
                    onBack: { selectedCategory = nil },
                    onEditBudget: { context in editingBudget = context }
                )
            } else {
                // State 1: All categories list
                BudgetCategoryListView(
                    onSelectCategory: { selectedCategory = $0 },
                    onEditBudget: { context in editingBudget = context }
                )
            }
        }
        .sheet(item: $editingBudget) { context in
            BudgetNumpadSheet(context: context)
        }
    }
}
```

#### BudgetCategoryListView
```swift
struct BudgetCategoryListView: View {
    // Shows all expense categories
    // Each row shows: icon, name, spent/budget, progress bar
    // Tap row → onSelectCategory (expand to show subcategories)
    // Long-press or tap amount → onEditBudget (show numpad)
}
```

#### BudgetCategoryDetailView
```swift
struct BudgetCategoryDetailView: View {
    let category: Category

    // Header: Back button, category name, month selector
    // First row: Category total budget (tap to edit)
    // Section: Subcategories list
    // Each subcategory row: tap to edit budget via numpad
}
```

#### BudgetNumpadSheet
```swift
struct BudgetNumpadSheet: View {
    let context: BudgetEditContext
    @State private var amountString: String = ""

    // Shows:
    // - Category/Subcategory icon & name
    // - Current spent this month
    // - Amount input field
    // - Minimum amount warning (for categories with sub-budgets)
    // - Numpad (reuse CustomKeypad)
    // - Cancel / Save buttons
    // - Remove Budget option (if budget exists)
}

struct BudgetEditContext: Identifiable {
    let id = UUID()
    let category: Category
    let subCategory: SubCategory?
    let currentBudget: Budget?
    let currentSpent: Double
    let minimumAmount: Double
}
```

#### BudgetRow (Reusable)
```swift
struct BudgetRow: View {
    let icon: String
    let name: String
    let spent: Double
    let budget: Double?  // nil = no budget set
    let currencyCode: String

    // Display:
    // - Icon + Name
    // - Progress bar (or "Tap to set budget" if nil)
    // - Spent / Budget amount
    // - Percentage
}
```

---

## UI/UX Flow

### Tap Behavior

| State | Row Type | Has SubCategories? | Tap Action |
|-------|----------|-------------------|------------|
| State 1 (List) | Category | Yes | → Navigate to State 2 (expanded) |
| State 1 (List) | Category | No | → Show Numpad |
| State 2 (Detail) | Category | - | → Show Numpad |
| State 2 (Detail) | SubCategory | - | → Show Numpad |

### Setting a Category Budget (No SubCategories)
1. Open Budgets tab → See all categories
2. Tap "Utilities" row (has no subcategories) → Numpad appears
3. Enter "$200" → Tap Save
4. Budget saved, row updates with progress

### Setting a Category Budget (With SubCategories)
1. Open Budgets tab → See all categories
2. Tap "Food" row → Expands to show Food + subcategories
3. Tap "Food (Total)" row at top → Numpad appears
4. Enter "$500" → Tap Save
5. Budget saved, row updates with progress

### Setting a SubCategory Budget
1. Open Budgets tab → See all categories
2. Tap "Food" row → Expands to show Food + subcategories
3. Tap "Restaurants" row → Numpad appears
4. Enter "$150" → Tap Save
5. Budget saved, both Restaurants and Food rows update

### Editing with Minimum Constraint
1. "Food" has subcategory budgets: Groceries $200 + Restaurants $150
2. Tap "Food" → Expand → Tap "Food (Total)" → Numpad appears
3. Shows: "Min: $350 (sum of subcategory budgets)"
4. Try to enter "$300" → Save button disabled
5. Enter "$400" → Save works

### Removing a Budget
1. Tap any row with existing budget → Numpad appears
2. Current amount shown in input field
3. Tap "Remove Budget" at bottom
4. Confirm → Budget deleted, row shows "Tap to set budget"

### Viewing Different Months
1. Tap < or > arrows in header
2. Month changes, spent amounts update
3. Budget amounts stay same (monthly recurring)
4. Can view historical spending vs budget

### Navigation
- State 2 has back button (←) to return to State 1
- Swipe right also returns to State 1

---

## Implementation Order

### Phase 1: Data Model
1. [ ] Update Core Data model (remove dates, add subCategory, isActive)
2. [ ] Update BudgetModel.swift computed properties
3. [ ] Update BudgetDTOs.swift

### Phase 2: Repository
4. [ ] Refactor BudgetRepository with new methods
5. [ ] Implement calculateSpent for any month
6. [ ] Implement calculateMinimumAmount for category budgets
7. [ ] Implement fetchBudget(for category/subCategory)

### Phase 3: Service
8. [ ] Refactor BudgetService
9. [ ] Implement getBudgetSummaries(for month)
10. [ ] Implement validateBudgetAmount

### Phase 4: ViewModel
11. [ ] Create new BudgetViewModel (replaces List + Form ViewModels)
    - Categories list with spending
    - Selected category state
    - Edit context for numpad
    - Month navigation
    - Save/delete budget actions

### Phase 5: Views
12. [ ] Create BudgetRow component (reusable)
13. [ ] Create BudgetCategoryListView (State 1)
14. [ ] Create BudgetCategoryDetailView (State 2)
15. [ ] Create BudgetNumpadSheet (numpad for editing)
16. [ ] Refactor BudgetListView (main container)
17. [ ] Delete old BudgetFormView (no longer needed)

### Phase 6: Testing & Polish
18. [ ] Test budget creation (category & subcategory)
19. [ ] Test minimum amount validation
20. [ ] Test spending calculation across months
21. [ ] Test month navigation

---

## Edge Cases to Handle

1. **Deleting SubCategory Budget**: Recalculate parent minimum
2. **Deleting Category**: Cascade delete all related budgets
3. **Category with no SubCategories**: Hide subcategory picker
4. **Transaction without SubCategory**: Only count toward category budget
5. **Split Transaction Items**: Each item's category/subcategory counted separately
6. **Budget amount = 0**: Treat as "no budget" or disabled?
7. **Negative remaining**: Display as over-budget (red)

---

## Questions Resolved

| Question | Decision |
|----------|----------|
| SubCategory budget priority | Both count - sub counts toward sub AND parent |
| Historical data | Yes, can view past months (read-only) |
| Parent budget constraint | Must be >= sum of subcategory budgets |
| Spent storage | Calculate dynamically, don't store |

---

## Files to Modify

| File | Action | Changes |
|------|--------|---------|
| `OneTap.xcdatamodeld` | MODIFY | Remove startDate, endDate, spent. Add subCategory relationship, isActive |
| `BudgetModel.swift` | MODIFY | Remove date-based properties, add dynamic spent calculation |
| `BudgetDTOs.swift` | MODIFY | Remove dates, add subCategoryID |
| `BudgetRepository.swift` | REWRITE | New methods for monthly calculation, hierarchy support |
| `BudgetService.swift` | REWRITE | Simplified API, summary generation |
| `BudgetViewModel.swift` | CREATE | New unified ViewModel |
| `BudgetListView.swift` | REWRITE | New container with state management |
| `BudgetCategoryListView.swift` | CREATE | State 1 view |
| `BudgetCategoryDetailView.swift` | CREATE | State 2 view |
| `BudgetNumpadSheet.swift` | CREATE | Numpad for budget editing |
| `BudgetRow.swift` | CREATE | Reusable row component |
| `BudgetListViewModel.swift` | DELETE | Replaced by BudgetViewModel |
| `BudgetFormViewModel.swift` | DELETE | Replaced by BudgetViewModel |
| `BudgetFormView.swift` | DELETE | Replaced by BudgetNumpadSheet |
| `DependencyContainer.swift` | MODIFY | Update factory methods |
