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
    /// 所有分类（系统预设 + 自定义）
    @Published var categories: [Category] = []
    
    // 本月汇总数据
    @Published var monthlyExpense: Double = 0
    @Published var monthlyIncome: Double = 0
    @Published var monthlySaving: Double = 0
    
    // 备份状态
    @Published var lastBackupDate: Date? {
        didSet {
            if let date = lastBackupDate {
                UserDefaults.standard.set(date.timeIntervalSince1970, forKey: "lastBackupTimestamp")
            }
        }
    }
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        let ts = UserDefaults.standard.double(forKey: "lastBackupTimestamp")
        if ts > 0 {
            self.lastBackupDate = Date(timeIntervalSince1970: ts)
        }
        setupDefaultDataIfNeeded()
        migrateMorandiColors()
        migrateV3Categories()
        refresh()
    }
    
    // MARK: - 读取数据
    
    func refresh() {
        fetchProjects()
        fetchRecentTransactions()
        fetchCategories()
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
    
    private func fetchCategories() {
        let descriptor = FetchDescriptor<Category>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        categories = (try? modelContext.fetch(descriptor)) ?? []
    }
    
    private func calcMonthlyStats() {
        let now = Date()
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        
        let descriptor = FetchDescriptor<Transaction>(
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
        project.transactions = (project.transactions ?? []) + [tx]
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
    
    /// 更新交易记录
    func updateTransaction(_ tx: Transaction, amount: Double, type: TransactionType,
                           categoryName: String, categoryIcon: String, categoryColorHex: String,
                           note: String, date: Date) {
        tx.amount = amount
        tx.type = type
        tx.categoryName = categoryName
        tx.categoryIcon = categoryIcon
        tx.categoryColorHex = categoryColorHex
        tx.note = note
        tx.date = date
        save()
        refresh()
    }
    
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
        for tx in project.transactions ?? [] {
            modelContext.delete(tx)
        }
        modelContext.delete(project)
        save()
        refresh()
    }
    
    func updateProjectColor(_ project: Project, colorHex: String) {
        project.colorHex = colorHex
        save()
        refresh()
    }
    
    // MARK: - 分类管理
    
    func addCategory(name: String, icon: String, colorHex: String) {
        let category = Category(name: name, icon: icon, colorHex: colorHex, isGlobal: false)
        modelContext.insert(category)
        save()
        refresh()
    }
    
    func deleteCategory(_ category: Category) {
        modelContext.delete(category)
        save()
        refresh()
    }

    func updateCategory(_ category: Category, name: String, icon: String, colorHex: String) {
        category.name = name
        category.icon = icon
        category.colorHex = colorHex
        save()
        refresh()
    }
    
    // MARK: - 备份
    
    func triggerBackup() {
        save()
        lastBackupDate = Date()
    }
    
    func dataStats() -> (projectCount: Int, transactionCount: Int, categoryCount: Int) {
        let projectCount = (try? modelContext.fetch(FetchDescriptor<Project>()).count) ?? 0
        let txCount = (try? modelContext.fetch(FetchDescriptor<Transaction>()).count) ?? 0
        let catCount = (try? modelContext.fetch(FetchDescriptor<Category>()).count) ?? 0
        return (projectCount, txCount, catCount)
    }
    
    // MARK: - 私有工具
    
    private func save() {
        try? modelContext.save()
    }
    
    /// 首次启动时创建默认「日常收支」项目和系统预设分类
    private func setupDefaultDataIfNeeded() {
        let descriptor = FetchDescriptor<Project>()
        let count = (try? modelContext.fetch(descriptor).count) ?? 0
        guard count == 0 else {
            seedDefaultCategoriesIfNeeded()
            return
        }
        
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
        
        seedDefaultCategoriesIfNeeded()
    }
    
    private func seedDefaultCategoriesIfNeeded() {
        let catCount = (try? modelContext.fetch(FetchDescriptor<Category>()).count) ?? 0
        guard catCount == 0 else { return }
        
        let defaults: [(String, String, String, String)] = [
            ("餐饮", "fork.knife",                           "#F6D7A8", "expense"),
            ("购物", "bag.fill",                             "#F2B7C6", "expense"),
            ("交通", "tram.fill",                            "#B3D1E6", "expense"),
            ("水果", "leaf.fill",                            "#A8E0C2", "expense"),
            ("学习", "book.closed.fill",                     "#C8E6C9", "expense"),
            ("其它", "ellipsis.circle.fill",                 "#DCCFC4", "both"),
            ("日用", "basket.fill",                          "#DCCFC4", "expense"),
            ("蔬菜", "leaf.circle.fill",                     "#A8E0C2", "expense"),
            ("饮品", "cup.and.saucer.fill",                  "#F6D7A8", "expense"),
            ("零食", "popcorn.fill",                         "#F2B7C6", "expense"),
            ("服饰", "tshirt.fill",                          "#D8C6E8", "expense"),
            ("外卖", "takeoutbag.and.cup.and.straw.fill",    "#F6D7A8", "expense"),
            ("买菜", "cart.fill",                            "#A8E0C2", "expense"),
            ("运动", "figure.run",                           "#BFE6EA", "expense"),
            ("娱乐", "gamecontroller.fill",                  "#D8C6E8", "expense"),
            ("话费", "phone.fill",                           "#B3D1E6", "expense"),
            ("美容", "sparkles",                             "#F2B7C6", "expense"),
            ("房租", "building.2.fill",                      "#B3D1E6", "expense"),
            ("房贷", "banknote.fill",                        "#DCCFC4", "expense"),
            ("住房", "house.fill",                           "#A8E0C2", "expense"),
            ("社交", "person.2.fill",                        "#D8C6E8", "expense"),
            ("礼物", "gift.fill",                            "#F2B7C6", "expense"),
            ("旅行", "airplane",                             "#B3D1E6", "expense"),
            ("烟酒", "wineglass.fill",                       "#F6D7A8", "expense"),
            ("快递", "shippingbox.fill",                     "#DCCFC4", "expense"),
            ("追星", "star.fill",                            "#F2B7C6", "expense"),
            ("游戏", "dice.fill",                            "#D8C6E8", "expense"),
            ("数码", "desktopcomputer",                      "#B3D1E6", "expense"),
            ("电影票", "film.fill",                          "#D8C6E8", "expense"),
            ("汽车", "car.fill",                             "#B3D1E6", "expense"),
            ("摩托", "scooter",                              "#B3D1E6", "expense"),
            ("加油费", "fuelpump.fill",                      "#B3D1E6", "expense"),
            ("医疗", "cross.fill",                           "#BFE6EA", "expense"),
            ("书籍", "book.fill",                            "#C8E6C9", "expense"),
            ("宠物", "pawprint.fill",                        "#A8E0C2", "expense"),
            ("水费", "drop.fill",                            "#B3D1E6", "expense"),
            ("电费", "bolt.fill",                            "#F6D7A8", "expense"),
            ("燃气费", "flame.fill",                         "#F2B7C6", "expense"),
            ("育儿", "figure.and.child.holdinghands",        "#D8C6E8", "expense"),
            ("长辈", "person.fill",                          "#DCCFC4", "expense"),
            ("租赁", "key.fill",                             "#BFE6EA", "expense"),
            ("办公", "briefcase.fill",                       "#C8E6C9", "expense"),
            ("维修", "wrench.and.screwdriver.fill",          "#DCCFC4", "expense"),
            ("红包", "envelope.fill",                        "#F2B7C6", "both"),
            ("彩票", "ticket.fill",                          "#F6D7A8", "expense"),
            ("捐赠", "heart.fill",                           "#F2B7C6", "expense"),
            ("礼金", "gift.fill",                            "#D8C6E8", "both"),
            ("转账", "arrow.left.arrow.right",               "#B3D1E6", "expense"),
            ("还款", "creditcard.fill",                      "#DCCFC4", "both"),
            ("借出", "arrow.up.forward.circle.fill",         "#BFE6EA", "expense"),
            ("麻将", "square.grid.3x3.fill",                 "#D8C6E8", "both"),
            ("保洁", "paintbrush.fill",                      "#A8E0C2", "expense"),
            ("洗衣服", "washer.fill",                        "#BFE6EA", "expense"),
            ("工资", "dollarsign.circle.fill",               "#A8E0C2", "income"),
            ("兼职", "clock.fill",                           "#BFE6EA", "income"),
            ("生活费", "wallet.pass.fill",                    "#C8E6C9", "both"),
            ("年终奖", "star.circle.fill",                   "#F6D7A8", "income"),
            ("奖学金", "graduationcap.fill",                 "#C8E6C9", "income"),
            ("分红", "chart.pie.fill",                       "#A8E0C2", "income"),
            ("理财", "chart.line.uptrend.xyaxis",            "#A8E0C2", "income"),
            ("退款", "arrow.uturn.backward",                 "#B3D1E6", "income"),
            ("借入", "arrow.down.circle.fill",               "#DCCFC4", "income"),
            ("卖闲置", "tag.fill",                           "#F2B7C6", "income"),
            ("奖金", "rosette",                              "#F6D7A8", "income"),
        ]
        
        for (name, icon, colorHex, type) in defaults {
            let cat = Category(name: name, icon: icon, colorHex: colorHex,
                               isGlobal: true, transactionType: type)
            modelContext.insert(cat)
        }
        try? modelContext.save()
        fetchCategories()
    }

    private func migrateMorandiColors() {
        guard !UserDefaults.standard.bool(forKey: "morandiMigrationV1Done") else { return }
        let morandiMap: [String: String] = [
            "餐饮": "#F6D7A8", "交通": "#B3D1E6", "购物": "#F2B7C6",
            "娱乐": "#D8C6E8", "住房": "#A8E0C2", "医疗": "#BFE6EA",
            "教育": "#C8E6C9", "通讯": "#B3D1E6", "服饰": "#F2B7C6",
            "日用": "#DCCFC4", "其他": "#DCCFC4", "其它": "#DCCFC4",
        ]
        for cat in categories where cat.isGlobal {
            if let target = morandiMap[cat.name] {
                cat.colorHex = target
            }
            if cat.transactionType.isEmpty {
                cat.transactionType = "both"
            }
        }
        save()
        UserDefaults.standard.set(true, forKey: "morandiMigrationV1Done")
        migrateV2Categories()
    }

    private func migrateV2Categories() {
        guard !UserDefaults.standard.bool(forKey: "categoryMigrationV2Done") else { return }
        let existingNames = Set(categories.map { $0.name })
        let newDefaults: [(String, String, String, String)] = [
            ("水果", "leaf.fill",                            "#A8E0C2", "expense"),
            ("蔬菜", "leaf.circle.fill",                     "#A8E0C2", "expense"),
            ("饮品", "cup.and.saucer.fill",                  "#F6D7A8", "expense"),
            ("零食", "popcorn.fill",                         "#F2B7C6", "expense"),
            ("外卖", "takeoutbag.and.cup.and.straw.fill",    "#F6D7A8", "expense"),
            ("买菜", "cart.fill",                            "#A8E0C2", "expense"),
            ("运动", "figure.run",                           "#BFE6EA", "expense"),
            ("美容", "sparkles",                             "#F2B7C6", "expense"),
            ("房租", "building.2.fill",                      "#B3D1E6", "expense"),
            ("房贷", "banknote.fill",                        "#DCCFC4", "expense"),
            ("社交", "person.2.fill",                        "#D8C6E8", "expense"),
            ("旅行", "airplane",                             "#B3D1E6", "expense"),
            ("烟酒", "wineglass.fill",                       "#F6D7A8", "expense"),
            ("快递", "shippingbox.fill",                     "#DCCFC4", "expense"),
            ("追星", "star.fill",                            "#F2B7C6", "expense"),
            ("游戏", "dice.fill",                            "#D8C6E8", "expense"),
            ("数码", "desktopcomputer",                      "#B3D1E6", "expense"),
            ("电影票", "film.fill",                          "#D8C6E8", "expense"),
            ("汽车", "car.fill",                             "#B3D1E6", "expense"),
            ("摩托", "scooter",                              "#B3D1E6", "expense"),
            ("加油费", "fuelpump.fill",                      "#B3D1E6", "expense"),
            ("书籍", "book.fill",                            "#C8E6C9", "expense"),
            ("宠物", "pawprint.fill",                        "#A8E0C2", "expense"),
            ("水费", "drop.fill",                            "#B3D1E6", "expense"),
            ("电费", "bolt.fill",                            "#F6D7A8", "expense"),
            ("燃气费", "flame.fill",                         "#F2B7C6", "expense"),
            ("育儿", "figure.and.child.holdinghands",        "#D8C6E8", "expense"),
            ("长辈", "person.fill",                          "#DCCFC4", "expense"),
            ("租赁", "key.fill",                             "#BFE6EA", "expense"),
            ("办公", "briefcase.fill",                       "#C8E6C9", "expense"),
            ("维修", "wrench.and.screwdriver.fill",          "#DCCFC4", "expense"),
            ("红包", "envelope.fill",                        "#F2B7C6", "both"),
            ("彩票", "ticket.fill",                          "#F6D7A8", "expense"),
            ("捐赠", "heart.fill",                           "#F2B7C6", "expense"),
            ("礼金", "gift.fill",                            "#D8C6E8", "both"),
            ("转账", "arrow.left.arrow.right",               "#B3D1E6", "expense"),
            ("还款", "creditcard.fill",                      "#DCCFC4", "both"),
            ("借出", "arrow.up.forward.circle.fill",         "#BFE6EA", "expense"),
            ("麻将", "square.grid.3x3.fill",                 "#D8C6E8", "both"),
            ("保洁", "paintbrush.fill",                      "#A8E0C2", "expense"),
            ("洗衣服", "washer.fill",                        "#BFE6EA", "expense"),
            ("工资", "dollarsign.circle.fill",               "#A8E0C2", "income"),
            ("兼职", "clock.fill",                           "#BFE6EA", "income"),
            ("生活费", "wallet.pass.fill",                    "#C8E6C9", "both"),
            ("年终奖", "star.circle.fill",                   "#F6D7A8", "income"),
            ("奖学金", "graduationcap.fill",                 "#C8E6C9", "income"),
            ("分红", "chart.pie.fill",                       "#A8E0C2", "income"),
            ("理财", "chart.line.uptrend.xyaxis",            "#A8E0C2", "income"),
            ("退款", "arrow.uturn.backward",                 "#B3D1E6", "income"),
            ("借入", "arrow.down.circle.fill",               "#DCCFC4", "income"),
            ("卖闲置", "tag.fill",                           "#F2B7C6", "income"),
            ("奖金", "rosette",                              "#F6D7A8", "income"),
        ]
        for (name, icon, colorHex, type) in newDefaults {
            guard !existingNames.contains(name) else { continue }
            let cat = Category(name: name, icon: icon, colorHex: colorHex,
                               isGlobal: true, transactionType: type)
            modelContext.insert(cat)
        }
        let iconUpdates: [String: String] = [
            "交通": "tram.fill", "医疗": "cross.fill", "学习": "book.closed.fill",
            "生活费": "wallet.pass.fill",
        ]
        for cat in categories where cat.isGlobal {
            if let newIcon = iconUpdates[cat.name] {
                cat.icon = newIcon
            }
            if cat.transactionType.isEmpty || cat.transactionType == "" {
                cat.transactionType = "both"
            }
        }
        save()
        fetchCategories()
        UserDefaults.standard.set(true, forKey: "categoryMigrationV2Done")
        migrateV3Categories()
    }

    private func migrateV3Categories() {
        guard !UserDefaults.standard.bool(forKey: "categoryMigrationV3Done") else { return }
        let allCats = (try? modelContext.fetch(FetchDescriptor<Category>())) ?? []
        for cat in allCats where cat.name == "生活费" {
            cat.icon = "wallet.pass.fill"
            cat.transactionType = "both"
        }
        save()
        fetchCategories()
        UserDefaults.standard.set(true, forKey: "categoryMigrationV3Done")
    }
}
