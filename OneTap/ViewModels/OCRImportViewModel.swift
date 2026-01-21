//
//  OCRImportViewModel.swift
//  OneTap
//
//  ViewModel for OCR transaction import confirmation screen
//

import SwiftUI
import Combine
@preconcurrency internal import CoreData

@MainActor
class OCRImportViewModel: ObservableObject, ViewModelProtocol {

    // MARK: - Published State

    @Published var extractedData: TransactionExtractionService.ExtractedTransaction?
    @Published var selectedAccount: Account?
    @Published var selectedCategory: Category?
    @Published var selectedSubCategory: SubCategory?
    @Published var amount: String = ""
    @Published var title: String = ""  // Transaction title (item name for single items)
    @Published var merchant: String = ""  // Store/merchant name
    @Published var transactionDate: Date = Date()
    @Published var note: String = ""

    @Published var accounts: [Account] = []
    @Published var categories: [Category] = []

    @Published var splitItems: [SplitItemData] = []
    @Published var hasSplitItems: Bool = false

    @Published var adjustments: [AdjustmentData] = []
    @Published var hasAdjustments: Bool = false

    @Published var loadingState: LoadingState = .idle
    @Published var errorMessage: String?
    @Published var shouldDismiss: Bool = false

    // MARK: - Dependencies

    private let ocrService: OCRService
    private let extractionService: TransactionExtractionService
    private let categoryMatchingService: CategoryMatchingService
    private let transactionRepository: TransactionRepository
    private let accountRepository: AccountRepository
    private let categoryRepository: CategoryRepository
    private let balanceService: BalanceService
    private let validationService: ValidationService

    // MARK: - Initialization

    init(
        ocrService: OCRService,
        extractionService: TransactionExtractionService,
        categoryMatchingService: CategoryMatchingService,
        transactionRepository: TransactionRepository,
        accountRepository: AccountRepository,
        categoryRepository: CategoryRepository,
        balanceService: BalanceService,
        validationService: ValidationService
    ) {
        self.ocrService = ocrService
        self.extractionService = extractionService
        self.categoryMatchingService = categoryMatchingService
        self.transactionRepository = transactionRepository
        self.accountRepository = accountRepository
        self.categoryRepository = categoryRepository
        self.balanceService = balanceService
        self.validationService = validationService

        loadData()
    }

    // MARK: - Data Loading

    private func loadData() {
        accounts = accountRepository.fetchAccounts(group: nil, includeArchived: false)
        categories = categoryRepository.fetchCategories(type: .expense)

        // Pre-select first account
        selectedAccount = accounts.first
    }

    // MARK: - OCR Processing

    func processScreenshot(_ image: UIImage) async {
        startLoading()

        do {
            // 1. Perform OCR
            let ocrResult = try await ocrService.extractText(from: image)

            // 2. Extract transaction data
            let extracted = extractionService.extractTransaction(from: ocrResult)
            extractedData = extracted

            // 3. Populate fields
            if let amount = extracted.amount {
                self.amount = String(format: "%.2f", amount)
            }

            if let merchant = extracted.merchant {
                self.merchant = merchant

                // 4. Suggest category based on merchant
                selectedCategory = categoryMatchingService.suggestCategory(
                    forMerchant: merchant,
                    notes: extracted.notes
                )
            }

            if let date = extracted.date {
                self.transactionDate = date
            }

            if let notes = extracted.notes {
                self.note = notes
            }

            // ENHANCED: 5. Convert line items to SplitItemData with smart categorization
            if !extracted.lineItems.isEmpty {
                // Filter out tax/service charge items (they're tracked separately)
                let actualItems = extracted.lineItems.filter { !$0.isTaxOrCharge }

                // SINGLE ITEM RULE: If only 1 item, don't create split transaction
                // Use the total amount (handles rounding) and item name as title
                if actualItems.count == 1 {
                    let singleItem = actualItems[0]

                    // Set title to item name (e.g., "Tau Foo Fa (Take Away)")
                    title = singleItem.title

                    // Keep merchant as store name (already extracted)
                    // If merchant is a generic food court name, it might need manual correction

                    // Keep using the total amount (already set from extracted.amount)
                    // This handles rounding correctly (e.g., item 7.39 + rounding 0.01 = total 7.40)

                    // Set category from item suggestion if available
                    if let suggestedCategoryName = singleItem.suggestedCategory,
                       let matchedCategory = categories.first(where: { $0.name == suggestedCategoryName }) {
                        selectedCategory = matchedCategory
                    }

                    // Don't create split items for single item
                    splitItems = []
                    hasSplitItems = false

                } else {
                    // Multiple items - create split transaction
                    splitItems = actualItems.map { item in
                        // Use suggested category if available, otherwise default to main category
                        var itemCategory = selectedCategory

                        if let suggestedCategoryName = item.suggestedCategory {
                            // Find the category by name
                            if let matchedCategory = categories.first(where: { $0.name == suggestedCategoryName }) {
                                itemCategory = matchedCategory
                            }
                        }

                        return SplitItemData(
                            title: item.title,
                            amount: item.amount,
                            category: itemCategory,  // ENHANCED: Use smart-suggested category
                            subCategory: nil
                        )
                    }
                    hasSplitItems = !splitItems.isEmpty
                }

            } else {
                splitItems = []
                hasSplitItems = false
            }

            // ENHANCED: 6. Convert extracted adjustments to AdjustmentData
            if !extracted.adjustments.isEmpty {
                adjustments = extracted.adjustments.map { adj in
                    AdjustmentData(
                        type: adj.type,
                        amount: adj.amount,
                        label: adj.label,
                        percentage: adj.percentage
                    )
                }
                hasAdjustments = true
            } else {
                adjustments = []
                hasAdjustments = false
            }

            finishLoading()

        } catch {
            handleError(error)
        }
    }

