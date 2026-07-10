import SwiftUI
import SwiftData
struct ProjectDetailView: View {
    let project: Project
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.presentationMode) var presentationMode
    @State private var editingTransaction: Transaction?
    @State private var viewingTransaction: Transaction?
    @State private var showColorPicker = false
    @State private var showEditProject = false
    @State private var showDeleteConfirm = false
    @State private var showUpgradeAlert = false

    // MARK: 新增状态
    @State private var showPaywall = false
    @State private var showBudgetManagement = false
    @State private var showArchiveReview = false
    @State private var showEarningDashboard = false
    @State private var showLifestyleDashboard = false
    
    // MARK: - 缓存数据
    @State private var _groupedTransactions: [(key: String, value: [Transaction])] = []
    @State private var _projectCategorySegments: [(name: String, amount: Double, colorHex: String, icon: String)] = []
    @State private var _projectTotalExpense: Double = 0
    @State private var _projectTrendData: [(label: String, expense: Double, income: Double, saving: Double)] = []
    // 概览数字缓存（避免 body 多次访问 project.totalSpent 等计算属性反复遍历账单）
    @State private var _totalSpent: Double = 0
    @State private var _totalIncome: Double = 0
    @State private var _budgetProgress: Double = 0
    
    // MARK: - 静态 DateFormatter（避免 body 每次重渲时重复创建）
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy年M月d日"
        return f
    }()
    
    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M月"
        return f
    }()
    
    // 按日期分组的交易记录
    private var groupedTransactions: [(key: String, value: [Transaction])] { _groupedTransactions }
    
    // 进度条同色系色对
    private var colorPair: ProgressColorPair {
        progressColorPair(for: project.colorHex)
    }
    private var accentColor: Color { Color(hex: colorPair.end) }

    // MARK: - 项目内分类占比数据
    private var projectCategorySegments: [(name: String, amount: Double, colorHex: String, icon: String)] { _projectCategorySegments }
    private var projectTotalExpense: Double { _projectTotalExpense }

    // MARK: - 项目收支趋势数据（按月）
    private var projectTrendData: [(label: String, expense: Double, income: Double, saving: Double)] { _projectTrendData }
    
    private func reloadCache() {
        Task { @MainActor in updateCacheData() }
    }

    private func updateCacheData() {
        let txs = project.transactions ?? []
        
        // 0. 概览汇总（一次遍历算出总支出/总收入）
        var totalExp: Double = 0
        var totalInc: Double = 0
        for tx in txs {
            if tx.type == .expense { totalExp += abs(tx.amount) }
            else if tx.type == .income { totalInc += abs(tx.amount) }
        }
        _totalSpent = totalExp
        _totalIncome = totalInc
        _budgetProgress = project.budget > 0 ? totalExp / project.budget : 0
        
        // 1. 分组交易记录
        let sorted = txs.sorted { $0.date > $1.date }
        var groups: [String: [Transaction]] = [:]
        for tx in sorted {
            let key = Self.dayFormatter.string(from: tx.date)
            groups[key, default: []].append(tx)
        }
        _groupedTransactions = groups.sorted { $0.key > $1.key }
        
        // 2. 分类占比
        let expenses = txs.filter { $0.type == .expense }
        var dict: [String: (amount: Double, color: String, icon: String)] = [:]
        for tx in expenses {
            let name = tx.categoryName
            let color = tx.categoryColorHex
            let icon = tx.categoryIcon
            let current = dict[name]?.amount ?? 0
            dict[name] = (current + abs(tx.amount), color, icon)
        }
        _projectCategorySegments = dict.map { (name: $0.key, amount: $0.value.amount, colorHex: $0.value.color, icon: $0.value.icon) }.sorted { $0.amount > $1.amount }
        _projectTotalExpense = _projectCategorySegments.reduce(0) { $0 + $1.amount }
        
        // 3. 趋势数据
        let calendar = Calendar.current
        let ascSorted = txs.sorted { $0.date < $1.date }
        if let first = ascSorted.first {
            let startDate = first.date
            let endDate = Date()
            var result: [(label: String, expense: Double, income: Double, saving: Double)] = []
            var current = calendar.date(from: calendar.dateComponents([.year, .month], from: startDate))!

            while current <= endDate {
                let next = calendar.date(byAdding: .month, value: 1, to: current)!
                let monthTxs = txs.filter { $0.date >= current && $0.date < next }
                let exp = monthTxs.filter { $0.type == .expense }.reduce(0) { $0 + abs($1.amount) }
                let inc = monthTxs.filter { $0.type == .income }.reduce(0) { $0 + abs($1.amount) }
                result.append((label: Self.monthFormatter.string(from: current), expense: exp, income: inc, saving: inc - exp))
                current = next
            }
            _projectTrendData = result
        } else {
            _projectTrendData = []
        }
    }

    // MARK: - 项目分类占比卡片
    private var projectCategoryDonutCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("分类占比")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(Color.App.textBlack)
                Spacer()
                Text("支出明细")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)
            }

            if projectTotalExpense == 0 {
                HStack(spacing: 10) {
                    Text("🦫").font(.system(size: 20))
                    Text("暂无支出记录").font(.system(size: 14, weight: .medium)).foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                DonutChartView(segments: projectCategorySegments, total: projectTotalExpense)
                    .frame(height: 200)

                VStack(spacing: 10) {
                    ForEach(projectCategorySegments.prefix(6), id: \.name) { seg in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color(hex: seg.colorHex))
                                .frame(width: 10, height: 10)
                            Text(seg.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.App.textBlack.opacity(0.8))
                            Spacer()
                            Text("¥\(seg.amount.formatted(.number.precision(.fractionLength(0))))")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.App.textBlack)
                            Text("(\(Int(seg.amount / projectTotalExpense * 100))%)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
        .padding(24)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
        .padding(.horizontal, 24)
    }

    // MARK: - 项目收支趋势卡片
    private var projectTrendCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("收支趋势")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(Color.App.textBlack)
                Spacer()
                Text("按月汇总")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)
            }

            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    Capsule().fill(Color.App.primaryGreen).frame(width: 20, height: 4)
                    Text("支出").font(.system(size: 12, weight: .bold)).foregroundColor(.gray)
                }
                HStack(spacing: 6) {
                    Capsule().fill(Color.App.lightOrange).frame(width: 20, height: 4)
                    Text("收入").font(.system(size: 12, weight: .bold)).foregroundColor(.gray)
                }
            }

            if projectTrendData.isEmpty || projectTrendData.allSatisfy({ $0.expense == 0 && $0.income == 0 }) {
                HStack(spacing: 10) {
                    Text("🦫").font(.system(size: 20))
                    Text("暂无趋势数据").font(.system(size: 14, weight: .medium)).foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                AreaChartView(data: projectTrendData)
                    .frame(height: 150)

                HStack {
                    ForEach(projectTrendData.suffix(6), id: \.label) { item in
                        Text(item.label)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(24)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
        .padding(.horizontal, 24)
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: 自定义顶部导航栏
            ZStack {
                // 标题居中（两侧对称留出返回按钮宽度）
                Text(project.name)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundColor(Color.App.textBlack)
                    .lineLimit(1)
                    .padding(.horizontal, 80) // 两侧各留80pt给返回按钮
                
                // 左侧返回按钮 + 右侧菜单
                HStack {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .bold))
                            Text("返回")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(accentColor)
                    }
                    Spacer()
                    Menu {
                        Button { showEditProject = true } label: {
                            Label("编辑项目", systemImage: "pencil")
                        }
                        if project.isArchived {
                            Button { store.toggleArchive(project: project) } label: {
                                Label("取消归档", systemImage: "archivebox")
                            }
                        } else {
                            Button { showArchiveReview = true } label: {
                                Label("归档并复盘", systemImage: "archivebox.fill")
                            }
                        }
                        Divider()
                        Button(role: .destructive) { showDeleteConfirm = true } label: {
                            Label("删除项目", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(accentColor)
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 44)
            .padding(.top, 8)
            .background(Color.App.backgroundGray)
            
            // MARK: 主内容滚动区
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // 项目概览卡片
                    VStack(alignment: .leading, spacing: 20) {
                        // 项目图标 + 描述 + 模式切换
                        HStack(spacing: 14) {
                            ZStack(alignment: .bottomTrailing) {
                                Circle()
                                    .fill(Color(hex: project.colorHex).opacity(0.3))
                                    .frame(width: 56, height: 56)
                                    .overlay(
                                        AppIconView(name: project.icon, size: 24,
                                                    color: Color.App.projectIconColor(for: project.colorHex))
                                    )
                                Circle()
                                    .fill(Color.App.cardBackground)
                                    .frame(width: 22, height: 22)
                                    .overlay(
                                        Image(systemName: "paintpalette.fill")
                                            .font(.system(size: 11))
                                            .foregroundColor(accentColor)
                                    )
                                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                    .onTapGesture { showColorPicker = true }
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Text(project.name)
                                        .font(.system(size: 20, weight: .heavy))
                                        .foregroundColor(Color.App.textBlack)
                                    // 模式切换标签
                                    Button {
                                        let newMode = projectModeEnum == .earning ? "lifestyle" : "earning"
                                        store.updateProject(project, name: project.name, icon: project.icon,
                                                           colorHex: project.colorHex, desc: project.desc,
                                                           budget: project.budget, projectMode: newMode)
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: projectModeEnum == .earning ? "briefcase.fill" : "heart.fill")
                                                .font(.system(size: 10, weight: .bold))
                                            Text(projectModeEnum == .earning ? "搞钱" : "生活")
                                                .font(.system(size: 11, weight: .bold))
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(projectModeEnum == .earning ? Color.App.darkGreen : Color(hex: "#FF6B9D"))
                                        .clipShape(Capsule())
                                    }
                                }
                                if !project.desc.isEmpty {
                                    Text(project.desc)
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
                                        .lineSpacing(3)
                                }
                            }
                        }
                        
                        // 收支汇总
                        HStack(spacing: 12) {
                            StatCard(title: "总支出", value: _totalSpent, color: Color.App.redExpense)
                            StatCard(title: "总收入", value: _totalIncome, color: Color.App.darkGreen)
                            let netIncome = _totalIncome - _totalSpent
                            StatCard(title: "净收益", value: netIncome, color: netIncome >= 0 ? Color.App.darkGreen : Color.App.redExpense)
                        }
                        

                    }
                    .padding(24)
                    .background(Color.App.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                    .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
                    .padding(.horizontal, 24)

                    // MARK: ⑤ 看板入口卡片
                    dashboardEntryCard

                    // MARK: ② 预算分类卡片
                    budgetCategoryCard

                    // MARK: 项目内分类占比
                    projectCategoryDonutCard

                    // MARK: 项目收支趋势
                    projectTrendCard

                    // MARK: 账单时间轴
                    LazyVStack(alignment: .leading, spacing: 0) {
                        Text("账单时间轴")
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundColor(Color.App.textBlack)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 16)
                        
                        if groupedTransactions.isEmpty {
                            Text("还没有任何记录，点击 + 记一笔吧！")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 24)
                        } else {
                            ForEach(groupedTransactions, id: \.key) { group in
                                LazyVStack(alignment: .leading, spacing: 0) {
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(Color(hex: project.colorHex))
                                            .frame(width: 10, height: 10)
                                        Text(group.key)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.leading, 24)
                                    .padding(.bottom, 10)
                                    
                                    LazyVStack(spacing: 10) {
                                        ForEach(group.value) { tx in
                                            SwipeActionView(
                                                onEdit: { editingTransaction = tx },
                                                onDelete: { store.deleteTransaction(tx) }
                                            ) {
                                                TimelineTxRow(transaction: tx, accentColor: Color(hex: project.colorHex))
                                                    .contentShape(Rectangle())
                                                    .onTapGesture {
                                                        viewingTransaction = tx
                                                    }
                                            }
                                            .padding(.horizontal, 24)
                                        }
                                    }
                                    .padding(.bottom, 20)
                                }
                            }
                        }
                    }
                    
                    Spacer().frame(height: 120)
                }
                .padding(.top, 16)
            }
        }
        .background(Color.App.backgroundGray.ignoresSafeArea())
        .sheet(item: $editingTransaction) { tx in
            EditTransactionView(transaction: tx)
                .environmentObject(store)
        }
        .sheet(item: $viewingTransaction) { tx in
            TransactionDetailView(transaction: tx)
                .environmentObject(store)
        }
        .sheet(isPresented: $showColorPicker) {
            EditProjectColorSheet(project: project, store: store)
        }
        .sheet(isPresented: $showEditProject) {
            EditProjectView(project: project)
                .environmentObject(store)
        }
        .confirmationDialog("确认删除该项目？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                store.deleteProject(project)
                presentationMode.wrappedValue.dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后项目内所有账单将被一并清除，且无法恢复。")
        }
        .alert("升级到专业版", isPresented: $showUpgradeAlert) {
            Button("取消", role: .cancel) { }
            Button("查看订阅方案") { showPaywall = true }
        } message: {
            Text("专业版用户可以解锁预算预警、经营看板、ROI 分析等高级功能！")
        }
        .fullScreenCover(isPresented: $showBudgetManagement) {
            NavigationView {
                BudgetManagementSheet(
                    project: project,
                    onShowPaywall: { showPaywall = true }
                )
                .environmentObject(store)
                .environmentObject(storeManager)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("关闭") { showBudgetManagement = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showArchiveReview) {
            ProjectReviewSheet(
                project: project,
                projectMode: projectModeEnum,
                onArchive: {
                    store.toggleArchive(project: project)
                    showArchiveReview = false
                    presentationMode.wrappedValue.dismiss()
                },
                onShowPaywall: { showPaywall = true }
            )
            .environmentObject(storeManager)
        }
        .fullScreenCover(isPresented: $showEarningDashboard) {
            ProjectEarningView(
                project: project,
                onShowPaywall: { showPaywall = true }
            )
            .environmentObject(store)
            .environmentObject(storeManager)
        }
        .fullScreenCover(isPresented: $showLifestyleDashboard) {
            ProjectLifestyleView(
                project: project,
                onShowPaywall: { showPaywall = true }
            )
            .environmentObject(store)
            .environmentObject(storeManager)
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView().environmentObject(storeManager)
        }
        .navigationBarHidden(true)
        .onAppear {
            updateCacheData()
        }
        // 增删：count 变化
        .onChange(of: project.transactions?.count) { _, _ in reloadCache() }
        // 编辑金额（count 不变，但弹窗关闭时数据已写入 CoreData）
        .onChange(of: editingTransaction != nil) { _, isPresented in
            if !isPresented { reloadCache() }
        }
        // CloudKit 同步兜底：月度汇总变化时也刷新
        .onChange(of: store.monthlyExpense) { _, _ in reloadCache() }
    }
}

