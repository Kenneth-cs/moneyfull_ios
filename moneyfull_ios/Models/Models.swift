import SwiftData
import SwiftUI

/// 分类模型：记账的分类标签（如餐饮、交通等）
@Model
final class Category {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = ""
    var colorHex: String = "#A8E6CF"
    var isGlobal: Bool = true
    var transactionType: String = "both"
    var projectID: UUID? = nil
    var createdAt: Date = Date()
    
    init(name: String, icon: String, colorHex: String, isGlobal: Bool = true,
         transactionType: String = "both", projectID: UUID? = nil) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.isGlobal = isGlobal
        self.transactionType = transactionType
        self.projectID = projectID
        self.createdAt = Date()
    }
}

extension Category: Identifiable {}

/// 项目（抽屉）模型：记账的顶级容器
@Model
final class Project {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = "folder.fill"
    var colorHex: String = "#A8E6CF"
    var desc: String = ""
    var budget: Double = 0
    var isArchived: Bool = false
    var isPinned: Bool = false
    var createdAt: Date = Date()
    
    @Relationship(deleteRule: .nullify, inverse: \Transaction.project)
    var transactions: [Transaction]?
    
    init(name: String, icon: String = "folder.fill", colorHex: String = "#A8E6CF",
         desc: String = "", budget: Double = 0, isPinned: Bool = false) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.desc = desc
        self.budget = budget
        self.isArchived = false
        self.isPinned = isPinned
        self.createdAt = Date()
    }
    
    /// 计算已花费总额（支出之和）
    var totalSpent: Double {
        (transactions ?? []).filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }
    
    /// 计算总收入
    var totalIncome: Double {
        (transactions ?? []).filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }
    
    /// 预算使用进度 (0.0 ~ 1.0+，超过1表示超支)
    var budgetProgress: Double {
        guard budget > 0 else { return 0 }
        return totalSpent / budget
    }
}

/// 交易类型枚举
enum TransactionType: String, Codable {
    case expense = "expense"   // 支出
    case income  = "income"    // 收入
}

/// 账单（流水）模型：每一笔具体的收支记录
@Model
final class Transaction {
    var id: UUID = UUID()
    var amount: Double = 0
    var type: TransactionType = TransactionType.expense
    var categoryName: String = ""
    var categoryIcon: String = ""
    var categoryColorHex: String = "#A8E6CF"
    var note: String = ""
    var date: Date = Date()
    var createdAt: Date = Date()
    
    var project: Project? = nil
    
    init(amount: Double, type: TransactionType, categoryName: String,
         categoryIcon: String, categoryColorHex: String,
         note: String = "", date: Date = Date()) {
        self.id = UUID()
        self.amount = amount
        self.type = type
        self.categoryName = categoryName
        self.categoryIcon = categoryIcon
        self.categoryColorHex = categoryColorHex
        self.note = note
        self.date = date
        self.createdAt = Date()
    }
}
