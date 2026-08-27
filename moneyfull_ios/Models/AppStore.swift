import SwiftData
import SwiftUI
import CoreData

/// 项目收支汇总（渲染路径查表用，避免每张卡片重复遍历关系）
struct ProjectSummary: Equatable {
    let totalSpent: Double
    let totalIncome: Double
    let budgetProgress: Double
}

/// 全局状态管理：负责所有数据的增删查改，注入到 View 层使用
@MainActor
class AppStore: ObservableObject {
    private let modelContext: ModelContext

    /// 统一数据变更信号：在金额相关模型写操作后自增，供各 View 作为缓存失效依据
    @Published private(set) var dataVersion: Int = 0

    /// 所有进行中项目
    @Published var activeProjects: [Project] = []
    /// 所有已归档项目
    @Published var archivedProjects: [Project] = []
    /// 最近交易（全局，按时间倒序，最多50条）
    @Published var recentTransactions: [Transaction] = []
    /// 所有分类（系统预设 + 自定义）
    @Published var categories: [Category] = []
    /// 消息中心通知列表（按时间倒序）
    @Published var appNotices: [AppNotice] = []
    /// 项目收支汇总表（fetchProjects 时一次遍历产出，渲染路径查表）
    @Published private(set) var projectSummaries: [UUID: ProjectSummary] = [:]
    
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
        migrateDailyProjectUnpin()
        migrateV6ProjectMode()
        migrateV7CostCategory()
        
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
    
    /// 全量刷新：启动、CloudKit 同步、批量导入等场景使用
    func refresh() {
        refreshProjects()
        refreshTransactions()
        refreshCategories()
        refreshNotices()
        calcMonthlyStats()
        bumpDataVersion()
    }

    // MARK: - 分域刷新（避免任意 @Published 变化触发全屏重绘）

    private func refreshProjects() {
        let descriptor = FetchDescriptor<Project>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        let newActive = all
            .filter { !$0.isArchived }
            .sorted {
                if $0.isPinned != $1.isPinned { return $0.isPinned }
                if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                return $0.createdAt > $1.createdAt
            }
        let newArchived = all
            .filter { $0.isArchived }
            .sorted { $0.createdAt > $1.createdAt }

        // 一次遍历产出全部项目的收支汇总，渲染路径（项目卡片）查表而非各自遍历关系
        var summaries: [UUID: ProjectSummary] = [:]
        summaries.reserveCapacity(all.count)
        for project in all {
            var spent: Double = 0
            var income: Double = 0
            for tx in project.transactions ?? [] {
                if tx.type == .expense {
                    spent += abs(tx.amount)
                } else if tx.type == .income {
                    income += abs(tx.amount)
                }
            }
            summaries[project.id] = ProjectSummary(
                totalSpent: spent,
                totalIncome: income,
                budgetProgress: project.budget > 0 ? spent / project.budget : 0
            )
        }

        assignIfChanged(\.activeProjects, newActive)
        assignIfChanged(\.archivedProjects, newArchived)
        assignIfChanged(\.projectSummaries, summaries)
    }

    private func refreshTransactions() {
        var descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 50
        assignIfChanged(\.recentTransactions, (try? modelContext.fetch(descriptor)) ?? [])
    }

    private func refreshCategories() {
        let descriptor = FetchDescriptor<Category>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let newCategories = (try? modelContext.fetch(descriptor)) ?? []
        assignIfChanged(\.categories, newCategories)

        repairCloudKitCategoriesIfNeeded()
    }

    private func refreshNotices() {
        let descriptor = FetchDescriptor<AppNotice>(
            sortBy: [SortDescriptor(\.receivedAt, order: .reverse)]
        )
        assignIfChanged(\.appNotices, (try? modelContext.fetch(descriptor)) ?? [])
    }

