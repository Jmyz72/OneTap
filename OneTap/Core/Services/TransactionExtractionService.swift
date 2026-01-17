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
        let quantity: Int  // ENHANCED: Track quantity
        let unitPrice: Double  // ENHANCED: Unit price (amount / quantity)
        let isTaxOrCharge: Bool  // ENHANCED: Flag for tax/service charge
        let suggestedCategory: String?  // ENHANCED: AI-suggested category

        // Legacy initializer for backward compatibility
        init(title: String, amount: Double) {
            self.title = title
            self.amount = amount
            self.quantity = 1
            self.unitPrice = amount
            self.isTaxOrCharge = false
            self.suggestedCategory = nil
        }

        // ENHANCED: Full initializer
        init(title: String, amount: Double, quantity: Int, unitPrice: Double, isTaxOrCharge: Bool, suggestedCategory: String?) {
            self.title = title
            self.amount = amount
            self.quantity = quantity
            self.unitPrice = unitPrice
            self.isTaxOrCharge = isTaxOrCharge
            self.suggestedCategory = suggestedCategory
        }
    }

    struct ExtractedTransaction {
        var amount: Double?
        var merchant: String?
        var date: Date?
        var notes: String?
        var lineItems: [ExtractedLineItem]
        var taxAmount: Double?  // ENHANCED: Separate tax tracking
        var serviceChargeAmount: Double?  // ENHANCED: Separate service charge
        var receiptFormat: ReceiptFormatDetectionService.ReceiptFormat?  // ENHANCED: Detected format
        var confidence: ConfidenceLevel

        enum ConfidenceLevel {
            case high, medium, low
        }
    }

    // ENHANCED: Inject smart services
    private let itemCategorizationService: ItemCategorizationService?
    private let receiptFormatDetectionService: ReceiptFormatDetectionService?
    private let fuzzyMatchingService: FuzzyMatchingService?  // PHASE 3
    private let validationService: ReceiptValidationService?  // PHASE 3
    private let learningService: OCRLearningService?  // PHASE 3

    init(itemCategorizationService: ItemCategorizationService? = nil,
         receiptFormatDetectionService: ReceiptFormatDetectionService? = nil,
         fuzzyMatchingService: FuzzyMatchingService? = nil,
         validationService: ReceiptValidationService? = nil,
         learningService: OCRLearningService? = nil) {
        self.itemCategorizationService = itemCategorizationService
        self.receiptFormatDetectionService = receiptFormatDetectionService
        self.fuzzyMatchingService = fuzzyMatchingService
        self.validationService = validationService
        self.learningService = learningService
    }

    func extractTransaction(from ocrResult: OCRService.OCRResult) -> ExtractedTransaction {
        var extracted = ExtractedTransaction(lineItems: [], confidence: .low)

        // PHASE 3: Check for QR code data first (most reliable)
        if let qrCodes = ocrResult.qrCodeData, !qrCodes.isEmpty {
            // Try to extract payment info from QR codes (DuitNow, etc.)
            for qrCode in qrCodes where qrCode.type == .duitNow {
                // QR code payment data is most reliable
                // Note: extractDuitNowPaymentInfo would need to be called from OCRService
                // For now, we'll note that QR data is available in the notes
                extracted.notes = "QR payment detected"
            }
        }

        // Preprocess text to clean up OCR noise
        let cleanedText = preprocessText(ocrResult.fullText)
        let cleanedLines = ocrResult.lines.map { preprocessText($0) }

        // ENHANCED: Detect receipt format first
        if let formatService = receiptFormatDetectionService {
            extracted.receiptFormat = formatService.detectFormat(from: cleanedText, lines: cleanedLines)
        }

        // 1. Extract Amount (total)
        extracted.amount = extractAmount(from: cleanedText, lines: cleanedLines)

        // 2. Extract Merchant (with fuzzy matching and learning)
        extracted.merchant = extractMerchant(from: cleanedLines)

        // PHASE 3: Apply fuzzy matching to merchant name
        if let merchant = extracted.merchant, let fuzzyService = fuzzyMatchingService {
            // Check learned patterns first
            if let suggestedMerchant = learningService?.getSuggestedMerchant(for: merchant) {
                extracted.merchant = suggestedMerchant
            } else {
                // Try fuzzy matching against known merchants
                let knownMerchants = learningService?.getAllMerchantPatterns().map { $0.correctedName } ?? []
                if let match = fuzzyService.findBestMerchantMatch(for: merchant, in: knownMerchants) {
                    if match.confidence > 0.8 {
                        extracted.merchant = match.match
                    }
                }
            }
        }

        // 3. Extract Date
        extracted.date = extractDate(from: cleanedText)

        // ENHANCED: 4. Extract Tax and Service Charges
        let (tax, serviceCharge) = extractTaxAndServiceCharge(from: cleanedLines, format: extracted.receiptFormat)
        extracted.taxAmount = tax
        extracted.serviceChargeAmount = serviceCharge

        // ENHANCED: 5. Extract Line Items with smart categorization
        extracted.lineItems = extractLineItems(
            from: cleanedLines,
            totalAmount: extracted.amount,
            format: extracted.receiptFormat
        )

        // 6. Store full OCR text as notes
        var notesText = "Imported from screenshot"
        if let format = extracted.receiptFormat {
            notesText += " (\(format.name))"
        }
        notesText += ":\n\(ocrResult.fullText)"
        extracted.notes = notesText

        // 7. Calculate confidence
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
        // ENHANCED: Priority-based patterns for Malaysian receipts & e-wallets
        // Try to find "Total", "Grand Total", "Amount" first (most reliable)
        let priorityPatterns = [
            // E-wallet specific patterns (Touch 'n Go, GrabPay, Boost, ShopeePay)
            "(?:Payment\\s*)?Amount:?\\s*RM\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})",  // Payment Amount: RM 50.00
            "(?:Total\\s*)?Paid:?\\s*RM\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})",      // Total Paid: RM 50.00
            "You\\s*(?:Paid|paid):?\\s*RM\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})",    // You paid: RM 50.00
            "Transfer\\s*Amount:?\\s*RM\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})",      // Transfer Amount: RM 50.00

            // DuitNow / QR Payment patterns
            "(?:DuitNow\\s*)?(?:Transfer|Payment):?\\s*RM\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})", // DuitNow Transfer: RM 50.00

            // Traditional receipt patterns
            "(?:Grand\\s*)?Total:?\\s*RM\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})",     // Total: RM 1,234.56
            "(?:Grand\\s*)?Total:?\\s*MYR\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})",    // Total: MYR 1,234.56
            "(?:Grand\\s*)?Total:?\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})",           // Total: 1234.56
            "(?:Net\\s*)?Amount\\s*(?:Paid|Due)?:?\\s*RM\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})", // Amount Paid: RM 50.00

            // Credit card statement patterns
            "Transaction\\s*Amount:?\\s*RM\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})",   // Transaction Amount: RM 50.00
            "Debit:?\\s*RM\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})",                   // Debit: RM 50.00

            // Bank transfer patterns
            "Amount\\s*Transferred:?\\s*RM\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})",   // Amount Transferred: RM 50.00
        ]

        // Try priority patterns first
        for pattern in priorityPatterns {
            if let amount = findAmount(in: text, pattern: pattern) {
                return amount
            }
        }

        // ENHANCED: Fallback patterns with multi-currency support
        let fallbackPatterns = [
            "RM\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})",     // RM 50.00 or RM1,234.56
            "MYR\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})",    // MYR 50.00
            "\\$\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})",    // $ 50.00 (SGD)
            "S\\$\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})",   // S$ 50.00 (SGD explicit)
            "SGD\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})",    // SGD 50.00
            "฿\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})",      // ฿ 50.00 (THB)
            "THB\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})",    // THB 50.00
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
        // ENHANCED: Multi-strategy merchant extraction for Malaysian receipts & e-wallets

        // Strategy 1: E-wallet merchant patterns (most reliable for QR payments)
        if let ewalletMerchant = extractEwalletMerchant(from: lines) {
            return ewalletMerchant
        }

        // Strategy 2: Bank transfer merchant patterns
        if let bankMerchant = extractBankMerchant(from: lines) {
            return bankMerchant
        }

        // Strategy 3: Traditional receipt heuristic
        return extractTraditionalMerchant(from: lines)
    }

    /// Extracts merchant from e-wallet receipts (Touch 'n Go, GrabPay, Boost, ShopeePay)
    private func extractEwalletMerchant(from lines: [String]) -> String? {
        let merchantPatterns = [
            "(?:Paid\\s*to|To):?\\s*(.+)",              // "Paid to: ABC Store"
            "(?:Merchant|Shop):?\\s*(.+)",              // "Merchant: ABC Store"
            "(?:Recipient|Receiver):?\\s*(.+)",         // "Recipient: ABC Store"
            "(?:Pay|Payment)\\s*to:?\\s*(.+)",          // "Payment to: ABC Store"
        ]

        for line in lines.prefix(15) {  // Check first 15 lines
            for pattern in merchantPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {

                    let range = match.range(at: 1)
                    guard range.location != NSNotFound,
                          let swiftRange = Range(range, in: line) else {
                        continue
                    }

                    var merchant = String(line[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)

                    // Clean up merchant name
                    merchant = cleanMerchantName(merchant)

                    if !merchant.isEmpty && merchant.count >= 2 && merchant.count <= 80 {
                        return merchant
                    }
                }
            }
        }

        return nil
    }

    /// Extracts merchant from bank transfer/statement screenshots
    private func extractBankMerchant(from lines: [String]) -> String? {
        let merchantPatterns = [
            "(?:Transfer\\s*to|Transferred\\s*to):?\\s*(.+)",  // "Transfer to: ABC Store"
            "(?:Payee|Beneficiary):?\\s*(.+)",                 // "Payee: ABC Store"
            "(?:Account\\s*Name):?\\s*(.+)",                   // "Account Name: ABC Store"
        ]

        for line in lines {
            for pattern in merchantPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {

                    let range = match.range(at: 1)
                    guard range.location != NSNotFound,
                          let swiftRange = Range(range, in: line) else {
                        continue
                    }

                    var merchant = String(line[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    merchant = cleanMerchantName(merchant)

                    if !merchant.isEmpty && merchant.count >= 2 && merchant.count <= 80 {
                        return merchant
                    }
                }
            }
        }

        return nil
    }

    /// Traditional heuristic-based merchant extraction
    private func extractTraditionalMerchant(from lines: [String]) -> String? {
        var candidateLines: [String] = []
        var candidateScores: [Double] = []

        for (index, line) in lines.prefix(10).enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip empty lines
            guard !trimmed.isEmpty else { continue }

            // Skip lines that are clearly not merchant names
            if shouldSkipMerchantLine(trimmed) {
                continue
            }

            // Merchant name is likely near the top and has reasonable length
            if index < 5 && trimmed.count >= 3 && trimmed.count <= 80 {
                // Score candidates based on heuristics
                var score = 0.0

                // Higher score for lines near the top
                score += Double(5 - index) * 2.0

                // Prefer lines with more letters
                let letterCount = trimmed.filter { $0.isLetter }.count
                score += Double(letterCount) * 0.5

                // Penalize lines with numbers
                let digitCount = trimmed.filter { $0.isNumber }.count
                score -= Double(digitCount) * 1.0

                // Prefer title case (e.g., "Starbucks Coffee")
                if trimmed.first?.isUppercase == true {
                    score += 2.0
                }

                // Penalize very long names
                if trimmed.count > 40 {
                    score -= Double(trimmed.count - 40) * 0.2
                }

                candidateLines.append(trimmed)
                candidateScores.append(score)
            }
        }

        // Return highest scoring candidate
        if let maxIndex = candidateScores.indices.max(by: { candidateScores[$0] < candidateScores[$1] }),
           candidateScores[maxIndex] > 0 {
            return candidateLines[maxIndex]
        }

        return nil
    }

    /// Cleans merchant name by removing common noise
    private func cleanMerchantName(_ name: String) -> String {
        var cleaned = name

        // Remove trailing reference numbers (e.g., "ABC Store #1234")
        cleaned = cleaned.replacingOccurrences(of: "\\s*[#@]\\s*\\d+.*$", with: "", options: .regularExpression)

        // Remove "(", ")", "[", "]" and content within
        cleaned = cleaned.replacingOccurrences(of: "\\s*[\\(\\[].*?[\\)\\]]", with: "", options: .regularExpression)

        // Remove trailing dots/commas
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))

        // Clean up whitespace
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func shouldSkipMerchantLine(_ line: String) -> Bool {
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
        // ENHANCED: Comprehensive date patterns for Malaysian receipts & e-wallets
        let datePatterns: [(pattern: String, formats: [String])] = [
            // DD/MM/YYYY or DD-MM-YYYY (Most common in Malaysia)
            ("\\b(\\d{1,2}[/-]\\d{1,2}[/-]\\d{4})\\b", ["dd/MM/yyyy", "dd-MM-yyyy", "d/M/yyyy", "d-M-yyyy"]),

            // YYYY-MM-DD (ISO format, common in bank statements)
            ("\\b(\\d{4}-\\d{2}-\\d{2})\\b", ["yyyy-MM-dd"]),

            // DD MMM YYYY (e.g., 16 Jan 2026, 16 January 2026)
            ("\\b(\\d{1,2}\\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\\.?\\s+\\d{4})\\b",
             ["dd MMM yyyy", "d MMM yyyy", "dd MMMM yyyy", "d MMMM yyyy"]),

            // MMM DD YYYY (e.g., Jan 16 2026, January 16, 2026)
            ("\\b((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\\.?\\s+\\d{1,2},?\\s+\\d{4})\\b",
             ["MMM dd yyyy", "MMM d yyyy", "MMMM dd yyyy", "MMMM d yyyy", "MMM dd, yyyy", "MMMM dd, yyyy"]),

            // DD.MM.YYYY (European format)
            ("\\b(\\d{1,2}\\.\\d{1,2}\\.\\d{4})\\b", ["dd.MM.yyyy", "d.M.yyyy"]),

            // DD/MM/YY (short year)
            ("\\b(\\d{1,2}[/-]\\d{1,2}[/-]\\d{2})\\b", ["dd/MM/yy", "dd-MM-yy", "d/M/yy", "d-M-yy"]),

            // YYYY/MM/DD (alternative ISO)
            ("\\b(\\d{4}[/-]\\d{1,2}[/-]\\d{1,2})\\b", ["yyyy/MM/dd", "yyyy-MM-dd", "yyyy/M/d", "yyyy-M-d"]),

            // DD MMM YY (e.g., 16 Jan 26)
            ("\\b(\\d{1,2}\\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\\.?\\s+\\d{2})\\b",
             ["dd MMM yy", "d MMM yy", "dd MMMM yy", "d MMMM yy"]),
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

    // MARK: - Tax and Service Charge Extraction

    /// ENHANCED: Extracts tax and service charge amounts separately
    private func extractTaxAndServiceCharge(
        from lines: [String],
        format: ReceiptFormatDetectionService.ReceiptFormat?
    ) -> (tax: Double?, serviceCharge: Double?) {
        var taxAmount: Double? = nil
        var serviceChargeAmount: Double? = nil

        // Tax patterns
        let taxPatterns = [
            "(?:SST|GST|VAT|TAX)\\s*:?\\s*RM\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})",
            "Tax\\s*Amount\\s*:?\\s*RM\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})",
            "Sales\\s*Tax\\s*:?\\s*RM\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})",
        ]

        // Service charge patterns
        let serviceChargePatterns = [
            "Service\\s*Charge\\s*:?\\s*RM\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})",
            "Svc\\s*Charge\\s*:?\\s*RM\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})",
            "Service\\s*:?\\s*RM\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})",
        ]

        // Extract tax
        for line in lines {
            for pattern in taxPatterns {
                if let amount = findAmount(in: line, pattern: pattern) {
                    taxAmount = amount
                    break
                }
            }
            if taxAmount != nil { break }
        }

        // Extract service charge
        for line in lines {
            for pattern in serviceChargePatterns {
                if let amount = findAmount(in: line, pattern: pattern) {
                    serviceChargeAmount = amount
                    break
                }
            }
            if serviceChargeAmount != nil { break }
        }

        return (taxAmount, serviceChargeAmount)
    }

    // MARK: - Line Item Extraction

    /// ENHANCED: Extracts line items with quantity detection and smart categorization
    private func extractLineItems(
        from lines: [String],
        totalAmount: Double?,
        format: ReceiptFormatDetectionService.ReceiptFormat?
    ) -> [ExtractedLineItem] {
        var lineItems: [ExtractedLineItem] = []

        // ENHANCED: Patterns for line items with better coverage
        let itemPatterns = [
            "^(.+?)\\s+RM\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})$",      // "Coffee RM 8.00"
            "^(.+?)\\s+MYR\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})$",     // "Coffee MYR 8.00"
            "^(.+?)\\s+(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})$",            // "Coffee 8.00"
            "^(.+?)\\s+@\\s*RM\\s*(\\d{1,}(?:[,\\.]\\d{3})*\\.\\d{2})$", // "Coffee @ RM 8.00"
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

    /// ENHANCED: Extracts line item with quantity detection and smart categorization
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
        var itemName = String(text[nameSwiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)

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

        // ENHANCED: Detect quantity from item name
        var quantity = 1
        var unitPrice = amount
        if let categorizationService = itemCategorizationService {
            let (cleanedTitle, detectedQuantity) = categorizationService.extractQuantity(from: itemName)
            itemName = cleanedTitle
            quantity = detectedQuantity
            unitPrice = amount / Double(quantity)
        }

        // ENHANCED: Check if this is a tax or service charge
        var isTaxOrCharge = false
        if let categorizationService = itemCategorizationService {
            let (isTax, _) = categorizationService.isTaxOrServiceCharge(itemName)
            isTaxOrCharge = isTax
        }

        // Skip if item name is too short or too long
        guard itemName.count >= 2 && itemName.count <= 80 else {
            return nil
        }

        // ENHANCED: Suggest category for this item
        var suggestedCategory: String? = nil
        if let categorizationService = itemCategorizationService, !isTaxOrCharge {
            suggestedCategory = categorizationService.suggestCategory(forItemTitle: itemName)?.name
        }

        return ExtractedLineItem(
            title: itemName,
            amount: amount,
            quantity: quantity,
            unitPrice: unitPrice,
            isTaxOrCharge: isTaxOrCharge,
            suggestedCategory: suggestedCategory
        )
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
