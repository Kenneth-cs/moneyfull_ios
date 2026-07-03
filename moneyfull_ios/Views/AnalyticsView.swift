import SwiftUI
import SwiftData

// MARK: - 时间维度枚举
enum TimeRange: String, CaseIterable {
    case week = "周"
    case month = "月"
    case year = "年"
    case custom = "自定义"
}

// MARK: - 图表维度枚举
enum ChartDimension: String, CaseIterable {
    case byProject = "按项目"
    case allCategories = "全部分类"
    case projectCategories = "项目内分类"
}

// MARK: - 收支类型枚举
enum ChartFlowType: String, CaseIterable {
    case expense = "支出"
    case income = "收入"
}

// MARK: - 财务统计页
struct AnalyticsView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var timeRange: TimeRange = .month
    @State private var selectedMonth: Date = {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
    }()
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedWeekStart: Date = {
        Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
    }()
    @State private var customStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
    @State private var customEndDate: Date = Date()
    
    @State private var showMonthPicker = false
    @State private var showWeekPicker = false
    @State private var showCustomRangeSheet = false
    @State private var showTrendDetail = false
    
    @State private var chartDimension: ChartDimension = .byProject
    @State private var chartFlowType: ChartFlowType = .expense
    @State private var selectedProjectForChart: Project?
    
    @State private var allTransactions: [Transaction] = []

    // MARK: - 缓存计算结果（避免 body 每次重渲时重复执行耗时操作）
    @State private var _filteredTransactions: [Transaction] = []
    @State private var _periodExpenseTxs: [Transaction] = []
    @State private var _periodIncomeTxs: [Transaction] = []
    @State private var _donutSegments: [(name: String, amount: Double, colorHex: String, icon: String)] = []
    @State private var _donutTotal: Double = 0
    @State private var _savingRate: Double = 0
    @State private var _trendData: [(label: String, expense: Double, income: Double, saving: Double)] = []
    @State private var _healthScore: Int = 0
    @State private var _expenseChangeDiff: Double = 0
    @State private var _previousPeriodExpense: Double = 0
    // 额外缓存：避免在 body 里内联计算
    @State private var _allTxDaysCount: Int = 0
    @State private var _budgetProjects: [Project] = []
    @State private var _activeProjects: [Project] = []

    // MARK: - 计算属性代理（body 直接读缓存，零计算开销）
    private var filteredTransactions: [Transaction] { _filteredTransactions }
    private var periodExpenseTransactions: [Transaction] { _periodExpenseTxs }
    private var periodIncomeTransactions: [Transaction] { _periodIncomeTxs }
    private var donutSegments: [(name: String, amount: Double, colorHex: String, icon: String)] { _donutSegments }
    private var donutTotal: Double { _donutTotal }
    private var savingRate: Double { _savingRate }
    private var trendData: [(label: String, expense: Double, income: Double, saving: Double)] { _trendData }
    private var healthScore: Int { _healthScore }
    private var expenseChangeDiff: Double { _expenseChangeDiff }
    private var previousPeriodExpense: Double { _previousPeriodExpense }
    private var budgetProjects: [Project] { _budgetProjects }

    // MARK: - 核心统计刷新（仅在过滤条件变化时调用，不在 body 里计算）
    private func updateFilteredData() {
        let calendar = Calendar.current

        // 1. 过滤当期交易
        let filtered: [Transaction]
        switch timeRange {
        case .week:
            guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: selectedWeekStart) else {
                _filteredTransactions = []; _periodExpenseTxs = []; _periodIncomeTxs = []
                _trendData = []; _healthScore = 0; _expenseChangeDiff = 0; _previousPeriodExpense = 0
                updateDonutData(); return
            }
            filtered = allTransactions.filter { $0.date >= selectedWeekStart && $0.date < weekEnd }
        case .month:
            filtered = allTransactions.filter { calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month) }
        case .year:
            filtered = allTransactions.filter { calendar.component(.year, from: $0.date) == selectedYear }
        case .custom:
            filtered = allTransactions.filter { $0.date >= customStartDate && $0.date <= customEndDate }
        }
        _filteredTransactions = filtered
        _periodExpenseTxs = filtered.filter { $0.type == .expense }
        _periodIncomeTxs  = filtered.filter { $0.type == .income }

        // 2. 上期对比
        var prevStart: Date?; var prevEnd: Date?
        switch timeRange {
        case .week:
            prevStart = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedWeekStart)
            prevEnd = selectedWeekStart
        case .month:
            prevStart = calendar.date(byAdding: .month, value: -1, to: selectedMonth)
            prevEnd = selectedMonth
        case .year:
            prevStart = calendar.date(from: DateComponents(year: selectedYear - 1, month: 1, day: 1))
            prevEnd   = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1))
        case .custom:
            let days = calendar.dateComponents([.day], from: customStartDate, to: customEndDate).day ?? 30
            prevStart = calendar.date(byAdding: .day, value: -days, to: customStartDate)
            prevEnd   = customStartDate
        }
        let prevExpense: Double
        if let s = prevStart, let e = prevEnd {
            prevExpense = allTransactions
                .filter { $0.date >= s && $0.date < e && $0.type == .expense }
                .reduce(0) { $0 + abs($1.amount) }
        } else { prevExpense = 0 }
        _previousPeriodExpense = prevExpense

        // 3. 收支汇总
        let currentExp = _periodExpenseTxs.reduce(0) { $0 + abs($1.amount) }
        let currentInc = _periodIncomeTxs.reduce(0)  { $0 + abs($1.amount) }
        _expenseChangeDiff = currentExp - prevExpense
        _savingRate = currentInc > 0 ? (currentInc - currentExp) / currentInc : 0

        // 4. 健康分（静态60 + 动态40）
        var staticScore: Double = 60
        if currentInc == 0 {
            if currentExp > 0 { staticScore = 30 }
        } else {
            let ratio = currentExp / currentInc
            if ratio <= 1 { staticScore = 60 }
            else if ratio <= 1.2 { staticScore = 50 }
            else if ratio <= 1.5 { staticScore = 40 }
            else { staticScore = 20 }
        }
        var dynamicScore: Double = 20
        if prevExpense > 0 {
            if currentExp < prevExpense {
                dynamicScore += min((prevExpense - currentExp) / prevExpense * 20, 20)
            } else if currentExp > prevExpense {
                dynamicScore -= min((currentExp - prevExpense) / prevExpense * 20, 20)
            }
        }
        _healthScore = max(0, min(Int(staticScore + dynamicScore), 100))

        // 5. 趋势图数据
        _trendData = computeTrendData()

        // 6. 环形图数据
        updateDonutData()

        // 7. 累计记账天数（Set 哈希去重，较慢，只在此处算一次存起来）
        _allTxDaysCount = Set(allTransactions.map { Calendar.current.startOfDay(for: $0.date) }).count

        // 8. 项目列表缓存（避免 body 直接持有 store.activeProjects 依赖）
        _activeProjects = store.activeProjects
        _budgetProjects = store.activeProjects.filter { $0.budget > 0 }
    }

    /// store 数据变化时调用：重新抓取所有账单并刷新缓存
    private func reloadFromStore() {
        Task { @MainActor in
            allTransactions = store.fetchAllTransactions()
            updateFilteredData()
        }
    }

    private func updateDonutData() {
        let transactions = chartFlowType == .expense ? _periodExpenseTxs : _periodIncomeTxs
        var segments: [(name: String, amount: Double, colorHex: String, icon: String)]

        switch chartDimension {
        case .byProject:
            var dict: [String: (amount: Double, color: String, icon: String)] = [:]
            for tx in transactions {
                let name = tx.project?.name ?? "未分类"
                let current = dict[name]?.amount ?? 0
                dict[name] = (current + abs(tx.amount), tx.project?.colorHex ?? "#EEEEEE", tx.project?.icon ?? "folder.fill")
            }
            segments = dict.map { (name: $0.key, amount: $0.value.amount, colorHex: $0.value.color, icon: $0.value.icon) }.sorted { $0.amount > $1.amount }
        case .allCategories:
            var dict: [String: (amount: Double, color: String, icon: String)] = [:]
            for tx in transactions {
                let current = dict[tx.categoryName]?.amount ?? 0
                dict[tx.categoryName] = (current + abs(tx.amount), tx.categoryColorHex, tx.categoryIcon)
            }
            segments = dict.map { (name: $0.key, amount: $0.value.amount, colorHex: $0.value.color, icon: $0.value.icon) }.sorted { $0.amount > $1.amount }
        case .projectCategories:
            guard let project = selectedProjectForChart ?? store.activeProjects.first else {
                _donutSegments = []; _donutTotal = 0; return
            }
            var dict: [String: (amount: Double, color: String, icon: String)] = [:]
            for tx in transactions where tx.project?.id == project.id {
                let current = dict[tx.categoryName]?.amount ?? 0
                dict[tx.categoryName] = (current + abs(tx.amount), tx.categoryColorHex, tx.categoryIcon)
            }
            segments = dict.map { (name: $0.key, amount: $0.value.amount, colorHex: $0.value.color, icon: $0.value.icon) }.sorted { $0.amount > $1.amount }
        }
        _donutSegments = segments
        _donutTotal = segments.reduce(0) { $0 + $1.amount }
    }

    private func computeTrendData() -> [(label: String, expense: Double, income: Double, saving: Double)] {
        let calendar = Calendar.current
        var result: [(label: String, expense: Double, income: Double, saving: Double)] = []
        let weekDayNames = ["日", "一", "二", "三", "四", "五", "六"]

        switch timeRange {
        case .year:
            for m in 1...12 {
                guard let date = calendar.date(from: DateComponents(year: selectedYear, month: m)) else { continue }
                let txs = allTransactions.filter { calendar.isDate($0.date, equalTo: date, toGranularity: .month) }
                let exp = txs.filter { $0.type == .expense }.reduce(0) { $0 + abs($1.amount) }
                let inc = txs.filter { $0.type == .income }.reduce(0) { $0 + abs($1.amount) }
                result.append((label: "\(m)月", expense: exp, income: inc, saving: inc - exp))
            }
        case .month:
            let range = calendar.range(of: .day, in: .month, for: selectedMonth) ?? 1..<32
            let step = range.count > 20 ? 5 : 1
            for day in stride(from: range.lowerBound, to: range.upperBound, by: step) {
                guard let date = calendar.date(from: DateComponents(year: calendar.component(.year, from: selectedMonth), month: calendar.component(.month, from: selectedMonth), day: day)) else { continue }
                let nextDate = calendar.date(byAdding: .day, value: step, to: date) ?? date
                let txs = allTransactions.filter { $0.date >= date && $0.date < nextDate }
                let exp = txs.filter { $0.type == .expense }.reduce(0) { $0 + abs($1.amount) }
                let inc = txs.filter { $0.type == .income }.reduce(0) { $0 + abs($1.amount) }
                result.append((label: "\(day)日", expense: exp, income: inc, saving: inc - exp))
            }
        case .week:
            for i in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: i, to: selectedWeekStart) else { continue }
                let nextDate = calendar.date(byAdding: .day, value: 1, to: date) ?? date
                let txs = allTransactions.filter { $0.date >= date && $0.date < nextDate }
                let exp = txs.filter { $0.type == .expense }.reduce(0) { $0 + abs($1.amount) }
                let inc = txs.filter { $0.type == .income }.reduce(0) { $0 + abs($1.amount) }
                let weekday = calendar.component(.weekday, from: date) - 1
                result.append((label: "周\(weekDayNames[weekday])", expense: exp, income: inc, saving: inc - exp))
            }
        case .custom:
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: customStartDate), to: calendar.startOfDay(for: customEndDate)).day ?? 1
            let step = days > 60 ? 7 : (days > 20 ? 3 : 1)
            var current = calendar.startOfDay(for: customStartDate)
            while current <= customEndDate {
                let next = calendar.date(byAdding: .day, value: step, to: current) ?? customEndDate
                let txs = allTransactions.filter { $0.date >= current && $0.date < next }
                let exp = txs.filter { $0.type == .expense }.reduce(0) { $0 + abs($1.amount) }
                let inc = txs.filter { $0.type == .income }.reduce(0) { $0 + abs($1.amount) }
                let m = calendar.component(.month, from: current)
                let d = calendar.component(.day, from: current)
                result.append((label: "\(m)月\(d)日", expense: exp, income: inc, saving: inc - exp))
                current = next
            }
        }
        return result
    }

    // MARK: - IP 形象联动
    private var ipImageName: String {
        switch healthScore {
        case 80...100: return "ip_bear"      // 开心悠闲
        case 60..<80: return "ip_bear"       // 正常状态
        case 40..<60: return "ip_sweat"      // 流汗紧张
        case 20..<40: return "ip_eat_dirt"   // 吃土状态
        default: return "ip_shocked"         // 震惊崩溃 (0-19)
        }
    }

    private var ipStatusText: String {
        switch healthScore {
        case 80...100: return "财务状态优秀，继续保持哦！🌿"
        case 60..<80: return "消费还算平稳，注意预算哦！"
        case 40..<60: return "开销有点大了，悠着点花！😰"
        case 20..<40: return "这个月要吃土啦，省着点！💸"
        default: return "财务红灯警告！快踩刹车！🚨"
        }
    }

    // MARK: - 静态 DateFormatter（避免 body 每次重渲时重复创建）
    private static let weekFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M月d日"
        return f
    }()
    
    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy年M月"
        return f
    }()
    
    private static let shortWeekFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f
    }()

    // MARK: - 时间显示文案
    private var periodDisplayText: String {
        switch timeRange {
        case .week:
            let end = Calendar.current.date(byAdding: .day, value: 6, to: selectedWeekStart)!
            return "\(Self.weekFormatter.string(from: selectedWeekStart)) - \(Self.weekFormatter.string(from: end))"
        case .month:
            return Self.monthFormatter.string(from: selectedMonth)
        case .year:
            return String(format: "%d年", selectedYear)
        case .custom:
            return "\(Self.weekFormatter.string(from: customStartDate)) - \(Self.weekFormatter.string(from: customEndDate))"
        }
    }

    private var shortPeriodDisplayText: String {
        switch timeRange {
        case .week:
            let end = Calendar.current.date(byAdding: .day, value: 6, to: selectedWeekStart)!
            return "\(Self.shortWeekFormatter.string(from: selectedWeekStart))-\(Self.shortWeekFormatter.string(from: end))"
        case .month:
            return Self.monthFormatter.string(from: selectedMonth)
        case .year:
            return String(format: "%d年", selectedYear)
        case .custom:
            return "\(Self.shortWeekFormatter.string(from: customStartDate))-\(Self.shortWeekFormatter.string(from: customEndDate))"
        }
    }

    // MARK: - Body
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                PageHeader(title: "财务统计")

                // MARK: 时间维度切换
                timeRangeSelector

                // MARK: 日期导航
                dateNavigator
                
                // MARK: IP 健康卡片
                ipStatusCard

                // MARK: 支出占比卡片
                donutChartCard

                // MARK: 趋势卡片
                trendChartCard

                // MARK: 底部卡片
                VStack(spacing: 16) {
                    if !budgetProjects.isEmpty {
                        budgetHealthCard
                    }
                    monthlySummaryCard
                }
                .padding(.horizontal, 24)

                // MARK: 豚言豚语
                InsightCardView(
                    transactions: filteredTransactions,
                    expense: periodExpenseTransactions.reduce(0) { $0 + $1.amount },
                    income: periodIncomeTransactions.reduce(0) { $0 + $1.amount }
                )
                .padding(.horizontal, 24)

                Spacer().frame(height: 16)
            }
        }
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 110) }
        .background(Color.App.backgroundGray.ignoresSafeArea())
        .onAppear {
            allTransactions = store.fetchAllTransactions()
            updateFilteredData()
        }
        // 数据源变化时重新计算（用 Task 推迟到下一个 RunLoop，让当前渲染帧先完成）
        // 同时监听 count（增删）和 monthlyExpense（编辑金额），覆盖所有 CRUD 场景
        .onChange(of: store.recentTransactions.count) { _, _ in reloadFromStore() }
        .onChange(of: store.monthlyExpense) { _, _ in reloadFromStore() }
        // 时间过滤条件变化
        .onChange(of: timeRange)       { _, _ in updateFilteredData() }
        .onChange(of: selectedMonth)   { _, _ in updateFilteredData() }
        .onChange(of: selectedYear)    { _, _ in updateFilteredData() }
        .onChange(of: selectedWeekStart) { _, _ in updateFilteredData() }
        .onChange(of: customStartDate) { _, _ in updateFilteredData() }
        .onChange(of: customEndDate)   { _, _ in updateFilteredData() }
        // 环形图维度变化（只更新 donut，不需要重走全量计算）
        .onChange(of: chartFlowType)   { _, _ in updateDonutData() }
        .onChange(of: chartDimension)  { _, _ in updateDonutData() }
        .onChange(of: selectedProjectForChart?.id) { _, _ in updateDonutData() }
        .sheet(isPresented: $showMonthPicker) {
            MonthYearPickerSheet(selectedMonth: $selectedMonth)
        }
        .sheet(isPresented: $showWeekPicker) {
            WeekPickerSheet(selectedWeekStart: $selectedWeekStart)
        }
        .sheet(isPresented: $showCustomRangeSheet) {
            CustomDateRangeSheet(startDate: $customStartDate, endDate: $customEndDate)
        }
        .background(
            NavigationLink(isActive: $showTrendDetail) {
                TrendDetailView(transactions: filteredTransactions, periodLabel: periodDisplayText)
                    .environmentObject(store)
            } label: { EmptyView() }.hidden()
        )
    }

    // MARK: - 时间维度选择器
    private var timeRangeSelector: some View {
        HStack(spacing: 0) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { timeRange = range } }) {
                    Text(range.rawValue)
                        .font(.system(size: 13, weight: timeRange == range ? .bold : .medium))
                        .foregroundColor(timeRange == range ? .white : Color.App.textBlack.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(timeRange == range ? Color.App.darkGreen : Color.clear)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(3)
        .background(Color.App.cardBackground.opacity(0.6))
        .clipShape(Capsule())
        .padding(.horizontal, 48)
    }

    // MARK: - 日期导航器
    private var dateNavigator: some View {
        Button(action: {
            switch timeRange {
            case .month: showMonthPicker = true
            case .custom: showCustomRangeSheet = true
            case .week: showWeekPicker = true
            case .year: break
            }
        }) {
            HStack(spacing: 4) {
                Text(periodDisplayText)
                    .font(.system(size: 14, weight: .heavy))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(Color.App.textBlack.opacity(0.9))
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - IP 健康卡片
    private var ipStatusCard: some View {
        HStack(spacing: 16) {
            // 左侧 IP 图片（根据健康分切换表情）
            Image(ipImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 70, height: 70)
                .id(ipImageName) // 确保图片切换时有动画
            
            // 中间文案
            VStack(alignment: .leading, spacing: 4) {
                Text("本期财务状态")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
                
                Text(ipStatusText)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.App.textBlack)
                    .lineLimit(2)
                
                if previousPeriodExpense > 0 {
                    HStack(spacing: 4) {
                        Text(expenseChangeDiff <= 0 ? "比上期节省了 ¥\(Int(abs(expenseChangeDiff)))" : "比上期多花了 ¥\(Int(abs(expenseChangeDiff)))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(expenseChangeDiff <= 0 ? Color.App.darkGreen : Color.App.redExpense)
                        Image(systemName: expenseChangeDiff <= 0 ? "arrow.down" : "arrow.up")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(expenseChangeDiff <= 0 ? Color.App.darkGreen : Color.App.redExpense)
                    }
                    .padding(.top, 2)
                }
            }
            
            Spacer()
            
            // 右侧健康分仪表盘
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(Color.gray.opacity(0.15), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(135))
                        .frame(width: 54, height: 54)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(healthScore) / 100.0 * 0.75)
                        .stroke(healthScore >= 80 ? Color.App.darkGreen : (healthScore >= 60 ? Color.App.darkOrangeBrown : Color.App.redExpense), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(135))
                        .frame(width: 54, height: 54)
                    
                    VStack(spacing: -2) {
                        Text("\(healthScore)")
                            .font(.system(size: 20, weight: .black))
                            .foregroundColor(Color.App.textBlack)
                        Text("健康分")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 60, height: 60)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            Group {
                if colorScheme == .dark {
                    Color.App.cardBackground
                } else {
                    Color(hex: "#F0FAF5")
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.App.darkGreen.opacity(0.06), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 24)
        .animation(.easeInOut(duration: 0.3), value: healthScore)
    }

    // MARK: - 支出占比卡片
    private var donutChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("收支占比")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(Color.App.textBlack)
                Spacer()
                Text(shortPeriodDisplayText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }

            // 收支类型切换
            HStack(spacing: 0) {
                ForEach(ChartFlowType.allCases, id: \.self) { type in
                    Button(action: { withAnimation(.easeInOut(duration: 0.2)) { chartFlowType = type } }) {
                        Text(type.rawValue)
                            .font(.system(size: 12, weight: chartFlowType == type ? .bold : .medium))
                            .foregroundColor(chartFlowType == type ? .white : .gray)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(chartFlowType == type ? (type == .expense ? Color.App.darkGreen : Color.App.darkOrange) : Color.clear)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(2)
            .background(Color.App.backgroundGray.opacity(0.5))
            .clipShape(Capsule())

            // 维度切换
            HStack(spacing: 0) {
                ForEach(ChartDimension.allCases, id: \.self) { dim in
                    Button(action: { withAnimation(.easeInOut(duration: 0.2)) { chartDimension = dim } }) {
                        Text(dim.rawValue)
                            .font(.system(size: 11, weight: chartDimension == dim ? .bold : .medium))
                            .foregroundColor(chartDimension == dim ? .white : .gray)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(chartDimension == dim ? Color.App.darkGreen : Color.clear)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(2)
            .background(Color.App.backgroundGray.opacity(0.5))
            .clipShape(Capsule())

            // 项目选择器
            if chartDimension == .projectCategories {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(_activeProjects) { project in
                            Button(action: { selectedProjectForChart = project }) {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color(hex: project.colorHex).opacity(0.3))
                                        .frame(width: 16, height: 16)
                                        .overlay(AppIconView(name: project.icon, size: 8, color: Color(hex: project.colorHex)))
                                    Text(project.name)
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background((selectedProjectForChart?.id == project.id) ? Color.App.darkGreen.opacity(0.1) : Color.App.backgroundGray.opacity(0.5))
                                .clipShape(Capsule())
                            }
                            .foregroundColor(Color.App.textBlack.opacity(0.8))
                        }
                    }
                }
                .onAppear { if selectedProjectForChart == nil { selectedProjectForChart = store.activeProjects.first } }
            }

            if donutTotal == 0 {
                EmptyStateView(message: chartFlowType == .expense ? "暂无支出记录" : "暂无收入记录")
            } else {
                HStack(spacing: 24) {
                    // 左侧：环形图 + 储蓄率
                    VStack(spacing: 12) {
                        DonutChartView(segments: donutSegments, total: donutTotal, centerLabel: chartFlowType == .expense ? "总支出" : "总收入")
                            .frame(width: 130, height: 130)

                        // 储蓄率指标
                        VStack(spacing: 4) {
                            Text("储蓄率")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.gray)
                            let displayPct = Int(savingRate * 100)
                            Text(abs(displayPct) > 999 ? (displayPct > 0 ? ">999%" : "<-999%") : "\(displayPct)%")
                                .font(.system(size: 18, weight: .heavy))
                                .foregroundColor(savingRate >= 0 ? Color.App.darkGreen : Color.App.redExpense)
                            // 进度条（用 scaleEffect 代替 GeometryReader，避免额外布局 pass）
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.gray.opacity(0.1))
                                Capsule()
                                    .fill(savingRate >= 0 ? Color.App.darkGreen : Color.App.redExpense)
                                    .frame(maxWidth: .infinity)
                                    .scaleEffect(x: max(0.001, CGFloat(min(max(savingRate, 0), 1))), y: 1, anchor: .leading)
                            }
                            .frame(height: 4)
                            .frame(width: 80)
                        }
                    }
                    
                    // 右侧：图例列表
                    VStack(spacing: 12) {
                        ForEach(donutSegments.prefix(3), id: \.name) { seg in
                            VStack(spacing: 4) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color(hex: seg.colorHex).opacity(0.15))
                                        .frame(width: 18, height: 18)
                                        .overlay(
                                            Image(systemName: seg.icon)
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(Color(hex: seg.colorHex))
                                        )
                                    
                                    Text(seg.name)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(Color.App.textBlack.opacity(0.8))
                                    
                                    Spacer()
                                    
                                    Text("¥\(Int(seg.amount))")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Color.App.textBlack)
                                }
                                
                                HStack(spacing: 6) {
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.gray.opacity(0.1))
                                        Capsule()
                                            .fill(Color(hex: seg.colorHex))
                                            .frame(maxWidth: .infinity)
                                            .scaleEffect(x: max(0.001, CGFloat(seg.amount / donutTotal)), y: 1, anchor: .leading)
                                    }
                                    .frame(height: 3)
                                    
                                    Text("\(Int(seg.amount / donutTotal * 100))%")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(.gray)
                                        .frame(width: 22, alignment: .trailing)
                                }
                                .padding(.leading, 24) // 对齐进度条
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(20)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 24)
    }

    // MARK: - 趋势图卡片
    private var trendChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: { showTrendDetail = true }) {
                HStack {
                    Text("区间收支趋势")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(Color.App.textBlack)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                }
            }

            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Capsule().fill(Color.App.primaryGreen).frame(width: 16, height: 4)
                    Text("支出").font(.system(size: 11, weight: .bold)).foregroundColor(.gray)
                }
                HStack(spacing: 6) {
                    Capsule().fill(Color.App.lightOrange).frame(width: 16, height: 4)
                    Text("收入").font(.system(size: 11, weight: .bold)).foregroundColor(.gray)
                }
                HStack(spacing: 6) {
                    // 虚线样式
                    Canvas { ctx, size in
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: size.height / 2))
                        path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                        ctx.stroke(path, with: .color(Color.purple.opacity(0.7)), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    }
                    .frame(width: 16, height: 4)
                    Text("储蓄").font(.system(size: 11, weight: .bold)).foregroundColor(.gray)
                }
            }

            if trendData.isEmpty || trendData.allSatisfy({ $0.expense == 0 && $0.income == 0 }) {
                EmptyStateView(message: "暂无趋势数据")
            } else {
                AreaChartView(data: trendData)
                    .frame(height: 140)

                HStack {
                    ForEach(trendData, id: \.label) { item in
                        Text(item.label)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 24)
    }

    // MARK: - 预算健康度卡片
    private var budgetHealthCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("项目预算追踪 (全局)")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(Color.App.textBlack)
                let totalBudget = budgetProjects.reduce(0) { $0 + $1.budget }
                Text("所有追踪中的项目总预算: ¥\(totalBudget.formatted(.number.precision(.fractionLength(0))))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
            }

            VStack(spacing: 12) {
                ForEach(budgetProjects.prefix(3)) { project in
                    BudgetHealthBar(project: project, periodSpent: nil) // 传入 nil 触发跨月全局累计逻辑
                }
            }
            .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - 本月小结卡片
    private var monthlySummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("本月小结")
                .font(.system(size: 13, weight: .heavy))
                .foregroundColor(Color.App.textBlack)
            
            let daysInPeriod = max(1, Calendar.current.dateComponents([.day], from: filteredTransactions.map{$0.date}.min() ?? Date(), to: Date()).day ?? 1)
            let avgDaily = periodExpenseTransactions.reduce(0){$0 + $1.amount} / Double(daysInPeriod)
            let maxExpense = periodExpenseTransactions.map{$0.amount}.max() ?? 0
            
            VStack(alignment: .leading, spacing: 8) {
                SummaryRow(icon: "list.bullet.rectangle.portrait", color: Color.App.darkGreen, title: "本期共支出", value: "\(periodExpenseTransactions.count) 笔")
                SummaryRow(icon: "calendar", color: Color.App.darkGreen, title: "平均每天支出", value: "¥\(Int(avgDaily))")
                SummaryRow(icon: "cup.and.saucer", color: Color.App.darkGreen, title: "最高一笔支出", value: "¥\(Int(maxExpense))")
                SummaryRow(icon: "clock", color: Color.App.darkGreen, title: "累计记账", value: "\(_allTxDaysCount) 天")
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 140)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - 小结行
struct SummaryRow: View {
    let icon: String
    let color: Color
    let title: String
    let value: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(.white)
                .frame(width: 16, height: 16)
                .background(color.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color.App.textBlack)
        }
    }
}

