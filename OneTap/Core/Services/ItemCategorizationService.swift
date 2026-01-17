//
//  ItemCategorizationService.swift
//  OneTap
//
//  Smart category suggestion service for line items
//  Uses keyword matching and ML-ready architecture for future enhancement
//

import Foundation

@MainActor
class ItemCategorizationService {
    private let categoryRepository: CategoryRepository

    init(categoryRepository: CategoryRepository) {
        self.categoryRepository = categoryRepository
    }

    // MARK: - Category Suggestion

    /// Suggests the best category for a line item based on its title
    func suggestCategory(forItemTitle title: String) -> Category? {
        let categories = categoryRepository.fetchCategories(type: .expense)
        let lowercased = title.lowercased()

        // Keyword-based matching with scoring
        var categoryScores: [Category: Double] = [:]

        for category in categories {
            let score = calculateCategoryScore(for: lowercased, category: category)
            if score > 0 {
                categoryScores[category] = score
            }
        }

        // Return highest scoring category
        return categoryScores.max(by: { $0.value < $1.value })?.key
    }

    /// Suggests categories for multiple line items
    func suggestCategories(forItems items: [(title: String, amount: Double)]) -> [String: Category] {
        var suggestions: [String: Category] = [:]

        for item in items {
            if let category = suggestCategory(forItemTitle: item.title) {
                suggestions[item.title] = category
            }
        }

        return suggestions
    }

    // MARK: - Scoring Algorithm

    private func calculateCategoryScore(for itemTitle: String, category: Category) -> Double {
        var score = 0.0
        let categoryName = category.name?.lowercased() ?? ""

        // Get keywords for this category
        let keywords = getKeywords(for: categoryName)

        // Check exact matches first (highest score)
        for keyword in keywords {
            if itemTitle == keyword {
                score += 10.0
            } else if itemTitle.contains(keyword) {
                // Partial match
                score += 5.0

                // Bonus for word boundary matches
                if itemTitle.hasPrefix(keyword) || itemTitle.hasSuffix(keyword) {
                    score += 2.0
                }
            }
        }

        return score
    }

    // MARK: - Category Keywords

    private func getKeywords(for categoryName: String) -> [String] {
        // COMPREHENSIVE keyword database for Malaysian receipts
        let keywordMap: [String: [String]] = [
            // Food & Drink
            "food & drink": [
                // Malaysian food
                "nasi", "mee", "kueh", "roti", "satay", "rendang", "laksa", "curry",
                "fried rice", "fried chicken", "chicken rice", "char kuey teow",
                "nasi lemak", "nasi goreng", "mee goreng", "ayam", "ikan", "udang",

                // Beverages
                "coffee", "tea", "kopi", "teh", "drink", "beverage", "water", "juice",
                "latte", "cappuccino", "espresso", "mocha", "smoothie", "milkshake",
                "soda", "cola", "sprite", "ice", "iced",

                // Western food
                "burger", "pizza", "pasta", "sandwich", "fries", "chips", "salad",
                "steak", "chicken", "fish", "soup", "bread", "toast",

                // Desserts
                "cake", "ice cream", "dessert", "pastry", "cookie", "donut", "waffle",

                // General
                "meal", "breakfast", "lunch", "dinner", "set", "combo", "upsize"
            ],

            // Transportation
            "transportation": [
                "grab", "uber", "taxi", "bus", "mrt", "lrt", "train", "komuter",
                "parking", "toll", "petrol", "diesel", "fuel", "gas", "station",
                "rapidkl", "prasarana", "touch n go", "tng",
                "ride", "fare", "trip", "journey"
            ],

            // Shopping
            "shopping": [
                "shirt", "pants", "dress", "shoes", "bag", "wallet", "watch",
                "clothes", "clothing", "apparel", "fashion", "accessories",
                "electronics", "gadget", "phone", "laptop", "tablet",
                "cosmetic", "makeup", "skincare", "perfume", "beauty",
                "book", "magazine", "stationery", "pen", "notebook",
                "home", "furniture", "decor", "kitchen", "bathroom",
                "toy", "game", "gift", "souvenir"
            ],

            // Groceries
            "groceries": [
                "rice", "flour", "sugar", "salt", "oil", "sauce", "spice",
                "vegetable", "fruit", "meat", "seafood", "egg", "milk", "cheese",
                "bread", "cereal", "snack", "instant", "canned", "frozen",
                "detergent", "soap", "shampoo", "tissue", "toilet",
                "fresh", "organic", "produce"
            ],

            // Health & Medical
            "health & medical": [
                "medicine", "drug", "panadol", "vitamin", "supplement", "pharmacy",
                "doctor", "clinic", "hospital", "medical", "health", "wellness",
                "consultation", "treatment", "checkup", "prescription", "ubat",
                "dental", "dentist", "teeth", "eye", "optical", "glasses"
            ],

            // Entertainment
            "entertainment": [
                "movie", "cinema", "film", "ticket", "show", "concert", "event",
                "netflix", "spotify", "youtube", "subscription", "streaming",
                "game", "gaming", "playstation", "xbox", "nintendo", "steam",
                "hobby", "sport", "gym", "fitness", "membership",
                "karaoke", "ktv", "bowling", "arcade"
            ],

            // Utilities
            "utilities": [
                "electric", "electricity", "tenaga", "tnb", "power", "bill",
                "water", "air", "syabas", "sewerage",
                "internet", "wifi", "broadband", "data", "phone", "telco",
                "telekom", "maxis", "digi", "celcom", "unifi", "time",
                "gas", "lpg", "cylinder"
            ],

            // Personal Care
            "personal care": [
                "haircut", "hair", "salon", "barber", "spa", "massage", "facial",
                "manicure", "pedicure", "nail", "grooming", "treatment",
                "shampoo", "conditioner", "body wash", "lotion", "cream"
            ],

            // Education
            "education": [
                "tuition", "course", "class", "lesson", "training", "workshop",
                "school", "college", "university", "book", "textbook", "notes",
                "exam", "test", "certification", "learning", "study"
            ],

            // Housing
            "housing": [
                "rent", "rental", "mortgage", "loan", "instalment", "payment",
                "maintenance", "repair", "service", "plumber", "electrician",
                "furniture", "appliance", "renovation", "cleaning"
            ]
        ]

        // Find matching keywords
        for (key, keywords) in keywordMap {
            if categoryName.contains(key) {
                return keywords
            }
        }

        // Fallback: use category name itself
        return [categoryName]
    }

