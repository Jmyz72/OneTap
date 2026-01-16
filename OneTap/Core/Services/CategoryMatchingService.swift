//
//  CategoryMatchingService.swift
//  OneTap
//
//  Suggests categories based on merchant keywords
//

import Foundation

@MainActor
class CategoryMatchingService {
    private let categoryRepository: CategoryRepository

    init(categoryRepository: CategoryRepository) {
        self.categoryRepository = categoryRepository
    }

    func suggestCategory(forMerchant merchant: String?, notes: String?) -> Category? {
        let categories = categoryRepository.fetchCategories(type: nil)

        guard let merchant = merchant?.lowercased() else {
            return nil
        }

        // Keyword mapping for common merchants/categories
        let keywordMap: [String: String] = [
            // Food & Drink
            "starbucks": "Food & Drink",
            "mcdonald": "Food & Drink",
            "kfc": "Food & Drink",
            "cafe": "Food & Drink",
            "restaurant": "Food & Drink",
            "coffee": "Food & Drink",
            "pizza": "Food & Drink",
            "food": "Food & Drink",

            // Transportation
            "grab": "Transportation",
            "uber": "Transportation",
            "shell": "Transportation",
            "petron": "Transportation",
            "petronas": "Transportation",
            "parking": "Transportation",
            "toll": "Transportation",

            // Shopping
            "shopee": "Shopping",
            "lazada": "Shopping",
            "tesco": "Shopping",
            "aeon": "Shopping",
            "mall": "Shopping",
            "store": "Shopping",

            // Utilities
            "tenaga": "Utilities",
            "water": "Utilities",
            "electric": "Utilities",
            "internet": "Utilities",
            "telekom": "Utilities",

            // Entertainment
            "cinema": "Entertainment",
            "movie": "Entertainment",
            "netflix": "Entertainment",
            "spotify": "Entertainment",
            "game": "Entertainment"
        ]

        // Check if merchant name contains any keywords
        for (keyword, categoryName) in keywordMap {
            if merchant.contains(keyword) {
                // Find matching category
                if let category = categories.first(where: { $0.name?.lowercased() == categoryName.lowercased() }) {
                    return category
                }
            }
        }

        // Fallback: return first expense category
        return categories.first(where: { $0.typeEnum == .expense })
    }
}