// MARK: - 年月滚轮选择器
struct MonthYearPickerSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedMonth: Date
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedMonthNum: Int = Calendar.current.component(.month, from: Date())

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                HStack(spacing: 0) {
                    Picker("年份", selection: $selectedYear) {
                        ForEach(2020...2030, id: \.self) { year in Text(String(format: "%d年", year)).tag(year) }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 160)
                    .clipped()

                    Picker("月份", selection: $selectedMonthNum) {
                        ForEach(1...12, id: \.self) { month in Text("\(month)月").tag(month) }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 120)
                    .clipped()
                }
                .frame(height: 200)

                Button(action: {
                    selectedMonth = Calendar.current.date(from: DateComponents(year: selectedYear, month: selectedMonthNum)) ?? selectedMonth
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("确定")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.App.darkGreen)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 24)
                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("选择年月")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .onAppear {
                selectedYear = Calendar.current.component(.year, from: selectedMonth)
                selectedMonthNum = Calendar.current.component(.month, from: selectedMonth)
            }
        }
    }
}

// MARK: - 周选择器
struct WeekPickerSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedWeekStart: Date

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedWeekOfYear: Int = Calendar.current.component(.weekOfYear, from: Date())

    private var weeksInYear: Int {
        let cal = Calendar.current
        guard let date = cal.date(from: DateComponents(year: selectedYear, month: 12, day: 31)) else { return 52 }
        return cal.component(.weekOfYear, from: date) == 1 ? 52 : cal.component(.weekOfYear, from: date)
    }

    private static let weekFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M月d日"
        return f
    }()

    private func weekDateRange(year: Int, week: Int) -> String {
        let cal = Calendar.current
        guard let start = cal.date(from: DateComponents(weekOfYear: week, yearForWeekOfYear: year)) else { return "" }
        let end = cal.date(byAdding: .day, value: 6, to: start)!
        return "\(Self.weekFormatter.string(from: start)) - \(Self.weekFormatter.string(from: end))"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                HStack(spacing: 0) {
                    Picker("年份", selection: $selectedYear) {
                        ForEach(2020...2030, id: \.self) { year in Text(String(format: "%d年", year)).tag(year) }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 160)
                    .clipped()

                    Picker("周", selection: $selectedWeekOfYear) {
                        ForEach(1...weeksInYear, id: \.self) { week in
                            Text("第\(week)周").tag(week)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 120)
                    .clipped()
                }
                .frame(height: 200)

                // 显示当前选中的周日期范围
                Text(weekDateRange(year: selectedYear, week: selectedWeekOfYear))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.App.darkGreen)

                Button(action: {
                    let cal = Calendar.current
                    if let start = cal.date(from: DateComponents(weekOfYear: selectedWeekOfYear, yearForWeekOfYear: selectedYear)) {
                        selectedWeekStart = start
                    }
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("确定")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.App.darkGreen)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 24)
                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("选择周")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .onAppear {
                selectedYear = Calendar.current.component(.year, from: selectedWeekStart)
                selectedWeekOfYear = Calendar.current.component(.weekOfYear, from: selectedWeekStart)
            }
        }
    }
}

