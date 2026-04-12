import SwiftData
import SwiftUI

/// 分类模型：记账的分类标签（如餐饮、交通等）
@Model
final class Category {
    var id: UUID
    var name: String       // 分类名称
    var icon: String       // SF Symbols 图标名
    var colorHex: String   // 图标背景颜色
    var isGlobal: Bool     // true=全局通用，false=项目专属
    var projectID: UUID?   // 若是项目专属，记录所属项目ID
    var createdAt: Date
    
    init(name: String, icon: String, colorHex: String, isGlobal: Bool = true, projectID: UUID? = nil) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.isGlobal = isGlobal
        self.projectID = projectID
        self.createdAt = Date()
    }
}

/// 项目（抽屉）模型：记账的顶级容器
@Model
final class Project {
    var id: UUID
    var name: String           // 项目名称
    var icon: String           // SF Symbols 图标名
    var colorHex: String       // 主题颜色
    var desc: String           // 项目描述
    var budget: Double         // 总预算（0表示不限预算）
    var isArchived: Bool       // true=已归档
    var isPinned: Bool         // true=常驻项目（如日常收支）
    var createdAt: Date
    
    // 关联的交易记录
    @Relationship(deleteRule: .cascade)
    var transactions: [Transaction] = []
    
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
        transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }
    
    /// 计算总收入
    var totalIncome: Double {
        transactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
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
    var id: UUID
    var amount: Double              // 金额
    var type: TransactionType       // 支出 or 收入
    var categoryName: String        // 分类名称（冗余存储，方便查询）
    var categoryIcon: String        // 分类图标
    var categoryColorHex: String    // 分类颜色
    var note: String                // 备注
    var date: Date                  // 交易日期
    var createdAt: Date
    
    // 所属项目（反向关联）
    var project: Project?
    
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
