//
//  BaseRepository.swift
//  OneTap
//
//  Base repository protocol for Core Data operations
//

import Foundation
import CoreData
import Combine

protocol BaseRepository {
    associatedtype Entity: NSManagedObject

    var context: NSManagedObjectContext { get }

    func save() throws
    func delete(_ entity: Entity) throws
    func findByID(_ id: NSManagedObjectID) -> Entity?
}

// Default implementations
extension BaseRepository {
    func save() throws {
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            throw RepositoryError.saveFailed(error.localizedDescription)
        }
    }

    func delete(_ entity: Entity) throws {
        context.delete(entity)

        do {
            try context.save()
        } catch {
            throw RepositoryError.deleteFailed(error.localizedDescription)
        }
    }

    func findByID(_ id: NSManagedObjectID) -> Entity? {
        do {
            return try context.existingObject(with: id) as? Entity
        } catch {
            return nil
        }
    }
}