    // MARK: - Split Item Management

    func addSplitItem() {
        let newItem = SplitItemData(
            title: "",
            amount: 0.0,
            category: selectedCategory,
            subCategory: nil
        )
        splitItems.append(newItem)
        hasSplitItems = true
    }

    func removeSplitItem(at index: Int) {
        guard index < splitItems.count else { return }
        splitItems.remove(at: index)
        hasSplitItems = !splitItems.isEmpty
    }

    func updateSplitItem(at index: Int, with item: SplitItemData) {
        guard index < splitItems.count else { return }
        splitItems[index] = item
        syncAmountFromSplitItems()
    }

    func clearSplitItems() {
        splitItems.removeAll()
        hasSplitItems = false
    }

    /// Syncs the total amount from split items
    private func syncAmountFromSplitItems() {
        if hasSplitItems && !splitItems.isEmpty {
            let total = splitItems.reduce(0) { $0 + $1.amount }
            amount = String(format: "%.2f", total)
        }
    }

    // MARK: - Save Transaction

    func saveTransaction() async {
        startLoading()

        do {
            // Calculate amount - use split items total if available
            let amountValue: Double
            if hasSplitItems && !splitItems.isEmpty {
                amountValue = splitItems.reduce(0) { $0 + $1.amount }
            } else {
                guard let parsedAmount = Double(amount), parsedAmount > 0 else {
                    throw ValidationError.invalidAmount
                }
                amountValue = parsedAmount
            }

            guard amountValue > 0 else {
                throw ValidationError.invalidAmount
            }

            guard let account = selectedAccount else {
                throw ValidationError.missingAccount
            }

            // For split items, use the first item's category as the main category
            // For single items, use the selectedCategory
            let mainCategory: Category
            if hasSplitItems && !splitItems.isEmpty {
                // Use first item's category or fall back to selectedCategory
                if let firstItemCategory = splitItems.first?.category {
                    mainCategory = firstItemCategory
                } else if let selected = selectedCategory {
                    mainCategory = selected
                } else {
                    throw ValidationError.missingCategory
                }
            } else {
                guard let category = selectedCategory else {
                    throw ValidationError.missingCategory
                }
                mainCategory = category
            }

            try validationService.validateTransaction(
                amount: amountValue,
                type: .expense,
                account: account,
                category: mainCategory,
                toAccount: nil
            )

            // Determine transaction title: prefer title field, fall back to merchant
            let transactionTitle: String
            if !title.isEmpty {
                transactionTitle = title
            } else if !merchant.isEmpty {
                transactionTitle = merchant
            } else {
                transactionTitle = "OCR Import"
            }

            // Create transaction
            let transaction = try transactionRepository.createTransaction(
                title: transactionTitle,
                amount: amountValue,
                type: .expense,
                date: transactionDate,
                account: account,
                category: mainCategory,
                subCategory: selectedSubCategory,
                merchant: merchant.isEmpty ? nil : merchant,
                notes: note.isEmpty ? nil : note,
                adjustmentReason: nil,
                excludeFromReports: false,
                isFromOCR: true  // Mark this transaction as created from OCR
            )

            // Add split items if available
            if hasSplitItems && !splitItems.isEmpty {
                try transactionRepository.addSplitItems(splitItems, to: transaction)
            }

            // Add adjustments if available
            if hasAdjustments && !adjustments.isEmpty {
                try transactionRepository.addAdjustments(adjustments, to: transaction)
            }

            try transactionRepository.save()

            // Recalculate balances
            try await balanceService.recalculateBalances(for: account.objectID, from: transactionDate)

            shouldDismiss = true
            finishLoading()

        } catch {
            handleError(error)
        }
    }
}