// MARK: - ② 预算分类卡片
extension ProjectDetailView {
    var budgetCategoryCard: some View {
        let budgetItems = project.budgetItems ?? []
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("预算分类")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(Color.App.textBlack)
                Spacer()
                if !budgetItems.isEmpty {
                    Button("管理分类 ›") { showBudgetManagement = true }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                }
            }

            if budgetItems.isEmpty {
                // 空状态
                VStack(spacing: 14) {
                    HStack(spacing: 10) {
                        Text("🦫").font(.system(size: 20))
                        Text("还没有设置预算分类")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    HStack(spacing: 12) {
                        // AI 生成（检查付费状态）
                        Button {
                            if storeManager.isPremium {
                                // Plus 用户：调用 AI 生成
                                generateAIBudgetForProject()
                            } else {
                                showPaywall = true
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: storeManager.isPremium ? "sparkles" : "lock.fill")
                                    .font(.system(size: 12, weight: .bold))
                                Text(storeManager.isPremium ? "AI 生成" : "AI 生成  Plus")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16).padding(.vertical, 9)
                            .background(storeManager.isPremium ? Color.App.darkGreen : Color.gray.opacity(0.5))
                            .clipShape(Capsule())
                        }
                        Button { showBudgetManagement = true } label: {
                            Text("手动添加")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.App.darkGreen)
                                .padding(.horizontal, 16).padding(.vertical, 9)
                                .background(Color.App.primaryGreen.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                // 总进度条
                let totalAllocated = budgetItems.reduce(0) { $0 + $1.amount }
                let totalProg      = totalAllocated > 0 ? min(project.currentCycleSpent / totalAllocated, 1.0) : 0
                let progColor: Color = totalProg >= 1.0 ? Color.App.redExpense
                    : totalProg >= 0.8 ? Color(hex: "#FFA500") : accentColor

                VStack(spacing: 6) {
                    HStack {
                        Text("总进度").font(.system(size: 12, weight: .bold)).foregroundColor(.gray)
                        Spacer()
                        Text("\(Int(totalProg * 100))%")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(progColor)
                    }
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.App.progressTrack).frame(height: 8)
                        Capsule()
                            .fill(LinearGradient(
                                colors: [Color(hex: colorPair.start), Color(hex: colorPair.end)],
                                startPoint: .leading, endPoint: .trailing))
                            .scaleEffect(x: max(0.001, CGFloat(totalProg)), y: 1, anchor: .leading)
                            .frame(height: 8)
                    }
                }

                // 分类列表（最多展示 3 条，超出折叠）
                let displayItems = budgetItems.prefix(3)
                VStack(spacing: 10) {
                    ForEach(displayItems) { item in
                        BudgetProgressRow(item: BudgetItemUI(
                            categoryName: item.categoryName,
                            categoryIcon: item.categoryIcon,
                            categoryColorHex: item.categoryColorHex,
                            amount: item.amount,
                            alertThreshold: item.alertThreshold,
                            spent: calculateSpentForCategory(item.categoryName)
                        ))
                    }
                }
                if budgetItems.count > 3 {
                    Button("展开全部 \(budgetItems.count) 个分类") { showBudgetManagement = true }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                }

                // 未分类支出提示
                let unclassifiedSpent = _totalSpent - project.currentCycleSpent
                if unclassifiedSpent > 0.01 {
                    HStack(spacing: 6) {
                        Image(systemName: "questionmark.circle").font(.system(size: 12))
                        Text("未分类支出 ¥\(Int(unclassifiedSpent))（无对应预算分类）")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.gray)
                    .padding(.top, 4)
                }
            }
        }
        .padding(24)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
        .padding(.horizontal, 24)
    }
    
    private func calculateSpentForCategory(_ categoryName: String) -> Double {
        let startDate = project.currentCycleStartDate
        return (project.transactions ?? [])
            .filter { $0.type == .expense && $0.categoryName == categoryName && $0.date >= startDate }
            .reduce(0) { $0 + abs($1.amount) }
    }
    
    private func generateAIBudgetForProject() {
        Task {
            do {
                let items = try await LLMService.shared.generateBudgetBreakdown(
                    name: project.name,
                    desc: project.desc,
                    supplement: "",
                    totalBudget: project.budget,
                    mode: projectModeEnum == .earning ? "搞钱" : "生活"
                )
                await MainActor.run {
                    for (index, item) in items.enumerated() {
                        store.addBudgetItem(
                            to: project,
                            categoryName: item.categoryName,
                            categoryIcon: item.categoryIcon,
                            categoryColorHex: item.categoryColorHex,
                            amount: item.amount,
                            sortOrder: index,
                            alertThreshold: item.alertThreshold
                        )
                    }
                }
            } catch {
                #if DEBUG
                print("AI预算生成失败: \(error)")
                #endif
            }
        }
    }
}

