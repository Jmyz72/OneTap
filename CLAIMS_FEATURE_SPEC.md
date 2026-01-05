# Advanced Claims & Reimbursements Feature Specification

## 1. Overview
The **Claims Feature** allows users to flag transactions as "Claims" (reimbursable expenses) to track money owed to them. Users can later bundle these pending claims into a single "Reimbursement" transaction (Income), allowing for flexible settlement where the actual reimbursed amount may differ from the sum of expenses.

## 2. User Stories
*   **As a user**, I want to flag an expense as a "Claim" so I remember to submit it later.
*   **As a user**, I want to see a list of all my pending claims in one place.
*   **As a user**, I want to select multiple claims and settle them with a single reimbursement transaction.
*   **As a user**, I want to modify the final reimbursement total (e.g., if the company pays less than I spent) without altering the original expense records.

## 3. Workflow Description

### 3.1. Recording the Expense
1.  User adds a Transaction (e.g., $150 Food).
2.  User toggles `[x] Mark as Claim`.
3.  App saves transaction as normal Expense (-$150).
4.  App statuses this transaction as **Claim: Pending**.

### 3.2. Managing Claims (The "Basket")
1.  User opens "Claims" screen.
2.  List shows all transactions with status **Claim: Pending**.
3.  User multi-selects items to settle (e.g., Lunch $50 + Taxi $30 = $80 Total).

### 3.3. Settling / Reimbursement
1.  User taps "Settle Selected".
2.  App presents a **"New Reimbursement"** screen.
    *   **Total Amount:** Pre-filled with sum of selected items ($80).
    *   **Editable:** User can change this to $75 (if limit applied).
    *   **Deposit To:** User selects the account receiving the money.
3.  **Confirming:**
    *   App creates **ONE Income Transaction** for $75 (Type: Reimbursement).
    *   App updates the selected original expenses status to **Claim: Settled**.
    *   (Optional) App links the expenses to the reimbursement for history.

## 4. Technical Architecture

### 4.1. Core Data Model Changes (`Transaction` Entity)
New attributes:
*   `isClaim`: `Boolean` (Default: `false`)
*   `claimStatus`: `String` (Enum: `none`, `pending`, `settled`. Default: `none`)
*   `settledDate`: `Date` (Optional. When it was reimbursed.)
*   `reimbursementID`: `UUID` (Optional. ID of the Income transaction that settled this claim.)

### 4.2. Logic Updates

#### **A. Add Transaction View**
*   Simple Toggle: `Mark as Claim`.
*   No extra amount fields needed.

#### **B. New "Claims Manager" View**
*   Fetch Request: `isClaim == true AND claimStatus == "pending"`.
*   Multi-selection capability.
*   "Settle" action flow.

#### **C. Settle Logic**
*   Create new Transaction (Type: Income).
*   Batch update selected transactions:
    *   `claimStatus` = `settled`
    *   `settledDate` = Now
    *   `reimbursementID` = New Transaction ID

## 5. UI Mockup (Mental Model)

**Claims List:**
```
[ ] Pending Claims
   [x] 12 Jan - Team Lunch - $50.00
   [x] 14 Jan - Grab - $30.00
   [ ] 15 Jan - Personal - $10.00

[ Settle 2 Claims ($80.00) ]
```

**Reimbursement Screen:**
```
Total Claimed: $80.00
Actual Reimbursement: [$75.00] (User edits this)
Deposit To: [ Maybank ]

[ Confirm ]
```