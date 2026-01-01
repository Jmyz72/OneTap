//
//  RepositoryDTOs.swift
//  OneTap
//
//  Data Transfer Objects for Repository layer
//

import Foundation
import CoreData

// MARK: - Transaction DTOs

struct TransactionUpdateData {
    let title: String?
    let amount: Double?
    let date: Date?
    let type: TransactionType?
    let account: Account?
    let category: Category?
    let subCategory: SubCategory?
    let notes: String?
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