    // MARK: - Smart Item Detection

    /// Detects if an item is likely a tax or service charge
    func isTaxOrServiceCharge(_ title: String) -> (isTax: Bool, type: TaxType?) {
        let lowercased = title.lowercased()

        // Tax patterns
        let taxKeywords = ["tax", "gst", "sst", "vat", "cukai"]
        for keyword in taxKeywords {
            if lowercased.contains(keyword) {
                return (true, .tax)
            }
        }

        // Service charge patterns
        let serviceKeywords = ["service charge", "svc charge", "service chg", "svc chg", "service"]
        for keyword in serviceKeywords {
            if lowercased.contains(keyword) {
                return (true, .serviceCharge)
            }
        }

        // Rounding adjustment
        if lowercased.contains("rounding") || lowercased.contains("round") {
            return (true, .rounding)
        }

        // Discount (negative tax)
        if lowercased.contains("discount") || lowercased.contains("disc") || lowercased.contains("promo") {
            return (true, .discount)
        }

        return (false, nil)
    }

    enum TaxType: String {
        case tax = "Tax"
        case serviceCharge = "Service Charge"
        case rounding = "Rounding"
        case discount = "Discount"
    }

    // MARK: - Quantity Detection

    /// Detects quantity from item title (e.g., "Coffee 2x", "2 × Burger")
    func extractQuantity(from title: String) -> (cleanedTitle: String, quantity: Int) {
        let patterns = [
            // "Coffee 2x" or "Coffee 2X"
            "(.+?)\\s*(\\d+)\\s*[xX]\\s*$",
            // "2x Coffee" or "2X Coffee"
            "^\\s*(\\d+)\\s*[xX]\\s*(.+)",
            // "Coffee × 2" or "Coffee x 2"
            "(.+?)\\s*[×xX]\\s*(\\d+)\\s*$",
            // "2 × Coffee" or "2 x Coffee"
            "^\\s*(\\d+)\\s*[×xX]\\s*(.+)",
            // "(2) Coffee" or "Coffee (2)"
            "(.+?)\\s*\\((\\d+)\\)",
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)) {

                // Extract item name and quantity
                var itemName = ""
                var quantity = 1

                // Pattern has 2 capture groups - order varies
                if match.numberOfRanges == 3 {
                    let range1 = match.range(at: 1)
                    let range2 = match.range(at: 2)

                    if range1.location != NSNotFound,
                       let swiftRange1 = Range(range1, in: title),
                       range2.location != NSNotFound,
                       let swiftRange2 = Range(range2, in: title) {

                        let group1 = String(title[swiftRange1]).trimmingCharacters(in: .whitespaces)
                        let group2 = String(title[swiftRange2]).trimmingCharacters(in: .whitespaces)

                        // Determine which is quantity
                        if let qty = Int(group1) {
                            quantity = qty
                            itemName = group2
                        } else if let qty = Int(group2) {
                            quantity = qty
                            itemName = group1
                        }

                        if !itemName.isEmpty && quantity > 0 {
                            return (cleanedTitle: itemName, quantity: quantity)
                        }
                    }
                }
            }
        }

        // No quantity found, return original title with quantity 1
        return (cleanedTitle: title, quantity: 1)
    }
}
