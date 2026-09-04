import SwiftUI
import SwiftData
import CloudKit

// 智能金额格式化：整数不显示小数，有小数才保留2位
private func smartFormat(_ value: Double) -> String {
    if value.truncatingRemainder(dividingBy: 1) == 0 {
        return value.formatted(.number.precision(.fractionLength(0)))
    }
    return value.formatted(.number.precision(.fractionLength(2)))
}

// MARK: - Hero 主卡 Tab（总览 / 预算日历）
enum HeroTab { case overview, calendar }

// MARK: - 首页看板时间维度
enum DashboardPeriod: String, CaseIterable {
    case week = "本周"
    case month = "本月"
    case year = "本年"
    case all = "累计"
}

struct DashboardView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var storeManager: StoreManager
    @Binding var selectedTab: Int
    @Binding var detailProject: Project?
    var onResetProjectNav: (() -> Void)? = nil
    @State private var editingTransaction: Transaction?
    @State private var viewingTransaction: Transaction?
    @State private var isAddRecordPresented = false
    @State private var selectedPeriod: DashboardPeriod = .month
    @State private var showPeriodPicker = false
    @State private var showAllTransactions = false
    @State private var heroTab: HeroTab = .overview
    // 气泡与卡皮共享同一个协调器，分别渲染在不同 ZStack 层
    @StateObject private var mascotCoordinator = MascotCoordinator()
    // 里程碑导出提醒 Banner
    @State private var exportBannerMilestone: Int? = nil       // 当前应提示的里程碑，nil = 不展示
    @State private var isCloudAvailable: Bool = true           // iCloud 同步是否正常
    @State private var showExportFromBanner: Bool = false      // Banner 触发的导出 Sheet
    // 预算设置 Sheet
    @State private var isBudgetSheetPresented = false

    // MARK: - 缓存计算结果（避免 body 每次重渲时重复执行耗时操作）
    @State private var _stats: (expense: Double, income: Double, saving: Double) = (0, 0, 0)
    // 预算统计缓存
    @State private var _budgetStats: BudgetStats? = nil

    // MARK: - 计算属性代理（body 直接读缓存，零计算开销）
    private var currentStats: (expense: Double, income: Double, saving: Double) { _stats }

    // MARK: - 核心统计刷新（仅在 dataVersion / 统计维度变化时调用，不在 body 里计算）
    private func updateStats() {
        _stats = store.stats(for: selectedPeriod)
        updateBudgetStats()
    }

    private func updateBudgetStats() {
        let now = Date()
        let cal = Calendar.current
        let year = cal.component(.year, from: now)
        let month = cal.component(.month, from: now)
        guard let budget = HomeBudgetService.budget(year: year, month: month) else {
            _budgetStats = nil
            return
        }
        let daily = store.dailyExpenses(year: year, month: month)
        let today = store.todayExpense()
        _budgetStats = HomeBudgetService.calcStats(budget: budget, dailyExpenses: daily, todayExpense: today)
    }

    // 进行中项目（使用 AppStore 已排序的顺序：置顶 → sortOrder → 创建时间）
    private var sortedActiveProjects: [Project] {
        store.activeProjects
    }

    // MARK: - Hero 卡 Segmented Control
    private var heroSegmentedControl: some View {
        HStack(spacing: 2) {
            segmentBtn("总览",    tab: .overview)
            segmentBtn("预算日历", tab: .calendar)
        }
        .padding(3)
        .background(Color.white.opacity(0.25))
        .clipShape(Capsule())
    }

    // 三个财务指标之间的浅色竖线分隔
    private var financeDivider: some View {
        Rectangle()
            .fill(Color.App.textOnPrimary.opacity(0.15))
            .frame(width: 0.75, height: 30)
    }

    private func segmentBtn(_ label: String, tab: HeroTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) { heroTab = tab }
        } label: {
            Text(label)
                .font(.system(size: 12, weight: heroTab == tab ? .bold : .medium))
                .foregroundColor(heroTab == tab ? Color.App.darkGreen : Color.App.textOnPrimary.opacity(0.65))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(heroTab == tab ? Color.white.opacity(0.92) : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 总览内容（支出金额 + 预算进度 + 财务指标 + 记一笔）
    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: 14) {

            // 大支出金额
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("¥")
                    .font(.system(size: 28, weight: .bold))
                Text(smartFormat(currentStats.expense))
                    .font(.system(size: 40, weight: .bold))
            }
            .foregroundColor(Color.App.textOnPrimary)
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .padding(.trailing, 140)

            // 预算进度区
            if let budgetStats = _budgetStats {
                budgetProgressSection(stats: budgetStats)
            } else {
                // 未设置预算 → 引导文案
                noBudgetGuideSection
            }

            // 三个财务指标（同一张透明白底卡片，内部竖线分隔）
            HStack(spacing: 0) {
                FinanceInfoCard(title: "收入",    value: currentStats.income)
                financeDivider
                FinanceInfoCard(title: "本月结余", value: currentStats.saving)
                financeDivider
                FinanceInfoCard(title: "今日可花", value: _budgetStats?.todayRemainingSpend ?? 0)
            }
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.42))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // 记一笔按钮
            Button(action: {
                AnalyticsManager.shared.trackEvent(
                    eventId: "record_click_add",
                    eventName: "点击记一笔入口",
                    params: ["source": "dashboard"]
                )
                isAddRecordPresented = true
            }) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 24, height: 24)
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(hex: "#34A873"))
                    }
                    Text("记一笔")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(hex: "#20AE73"))
                .clipShape(Capsule())
                .shadow(color: Color(hex: "#20AE73").opacity(0.4), radius: 8, x: 0, y: 4)
            }
        }
    }

    /// 有预算时的进度条区域
    private func budgetProgressSection(stats: BudgetStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("预算已用")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.App.textOnPrimary.opacity(0.9))

            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.55))
                            .frame(height: 8)
                        Capsule()
                            .fill(stats.budgetProgress >= 1.0 ? Color(hex: "#D94B4B") : Color(hex: "#20AE73"))
                            .frame(width: geo.size.width * min(1.0, stats.budgetProgress), height: 8)
                    }
                }
                .frame(height: 8)

                Text("\(Int(stats.budgetProgress * 100))%")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.App.textOnPrimary)
            }

            HStack(alignment: .center) {
                Text("本月已过 \(Int(stats.timeProgress * 100))% · \(stats.paceLabel)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.App.textOnPrimary.opacity(0.65))
                
                Spacer()
                
                // 剩余预算胶囊（点击打开预算设置）
                Button { isBudgetSheetPresented = true } label: {
                    if stats.remainingBudget >= 0 {
                        Text("剩余 ¥\(Int(stats.remainingBudget))")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.App.darkGreen)
                    } else {
                        Text("超预算 ¥\(Int(abs(stats.remainingBudget)))")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: "#D94B4B"))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.55))
                .clipShape(Capsule())
                .contentShape(Rectangle())
            }
        }
        .padding(.trailing, 85)
    }

    /// 未设置预算时的引导区域
    private var noBudgetGuideSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("预算已用")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.App.textOnPrimary.opacity(0.9))

            HStack(spacing: 8) {
                Capsule()
                    .fill(Color.white.opacity(0.55))
                    .frame(height: 8)
            }

            HStack(alignment: .center) {
                Text("尚未设置本月预算")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.App.textOnPrimary.opacity(0.65))
                
                Spacer()
                
                Button { isBudgetSheetPresented = true } label: {
                    Text("设置预算")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.App.darkGreen)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.55))
                .clipShape(Capsule())
                .contentShape(Rectangle())
            }
        }
        .padding(.trailing, 85)
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // MARK: Header
                PageHeader(title: "首页看板")
                
                // MARK: 顶部财务看板（总览 / 预算日历 双 Tab）
                ZStack(alignment: .topTrailing) {

                    // ── 层1: 背景渐变卡片
                    RoundedRectangle(cornerRadius: 24)
                        .fill(LinearGradient(
                            colors: [Color.App.primaryGreen, Color.App.lightGreen],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .shadow(color: Color.App.primaryGreen.opacity(0.4), radius: 20, x: 0, y: 10)

                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 160, height: 160)
                        .blur(radius: 20)
                        .offset(x: 40, y: -40)

                    // ── 层2: 气泡（日历模式淡出；位置让开顶部 Header/Segmented Control）
                    GreetingBubbleView(coordinator: mascotCoordinator)
                        .frame(maxWidth: 150, alignment: .trailing)
                        .padding(.trailing, 12)
                        .padding(.top, 64)
                        .opacity(heroTab == .overview ? 1 : 0)
                        .animation(.easeInOut(duration: 0.25), value: heroTab)

                    // ── 层3: 主内容 VStack
                    VStack(alignment: .leading, spacing: 0) {

                        // 顶部标题行：支出标签 + Segmented Control + 预算金额
                        HStack(spacing: 6) {
                            Text("\(selectedPeriod.rawValue)支出")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color.App.textOnPrimary.opacity(0.8))

                            // 下拉箭头仅在总览模式显示
                            if heroTab == .overview {
                                Button(action: { showPeriodPicker = true }) {
                                    Image(systemName: "chevron.down.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color.App.textOnPrimary.opacity(0.6))
                                }
                            }

                            Spacer()

                            // Segmented Control
                            heroSegmentedControl

                                                    }
                        .padding(.bottom, 12)

                        // ── 总览内容
                        if heroTab == .overview {
                            overviewContent
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .offset(y: 6)),
                                    removal:   .opacity.combined(with: .offset(y: -6))
                                ))
                        }

                        // ── 预算日历内容
                        if heroTab == .calendar {
                            BudgetCalendarView()
                                .padding(.horizontal, -8)
                                .padding(.top, 4)
                                .padding(.bottom, -8)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .offset(y: 6)),
                                    removal:   .opacity.combined(with: .offset(y: -6))
                                ))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 20)

                    // ── 层4: 卡皮（日历模式淡出；头部落在预算进度条下方、财务卡片上方）
                    GreetingCapybaraView(coordinator: mascotCoordinator)
                        .padding(.trailing, 18)
                        .padding(.top, 120)
                        .opacity(heroTab == .overview ? 1 : 0)
                        .animation(.easeInOut(duration: 0.25), value: heroTab)
                }
                .padding(.horizontal, 24)

                // MARK: 里程碑导出提醒 Banner（仅 iCloud 未同步时展示）
                if let milestone = exportBannerMilestone {
                    ExportReminderBanner(
                        milestone: milestone,
                        onExport: {
                            ExportReminderBanner.markDismissed(milestone: milestone)
                            exportBannerMilestone = nil
                            showExportFromBanner = true
                        },
                        onDismiss: {
                            ExportReminderBanner.markDismissed(milestone: milestone)
                            withAnimation(.easeOut(duration: 0.25)) {
                                exportBannerMilestone = nil
                            }
                        }
                    )
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // MARK: 进行中的项目（横向滑动，最新在前）
                VStack(spacing: 16) {
                    HStack {
                        Text("进行中的项目")
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundColor(Color.App.textBlack)
                        Spacer()
                        Button(action: {
                            AnalyticsManager.shared.trackEvent(eventId: "dashboard_view_all_projects", eventName: "首页查看全部项目")
                            onResetProjectNav?()
                            withAnimation { selectedTab = 1 }
                        }) {
                            HStack(spacing: 4) {
                                Text("查看全部")
                                    .font(.system(size: 14, weight: .bold))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(Color.App.darkGreen)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    if sortedActiveProjects.isEmpty {
                        // 空状态：小满引导新建项目
                        VStack(spacing: 12) {
                            Text("🦫")
                                .font(.system(size: 40))
                            Text("还没有项目，点击下方「+」\n新建一个专属账本吧～")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .padding(.horizontal, 24)
                    } else {
                        // 横向可滑动卡片列表（onTapGesture 不会被 ScrollView 滑动误触发）
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 14) {
                                ForEach(sortedActiveProjects) { project in
                                    ProjectCard(project: project)
                                        .frame(width: 160)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            AnalyticsManager.shared.trackEvent(eventId: "project_view_detail", eventName: "查看项目详情", params: ["project_status": "active", "source": "dashboard"])
                                            detailProject = project
                                        }
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                // MARK: 最近交易（真实数据）
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("最近交易")
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundColor(Color.App.textBlack)
                        Spacer()
                        Button(action: { showAllTransactions = true }) {
                            HStack(spacing: 4) {
                                Text("查看全部")
                                    .font(.system(size: 14, weight: .medium))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(Color.App.darkGreen)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    if store.recentTransactions.isEmpty {
                        VStack(spacing: 12) {
                            Text("🦫")
                                .font(.system(size: 40))
                            Text("还没有任何记录")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Color.App.textBlack)
                            Text("点击底部「+」记录今天的\n第一笔收支吧")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .padding(.horizontal, 24)
                        .background(Color.App.cardBackground.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .padding(.horizontal, 24)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(store.recentTransactions.prefix(10)) { tx in
                                TransactionItem(transaction: tx)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        viewingTransaction = tx
                                    }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .sheet(item: $editingTransaction) { tx in
                    EditTransactionView(transaction: tx)
                        .environmentObject(store)
                }
                .sheet(item: $viewingTransaction) { tx in
                    TransactionDetailView(transaction: tx)
                        .environmentObject(store)
                }
                
                Spacer().frame(height: 16)
            }
        }
        .safeAreaInset(edge: .bottom) {
            // 为浮动 Tab 栏留出空间，防止内容被遮住
            Color.clear.frame(height: 110)
        }
        .background(Color.App.backgroundGray.ignoresSafeArea())
        .fullScreenCover(isPresented: $isAddRecordPresented) {
            AddRecordView()
                .environmentObject(store)
        }
        .sheet(isPresented: $showPeriodPicker) {
            PeriodPickerSheet(selectedPeriod: $selectedPeriod)
        }
        .fullScreenCover(isPresented: $showAllTransactions) {
            AllTransactionsView()
                .environmentObject(store)
        }
        // Banner 触发的导出 Sheet
        .sheet(isPresented: $showExportFromBanner) {
            ExportConfigSheet()
                .environmentObject(store)
        }
        // 首次进入时：异步检测 iCloud 状态 + 里程碑
        .onAppear {
            checkExportBannerIfNeeded()
            updateStats()  // 确保预算统计立即就绪
        }
        // 预算设置 Sheet 关闭后显式刷新（不依赖 dataVersion 变化）
        .sheet(isPresented: $isBudgetSheetPresented, onDismiss: {
            updateBudgetStats()
        }) {
            BudgetSetSheet()
                .environmentObject(store)
        }
        // 统计缓存：数据变更（dataVersion）或切换统计维度时重算一次
        // 300ms 防抖：避免 CloudKit 同步连续 bump dataVersion 时反复在主线程执行 3 次 DB fetch
        .task(id: store.dataVersion) {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            updateStats()
        }
        .onChange(of: selectedPeriod) {
            updateStats()
        }
        // 切到预算日历时自动锁定「本月」维度
        .onChange(of: heroTab) {
            if heroTab == .calendar, selectedPeriod != .month {
                selectedPeriod = .month
                updateStats()
            }
        }
        // 每次数据变更时重新检测（新记录写入后可能触发新里程碑）
        .onChange(of: store.dataVersion) {
            checkExportBannerIfNeeded()
        }
    }

    /// 检测 iCloud 同步状态 + 未展示的里程碑，决定是否显示导出提醒 Banner
    private func checkExportBannerIfNeeded() {
        let total = store.fetchTotalTransactionCount()
        guard let milestone = ExportReminderBanner.pendingMilestone(for: total) else { return }

        // 异步检测 iCloud 账号状态
        CKContainer.default().accountStatus { status, _ in
            DispatchQueue.main.async {
                isCloudAvailable = (status == .available)
                // 只有 iCloud 不可用时才展示 Banner
                if !isCloudAvailable {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        exportBannerMilestone = milestone
                    }
                }
            }
        }
    }
}

// MARK: - 时间维度选择器（莫兰迪绿风格）
struct PeriodPickerSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedPeriod: DashboardPeriod

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            HStack {
                Text("选择统计维度")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundColor(Color.App.textBlack)
                Spacer()
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.gray.opacity(0.4))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 20)

            // 选项列表
            VStack(spacing: 10) {
                ForEach(DashboardPeriod.allCases, id: \.self) { period in
                    Button(action: {
                        selectedPeriod = period
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Text(period.rawValue)
                                .font(.system(size: 16, weight: selectedPeriod == period ? .bold : .medium))
                                .foregroundColor(selectedPeriod == period ? Color.App.darkGreen : Color.App.textBlack.opacity(0.7))

                            Spacer()

                            if selectedPeriod == period {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color.App.darkGreen)
                            } else {
                                Circle()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1.5)
                                    .frame(width: 20, height: 20)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(selectedPeriod == period ? Color.App.darkGreen.opacity(0.08) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .presentationDetents([.height(300)])
        .presentationCornerRadius(24)
    }
}

// MARK: - 财务指标小卡片（支持3卡片布局）
struct FinanceInfoCard: View {
    let title: String
    let value: Double
    @Environment(\.colorScheme) private var colorScheme

    private var isNegative: Bool { value < 0 }
    // 负值（如本月结余为负）→ 红色；正值 → 主题绿
    private var amountColor: Color {
        isNegative ? Color(hex: "#D94B4B") : Color.App.textOnPrimary
    }

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.App.textOnPrimary.opacity(0.75))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text("\(isNegative ? "-" : "")¥\(abs(value).formatted(.number.precision(.fractionLength(0))))")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(amountColor)
                .minimumScaleFactor(0.65)
                .lineLimit(1)
        }
        // 背景已上移至外层「三个财务指标」容器统一绘制，这里只负责排版
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - 项目卡片（绑定真实 Project）
struct ProjectCard: View {
    let project: Project
    @EnvironmentObject var store: AppStore

    var body: some View {
        // 查 AppStore 预计算的汇总表，避免每张卡片遍历 CoreData 关系
        let summary = store.projectSummaries[project.id]
        let totalSpent = summary?.totalSpent ?? 0
        let budgetProgress = summary?.budgetProgress ?? 0
        let pair = progressColorPair(for: project.colorHex)
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Circle()
                    .fill(Color(hex: project.colorHex).opacity(0.4))
                    .frame(width: 40, height: 40)
                    .overlay(
                        AppIconView(name: project.icon, size: 18,
                                    color: Color.App.projectIconColor(for: project.colorHex))
                    )
                Spacer(minLength: 4)
                Text("进行中")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.App.darkGreen)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.App.primaryGreen.opacity(0.5))
                    .clipShape(Capsule())
            }
            
            Text(project.name)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color.App.textBlack)
                .lineLimit(1)
            
            if project.budget > 0 {
                HStack {
                    Text("¥\(totalSpent.formatted(.number.precision(.fractionLength(0))))")
                    Spacer()
                    Text("预算¥\(project.budget.formatted(.number.precision(.fractionLength(0))))")
                }
                .font(.system(size: 10))
                .foregroundColor(.gray)
                
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.App.progressTrack)
                        .frame(height: 6)
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color(hex: pair.start), Color(hex: pair.end)],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(height: 6)
                        .scaleEffect(x: min(1, budgetProgress), anchor: .leading)
                }
            } else {
                Text("已用 ¥\(totalSpent.formatted(.number.precision(.fractionLength(0))))")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                Spacer().frame(height: 6)
            }
        }
        .padding(16)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
    }
}

