# Known Issues and Bugs

**Last Updated:** 2026-01-12
**Status:** Needs fixing before production release

This document lists all known critical bugs and logic issues in the OneTap personal finance app that cause incorrect financial calculations or data loss.

---

## 🔴 Critical Bugs (Must Fix)

### Bug #1: Split Transaction Amount Mismatch

**Severity:** 🔴 Critical
**Impact:** Incorrect account balances, lost money tracking
**Location:** `AddTransactionViewModel.swift` lines 104-109, 218-233
**Estimated Fix Time:** 30 minutes

#### Problem Description

When creating a split transaction, the sum of split items is not validated to equal the parent transaction amount. This allows users to create transactions where the total doesn't match the items, causing incorrect balance tracking.

#### Example Scenario

```
User creates transaction for: $100
Split items:
  - Food: $30
  - Drinks: $40
  - Tip: $25
  Total: $95

Transaction saves with amount=$100, but items sum to $95
Difference: $5 unaccounted for
```

#### Current Code (Buggy)

```swift
// Line 104-109: totalAmount calculation
var totalAmount: Double {
    if splitItems.isEmpty {
        return Double(amountString) ?? 0
    } else {
        // BUG: Adds splitItems total + amountString together!
        return splitItems.reduce(0) { $0 + $1.amount } + (Double(amountString) ?? 0)
    }
}

// Line 218-233: Validation only checks if items > 0
let splitTotal = splitItems.reduce(0) { $0 + $1.amount }
guard splitItems.allSatisfy({ $0.amount > 0 }) else {
    throw ValidationError.invalidAmount
}
// Missing: guard splitTotal == transaction.amount
```

#### Impact

- Account balances become incorrect over time
- Transaction detail view shows different amount than sum of items
- Users lose track of money ($5 vanishes in the example)
- Historical reports will have wrong totals

#### Recommended Fix

```swift
// In AddTransactionViewModel.swift

// Fix 1: totalAmount should use splitItems OR amountString, not both
var totalAmount: Double {
    if splitItems.isEmpty {
        return Double(amountString) ?? 0
    } else {
        return splitItems.reduce(0) { $0 + $1.amount }
    }
}

// Fix 2: Add validation in saveTransaction()
if !splitItems.isEmpty {
    let splitTotal = splitItems.reduce(0) { $0 + $1.amount }
    let expectedTotal = Double(amountString) ?? 0

    guard abs(splitTotal - expectedTotal) < 0.01 else {
        throw ValidationError.splitItemsMismatch(
            expected: expectedTotal,
            actual: splitTotal
        )
    }
}
```

---

### Bug #2: Transfer Between Different Currencies - No Validation

**Severity:** 🔴 Critical
**Impact:** Multi-currency users have completely wrong balances
**Location:** `TransferService.swift` lines 51-97, `ValidationService.swift` lines 56-66
**Estimated Fix Time:** 1 hour

#### Problem Description

The app allows transfers between accounts with different currencies without any exchange rate conversion or validation. The numeric amount is simply added/subtracted without considering the currency difference.

#### Example Scenario

```
Checking Account (USD): $10,000
Credit Card (MYR): RM5,000

User transfers $1,000 from Checking to Credit Card

Result:
- Checking (USD): $9,000 ✅ (correct)
- Credit Card (MYR): RM6,000 ❌ (WRONG!)

Expected at 4.7 exchange rate:
- Credit Card should show: RM9,700 (5000 + 4700)

Net worth calculation:
- Before: $10,000 + RM5,000/4.7 = $11,064
- After (wrong): $9,000 + RM6,000/4.7 = $10,277 (lost $787!)
- After (correct): $9,000 + RM9,700/4.7 = $11,064
```

#### Current Code (Buggy)

```swift
// TransferService.swift - createTransfer()
func createTransfer(
    amount: Double,
    fromAccount: Account,
    toAccount: Account,
    // ...
) async throws -> (Transaction, Transaction) {
    // NO currency check here

    // Source transaction deducts amount
    sourceTransaction.amount = amount

    // Destination adds same numeric amount (ignoring currency!)
    destinationTransaction.amount = amount

    // Missing:
    // 1. Check if fromAccount.currency == toAccount.currency
    // 2. Apply exchange rate if different
    // 3. Show exchange rate to user
}
```

#### Impact

- Multi-currency users have completely wrong balances
- Cannot accurately track net worth
- Money appears to vanish or appear from nowhere
- International users cannot use the app reliably

#### Recommended Fix

**Option A: Prevent cross-currency transfers**
```swift
// In ValidationService.swift
func validateTransfer(from: Account, to: Account) throws {
    guard from.currency == to.currency else {
        throw ServiceError.validationFailed(
            "Cannot transfer between accounts with different currencies. " +
            "Convert currency manually first."
        )
    }
}
```