// MARK: - 自定义日期范围选择器
struct CustomDateRangeSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var startDate: Date
    @Binding var endDate: Date

    private let presets: [(label: String, start: Date, end: Date)] = {
        let cal = Calendar.current
        let now = Date()
        let last30 = cal.date(byAdding: .day, value: -30, to: now)!
        let last90 = cal.date(byAdding: .day, value: -90, to: now)!
        let yearStart = cal.date(from: DateComponents(year: cal.component(.year, from: now), month: 1, day: 1))!
        let payDayStart: Date = {
            let today = cal.component(.day, from: now)
            if today >= 15 {
                return cal.date(from: DateComponents(year: cal.component(.year, from: now), month: cal.component(.month, from: now), day: 15))!
            } else {
                return cal.date(byAdding: .month, value: -1, to: cal.date(from: DateComponents(year: cal.component(.year, from: now), month: cal.component(.month, from: now), day: 15))!)!
            }
        }()
        let payDayEnd = cal.date(byAdding: .day, value: -1, to: cal.date(byAdding: .month, value: 1, to: payDayStart)!)!
        return [("近30天", last30, now), ("近90天", last90, now), ("今年以来", yearStart, now), ("按发薪日(15号)", payDayStart, payDayEnd)]
    }()

    private func chineseDateString(_ date: Date) -> String {
        let cal = Calendar.current
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        return "\(m)月\(d)日"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("快捷预设").font(.system(size: 14, weight: .bold)).foregroundColor(Color.App.textBlack.opacity(0.7))
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(presets, id: \.label) { preset in
                            Button(action: { startDate = preset.start; endDate = preset.end }) {
                                Text(preset.label)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color.App.darkGreen)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.App.darkGreen.opacity(0.08))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 16) {
                    Text("自定义区间").font(.system(size: 14, weight: .bold)).foregroundColor(Color.App.textBlack.opacity(0.7))
                    DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                        .font(.system(size: 14))
                    DatePicker("结束日期", selection: $endDate, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                        .font(.system(size: 14))
                    
                    // 显示当前选中的中文日期范围
                    HStack {
                        Text("当前选择：")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                        Text("\(chineseDateString(startDate)) - \(chineseDateString(endDate))")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.App.darkGreen)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)

                Button(action: {
                    if startDate > endDate { swap(&startDate, &endDate) }
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("确定")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.App.darkGreen)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 24)
                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("自定义时间范围")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { presentationMode.wrappedValue.dismiss() } } }
        }
    }
}