// MARK: - ⑤ 看板入口卡片
extension ProjectDetailView {
    private var projectModeEnum: ProjectMode {
        project.projectMode == "earning" ? .earning : .lifestyle
    }
    
    @ViewBuilder
    var dashboardEntryCard: some View {
        if projectModeEnum == .earning {
            earningEntryCard
        } else {
            lifestyleEntryCard
        }
    }

    private var earningEntryCard: some View {
        Group {
            if storeManager.isPremium {
                // Plus：显示核心指标预览，点击进全页
                NavigationLink {
                    ProjectDashboardView(project: project)
                        .environmentObject(store)
                        .environmentObject(storeManager)
                } label: {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "briefcase.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(accentColor)
                                Text("经营看板")
                                    .font(.system(size: 20, weight: .heavy))
                                    .foregroundColor(Color.App.textBlack)
                            }
                            Spacer()
                            Text("查看 ›")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gray)
                        }
                        
                        // 4个主指标
                        HStack(spacing: 0) {
                            earningMetricCell(title: "可用资金",
                                            value: "¥\(Int(project.availableCash))",
                                            color: project.availableCash >= 0 ? Color.App.darkGreen : Color.App.redExpense)
                            Divider().frame(height: 36)
                            earningMetricCell(title: "本月净现金流",
                                            value: "¥\(Int(project.monthlyNetCashFlow))",
                                            color: project.monthlyNetCashFlow >= 0 ? Color.App.darkGreen : Color.App.redExpense)
                            Divider().frame(height: 36)
                            earningMetricCell(title: "毛利率",
                                            value: "\(Int(project.grossMargin * 100))%",
                                            color: project.grossMargin >= 0 ? Color.App.darkGreen : Color.App.redExpense)
                        }
                        
                        // 2个辅助小字
                        HStack(spacing: 16) {
                            Text("可支配收入: ¥\(Int(project.disposableIncome))")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            
                            if project.totalReceivable > 0 {
                                Text("待回款: ¥\(Int(project.totalReceivable))")
                                    .font(.system(size: 12))
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding(24)
                    .background(Color.App.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                    .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
                    .padding(.horizontal, 24)
                }
                .buttonStyle(.plain)
            } else {
                PlusLockedEntryCard(
                    icon: "briefcase.fill",
                    title: "经营看板",
                    description: "四维度经营分析，看清这个项目到底赚没赚、剩多少。",
                    features: ["现金流 · 收入确认 · 成本拆分", "利润瀑布 · 毛利率 · 可支配收入", "应收账款 · 固定成本 · 趋势图表"],
                    onUnlock: { showPaywall = true }
                )
            }
        }
    }