**Option B: Add exchange rate support (more complex)**
```swift
// New ExchangeRateService needed
func createTransfer(
    amount: Double,
    fromAccount: Account,
    toAccount: Account,
    exchangeRate: Double? = nil
) async throws {
    let rate = exchangeRate ?? getExchangeRate(
        from: fromAccount.currency,
        to: toAccount.currency
    )

    sourceTransaction.amount = amount
    destinationTransaction.amount = amount * rate
}
```

---

### Bug #3: Credit Card Limit Not Enforced

**Severity:** 🔴 Critical
**Impact:** Users can overspend beyond credit limit, limit field is useless
**Location:** `ValidationService.swift`, `AccountModel.swift`
**Estimated Fix Time:** 30 minutes

#### Problem Description

Credit card accounts have a `creditLimit` field in Core Data, but nothing prevents transactions that would exceed this limit. The field is stored but never validated.

#### Example Scenario

```
Credit Card Account:
- Credit Limit: $5,000
- Current Balance: $4,800 (amount owed)

User makes purchase: $500

Expected: ❌ Error "Transaction would exceed credit limit of $5,000"
Actual: ✅ Transaction succeeds, balance becomes $5,300

User now owes $5,300 on a $5,000 limit card
```

#### Current Code (Buggy)

```swift
// Core Data model has the field
<attribute name="creditLimit"
           attributeType="Double"
           defaultValueString="0.0"/>

// But ValidationService.swift has NO validation
func validateTransaction(
    amount: Double,
    type: TransactionType,
    account: Account?,
    // ...
) throws {
    guard amount > 0 else {
        throw ServiceError.validationFailed("Amount must be greater than zero")
    }

    // Missing: Check credit limit for credit cards
}
```

#### Impact

- Credit limit setting is decorative only
- Users expect protection from overspending but get none
- Doesn't match real-world credit card behavior
- Could lead to actual overspending in real life if user trusts the app

#### Recommended Fix

```swift
// In ValidationService.swift
func validateTransaction(
    amount: Double,
    type: TransactionType,
    account: Account?,
    // ...
) throws {
    // Existing validations...

    // Add credit limit validation
    if let account = account,
       account.typeEnum == .creditCard,
       type == .expense {

        let currentOwed = account.balance // For credit cards, positive = owed
        let newBalance = currentOwed + amount

        if account.creditLimit > 0 && newBalance > account.creditLimit {
            let available = account.creditLimit - currentOwed
            throw ServiceError.validationFailed(
                "Transaction would exceed credit limit. " +
                "Available: \(formatCurrency(available, account.currency))"
            )
        }
    }
}
```

---

### Bug #4: Monthly Billing Date Edge Case (Day 31)

**Severity:** 🔴 Critical
**Impact:** Recurring bills scheduled on wrong dates, billing cycles drift
**Location:** `RecurringTransactionService.swift` lines 192-230, 346-381
**Estimated Fix Time:** 1 hour

#### Problem Description

When a recurring transaction is set for the 31st of each month, the date calculation fails in months with fewer than 31 days, causing the billing date to drift and become inconsistent.

#### Example Scenario

```
User sets credit card bill: "Due monthly on the 31st"

Actual behavior:
- January 31: ✅ Correct (31st)
- February 28: ✅ Correct (last day of Feb)
- March 28: ❌ WRONG (adds 1 month from Feb 28, should be March 31)
- April 28: ❌ WRONG (should be April 30)
- May 28: ❌ WRONG (should be May 31)

Billing cycles: 28 days, 28 days, 31 days, 33 days (inconsistent!)
Expected: Always last day of month
```

#### Real-World Impact

```
Credit card statement due date: 31st
- App schedules payment for March 28 instead of March 31
- User makes payment on March 28 (when app reminds them)
- Bank expects payment by March 31
- User gets charged late fee for being "3 days early" but in wrong cycle
```

#### Current Code (Buggy)

```swift
// Line 225 in calculateNextDate()
components.day = min(monthlyDay, daysInMonth)

// Problem:
// If monthlyDay = 31 and February has 28 days:
//   components.day = min(31, 28) = 28
// Then calendar.date(byAdding: .month, value: 1, to: Feb28)
//   Returns: March 28 (not March 31!)
```

#### Impact

- Recurring bills are scheduled on incorrect dates
- Late payment fees in real life
- User loses trust in the app
- Billing cycle length varies wildly (28-33 days)
- Cannot rely on app for bill reminders

#### Recommended Fix

