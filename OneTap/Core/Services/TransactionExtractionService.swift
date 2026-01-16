//
//  TransactionExtractionService.swift
//  OneTap
//
//  Extracts transaction details from OCR text using regex patterns
//

import Foundation

@MainActor
class TransactionExtractionService {

    struct ExtractedLineItem {
        let title: String
        let amount: Double
    }

    struct ExtractedTransaction {
        var amount: Double?
        var merchant: String?
        var date: Date?
        var notes: String?
        var lineItems: [ExtractedLineItem]
        var confidence: ConfidenceLevel

        enum ConfidenceLevel {
            case high, medium, low
        }
    }

    func extractTransaction(from ocrResult: OCRService.OCRResult) -> ExtractedTransaction {
        var extracted = ExtractedTransaction(lineItems: [], confidence: .low)

        // Preprocess text to clean up OCR noise
        let cleanedText = preprocessText(ocrResult.fullText)
        let cleanedLines = ocrResult.lines.map { preprocessText($0) }

        // 1. Extract Amount (total)
        extracted.amount = extractAmount(from: cleanedText, lines: cleanedLines)

        // 2. Extract Merchant
        extracted.merchant = extractMerchant(from: cleanedLines)

        // 3. Extract Date
        extracted.date = extractDate(from: cleanedText)

        // 4. Extract Line Items (NEW!)
        extracted.lineItems = extractLineItems(from: cleanedLines, totalAmount: extracted.amount)

        // 5. Store full OCR text as notes
        extracted.notes = "Imported from screenshot:\n\(ocrResult.fullText)"

        // 6. Calculate confidence
        extracted.confidence = calculateConfidence(extracted, ocrConfidence: ocrResult.confidence)

        return extracted
    }

    // MARK: - Text Preprocessing

    private func preprocessText(_ text: String) -> String {
        var cleaned = text

        // Remove excessive whitespace
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        // Fix common OCR mistakes for currency
        cleaned = cleaned.replacingOccurrences(of: "RIvI", with: "RM") // RM often read as RIvI
        cleaned = cleaned.replacingOccurrences(of: "Rivi", with: "RM")
        cleaned = cleaned.replacingOccurrences(of: "R[M|N1]", with: "RM", options: .regularExpression)

        // Fix comma/period confusion in amounts
        cleaned = cleaned.replacingOccurrences(of: "(\\d),00", with: "$1.00", options: .regularExpression)

        // Remove special characters that might confuse parsing
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned
    }

    // MARK: - Amount Extraction

    private func extractAmount(from text: String, lines: [String]) -> Double? {
        // Priority-based patterns for Malaysian receipts
        // Try to find "Total", "Grand Total", "Amount" first (most reliable)
        let priorityPatterns = [
            "(?:Grand\\s*)?Total:?\\s*RM\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})",    // Total: RM 1,234.56 or Total RM1234.56
            "(?:Grand\\s*)?Total:?\\s*MYR\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})",  // Total: MYR 1,234.56
            "(?:Grand\\s*)?Total:?\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})",         // Total: 1234.56 (without currency)
            "Amount\\s*(?:Paid|Due)?:?\\s*RM\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})", // Amount Paid: RM 50.00
            "Net\\s*Amount:?\\s*RM\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})",         // Net Amount: RM 50.00
        ]

        // Try priority patterns first
        for pattern in priorityPatterns {
            if let amount = findAmount(in: text, pattern: pattern) {
                return amount
            }
        }

        // Fallback: Look for standalone amounts in lines (less reliable)
        let fallbackPatterns = [
            "RM\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})",     // RM 50.00 or RM1,234.56
            "MYR\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})",    // MYR 50.00
            "\\$\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})",    // $ 50.00 (for SGD receipts)
        ]

        // Check last 5 lines first (total usually at bottom)
        let bottomLines = lines.suffix(5).reversed()
        for line in bottomLines {
            for pattern in fallbackPatterns {
                if let amount = findAmount(in: line, pattern: pattern) {
                    return amount
                }
            }
        }

        // Last resort: find any decimal amount (might be wrong)
        if let amount = findAmount(in: text, pattern: "\\b(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})\\b") {
            return amount
        }

        return nil
    }

    private func findAmount(in text: String, pattern: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: nsRange) else {
            return nil
        }

        let range = match.range(at: 1)
        guard range.location != NSNotFound,
              let swiftRange = Range(range, in: text) else {
            return nil
        }

        var amountString = String(text[swiftRange])

        // Remove thousands separators (commas)
        amountString = amountString.replacingOccurrences(of: ",", with: "")

