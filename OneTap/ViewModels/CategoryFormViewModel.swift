//
//  CategoryFormViewModel.swift
//  OneTap
//
//  ViewModel for category creation/editing
//

import Foundation
import SwiftUI

@MainActor
class CategoryFormViewModel: ObservableObject, ViewModelProtocol {
    // MARK: - Published State
    @Published var name = ""
    @Published var icon = "circle.fill"
    @Published var color = "blue"
    @Published var type: TransactionType = .expense
    @Published var subCategories: [SubCategory] = []

    @Published var loadingState: LoadingState = .idle
    @Published var errorMessage: String?

    // MARK: - Dependencies
    private let category: Category?
    private let categoryRepository: CategoryRepository

    var isEditing: Bool { category != nil }

    init(
        category: Category? = nil,
        categoryRepository: CategoryRepository
    ) {
        self.category = category
        self.categoryRepository = categoryRepository

        loadInitialValues()
    }

    // MARK: - Lifecycle

    private func loadInitialValues() {
        if let category = category {
            name = category.name ?? ""
            icon = category.iconName
            color = category.color ?? "blue"
            type = category.typeEnum

            if let subs = category.subCategories?.allObjects as? [SubCategory] {
                subCategories = subs.sorted { $0.order < $1.order }
            }
        }
    }

    // MARK: - Computed Properties

    var isValid: Bool {
        !name.isEmpty
    }

    // MARK: - Actions

    func saveCategory() async {
        startLoading()

        do {
            try categoryRepository.validateCategory(name: name)

            if let existingCategory = category {
                // Update
                let updateData = CategoryUpdateData(
                    name: name,
                    icon: icon,
                    color: color,
                    order: nil
                )
                try categoryRepository.updateCategory(existingCategory, with: updateData)
            } else {
                // Create
                let existingCategories = categoryRepository.fetchCategories(type: type)
                let order = existingCategories.count

                _ = try categoryRepository.createCategory(
                    name: name,
                    type: type,
                    icon: icon,
                    color: color,
                    order: order
                )
            }

            try categoryRepository.save()
            finishLoading()

        } catch {
            handleError(error)
        }
    }

    func addSubCategory(name: String, icon: String) async {
        guard let category = category else { return }

        do {
            _ = try categoryRepository.createSubCategory(name: name, icon: icon, for: category)
            try categoryRepository.save()

            // Reload
            if let subs = category.subCategories?.allObjects as? [SubCategory] {
                subCategories = subs.sorted { $0.order < $1.order }
            }
        } catch {
            handleError(error)
        }
    }

    func deleteSubCategory(_ subCategory: SubCategory) async {
        do {
            try categoryRepository.deleteSubCategory(subCategory)
            try categoryRepository.save()

            subCategories.removeAll { $0.id == subCategory.id }
        } catch {
            handleError(error)
        }
    }
}
