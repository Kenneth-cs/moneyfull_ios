import SwiftData
import SwiftUI
import CoreData

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
    
    private var refreshDebounceTask: Task<Void, Never>?
    private var notificationObserver: NSObjectProtocol?
    private var cloudKitEventObserver: NSObjectProtocol?
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        let ts = UserDefaults.standard.double(forKey: "lastBackupTimestamp")
        if ts > 0 {
            self.lastBackupDate = Date(timeIntervalSince1970: ts)
        }
        setupDefaultDataIfNeeded()
        
        // 依次执行所有迁移脚本
        migrateMorandiColors()
        migrateV2Categories()
        migrateV3Categories()
        migrateV4Categories()
        migrateV5Categories()
        
        refresh()
        startObservingDataChanges()
    }
    
    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = cloudKitEventObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func startObservingDataChanges() {
        // 监听 Core Data 的对象变化（主要捕获本地变化或部分同步变化）
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextObjectsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.triggerDebouncedRefresh()
            }
        }
        
        // 监听 CloudKit 的同步事件（捕获远程数据下载）
        cloudKitEventObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // 确保是 import 结束事件
            if let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event {
                if event.type == .import && event.endDate != nil {
                    Task { @MainActor [weak self] in
                        self?.triggerDebouncedRefresh()
                    }
                }
            }
        }
    }
    
    private func triggerDebouncedRefresh() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.refreshDebounceTask?.cancel()
            self.refreshDebounceTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled, let self else { return }
                self.deduplicateDefaultProjects()
                self.deduplicateCategories()
                self.refresh()
            }
        }
    }
    
    // MARK: - 读取数据
    
    func refresh() {
        fetchProjects()
        fetchRecentTransactions()
        fetchCategories()
        calcMonthlyStats()
    }
    
    private func fetchProjects() {
        let descriptor = FetchDescriptor<Project>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        activeProjects = all
            .filter { !$0.isArchived }
            .sorted {
                if $0.isPinned != $1.isPinned { return $0.isPinned }
                if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                return $0.createdAt > $1.createdAt
            }
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
        
        repairCloudKitCategoriesIfNeeded()
    }
    
    /// 动态修复从 iCloud 延迟同步过来的缺乏 groupName 的旧分类数据
    private func repairCloudKitCategoriesIfNeeded() {
        var needsSave = false
        
        let categoryGroups: [String: (group: String, incomeGroup: String?)] = [
            "餐饮": ("吃喝", nil), "外卖": ("吃喝", nil), "零食": ("吃喝", nil), "饮品": ("吃喝", nil), "水果": ("吃喝", nil), "蔬菜": ("吃喝", nil), "买菜": ("吃喝", nil),
            "日用": ("居家", nil), "水费": ("居家", nil), "电费": ("居家", nil), "燃气费": ("居家", nil), "房租": ("居家", nil), "房贷": ("居家", nil), "住房": ("居家", nil), "保洁": ("居家", nil), "洗衣服": ("居家", nil), "维修": ("居家", nil), "宠物": ("居家", nil), "话费": ("居家", nil), "医疗": ("居家", nil), "育儿": ("居家", nil), "长辈": ("居家", nil),
            "交通": ("出行", nil), "汽车": ("出行", nil), "摩托": ("出行", nil), "加油费": ("出行", nil), "租赁": ("出行", nil),
            "电影票": ("娱乐", nil), "游戏": ("娱乐", nil), "追星": ("娱乐", nil), "数码": ("娱乐", nil), "运动": ("娱乐", nil), "旅行": ("娱乐", nil), "烟酒": ("娱乐", nil), "麻将": ("娱乐", "额外"),
            "学习": ("成长", nil), "书籍": ("成长", nil), "美容": ("成长", nil), "服饰": ("成长", nil), "办公": ("成长", nil),
            "红包": ("人情", "额外"), "礼金": ("人情", "额外"), "捐赠": ("人情", nil), "社交": ("人情", nil), "礼物": ("人情", nil),
            "彩票": ("其他", nil), "转账": ("其他", nil), "还款": ("其他", "临时"), "借出": ("其他", nil), "快递": ("其他", nil), "购物": ("其他", nil), "其它": ("其他", "其他"),
            
            "工资": ("工资", "工资"), "兼职": ("工资", "工资"), "年终奖": ("工资", "工资"), "奖金": ("工资", "工资"), "奖学金": ("工资", "工资"),
            "分红": ("额外", "额外"), "理财": ("额外", "额外"), "生活费": ("额外", "额外"),
            "退款": ("临时", "临时"), "卖闲置": ("临时", "临时"), "借入": ("临时", "临时")
        ]
        
        for cat in categories {
            // 只处理 groupName 为空的数据，即从 iCloud 直接同步下来的旧数据
            if cat.groupName.isEmpty {
                if let mapping = categoryGroups[cat.name] {
                    cat.groupName = mapping.group
                    if let incomeGroup = mapping.incomeGroup {
                        cat.incomeGroupName = incomeGroup
                    }
                } else {
                    cat.groupName = "其他" // 未知类别默认丢到其他
                }
                needsSave = true
            }
            if cat.transactionType.isEmpty {
                cat.transactionType = "both"
                needsSave = true
            }
        }
        
        if needsSave {
            save()
        }
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
        tx.rawType = type.rawValue // 直接修改底层存储属性
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
    
    func updateProject(_ project: Project, name: String, icon: String,
                       colorHex: String, desc: String, budget: Double) {
        project.name = name
        project.icon = icon
        project.colorHex = colorHex
        project.desc = desc
        project.budget = budget
        save()
        refresh()
    }

    func updateProjectSortOrder(_ orderedProjects: [Project]) {
        for (index, project) in orderedProjects.enumerated() {
            project.sortOrder = index
        }
        save()
        refresh()
    }
    
    // MARK: - 分类管理
    
    func addCategory(name: String, icon: String, colorHex: String, groupName: String = "", transactionType: String = "both") {
        let category = Category(name: name, icon: icon, colorHex: colorHex, isGlobal: false, transactionType: transactionType, groupName: groupName)
        modelContext.insert(category)
        save()
        refresh()
    }
    
    func deleteCategory(_ category: Category) {
        modelContext.delete(category)
        save()
        refresh()
    }

    func updateCategory(_ category: Category, name: String, icon: String, colorHex: String, groupName: String? = nil) {
        category.name = name
        category.icon = icon
        category.colorHex = colorHex
        if let groupName = groupName {
            category.groupName = groupName
        }
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
        let all = (try? modelContext.fetch(descriptor)) ?? []
        let hasDailyProject = all.contains { $0.name == "日常收支" && !$0.isArchived }
        
        if !hasDailyProject {
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
        
        seedDefaultCategoriesIfNeeded()
    }
    
    private func seedDefaultCategoriesIfNeeded() {
        let existingNames = Set(((try? modelContext.fetch(FetchDescriptor<Category>())) ?? []).map { $0.name })
        guard existingNames.isEmpty else { return }
        
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
    
    private func migrateV4Categories() {
        guard !UserDefaults.standard.bool(forKey: "categoryMigrationV4Done_fix1") else { return }
        
        let allCats = (try? modelContext.fetch(FetchDescriptor<Category>())) ?? []
        let existingNames = Set(allCats.map { $0.name })
        
        // 1. 定义每个分类的分组信息
        let categoryGroups: [String: (group: String, incomeGroup: String?)] = [
            "餐饮": ("吃喝", nil), "外卖": ("吃喝", nil), "零食": ("吃喝", nil), "饮品": ("吃喝", nil), "水果": ("吃喝", nil), "蔬菜": ("吃喝", nil), "买菜": ("吃喝", nil),
            "日用": ("居家", nil), "水费": ("居家", nil), "电费": ("居家", nil), "燃气费": ("居家", nil), "房租": ("居家", nil), "房贷": ("居家", nil), "住房": ("居家", nil), "保洁": ("居家", nil), "洗衣服": ("居家", nil), "维修": ("居家", nil), "宠物": ("居家", nil), "话费": ("居家", nil), "医疗": ("居家", nil), "育儿": ("居家", nil), "长辈": ("居家", nil),
            "交通": ("出行", nil), "汽车": ("出行", nil), "摩托": ("出行", nil), "加油费": ("出行", nil), "租赁": ("出行", nil),
            "电影票": ("娱乐", nil), "游戏": ("娱乐", nil), "追星": ("娱乐", nil), "数码": ("娱乐", nil), "运动": ("娱乐", nil), "旅行": ("娱乐", nil), "烟酒": ("娱乐", nil), "麻将": ("娱乐", "额外"),
            "学习": ("成长", nil), "书籍": ("成长", nil), "美容": ("成长", nil), "服饰": ("成长", nil), "办公": ("成长", nil),
            "红包": ("人情", "额外"), "礼金": ("人情", "额外"), "捐赠": ("人情", nil), "社交": ("人情", nil), "礼物": ("人情", nil),
            "彩票": ("其他", nil), "转账": ("其他", nil), "还款": ("其他", "临时"), "借出": ("其他", nil), "快递": ("其他", nil), "购物": ("其他", nil), "其它": ("其他", "其他"),
            
            "工资": ("工资", "工资"), "兼职": ("工资", "工资"), "年终奖": ("工资", "工资"), "奖金": ("工资", "工资"), "奖学金": ("工资", "工资"),
            "分红": ("额外", "额外"), "理财": ("额外", "额外"), "生活费": ("额外", "额外"),
            "退款": ("临时", "临时"), "卖闲置": ("临时", "临时"), "借入": ("临时", "临时")
        ]
        
        // 2. 为现有分类设置分组
        for cat in allCats {
            if let mapping = categoryGroups[cat.name] {
                cat.groupName = mapping.group
                if let incomeGroup = mapping.incomeGroup {
                    cat.incomeGroupName = incomeGroup
                }
            } else if cat.groupName.isEmpty {
                // 如果没有匹配到且为空，默认放入其他
                cat.groupName = "其他"
            }
            // 确保旧数据的 isGlobal 和类型能够正确显示
            if cat.transactionType.isEmpty {
                cat.transactionType = "both"
            }
        }
        
        // 3. 补充 V4 新增的通用分类和可能遗漏的系统默认子分类
        let v4Defaults: [(String, String, String, String, String, String)] = [
            // 通用大类
            ("吃喝(通用)", "fork.knife", "#F6D7A8", "expense", "吃喝", ""),
            ("居家(通用)", "house.fill", "#A8E0C2", "expense", "居家", ""),
            ("出行(通用)", "car.fill", "#B3D1E6", "expense", "出行", ""),
            ("娱乐(通用)", "gamecontroller.fill", "#D8C6E8", "expense", "娱乐", ""),
            ("成长(通用)", "book.closed.fill", "#C8E6C9", "expense", "成长", ""),
            ("人情(通用)", "envelope.fill", "#F2B7C6", "expense", "人情", ""),
            ("其他(通用)", "ellipsis.circle.fill", "#DCCFC4", "both", "其他", "其他"),
            
            ("工资(通用)", "dollarsign.circle.fill", "#A8E0C2", "income", "工资", "工资"),
            ("额外(通用)", "gift.fill", "#F2B7C6", "income", "额外", "额外"),
            ("临时(通用)", "clock.fill", "#BFE6EA", "income", "临时", "临时"),
            
            // 补充基础默认子类防止它们在部分老用户库中丢失
            ("餐饮", "fork.knife", "#F6D7A8", "expense", "吃喝", ""),
            ("交通", "tram.fill", "#B3D1E6", "expense", "出行", ""),
            ("购物", "bag.fill", "#F2B7C6", "expense", "其他", ""),
            ("娱乐", "gamecontroller.fill", "#D8C6E8", "expense", "娱乐", ""),
            ("住房", "house.fill", "#A8E0C2", "expense", "居家", ""),
            ("日用", "basket.fill", "#DCCFC4", "expense", "居家", "")
        ]
        
        for (name, icon, colorHex, type, group, incomeGroup) in v4Defaults {
            if !existingNames.contains(name) {
                let cat = Category(name: name, icon: icon, colorHex: colorHex, isGlobal: true, transactionType: type, groupName: group, incomeGroupName: incomeGroup)
                modelContext.insert(cat)
            }
        }
        
        save()
        fetchCategories()
        UserDefaults.standard.set(true, forKey: "categoryMigrationV4Done_fix1")
    }
    
    private func migrateV5Categories() {
        guard !UserDefaults.standard.bool(forKey: "categoryMigrationV5Done") else { return }
        
        let allCats = (try? modelContext.fetch(FetchDescriptor<Category>())) ?? []
        
        // 1. 删除所有带 "(通用)" 的冗余分类，解决文案和图标重复问题
        for cat in allCats {
            if cat.name.contains("(通用)") {
                modelContext.delete(cat)
            }
        }
        
        // 2. 对于原本没有单独基础分类的类目，补充纯净的名称（去掉通用两字）
        let existingNames = Set(allCats.map { $0.name })
        let v5Defaults: [(String, String, String, String, String, String)] = [
            ("居家", "house.fill", "#A8E0C2", "expense", "居家", ""),
            ("成长", "book.closed.fill", "#C8E6C9", "expense", "成长", ""),
            ("人情", "envelope.fill", "#F2B7C6", "expense", "人情", ""),
            ("额外", "gift.fill", "#F2B7C6", "income", "额外", "额外"),
            ("临时", "clock.fill", "#BFE6EA", "income", "临时", "临时")
        ]
        
        for (name, icon, colorHex, type, group, incomeGroup) in v5Defaults {
            if !existingNames.contains(name) {
                let cat = Category(name: name, icon: icon, colorHex: colorHex, isGlobal: true, transactionType: type, groupName: group, incomeGroupName: incomeGroup)
                modelContext.insert(cat)
            }
        }
        
        save()
        fetchCategories()
        UserDefaults.standard.set(true, forKey: "categoryMigrationV5Done")
    }
    
    // MARK: - 去重逻辑
    
    private func deduplicateDefaultProjects() {
        let descriptor = FetchDescriptor<Project>()
        guard let all = try? modelContext.fetch(descriptor) else { return }
        
        let dailyProjects = all.filter { $0.name == "日常收支" && !$0.isArchived }
        guard dailyProjects.count > 1 else { return }
        
        let sorted = dailyProjects.sorted { lhs, rhs in
            let lhsCount = lhs.transactions?.count ?? 0
            let rhsCount = rhs.transactions?.count ?? 0
            if lhsCount != rhsCount { return lhsCount > rhsCount }
            return lhs.createdAt < rhs.createdAt
        }
        
        let mainProject = sorted[0]
        
        for duplicate in sorted.dropFirst() {
            if let txs = duplicate.transactions {
                for tx in txs {
                    tx.project = mainProject
                }
            }
            modelContext.delete(duplicate)
        }
        
        try? modelContext.save()
    }
    
    private func deduplicateCategories() {
        let descriptor = FetchDescriptor<Category>()
        guard let all = try? modelContext.fetch(descriptor) else { return }
        
        var seen = [String: Category]()
        var toDelete = [Category]()
        
        for cat in all {
            let key = "\(cat.name)_\(cat.transactionType)"
            if let existing = seen[key] {
                if cat.createdAt < existing.createdAt {
                    toDelete.append(existing)
                    seen[key] = cat
                } else {
                    toDelete.append(cat)
                }
            } else {
                seen[key] = cat
            }
        }
        
        guard !toDelete.isEmpty else { return }
        
        for cat in toDelete {
            modelContext.delete(cat)
        }
        
        try? modelContext.save()
        fetchCategories()
    }
}
