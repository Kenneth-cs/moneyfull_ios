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
    
    // V4 新增字段
    var groupName: String = "" // 主要所属一级分类名称（如：吃喝、居家）
    var incomeGroupName: String = "" // 收入时的分类名称（如：额外、工资），如果不填则退回使用 groupName
    var sortOrder: Int = 0 // 同组内排序
    var useCount: Int = 0 // 使用次数（用于常用列表）
    var lastUsedAt: Date? = nil // 最后使用时间
    
    init(name: String, icon: String, colorHex: String, isGlobal: Bool = true,
         transactionType: String = "both", projectID: UUID? = nil, groupName: String = "", incomeGroupName: String = "") {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.isGlobal = isGlobal
        self.transactionType = transactionType
        self.projectID = projectID
        self.groupName = groupName
        self.incomeGroupName = incomeGroupName
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
    var sortOrder: Int = 0
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
        (transactions ?? []).filter { $0.type == .expense }.reduce(0) { $0 + abs($1.amount) }
    }
    
    /// 计算总收入
    var totalIncome: Double {
        (transactions ?? []).filter { $0.type == .income }.reduce(0) { $0 + abs($1.amount) }
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

/// 交易来源枚举
enum TransactionSource: String, Codable {
    case manual = "manual"     // 手动记账
    case voice  = "voice"      // 语音记账
    case image  = "image"      // 图片记账
    case auto   = "auto"       // 自动记账
}

/// 账单（流水）模型：每一笔具体的收支记录
@Model
final class Transaction {
    var id: UUID = UUID()
    var amount: Double = 0
    var rawType: String = TransactionType.expense.rawValue // CloudKit 不支持枚举，必须用基础类型存储
    var rawSource: String = TransactionSource.manual.rawValue // 记录来源
    var categoryName: String = ""
    var categoryIcon: String = ""
    var categoryColorHex: String = "#A8E6CF"
    var note: String = ""
    var date: Date = Date()
    var createdAt: Date = Date()
    var importBatchID: UUID? = nil // 导入批次标识，用于撤销整批导入
    
    var project: Project? = nil
    
    // 提供一个计算属性方便业务层使用枚举
    @Transient
    var type: TransactionType {
        get { TransactionType(rawValue: rawType) ?? .expense }
        set { rawType = newValue.rawValue }
    }
    
    // 提供一个计算属性方便业务层使用枚举
    @Transient
    var source: TransactionSource {
        get { TransactionSource(rawValue: rawSource) ?? .manual }
        set { rawSource = newValue.rawValue }
    }
    
    init(amount: Double, type: TransactionType, categoryName: String,
         categoryIcon: String, categoryColorHex: String,
         note: String = "", date: Date = Date(), source: TransactionSource = .manual) {
        self.id = UUID()
        self.amount = amount
        self.rawType = type.rawValue
        self.rawSource = source.rawValue
        self.categoryName = categoryName
        self.categoryIcon = categoryIcon
        self.categoryColorHex = categoryColorHex
        self.note = note
        self.date = date
        self.createdAt = Date()
    }
}

/// 聊天历史模型
@Model
final class ChatHistory {
    var id: UUID = UUID()
    var role: String = "user" // "user" 或 "assistant"
    var content: String = ""
    var timestamp: Date = Date()
    
    init(role: String, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

/// 记忆规则模型
@Model
final class MemoryRule {
    var id: UUID = UUID()
    var keyword: String = ""
    var targetCategoryName: String = ""
    var targetProjectName: String = ""
    var weight: Int = 1
    var createdAt: Date = Date()
    
    init(keyword: String, targetCategoryName: String, targetProjectName: String, weight: Int = 1) {
        self.id = UUID()
        self.keyword = keyword
        self.targetCategoryName = targetCategoryName
        self.targetProjectName = targetProjectName
        self.weight = weight
        self.createdAt = Date()
    }
}

/// 周期频率枚举
enum RecurringFrequency: String, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"
}

/// 周期账单模型
@Model
final class RecurringBill {
    var id: UUID = UUID()
    var name: String = ""
    var amount: Double = 0
    var rawType: String = TransactionType.expense.rawValue
    var categoryName: String = ""
    var categoryIcon: String = ""
    var categoryColorHex: String = "#A8E6CF"
    var projectID: UUID? = nil
    var rawFrequency: String = RecurringFrequency.monthly.rawValue
    var nextDueDate: Date = Date()
    var isAutoRecord: Bool = true
    var isActive: Bool = true
    var note: String = ""
    var createdAt: Date = Date()
    var lastRecordedAt: Date? = nil
    
    @Transient
    var type: TransactionType {
        get { TransactionType(rawValue: rawType) ?? .expense }
        set { rawType = newValue.rawValue }
    }
    
    @Transient
    var frequency: RecurringFrequency {
        get { RecurringFrequency(rawValue: rawFrequency) ?? .monthly }
        set { rawFrequency = newValue.rawValue }
    }
    
    init(name: String, amount: Double, type: TransactionType, categoryName: String,
         categoryIcon: String, categoryColorHex: String, projectID: UUID? = nil,
         frequency: RecurringFrequency = .monthly, nextDueDate: Date = Date(),
         isAutoRecord: Bool = true, note: String = "") {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.rawType = type.rawValue
        self.categoryName = categoryName
        self.categoryIcon = categoryIcon
        self.categoryColorHex = categoryColorHex
        self.projectID = projectID
        self.rawFrequency = frequency.rawValue
        self.nextDueDate = nextDueDate
        self.isAutoRecord = isAutoRecord
        self.note = note
        self.createdAt = Date()
    }
    
    func calculateNextDueDate() -> Date {
        let calendar = Calendar.current
        switch frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: nextDueDate) ?? nextDueDate
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: nextDueDate) ?? nextDueDate
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: nextDueDate) ?? nextDueDate
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: nextDueDate) ?? nextDueDate
        }
    }
}