// MARK: - 环形图（Canvas 绘制）
struct DonutChartView: View {
    let segments: [(name: String, amount: Double, colorHex: String, icon: String)]
    let total: Double
    var centerLabel: String = "总支出"

    private let lineWidth: CGFloat = 26
    private let chartColors: [String] = ["#A8E6CF", "#FDD1B4", "#DCDE8D", "#DBEAFE", "#F3E8FF", "#FFD6C4", "#C8E6C9", "#FFF9C4", "#FCE4EC", "#E8EAF6"]

    var body: some View {
        ZStack {
            GeometryReader { geo in
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                let radius = min(geo.size.width, geo.size.height) / 2 - lineWidth / 2

                Canvas { context, size in
                    var startAngle = Angle.degrees(-90)
                    for (i, seg) in segments.prefix(6).enumerated() {
                        let pct = seg.amount / total
                        let sweep = Angle.degrees(360 * pct)
                        let color = i < segments.count ? Color(hex: seg.colorHex) : Color(hex: chartColors[i % chartColors.count])

                        var arc = Path()
                        arc.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: startAngle + sweep, clockwise: false)
                        context.stroke(arc, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                        startAngle += sweep
                    }
                    let innerR = radius - lineWidth / 2 - 2
                    context.fill(Circle().path(in: CGRect(x: center.x - innerR, y: center.y - innerR, width: innerR * 2, height: innerR * 2)), with: .color(Color.App.cardBackground))
                }

                VStack(spacing: 2) {
                    Text("¥\(Int(total))")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(Color.App.textBlack)
                    Text(centerLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.App.textSecondary)
                }
                .position(center)
            }
        }
        .drawingGroup()  // 将多层 Canvas 合并为单个 GPU 纹理，减少合成开销
    }
}

