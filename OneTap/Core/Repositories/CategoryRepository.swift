//
//  CategoryRepository.swift
//  OneTap
//
//  Repository for Category and SubCategory entities
//

import Foundation
@preconcurrency internal import CoreData
import Combine

class CategoryRepository: BaseRepository {
    typealias Entity = Category

    let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    deinit {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    // MARK: - Publishers

    func categoriesPublisher(type: TransactionType?) -> AnyPublisher<[Category], Error> {
        let initialCategories = fetchCategories(type: type)
        let subject = CurrentValueSubject<[Category], Error>(initialCategories)

        // Observe Core Data changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave, object: context)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let categories = self.fetchCategories(type: type)
                subject.send(categories)
            }
            .store(in: &cancellables)

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

    func deleteAllCategories() throws {
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        let categories = try context.fetch(fetchRequest)
        
        for category in categories {
            context.delete(category)
        }
        
        try save()
    }

    func resetToDefaults() throws {
        // 1. Fetch all existing (old) categories
        let oldCategoriesRequest: NSFetchRequest<Category> = Category.fetchRequest()
        let oldCategories = try context.fetch(oldCategoriesRequest)

        // 2. Seed new default categories
        // We use the model's logic but we need to capture the new objects to use them
        // So we will manually duplicate the seed logic here to get the references,
        // or fetch them immediately after seeding.
        Category.seedDefaults(context: context)
        try context.save()
        
        // 3. Fetch the NEW categories we just created
        // We can identify them because they are not in the 'oldCategories' list
        // (Actually, checking ID is safer, but newly inserted objects have temporary IDs until save.
        // A safer way is to fetch all and filter out the old ones).
        
        // Let's just fetch all categories.
        let allCategories = fetchCategories(type: nil) // fetch logic is sorting by order
        let newCategories = allCategories.filter { newCat in
            !oldCategories.contains(where: { $0.objectID == newCat.objectID })
        }
        
        // 4. Fetch all Transactions
        let transactionRequest: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        let transactions = try context.fetch(transactionRequest)
        
        // 5. Reassign Transactions
        for transaction in transactions {
            guard let oldCat = transaction.category else { continue }
            
            // Try to find a new category with the same name and type
            if let match = newCategories.first(where: { 
                $0.name == oldCat.name && $0.type == oldCat.type 
            }) {
                transaction.category = match
            } else {
                // Fallback to "Others" of the same type
                if let others = newCategories.first(where: { 
                    ($0.name == "Others" || $0.name == "Other") && $0.type == oldCat.type 
                }) {
                    transaction.category = others
                } else {
                    // Last resort: just pick the first one of same type
                    if let anyMatch = newCategories.first(where: { $0.type == oldCat.type }) {
                        transaction.category = anyMatch
                    }
                }
            }
        }
        
        // 6. Delete OLD categories
        for category in oldCategories {
            context.delete(category)
        }

        try save()
    }
}
