//
//  MerchantCategoryMapping+CoreDataProperties.swift
//  OneTap
//
//  Core Data properties for merchant category mappings
//

import Foundation
@preconcurrency internal import CoreData

extension MerchantCategoryMapping {

    @nonobjc class func fetchRequest() -> NSFetchRequest<MerchantCategoryMapping> {
        return NSFetchRequest<MerchantCategoryMapping>(entityName: "MerchantCategoryMapping")
    }

    @NSManaged var id: UUID?
    @NSManaged var merchantName: String?
    @NSManaged var categoryName: String?
    @NSManaged var occurrences: Int64
    @NSManaged var lastUsed: Date?
    @NSManaged var createdAt: Date?

}

extension MerchantCategoryMapping : Identifiable {

}
