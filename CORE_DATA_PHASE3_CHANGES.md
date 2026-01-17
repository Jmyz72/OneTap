# Core Data Changes Required for Phase 3 - OCR Learning

Phase 3 introduces machine learning capabilities that require new Core Data entities to store learning history.

## New Entities to Add

You need to add 3 new entities to `OneTap.xcdatamodeld`:

---

### 1. **MerchantCorrection**

Stores user corrections to merchant names for fuzzy matching and learning.

**Attributes:**
- `id` - UUID - Not Optional
- `ocrText` - String - Not Optional
  (The raw text extracted by OCR)
- `correctedName` - String - Not Optional
  (The corrected merchant name the user entered)
- `occurrences` - Integer 64 - Not Optional - Default: 1
  (How many times this pattern has been seen)
- `lastSeen` - Date - Not Optional
  (When this pattern was last encountered)
- `createdAt` - Date - Not Optional
  (When this pattern was first learned)

**Relationships:** None

**Indexes:**
- `ocrText` (for fast lookups)
- `correctedName` (for fuzzy matching)

---

### 2. **MerchantCategoryMapping**

Stores user's category preferences for specific merchants.

**Attributes:**
- `id` - UUID - Not Optional
- `merchantName` - String - Not Optional
  (The merchant name)
- `categoryName` - String - Not Optional
  (The category name the user prefers for this merchant)
- `occurrences` - Integer 64 - Not Optional - Default: 1
  (How many times this mapping has been used)
- `lastUsed` - Date - Not Optional
  (When this mapping was last used)
- `createdAt` - Date - Not Optional
  (When this mapping was first created)

**Relationships:** None

**Indexes:**
- `merchantName` (for fast lookups)

---

### 3. **ItemCategoryMapping**

Stores user's category preferences for specific line items.

**Attributes:**
- `id` - UUID - Not Optional
- `itemTitle` - String - Not Optional
  (The line item title, e.g., "Coffee", "Nasi Lemak")
- `categoryName` - String - Not Optional
  (The category name the user prefers for this item)
- `occurrences` - Integer 64 - Not Optional - Default: 1
  (How many times this mapping has been used)
- `lastUsed` - Date - Not Optional
  (When this mapping was last used)
- `createdAt` - Date - Not Optional
  (When this mapping was first created)

**Relationships:** None

**Indexes:**
- `itemTitle` (for fast lookups)

---

## How to Add These Entities

### Using Xcode:

1. **Open the Core Data Model:**
   - In Xcode, navigate to `OneTap/OneTap.xcdatamodeld`
   - Click on it to open the Data Model Editor

2. **Add New Entity (repeat for each entity):**
   - Click the "+" button at the bottom of the Entities list
   - Name it (e.g., `MerchantCorrection`)
   - Click on the entity to select it

3. **Add Attributes:**
   - In the Attributes section, click "+"
   - Enter attribute name
   - Select Type from dropdown
   - Uncheck "Optional" if marked as "Not Optional" above
   - Set Default Value if specified

4. **Add Fetch Indexes (for performance):**
   - Select the entity
   - Go to the "Indexes" tab in the Data Model Inspector (right panel)
   - Click "+" to add an index
   - Select the attribute to index

5. **Generate NSManagedObject Subclasses:**
   - Select all three new entities
   - Go to Editor → Create NSManagedObject Subclass...
   - Select your data model
   - Check all three entities
   - Choose Swift language
   - Save in the Models/ directory

---

## Verification

After adding the entities, the following should work:

```swift
// Test MerchantCorrection
let correction = MerchantCorrection(context: viewContext)
correction.id = UUID()
correction.ocrText = "Starbcks"  // OCR error
correction.correctedName = "Starbucks"  // Correct name
correction.occurrences = 1
correction.lastSeen = Date()
correction.createdAt = Date()

// Test MerchantCategoryMapping
let mapping = MerchantCategoryMapping(context: viewContext)
mapping.id = UUID()
mapping.merchantName = "Starbucks"
mapping.categoryName = "Food & Drink"
mapping.occurrences = 1
mapping.lastUsed = Date()
mapping.createdAt = Date()

// Test ItemCategoryMapping
let itemMapping = ItemCategoryMapping(context: viewContext)
itemMapping.id = UUID()
itemMapping.itemTitle = "Coffee"
itemMapping.categoryName = "Food & Drink"
itemMapping.occurrences = 1
itemMapping.lastUsed = Date()
itemMapping.createdAt = Date()

try viewContext.save()
```

---

## Migration

Since you're adding new entities (not modifying existing ones), **lightweight migration** will handle this automatically. The app will:

1. Detect the new model version
2. Create the new entity tables in SQLite
3. Preserve all existing data

No manual migration code is required!

---

## What These Entities Enable

Once added, these entities power:

1. **Fuzzy Matching** - "Starbcks" → "Starbucks" (learns from your corrections)
2. **Smart Categorization** - Automatically suggests "Food & Drink" for "Starbucks"
3. **Item Learning** - Remembers "Coffee" should be "Food & Drink"
4. **Pattern Recognition** - Improves accuracy over time as you use the app

The more you use OCR import, the smarter it gets!

---

## Privacy Notes

All learning data is stored **locally on device** in your Core Data database. Nothing is sent to external servers.

Users can clear learning data via:
- `OCRLearningService.clearAllLearningData()` - Clears everything
- `OCRLearningService.clearOldLearningData(olderThan: days)` - Clears old patterns

---

## Optional: Add Settings UI

You may want to add a settings screen for users to:
- View learning statistics (`getLearningSummary()`)
- Clear learning data
- Export/import learning patterns

Example:
```swift
let summary = ocrLearningService.getLearningSummary()
print("Merchant corrections: \(summary.merchantCorrections)")
print("Merchant-category mappings: \(summary.merchantCategoryMappings)")
print("Item-category mappings: \(summary.itemCategoryMappings)")
print("Total learnings: \(summary.totalLearnings)")
```

---

## Next Steps

1. Add the 3 entities to Core Data model
2. Generate NSManagedObject subclasses
3. Build the project (should compile successfully)
4. Test OCR import - the system will start learning automatically!

The learning is passive - it happens automatically as users:
- Correct merchant names (fuzzy matching learns)
- Assign categories to merchants (category learning)
- Assign categories to line items (item learning)