// MARK: - 面积折线图（Canvas 绘制 + 渐变面积 + 峰值 + 长按十字线 + 储蓄线）
struct AreaChartView: View {
    let data: [(label: String, expense: Double, income: Double, saving: Double)]
    private let chartPadding: CGFloat = 30
    @State private var selectedIndex: Int? = nil

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let allVals = data.flatMap { [$0.expense, $0.income, $0.saving] }
            let maxVal = max(allVals.max() ?? 1, 1)
            let minVal = min(allVals.min() ?? 0, 0)
            let range = maxVal - minVal
            let count = max(data.count, 2)

            ZStack {
                Canvas { context, size in
                    func pt(_ i: Int, _ val: Double) -> CGPoint {
                        let x = w * CGFloat(i) / CGFloat(count - 1)
                        let normalized = range > 0 ? (val - minVal) / range : 0.5
                        let y = h - h * CGFloat(normalized) - chartPadding + 15
                        return CGPoint(x: x, y: max(15, min(y, h - 5)))
                    }

                    // 绘制面积渐变
                    var areaPath = Path()
                    var expPath = Path()
                    for (i, item) in data.enumerated() {
                        let p = pt(i, item.expense)
                        if i == 0 {
                            areaPath.move(to: CGPoint(x: p.x, y: h))
                            areaPath.addLine(to: p)
                            expPath.move(to: p)
                        } else {
                            areaPath.addLine(to: p)
                            expPath.addLine(to: p)
                        }
                    }
                    if let lastPt = data.indices.last.map({ pt($0, data[$0].expense) }) {
                        areaPath.addLine(to: CGPoint(x: lastPt.x, y: h))
                        areaPath.closeSubpath()
                    }
                    
                    context.fill(areaPath, with: .linearGradient(Gradient(colors: [Color.App.primaryGreen.opacity(0.3), Color.App.primaryGreen.opacity(0)]), startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: h)))
                    context.stroke(expPath, with: .color(Color.App.primaryGreen), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    // 绘制收入线
                    var incPath = Path()
                    for (i, item) in data.enumerated() {
                        let p = pt(i, item.income)
                        if i == 0 { incPath.move(to: p) } else { incPath.addLine(to: p) }
                    }
                    context.stroke(incPath, with: .color(Color.App.lightOrange), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    // 绘制储蓄线（紫色虚线）
                    var savPath = Path()
                    for (i, item) in data.enumerated() {
                        let p = pt(i, item.saving)
                        if i == 0 { savPath.move(to: p) } else { savPath.addLine(to: p) }
                    }
                    context.stroke(savPath, with: .color(Color.purple.opacity(0.7)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round, dash: [6, 4]))

                    let innerDotColor = Color.white
                    for (i, item) in data.enumerated() {
                        let ep = pt(i, item.expense)
                        context.fill(Circle().path(in: CGRect(x: ep.x-3.5, y: ep.y-3.5, width: 7, height: 7)), with: .color(Color.App.darkGreen))
                        context.fill(Circle().path(in: CGRect(x: ep.x-2, y: ep.y-2, width: 4, height: 4)), with: .color(innerDotColor))
                        let ip = pt(i, item.income)
                        context.fill(Circle().path(in: CGRect(x: ip.x-3.5, y: ip.y-3.5, width: 7, height: 7)), with: .color(Color.App.darkOrange))
                        context.fill(Circle().path(in: CGRect(x: ip.x-2, y: ip.y-2, width: 4, height: 4)), with: .color(innerDotColor))
                    }

                    // 长按十字线
                    if let idx = selectedIndex, idx < data.count {
                        let x = w * CGFloat(idx) / CGFloat(count - 1)
                        let ep = pt(idx, data[idx].expense)
                        let ip = pt(idx, data[idx].income)
                        let sp = pt(idx, data[idx].saving)

                        var dashPath = Path()
                        dashPath.move(to: CGPoint(x: x, y: 10))
                        dashPath.addLine(to: CGPoint(x: x, y: h - 5))
                        context.stroke(dashPath, with: .color(Color.gray.opacity(0.5)),
                                       style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))

                        context.fill(Circle().path(in: CGRect(x: ep.x-8, y: ep.y-8, width: 16, height: 16)), with: .color(Color.App.darkGreen))
                        context.fill(Circle().path(in: CGRect(x: ep.x-4, y: ep.y-4, width: 8, height: 8)), with: .color(innerDotColor))
                        context.fill(Circle().path(in: CGRect(x: ip.x-8, y: ip.y-8, width: 16, height: 16)), with: .color(Color.App.darkOrange))
                        context.fill(Circle().path(in: CGRect(x: ip.x-4, y: ip.y-4, width: 8, height: 8)), with: .color(innerDotColor))
                        context.fill(Circle().path(in: CGRect(x: sp.x-8, y: sp.y-8, width: 16, height: 16)), with: .color(Color.purple.opacity(0.7)))
                        context.fill(Circle().path(in: CGRect(x: sp.x-4, y: sp.y-4, width: 8, height: 8)), with: .color(innerDotColor))
                    }
                }

                // 数据气泡（长按时显示）
                if let idx = selectedIndex, idx < data.count {
                    let item = data[idx]
                    let x = w * CGFloat(idx) / CGFloat(count - 1)
                    let bubbleW: CGFloat = 110
                    let bubbleX = min(max(x, bubbleW / 2 + 4), w - bubbleW / 2 - 4)

                    VStack(spacing: 4) {
                        Text(item.label)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color.App.textBlack.opacity(0.6))
                        HStack(spacing: 4) {
                            Circle().fill(Color.App.darkGreen).frame(width: 6, height: 6)
                            Text("支出 ¥\(Int(item.expense))")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(Color.App.darkGreen)
                        HStack(spacing: 4) {
                            Circle().fill(Color.App.darkOrange).frame(width: 6, height: 6)
                            Text("收入 ¥\(Int(item.income))")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(Color.App.darkOrange)
                        HStack(spacing: 4) {
                            Circle().fill(Color.purple.opacity(0.7)).frame(width: 6, height: 6)
                            Text("储蓄 ¥\(Int(item.saving))")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(Color.purple.opacity(0.7))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.App.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                    .position(x: bubbleX, y: 28)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                LongPressGesture(minimumDuration: 0.25)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onChanged { value in
                        switch value {
                        case .second(true, let drag):
                            if let location = drag?.location {
                                let step = w / CGFloat(count - 1)
                                let idx = Int(round(location.x / step))
                                selectedIndex = max(0, min(idx, data.count - 1))
                            }
                        default: break
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.easeOut(duration: 0.15)) { selectedIndex = nil }
                    }
            )
        }
    }
}

// MARK: - 预算健康度条
struct BudgetHealthBar: View {
    let project: Project
    var periodSpent: Double? = nil

    var body: some View {
        // 一次性算出，避免 spent (project.totalSpent) 在 body 里多次遍历账单
        let spent = periodSpent ?? project.totalSpent
        let ratio = project.budget > 0 ? spent / project.budget : 0
        let progress = min(ratio, 1.0)
        let progressColor: Color = ratio >= 1.0 ? Color.App.redExpense
            : (ratio >= 0.8 ? Color(hex: "#FFA500") : Color.App.darkGreen)
        let projectColor = Color(hex: project.colorHex)

        return VStack(spacing: 4) {
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(projectColor.opacity(0.3))
                        .frame(width: 16, height: 16)
                        .overlay(AppIconView(name: project.icon, size: 8, color: projectColor))
                    Text(project.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.App.textBlack)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("¥\(spent.formatted(.number.precision(.fractionLength(0)))) / ¥\(project.budget.formatted(.number.precision(.fractionLength(0))))")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(progressColor)
                    Text("\(Int(ratio * 100))%")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
            ZStack(alignment: .leading) {
                Capsule().fill(Color.gray.opacity(0.1))
                Capsule()
                    .fill(LinearGradient(colors: [projectColor.opacity(0.6), progressColor], startPoint: .leading, endPoint: .trailing))
                    .frame(maxWidth: .infinity)
                    .scaleEffect(x: max(0.001, CGFloat(progress)), y: 1, anchor: .leading)
            }
            .frame(height: 4)
        }
    }
}

// MARK: - 智能洞察卡片 (豚言豚语)
struct InsightCardView: View {
    let transactions: [Transaction]
    let expense: Double
    let income: Double

    @State private var aiAdvice: String?
    @State private var isLoadingAdvice = false
    @State private var showAdviceSheet = false

    private var surplus: Double { income - expense }

    private var savingText: String {
        if transactions.isEmpty { return "还没有记录，先记一笔开始吧～" }
        let expenseTx = transactions.filter { $0.type == .expense }
        let byCategory = Dictionary(grouping: expenseTx, by: { $0.categoryName })
        if let topCat = byCategory.max(by: { $0.value.reduce(0) { $0 + $1.amount } < $1.value.reduce(0) { $0 + $1.amount } }) {
            let topAmt = topCat.value.reduce(0) { $0 + $1.amount }
            return "「\(topCat.key)」是本期间最大支出项（¥\(Int(topAmt))）。适当规划一下，会更从容～"
        }
        return "记录越多，小满越了解你的财务习惯，快去记一笔吧！"
    }

    private var healthText: String {
        if transactions.isEmpty { return "财务数据还是空白，保持平静的心情，慢慢记录起来吧 🌿" }
        if surplus > 0 { return "干得漂亮！本期间结余 ¥\(Int(surplus))，财务状态就像泡在温泉里一样舒适 ♨️" }
        else if income == 0 { return "本期间支出 ¥\(Int(expense))，还没有录入收入，记得补上哦～" }
        else { return "本期间支出超出收入 ¥\(Int(abs(surplus)))，不过偶尔犒劳自己也没关系，慢慢调整就好 🦫" }
    }

    private var topCategories: [(name: String, amount: Double)] {
        let expenseTx = transactions.filter { $0.type == .expense }
        let byCategory = Dictionary(grouping: expenseTx, by: { $0.categoryName })
        return byCategory.map { (name: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }) }.sorted { $0.amount > $1.amount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 8) {
                Text("豚言豚语")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(Color.App.textBlack)
                Text("🦫").font(.system(size: 20))
            }

            InsightMiniCard(icon: "lightbulb", title: "节省方案", text: savingText, bgColor: Color.App.primaryGreen.opacity(0.35), titleColor: Color.App.darkGreen)
            InsightMiniCard(icon: "chart.line.uptrend.xyaxis", title: "健康提醒", text: healthText, bgColor: Color.App.lightOrange.opacity(0.45), titleColor: Color.App.darkOrangeBrown)

            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 24).fill(Color.App.darkGreen)
                VStack(alignment: .leading, spacing: 16) {
                    Text("优化财务结构，\n让增长更自然。")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(.white)
                        .lineSpacing(4)

                    Button(action: {
                        AnalyticsManager.shared.trackEvent(eventId: "analytics_click_report", eventName: "点击深度报告")
                        generateAIAdvice()
                    }) {
                        HStack {
                            if isLoadingAdvice {
                                ProgressView().tint(Color.App.darkGreen)
                                Text("AI 分析中...").font(.system(size: 14, weight: .bold)).foregroundColor(Color.App.darkGreen)
                            } else {
                                Text("立即生成深度报告").font(.system(size: 14, weight: .bold)).foregroundColor(Color.App.darkGreen)
                                Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold)).foregroundColor(Color.App.darkGreen)
                            }
                        }
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                    }
                    .disabled(isLoadingAdvice)
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showAdviceSheet) {
            AIAdviceSheet(advice: aiAdvice ?? "")
        }
    }

    private func generateAIAdvice() {
        isLoadingAdvice = true
        Task {
            do {
                let advice = try await LLMService.shared.generateFinancialAdvice(expense: expense, income: income, topCategories: topCategories)
                await MainActor.run { aiAdvice = advice; isLoadingAdvice = false; showAdviceSheet = true }
            } catch {
                await MainActor.run { isLoadingAdvice = false; aiAdvice = "抱歉，AI分析暂时不可用，请稍后再试。"; showAdviceSheet = true }
            }
        }
    }
}

