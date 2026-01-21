//
//  ScanReceiptViewModel.swift
//  OneTap
//
//  ViewModel for Receipt History screen with quick scan access
//

import SwiftUI
import Combine
@preconcurrency internal import CoreData

@MainActor
class ScanReceiptViewModel: ObservableObject, ViewModelProtocol {

    // MARK: - Published State

    @Published var recentTransactions: [Transaction] = []
    @Published var loadingState: LoadingState = .idle
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let transactionRepository: TransactionRepository
    private let viewContext: NSManagedObjectContext

    // MARK: - Initialization

    init(
        transactionRepository: TransactionRepository,
        viewContext: NSManagedObjectContext
    ) {
        self.transactionRepository = transactionRepository
        self.viewContext = viewContext
    }

    // MARK: - Data Loading

    func loadRecentTransactions() {
        startLoading()

        // Filter to only show OCR-imported transactions
        let predicate = NSPredicate(format: "isFromOCR == YES")
        let sortDescriptors = [NSSortDescriptor(keyPath: \Transaction.date, ascending: false)]
        let ocrTransactions = transactionRepository.fetch(predicate: predicate, sortDescriptors: sortDescriptors)

        // Take only the 10 most recent OCR transactions
        recentTransactions = Array(ocrTransactions.prefix(10))

        finishLoading()
    }
}
