//
//  RepositoryDTOs.swift
//  OneTap
//
//  Data Transfer Objects for Repository layer
//

import Foundation
internal import CoreData

// MARK: - Transaction DTOs

struct TransactionUpdateData {
    let title: String?
    let amount: Double?
    let date: Date?
    let type: TransactionType?
    let account: Account?
    let category: Category?
    let subCategory: SubCategory?
    let merchant: String?
    let notes: String?
    let excludeFromReports: Bool?
}

struct SplitItemData: Identifiable {
    let id = UUID()
    var title: String
    var amount: Double
    var category: Category?
    var subCategory: SubCategory?
}

// MARK: - Account DTOs

struct AccountUpdateData {
    let name: String?
    let institution: String?
    let type: AccountType?
    let currency: String?
    let creditLimit: Double?
    let icon: String?
    let billingDay: Int?
    let dueDay: Int?
    let lastFourDigits: String?
}

// MARK: - Category DTOs

struct CategoryUpdateData {
    let name: String?
    let icon: String?
    let color: String?
    let order: Int?
}

// MARK: - Adjustment DTOs

struct AdjustmentData: Identifiable {
    let id = UUID()
    var type: AdjustmentType
    var amount: Double
    var label: String?
    var percentage: Double?

    init(type: AdjustmentType, amount: Double, label: String? = nil, percentage: Double? = nil) {
        self.type = type
        self.amount = amount
        self.label = label
        self.percentage = percentage
    }
}