    private var lifestyleEntryCard: some View {
        Button { showLifestyleDashboard = true } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(accentColor)
                        Text("预算防线")
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundColor(Color.App.textBlack)
                    }
                    Spacer()
                    Text("查看 ›")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                }
                if project.budget > 0 {
                    let remaining = max(project.budget - _totalSpent, 0)
                    let prog = min(_budgetProgress, 1.0)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("剩余预算")
                                .font(.system(size: 11, weight: .bold)).foregroundColor(.gray)
                            Text("¥\(Int(remaining))")
                                .font(.system(size: 22, weight: .heavy))
                                .foregroundColor(Color.App.textBlack)
                        }
                        Spacer()
                        Text("已用 \(Int(_budgetProgress * 100))%")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(_budgetProgress >= 0.9 ? Color.App.redExpense
                                : _budgetProgress >= 0.7 ? Color(hex: "#FFA500") : accentColor)
                    }
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.App.progressTrack).frame(height: 8)
                        Capsule()
                            .fill(LinearGradient(
                                colors: _budgetProgress >= 0.9
                                    ? [Color.App.redExpense.opacity(0.7), Color.App.redExpense]
                                    : [Color(hex: colorPair.start), Color(hex: colorPair.end)],
                                startPoint: .leading, endPoint: .trailing))
                            .scaleEffect(x: max(0.001, CGFloat(prog)), y: 1, anchor: .leading)
                            .frame(height: 8)
                    }
                } else {
                    Text("未设置预算，点击查看消费结构分析")
                        .font(.system(size: 13)).foregroundColor(.gray)
                }
            }
            .padding(24)
            .background(Color.App.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
            .padding(.horizontal, 24)
        }
        .buttonStyle(.plain)
    }

    private func earningMetricCell(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .bold)).foregroundColor(.gray)
            Text(value)
                .font(.system(size: 15, weight: .heavy)).foregroundColor(color)
                .minimumScaleFactor(0.7).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 统计小卡片
