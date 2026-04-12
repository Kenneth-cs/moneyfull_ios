import SwiftData
import SwiftUI

/// 全局状态管理：负责所有数据的增删查改，注入到 View 层使用
@MainActor
class AppStore: ObservableObject {
    private let modelContext: ModelContext
    
    /// 所有进行中项目
    @Published var activeProjects: [Project] = []
    /// 所有已归档项目
    @Published var archivedProjects: [Project] = []
    /// 最近交易（全局，按时间倒序，最多50条）
    @Published var recentTransactions: [Transaction] = []
    
    // 本月汇总数据
    @Published var monthlyExpense: Double = 0
    @Published var monthlyIncome: Double = 0
    @Published var monthlySaving: Double = 0
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        setupDefaultDataIfNeeded()
        refresh()
    }
    
    // MARK: - 读取数据
    
    func refresh() {
        fetchProjects()
        fetchRecentTransactions()
        calcMonthlyStats()
    }
    
    private func fetchProjects() {
        var descriptor = FetchDescriptor<Project>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        activeProjects = all
            .filter { !$0.isArchived }
            .sorted { ($0.isPinned ? 1 : 0) > ($1.isPinned ? 1 : 0) }
        archivedProjects = all
            .filter { $0.isArchived }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    private func fetchRecentTransactions() {
        var descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 50
        recentTransactions = (try? modelContext.fetch(descriptor)) ?? []
    }
    
    private func calcMonthlyStats() {
        let now = Date()
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        
        var descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.date >= startOfMonth }
        )
        let monthlyTx = (try? modelContext.fetch(descriptor)) ?? []
        
        monthlyExpense = monthlyTx.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
        monthlyIncome = monthlyTx.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        monthlySaving = monthlyIncome - monthlyExpense
    }
    
    // MARK: - 新增数据
    
    /// 添加一笔账单到指定项目
    func addTransaction(to project: Project, amount: Double, type: TransactionType,
                        categoryName: String, categoryIcon: String, categoryColorHex: String,
                        note: String = "", date: Date = Date()) {
        let tx = Transaction(amount: amount, type: type, categoryName: categoryName,
                             categoryIcon: categoryIcon, categoryColorHex: categoryColorHex,
                             note: note, date: date)
        tx.project = project
        project.transactions.append(tx)
        modelContext.insert(tx)
        save()
        refresh()
    }
    
    /// 新建项目
    @discardableResult
    func addProject(name: String, icon: String, colorHex: String,
                    desc: String, budget: Double, isPinned: Bool = false) -> Project {
        let project = Project(name: name, icon: icon, colorHex: colorHex,
                              desc: desc, budget: budget, isPinned: isPinned)
        modelContext.insert(project)
        save()
        refresh()
        return project
    }
    
    // MARK: - 修改数据
    
    /// 归档 / 取消归档项目
    func toggleArchive(project: Project) {
        project.isArchived.toggle()
        save()
        refresh()
    }
    
    // MARK: - 删除数据
    
    func deleteTransaction(_ tx: Transaction) {
        modelContext.delete(tx)
        save()
        refresh()
    }
    
    func deleteProject(_ project: Project) {
        modelContext.delete(project)
        save()
        refresh()
    }
    
    // MARK: - 私有工具
    
    private func save() {
        try? modelContext.save()
    }
    
    /// 首次启动时创建默认「日常收支」项目，作为用户的起点
    /// 不插入任何示例账单，让用户从干净状态开始
    private func setupDefaultDataIfNeeded() {
        let descriptor = FetchDescriptor<Project>()
        let count = (try? modelContext.fetch(descriptor).count) ?? 0
        guard count == 0 else { return }
        
        // 只创建「日常收支」常驻项目，让用户从这里开始记录
        let daily = Project(
            name: "日常收支",
            icon: "house.fill",
            colorHex: "#A8E6CF",
            desc: "日常吃喝玩乐的流水账，真实反映基础生活成本。",
            isPinned: true
        )
        modelContext.insert(daily)
        try? modelContext.save()
    }
}
