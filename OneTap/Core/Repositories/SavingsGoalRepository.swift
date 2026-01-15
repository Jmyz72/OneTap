//
//  SavingsGoalRepository.swift
//  OneTap
//
//  Repository for SavingsGoal CRUD operations
//

import Foundation
@preconcurrency internal import CoreData

// MARK: - DTOs

struct SavingsGoalCreateData {
    let name: String
    let targetAmount: Double
    let targetDate: Date?
    let accountID: NSManagedObjectID
}

struct SavingsGoalUpdateData {
    var name: String?
    var targetAmount: Double?
    var targetDate: Date?
}

// MARK: - Protocol

protocol SavingsGoalRepositoryProtocol {
    func create(_ dto: SavingsGoalCreateData) throws -> SavingsGoal
    func fetch(for account: Account) -> SavingsGoal?
    func update(_ goal: SavingsGoal, with dto: SavingsGoalUpdateData) throws
    func delete(_ goal: SavingsGoal) throws
    func save() throws
}

// MARK: - Implementation

class SavingsGoalRepository: SavingsGoalRepositoryProtocol {
    let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - Create

    func create(_ dto: SavingsGoalCreateData) throws -> SavingsGoal {
        guard let account = try? context.existingObject(with: dto.accountID) as? Account else {
            throw RepositoryError.entityNotFound
        }

        // Delete existing goal if any (1 account = 1 goal)
        if let existingGoal = account.savingsGoal {
            context.delete(existingGoal)
        }

        let goal = SavingsGoal(context: context)
        goal.id = UUID()
        goal.name = dto.name
        goal.targetAmount = dto.targetAmount
        goal.targetDate = dto.targetDate
        goal.account = account
        goal.createdAt = Date()
        goal.updatedAt = Date()

        try context.save()
        return goal
    }

    // MARK: - Fetch

    func fetch(for account: Account) -> SavingsGoal? {
        return account.savingsGoal
    }

    // MARK: - Update

    func update(_ goal: SavingsGoal, with dto: SavingsGoalUpdateData) throws {
        if let name = dto.name {
            goal.name = name
        }
        if let targetAmount = dto.targetAmount {
            goal.targetAmount = targetAmount
        }
        // Allow setting targetDate to nil
        goal.targetDate = dto.targetDate
        goal.updatedAt = Date()

        try context.save()
    }

    // MARK: - Delete

    func delete(_ goal: SavingsGoal) throws {
        context.delete(goal)
        try context.save()
    }

    // MARK: - Save

    func save() throws {
        if context.hasChanges {
            try context.save()
        }
    }
}