struct StatCard: View {
    let title: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
            Text("¥\(abs(value).formatted(.number.precision(.fractionLength(0))))")
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(value < 0 ? Color.App.redExpense : color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Timeline 账单行
struct TimelineTxRow: View {
    let transaction: Transaction
    let accentColor: Color
    
    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color(hex: transaction.categoryColorHex).opacity(0.3))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: transaction.categoryIcon)
                        .foregroundColor(Color(hex: transaction.categoryColorHex))
                        .font(.system(size: 18))
                )
            
            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.note.isEmpty ? transaction.categoryName : transaction.note)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.App.textBlack)
                Text("\(transaction.categoryName) · \(transaction.date.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text("\(transaction.type == .expense ? "-" : "+") ¥\(transaction.amount.formatted(.number.precision(.fractionLength(2))))")
                .font(.system(size: 15, weight: .heavy))
                .foregroundColor(transaction.type == .expense ? Color.App.redExpense : Color.App.darkGreen)
        }
        .padding(14)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 3)
    }
}

// MARK: - 编辑项目颜色 Sheet
struct EditProjectColorSheet: View {
    let project: Project
    let store: AppStore
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedColor: String

    init(project: Project, store: AppStore) {
        self.project = project
        self.store = store
        _selectedColor = State(initialValue: project.colorHex)
    }

