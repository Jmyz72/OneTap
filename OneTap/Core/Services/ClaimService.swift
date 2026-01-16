//
//  ClaimService.swift
//  OneTap
//
//  Service for handling claim business logic
//

import Foundation
@preconcurrency internal import CoreData

@MainActor
class ClaimService {
    private let claimRepository: ClaimRepository
    private let transactionRepository: TransactionRepository
    private let balanceService: BalanceService

    init(
        claimRepository: ClaimRepository,
        transactionRepository: TransactionRepository,
        balanceService: BalanceService
    ) {
        self.claimRepository = claimRepository
        self.transactionRepository = transactionRepository
        self.balanceService = balanceService
    }

    // MARK: - Create Claim

    func createClaim(from transaction: Transaction) throws -> Claim {
        guard transaction.typeEnum == .expense else {
            throw ServiceError.validationFailed("Only expenses can be marked as claims")
        }

        return try claimRepository.createClaim(from: transaction)
    }

    // MARK: - Settle Claims

    func settleClaims(
        _ claims: [Claim],
        reimbursementAmount: Double,
        toAccount: Account,
        date: Date = Date()
    ) async throws {
        guard !claims.isEmpty else {
            throw ServiceError.validationFailed("No claims selected")
        }

        guard reimbursementAmount > 0 else {
            throw ServiceError.validationFailed("Reimbursement amount must be greater than zero")
        }

        // Calculate total claimed amount
        let totalClaimed = claims.reduce(0.0) { $0 + $1.amount }

        // 1. Create reimbursement Income transaction (EXCLUDED - it just returns your money, not real income)
        let reimbursementTransaction = try transactionRepository.createTransaction(
            title: "Reimbursement (\(claims.count) claims)",
            amount: reimbursementAmount,
            type: .income,
            date: date,
            account: toAccount,
            category: nil,
            subCategory: nil,
            merchant: nil,
            notes: "Settled \(claims.count) claims totaling \(Formatters.currencyFormatter(for: toAccount.currency ?? "USD").string(from: NSNumber(value: totalClaimed)) ?? "$0")",
            adjustmentReason: nil,
            excludeFromReports: true
        )

        try transactionRepository.save()

        // 2. Handle difference if reimbursement != total claimed
        var adjustmentTransactionID: UUID?
        if abs(reimbursementAmount - totalClaimed) > 0.01 { // Use 0.01 for floating point comparison
            let difference = totalClaimed - reimbursementAmount

            // Adjustment is NOT excluded - the difference is real income/expense
            let adjustmentTransaction = try transactionRepository.createTransaction(
                title: "Claim Settlement Adjustment",
                amount: abs(difference),
                type: .adjustment,
                date: date,
                account: toAccount,
                category: nil,
                subCategory: nil,
                merchant: nil,
                notes: difference > 0 ? "Shortfall: Claimed \(totalClaimed) but reimbursed \(reimbursementAmount)" : "Overpayment: Claimed \(totalClaimed) but reimbursed \(reimbursementAmount)",
                adjustmentReason: "Claim settlement difference",
                excludeFromReports: false
            )

            adjustmentTransactionID = adjustmentTransaction.id
            try transactionRepository.save()
        }

        // 3. Update all claims to settled status
        for claim in claims {
            try claimRepository.update(
                claim,
                status: .settled,
                settledDate: date,
                reimbursementID: reimbursementTransaction.id,
                adjustmentID: adjustmentTransactionID
            )
        }

        try claimRepository.save()

        // 4. Recalculate balances
        try await balanceService.recalculateBalances(for: toAccount.objectID, from: date)
    }

    // MARK: - Delete Claim

    func deleteClaim(_ claim: Claim) throws {
        guard !claim.isSettled else {
            throw ServiceError.validationFailed("Cannot delete settled claims")
        }

        try claimRepository.delete(claim)
    }
}