// MARK: - 子卡片
struct InsightMiniCard: View {
    let icon: String
    let title: String
    let text: String
    let bgColor: Color
    let titleColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold)).foregroundColor(titleColor)
                Text(title).font(.system(size: 14, weight: .heavy)).foregroundColor(titleColor)
            }
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.App.textBlack.opacity(0.75))
                .lineSpacing(5)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - AI 建议弹窗
struct AIAdviceSheet: View {
    @Environment(\.presentationMode) var presentationMode
    let advice: String

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color.App.primaryGreen.opacity(0.3)).frame(width: 56, height: 56)
                            Text("🦫").font(.system(size: 28))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("小满的财务建议").font(.system(size: 20, weight: .heavy)).foregroundColor(Color.App.textBlack)
                            Text("AI 深度分析").font(.system(size: 13)).foregroundColor(.gray)
                        }
                    }
                    .padding(.bottom, 8)

                    Text(advice)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.App.textBlack.opacity(0.85))
                        .lineSpacing(8)

                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill").font(.system(size: 14)).foregroundColor(.blue)
                        Text("以上建议由AI生成，仅供参考").font(.system(size: 12)).foregroundColor(.gray)
                    }
                    .padding(.top, 12)
                }
                .padding(24)
            }
            .background(Color.App.backgroundGray.ignoresSafeArea())
            .navigationTitle("AI 财务建议")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { presentationMode.wrappedValue.dismiss() }.foregroundColor(Color.App.darkGreen)
                }
            }
        }
    }
}

