# Scanned Receipt Badge Feature

## Summary

I've added a user-friendly "Scanned" badge to identify transactions created from receipt scanning, replacing the technical "OCR" terminology with something more intuitive.

## What Changed

### 1. **Added Badge Color** (`/OneTap/Core/Theme/ThemeColors.swift`)
- Added `AppTheme.scanned` color (bright blue) for the scanned receipt badge
- Matches the existing badge color system

### 2. **Transaction List Badge** (`/OneTap/Views/Shared/TransactionRow.swift`)
- Added CoreData import for accessing `isFromOCR` property
- Added "Scanned" badge with camera icon
- Badge appears next to other transaction badges (installment, recurring, claims)
- Shows as: 📷 "Scanned" in bright blue capsule

### 3. **Transaction Detail Badge** (`/OneTap/Views/Transaction/TransactionDetailView.swift`)
- Added "SCANNED RECEIPT" badge in the receipt header
- Displayed in monospaced font to match receipt design
- Shows with camera icon in bright blue capsule

## Visual Design

**List View:**
- Small compact badge: 📷 "Scanned"
- Sits alongside other feature badges
- Bright blue color (#4169E5) for visibility

**Detail View:**
- Larger badge: 📷 "SCANNED RECEIPT"
- Appears below account name in receipt header
- Monospaced font for receipt aesthetic
- More prominent for single-transaction view

## User-Friendly Naming

| Technical Term | User-Friendly Term |
|----------------|-------------------|
| OCR | Scanned |
| OCR Import | Scanned Receipt |

Users immediately understand "Scanned" means the transaction came from scanning a receipt, rather than needing to know what "OCR" means.

## How It Works

The badge uses Key-Value Coding (KVC) to check the `isFromOCR` field:
```swift
private var isFromOCR: Bool {
    (transaction.value(forKey: "isFromOCR") as? Bool) ?? false
}
```

This allows the code to work even before you add the Core Data attribute. Once you add the `isFromOCR` field to the Transaction entity and rebuild, the badge will automatically appear on scanned transactions.

## Next Steps

1. **Add Core Data Field**: Follow instructions in `/ADD_OCR_TRACKING_FIELD.md`
2. **Rebuild**: Clean and build the project
3. **Test**: Scan a new receipt and see the "Scanned" badge appear!

## Files Modified

- `/OneTap/Core/Theme/ThemeColors.swift` - Added scanned badge color
- `/OneTap/Views/Shared/TransactionRow.swift` - Added badge to transaction list
- `/OneTap/Views/Transaction/TransactionDetailView.swift` - Added badge to receipt view

## Expected Behavior

**Transaction List:**
```
┌─────────────────────────────┐
│ 🍔 Lunch                    │
│ McDonald's • 12:30 PM       │
│ 📷 Scanned  💳 Expense  -RM 15.00 │
└─────────────────────────────┘
```

**Transaction Detail (Receipt):**
```
╔═══════════════════════════╗
║   MCDONALD'S SETIAWANGSA  ║
║                           ║
║  📷 SCANNED RECEIPT        ║
║                           ║
║  DATE:    17 JAN 2026     ║
║  TIME:    12:30 PM        ║
╚═══════════════════════════╝
```

The build succeeded and everything is ready to use once you add the Core Data field!
