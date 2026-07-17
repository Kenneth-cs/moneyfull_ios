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
    
    // V7 新增字段：是否为直接成本（用于经营看板成本分类）
    var isDirectCost: Bool = true // true = 直接成本，false = 个人生活成本
    
    init(name: String, icon: String, colorHex: String, isGlobal: Bool = true,
         transactionType: String = "both", projectID: UUID? = nil, groupName: String = "", incomeGroupName: String = "",
         isDirectCost: Bool = true) {
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
        self.isDirectCost = isDirectCost
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
    var isActiveProject: Bool = false
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    
    @Relationship(deleteRule: .nullify, inverse: \Transaction.project)
    var transactions: [Transaction]?

    // MARK: - V6 新增字段（预算分类系统 + 经营看板）
    var projectMode: String = "lifestyle"       // "earning" | "lifestyle"
    var budgetCycle: String = "project"         // "project" | "monthly" | "custom"
    var budgetCycleStartDate: Date? = nil
    var budgetCycleDays: Int = 30
    var budgetAlertThreshold: Double = 0        // 总预算预警线（Pro）
    var budgetAlertStep: Double = 0.05          // 预警步进（默认5%，Pro）
    var defaultRate: Double = 0                 // 默认时薪（记工时时使用，可选功能）
    var defaultRateGranularity: String = "hour" // "hour" | "day"
    var targetIncome: Double = 0                // 目标收入 / 合同金额
    var workingDays: Int = 0                    // 实际工作天数（0 = 自动用自然天数）

    @Relationship(deleteRule: .cascade, inverse: \BudgetItem.project)
    var budgetItems: [BudgetItem]?

    @Relationship(deleteRule: .cascade, inverse: \TimeEntry.project)
    var timeEntries: [TimeEntry]?
    
    // V7 新增字段（经营看板完整版）
    var taxRate: Double = 0                     // 税率（如 0.2 表示 20%）
    
    @Relationship(deleteRule: .cascade, inverse: \Receivable.project)
    var receivables: [Receivable]?
    
    @Relationship(deleteRule: .cascade, inverse: \FixedCost.project)
    var fixedCosts: [FixedCost]?
    
    init(name: String, icon: String = "folder.fill", colorHex: String = "#A8E6CF",
         desc: String = "", budget: Double = 0, isPinned: Bool = false, isActiveProject: Bool = false,
         projectMode: String = "lifestyle", budgetCycle: String = "project",
         targetIncome: Double = 0, defaultRate: Double = 0) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.desc = desc
        self.budget = budget
        self.isArchived = false
        self.isPinned = isPinned
        self.isActiveProject = isActiveProject
        self.createdAt = Date()
        self.projectMode = projectMode
        self.budgetCycle = budgetCycle
        self.targetIncome = targetIncome
        self.defaultRate = defaultRate
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

    // MARK: - 预算分类相关计算属性

    /// 已分配预算总额
    var budgetItemsAllocated: Double {
        (budgetItems ?? []).reduce(0) { $0 + $1.amount }
    }

    /// 未分配预算
    var budgetUnallocated: Double {
        budget - budgetItemsAllocated
    }

    /// 当前周期起始日期
    var currentCycleStartDate: Date {
        let calendar = Calendar.current
        switch budgetCycle {
        case "project":
            return createdAt
        case "monthly":
            return calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? createdAt
        case "custom":
            guard let startDate = budgetCycleStartDate else { return createdAt }
            let days = calendar.dateComponents([.day], from: startDate, to: Date()).day ?? 0
            let cycleLength = max(budgetCycleDays, 1)
            let completedCycles = days / cycleLength
            return calendar.date(byAdding: .day, value: completedCycles * cycleLength, to: startDate) ?? startDate
        default:
            return createdAt
        }
    }

    /// 当前周期已花费
    var currentCycleSpent: Double {
        let startDate = currentCycleStartDate
        return (transactions ?? [])
            .filter { $0.type == .expense && $0.date >= startDate }
            .reduce(0) { $0 + abs($1.amount) }
    }

    // MARK: - 搞钱模式核心计算属性（日均体系）

    /// 净利润 = 总收入 - 总支出（不含时间成本，时间成本为可选增强）
    var netProfit: Double {
        totalIncome - totalSpent
    }

    /// ROI = 净利润 / 总支出（衡量资金回报，无支出时为 0）
    var roi: Double {
        guard totalSpent > 0 else { return 0 }
        return (netProfit / totalSpent) * 100
    }

    /// 有效工作天数（0 = 使用自然天数）
    var effectiveWorkingDays: Int {
        if workingDays > 0 { return workingDays }
        let days = Calendar.current.dateComponents([.day], from: createdAt, to: Date()).day ?? 0
        return max(1, days)
    }

    /// 日均成本
    var dailyCost: Double {
        Double(totalSpent) / Double(effectiveWorkingDays)
    }

    /// 日均收益（有收入时才有意义）
    var dailyProfit: Double {
        Double(netProfit) / Double(effectiveWorkingDays)
    }

    // MARK: - 搞钱模式可选增强（需用户主动记工时）

    /// 总时间成本（仅当有工时记录时有意义）
    var totalTimeCost: Double {
        (timeEntries ?? []).reduce(0) { $0 + $1.duration * $1.rate }
    }

    /// 总成本（含时间成本，用于精确 ROI 计算）
    var totalCost: Double {
        totalTimeCost + totalSpent
    }

    /// 总工时（统一折算为小时当量，工日 × 8）
    var totalHourEquivalent: Double {
        (timeEntries ?? []).reduce(0) {
            $0 + ($1.granularity == "day" ? $1.duration * 8 : $1.duration)
        }
    }

    /// 真实时薪 = (收入 - 支出) ÷ 工时（不含时间成本）
    var effectiveHourlyRate: Double {
        guard totalHourEquivalent > 0 else { return 0 }
        return (totalIncome - totalSpent) / totalHourEquivalent
    }

    /// 是否有工时记录
    var hasTimeEntries: Bool {
        !(timeEntries ?? []).isEmpty
    }

    // MARK: - 生活模式计算属性

    /// 项目持续天数（从创建到今天）
    var totalDays: Int {
        let days = Calendar.current.dateComponents([.day], from: createdAt, to: Date()).day ?? 0
        return max(1, days)
    }

    /// 日均花费
    var dailyAvgSpend: Double {
        guard totalDays > 0 else { return 0 }
        return totalSpent / Double(totalDays)
    }
    
    // MARK: - 经营看板计算属性（V7）
    
    // ============ 现金流维度 ============
    
    /// 累计可用资金 = 累计收入 - 累计支出
    var availableCash: Double {
        totalIncome - totalSpent
    }
    
    /// 本月净现金流 = 当月收入 - 当月支出
    var monthlyNetCashFlow: Double {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let monthTransactions = (transactions ?? []).filter { $0.date >= startOfMonth }
        let monthIncome = monthTransactions.filter { $0.type == .income }.reduce(0) { $0 + abs($1.amount) }
        let monthExpense = monthTransactions.filter { $0.type == .expense }.reduce(0) { $0 + abs($1.amount) }
        return monthIncome - monthExpense
    }
    
    /// 经营现金流（本月经营支出）
    var operatingCashFlow: Double {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        return (transactions ?? [])
            .filter { $0.date >= startOfMonth && $0.type == .expense && $0.cashFlowType == "operating" }
            .reduce(0) { $0 + abs($1.amount) }
    }
    
    /// 个人现金流（本月个人支出）
    var personalCashFlow: Double {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        return (transactions ?? [])
            .filter { $0.date >= startOfMonth && $0.type == .expense && $0.cashFlowType == "personal" }
            .reduce(0) { $0 + abs($1.amount) }
    }
    
    /// 未来30天刚性支出（固定成本）
    var upcomingFixedCosts: Double {
        let now = Date()
        let thirtyDaysLater = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now
        return (fixedCosts ?? [])
            .filter { $0.isActive }
            .filter { cost in
                guard let dueDate = cost.nextDueDate else { return false }
                return dueDate >= now && dueDate <= thirtyDaysLater
            }
            .reduce(0) { $0 + $1.monthlyAmount }
    }
    
    // ============ 收入维度 ============
    
    /// 待回款总额
    var totalReceivable: Double {
        (receivables ?? []).filter { $0.status == .pending }.reduce(0) { $0 + $1.amount }
    }
    
    /// 逾期未回款金额
    var overdueReceivable: Double {
        (receivables ?? []).filter { $0.isOverdue }.reduce(0) { $0 + $1.amount }
    }
    
    /// 逾期比例
    var overdueRatio: Double {
        guard totalReceivable > 0 else { return 0 }
        return overdueReceivable / totalReceivable
    }
    
    /// 按业务线（分类）聚合收入占比
    var incomeByCategory: [(categoryName: String, amount: Double, percentage: Double)] {
        let incomeTransactions = (transactions ?? []).filter { $0.type == .income }
        let totalIncomeAmount = incomeTransactions.reduce(0) { $0 + abs($1.amount) }
        guard totalIncomeAmount > 0 else { return [] }
        
        var categoryMap: [String: Double] = [:]
        for t in incomeTransactions {
            categoryMap[t.categoryName, default: 0] += abs(t.amount)
        }
        
        return categoryMap.map { key, value in
            (categoryName: key, amount: value, percentage: value / totalIncomeAmount)
        }.sorted { $0.amount > $1.amount }
    }
    
    // ============ 成本维度 ============
    
    /// 直接成本（本月，按分类的 isDirectCost 判断）
    var directCost: Double {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        // 暂时按现金流量类型为经营支出来近似直接成本
        return (transactions ?? [])
            .filter { $0.date >= startOfMonth && $0.type == .expense && $0.cashFlowType == "operating" }
            .reduce(0) { $0 + abs($1.amount) }
    }
    
    /// 固定经营成本（月度，按频率折算）
    var fixedCostMonthly: Double {
        (fixedCosts ?? []).filter { $0.isActive }.reduce(0) { $0 + $1.monthlyAmount }
    }
    
    /// 个人生活成本（本月）
    var personalCost: Double {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        return (transactions ?? [])
            .filter { $0.date >= startOfMonth && $0.type == .expense && $0.cashFlowType == "personal" }
            .reduce(0) { $0 + abs($1.amount) }
    }
    
    // ============ 利润维度 ============
    
    /// 本月已到账收入
    var monthlyIncome: Double {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        return (transactions ?? [])
            .filter { $0.date >= startOfMonth && $0.type == .income }
            .reduce(0) { $0 + abs($1.amount) }
    }
    
    /// 毛利 = 已到账收入 - 直接成本
    var grossProfit: Double {
        monthlyIncome - directCost
    }
    
    /// 毛利率
    var grossMargin: Double {
        guard monthlyIncome > 0 else { return 0 }
        return grossProfit / monthlyIncome
    }
    
    /// 经营净利润 = 毛利 - 固定经营成本
    var operatingNetProfit: Double {
        grossProfit - fixedCostMonthly
    }
    
    /// 税费预留
    var taxReserve: Double {
        operatingNetProfit * taxRate
    }
    
    /// 可支配收入 = 经营净利润 - 个人生活成本 - 税费预留
    var disposableIncome: Double {
        operatingNetProfit - personalCost - taxReserve
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
    
    // V7 新增字段：现金流类型（经营支出/个人支出）
    var cashFlowType: String = "operating" // "operating" | "personal"
    
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
         note: String = "", date: Date = Date(), source: TransactionSource = .manual,
         cashFlowType: String = "operating") {
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
        self.cashFlowType = cashFlowType
    }
}

