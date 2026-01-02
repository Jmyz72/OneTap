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
            DefaultSubCategory(name: "Alcohol & Bars", icon: "wineglass.fill"),
            DefaultSubCategory(name: "Snacks & Desserts", icon: "birthday.cake.fill"),
            DefaultSubCategory(name: "Food Delivery", icon: "shippingbox.fill")
        ]),

        // 2. Transport
        DefaultCategory(name: "Transport", icon: "car.fill", color: "#5856D6", type: .expense, subcategories: [
            DefaultSubCategory(name: "Fuel", icon: "fuelpump.fill"),
            DefaultSubCategory(name: "Public Transit", icon: "bus.fill"),
            DefaultSubCategory(name: "Ride Share", icon: "car.circle.fill"),
            DefaultSubCategory(name: "Parking", icon: "parkingsign.circle.fill"),
            DefaultSubCategory(name: "Car Maintenance", icon: "wrench.and.screwdriver.fill"),
            DefaultSubCategory(name: "Tolls", icon: "dollarsign.circle.fill"),
            DefaultSubCategory(name: "Vehicle Insurance", icon: "shield.lefthalf.filled"),
            DefaultSubCategory(name: "Car Payments", icon: "creditcard.fill")
        ]),

        // 3. Shopping
        DefaultCategory(name: "Shopping", icon: "bag.fill", color: "#FF2D55", type: .expense, subcategories: [
            DefaultSubCategory(name: "Clothing", icon: "tshirt.fill"),
            DefaultSubCategory(name: "Shoes", icon: "shoe.fill"),
            DefaultSubCategory(name: "Accessories", icon: "eyeglasses"),
            DefaultSubCategory(name: "Electronics", icon: "desktopcomputer"),
            DefaultSubCategory(name: "Furniture", icon: "sofa.fill"),
            DefaultSubCategory(name: "Home Decor", icon: "lamp.table.fill"),
            DefaultSubCategory(name: "Books & Magazines", icon: "book.fill"),
            DefaultSubCategory(name: "Online Shopping", icon: "cart.fill.badge.plus")
        ]),

        // 4. Housing
        DefaultCategory(name: "Housing", icon: "house.fill", color: "#8E8E93", type: .expense, subcategories: [
            DefaultSubCategory(name: "Rent", icon: "house.circle.fill"),
            DefaultSubCategory(name: "Mortgage", icon: "banknote.fill"),
            DefaultSubCategory(name: "Property Tax", icon: "doc.text.fill"),
            DefaultSubCategory(name: "Home Insurance", icon: "shield.fill"),
            DefaultSubCategory(name: "HOA Fees", icon: "building.2.fill"),
            DefaultSubCategory(name: "Repairs & Maintenance", icon: "hammer.fill"),
            DefaultSubCategory(name: "Household Supplies", icon: "basket.fill")
        ]),

        // 5. Utilities & Bills
        DefaultCategory(name: "Utilities & Bills", icon: "bolt.fill", color: "#FFCC00", type: .expense, subcategories: [
            DefaultSubCategory(name: "Electricity", icon: "bolt.circle.fill"),
            DefaultSubCategory(name: "Water & Sewer", icon: "drop.fill"),
            DefaultSubCategory(name: "Gas", icon: "flame.fill"),
            DefaultSubCategory(name: "Internet", icon: "wifi"),
            DefaultSubCategory(name: "Phone", icon: "iphone"),
            DefaultSubCategory(name: "Cable TV", icon: "tv.fill"),
            DefaultSubCategory(name: "Streaming Services", icon: "play.tv.fill"),
            DefaultSubCategory(name: "Cloud Storage", icon: "icloud.fill")
        ]),

        // 6. Health & Fitness
        DefaultCategory(name: "Health & Fitness", icon: "heart.fill", color: "#FF3B30", type: .expense, subcategories: [
            DefaultSubCategory(name: "Doctor Visits", icon: "stethoscope"),
            DefaultSubCategory(name: "Dentist", icon: "cross.case.fill"),
            DefaultSubCategory(name: "Pharmacy", icon: "pills.fill"),
            DefaultSubCategory(name: "Health Insurance", icon: "cross.circle.fill"),
            DefaultSubCategory(name: "Gym Membership", icon: "figure.run"),
            DefaultSubCategory(name: "Sports Equipment", icon: "sportscourt.fill"),
            DefaultSubCategory(name: "Therapy & Wellness", icon: "leaf.fill"),
            DefaultSubCategory(name: "Vitamins & Supplements", icon: "cross.vial.fill")
        ]),

        // 7. Personal Care
        DefaultCategory(name: "Personal Care", icon: "sparkles", color: "#FF69B4", type: .expense, subcategories: [
            DefaultSubCategory(name: "Hair Salon", icon: "scissors"),
            DefaultSubCategory(name: "Spa & Massage", icon: "hand.raised.fill"),
            DefaultSubCategory(name: "Cosmetics", icon: "paintbrush.fill"),
            DefaultSubCategory(name: "Skincare", icon: "drop.triangle.fill"),
            DefaultSubCategory(name: "Barber", icon: "scissors"),
            DefaultSubCategory(name: "Nails", icon: "hand.point.up.fill")
        ]),

        // 8. Entertainment & Leisure
        DefaultCategory(name: "Entertainment", icon: "ticket.fill", color: "#AF52DE", type: .expense, subcategories: [
            DefaultSubCategory(name: "Movies & Theater", icon: "film.fill"),
            DefaultSubCategory(name: "Concerts & Events", icon: "music.mic"),
            DefaultSubCategory(name: "Gaming", icon: "gamecontroller.fill"),
            DefaultSubCategory(name: "Hobbies", icon: "paintpalette.fill"),
            DefaultSubCategory(name: "Books & Music", icon: "books.vertical.fill"),
            DefaultSubCategory(name: "Subscriptions", icon: "arrow.clockwise.circle.fill"),
            DefaultSubCategory(name: "Sports Events", icon: "sportscourt.fill")
        ]),

        // 9. Travel & Vacation
        DefaultCategory(name: "Travel & Vacation", icon: "airplane", color: "#5AC8FA", type: .expense, subcategories: [
            DefaultSubCategory(name: "Flights", icon: "airplane.departure"),
            DefaultSubCategory(name: "Hotels", icon: "bed.double.fill"),
            DefaultSubCategory(name: "Car Rental", icon: "car.2.fill"),
            DefaultSubCategory(name: "Tours & Activities", icon: "map.fill"),
            DefaultSubCategory(name: "Travel Insurance", icon: "shield.checkered"),
            DefaultSubCategory(name: "Souvenirs", icon: "gift.fill"),
            DefaultSubCategory(name: "Luggage", icon: "suitcase.fill")
        ]),

        // 10. Education
        DefaultCategory(name: "Education", icon: "book.fill", color: "#007AFF", type: .expense, subcategories: [
            DefaultSubCategory(name: "Tuition", icon: "graduationcap.fill"),
            DefaultSubCategory(name: "Textbooks", icon: "text.book.closed.fill"),
            DefaultSubCategory(name: "Online Courses", icon: "laptopcomputer"),
            DefaultSubCategory(name: "School Supplies", icon: "pencil.and.ruler.fill"),
            DefaultSubCategory(name: "Student Loans", icon: "banknote.fill"),
            DefaultSubCategory(name: "Workshops", icon: "person.3.fill")
        ]),

        // 11. Family & Kids
        DefaultCategory(name: "Family & Kids", icon: "figure.2.and.child.holdinghands", color: "#FFD700", type: .expense, subcategories: [
            DefaultSubCategory(name: "Childcare", icon: "figure.and.child.holdinghands"),
            DefaultSubCategory(name: "Baby Supplies", icon: "basket.fill"),
            DefaultSubCategory(name: "Toys", icon: "teddybear.fill"),
            DefaultSubCategory(name: "School Fees", icon: "building.columns.fill"),
            DefaultSubCategory(name: "Children's Activities", icon: "figure.play"),
            DefaultSubCategory(name: "Allowance", icon: "dollarsign.circle.fill")
        ]),

        // 12. Pets
        DefaultCategory(name: "Pets", icon: "pawprint.fill", color: "#8B4513", type: .expense, subcategories: [
            DefaultSubCategory(name: "Pet Food", icon: "pawprint.circle.fill"),
            DefaultSubCategory(name: "Veterinarian", icon: "cross.case.fill"),
            DefaultSubCategory(name: "Pet Supplies", icon: "basket.fill"),
            DefaultSubCategory(name: "Grooming", icon: "sparkles"),
            DefaultSubCategory(name: "Pet Insurance", icon: "shield.fill"),
            DefaultSubCategory(name: "Pet Boarding", icon: "house.fill")
        ]),

        // 13. Subscriptions & Memberships
        DefaultCategory(name: "Subscriptions", icon: "arrow.clockwise.circle.fill", color: "#FF9500", type: .expense, subcategories: [
            DefaultSubCategory(name: "Streaming", icon: "play.tv.fill"),
            DefaultSubCategory(name: "Music", icon: "music.note"),
            DefaultSubCategory(name: "News & Magazines", icon: "newspaper.fill"),
            DefaultSubCategory(name: "Software", icon: "app.fill"),
            DefaultSubCategory(name: "Gym", icon: "figure.strengthtraining.traditional"),
            DefaultSubCategory(name: "Club Memberships", icon: "person.3.fill"),
            DefaultSubCategory(name: "Professional Associations", icon: "briefcase.fill")
        ]),

        // 14. Gifts & Donations
        DefaultCategory(name: "Gifts & Donations", icon: "gift.fill", color: "#FF2D55", type: .expense, subcategories: [
            DefaultSubCategory(name: "Birthday Gifts", icon: "birthday.cake.fill"),
            DefaultSubCategory(name: "Holiday Gifts", icon: "gift.circle.fill"),
            DefaultSubCategory(name: "Wedding Gifts", icon: "heart.fill"),
            DefaultSubCategory(name: "Charity", icon: "hand.raised.fill"),
            DefaultSubCategory(name: "Religious Donations", icon: "building.columns.fill"),
            DefaultSubCategory(name: "Crowdfunding", icon: "person.3.fill")
        ]),

        // 15. Insurance
        DefaultCategory(name: "Insurance", icon: "shield.fill", color: "#34C759", type: .expense, subcategories: [
            DefaultSubCategory(name: "Life Insurance", icon: "shield.checkered"),
            DefaultSubCategory(name: "Health Insurance", icon: "cross.case.fill"),
            DefaultSubCategory(name: "Disability Insurance", icon: "shield.lefthalf.filled"),
            DefaultSubCategory(name: "Umbrella Policy", icon: "umbrella.fill"),
            DefaultSubCategory(name: "Other Insurance", icon: "shield.fill")
        ]),

        // 16. Taxes
        DefaultCategory(name: "Taxes", icon: "doc.text.fill", color: "#8E8E93", type: .expense, subcategories: [
            DefaultSubCategory(name: "Income Tax", icon: "dollarsign.circle.fill"),
            DefaultSubCategory(name: "Property Tax", icon: "house.circle.fill"),
            DefaultSubCategory(name: "Sales Tax", icon: "cart.fill"),
            DefaultSubCategory(name: "Tax Preparation", icon: "doc.badge.gearshape.fill")
        ]),

        // 17. Debt Payments
        DefaultCategory(name: "Debt Payments", icon: "creditcard.fill", color: "#FF3B30", type: .expense, subcategories: [
            DefaultSubCategory(name: "Credit Card", icon: "creditcard.and.123"),
            DefaultSubCategory(name: "Personal Loan", icon: "banknote.fill"),
            DefaultSubCategory(name: "Student Loan", icon: "graduationcap.fill"),
            DefaultSubCategory(name: "Medical Debt", icon: "cross.case.fill"),
            DefaultSubCategory(name: "Other Loans", icon: "dollarsign.circle.fill")
        ]),

        // 18. Business Expenses
        DefaultCategory(name: "Business Expenses", icon: "briefcase.fill", color: "#5856D6", type: .expense, subcategories: [
            DefaultSubCategory(name: "Office Supplies", icon: "pencil.and.ruler.fill"),
            DefaultSubCategory(name: "Software & Tools", icon: "app.fill"),
            DefaultSubCategory(name: "Marketing", icon: "megaphone.fill"),
            DefaultSubCategory(name: "Business Travel", icon: "airplane.departure"),
            DefaultSubCategory(name: "Meals & Entertainment", icon: "fork.knife"),
            DefaultSubCategory(name: "Professional Services", icon: "person.fill.checkmark"),
            DefaultSubCategory(name: "Equipment", icon: "desktopcomputer")
        ]),

        // 19. Bank Fees & Charges
        DefaultCategory(name: "Fees & Charges", icon: "banknote.fill", color: "#FF9500", type: .expense, subcategories: [
            DefaultSubCategory(name: "Bank Fees", icon: "building.columns.fill"),
            DefaultSubCategory(name: "ATM Fees", icon: "dollarsign.circle.fill"),
            DefaultSubCategory(name: "Late Fees", icon: "clock.fill"),
            DefaultSubCategory(name: "Service Charges", icon: "doc.fill"),
            DefaultSubCategory(name: "Foreign Transaction Fees", icon: "globe")
        ]),

        // 20. Others (Expense)
        DefaultCategory(name: "Others", icon: "ellipsis.circle.fill", color: "#C7C7CC", type: .expense, subcategories: [
            DefaultSubCategory(name: "Miscellaneous", icon: "questionmark.circle.fill"),
            DefaultSubCategory(name: "Cash Withdrawal", icon: "banknote.fill"),
            DefaultSubCategory(name: "Uncategorized", icon: "tray.fill")
        ]),

        // MARK: - INCOME

        // 1. Salary & Wages
        DefaultCategory(name: "Salary & Wages", icon: "banknote.fill", color: "#34C759", type: .income, subcategories: [
            DefaultSubCategory(name: "Full-time Salary", icon: "briefcase.fill"),
            DefaultSubCategory(name: "Part-time Wages", icon: "clock.fill"),
            DefaultSubCategory(name: "Overtime Pay", icon: "hourglass.fill"),
            DefaultSubCategory(name: "Bonus", icon: "star.circle.fill"),
            DefaultSubCategory(name: "Commission", icon: "percent"),
            DefaultSubCategory(name: "Tips", icon: "dollarsign.circle.fill")
        ]),

        // 2. Business Income
        DefaultCategory(name: "Business Income", icon: "briefcase.circle.fill", color: "#5856D6", type: .income, subcategories: [
            DefaultSubCategory(name: "Sales Revenue", icon: "cart.fill.badge.plus"),
            DefaultSubCategory(name: "Consulting Fees", icon: "person.fill.checkmark"),
            DefaultSubCategory(name: "Service Income", icon: "wrench.and.screwdriver.fill"),
            DefaultSubCategory(name: "Client Payments", icon: "banknote.fill"),
            DefaultSubCategory(name: "Contract Work", icon: "doc.text.fill")
        ]),

        // 3. Freelance & Side Hustle
        DefaultCategory(name: "Freelance & Gigs", icon: "person.crop.circle.badge.checkmark", color: "#FF9500", type: .income, subcategories: [
            DefaultSubCategory(name: "Freelance Work", icon: "laptopcomputer"),
            DefaultSubCategory(name: "Gig Economy", icon: "car.circle.fill"),
            DefaultSubCategory(name: "Creative Work", icon: "paintpalette.fill"),
            DefaultSubCategory(name: "Online Sales", icon: "cart.fill"),
            DefaultSubCategory(name: "Tutoring", icon: "book.fill")
        ]),

        // 4. Investment Income
        DefaultCategory(name: "Investment", icon: "chart.line.uptrend.xyaxis", color: "#30B0C7", type: .income, subcategories: [
            DefaultSubCategory(name: "Dividends", icon: "percent"),
            DefaultSubCategory(name: "Capital Gains", icon: "arrow.up.right.circle.fill"),
            DefaultSubCategory(name: "Interest", icon: "chart.pie.fill"),
            DefaultSubCategory(name: "Crypto Gains", icon: "bitcoinsign.circle.fill"),
            DefaultSubCategory(name: "Stock Sales", icon: "chart.bar.fill")
        ]),

        // 5. Rental Income
        DefaultCategory(name: "Rental Income", icon: "house.and.flag.fill", color: "#8E8E93", type: .income, subcategories: [
            DefaultSubCategory(name: "Property Rent", icon: "house.circle.fill"),
            DefaultSubCategory(name: "Vacation Rental", icon: "airplane"),
            DefaultSubCategory(name: "Equipment Rental", icon: "gearshape.fill"),
            DefaultSubCategory(name: "Storage Rental", icon: "archivebox.fill")
        ]),

        // 6. Government Benefits
        DefaultCategory(name: "Benefits & Grants", icon: "building.columns.fill", color: "#007AFF", type: .income, subcategories: [
            DefaultSubCategory(name: "Social Security", icon: "person.fill"),
            DefaultSubCategory(name: "Unemployment", icon: "briefcase.circle.fill"),
            DefaultSubCategory(name: "Disability", icon: "figure.stand"),
            DefaultSubCategory(name: "Pension", icon: "building.columns.circle.fill"),
            DefaultSubCategory(name: "Child Support", icon: "figure.2.and.child.holdinghands"),
            DefaultSubCategory(name: "Government Grants", icon: "doc.fill")
        ]),

        // 7. Gifts & Inheritance
        DefaultCategory(name: "Gifts & Inheritance", icon: "gift.fill", color: "#FF2D55", type: .income, subcategories: [
            DefaultSubCategory(name: "Monetary Gifts", icon: "banknote.fill"),
            DefaultSubCategory(name: "Inheritance", icon: "building.columns.fill"),
            DefaultSubCategory(name: "Birthday Money", icon: "birthday.cake.fill"),
            DefaultSubCategory(name: "Holiday Gifts", icon: "gift.circle.fill")
        ]),

        // 8. Refunds & Reimbursements
        DefaultCategory(name: "Refunds", icon: "arrow.uturn.backward.circle.fill", color: "#34C759", type: .income, subcategories: [
            DefaultSubCategory(name: "Tax Refund", icon: "doc.text.fill"),
            DefaultSubCategory(name: "Purchase Refund", icon: "cart.fill"),
            DefaultSubCategory(name: "Insurance Claim", icon: "shield.fill"),
            DefaultSubCategory(name: "Expense Reimbursement", icon: "dollarsign.circle.fill"),
            DefaultSubCategory(name: "Cashback & Rewards", icon: "percent")
        ]),

        // 9. Selling Items
        DefaultCategory(name: "Selling Items", icon: "tag.fill", color: "#FFCC00", type: .income, subcategories: [
            DefaultSubCategory(name: "Online Sales", icon: "cart.badge.plus"),
            DefaultSubCategory(name: "Garage Sale", icon: "house.fill"),
            DefaultSubCategory(name: "Used Items", icon: "arrow.triangle.2.circlepath"),
            DefaultSubCategory(name: "Handmade Goods", icon: "paintpalette.fill"),
            DefaultSubCategory(name: "Vehicle Sale", icon: "car.fill")
        ]),

        // 10. Others (Income)
        DefaultCategory(name: "Others", icon: "ellipsis.circle.fill", color: "#C7C7CC", type: .income, subcategories: [
            DefaultSubCategory(name: "Miscellaneous", icon: "questionmark.circle.fill"),
            DefaultSubCategory(name: "Uncategorized", icon: "tray.fill")
        ])
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
        // Note: Caller is responsible for saving the context
    }
}
