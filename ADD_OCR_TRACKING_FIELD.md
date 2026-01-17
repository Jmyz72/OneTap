# Adding OCR Tracking to Transaction Entity

## Overview
To show only OCR-scanned receipts in the Receipt Scanner screen, we need to add a field to track which transactions were created from OCR.

## Steps to Add `isFromOCR` Attribute

### 1. Open Core Data Model in Xcode

1. Open `OneTap.xcodeproj` in Xcode
2. Navigate to `OneTap.xcdatamodeld` in the Project Navigator
3. Click on `OneTap.xcdatamodel` to open the data model editor

### 2. Add New Attribute to Transaction Entity

1. Select the **Transaction** entity in the left sidebar
2. In the Attributes section, click the **+** button to add a new attribute
3. Configure the new attribute:
   - **Name**: `isFromOCR`
   - **Type**: `Boolean`
   - **Default Value**: `NO`
   - **Optional**: Unchecked (leave it required)
   - **Uses Scalar Type**: Checked

### 3. Save the Model

1. Press `Cmd+S` to save the model
2. Clean the build folder: `Product` → `Clean Build Folder` (or `Cmd+Shift+K`)
3. Build the project: `Cmd+B`

## What This Enables

After adding this field:
- OCR-imported transactions will be marked with `isFromOCR = true`
- The Receipt Scanner screen will show only these OCR transactions
- Manual transactions will have `isFromOCR = false`

## Migration

Core Data will automatically handle lightweight migration for this change since we're only adding a new optional attribute with a default value. Existing transactions will automatically get `isFromOCR = false`.

## Code Changes Already Prepared

The following files have been updated to support this field:
- `OCRImportViewModel.swift` - Sets `isFromOCR = true` when creating transactions
- `ScanReceiptViewModel.swift` - Filters to show only OCR transactions
- `TransactionRepository.swift` - Added parameter to `createTransaction()`

Once you add the Core Data attribute and rebuild, everything will work automatically.
