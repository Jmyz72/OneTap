//
//  CategoryListViewModel.swift
//  OneTap
//
//  ViewModel for category management list
//  Replaces logic from CategoryListView.swift (lines 89-124)
//

import Foundation
import SwiftUI
import Combine
@preconcurrency internal import CoreData

@MainActor
class CategoryListViewModel: ObservableObject, ViewModelProtocol {
    // MARK: - Published State
    @Published var expenseCategories: [Category] = []
    @Published var incomeCategories: [Category] = []
    @Published var loadingState: LoadingState = .idle
    @Published var errorMessage: String?

    // MARK: - Dependencies
    private let categoryRepository: CategoryRepository
    private var cancellables = Set<AnyCancellable>()

    init(categoryRepository: CategoryRepository) {
        self.categoryRepository = categoryRepository
        setupSubscriptions()

        // Also do an initial fetch to populate immediately
        let allCategories = categoryRepository.fetchCategories(type: nil)
        self.expenseCategories = allCategories.filter { $0.typeEnum == .expense }.sorted { $0.order < $1.order }
        self.incomeCategories = allCategories.filter { $0.typeEnum == .income }.sorted { $0.order < $1.order }
    }

    // MARK: - Subscriptions

    private func setupSubscriptions() {
        // Expense categories
        categoryRepository.categoriesPublisher(type: .expense)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleError(error)
                }
            } receiveValue: { [weak self] categories in
                self?.expenseCategories = categories.sorted { $0.order < $1.order }
            }
            .store(in: &cancellables)

        // Income categories
        categoryRepository.categoriesPublisher(type: .income)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleError(error)
                }
            } receiveValue: { [weak self] categories in
                self?.incomeCategories = categories.sorted { $0.order < $1.order }
                self?.loadingState = .loaded
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    func moveExpenseCategories(from source: IndexSet, to destination: Int) async {
        var items = expenseCategories
        items.move(fromOffsets: source, toOffset: destination)

        do {
            try categoryRepository.reorderCategories(items)
            try categoryRepository.save()
        } catch {
            handleError(error)
        }
    }

    func moveIncomeCategories(from source: IndexSet, to destination: Int) async {
        var items = incomeCategories
        items.move(fromOffsets: source, toOffset: destination)

        do {
            try categoryRepository.reorderCategories(items)
            try categoryRepository.save()
        } catch {
            handleError(error)
        }
    }

    func deleteExpenseCategories(at offsets: IndexSet) async {
        do {
            for index in offsets {
                try categoryRepository.deleteCategory(expenseCategories[index])
            }
            try categoryRepository.save()
        } catch {
            handleError(error)
        }
    }

    func deleteIncomeCategories(at offsets: IndexSet) async {
        do {
            for index in offsets {
                try categoryRepository.deleteCategory(incomeCategories[index])
            }
            try categoryRepository.save()
        } catch {
            handleError(error)
        }
    }

    func resetCategories() async {
        loadingState = .loading
        do {
            try categoryRepository.resetToDefaults()
            loadingState = .loaded
        } catch {
            handleError(error)
        }
    }
}