/// 聊天历史模型
@Model
final class ChatHistory {
    var id: UUID = UUID()
    var role: String = "user" // "user" 或 "assistant"
    var content: String = ""
    var timestamp: Date = Date()
    var isPrescripted: Bool = false // true = 预制消息，不进入 API 上下文
    
    init(role: String, content: String, isPrescripted: Bool = false) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.isPrescripted = isPrescripted
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

/// 预算分类模型
@Model
final class BudgetItem {
    var id: UUID = UUID()
    var categoryName: String = ""
    var categoryIcon: String = ""
    var categoryColorHex: String = ""
    var amount: Double = 0
    var sortOrder: Int = 0
    var alertThreshold: Double = 0   // 0 = 不预警；0.8 = 80% 提醒（Pro）
    var createdAt: Date = Date()

    var project: Project?

    init(categoryName: String, categoryIcon: String, categoryColorHex: String,
         amount: Double, sortOrder: Int = 0, alertThreshold: Double = 0) {
        self.id = UUID()
        self.categoryName = categoryName
        self.categoryIcon = categoryIcon
        self.categoryColorHex = categoryColorHex
        self.amount = amount
        self.sortOrder = sortOrder
        self.alertThreshold = alertThreshold
        self.createdAt = Date()
    }
}

/// 工时记录模型
@Model
final class TimeEntry {
    var id: UUID = UUID()
    var duration: Double = 0            // 工时数量（小时 or 天）
    var granularity: String = "hour"    // "hour" | "day"
    var rate: Double = 0                // 时薪（hour）或日薪（day）
    var note: String = ""               // 任务描述
    var date: Date = Date()
    var createdAt: Date = Date()

