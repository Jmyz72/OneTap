//
//  ItemCategoryMapping+CoreDataProperties.swift
//  OneTap
//
//  Core Data properties for item category mappings
//

import Foundation
@preconcurrency internal import CoreData

extension ItemCategoryMapping {

    @nonobjc class func fetchRequest() -> NSFetchRequest<ItemCategoryMapping> {
        return NSFetchRequest<ItemCategoryMapping>(entityName: "ItemCategoryMapping")
    }

    @NSManaged var id: UUID?
    @NSManaged var itemTitle: String?
    @NSManaged var categoryName: String?
    @NSManaged var occurrences: Int64
    @NSManaged var lastUsed: Date?
    @NSManaged var createdAt: Date?

}

extension ItemCategoryMapping : Identifiable {

}