// MARK: - 交易记录行（绑定真实 Transaction）
struct TransactionItem: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color(hex: transaction.categoryColorHex).opacity(0.3))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: transaction.categoryIcon)
                        .foregroundColor(Color(hex: transaction.categoryColorHex))
                        .font(.system(size: 20))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.note.isEmpty ? transaction.categoryName : transaction.note)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.App.textBlack)
                Text("\(transaction.categoryName) · \(transaction.date.relativeDisplay)")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text("\(transaction.type == .expense ? "-" : "+") ¥\(transaction.amount.formatted(.number.precision(.fractionLength(2))))")
                .font(.system(size: 15, weight: .heavy))
                .foregroundColor(transaction.type == .expense ? Color.App.redExpense : Color.App.darkGreen)
        }
        .padding(16)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 5)
    }
}

// MARK: - 日期相对显示扩展
extension Date {
    // 静态 DateFormatter：创建一次，反复复用
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f
    }()
    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M/d"
        return f
    }()
    private static let fullDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy/M/d"
        return f
    }()
    static let chineseDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月d日"
        return f
    }()

    var relativeDisplay: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            return "今天 \(Date.timeFormatter.string(from: self))"
        }
        if calendar.isDateInYesterday(self) {
            return "昨天 \(Date.timeFormatter.string(from: self))"
        }
        if calendar.component(.year, from: self) == calendar.component(.year, from: Date()) {
            return Date.shortDateFormatter.string(from: self)
        }
        return Date.fullDateFormatter.string(from: self)
    }
    
    var formattedChineseDate: String {
        Date.chineseDateFormatter.string(from: self)
    }
}

#Preview {
    DashboardView(selectedTab: .constant(0), detailProject: .constant(nil))
        .environmentObject(AppStore(modelContext: try! ModelContainer(for: Project.self, Transaction.self, Category.self, ChatHistory.self, MemoryRule.self).mainContext))
}
