//
//  ReceiptFormatDetectionService.swift
//  OneTap
//
//  Detects receipt formats from common Malaysian retailers
//  Enables format-specific parsing rules for better accuracy
//

import Foundation

@MainActor
class ReceiptFormatDetectionService {

    enum ReceiptFormat {
        case sevenEleven
        case familyMart
        case tesco
        case aeon
        case mydin
        case jaya
        case mrDiy
        case watsons
        case guardian
        case starbucks
        case mcdonald
        case kfc
        case grabFood
        case foodPanda
        case touchNGo
        case boost
        case grabPay
        case shopeePay
        case maybank
        case cimb
        case publicBank
        case rhb
        case generic

        var name: String {
            switch self {
            case .sevenEleven: return "7-Eleven"
            case .familyMart: return "FamilyMart"
            case .tesco: return "Tesco"
            case .aeon: return "AEON"
            case .mydin: return "MYDIN"
            case .jaya: return "Jaya Grocer"
            case .mrDiy: return "MR.DIY"
            case .watsons: return "Watsons"
            case .guardian: return "Guardian"
            case .starbucks: return "Starbucks"
            case .mcdonald: return "McDonald's"
            case .kfc: return "KFC"
            case .grabFood: return "GrabFood"
            case .foodPanda: return "foodpanda"
            case .touchNGo: return "Touch 'n Go"
            case .boost: return "Boost"
            case .grabPay: return "GrabPay"
            case .shopeePay: return "ShopeePay"
            case .maybank: return "Maybank"
            case .cimb: return "CIMB"
            case .publicBank: return "Public Bank"
            case .rhb: return "RHB"
            case .generic: return "Generic Receipt"
            }
        }

        var hasLineItems: Bool {
            // Which formats typically have itemized receipts
            switch self {
            case .sevenEleven, .familyMart, .tesco, .aeon, .mydin, .jaya,
                 .mrDiy, .watsons, .guardian, .starbucks, .mcdonald, .kfc:
                return true
            case .grabFood, .foodPanda:
                return true
            default:
                return false
            }
        }

        var taxPattern: String? {
            // Format-specific tax patterns
            switch self {
            case .sevenEleven, .familyMart:
                return "(?:SST|TAX)\\s*:\\s*RM\\s*(\\d+\\.\\d{2})"
            case .starbucks:
                return "Service\\s*Tax\\s*RM\\s*(\\d+\\.\\d{2})"
            case .mcdonald, .kfc:
                return "(?:GST|TAX)\\s*RM\\s*(\\d+\\.\\d{2})"
            default:
                return nil
            }
        }
    }

    // MARK: - Format Detection

    func detectFormat(from text: String, lines: [String]) -> ReceiptFormat {
        let fullText = text.lowercased()
        let topLines = lines.prefix(10).joined(separator: " ").lowercased()

        // Convenience stores
        if topLines.contains("7-eleven") || topLines.contains("7eleven") {
            return .sevenEleven
        }
        if topLines.contains("familymart") || topLines.contains("family mart") {
            return .familyMart
        }

        // Supermarkets
        if topLines.contains("tesco") {
            return .tesco
        }
        if topLines.contains("aeon") {
            return .aeon
        }
        if topLines.contains("mydin") {
            return .mydin
        }
        if topLines.contains("jaya grocer") || topLines.contains("jaya") {
            return .jaya
        }

        // Retail
        if topLines.contains("mr.diy") || topLines.contains("mr diy") || topLines.contains("mrdiy") {
            return .mrDiy
        }
        if topLines.contains("watsons") {
            return .watsons
        }
        if topLines.contains("guardian") {
            return .guardian
        }

        // F&B
        if topLines.contains("starbucks") {
            return .starbucks
        }
        if topLines.contains("mcdonald") || topLines.contains("mcd") {
            return .mcdonald
        }
        if topLines.contains("kfc") || topLines.contains("kentucky") {
            return .kfc
        }

        // Food delivery
        if fullText.contains("grabfood") || fullText.contains("grab food") {
            return .grabFood
        }
        if fullText.contains("foodpanda") || fullText.contains("food panda") {
            return .foodPanda
        }

        // E-wallets
        if fullText.contains("touch 'n go") || fullText.contains("touch n go") || fullText.contains("tng") {
            return .touchNGo
        }
        if fullText.contains("boost") && (fullText.contains("payment") || fullText.contains("paid")) {
            return .boost
        }
        if fullText.contains("grabpay") || fullText.contains("grab pay") {
            return .grabPay
        }
        if fullText.contains("shopeepay") || fullText.contains("shopee pay") {
            return .shopeePay
        }

        // Banks
        if topLines.contains("maybank") {
            return .maybank
        }
        if topLines.contains("cimb") {
            return .cimb
        }
        if topLines.contains("public bank") || topLines.contains("pbb") {
            return .publicBank
        }
        if topLines.contains("rhb") {
            return .rhb
        }

        return .generic
    }

