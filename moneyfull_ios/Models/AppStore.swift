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
    
    /// 首次启动时插入示例数据，方便演示
    private func setupDefaultDataIfNeeded() {
        let descriptor = FetchDescriptor<Project>()
        let count = (try? modelContext.fetch(descriptor).count) ?? 0
        guard count == 0 else { return }
        
        // 默认创建「日常收支」常驻项目
        let daily = Project(name: "日常收支", icon: "house.fill", colorHex: "#A8E6CF",
                            desc: "日常吃喝玩乐的流水账，真实反映基础生活成本。", isPinned: true)
        modelContext.insert(daily)
        
        // 海景房装修
        let renovation = Project(name: "海景房装修", icon: "hammer.fill", colorHex: "#DCEDC1",
                                 desc: "温馨自然的北欧风格，注重采光与海景视野的最大化。", budget: 100000)
        modelContext.insert(renovation)
        
        // 品牌重塑项目
        let branding = Project(name: "品牌重塑项目", icon: "paintpalette.fill", colorHex: "#FDD1B4",
                               desc: "为本地精品咖啡馆设计的全新视觉系统。", budget: 10000)
        modelContext.insert(branding)
        
        // 插入一些示例账单
        let sampleData: [(Project, Double, TransactionType, String, String, String, Int)] = [
            (daily,      458, .expense, "海鲜餐厅",  "fork.knife",      "#FDD1B4", -0),
            (daily,      120, .expense, "设计素材",  "pencil.tip",      "#A8E6CF", -1),
            (daily,      100, .expense, "交通充值",  "tram.fill",       "#DCDE8D", -1),
            (renovation, 75000, .expense, "装修款",  "hammer.fill",     "#DCEDC1", -10),
            (branding,   3200, .expense, "设计支出", "paintpalette.fill","#FDD1B4", -5),
            (branding,   5000, .income,  "项目结款", "briefcase.fill",  "#A8E6CF", -3),
        ]
        
        for (proj, amount, type, name, icon, color, dayOffset) in sampleData {
            let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: Date())!
            let tx = Transaction(amount: amount, type: type, categoryName: name,
                                 categoryIcon: icon, categoryColorHex: color, date: date)
            tx.project = proj
            proj.transactions.append(tx)
            modelContext.insert(tx)
        }
        
        try? modelContext.save()
    }
}