        return Double(amountString)
    }

    // MARK: - Merchant Extraction

    private func extractMerchant(from lines: [String]) -> String? {
        // Enhanced heuristic for Malaysian receipts
        // Merchant name is usually in first 5 lines, avoid numbers/dates/keywords

        var candidateLines: [String] = []

        for (index, line) in lines.prefix(10).enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip empty lines
            guard !trimmed.isEmpty else { continue }

            // Skip lines that are clearly not merchant names
            if shouldSkipLine(trimmed) {
                continue
            }

            // Merchant name is likely near the top and has reasonable length
            if index < 5 && trimmed.count >= 3 && trimmed.count <= 60 {
                candidateLines.append(trimmed)
            }
        }

        // Return the first valid candidate (usually the merchant name)
        // Prefer lines with letters only or mixed alphanumeric
        for candidate in candidateLines {
            if candidate.rangeOfCharacter(from: .letters) != nil {
                return candidate
            }
        }

        return candidateLines.first
    }

    private func shouldSkipLine(_ line: String) -> Bool {
        let lowercased = line.lowercased()

        // Skip lines with currency amounts
        if line.contains("RM") || line.contains("MYR") || line.contains("$") {
            return true
        }

        // Skip lines with common receipt keywords
        let skipKeywords = [
            "total", "amount", "subtotal", "tax", "gst", "sst",
            "receipt", "invoice", "bill", "payment", "paid",
            "balance", "change", "cash", "card", "date", "time",
            "tel:", "phone:", "email:", "fax:", "website:",
            "thank you", "terima kasih", "welcome", "address"
        ]

        for keyword in skipKeywords {
            if lowercased.contains(keyword) {
                return true
            }
        }

        // Skip lines that look like dates (contains /)
        if line.contains("/") || line.contains("-") && line.count < 15 {
            // Check if it's a date pattern
            let datePattern = "\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4}"
            if let _ = line.range(of: datePattern, options: .regularExpression) {
                return true
            }
        }

        // Skip lines that are mostly numbers
        let digitCount = line.filter { $0.isNumber }.count
        if Double(digitCount) / Double(line.count) > 0.6 {
            return true
        }

        return false
    }

    // MARK: - Date Extraction

    private func extractDate(from text: String) -> Date? {
        // Enhanced date patterns for Malaysian receipts
        let datePatterns: [(pattern: String, formats: [String])] = [
            // DD/MM/YYYY or DD-MM-YYYY
            ("\\b(\\d{1,2}[/-]\\d{1,2}[/-]\\d{4})\\b", ["dd/MM/yyyy", "dd-MM-yyyy", "d/M/yyyy", "d-M-yyyy"]),

            // YYYY-MM-DD (ISO format)
            ("\\b(\\d{4}-\\d{2}-\\d{2})\\b", ["yyyy-MM-dd"]),

            // DD MMM YYYY (e.g., 16 Jan 2026)
            ("\\b(\\d{1,2}\\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\\.?\\s+\\d{4})\\b",
             ["dd MMM yyyy", "d MMM yyyy", "dd MMMM yyyy", "d MMMM yyyy"]),

            // MMM DD YYYY (e.g., Jan 16 2026)
            ("\\b((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\\.?\\s+\\d{1,2},?\\s+\\d{4})\\b",
             ["MMM dd yyyy", "MMM d yyyy", "MMMM dd yyyy", "MMMM d yyyy"]),

            // DD.MM.YYYY (European format)
            ("\\b(\\d{1,2}\\.\\d{1,2}\\.\\d{4})\\b", ["dd.MM.yyyy", "d.M.yyyy"]),

            // DD/MM/YY (short year)
            ("\\b(\\d{1,2}[/-]\\d{1,2}[/-]\\d{2})\\b", ["dd/MM/yy", "dd-MM-yy", "d/M/yy", "d-M-yy"]),
        ]

        for (pattern, formats) in datePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {

                let range = match.range(at: 1)
                guard range.location != NSNotFound,
                      let swiftRange = Range(range, in: text) else {
                    continue
                }

                let dateString = String(text[swiftRange])

                // Try all format variations for this pattern
                for format in formats {
                    let formatter = DateFormatter()
                    formatter.dateFormat = format
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    formatter.timeZone = TimeZone.current

                    if let date = formatter.date(from: dateString) {
                        // Validate date is reasonable (not too far in past/future)
                        let now = Date()
                        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: now)!
                        let oneYearFromNow = Calendar.current.date(byAdding: .year, value: 1, to: now)!

                        if date >= oneYearAgo && date <= oneYearFromNow {
                            return date
                        }
                    }
                }
            }
        }

        // Fallback: use current date
        return Date()
    }

    // MARK: - Line Item Extraction

    private func extractLineItems(from lines: [String], totalAmount: Double?) -> [ExtractedLineItem] {
        var lineItems: [ExtractedLineItem] = []

        // Patterns for line items (item name followed by amount)
        // Examples: "Coffee RM 8.00", "Nasi Lemak RM12.00", "Ice Tea 3.50"
        let itemPatterns = [
            "^(.+?)\\s+RM\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})$",      // "Coffee RM 8.00"
            "^(.+?)\\s+MYR\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})$",     // "Coffee MYR 8.00"
            "^(.+?)\\s+(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})$",            // "Coffee 8.00"
        ]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip empty lines
            guard !trimmed.isEmpty else { continue }

            // Skip lines that are clearly not items
            if shouldSkipLineItem(trimmed) {
                continue
            }

            // Try to match item patterns
            for pattern in itemPatterns {
                if let item = extractLineItem(from: trimmed, pattern: pattern) {
                    lineItems.append(item)
                    break // Found a match, no need to try other patterns
                }
            }
        }

        // Validate: If we have line items and a total, check if they sum reasonably
        if !lineItems.isEmpty, let total = totalAmount {
            let sum = lineItems.reduce(0.0) { $0 + $1.amount }
            let difference = abs(sum - total)
            let tolerance = total * 0.15 // 15% tolerance for tax, service charge, discounts

            // If sum doesn't match total (accounting for tax/charges), clear items
            // This prevents false positives from non-itemized receipts
            if difference > tolerance && difference > 5.0 {
                return []
            }
        }

        return lineItems
    }

    private func extractLineItem(from text: String, pattern: String) -> ExtractedLineItem? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: nsRange) else {
            return nil
        }

        // Extract item name (capture group 1)
        let nameRange = match.range(at: 1)
        guard nameRange.location != NSNotFound,
              let nameSwiftRange = Range(nameRange, in: text) else {
            return nil
        }
        let itemName = String(text[nameSwiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)

        // Extract amount (capture group 2)
        let amountRange = match.range(at: 2)
        guard amountRange.location != NSNotFound,
              let amountSwiftRange = Range(amountRange, in: text) else {
            return nil
        }

        var amountString = String(text[amountSwiftRange])
        amountString = amountString.replacingOccurrences(of: ",", with: "")

        guard let amount = Double(amountString), amount > 0 else {
            return nil
        }

        // Skip if item name is too short or too long
        guard itemName.count >= 2 && itemName.count <= 50 else {
            return nil
        }

        return ExtractedLineItem(title: itemName, amount: amount)
    }

    private func shouldSkipLineItem(_ line: String) -> Bool {
        let lowercased = line.lowercased()

        // Skip lines with total/subtotal keywords
        let skipKeywords = [
            "total", "subtotal", "sub-total", "sub total",
            "grand total", "amount", "balance", "change",
            "payment", "paid", "due", "cash", "card",
            "tax", "gst", "sst", "service charge", "discount",
            "receipt", "invoice", "bill", "thank you", "terima kasih",
            "date", "time", "cashier", "server", "table",
            "order", "transaction", "reference", "no:",
            "tel:", "phone:", "email:", "address:", "website:"
        ]

        for keyword in skipKeywords {
            if lowercased.contains(keyword) {
                return true
            }
        }

        // Skip lines that look like dates
        if line.contains("/") || (line.contains("-") && line.count < 15) {
            let datePattern = "\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4}"
            if let _ = line.range(of: datePattern, options: .regularExpression) {
                return true
            }
        }

        // Skip lines with only numbers (like receipt numbers)
        let digitCount = line.filter { $0.isNumber }.count
        if Double(digitCount) / Double(line.count) > 0.7 {
            return true
        }

        return false
    }

    // MARK: - Confidence Calculation

    private func calculateConfidence(_ extracted: ExtractedTransaction, ocrConfidence: Float) -> ExtractedTransaction.ConfidenceLevel {
        var score = 0

        // Amount found: +3 points
        if extracted.amount != nil { score += 3 }

        // Merchant found: +2 points
        if extracted.merchant != nil { score += 2 }

        // Date found: +1 point
        if extracted.date != nil { score += 1 }

        // OCR confidence: +2 if high
        if ocrConfidence > 0.8 { score += 2 }

        // Total possible: 8 points
        // High: 6+, Medium: 4-5, Low: 0-3

        if score >= 6 { return .high }
        if score >= 4 { return .medium }
        return .low
    }
}