    // MARK: - Format-Specific Parsing Rules

    struct FormatParsingRules {
        let datePattern: String?
        let amountPattern: String?
        let lineItemPattern: String?
        let merchantLineIndex: Int?
        let skipLines: [String]

        static let `default` = FormatParsingRules(
            datePattern: nil,
            amountPattern: nil,
            lineItemPattern: nil,
            merchantLineIndex: nil,
            skipLines: []
        )
    }

    func getParsingRules(for format: ReceiptFormat) -> FormatParsingRules {
        switch format {
        case .sevenEleven:
            return FormatParsingRules(
                datePattern: "\\d{2}/\\d{2}/\\d{4}\\s+\\d{2}:\\d{2}",
                amountPattern: "TOTAL\\s+RM\\s*(\\d+\\.\\d{2})",
                lineItemPattern: "^(.+?)\\s+(\\d+\\.\\d{2})$",
                merchantLineIndex: 0,
                skipLines: ["GST ID", "RECEIPT"]
            )

        case .starbucks:
            return FormatParsingRules(
                datePattern: "\\d{2}-\\d{2}-\\d{4}",
                amountPattern: "TOTAL\\s+RM\\s*(\\d+\\.\\d{2})",
                lineItemPattern: "^(.+?)\\s+RM\\s+(\\d+\\.\\d{2})$",
                merchantLineIndex: 0,
                skipLines: ["TAX INVOICE", "STORE"]
            )

        case .grabFood, .foodPanda:
            return FormatParsingRules(
                datePattern: "\\d{1,2}\\s+[A-Za-z]{3}\\s+\\d{4}",
                amountPattern: "(?:Total|Amount):\\s*RM\\s*(\\d+\\.\\d{2})",
                lineItemPattern: "^(.+?)\\s+RM\\s*(\\d+\\.\\d{2})$",
                merchantLineIndex: nil,
                skipLines: ["Delivery Fee", "Platform Fee", "Small Order Fee"]
            )

        case .touchNGo, .boost, .grabPay, .shopeePay:
            return FormatParsingRules(
                datePattern: "\\d{2}/\\d{2}/\\d{4}",
                amountPattern: "(?:Amount|Paid|Payment):\\s*RM\\s*(\\d+\\.\\d{2})",
                lineItemPattern: nil,  // E-wallets typically don't have line items
                merchantLineIndex: nil,
                skipLines: ["Transaction ID", "Reference", "Receipt"]
            )

        default:
            return .default
        }
    }

    // MARK: - Helper Methods

    /// Returns expected category based on receipt format
    func getDefaultCategory(for format: ReceiptFormat) -> String? {
        switch format {
        case .sevenEleven, .familyMart:
            return "Food & Drink"  // Convenience stores

        case .tesco, .aeon, .mydin, .jaya:
            return "Groceries"  // Supermarkets

        case .mrDiy:
            return "Shopping"  // Home improvement

        case .watsons, .guardian:
            return "Personal Care"  // Health & beauty

        case .starbucks:
            return "Food & Drink"  // Coffee

        case .mcdonald, .kfc:
            return "Food & Drink"  // Fast food

        case .grabFood, .foodPanda:
            return "Food & Drink"  // Food delivery

        case .touchNGo, .boost, .grabPay, .shopeePay:
            return nil  // E-wallets - category depends on merchant

        case .maybank, .cimb, .publicBank, .rhb:
            return nil  // Bank transfers - category varies

        case .generic:
            return nil
        }
    }

    /// Returns whether this format typically includes service tax
    func includesServiceTax(format: ReceiptFormat) -> Bool {
        switch format {
        case .starbucks, .mcdonald, .kfc, .grabFood, .foodPanda:
            return true
        default:
            return false
        }
    }

    /// Returns whether this format uses SST (Sales and Service Tax)
    func includesSST(format: ReceiptFormat) -> Bool {
        switch format {
        case .sevenEleven, .familyMart, .tesco, .aeon, .mydin:
            return true
        default:
            return false
        }
    }
}
