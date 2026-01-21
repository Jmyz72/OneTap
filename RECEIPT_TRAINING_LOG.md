# Receipt Training Log

This document tracks the receipt formats we've trained the OCR/extraction system to handle. Each entry documents patterns, edge cases, and extraction rules learned from real receipts.

---

## Receipt Format #1: Makan Hall

**Date Trained:** 2026-01-17
**Location:** Central Market, Kuala Lumpur
**Receipt Type:** Food court / hawker stall

### Sample Receipt Structure

```
Makan Hall
I Love Yoo!
CHAMP LEADER SDN. BHD.
202101007298 (1407597-P)
Lot G-08, Ground Floor,
Central Market, Jalan Hang Kasturi,
50050 Kuala Lumpur.
Tax Invoice
Jan 17, 2026 3:12 PM
Receipt: 260117TVRNVBC
--------------------------
I Love Yoo
Dine In - I Love Yoo
Pax: 1
RM7.39
1x Tau Foo Fa
- Take Away RM7.39
--------------------------
Subtotal          RM7.39
Rounding          RM0.01
Total             RM7.40
--------------------------
Amount            RM7.40
ewallet - I Love Yoo
Payment Status
Thank you for dining with us
Please Come Again
RM7.39
RM0.01
RM7.40
RM7.40
RM7.40
Paid
```

### Extraction Rules Learned

#### 1. Merchant Name
| Position | Content | Use As |
|----------|---------|--------|
| Line 1 | Makan Hall | Food court name (ignore) |
| Line 2 | I Love Yoo! | **Store/Brand name (USE THIS)** |
| Line 3 | CHAMP LEADER SDN. BHD. | Company registration name (ignore) |

**Rule:** Look for the store/brand name, NOT the "SDN. BHD." company name. The merchant is typically the line after the food court name and before the company registration.

#### 2. Item Name + Modifier Pattern
```
1x Tau Foo Fa        ← Item name (with quantity prefix)
- Take Away RM7.39   ← Modifier + Price
```

**Rule:** Combine item name with modifier in parentheses:
- Extract: "Tau Foo Fa" + "Take Away"
- Result: **"Tau Foo Fa (Take Away)"**

Common modifiers to detect:
- "Take Away" / "Takeaway"
- "Dine In" / "Dine-In"

#### 3. Single Item + Rounding
```
Subtotal    RM7.39
Rounding    RM0.01
Total       RM7.40
```

**Rule:** When there's only 1 line item:
- Do NOT create split transaction
- Use the **Total amount** (RM7.40), not the subtotal
- Use item name as transaction title
- Rounding is absorbed into total (no need to show separately)

#### 4. Quantity Prefix
```
1x Tau Foo Fa
```

**Rule:** Strip quantity prefix (e.g., "1x", "2x") from item name when quantity is 1. Keep it if quantity > 1.

### Patterns to Ignore
- Company registration number: `202101007298 (1407597-P)`
- Pax count: `Pax: 1`
- Payment confirmations: `Paid`, `Payment Status`
- Repeated totals at bottom (receipt often prints total multiple times)

### Test Case

**Input Receipt:** Makan Hall / I Love Yoo! receipt
**Expected Extraction:**
- Merchant: `I Love Yoo!`
- Item: `Tau Foo Fa (Take Away)`
- Amount: `RM 7.40`
- Date: `Jan 17, 2026 3:12 PM`

---

## Adding New Receipt Formats

When training a new receipt format:

1. Add a new section with `## Receipt Format #N: [Name]`
2. Include a sample receipt structure (anonymize if needed)
3. Document extraction rules with examples
4. Note any patterns to ignore
5. Add a test case with expected output

---

## Common Malaysian Receipt Patterns

### Merchant Name Hierarchy
1. Brand/Store name (use this)
2. Company name with "SDN. BHD." / "BHD." (ignore)
3. Food court/mall name (context only)

### Rounding (Malaysia)
- 1 sen coins eliminated
- Totals round to nearest 5 sen
- Look for "Rounding" line with small amount (±0.01 to ±0.02)

### Common Modifiers
- Take Away / Takeaway / TA
- Dine In / Dine-In / DI
- Add On / Extra
- Less Sugar / No Ice / etc.

### Tax Types
- SST (Sales and Service Tax)
- GST (old, replaced by SST)
- Service Charge (typically 10%)