// MARK: - 空状态
struct EmptyStateView: View {
    let message: String
    var body: some View {
        HStack(spacing: 10) {
            Text("🦫").font(.system(size: 20))
            Text(message).font(.system(size: 14, weight: .medium)).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - Date 扩展
extension Date {
    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy年M月"
        return f
    }()
    
    private static let monthOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M月"
        return f
    }()

    var monthYearDisplay: String {
        return Self.monthYearFormatter.string(from: self)
    }
    var monthDisplay: String {
        return Self.monthOnlyFormatter.string(from: self)
    }
}

// MARK: - 趋势详情页
struct TrendDetailView: View {
    let transactions: [Transaction]
    let periodLabel: String
    @Environment(\.presentationMode) var presentationMode

    private struct DayData: Identifiable {
        let id = UUID()
        let date: Date
        let label: String
        let expense: Double
        let income: Double
    }

    @State private var dailyData: [DayData] = []

    private func computeDailyData() {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: transactions) { cal.startOfDay(for: $0.date) }
        let weekDayNames = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let computed = grouped.map { (date, txs) in
            let exp = txs.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
            let inc = txs.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
            let m = cal.component(.month, from: date)
            let d = cal.component(.day, from: date)
            let weekday = cal.component(.weekday, from: date) - 1
            return DayData(date: date, label: "\(m)月\(d)日 \(weekDayNames[weekday])", expense: exp, income: inc)
        }
        .sorted { $0.date < $1.date }
        
