import Foundation

struct BudgetCreateData {
    let amount: Double
    let categoryID: UUID
    let startDate: Date
    let endDate: Date
}

struct BudgetUpdateData {
    let amount: Double?
    let spent: Double?
    let startDate: Date?
    let endDate: Date?
}
