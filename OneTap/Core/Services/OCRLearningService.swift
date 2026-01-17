//
//  OCRLearningService.swift
//  OneTap
//
//  Learns from user corrections to improve future OCR accuracy
//  Tracks merchant name corrections, category assignments, and patterns
//

import Foundation
@preconcurrency internal import CoreData

@MainActor
class OCRLearningService {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - Merchant Learning

    /// Records a merchant name correction
    func recordMerchantCorrection(ocrText: String, correctedName: String) {
        // Store correction for fuzzy matching
        let correction = MerchantCorrection(context: context)
        correction.id = UUID()
        correction.ocrText = ocrText
        correction.correctedName = correctedName
        correction.occurrences = 1
        correction.lastSeen = Date()
        correction.createdAt = Date()

        // Check if we already have this pattern
        let fetchRequest: NSFetchRequest<MerchantCorrection> = MerchantCorrection.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "ocrText ==[cd] %@ AND correctedName ==[cd] %@", ocrText, correctedName)
        fetchRequest.fetchLimit = 1

        if let existing = try? context.fetch(fetchRequest).first {
            // Increment occurrence count
            existing.occurrences += 1
            existing.lastSeen = Date()
            context.delete(correction)
        }

        saveContext()
    }

    /// Gets the most likely merchant name for OCR text
    func getSuggestedMerchant(for ocrText: String) -> String? {
        let fetchRequest: NSFetchRequest<MerchantCorrection> = MerchantCorrection.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "ocrText ==[cd] %@", ocrText)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "occurrences", ascending: false)]
        fetchRequest.fetchLimit = 1

        if let correction = try? context.fetch(fetchRequest).first {
            return correction.correctedName
        }

        return nil
    }

    /// Gets all known merchant variations for fuzzy matching
    func getAllMerchantPatterns() -> [(ocrText: String, correctedName: String, occurrences: Int)] {
        let fetchRequest: NSFetchRequest<MerchantCorrection> = MerchantCorrection.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "occurrences", ascending: false)]

        guard let corrections = try? context.fetch(fetchRequest) else {
            return []
        }

        return corrections.map { ($0.ocrText ?? "", $0.correctedName ?? "", Int($0.occurrences)) }
    }

    // MARK: - Category Learning

    /// Records a category assignment for a merchant
    func recordCategoryAssignment(merchant: String, category: String) {
        let assignment = MerchantCategoryMapping(context: context)
        assignment.id = UUID()
        assignment.merchantName = merchant
        assignment.categoryName = category
        assignment.occurrences = 1
        assignment.lastUsed = Date()
        assignment.createdAt = Date()

        // Check if we already have this mapping
        let fetchRequest: NSFetchRequest<MerchantCategoryMapping> = MerchantCategoryMapping.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "merchantName ==[cd] %@ AND categoryName ==[cd] %@", merchant, category)
        fetchRequest.fetchLimit = 1

        if let existing = try? context.fetch(fetchRequest).first {
            existing.occurrences += 1
            existing.lastUsed = Date()
            context.delete(assignment)
        }

        saveContext()
    }

    /// Gets the most frequently used category for a merchant
    func getSuggestedCategory(for merchant: String) -> String? {
        let fetchRequest: NSFetchRequest<MerchantCategoryMapping> = MerchantCategoryMapping.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "merchantName ==[cd] %@", merchant)
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "occurrences", ascending: false),
            NSSortDescriptor(key: "lastUsed", ascending: false)
        ]
        fetchRequest.fetchLimit = 1

        if let mapping = try? context.fetch(fetchRequest).first {
            return mapping.categoryName
        }

        return nil
    }

    // MARK: - Item Category Learning

    /// Records a category assignment for a line item
    func recordItemCategoryAssignment(itemTitle: String, category: String) {
        let assignment = ItemCategoryMapping(context: context)
        assignment.id = UUID()
        assignment.itemTitle = itemTitle
        assignment.categoryName = category
        assignment.occurrences = 1
        assignment.lastUsed = Date()
        assignment.createdAt = Date()

        // Check if we already have this mapping
        let fetchRequest: NSFetchRequest<ItemCategoryMapping> = ItemCategoryMapping.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "itemTitle ==[cd] %@ AND categoryName ==[cd] %@", itemTitle, category)
        fetchRequest.fetchLimit = 1

        if let existing = try? context.fetch(fetchRequest).first {
            existing.occurrences += 1
            existing.lastUsed = Date()
            context.delete(assignment)
        }

        saveContext()
    }

    /// Gets the most frequently used category for a line item
    func getSuggestedItemCategory(for itemTitle: String) -> String? {
        let fetchRequest: NSFetchRequest<ItemCategoryMapping> = ItemCategoryMapping.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "itemTitle ==[cd] %@", itemTitle)
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "occurrences", ascending: false),
            NSSortDescriptor(key: "lastUsed", ascending: false)
        ]
        fetchRequest.fetchLimit = 1

        if let mapping = try? context.fetch(fetchRequest).first {
            return mapping.categoryName
        }

        return nil
    }

    // MARK: - Pattern Analysis

    /// Analyzes learning data to provide insights
    func getLearningSummary() -> LearningSummary {
        let merchantCount = (try? context.count(for: MerchantCorrection.fetchRequest())) ?? 0
        let merchantCategoryCount = (try? context.count(for: MerchantCategoryMapping.fetchRequest())) ?? 0
        let itemCategoryCount = (try? context.count(for: ItemCategoryMapping.fetchRequest())) ?? 0

        return LearningSummary(
            merchantCorrections: merchantCount,
            merchantCategoryMappings: merchantCategoryCount,
            itemCategoryMappings: itemCategoryCount
        )
    }

    struct LearningSummary {
        let merchantCorrections: Int
        let merchantCategoryMappings: Int
        let itemCategoryMappings: Int

        var totalLearnings: Int {
            merchantCorrections + merchantCategoryMappings + itemCategoryMappings
        }
    }

    // MARK: - Data Management

    /// Clears old learning data (older than specified days)
    func clearOldLearningData(olderThan days: Int) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        // Clear old merchant corrections
        let merchantFetch: NSFetchRequest<MerchantCorrection> = MerchantCorrection.fetchRequest()
        merchantFetch.predicate = NSPredicate(format: "lastSeen < %@", cutoffDate as NSDate)
        if let oldCorrections = try? context.fetch(merchantFetch) {
            oldCorrections.forEach { context.delete($0) }
        }

        // Clear old merchant category mappings
        let merchantCatFetch: NSFetchRequest<MerchantCategoryMapping> = MerchantCategoryMapping.fetchRequest()
        merchantCatFetch.predicate = NSPredicate(format: "lastUsed < %@", cutoffDate as NSDate)
        if let oldMappings = try? context.fetch(merchantCatFetch) {
            oldMappings.forEach { context.delete($0) }
        }

        // Clear old item category mappings
        let itemCatFetch: NSFetchRequest<ItemCategoryMapping> = ItemCategoryMapping.fetchRequest()
        itemCatFetch.predicate = NSPredicate(format: "lastUsed < %@", cutoffDate as NSDate)
        if let oldMappings = try? context.fetch(itemCatFetch) {
            oldMappings.forEach { context.delete($0) }
        }

        saveContext()
    }

    /// Clears all learning data
    func clearAllLearningData() {
        // Delete all merchant corrections
        let merchantFetch: NSFetchRequest<NSFetchRequestResult> = MerchantCorrection.fetchRequest()
        let merchantDelete = NSBatchDeleteRequest(fetchRequest: merchantFetch)
        _ = try? context.execute(merchantDelete)

        // Delete all merchant category mappings
        let merchantCatFetch: NSFetchRequest<NSFetchRequestResult> = MerchantCategoryMapping.fetchRequest()
        let merchantCatDelete = NSBatchDeleteRequest(fetchRequest: merchantCatFetch)
        _ = try? context.execute(merchantCatDelete)

        // Delete all item category mappings
        let itemCatFetch: NSFetchRequest<NSFetchRequestResult> = ItemCategoryMapping.fetchRequest()
        let itemCatDelete = NSBatchDeleteRequest(fetchRequest: itemCatFetch)
        _ = try? context.execute(itemCatDelete)

        saveContext()
    }

    // MARK: - Helper Methods

    private func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save learning data: \(error.localizedDescription)")
            }
        }
    }
}
