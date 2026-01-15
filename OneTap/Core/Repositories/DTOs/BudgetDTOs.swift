import Foundation

struct BudgetCreateData {
    let amount: Double
    let categoryID: UUID
    let subCategoryID: UUID?  // nil = category-level budget
}

struct BudgetUpdateData {
    let amount: Double?
    let isActive: Bool?
}
