import Foundation
import SwiftData

// --- PRIORITIES ---
enum Priority: String, Codable, CaseIterable, Identifiable {
    case essential = "essential"
    case neededNow = "neededNow"
    case want = "want"
    
    var id: String { self.rawValue }
    
    // UI Titles remain in Ukrainian for the interface
    var title: String {
        switch self {
        case .essential: return "Життєво необхідно"
        case .neededNow: return "Потрібно зараз"
        case .want: return "Хотілка"
        }
    }
    
    var shortTitle: String {
        switch self {
        case .essential: return "Важливо"
        case .neededNow: return "Потрібно"
        case .want: return "Хотілка"
        }
    }
}

// --- CATEGORY MODEL ---
@Model
final class CategoryItem {
    var id: UUID
    var name: String
    var icon: String
    var order: Int
    var dateAdded: Date
    
    init(name: String, icon: String = "circle", order: Int = 0) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.order = order
        self.dateAdded = Date()
    }
}

// --- INCOME MODEL ---
@Model
final class IncomeItem {
    var id: UUID
    var name: String
    var amount: Double
    var isUSD: Bool
    var dateAdded: Date
    
    init(name: String, amount: Double, isUSD: Bool = false) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.isUSD = isUSD
        self.dateAdded = Date()
    }
}

// --- EXPENSE MODEL ---
@Model
final class ExpenseItem {
    var id: UUID
    var name: String
    var amount: Double
    var categoryName: String
    var dateAdded: Date
    var isUSD: Bool
    
    var priority: Priority = Priority.essential
    
    // NEW FIELD: Payment Status
    var isPaid: Bool = false
    
    var monthHistory: MonthHistory?
    
    init(name: String, amount: Double, categoryName: String, isUSD: Bool = false, priority: Priority = .essential, isPaid: Bool = false) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.categoryName = categoryName
        self.dateAdded = Date()
        self.isUSD = isUSD
        self.priority = priority
        self.isPaid = isPaid
    }
}

// --- HISTORY MODEL ---
@Model
final class MonthHistory {
    var id: UUID
    var date: Date
    
    var totalIncomeUAH: Double
    var totalExpenses: Double
    var totalSaved: Double
    var remaining: Double
    
    @Relationship(deleteRule: .cascade, inverse: \ExpenseItem.monthHistory)
    var expenses: [ExpenseItem]? = []
    
    init(totalIncomeUAH: Double, totalExpenses: Double, totalSaved: Double, remaining: Double) {
        self.id = UUID()
        self.date = Date()
        self.totalIncomeUAH = totalIncomeUAH
        self.totalExpenses = totalExpenses
        self.totalSaved = totalSaved
        self.remaining = remaining
    }
}
