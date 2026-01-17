//
//  ReceiptValidationService.swift
//  OneTap
//
//  Validates extracted receipt data for accuracy and consistency
//  Catches OCR errors and provides confidence adjustments
//

import Foundation

@MainActor
class ReceiptValidationService {

    struct ValidationResult {
        let isValid: Bool
        let issues: [ValidationIssue]
        let adjustedConfidence: Double  // 0.0 to 1.0

        var hasWarnings: Bool {
            !issues.filter { $0.severity == .warning }.isEmpty
        }

        var hasErrors: Bool {
            !issues.filter { $0.severity == .error }.isEmpty
        }
    }

    struct ValidationIssue {
        enum Severity {
            case info
            case warning
            case error
        }

        let severity: Severity
        let message: String
        let field: String?
    }

    // MARK: - Main Validation

    /// Validates an extracted transaction
    func validateExtraction(
        amount: Double?,
        merchant: String?,
        date: Date?,
        lineItems: [TransactionExtractionService.ExtractedLineItem],
        taxAmount: Double?,
        serviceChargeAmount: Double?
    ) -> ValidationResult {
        var issues: [ValidationIssue] = []
        var confidenceAdjustment = 1.0

        // 1. Validate amount
        if let amount = amount {
            let amountIssues = validateAmount(amount)
            issues.append(contentsOf: amountIssues)
        } else {
            issues.append(ValidationIssue(
                severity: .error,
                message: "No amount detected",
                field: "amount"
            ))
            confidenceAdjustment *= 0.5
        }

        // 2. Validate merchant
        let merchantIssues = validateMerchant(merchant)
        issues.append(contentsOf: merchantIssues)
        if merchant == nil || merchant?.isEmpty == true {
            confidenceAdjustment *= 0.8
        }

        // 3. Validate date
        let dateIssues = validateDate(date)
        issues.append(contentsOf: dateIssues)
        if date == nil {
            confidenceAdjustment *= 0.9
        }

        // 4. Validate line items
        if let amount = amount, !lineItems.isEmpty {
            let itemIssues = validateLineItems(lineItems, totalAmount: amount, taxAmount: taxAmount, serviceChargeAmount: serviceChargeAmount)
            issues.append(contentsOf: itemIssues)

            // Adjust confidence based on line item validation
            if itemIssues.contains(where: { $0.severity == .error }) {
                confidenceAdjustment *= 0.7
            } else if itemIssues.contains(where: { $0.severity == .warning }) {
                confidenceAdjustment *= 0.9
            }
        }

        // 5. Cross-field validation
        let crossIssues = validateCrossFields(amount: amount, lineItems: lineItems, taxAmount: taxAmount, serviceChargeAmount: serviceChargeAmount)
        issues.append(contentsOf: crossIssues)

        let isValid = !issues.contains { $0.severity == .error }

        return ValidationResult(
            isValid: isValid,
            issues: issues,
            adjustedConfidence: confidenceAdjustment
        )
    }

    // MARK: - Field Validators

    private func validateAmount(_ amount: Double) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        // Check for unreasonably large amounts
        if amount > 100_000 {
            issues.append(ValidationIssue(
                severity: .warning,
                message: "Amount seems unusually large (RM \(String(format: "%.2f", amount)))",
                field: "amount"
            ))
        }

        // Check for very small amounts (possible OCR error)
        if amount < 0.01 {
            issues.append(ValidationIssue(
                severity: .error,
                message: "Amount is too small (RM \(String(format: "%.2f", amount)))",
                field: "amount"
            ))
        }

        // Check for suspicious decimal patterns (e.g., .99999)
        let decimalPart = amount.truncatingRemainder(dividingBy: 1.0)
        if decimalPart > 0 && decimalPart < 0.01 || decimalPart > 0.99 {
            issues.append(ValidationIssue(
                severity: .info,
                message: "Amount has unusual decimal value",
                field: "amount"
            ))
        }