    /// 只在值变化时赋值，避免无谓的 objectWillChange
    private func assignIfChanged<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<AppStore, T>, _ newValue: T) {
        if self[keyPath: keyPath] != newValue {
            self[keyPath: keyPath] = newValue
        }
    }

    /// dataVersion 只在金额相关模型变更时自增
    private func bumpDataVersion() {
        dataVersion += 1
    }

    /// 刷新与金额/项目汇总相关的域，并 bump dataVersion
    private func refreshFinancialAndBump() {
        refreshProjects()
        refreshTransactions()
        calcMonthlyStats()
        bumpDataVersion()
    }

    /// 消息中心未读数量，用于首页铃铛角标
    var unreadNoticeCount: Int {
        appNotices.filter { !$0.isRead }.count
    }

    /// 将某条消息标记为已读（点开详情时调用）
    func markNoticeAsRead(_ notice: AppNotice) {
        guard !notice.isRead else { return }
        notice.isRead = true
        save()
        refreshNotices()
    }

    /// 关闭自动弹出的"给陪伴的你"感谢信时调用，把消息中心对应那条也标记为已读
    func markLegacyGiftNoticeAsRead() {
        let noticeID = AppNoticeData.legacyGiftLetter.id
        if let notice = appNotices.first(where: { $0.noticeID == noticeID }) {
            markNoticeAsRead(notice)
        }
    }
    
    func fetchAllTransactions() -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func fetchTotalTransactionCount() -> Int {
        let descriptor = FetchDescriptor<Transaction>()
        return (try? modelContext.fetchCount(descriptor)) ?? 0
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
        
        monthlyExpense = monthlyTx.filter { $0.type == .expense }.reduce(0) { $0 + abs($1.amount) }
        monthlyIncome = monthlyTx.filter { $0.type == .income }.reduce(0) { $0 + abs($1.amount) }
        monthlySaving = monthlyIncome - monthlyExpense
    }

    // MARK: - 首页看板多维度统计
    func stats(for period: DashboardPeriod) -> (expense: Double, income: Double, saving: Double) {
        let calendar = Calendar.current
        let now = Date()
        var startDate: Date

        switch period {
        case .week:
            startDate = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        case .month:
            startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        case .year:
            startDate = calendar.date(from: DateComponents(year: calendar.component(.year, from: now), month: 1, day: 1))!
        case .all:
            startDate = Date.distantPast
        }

        // 时间范围下推到数据库，求和不依赖顺序故去掉 sortBy
        let descriptor: FetchDescriptor<Transaction>
        if period == .all {
            descriptor = FetchDescriptor<Transaction>()
        } else {
            descriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate { $0.date >= startDate }
            )
        }
        let txs = (try? modelContext.fetch(descriptor)) ?? []
        // 一次遍历同时累加收入与支出
        var exp: Double = 0
        var inc: Double = 0
        for tx in txs {
            if tx.type == .expense {
                exp += abs(tx.amount)
            } else if tx.type == .income {
                inc += abs(tx.amount)
            }
        }
        return (exp, inc, inc - exp)
    }
    
    // MARK: - 新增数据
    
    /// 添加一笔账单到指定项目
    @discardableResult
    func addTransaction(to project: Project, amount: Double, type: TransactionType,
                        categoryName: String, categoryIcon: String, categoryColorHex: String,
                        note: String = "", date: Date = Date(),
                        cashFlowType: String = "operating") -> Transaction {
        let tx = Transaction(amount: amount, type: type, categoryName: categoryName,
                             categoryIcon: categoryIcon, categoryColorHex: categoryColorHex,
                             note: note, date: date, cashFlowType: cashFlowType)
        tx.project = project
        project.transactions = (project.transactions ?? []) + [tx]
        modelContext.insert(tx)
        save()
        refreshFinancialAndBump()

        // 预算预警检查
        BudgetAlertService.shared.check(after: tx, in: project)

        return tx
    }

    /// 新建项目
    @discardableResult
    func addProject(name: String, icon: String, colorHex: String,
                    desc: String, budget: Double, isPinned: Bool = false,
                    projectMode: String = "lifestyle", budgetCycle: String = "project",
                    targetIncome: Double = 0, defaultRate: Double = 0) -> Project {
        let project = Project(name: name, icon: icon, colorHex: colorHex,
                              desc: desc, budget: budget, isPinned: isPinned,
                              projectMode: projectMode, budgetCycle: budgetCycle,
                              targetIncome: targetIncome, defaultRate: defaultRate)
        modelContext.insert(project)
        save()
        refreshProjects()
        bumpDataVersion()
        return project
    }
    
    // MARK: - 修改数据
    
    /// 更新交易记录
    /// 注意：通过 UUID 重新从数据库获取活跃对象后再修改，
    /// 避免因 SwiftData 内存淘汰或 iCloud 同步导致传入的 tx 成为"幽灵对象"而修改不生效
    func updateTransaction(_ tx: Transaction, amount: Double, type: TransactionType,
                           categoryName: String, categoryIcon: String, categoryColorHex: String,
                           note: String, date: Date, project: Project? = nil,
                           cashFlowType: String? = nil) {
        // 通过 UUID 重新抓取活跃的 managed 对象
        let txID = tx.id
        let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.id == txID })
        let target = (try? modelContext.fetch(descriptor))?.first ?? tx

        target.amount = amount
        target.rawType = type.rawValue  // 底层存储属性，CloudKit 不支持枚举
        target.categoryName = categoryName
        target.categoryIcon = categoryIcon
        target.categoryColorHex = categoryColorHex
        target.note = note
        target.date = date
        if let project = project {
            target.project = project
        }
        if let cashFlowType = cashFlowType {
            target.cashFlowType = cashFlowType
        }
        save()
        refreshFinancialAndBump()

        // 预算预警检查
        if let project = target.project {
            BudgetAlertService.shared.check(after: target, in: project)
        }
    }

    /// 归档 / 取消归档项目
    func toggleArchive(project: Project) {
        let wasArchived = project.isArchived
        project.isArchived.toggle()
        save()
        refreshFinancialAndBump()

        if !wasArchived {
            AnalyticsManager.shared.trackEvent(
                eventId: "project_archive",
                eventName: "归档项目",
                params: [
                    "project_name": project.name
                ]
            )
        }
    }

    /// 设置/取消活跃项目（全局唯一）
    func toggleActiveProject(_ project: Project) {
        // 如果当前项目已经是活跃项目，则取消
        if project.isActiveProject {
            project.isActiveProject = false
        } else {
            // 先取消所有其他项目的活跃状态
            let allProjects = (try? modelContext.fetch(FetchDescriptor<Project>())) ?? []
            for p in allProjects {
                p.isActiveProject = false
            }
            // 设置当前项目为活跃项目
            project.isActiveProject = true
        }
        save()
        refreshProjects()
        bumpDataVersion()
    }

    // MARK: - 删除数据

    func deleteTransaction(_ tx: Transaction) {
        modelContext.delete(tx)
        save()
        refreshFinancialAndBump()
    }

    func deleteProject(_ project: Project) {
        for tx in project.transactions ?? [] {
            modelContext.delete(tx)
        }
        modelContext.delete(project)
        save()
        refreshFinancialAndBump()
    }

    func updateProjectColor(_ project: Project, colorHex: String) {
        project.colorHex = colorHex
        save()
        refreshProjects()
        bumpDataVersion()
    }

    func updateProjectWorkingDays(_ project: Project, days: Int) {
        project.workingDays = max(0, days)
        save()
    }

    func updateProject(_ project: Project, name: String, icon: String,
                       colorHex: String, desc: String, budget: Double,
                       projectMode: String? = nil, budgetCycle: String? = nil,
                       targetIncome: Double? = nil, defaultRate: Double? = nil) {
        let budgetChanged = project.budget != budget
        project.name = name
        project.icon = icon
        project.colorHex = colorHex
        project.desc = desc
        project.budget = budget
        if let mode = projectMode { project.projectMode = mode }
        if let cycle = budgetCycle { project.budgetCycle = cycle }
        if let income = targetIncome { project.targetIncome = income }
        if let rate = defaultRate { project.defaultRate = rate }
        save()
        refreshFinancialAndBump()

        // 预算金额变更时重置检查点
        if budgetChanged {
            BudgetAlertService.shared.resetProjectCheckpoint(for: project.id)
        }
    }

    func updateProjectSortOrder(_ orderedProjects: [Project]) {
        for (index, project) in orderedProjects.enumerated() {
            project.sortOrder = index
        }
        save()
        refreshProjects()
        bumpDataVersion()
    }

    // MARK: - 分类管理

    func addCategory(name: String, icon: String, colorHex: String, groupName: String = "", transactionType: String = "both") {
        let category = Category(name: name, icon: icon, colorHex: colorHex, isGlobal: false, transactionType: transactionType, groupName: groupName)
        modelContext.insert(category)
        save()
        refreshCategories()

        AnalyticsManager.shared.trackEvent(
            eventId: "category_created",
            eventName: "添加分类",
            params: [
                "category_name": name,
                "group_name": groupName,
                "transaction_type": transactionType
            ]
        )
    }

    func deleteCategory(_ category: Category) {
        modelContext.delete(category)
        save()
        refreshCategories()
    }

    func updateCategory(_ category: Category, name: String, icon: String, colorHex: String, groupName: String? = nil) {
        category.name = name
        category.icon = icon
        category.colorHex = colorHex
        if let groupName = groupName {
            category.groupName = groupName
        }
        save()
        refreshCategories()
    }
    
    // MARK: - BudgetItem CRUD
    
    @discardableResult
    func addBudgetItem(to project: Project, categoryName: String, categoryIcon: String,
                       categoryColorHex: String, amount: Double, sortOrder: Int = 0,
                       alertThreshold: Double = 0) -> BudgetItem {
        let item = BudgetItem(categoryName: categoryName, categoryIcon: categoryIcon,
                              categoryColorHex: categoryColorHex, amount: amount,
                              sortOrder: sortOrder, alertThreshold: alertThreshold)
        item.project = project
        project.budgetItems = (project.budgetItems ?? []) + [item]
        modelContext.insert(item)
        save()
        refreshProjects()
        bumpDataVersion()
        return item
    }

    func updateBudgetItem(_ item: BudgetItem, categoryName: String? = nil, categoryIcon: String? = nil,
                          categoryColorHex: String? = nil, amount: Double? = nil,
                          sortOrder: Int? = nil, alertThreshold: Double? = nil) {
        if let name = categoryName { item.categoryName = name }
        if let icon = categoryIcon { item.categoryIcon = icon }
        if let color = categoryColorHex { item.categoryColorHex = color }
        if let amt = amount { item.amount = amt }
        if let order = sortOrder { item.sortOrder = order }
        if let threshold = alertThreshold { item.alertThreshold = threshold }
        save()
        refreshProjects()
        bumpDataVersion()
    }

    func deleteBudgetItem(_ item: BudgetItem) {
        if let project = item.project {
            project.budgetItems = (project.budgetItems ?? []).filter { $0.id != item.id }
        }
        modelContext.delete(item)
        save()
        refreshProjects()
        bumpDataVersion()
    }

    func reorderBudgetItems(_ items: [BudgetItem]) {
        for (index, item) in items.enumerated() {
            item.sortOrder = index
        }
        save()
        refreshProjects()
        bumpDataVersion()
    }

    // MARK: - TimeEntry CRUD

    @discardableResult
    func addTimeEntry(to project: Project, duration: Double, granularity: String = "hour",
                      rate: Double, note: String = "", date: Date = Date()) -> TimeEntry {
        let entry = TimeEntry(duration: duration, granularity: granularity, rate: rate,
                              note: note, date: date)
        entry.project = project
        project.timeEntries = (project.timeEntries ?? []) + [entry]
        modelContext.insert(entry)
        save()
        refreshProjects()
        bumpDataVersion()
        return entry
    }

    func deleteTimeEntry(_ entry: TimeEntry) {
        if let project = entry.project {
            project.timeEntries = (project.timeEntries ?? []).filter { $0.id != entry.id }
        }
        modelContext.delete(entry)
        save()
        refreshProjects()
        bumpDataVersion()
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
    
    // MARK: - 导入数据
    
    static let historyProjectName = "历史账单"
    
    func getOrCreateHistoryProject() -> Project {
        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { $0.name == "历史账单" }
        )
        if let existing = (try? modelContext.fetch(descriptor))?.first {
            return existing
        }
        let project = Project(
            name: Self.historyProjectName,
            icon: "clock.arrow.circlepath",
            colorHex: "#B3D1E6",
            desc: "从其他 App 导入的历史账单，可使用 AI 整理功能分配到对应项目"
        )
        modelContext.insert(project)
        save()
        refreshProjects()
        return project
    }

    @discardableResult
    func addImportedTransactions(_ transactions: [(amount: Double, type: TransactionType, categoryName: String, categoryIcon: String, categoryColorHex: String, note: String, date: Date)], batchID: UUID) -> Int {
        let project = getOrCreateHistoryProject()

        var count = 0
        for item in transactions {
            let tx = Transaction(
                amount: item.amount,
                type: item.type,
                categoryName: item.categoryName,
                categoryIcon: item.categoryIcon,
                categoryColorHex: item.categoryColorHex,
                note: item.note,
                date: item.date
            )
            tx.importBatchID = batchID
            tx.project = project
            project.transactions = (project.transactions ?? []) + [tx]
            modelContext.insert(tx)
            count += 1
        }
        save()
        refreshFinancialAndBump()
        return count
    }

    func undoImport(batchID: UUID) -> Int {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.importBatchID != nil }
        )
        guard let allImported = try? modelContext.fetch(descriptor) else { return 0 }

        let batch = allImported.filter { $0.importBatchID == batchID }
        for tx in batch {
            modelContext.delete(tx)
        }
        save()
        refreshFinancialAndBump()
        return batch.count
    }
    
    // MARK: - 私有工具
    
    private func save() {
        try? modelContext.save()
    }

    // MARK: - 性能测试数据（仅 Debug 包）

    #if DEBUG
    /// 性能测试专用批次标识（固定 UUID，保证重启后仍能一键清除）
    static let perfTestBatchID = UUID(uuidString: "A1B2C3D4-1111-2222-3333-444455556666")!

    /// 一键生成 count 条测试账单（挂到"日常收支"项目，用于滚动性能复现）
    func generatePerfTestTransactions(count: Int = 5000) {
        let project = activeProjects.first(where: { $0.name == "日常收支" }) ?? activeProjects.first ?? getOrCreateHistoryProject()
        let categories: [(name: String, icon: String, color: String, type: TransactionType)] = [
            ("餐饮", "fork.knife", "#F6D7A8", .expense),
            ("购物", "bag.fill", "#F2B7C6", .expense),
            ("交通", "tram.fill", "#B3D1E6", .expense),
            ("日用", "basket.fill", "#DCCFC4", .expense),
            ("娱乐", "gamecontroller.fill", "#D8C6E8", .expense),
            ("工资", "dollarsign.circle.fill", "#A8E0C2", .income),
            ("兼职", "clock.fill", "#BFE6EA", .income)
        ]
        let now = Date()
        for i in 0..<count {
            let cat = categories[i % categories.count]
            // 均匀分布在过去的两年内
            let date = now.addingTimeInterval(-Double(i % 730) * 86400 - Double(i % 86400))
            let tx = Transaction(
                amount: Double((i % 500) + 1) + Double(i % 100) / 100,
                type: cat.type,
                categoryName: cat.name,
                categoryIcon: cat.icon,
                categoryColorHex: cat.color,
                note: "性能测试 #\(i)",
                date: date
            )
            tx.importBatchID = Self.perfTestBatchID
            tx.project = project
            modelContext.insert(tx)
        }
        save()
        refreshFinancialAndBump()
    }

    /// 一键清除全部性能测试账单，返回清除条数
    @discardableResult
    func clearPerfTestTransactions() -> Int {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.importBatchID != nil }
        )
        guard let allImported = try? modelContext.fetch(descriptor) else { return 0 }
        let batch = allImported.filter { $0.importBatchID == Self.perfTestBatchID }
        for tx in batch {
            modelContext.delete(tx)
        }
        save()
        refreshFinancialAndBump()
        return batch.count
    }
    #endif
    
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
        refreshCategories()
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
        refreshCategories()
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
        refreshCategories()
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
        refreshCategories()
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
        refreshCategories()
        UserDefaults.standard.set(true, forKey: "categoryMigrationV5Done")
    }
    
    /// 迁移：取消"日常收支"项目的置顶状态，让它参与正常排序
    private func migrateDailyProjectUnpin() {
        guard !UserDefaults.standard.bool(forKey: "dailyProjectUnpinDone") else { return }

        let descriptor = FetchDescriptor<Project>()
        let all = (try? modelContext.fetch(descriptor)) ?? []

        for project in all where project.name == "日常收支" && project.isPinned {
            project.isPinned = false
        }

        save()
        refreshProjects()
        UserDefaults.standard.set(true, forKey: "dailyProjectUnpinDone")
    }

    /// 迁移：为个人生活成本分类设置 isDirectCost = false
    private func migrateV7CostCategory() {
        guard !UserDefaults.standard.bool(forKey: "costCategoryMigrationV7Done") else { return }

        let personalCategories = ["餐饮", "外卖", "零食", "饮品", "水果", "蔬菜", "买菜",
                                  "娱乐", "游戏", "追星", "电影票", "烟酒", "麻将",
                                  "购物", "服饰", "美容", "数码",
                                  "交通", "汽车", "摩托", "加油费", "租赁",
                                  "旅行", "社交", "礼物", "红包", "礼金",
                                  "医疗", "育儿", "长辈", "宠物"]

        let allCats = (try? modelContext.fetch(FetchDescriptor<Category>())) ?? []
        for cat in allCats {
            if personalCategories.contains(cat.name) {
                cat.isDirectCost = false
            }
        }

        save()
        refreshCategories()
        UserDefaults.standard.set(true, forKey: "costCategoryMigrationV7Done")
    }

    /// 迁移：为旧项目设置默认 projectMode = "lifestyle"
    private func migrateV6ProjectMode() {
        guard !UserDefaults.standard.bool(forKey: "projectModeMigrationV6Done") else { return }

        let descriptor = FetchDescriptor<Project>()
        let all = (try? modelContext.fetch(descriptor)) ?? []

        for project in all {
            // 新字段都有默认值，这里主要确保 projectMode 不为空
            if project.projectMode.isEmpty {
                project.projectMode = "lifestyle"
            }
        }

        save()
        refreshProjects()
        UserDefaults.standard.set(true, forKey: "projectModeMigrationV6Done")
    }
    
    // MARK: - 初始化检查
    
    /// 执行一次性初始化检查（Grandfathering检测）
    func initialize() {
        // 仅执行一次（UserDefaults flag 保护）
        if !UserDefaults.standard.bool(forKey: "grandfatheringChecked") {
            let count = activeProjects.count + archivedProjects.count
            if count > 3 {
                UserDefaults.standard.set(true, forKey: "hasGrandfatheredProjects")
                #if DEBUG
                print("✅ Grandfathering检测: 老用户，已有\(count)个项目")
                #endif
            }
            UserDefaults.standard.set(true, forKey: "grandfatheringChecked")
        }

        checkAndGrantLegacyGiftIfNeeded()
    }

    // MARK: - 老用户会员福利（Legacy Gift）

    /// 老用户判定截止日期：此日期之前有记账记录的用户才算"老用户"
    private static let legacyUserCutoffDate: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        return calendar.date(from: DateComponents(year: 2026, month: 7, day: 18)) ?? .distantPast
    }()

    /// 福利领取截止日期：此日期之后不再发放福利
    private static let legacyGiftClaimDeadline: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        return calendar.date(from: DateComponents(year: 2026, month: 8, day: 9)) ?? .distantFuture
    }()

    /// 每次启动检测：是否为老用户，若是则发放 6 个月会员体验期 + 插入消息中心通知
    /// 超过截止日期后此脚本不再执行
    private func checkAndGrantLegacyGiftIfNeeded() {
        // 超过领取截止时间，不再检测
        guard Date() < Self.legacyGiftClaimDeadline else { return }

        // 已经领取过（可能是从其他设备通过 CloudKit 同步过来的记录），不重复发放
        let grantDescriptor = FetchDescriptor<LegacyGiftGrant>()
        let existingGrants = (try? modelContext.fetch(grantDescriptor)) ?? []
        if existingGrants.contains(where: { $0.isGranted }) {
            #if DEBUG
            print("ℹ️ 老用户福利: 已在其他设备领取过，跳过")
            #endif
            return
        }

        // 判断是否存在早于截止日期的记账记录
        let cutoffDate = Self.legacyUserCutoffDate
        var txDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date < cutoffDate }
        )
        txDescriptor.fetchLimit = 1
        let hasLegacyTransaction = !((try? modelContext.fetch(txDescriptor)) ?? []).isEmpty

        guard hasLegacyTransaction else {
            #if DEBUG
            print("ℹ️ 老用户福利: 首次检查无记录，5秒后重试（等待 CloudKit 同步）")
            #endif
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                self?.retryCheckAndGrantLegacyGift(attempt: 1)
            }
            return
        }

        // 发放福利
        let now = Date()
        let grant = existingGrants.first ?? LegacyGiftGrant()
        grant.isGranted = true
        grant.grantedAt = now
        grant.expiresAt = Calendar.current.date(byAdding: .month, value: 6, to: now)
        if existingGrants.isEmpty {
            modelContext.insert(grant)
        }

        // 插入消息中心通知（若已存在同 ID 通知则不重复插入）
        let noticeID = AppNoticeData.legacyGiftLetter.id
        let noticeDescriptor = FetchDescriptor<AppNotice>(predicate: #Predicate<AppNotice> { $0.noticeID == noticeID })
        let existingNotices = (try? modelContext.fetch(noticeDescriptor)) ?? []
        if existingNotices.isEmpty {
            let notice = AppNotice(noticeID: noticeID, title: AppNoticeData.legacyGiftLetter.title, receivedAt: now, isRead: false)
            modelContext.insert(notice)
        }

        save()
        refreshNotices()

        // 通知 UI 层：本次需要自动弹出一次感谢信
        UserDefaults.standard.set(true, forKey: "legacyGiftShouldAutoPresent")
        // 通知 StoreManager 重新计算会员状态
        NotificationCenter.default.post(name: .legacyGiftGranted, object: nil)

        // 发放后调度事后核查（以防 CloudKit 延迟同步了更早的授权记录）
        schedulePostGrantReconciliation()

        #if DEBUG
        let expiry = grant.expiresAt?.description ?? "-"
        print("✅ 老用户福利: 发放成功，体验期至 \(expiry)")
        #endif
    }
    
    /// 重试检测：等待 CloudKit 同步完成后再次检查，最多重试3次（5秒、15秒、30秒）
    ///
    /// 重要防重逻辑：当发现"有老交易但无授权记录"时，不在 attempt 1/2 立即发放，
    /// 而是继续等待授权记录从 CloudKit 同步过来（授权记录比交易记录慢到）。
    /// 仅在 attempt 3（距首次检查约 50 秒）仍无授权记录时才真正发放。
    /// 这样可防止重装 App + 网络延迟导致原有授权记录被覆盖、截止日期向后偏移。
    private func retryCheckAndGrantLegacyGift(attempt: Int) {
        guard Date() < Self.legacyGiftClaimDeadline else { return }

        let grantDescriptor = FetchDescriptor<LegacyGiftGrant>()
        let existingGrants = (try? modelContext.fetch(grantDescriptor)) ?? []

        // 已有有效授权（可能刚从 CloudKit 同步过来），更新会员状态 + 触发弹窗，然后跳过发放
        if existingGrants.contains(where: { $0.isGranted }) {
            // 更新 StoreManager 的 isPremium（否则要等下次启动才刷新）
            StoreManager.shared.refreshLegacyGiftStatus()
            // 通知 ContentView 重新检查是否需要弹出感谢信
            NotificationCenter.default.post(name: .legacyGiftGranted, object: nil)
            #if DEBUG
            print("ℹ️ 老用户福利: 重试时发现 CloudKit 已同步授权记录，已更新会员状态并触发弹窗检查")
            #endif
            return
        }

        let cutoffDate = Self.legacyUserCutoffDate
        var txDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date < cutoffDate }
        )
        txDescriptor.fetchLimit = 1
        let hasLegacyTransaction = !((try? modelContext.fetch(txDescriptor)) ?? []).isEmpty

        // 没有老交易记录 → 继续等待 CloudKit 同步（可能确实是新用户）
        guard hasLegacyTransaction else {
            if attempt < 3 {
                let delays = [15, 30]
                let delay = delays[attempt - 1]
                #if DEBUG
                print("ℹ️ 老用户福利: 第\(attempt)次重试无记录，\(delay)秒后再试")
                #endif
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay)) { [weak self] in
                    self?.retryCheckAndGrantLegacyGift(attempt: attempt + 1)
                }
            } else {
                #if DEBUG
                print("ℹ️ 老用户福利: 3次重试均无记录，判定为新用户（可能CloudKit同步失败或确实是新用户）")
                #endif
            }
            return
        }

        // ⚠️ 关键防重：有老交易但授权记录尚未到达
        // attempt 1/2 时继续等待，给授权记录同步时间；attempt 3 才确认发放
        // 场景：重装 App 后交易记录同步快（已有大量记录），授权记录同步慢（只有 1 条）
        if existingGrants.isEmpty && attempt < 3 {
            let extraDelay = attempt == 1 ? 20 : 25
            #if DEBUG
            print("ℹ️ 老用户福利: 第\(attempt)次重试 — 有老交易但授权记录未到，等\(extraDelay)秒确认（防止重复发放）")
            #endif
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(extraDelay)) { [weak self] in
                self?.retryCheckAndGrantLegacyGift(attempt: attempt + 1)
            }
            return
        }

        // attempt == 3 或授权确实不存在 → 正式发放
        let now = Date()
        let grant = existingGrants.first ?? LegacyGiftGrant()
        grant.isGranted = true
        grant.grantedAt = now
        grant.expiresAt = Calendar.current.date(byAdding: .month, value: 6, to: now)
        if existingGrants.isEmpty {
            modelContext.insert(grant)
        }

        let noticeID = AppNoticeData.legacyGiftLetter.id
        let noticeDescriptor = FetchDescriptor<AppNotice>(predicate: #Predicate<AppNotice> { $0.noticeID == noticeID })
        let existingNotices = (try? modelContext.fetch(noticeDescriptor)) ?? []
        if existingNotices.isEmpty {
            let notice = AppNotice(noticeID: noticeID, title: AppNoticeData.legacyGiftLetter.title, receivedAt: now, isRead: false)
            modelContext.insert(notice)
        }

        save()
        refreshNotices()
        UserDefaults.standard.set(true, forKey: "legacyGiftShouldAutoPresent")
        NotificationCenter.default.post(name: .legacyGiftGranted, object: nil)

        // 发放后调度事后核查：若 CloudKit 延迟同步了更早的授权记录，自动修正截止日期
        schedulePostGrantReconciliation()

        #if DEBUG
        let retryExpiry = grant.expiresAt?.description ?? "-"
        print("✅ 老用户福利: 重试发放成功（attempt \(attempt)），体验期至 \(retryExpiry)")
        #endif
    }

    /// 发放后 120 秒调度一次核查：
    /// 若 CloudKit 延迟同步了更早的授权记录（重装时原始记录迟到），保留 grantedAt 最早的那条
    private func schedulePostGrantReconciliation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 120) { [weak self] in
            self?.reconcileDuplicateLegacyGrants()
        }
    }

    /// 去重核查：若存在多条有效授权（重装+CloudKit延迟可能产生），保留最早那条并删除多余的
    private func reconcileDuplicateLegacyGrants() {
        let descriptor = FetchDescriptor<LegacyGiftGrant>()
        let allGrants = (try? modelContext.fetch(descriptor)) ?? []
        let validGrants = allGrants.filter { $0.isGranted }
        guard validGrants.count > 1 else { return }

        // 保留 grantedAt 最早的授权（原始发放时间），删除后续重复产生的
        guard let earliest = validGrants.min(by: {
            ($0.grantedAt ?? .distantFuture) < ($1.grantedAt ?? .distantFuture)
        }) else { return }

        for grant in validGrants where grant !== earliest {
            modelContext.delete(grant)
        }
        save()
        StoreManager.shared.refreshLegacyGiftStatus()

        #if DEBUG
        print("🔧 老用户福利核查: 发现 \(validGrants.count) 条重复授权，已合并，保留最早记录（grantedAt: \(earliest.grantedAt?.description ?? "-")，expiresAt: \(earliest.expiresAt?.description ?? "-")）")
        #endif
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
        refreshCategories()
    }

    // MARK: - Receivable CRUD（应收账款）
    
    @discardableResult
    func addReceivable(to project: Project, clientName: String, projectName: String,
                       amount: Double, expectedDate: Date? = nil, note: String = "") -> Receivable {
        let receivable = Receivable(clientName: clientName, projectName: projectName,
                                    amount: amount, expectedDate: expectedDate, note: note)
        receivable.project = project
        project.receivables = (project.receivables ?? []) + [receivable]
        modelContext.insert(receivable)
        save()
        refreshProjects()
        bumpDataVersion()
        return receivable
    }

    func updateReceivable(_ receivable: Receivable, clientName: String? = nil,
                          projectName: String? = nil, amount: Double? = nil,
                          expectedDate: Date? = nil, note: String? = nil) {
        if let name = clientName { receivable.clientName = name }
        if let project = projectName { receivable.projectName = project }
        if let amt = amount { receivable.amount = amt }
        if let date = expectedDate { receivable.expectedDate = date }
        if let n = note { receivable.note = n }
        save()
        refreshProjects()
        bumpDataVersion()
    }

    func markReceivable(_ receivable: Receivable, received: Bool) {
        if received {
            receivable.rawStatus = ReceivableStatus.received.rawValue
            receivable.receivedDate = Date()
        } else {
            receivable.rawStatus = ReceivableStatus.pending.rawValue
            receivable.receivedDate = nil
        }
        save()
        refreshProjects()
        bumpDataVersion()
    }

    func deleteReceivable(_ receivable: Receivable) {
        if let project = receivable.project {
            project.receivables = (project.receivables ?? []).filter { $0.id != receivable.id }
        }
        modelContext.delete(receivable)
        save()
        refreshProjects()
        bumpDataVersion()
    }

    // MARK: - FixedCost CRUD（固定成本）

    @discardableResult
    func addFixedCost(to project: Project, name: String, amount: Double,
                      frequency: FixedCostFrequency = .monthly, category: String = "",
                      nextDueDate: Date? = nil) -> FixedCost {
        let fixedCost = FixedCost(name: name, amount: amount, frequency: frequency,
                                  category: category, nextDueDate: nextDueDate)
        fixedCost.project = project
        project.fixedCosts = (project.fixedCosts ?? []) + [fixedCost]
        modelContext.insert(fixedCost)
        save()
        refreshProjects()
        bumpDataVersion()
        return fixedCost
    }

    func updateFixedCost(_ fixedCost: FixedCost, name: String? = nil, amount: Double? = nil,
                         frequency: FixedCostFrequency? = nil, category: String? = nil,
                         nextDueDate: Date? = nil) {
        if let n = name { fixedCost.name = n }
        if let amt = amount { fixedCost.amount = amt }
        if let freq = frequency { fixedCost.rawFrequency = freq.rawValue }
        if let cat = category { fixedCost.category = cat }
        if let date = nextDueDate { fixedCost.nextDueDate = date }
        save()
        refreshProjects()
        bumpDataVersion()
    }

    func toggleFixedCost(_ fixedCost: FixedCost) {
        fixedCost.isActive.toggle()
        save()
        refreshProjects()
        bumpDataVersion()
    }

    func deleteFixedCost(_ fixedCost: FixedCost) {
        if let project = fixedCost.project {
            project.fixedCosts = (project.fixedCosts ?? []).filter { $0.id != fixedCost.id }
        }
        modelContext.delete(fixedCost)
        save()
        refreshProjects()
        bumpDataVersion()
    }
}