```swift
private func calculateNextDate(for recurring: RecurringTransaction, from date: Date) -> Date? {
    let calendar = Calendar.current
    let monthlyDay = Int(recurring.monthlyDay ?? 0)

    if monthlyDay == 0 || monthlyDay > 28 {
        // Use "last day of month" logic
        var components = calendar.dateComponents([.year, .month], from: date)

        // Move to next month
        components.month! += 1

        // Get the last day of that month
        guard let firstOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else {
            return nil
        }

        components.day = range.count // Last day
        return calendar.date(from: components)
    } else {
        // Day 1-28: safe to use standard month addition
        return calendar.date(byAdding: .month, value: 1, to: date)
    }
}
```

---

### Bug #5: Account Deletion Cascades to Transactions (Data Loss)

**Severity:** 🟠 High Priority
**Impact:** Permanent data loss, no way to recover transaction history
**Location:** `OneTap.xcdatamodel` line 18
**Estimated Fix Time:** 30 minutes

#### Problem Description

The Core Data relationship between `Account` and `Transaction` uses `deletionRule="Cascade"`, which means deleting an account permanently deletes ALL its transactions. There's no way to recover this data.

#### Example Scenario

```
User has account "Old Credit Card"
- 500 transactions over 2 years
- $50,000 total spending history
- Closed 6 months ago but kept for records

User accidentally taps "Delete Account"
(or wants to clean up closed accounts)

Result:
- All 500 transactions deleted permanently
- Cannot generate year-end tax reports
- Cannot see historical spending patterns
- Cannot prove purchase history for warranty claims
```

#### Current Code (Buggy)

```xml
<!-- OneTap.xcdatamodel line 18 -->
<relationship name="transactions"
             optional="YES"
             toMany="YES"
             deletionRule="Cascade"  <!-- Problem here -->
             destinationEntity="Transaction"
             inverseName="account"
             inverseEntity="Transaction"/>
```

#### Impact

- **Data loss is permanent** - no undo, no recovery
- Users cannot archive closed accounts
- Historical analysis becomes impossible
- Tax reporting requires historical data
- Violates financial best practice (keep records for 7 years)
- One misclick destroys years of data

#### Recommended Fix

**Option A: Change deletion rule (safest)**
```xml
<relationship name="transactions"
             deletionRule="Nullify"  <!-- Change from Cascade -->
             .../>
```

Then add "archived" flag to accounts instead of deleting:
```swift
// Add to Account entity
<attribute name="isArchived" attributeType="Boolean" defaultValueString="NO"/>

// Filter in queries
let request: NSFetchRequest<Account> = Account.fetchRequest()
request.predicate = NSPredicate(format: "isArchived == NO")
```

**Option B: Soft delete with warning**
```swift
func deleteAccount(_ account: Account) throws {
    let transactionCount = account.transactions?.count ?? 0

    if transactionCount > 0 {
        // Show confirmation alert
        throw ServiceError.validationFailed(
            "This account has \(transactionCount) transactions. " +
            "Deleting it will permanently delete all transaction history. " +
            "Consider archiving instead."
        )
    }

    // Proceed with deletion
}
```

---

## 🟡 Medium Priority Issues

### Issue #6: Installment Plans Don't Model Interest

**Severity:** 🟡 Medium
**Impact:** Incorrect remaining balance calculations for real BNPL services
**Location:** `RecurringTransactionModel.swift` lines 37-44, `RecurringTransactionService.swift` lines 256-343

#### Problem Description

Installment plans assume simple division (totalAmount ÷ numberOfPayments) without accounting for interest or fees that real Buy Now Pay Later services charge.

#### Example Scenario

```
Real BNPL purchase:
- Item price: $1,200
- Plan: 12 monthly payments at 15% APR
- Actual payment: $107.50/month
- Total paid: $1,290

App shows:
- Monthly payment: $100/month
- Total: $1,200

After 6 payments:
- App shows remaining: $600 (6 × $100)
- Reality remaining: $645 (6 × $107.50)
- Difference: $45 underpaid
```

#### Current Code

```swift
// RecurringTransactionModel.swift line 37-38
var paidAmount: Double {
    return amount * Double(occurrencesCount)  // Assumes no interest
}

// RecurringTransactionModel.swift line 42-44
var remainingAmount: Double {
    return installmentTotalAmount - paidAmount  // Wrong if interest exists
}
```

#### Impact

- Early payoff calculations are incorrect
- Users underestimate true cost of financing
- Cannot accurately track BNPL debt
- App doesn't match real-world financing

#### Recommended Fix