        return issues
    }

    private func validateMerchant(_ merchant: String?) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        guard let merchant = merchant, !merchant.isEmpty else {
            issues.append(ValidationIssue(
                severity: .warning,
                message: "No merchant name detected",
                field: "merchant"
            ))
            return issues
        }

        // Check for very short merchant names (likely OCR error)
        if merchant.count < 2 {
            issues.append(ValidationIssue(
                severity: .warning,
                message: "Merchant name is very short",
                field: "merchant"
            ))
        }

        // Check for suspicious characters
        let alphanumericCount = merchant.filter { $0.isLetter || $0.isNumber }.count
        if Double(alphanumericCount) / Double(merchant.count) < 0.5 {
            issues.append(ValidationIssue(
                severity: .info,
                message: "Merchant name contains many special characters",
                field: "merchant"
            ))
        }

        return issues
    }

    private func validateDate(_ date: Date?) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        guard let date = date else {
            issues.append(ValidationIssue(
                severity: .info,
                message: "No date detected, using current date",
                field: "date"
            ))
            return issues
        }

        // Check if date is in the future
        if date > Date() {
            issues.append(ValidationIssue(
                severity: .warning,
                message: "Date is in the future",
                field: "date"
            ))
        }

        // Check if date is too old (more than 1 year ago)
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        if date < oneYearAgo {
            issues.append(ValidationIssue(
                severity: .info,
                message: "Date is more than 1 year old",
                field: "date"
            ))
        }

        return issues
    }

    // MARK: - Line Item Validation

    private func validateLineItems(
        _ items: [TransactionExtractionService.ExtractedLineItem],
        totalAmount: Double,
        taxAmount: Double?,
        serviceChargeAmount: Double?
    ) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        // Calculate sum of line items
        let itemsSum = items.reduce(0.0) { $0 + $1.amount }

        // Calculate expected total (items + tax + service charge)
        var expectedTotal = itemsSum
        if let tax = taxAmount {
            expectedTotal += tax
        }
        if let service = serviceChargeAmount {
            expectedTotal += service
        }

        // Check if sum matches total (with tolerance)
        let difference = abs(expectedTotal - totalAmount)
        let tolerance = totalAmount * 0.05  // 5% tolerance

        if difference > tolerance && difference > 1.0 {
            // Significant mismatch
            issues.append(ValidationIssue(
                severity: .error,
                message: "Line items sum (RM \(String(format: "%.2f", expectedTotal))) doesn't match total (RM \(String(format: "%.2f", totalAmount)))",
                field: "lineItems"
            ))
        } else if difference > 0.10 {
            // Small mismatch (rounding or missing items)
            issues.append(ValidationIssue(
                severity: .warning,
                message: "Line items sum differs from total by RM \(String(format: "%.2f", difference))",
                field: "lineItems"
            ))
        }

        // Check for duplicate items
        let itemTitles = items.map { $0.title.lowercased() }
        let uniqueTitles = Set(itemTitles)
        if itemTitles.count != uniqueTitles.count {
            issues.append(ValidationIssue(
                severity: .info,
                message: "Some line items have the same name",
                field: "lineItems"
            ))
        }

        // Check for items with unusually high amounts
        for item in items where !item.isTaxOrCharge {
            if item.amount > totalAmount * 0.8 {
                issues.append(ValidationIssue(
                    severity: .info,
                    message: "\(item.title) accounts for \(Int((item.amount / totalAmount) * 100))% of total",
                    field: "lineItems"
                ))
            }
        }

        return issues
    }

    // MARK: - Cross-Field Validation

    private func validateCrossFields(
        amount: Double?,
        lineItems: [TransactionExtractionService.ExtractedLineItem],
        taxAmount: Double?,
        serviceChargeAmount: Double?
    ) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        // If we have line items but no tax, that might be suspicious for certain amounts
        if !lineItems.isEmpty, taxAmount == nil, let total = amount, total > 20.0 {
            // Many restaurants charge tax above RM 20
            issues.append(ValidationIssue(
                severity: .info,
                message: "No tax detected for itemized receipt",
                field: "tax"
            ))
        }

        // If we have service charge but no line items, that's unusual
        if serviceChargeAmount != nil && lineItems.isEmpty {
            issues.append(ValidationIssue(
                severity: .info,
                message: "Service charge detected without line items",
                field: "serviceCharge"
            ))
        }

        // Check if tax amount seems reasonable (usually 6-10% in Malaysia)
        if let tax = taxAmount, let total = amount {
            let taxPercentage = (tax / total) * 100
            if taxPercentage > 15 {
                issues.append(ValidationIssue(
                    severity: .warning,
                    message: "Tax amount (\(String(format: "%.1f", taxPercentage))%) seems high",
                    field: "tax"
                ))
            }
        }

        // Check if service charge seems reasonable (usually 10%)
        if let service = serviceChargeAmount, let total = amount {
            let servicePercentage = (service / total) * 100
            if servicePercentage > 15 {
                issues.append(ValidationIssue(
                    severity: .warning,
                    message: "Service charge (\(String(format: "%.1f", servicePercentage))%) seems high",
                    field: "serviceCharge"
                ))
            }
        }

        return issues
    }

    // MARK: - Confidence Scoring

    /// Calculates overall confidence score based on validation results
    func calculateConfidenceScore(
        ocrConfidence: Float,
        validationResult: ValidationResult,
        hasLineItems: Bool,
        hasMerchant: Bool,
        hasDate: Bool
    ) -> Double {
        var score = Double(ocrConfidence)

        // Apply validation adjustment
        score *= validationResult.adjustedConfidence

        // Bonus for having complete data
        if hasLineItems { score += 0.05 }
        if hasMerchant { score += 0.05 }
        if hasDate { score += 0.05 }

        // Penalty for validation issues
        if validationResult.hasErrors {
            score *= 0.6
        } else if validationResult.hasWarnings {
            score *= 0.8
        }

        // Clamp to 0.0-1.0
        return min(1.0, max(0.0, score))
    }
}