    var project: Project?

    /// 时间成本
    var cost: Double { duration * rate }

    init(duration: Double, granularity: String = "hour", rate: Double,
         note: String = "", date: Date = Date()) {
        self.id = UUID()
        self.duration = duration
        self.granularity = granularity
        self.rate = rate
        self.note = note
        self.date = date
        self.createdAt = Date()
    }
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

/// 应收账款状态枚举
enum ReceivableStatus: String, Codable {
    case pending = "pending"     // 待回款
    case overdue = "overdue"     // 逾期
    case received = "received"   // 已到账
}

/// 应收账款模型
@Model
final class Receivable {
    var id: UUID = UUID()
    var clientName: String = ""
    var projectName: String = ""
    var amount: Double = 0
    var expectedDate: Date? = nil
    var rawStatus: String = ReceivableStatus.pending.rawValue
    var receivedDate: Date? = nil
    var note: String = ""
    var createdAt: Date = Date()
    
    var project: Project? = nil
    
    @Transient
    var status: ReceivableStatus {
        get { ReceivableStatus(rawValue: rawStatus) ?? .pending }
        set { rawStatus = newValue.rawValue }
    }
    
    /// 是否逾期（系统自动判断）
    var isOverdue: Bool {
        guard let expected = expectedDate else { return false }
        return expected < Date() && status == .pending
    }
    
