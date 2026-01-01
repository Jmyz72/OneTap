//
//  CategoryRepository.swift
//  OneTap
//
//  Repository for Category and SubCategory entities
//

import Foundation
import CoreData
import Combine

class CategoryRepository: BaseRepository {
    typealias Entity = Category

    let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - Publishers

    func categoriesPublisher(type: TransactionType?) -> AnyPublisher<[Category], Error> {
        let subject = PassthroughSubject<[Category], Error>()

        // Observe Core Data changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: context)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let categories = self.fetchCategories(type: type)
                subject.send(categories)
            }
            .store(in: &cancellables)

        // Send initial value
        let categories = fetchCategories(type: type)
        subject.send(categories)

        return subject.eraseToAnyPublisher()
    }

    // MARK: - Category CRUD

    func createCategory(
        name: String,
        type: TransactionType,
        icon: String,
        color: String,
        order: Int
    ) throws -> Category {
        let category = Category(context: context)
        category.id = UUID()
        category.name = name
        category.type = type.rawValue
        category.icon = icon
        category.color = color
        category.order = Int16(order)

        return category
    }

    func updateCategory(_ category: Category, with data: CategoryUpdateData) throws {
        if let name = data.name {
            category.name = name
        }
        if let icon = data.icon {
            category.icon = icon
        }
        if let color = data.color {
            category.color = color
        }
        if let order = data.order {
            category.order = Int16(order)
        }
    }

    func deleteCategory(_ category: Category) throws {
        // Core Data cascade rules will handle subcategory deletion
        context.delete(category)
    }

    // MARK: - SubCategory CRUD

    func createSubCategory(
        name: String,
        icon: String,
        for category: Category
    ) throws -> SubCategory {
        let subCategory = SubCategory(context: context)
        subCategory.id = UUID()
        subCategory.name = name
        subCategory.icon = icon
        subCategory.category = category

        // Set order as last in the category
        let existingCount = (category.subCategories?.count ?? 0)
        subCategory.order = Int16(existingCount)

        return subCategory
    }

    func deleteSubCategory(_ subCategory: SubCategory) throws {
        context.delete(subCategory)
    }

    // MARK: - Queries

    func fetchCategories(type: TransactionType?) -> [Category] {
        let request = NSFetchRequest<Category>(entityName: "Category")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Category.order, ascending: true)]

        if let type = type {
            request.predicate = NSPredicate(format: "type == %@", type.rawValue)
        }

        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching categories: \(error)")
            return []
        }
    }

    // MARK: - Validation

    func validateCategory(name: String) throws {
        guard !name.isEmpty else {
            throw ValidationError.invalidCategoryName
        }
    }

    // MARK: - Ordering

    func reorderCategories(_ categories: [Category]) throws {
        for (index, category) in categories.enumerated() {
            category.order = Int16(index)
        }
    }

    func reorderSubCategories(_ subCategories: [SubCategory], in category: Category) throws {
        for (index, subCategory) in subCategories.enumerated() {
            subCategory.order = Int16(index)
        }
    }

    // MARK: - Seeding

    func seedDefaultCategories() throws {
        // Check if categories already exist
        let existingCount = try context.count(for: NSFetchRequest<Category>(entityName: "Category"))
        guard existingCount == 0 else { return }

        // Use the existing seeding logic from CategoryModel
        Category.seedDefaults(context: context)
        try save()
    }
}
