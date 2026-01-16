//
//  ClaimRepository.swift
//  OneTap
//
//  Repository for managing Claim entities
//

import Foundation
@preconcurrency internal import CoreData
import Combine

protocol ClaimRepositoryProtocol {
    // CRUD
    func createClaim(from transaction: Transaction) throws -> Claim
    func fetch(predicate: NSPredicate?, sortDescriptors: [NSSortDescriptor]) -> [Claim]
    func fetchPendingClaims(for account: Account?) -> [Claim]
    func update(_ claim: Claim, status: ClaimStatus, settledDate: Date?, reimbursementID: UUID?, adjustmentID: UUID?) throws
    func delete(_ claim: Claim) throws
    func save() throws

    // Publishers
    var claimsPublisher: AnyPublisher<[Claim], Never> { get }
}

class ClaimRepository: BaseRepository, ClaimRepositoryProtocol {
    typealias Entity = Claim

    let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    deinit {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    // MARK: - Create

    func createClaim(from transaction: Transaction) throws -> Claim {
        guard transaction.typeEnum == .expense else {
            throw RepositoryError.validationFailed("Only expense transactions can be marked as claims")
        }

        let claim = Claim(context: context)
        claim.id = UUID()
        claim.originalTransactionID = transaction.id
        claim.amount = transaction.amount
        claim.status = ClaimStatus.pending.rawValue
        claim.submittedDate = Date()
        claim.account = transaction.account
        claim.category = transaction.category
        claim.notes = transaction.notes
        claim.createdAt = Date()
        claim.updatedAt = Date()

        try context.save()
        return claim
    }

    // MARK: - Fetch

    func fetch(predicate: NSPredicate? = nil, sortDescriptors: [NSSortDescriptor] = []) -> [Claim] {
        let request = NSFetchRequest<Claim>(entityName: "Claim")
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors

        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching claims: \(error)")
            return []
        }
    }

    func fetchPendingClaims(for account: Account? = nil) -> [Claim] {
        var predicates: [NSPredicate] = [
            NSPredicate(format: "status == %@", ClaimStatus.pending.rawValue)
        ]

        if let account = account {
            predicates.append(NSPredicate(format: "account == %@", account))
        }

        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        let sortDescriptors = [NSSortDescriptor(keyPath: \Claim.submittedDate, ascending: false)]

        return fetch(predicate: predicate, sortDescriptors: sortDescriptors)
    }

    // MARK: - Update

    func update(_ claim: Claim, status: ClaimStatus, settledDate: Date? = nil, reimbursementID: UUID? = nil, adjustmentID: UUID? = nil) throws {
        claim.status = status.rawValue
        claim.settledDate = settledDate
        claim.reimbursementTransactionID = reimbursementID
        claim.adjustmentTransactionID = adjustmentID
        claim.updatedAt = Date()

        try context.save()
    }

    // MARK: - Delete

    func delete(_ claim: Claim) throws {
        context.delete(claim)
        try context.save()
    }

    func save() throws {
        if context.hasChanges {
            try context.save()
        }
    }

    // MARK: - Publisher

    var claimsPublisher: AnyPublisher<[Claim], Never> {
        let initial = fetchPendingClaims()
        let subject = CurrentValueSubject<[Claim], Never>(initial)

        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] notification in
                guard let self = self else { return }

                guard let savedContext = notification.object as? NSManagedObjectContext,
                      savedContext.persistentStoreCoordinator === self.context.persistentStoreCoordinator else {
                    return
                }

                let inserted = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
                let updated = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? []
                let deleted = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? []

                let hasChanges = (inserted.union(updated).union(deleted))
                    .contains { $0 is Claim }

                guard hasChanges else { return }

                let claims = self.fetchPendingClaims()
                subject.send(claims)
            }
            .store(in: &cancellables)

        return subject.eraseToAnyPublisher()
    }
}