    init(clientName: String, projectName: String, amount: Double,
         expectedDate: Date? = nil, note: String = "") {
        self.id = UUID()
        self.clientName = clientName
        self.projectName = projectName
        self.amount = amount
        self.expectedDate = expectedDate
        self.rawStatus = ReceivableStatus.pending.rawValue
        self.note = note
        self.createdAt = Date()
    }
}

/// 固定成本频率枚举
enum FixedCostFrequency: String, Codable {
    case monthly = "monthly"
    case quarterly = "quarterly"
    case yearly = "yearly"
}

/// 固定成本模型
@Model
final class FixedCost {
    var id: UUID = UUID()
    var name: String = ""
    var amount: Double = 0
    var rawFrequency: String = FixedCostFrequency.monthly.rawValue
    var category: String = ""
    var nextDueDate: Date? = nil
    var isActive: Bool = true
    var createdAt: Date = Date()
    
    var project: Project? = nil
    
    @Transient
    var frequency: FixedCostFrequency {
        get { FixedCostFrequency(rawValue: rawFrequency) ?? .monthly }
        set { rawFrequency = newValue.rawValue }
    }
    
    /// 月度成本（按频率折算）
    var monthlyAmount: Double {
        switch frequency {
        case .monthly:
            return amount
        case .quarterly:
            return amount / 3.0
        case .yearly:
            return amount / 12.0
        }
    }
    
    init(name: String, amount: Double, frequency: FixedCostFrequency = .monthly,
         category: String = "", nextDueDate: Date? = nil) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.rawFrequency = frequency.rawValue
        self.category = category
        self.nextDueDate = nextDueDate
        self.isActive = true
        self.createdAt = Date()
    }
}

/// 复盘缓存模型：持久化 AI 复盘结果，避免重复调用 LLM
@Model
final class ProjectReviewCache {
    var id: UUID = UUID()
    var projectID: UUID = UUID()
    var resultJSON: String = ""
    var createdAt: Date = Date()
    var dataHash: String = ""
    var dailyUsageDate: Date = Date()

    init(projectID: UUID, resultJSON: String, dataHash: String) {
        self.id = UUID()
        self.projectID = projectID
        self.resultJSON = resultJSON
        self.createdAt = Date()
        self.dataHash = dataHash
        self.dailyUsageDate = Date()
    }
}
