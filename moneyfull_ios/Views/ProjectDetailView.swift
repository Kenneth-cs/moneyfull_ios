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
                        Button { store.toggleArchive(project: project) } label: {
                            Label(project.isArchived ? "取消归档" : "归档项目",
                                  systemImage: "archivebox")
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
                        // 项目图标 + 描述（不再重复项目名，导航栏已显示）
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
                                Text(project.name)
                                    .font(.system(size: 20, weight: .heavy))
                                    .foregroundColor(Color.App.textBlack)
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
                        
                        // 预算进度条（同色系渐变）
                        if project.budget > 0 {
                            let progress = min(_budgetProgress, 1.0)
                            let pctColor: Color = _budgetProgress >= 1.0 ? Color.App.redExpense :
                                _budgetProgress >= 0.8 ? Color(hex: "#FFA500") : accentColor
                            
                            VStack(spacing: 8) {
                                HStack {
                                    Text("预算进度")
                                        .font(.system(size: 13, weight: .bold)).foregroundColor(.gray)
                                    Spacer()
                                    Text("\(Int(_budgetProgress * 100))%")
                                        .font(.system(size: 13, weight: .bold)).foregroundColor(pctColor)
                                }
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.App.progressTrack)
                                    Capsule()
                                        .fill(LinearGradient(
                                            colors: [Color(hex: colorPair.start), Color(hex: colorPair.end)],
                                            startPoint: .leading, endPoint: .trailing
                                        ))
                                        .frame(maxWidth: .infinity)
                                        .scaleEffect(x: max(0.001, CGFloat(progress)), y: 1, anchor: .leading)
                                }
                                .frame(height: 10)
                                HStack {
                                    Text("已用 ¥\(_totalSpent.formatted(.number.precision(.fractionLength(0))))")
                                    Spacer()
                                    Text("预算 ¥\(project.budget.formatted(.number.precision(.fractionLength(0))))")
                                }
                                .font(.system(size: 11, weight: .semibold)).foregroundColor(.gray)
                                
                                // 预算超80%预警提示
                                if _budgetProgress >= 0.8 && !storeManager.isPremium {
                                    Button(action: { showUpgradeAlert = true }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(Color(hex: "#FFA500"))
                                            Text("预算即将超标，升级专业版解锁动态趋势预测")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(Color.App.textBlack)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.gray)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(Color(hex: "#FFA500").opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.top, 8)
                                }
                            }
                        }
                    }
                    .padding(24)
                    .background(Color.App.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                    .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
                    .padding(.horizontal, 24)

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
            Button("查看订阅方案") {
                // TODO: 跳转到订阅页面
            }
        } message: {
            Text("专业版用户可以解锁动态趋势预测、ROI 分析看板等高级功能，帮助你更好地掌控预算！")
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