    private var accentColor: Color {
        Color(hex: progressColorPair(for: selectedColor).end)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 28) {
                Circle()
                    .fill(Color(hex: selectedColor).opacity(0.3))
                    .frame(width: 80, height: 80)
                    .overlay(
                        AppIconView(name: project.icon, size: 32,
                                    color: Color.App.projectIconColor(for: selectedColor))
                    )

                Text("选择项目颜色")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.App.textBlack)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
                    ForEach(Color.App.Morandi.allHexes, id: \.self) { hex in
                        Button(action: { selectedColor = hex }) {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Circle()
                                        .stroke(Color.App.darkGreen, lineWidth: selectedColor == hex ? 3 : 0)
                                        .padding(2)
                                )
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(Color(hex: progressColorPair(for: hex).end))
                                        .opacity(selectedColor == hex ? 1 : 0)
                                )
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .padding(.top, 32)
            .background(Color.App.backgroundGray.ignoresSafeArea())
            .navigationTitle("更换颜色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        store.updateProjectColor(project, colorHex: selectedColor)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 16, weight: .bold))
                    .disabled(selectedColor == project.colorHex)
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        ProjectDetailView(project: Project(name: "示例项目", icon: "house.fill", colorHex: "#A8E6CF", desc: "这是一个测试项目", budget: 10000))
            .environmentObject(AppStore(modelContext: try! ModelContainer(for: Project.self, Transaction.self, Category.self, ChatHistory.self, MemoryRule.self).mainContext))
    }
}