Add interest rate fields to installment plans:
```swift
// Add to RecurringTransaction entity
<attribute name="interestRate"
           optional="YES"
           attributeType="Double"
           defaultValueString="0.0"/>
<attribute name="effectiveAPR"
           optional="YES"
           attributeType="Double"
           defaultValueString="0.0"/>

// Calculate true monthly payment
func calculateMonthlyPayment(
    principal: Double,
    apr: Double,
    months: Int
) -> Double {
    if apr == 0 { return principal / Double(months) }

    let monthlyRate = apr / 12.0
    let payment = principal * (monthlyRate * pow(1 + monthlyRate, Double(months)))
                  / (pow(1 + monthlyRate, Double(months)) - 1)
    return payment
}
```

---

### Issue #7: Adjustment Transactions Set Balance Without Audit Trail

**Severity:** 🟡 Medium
**Impact:** Users can manipulate balances without explanation
**Location:** `BalanceService.swift` lines 179-181

#### Problem Description

The "Adjustment" transaction type simply sets the account balance to any value, bypassing all normal transaction logic. There's no audit trail explaining why the balance was changed.

#### Example Scenario

```
Account balance: $1,000

User creates adjustment transaction: -$5,000

New balance: -$5,000

Questions:
- Why did balance change by $6,000?
- What was corrected?
- Is this legitimate or a mistake?
- No way to know from transaction history
```

#### Current Code

```swift
// BalanceService.swift line 179-181
case .adjustment:
    return amount  // Sets balance to this exact amount, no questions asked
```

#### Impact

- Users can artificially inflate/deflate balances
- No accountability for balance corrections
- Historical analysis shows mysterious jumps
- Cannot audit why balances changed

#### Recommended Fix

```swift
// Add adjustment reason field
<attribute name="adjustmentReason"
           optional="YES"
           attributeType="String"/>

// Require reason for adjustments
func createAdjustment(
    account: Account,
    newBalance: Double,
    reason: String,  // Required
    notes: String?
) throws -> Transaction {
    guard !reason.isEmpty else {
        throw ValidationError.missingAdjustmentReason
    }

    // Create transaction with explanation
    let adjustment = Transaction(context: context)
    adjustment.type = TransactionType.adjustment.rawValue
    adjustment.amount = newBalance
    adjustment.title = "Balance Adjustment: \(reason)"
    adjustment.notes = notes

    return adjustment
}
```

---

## 📊 Summary

| Bug # | Severity | Issue | Impact | Est. Fix Time |
|-------|----------|-------|--------|---------------|
| 1 | 🔴 Critical | Split transaction amount mismatch | Wrong balances | 30 min |
| 2 | 🔴 Critical | Currency transfer no validation | Multi-currency balances wrong | 1 hour |
| 3 | 🔴 Critical | Credit limit not enforced | Overspending not prevented | 30 min |
| 4 | 🔴 Critical | Day 31 billing date drift | Bills on wrong dates | 1 hour |
| 5 | 🟠 High | Account deletion cascade | Permanent data loss | 30 min |
| 6 | 🟡 Medium | No interest in installments | Incorrect remaining balance | 2 hours |
| 7 | 🟡 Medium | Adjustment no audit trail | Balance manipulation | 1 hour |

**Total Critical Bug Fix Time:** ~3.5 hours
**Total All Issues Fix Time:** ~6.5 hours

---

## Testing Checklist

After fixing each bug, verify:

### Bug #1: Split Transactions
- [ ] Create split transaction where items sum equals transaction amount (should succeed)
- [ ] Try to create split transaction where items sum differs (should fail with error)
- [ ] Edit existing split transaction and change amounts (should validate)
- [ ] Create transaction without split items (should still work)

### Bug #2: Currency Transfers
- [ ] Transfer between same currency accounts (should work)
- [ ] Try transfer between different currency accounts (should show error or exchange rate UI)
- [ ] Net worth should remain consistent after transfer

### Bug #3: Credit Limit
- [ ] Make purchase on credit card within limit (should succeed)
- [ ] Try to make purchase that exceeds limit (should fail with clear error)
- [ ] Credit cards with 0 limit should not enforce (unlimited)

### Bug #4: Day 31 Billing
- [ ] Create monthly recurring for day 31
- [ ] Process through February, March, April, May
- [ ] Verify always processes on last day of each month
- [ ] Day 31 in 31-day months, day 30 in 30-day months, day 28/29 in February

### Bug #5: Account Deletion
- [ ] Try to delete account with transactions (should warn or prevent)
- [ ] Archive account instead of deleting
- [ ] Archived accounts don't show in active list
- [ ] Can view transaction history for archived accounts

---

## References

- Code review completed: 2026-01-12
- Build status: All files compile successfully
- Last commit: `90a78d6` - Fix all build warnings

---

**Next Steps:**
1. Review and prioritize which bugs to fix first
2. Create feature branch: `git checkout -b bugfix/critical-issues`
3. Fix bugs systematically with tests
4. Commit after each bug fix
5. Full regression testing before merge
