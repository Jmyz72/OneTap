# Receipt Scanner - OCR Transaction Filtering Update

## Summary

I've updated the Receipt Scanner screen to show **only transactions created from OCR scanning**, not all transactions. This makes the screen more useful as a receipt history viewer.

## What Changed

### 1. **TransactionRepository** (`/OneTap/Core/Repositories/TransactionRepository.swift`)
- Added `isFromOCR: Bool = false` parameter to `createTransaction()` method
- This field tracks which transactions were created from OCR vs manual entry

### 2. **OCRImportViewModel** (`/OneTap/ViewModels/OCRImportViewModel.swift`)
- Updated to pass `isFromOCR: true` when creating transactions from scanned receipts
- All OCR-imported transactions are now marked automatically

### 3. **ScanReceiptViewModel** (`/OneTap/ViewModels/ScanReceiptViewModel.swift`)
- Added filter predicate: `isFromOCR == YES`
- Now shows only the 10 most recent OCR-scanned transactions instead of all transactions

### 4. **ScanReceiptView** (`/OneTap/Views/Scanner/ScanReceiptView.swift`)
- Already updated in previous work to show transaction history with floating scan button
- Works seamlessly with the new OCR filtering

## What You Need to Do

### Step 1: Add `isFromOCR` Field to Core Data Model

You need to add a new attribute to the Transaction entity in Xcode:

1. **Open** `OneTap.xcodeproj` in Xcode
2. **Navigate to** `OneTap.xcdatamodeld` in the Project Navigator
3. **Click** on `OneTap.xcdatamodel` to open the data model editor
4. **Select** the **Transaction** entity in the left sidebar
5. **Click** the **+** button in the Attributes section
6. **Configure** the new attribute:
   - **Name**: `isFromOCR`
   - **Type**: `Boolean`
   - **Default Value**: `NO`
   - **Optional**: Unchecked
   - **Uses Scalar Type**: Checked

7. **Save** with `Cmd+S`
8. **Clean** build folder: `Product` → `Clean Build Folder` (or `Cmd+Shift+K`)
9. **Build** the project: `Cmd+B`

### Step 2: Test the Feature

1. **Run** the app
2. **Navigate** to the Receipt Scanner tab
3. **Scan** a new receipt using the + button
4. **Verify** that only OCR-scanned receipts appear in the list

## Migration Handling

Core Data will automatically perform lightweight migration:
- **Existing transactions** will get `isFromOCR = false` (manual entries)
- **New OCR transactions** will get `isFromOCR = true` (scanned receipts)
- No data loss occurs during migration

## Technical Details

The code uses **Key-Value Coding (KVC)** to set the `isFromOCR` field:
```swift
transaction.setValue(isFromOCR, forKey: "isFromOCR")
```

This allows the code to compile even before you add the Core Data attribute. Once you add the attribute and rebuild, Core Data will properly manage this field.

## Files Modified

- `/OneTap/Core/Repositories/TransactionRepository.swift`
- `/OneTap/ViewModels/OCRImportViewModel.swift`
- `/OneTap/ViewModels/ScanReceiptViewModel.swift`

## Files Created

- `/ADD_OCR_TRACKING_FIELD.md` - Detailed instructions for Core Data changes
- `/RECEIPT_SCANNER_UPDATE_SUMMARY.md` - This file

## Expected Behavior

**Before:** Receipt Scanner showed all transactions (manual + OCR)
**After:** Receipt Scanner shows only OCR-scanned receipts

**Empty State:**
- Shows when no OCR receipts have been scanned yet
- Displays feature descriptions and scan options

**With OCR Receipts:**
- Shows last 10 scanned receipts
- Each receipt is clickable to view details
- Floating + button provides quick scan access

The build was successful, and everything is ready for you to add the Core Data field!
