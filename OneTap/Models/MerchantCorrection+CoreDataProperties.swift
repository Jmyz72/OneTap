//
//  MerchantCorrection+CoreDataProperties.swift
//  OneTap
//
//  Core Data properties for merchant corrections
//

import Foundation
@preconcurrency internal import CoreData

extension MerchantCorrection {

    @nonobjc class func fetchRequest() -> NSFetchRequest<MerchantCorrection> {
        return NSFetchRequest<MerchantCorrection>(entityName: "MerchantCorrection")
    }

    @NSManaged var id: UUID?
    @NSManaged var ocrText: String?
    @NSManaged var correctedName: String?
    @NSManaged var occurrences: Int64
    @NSManaged var lastSeen: Date?
    @NSManaged var createdAt: Date?

}

extension MerchantCorrection : Identifiable {

}
