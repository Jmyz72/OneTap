//
//  CategoryModel.swift
//  OneTap
//

import Foundation
import SwiftUI
import CoreData

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
}

extension Category {
    static let defaults: [DefaultCategory] = [
        // Expenses
        DefaultCategory(name: "Food & Drinks", icon: "fork.knife", color: "#FF9500", type: .expense),
        DefaultCategory(name: "Transport", icon: "car.fill", color: "#5856D6", type: .expense),
        DefaultCategory(name: "Shopping", icon: "bag.fill", color: "#FF2D55", type: .expense),
        DefaultCategory(name: "Entertainment", icon: "play.tv.fill", color: "#AF52DE", type: .expense),
        DefaultCategory(name: "Health", icon: "heart.fill", color: "#FF3B30", type: .expense),
        DefaultCategory(name: "Utilities", icon: "bolt.fill", color: "#FFCC00", type: .expense),
        DefaultCategory(name: "Rent", icon: "house.fill", color: "#8E8E93", type: .expense),
        DefaultCategory(name: "Education", icon: "book.fill", color: "#007AFF", type: .expense),
        DefaultCategory(name: "Others", icon: "ellipsis.circle.fill", color: "#C7C7CC", type: .expense),
        
        // Income
        DefaultCategory(name: "Salary", icon: "banknote.fill", color: "#34C759", type: .income),
        DefaultCategory(name: "Investment", icon: "chart.line.uptrend.xyaxis", color: "#30B0C7", type: .income),
        DefaultCategory(name: "Gift", icon: "gift.fill", color: "#FF2D55", type: .income),
        DefaultCategory(name: "Others", icon: "ellipsis.circle.fill", color: "#C7C7CC", type: .income)
    ]
    
    static func seedDefaults(context: NSManagedObjectContext) {
        for item in defaults {
            let category = Category(context: context)
            category.id = UUID()
            category.name = item.name
            category.icon = item.icon
            category.color = item.color
            category.type = item.type.rawValue
        }
        try? context.save()
    }
}