        dailyData = computed
    }

    private var peakExpenseDay: DayData? { dailyData.max(by: { $0.expense < $1.expense }) }
    private var peakIncomeDay: DayData? { dailyData.max(by: { $0.income < $1.income }) }
    private var totalExpense: Double { dailyData.reduce(0) { $0 + $1.expense } }
    private var totalIncome: Double { dailyData.reduce(0) { $0 + $1.income } }
    private var avgDailyExpense: Double {
        guard !dailyData.isEmpty else { return 0 }
        return totalExpense / Double(dailyData.count)
    }
    private var avgDailyIncome: Double {
        guard !dailyData.isEmpty else { return 0 }
        return totalIncome / Double(dailyData.count)
    }

    private var trendChartData: [(label: String, expense: Double, income: Double, saving: Double)] {
        dailyData.map { (label: $0.label, expense: $0.expense, income: $0.income, saving: $0.income - $0.expense) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // 顶部导航
                HStack {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.App.textBlack)
                    }
                    Spacer()
                    Text("趋势详情")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(Color.App.textBlack)
                    Spacer()
                    Color.clear.frame(width: 24, height: 24)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                // 时间段标签
                Text(periodLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)

                // 概览卡片
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        TrendStatCard(title: "总支出", value: totalExpense, color: Color.App.darkGreen, icon: "arrow.down.circle.fill")
                        TrendStatCard(title: "总收入", value: totalIncome, color: Color.App.darkOrange, icon: "arrow.up.circle.fill")
                    }
                    HStack(spacing: 12) {
                        TrendStatCard(title: "日均支出", value: avgDailyExpense, color: Color.App.darkGreen.opacity(0.7), icon: "chart.bar.fill")
                        TrendStatCard(title: "日均收入", value: avgDailyIncome, color: Color.App.darkOrange.opacity(0.7), icon: "chart.bar.fill")
                    }
                }
                .padding(.horizontal, 24)

                // 峰值分析
                if let peak = peakExpenseDay, peak.expense > 0 {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("峰值分析")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundColor(Color.App.textBlack)

                        HStack(spacing: 12) {
                            PeakCard(title: "支出最高日", day: peak.label, amount: peak.expense, color: Color.App.redExpense)
                            if let peakInc = peakIncomeDay, peakInc.income > 0 {
                                PeakCard(title: "收入最高日", day: peakInc.label, amount: peakInc.income, color: Color.App.darkGreen)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }

                // 趋势图
                if !trendChartData.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("每日收支趋势")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundColor(Color.App.textBlack)

                        HStack(spacing: 16) {
                            HStack(spacing: 6) {
                                Capsule().fill(Color.App.primaryGreen).frame(width: 16, height: 4)
                                Text("支出").font(.system(size: 11, weight: .bold)).foregroundColor(.gray)
                            }
                            HStack(spacing: 6) {
                                Capsule().fill(Color.App.lightOrange).frame(width: 16, height: 4)
                                Text("收入").font(.system(size: 11, weight: .bold)).foregroundColor(.gray)
                            }
                        }

                        AreaChartView(data: trendChartData)
                            .frame(height: 200)
                    }
                    .padding(20)
                    .background(Color.App.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding(.horizontal, 24)
                }

                // 每日明细列表
                LazyVStack(alignment: .leading, spacing: 12) {
                    Text("每日明细")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(Color.App.textBlack)

                    if dailyData.isEmpty {
                        EmptyStateView(message: "暂无交易记录")
                    } else {
                        ForEach(dailyData) { day in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(day.label)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(Color.App.textBlack)
                                    let net = day.income - day.expense
                                    Text(net >= 0 ? "结余 ¥\(Int(net))" : "超支 ¥\(Int(abs(net)))")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(net >= 0 ? Color.App.darkGreen : Color.App.redExpense)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    if day.expense > 0 {
                                        Text("-¥\(Int(day.expense))")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color.App.redExpense)
                                    }
                                    if day.income > 0 {
                                        Text("+¥\(Int(day.income))")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color.App.darkGreen)
                                    }
                                }
                            }
                            .padding(14)
                            .background(Color.App.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 24)
            }
        }
        .background(Color.App.backgroundGray.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            computeDailyData()
        }
        .onChange(of: transactions.count) { _, _ in
            computeDailyData()
        }
    }
}

// MARK: - 趋势统计卡片
struct TrendStatCard: View {
    let title: String
    let value: Double
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }
            Text("¥\(Int(value))")
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(Color.App.textBlack)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - 峰值分析卡片
struct PeakCard: View {
    let title: String
    let day: String
    let amount: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)
            Text("¥\(Int(amount))")
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(color)
            Text(day)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.App.textBlack.opacity(0.6))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    AnalyticsView()
        .environmentObject(AppStore(modelContext: try! ModelContainer(for: Project.self, Transaction.self, Category.self, ChatHistory.self, MemoryRule.self).mainContext))
}