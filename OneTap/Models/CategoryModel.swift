//
//  CategoryModel.swift
//  OneTap
//

import Foundation
import SwiftUI
internal import CoreData

extension Category {
    var colorView: Color {
        Color(hex: color ?? "#808080")
    }
    
    var iconName: String {
        icon ?? "questionmark.circle.fill"
    }
    
    var typeEnum: TransactionType {
        get {
            guard let typeString = type, let value = TransactionType(rawValue: typeString) else {
                return .expense
            }
            return value
        }
        set {
            type = newValue.rawValue
        }
    }
}

// Extension to handle Hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHex() -> String? {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        var a = Float(1.0)

        if components.count >= 4 {
            a = Float(components[3])
        }

        if a != Float(1.0) {
            return String(format: "%02lX%02lX%02lX%02lX", lroundf(a * 255), lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        } else {
            return String(format: "%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        }
    }
}

struct DefaultCategory {
    let name: String
    let icon: String
    let color: String
    let type: TransactionType
    let subcategories: [DefaultSubCategory]
    
    init(name: String, icon: String, color: String, type: TransactionType, subcategories: [DefaultSubCategory] = []) {
        self.name = name
        self.icon = icon
        self.color = color
        self.type = type
        self.subcategories = subcategories
    }
}

struct DefaultSubCategory {
    let name: String
    let icon: String
}

extension Category {
    static let defaults: [DefaultCategory] = [
        // MARK: - EXPENSES
        
        // 1. Food & Drinks
        DefaultCategory(name: "Food & Drinks", icon: "fork.knife", color: "#FF9500", type: .expense, subcategories: [
            DefaultSubCategory(name: "Groceries", icon: "cart.fill"),
            DefaultSubCategory(name: "Restaurants", icon: "fork.knife"),
            DefaultSubCategory(name: "Fast Food", icon: "takeoutbag.and.cup.and.straw.fill"),
            DefaultSubCategory(name: "Coffee & Tea", icon: "cup.and.saucer.fill"),
            DefaultSubCategory(name: "Alcohol", icon: "wineglass.fill"),
            DefaultSubCategory(name: "Snacks", icon: "birthday.cake.fill")
        ]),
        
        // 2. Transport
        DefaultCategory(name: "Transport", icon: "car.fill", color: "#5856D6", type: .expense, subcategories: [
            DefaultSubCategory(name: "Fuel", icon: "fuelpump.fill"),
            DefaultSubCategory(name: "Public Transport", icon: "bus.fill"),
            DefaultSubCategory(name: "Ride Hailing", icon: "car.circle.fill"),
            DefaultSubCategory(name: "Parking", icon: "parkingsign.circle.fill"),
            DefaultSubCategory(name: "Maintenance", icon: "wrench.and.screwdriver.fill"),
            DefaultSubCategory(name: "Tolls", icon: "dollarsign.circle.fill")
        ]),
        
        // 3. Shopping
        DefaultCategory(name: "Shopping", icon: "bag.fill", color: "#FF2D55", type: .expense, subcategories: [
            DefaultSubCategory(name: "Clothes", icon: "tshirt.fill"),
            DefaultSubCategory(name: "Electronics", icon: "desktopcomputer"),
            DefaultSubCategory(name: "Home Decor", icon: "sofa.fill"),
            DefaultSubCategory(name: "Beauty & Personal", icon: "mustache.fill"), // Using mustache as placeholder for personal care if no specific beauty icon
            DefaultSubCategory(name: "Hobbies", icon: "paintpalette.fill")
        ]),
        
        // 4. Housing
        DefaultCategory(name: "Housing", icon: "house.fill", color: "#8E8E93", type: .expense, subcategories: [
            DefaultSubCategory(name: "Rent", icon: "house.circle.fill"),
            DefaultSubCategory(name: "Mortgage", icon: "banknote.fill"),
            DefaultSubCategory(name: "Home Insurance", icon: "shield.fill"),
            DefaultSubCategory(name: "Repairs", icon: "hammer.fill")
        ]),
        
        // 5. Utilities
        DefaultCategory(name: "Utilities", icon: "bolt.fill", color: "#FFCC00", type: .expense, subcategories: [
            DefaultSubCategory(name: "Electricity", icon: "bolt.circle.fill"),
            DefaultSubCategory(name: "Water", icon: "drop.fill"),
            DefaultSubCategory(name: "Internet", icon: "wifi"),
            DefaultSubCategory(name: "Phone", icon: "iphone"),
            DefaultSubCategory(name: "Streaming Services", icon: "play.tv.fill")
        ]),
        
        // 6. Health
        DefaultCategory(name: "Health", icon: "heart.fill", color: "#FF3B30", type: .expense, subcategories: [
            DefaultSubCategory(name: "Doctor", icon: "stethoscope"),
            DefaultSubCategory(name: "Pharmacy", icon: "pills.fill"),
            DefaultSubCategory(name: "Sports", icon: "figure.run"),
            DefaultSubCategory(name: "Insurance", icon: "cross.case.fill")
        ]),
        
        // 7. Entertainment
        DefaultCategory(name: "Entertainment", icon: "ticket.fill", color: "#AF52DE", type: .expense, subcategories: [
            DefaultSubCategory(name: "Movies", icon: "film.fill"),
            DefaultSubCategory(name: "Games", icon: "gamecontroller.fill"),
            DefaultSubCategory(name: "Travel", icon: "airplane"),
            DefaultSubCategory(name: "Events", icon: "music.mic")
        ]),
        
        // 8. Education
        DefaultCategory(name: "Education", icon: "book.fill", color: "#007AFF", type: .expense, subcategories: [
            DefaultSubCategory(name: "Tuition", icon: "graduationcap.fill"),
            DefaultSubCategory(name: "Books", icon: "text.book.closed.fill"),
            DefaultSubCategory(name: "Courses", icon: "laptopcomputer")
        ]),
        
        // 9. Others (Expense)
        DefaultCategory(name: "Others", icon: "ellipsis.circle.fill", color: "#C7C7CC", type: .expense),
        
        // MARK: - INCOME
        
        // 1. Salary
        DefaultCategory(name: "Salary", icon: "banknote.fill", color: "#34C759", type: .income, subcategories: [
            DefaultSubCategory(name: "Full-time", icon: "briefcase.fill"),
            DefaultSubCategory(name: "Freelance", icon: "person.crop.circle.badge.checkmark"),
            DefaultSubCategory(name: "Bonus", icon: "star.circle.fill")
        ]),
        
        // 2. Investment
        DefaultCategory(name: "Investment", icon: "chart.line.uptrend.xyaxis", color: "#30B0C7", type: .income, subcategories: [
            DefaultSubCategory(name: "Dividends", icon: "percent"),
            DefaultSubCategory(name: "Capital Gains", icon: "arrow.up.right.circle.fill"),
            DefaultSubCategory(name: "Interest", icon: "chart.pie.fill")
        ]),
        
        // 3. Gifts
        DefaultCategory(name: "Gift", icon: "gift.fill", color: "#FF2D55", type: .income),
        
        // 4. Others (Income)
        DefaultCategory(name: "Others", icon: "ellipsis.circle.fill", color: "#C7C7CC", type: .income)
    ]
    
    static func seedDefaults(context: NSManagedObjectContext) {
        for (index, item) in defaults.enumerated() {
            let category = Category(context: context)
            category.id = UUID()
            category.name = item.name
            category.icon = item.icon
            category.color = item.color
            category.type = item.type.rawValue
            category.order = Int16(index)
            
            // Seed Subcategories
            for (subIndex, subItem) in item.subcategories.enumerated() {
                let sub = SubCategory(context: context)
                sub.id = UUID()
                sub.name = subItem.name
                sub.icon = subItem.icon
                sub.order = Int16(subIndex)
                sub.category = category
            }
        }
        try? context.save()
    }
}
