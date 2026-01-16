//
//  ClaimsListViewModel.swift
//  OneTap
//
//  ViewModel for managing the claims list screen
//

import Foundation
import SwiftUI
import Combine
@preconcurrency internal import CoreData

@MainActor
class ClaimsListViewModel: ObservableObject, ViewModelProtocol {
    // MARK: - Published State

    @Published var pendingClaims: [Claim] = []
    @Published var selectedClaimIDs: Set<NSManagedObjectID> = []
    @Published var isSelectMode: Bool = false
    @Published var selectedAccount: Account?
    @Published var accounts: [Account] = []

    // Settlement sheet
    @Published var showingSettlementSheet: Bool = false
    @Published var settlementAmount: String = ""
    @Published var settlementAccount: Account?

    @Published var loadingState: LoadingState = .idle
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let claimRepository: ClaimRepository
    private let claimService: ClaimService
    private let accountRepository: AccountRepository
    private var cancellables = Set<AnyCancellable>()

    init(
        claimRepository: ClaimRepository,
        claimService: ClaimService,
        accountRepository: AccountRepository
    ) {
        self.claimRepository = claimRepository
        self.claimService = claimService
        self.accountRepository = accountRepository

        loadData()
        setupObservers()
    }

    deinit {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    // MARK: - Computed Properties

    var filteredClaims: [Claim] {
        if let account = selectedAccount {
            return pendingClaims.filter { $0.account == account }
        }
        return pendingClaims
    }

    var selectedClaims: [Claim] {
        filteredClaims.filter { selectedClaimIDs.contains($0.objectID) }
    }

    var totalSelectedAmount: Double {
        selectedClaims.reduce(0.0) { $0 + $1.amount }
    }

    var formattedTotalSelected: String {
        let formatter = Formatters.currencyFormatter(for: SettingsManager.shared.currencyCode)
        return formatter.string(from: NSNumber(value: totalSelectedAmount)) ?? "$0"
    }

    var canSettle: Bool {
        !selectedClaimIDs.isEmpty
    }

    // MARK: - Data Loading

    private func loadData() {
        pendingClaims = claimRepository.fetchPendingClaims()
        accounts = accountRepository.fetchAccounts(group: nil, includeArchived: false)
    }

    private func setupObservers() {
        // Observe claims changes
        claimRepository.claimsPublisher
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] claims in
                    self?.pendingClaims = claims
                }
            )
            .store(in: &cancellables)

        // Observe accounts changes
        accountRepository.accountsPublisher()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] accounts in
                    self?.accounts = accounts
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Actions

    func toggleSelection(_ claim: Claim) {
        if selectedClaimIDs.contains(claim.objectID) {
            selectedClaimIDs.remove(claim.objectID)
        } else {
            selectedClaimIDs.insert(claim.objectID)
        }
    }

    func selectAll() {
        selectedClaimIDs = Set(filteredClaims.map { $0.objectID })
    }

    func deselectAll() {
        selectedClaimIDs.removeAll()
        isSelectMode = false
    }

    func startSettlement() {
        guard canSettle else { return }

        // Pre-fill settlement amount with total
        settlementAmount = String(format: "%.2f", totalSelectedAmount)

        // Pre-select first account or account from first claim
        settlementAccount = selectedClaims.first?.account ?? accounts.first

        showingSettlementSheet = true
    }

    func confirmSettlement() async {
        startLoading()

        do {
            guard let amount = Double(settlementAmount), amount > 0 else {
                throw ServiceError.validationFailed("Please enter a valid reimbursement amount")
            }

            guard let account = settlementAccount else {
                throw ServiceError.validationFailed("Please select an account")
            }

            try await claimService.settleClaims(
                selectedClaims,
                reimbursementAmount: amount,
                toAccount: account
            )

            // Clear selection
            deselectAll()
            showingSettlementSheet = false

            finishLoading()

        } catch {
            handleError(error)
        }
    }

    func deleteClaim(_ claim: Claim) async {
        do {
            try claimService.deleteClaim(claim)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
