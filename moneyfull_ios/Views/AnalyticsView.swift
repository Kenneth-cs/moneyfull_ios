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

// MARK: - 财务统计页
struct AnalyticsView: View {
    @EnvironmentObject var store: AppStore
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
    @State private var showCustomRangeSheet = false
    @State private var chartDimension: ChartDimension = .byProject
    @State private var selectedProjectForChart: Project?
    @State private var allTransactions: [Transaction] = []

    // MARK: - 时间过滤
    private var filteredTransactions: [Transaction] {
        let calendar = Calendar.current
        switch timeRange {
        case .week:
            guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: selectedWeekStart) else { return [] }
            return allTransactions.filter { $0.date >= selectedWeekStart && $0.date < weekEnd }
        case .month:
            return allTransactions.filter { calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month) }
        case .year:
            return allTransactions.filter { calendar.component(.year, from: $0.date) == selectedYear }
        case .custom:
            return allTransactions.filter { $0.date >= customStartDate && $0.date <= customEndDate }
        }
    }

    private var periodExpenseTransactions: [Transaction] {
        filteredTransactions.filter { $0.type == .expense }
    }

    // MARK: - 环形图数据（多维度）
    private var donutSegments: [(name: String, amount: Double, colorHex: String)] {
        switch chartDimension {
        case .byProject:
            var dict: [String: (Double, String)] = [:]
            for tx in periodExpenseTransactions {
                let name = tx.project?.name ?? "未分类"
                let color = tx.project?.colorHex ?? "#EEEEEE"
                dict[name] = ((dict[name]?.0 ?? 0) + tx.amount, color)
            }
            return dict.map { (name: $0.key, amount: $0.value.0, colorHex: $0.value.1) }.sorted { $0.amount > $1.amount }

        case .allCategories:
            var dict: [String: (Double, String)] = [:]
            for tx in periodExpenseTransactions {
                let name = tx.categoryName
                let color = tx.categoryColorHex
                dict[name] = ((dict[name]?.0 ?? 0) + tx.amount, color)
            }
            return dict.map { (name: $0.key, amount: $0.value.0, colorHex: $0.value.1) }.sorted { $0.amount > $1.amount }

        case .projectCategories:
            guard let project = selectedProjectForChart ?? store.activeProjects.first else { return [] }
            var dict: [String: (Double, String)] = [:]
            for tx in periodExpenseTransactions where tx.project?.id == project.id {
                let name = tx.categoryName
                let color = tx.categoryColorHex
                dict[name] = ((dict[name]?.0 ?? 0) + tx.amount, color)
            }
            return dict.map { (name: $0.key, amount: $0.value.0, colorHex: $0.value.1) }.sorted { $0.amount > $1.amount }
        }
    }

    private var totalExpense: Double { donutSegments.reduce(0) { $0 + $1.amount } }

    // MARK: - 趋势图数据（自适应）
    private var trendData: [(label: String, expense: Double, income: Double)] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        var result: [(label: String, expense: Double, income: Double)] = []

        switch timeRange {
        case .year:
            formatter.dateFormat = "M月"
            for m in 1...12 {
                guard let date = calendar.date(from: DateComponents(year: selectedYear, month: m)) else { continue }
                let txs = allTransactions.filter { calendar.isDate($0.date, equalTo: date, toGranularity: .month) }
                let exp = txs.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
                let inc = txs.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
                result.append((label: formatter.string(from: date), expense: exp, income: inc))
            }

        case .month:
            let range = calendar.range(of: .day, in: .month, for: selectedMonth) ?? 1..<32
            let step = range.count > 20 ? 5 : 1
            formatter.dateFormat = "d日"
            for day in stride(from: range.lowerBound, to: range.upperBound, by: step) {
                guard let date = calendar.date(from: DateComponents(year: calendar.component(.year, from: selectedMonth), month: calendar.component(.month, from: selectedMonth), day: day)) else { continue }
                let nextDate = calendar.date(byAdding: .day, value: step, to: date) ?? date
                let txs = allTransactions.filter { $0.date >= date && $0.date < nextDate }
                let exp = txs.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
                let inc = txs.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
                result.append((label: formatter.string(from: date), expense: exp, income: inc))
            }

        case .week:
            formatter.dateFormat = "E"
            for i in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: i, to: selectedWeekStart) else { continue }
                let nextDate = calendar.date(byAdding: .day, value: 1, to: date) ?? date
                let txs = allTransactions.filter { $0.date >= date && $0.date < nextDate }
                let exp = txs.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
                let inc = txs.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
                result.append((label: formatter.string(from: date), expense: exp, income: inc))
            }

        case .custom:
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: customStartDate), to: calendar.startOfDay(for: customEndDate)).day ?? 1
            let step = days > 60 ? 7 : (days > 20 ? 3 : 1)
            formatter.dateFormat = step >= 7 ? "M/d" : "d日"
            var current = calendar.startOfDay(for: customStartDate)
            while current < customEndDate {
                let next = calendar.date(byAdding: .day, value: step, to: current) ?? customEndDate
                let txs = allTransactions.filter { $0.date >= current && $0.date < next }
                let exp = txs.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
                let inc = txs.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
                result.append((label: formatter.string(from: current), expense: exp, income: inc))
                current = next
            }
        }
        return result
    }

    private var budgetProjects: [Project] { store.activeProjects.filter { $0.budget > 0 } }

    // MARK: - 环比计算
    private var previousPeriodExpense: Double {
        let calendar = Calendar.current
        var startDate: Date?
        var endDate: Date?
        switch timeRange {
        case .week:
            startDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedWeekStart)
            endDate = selectedWeekStart
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: selectedMonth)
            endDate = selectedMonth
        case .year:
            startDate = calendar.date(from: DateComponents(year: selectedYear - 1, month: 1, day: 1))
            endDate = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1))
        case .custom:
            let days = calendar.dateComponents([.day], from: customStartDate, to: customEndDate).day ?? 30
            startDate = calendar.date(byAdding: .day, value: -days, to: customStartDate)
            endDate = customStartDate
        }
        guard let s = startDate, let e = endDate else { return 0 }
        return allTransactions.filter { $0.date >= s && $0.date < e && $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    private var expenseChangePercent: Double? {
        guard previousPeriodExpense > 0 else { return nil }
        return (periodExpenseTransactions.reduce(0) { $0 + $1.amount } - previousPeriodExpense) / previousPeriodExpense
    }

    // MARK: - 预算健康度（联动时间维度）
    private func projectPeriodSpent(_ project: Project) -> Double {
        periodExpenseTransactions.filter { $0.project?.id == project.id }.reduce(0) { $0 + $1.amount }
    }

    // MARK: - 时间显示文案
    private var periodDisplayText: String {
        switch timeRange {
        case .week:
            let f = DateFormatter(); f.dateFormat = "M/d"; let end = Calendar.current.date(byAdding: .day, value: 6, to: selectedWeekStart)!; return "\(f.string(from: selectedWeekStart)) - \(f.string(from: end))"
        case .month:
            return selectedMonth.monthYearDisplay
        case .year:
            return "\(selectedYear)年"
        case .custom:
            let f = DateFormatter(); f.dateFormat = "M/d"; return "\(f.string(from: customStartDate)) - \(f.string(from: customEndDate))"
        }
    }

    private var trendTitle: String {
        switch timeRange {
        case .week: return "本周收支"
        case .month: return "本月收支"
        case .year: return "全年收支"
        case .custom: return "区间收支"
        }
    }

    // MARK: - 前后导航
    private func navigatePrev() {
        let cal = Calendar.current
        switch timeRange {
        case .week: selectedWeekStart = cal.date(byAdding: .weekOfYear, value: -1, to: selectedWeekStart) ?? selectedWeekStart
        case .month: selectedMonth = cal.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
        case .year: selectedYear -= 1
        case .custom: break
        }
    }

    private func navigateNext() {
        let cal = Calendar.current
        switch timeRange {
        case .week: selectedWeekStart = cal.date(byAdding: .weekOfYear, value: 1, to: selectedWeekStart) ?? selectedWeekStart
        case .month: selectedMonth = cal.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
        case .year: selectedYear += 1
        case .custom: break
        }
    }

    // MARK: - Body
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                PageHeader(title: "财务统计")

                // MARK: 时间维度切换
                timeRangeSelector

                // MARK: 日期导航
                dateNavigator

                // MARK: 环形图卡片
                donutChartCard

                // MARK: 趋势折线图
                trendChartCard

                // MARK: 预算健康度
                budgetHealthCard

                // MARK: 豚言豚语
                InsightCardView(transactions: filteredTransactions, expense: periodExpenseTransactions.reduce(0) { $0 + $1.amount }, income: filteredTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount })
                    .padding(.horizontal, 24)

                Spacer().frame(height: 16)
            }
        }
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 110) }
        .background(Color.App.backgroundGray.ignoresSafeArea())
        .onAppear {
            allTransactions = store.fetchAllTransactions()
        }
        .sheet(isPresented: $showMonthPicker) {
            MonthYearPickerSheet(selectedMonth: $selectedMonth)
        }
        .sheet(isPresented: $showCustomRangeSheet) {
            CustomDateRangeSheet(startDate: $customStartDate, endDate: $customEndDate)
        }
    }

    // MARK: - 时间维度选择器
    private var timeRangeSelector: some View {
        HStack(spacing: 0) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { timeRange = range } }) {
                    Text(range.rawValue)
                        .font(.system(size: 13, weight: timeRange == range ? .bold : .medium))
                        .foregroundColor(timeRange == range ? Color.white : Color.App.textBlack.opacity(0.6))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(timeRange == range ? Color.App.darkGreen : Color.clear)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(4)
        .background(Color.App.tabBackground)
        .clipShape(Capsule())
        .padding(.horizontal, 24)
    }

    // MARK: - 日期导航器
    private var dateNavigator: some View {
        HStack(spacing: 16) {
            if timeRange != .custom {
                Button(action: navigatePrev) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.App.darkGreen)
                        .frame(width: 36, height: 36)
                        .background(Color.App.tabBackground)
                        .clipShape(Circle())
                }
            }

            Button(action: {
                if timeRange == .month { showMonthPicker = true }
                else if timeRange == .custom { showCustomRangeSheet = true }
            }) {
                Text(periodDisplayText)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.App.textBlack.opacity(0.8))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.App.tabBackground)
                    .clipShape(Capsule())
            }

            if timeRange != .custom {
                Button(action: navigateNext) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.App.darkGreen)
                        .frame(width: 36, height: 36)
                        .background(Color.App.tabBackground)
                        .clipShape(Circle())
                }
            }
        }
    }

    // MARK: - 环形图卡片
    private var donutChartCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("支出占比")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(Color.App.textBlack)
                Spacer()
                if let pct = expenseChangePercent {
                    HStack(spacing: 4) {
                        Image(systemName: pct >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 11, weight: .bold))
                        Text("环比 \(Int(abs(pct) * 100))%")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(pct >= 0 ? Color.App.redExpense : Color.App.darkGreen)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background((pct >= 0 ? Color.App.redExpense : Color.App.darkGreen).opacity(0.1))
                    .clipShape(Capsule())
                }
                Text(periodDisplayText)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)
            }

            // 维度切换
            HStack(spacing: 0) {
                ForEach(ChartDimension.allCases, id: \.self) { dim in
                    Button(action: { withAnimation(.easeInOut(duration: 0.2)) { chartDimension = dim } }) {
                        Text(dim.rawValue)
                            .font(.system(size: 12, weight: chartDimension == dim ? .bold : .medium))
                            .foregroundColor(chartDimension == dim ? Color.white : Color.App.textBlack.opacity(0.6))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(chartDimension == dim ? Color.App.darkGreen : Color.clear)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(3)
            .background(Color.App.tabBackground)
            .clipShape(Capsule())

            // 项目内分类时，显示项目选择器
            if chartDimension == .projectCategories {
                projectPickerForChart
            }

            if totalExpense == 0 {
                EmptyStateView(message: "暂无支出记录")
            } else {
                DonutChartView(segments: donutSegments, total: totalExpense)
                    .frame(height: 220)

                VStack(spacing: 12) {
                    ForEach(donutSegments.prefix(5), id: \.name) { seg in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color(hex: seg.colorHex))
                                .frame(width: 12, height: 12)
                            Text(seg.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.App.textBlack.opacity(0.8))
                            Spacer()
                            Text("¥\(seg.amount.formatted(.number.precision(.fractionLength(0))))")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color.App.textBlack)
                            Text("(\(Int(seg.amount / totalExpense * 100))%)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
        .padding(28)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 40))
        .padding(.horizontal, 24)
    }

    // MARK: - 项目选择器（用于项目内分类维度）
    private var projectPickerForChart: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.activeProjects) { project in
                    Button(action: { selectedProjectForChart = project }) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: project.colorHex).opacity(0.3))
                                .frame(width: 20, height: 20)
                                .overlay(
                                    AppIconView(name: project.icon, size: 10, color: Color(hex: project.colorHex))
                                )
                            Text(project.name)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background((selectedProjectForChart?.id == project.id) ? Color.App.darkGreen.opacity(0.15) : Color.App.tabBackground)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke((selectedProjectForChart?.id == project.id) ? Color.App.darkGreen : Color.clear, lineWidth: 1)
                        )
                    }
                    .foregroundColor(Color.App.textBlack.opacity(0.8))
                }
            }
        }
        .onAppear {
            if selectedProjectForChart == nil { selectedProjectForChart = store.activeProjects.first }
        }
    }

    // MARK: - 趋势图卡片
    private var trendChartCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(trendTitle)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(Color.App.textBlack)
                Spacer()
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

            if trendData.isEmpty || trendData.allSatisfy({ $0.expense == 0 && $0.income == 0 }) {
                EmptyStateView(message: "暂无趋势数据")
            } else {
                LineChartView(data: trendData)
                    .frame(height: 160)

                HStack {
                    ForEach(trendData, id: \.label) { item in
                        Text(item.label)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(28)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 40))
        .padding(.horizontal, 24)
    }

    // MARK: - 预算健康度卡片
    private var budgetHealthCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("预算健康度")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(Color.App.textBlack)
                Spacer()
                let totalBudget = budgetProjects.reduce(0) { $0 + $1.budget }
                if totalBudget > 0 {
                    Text("总预算: ¥\(totalBudget.formatted(.number.precision(.fractionLength(0))))")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.App.darkGreen)
                }
            }

            if budgetProjects.isEmpty {
                EmptyStateView(message: "还没有设置预算的项目")
            } else {
                VStack(spacing: 16) {
                    ForEach(budgetProjects) { project in
                        BudgetHealthBar(project: project, periodSpent: projectPeriodSpent(project))
                    }
                }
            }
        }
        .padding(28)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 40))
        .padding(.horizontal, 24)
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
                        ForEach(2020...2030, id: \.self) { year in
                            Text("\(year)年").tag(year)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 160)
                    .clipped()

                    Picker("月份", selection: $selectedMonthNum) {
                        ForEach(1...12, id: \.self) { month in
                            Text("\(month)月").tag(month)
                        }
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
        return [
            ("近30天", last30, now),
            ("近90天", last90, now),
            ("今年以来", yearStart, now),
            ("按发薪日(15号)", payDayStart, payDayEnd),
        ]
    }()

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("快捷预设")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.App.textBlack.opacity(0.7))

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(presets, id: \.label) { preset in
                            Button(action: {
                                startDate = preset.start
                                endDate = preset.end
                            }) {
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
                    Text("自定义区间")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.App.textBlack.opacity(0.7))

                    DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                        .font(.system(size: 14))

                    DatePicker("结束日期", selection: $endDate, displayedComponents: .date)
                        .font(.system(size: 14))
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}

// MARK: - 环形图（Canvas 绘制）
struct DonutChartView: View {
    let segments: [(name: String, amount: Double, colorHex: String)]
    let total: Double

    private let lineWidth: CGFloat = 36
    private let chartColors: [String] = [
        "#A8E6CF", "#FDD1B4", "#DCDE8D", "#DBEAFE", "#F3E8FF",
        "#FFD6C4", "#C8E6C9", "#FFF9C4", "#FCE4EC", "#E8EAF6"
    ]

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
                        arc.addArc(center: center, radius: radius,
                                   startAngle: startAngle, endAngle: startAngle + sweep,
                                   clockwise: false)
                        context.stroke(arc, with: .color(color),
                                       style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                        startAngle += sweep
                    }
                    let innerR = radius - lineWidth / 2 - 4
                    context.fill(Circle().path(in: CGRect(
                        x: center.x - innerR, y: center.y - innerR,
                        width: innerR * 2, height: innerR * 2
                    )), with: .color(Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(Color(hex: "#1C1C1E")) : UIColor.white })))
                }

                VStack(spacing: 4) {
                    Text("¥\(Int(total).formatted())")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(Color.App.textBlack)
                    Text("总支出")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                }
                .position(center)
            }
        }
    }
}

// MARK: - 折线图（Canvas 绘制）
struct LineChartView: View {
    let data: [(label: String, expense: Double, income: Double)]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let maxVal = max(
                data.map { $0.expense }.max() ?? 1,
                data.map { $0.income }.max() ?? 1,
                1
            )
            let count = max(data.count, 2)

            Canvas { context, size in
                func pt(_ i: Int, _ val: Double, _ padding: CGFloat = 20) -> CGPoint {
                    let x = w * CGFloat(i) / CGFloat(count - 1)
                    let y = h - h * CGFloat(val / maxVal) - padding
                    return CGPoint(x: x, y: max(padding, y))
                }

                var expPath = Path()
                for (i, item) in data.enumerated() {
                    let p = pt(i, item.expense)
                    if i == 0 { expPath.move(to: p) } else { expPath.addLine(to: p) }
                }
                context.stroke(expPath, with: .color(Color.App.primaryGreen),
                               style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                var incPath = Path()
                for (i, item) in data.enumerated() {
                    let p = pt(i, item.income)
                    if i == 0 { incPath.move(to: p) } else { incPath.addLine(to: p) }
                }
                context.stroke(incPath, with: .color(Color.App.lightOrange),
                               style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                let innerDotColor = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(Color(hex: "#1C1C1E")) : UIColor.white })
                for (i, item) in data.enumerated() {
                    let ep = pt(i, item.expense)
                    context.fill(Circle().path(in: CGRect(x: ep.x-5, y: ep.y-5, width: 10, height: 10)), with: .color(Color.App.darkGreen))
                    context.fill(Circle().path(in: CGRect(x: ep.x-3, y: ep.y-3, width: 6, height: 6)), with: .color(innerDotColor))
                    let ip = pt(i, item.income)
                    context.fill(Circle().path(in: CGRect(x: ip.x-5, y: ip.y-5, width: 10, height: 10)), with: .color(Color.App.darkOrange))
                    context.fill(Circle().path(in: CGRect(x: ip.x-3, y: ip.y-3, width: 6, height: 6)), with: .color(innerDotColor))
                }
            }
        }
    }
}

// MARK: - 预算健康度条
struct BudgetHealthBar: View {
    let project: Project
    var periodSpent: Double? = nil

    private var spent: Double { periodSpent ?? project.totalSpent }
    private var progress: Double { min(spent / project.budget, 1.0) }
    private var progressColor: Color {
        if spent / project.budget >= 1.0 { return Color.App.redExpense }
        if spent / project.budget >= 0.8 { return Color(hex: "#FFA500") }
        return Color.App.darkGreen
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: project.colorHex).opacity(0.3))
                        .frame(width: 28, height: 28)
                        .overlay(AppIconView(name: project.icon, size: 12, color: Color(hex: project.colorHex)))
                    Text(project.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.App.textBlack)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("¥\(spent.formatted(.number.precision(.fractionLength(0)))) / ¥\(project.budget.formatted(.number.precision(.fractionLength(0))))")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(progressColor)
                    Text("\(Int(spent / project.budget * 100))%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.08)).frame(height: 12)
                    Capsule()
                        .fill(LinearGradient(colors: [Color(hex: project.colorHex).opacity(0.6), progressColor], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * progress, height: 12)
                }
            }
            .frame(height: 12)
        }
    }
}

// MARK: - 智能洞察卡片
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
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(Color.App.textBlack)
                Text("🦫").font(.system(size: 22))
            }

            InsightMiniCard(icon: "lightbulb", title: "节省方案", text: savingText, bgColor: Color.App.primaryGreen.opacity(0.35), titleColor: Color.App.darkGreen)
            InsightMiniCard(icon: "chart.line.uptrend.xyaxis", title: "健康提醒", text: healthText, bgColor: Color.App.lightOrange.opacity(0.45), titleColor: Color.App.darkOrangeBrown)

            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 24).fill(Color.App.darkGreen)
                VStack(alignment: .leading, spacing: 16) {
                    Text("优化财务结构，\n让增长更自然。")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(.white)
                        .lineSpacing(4)

                    Button(action: {
                        AnalyticsManager.shared.trackEvent(eventId: "analytics_click_report", eventName: "点击深度报告")
                        generateAIAdvice()
                    }) {
                        HStack {
                            if isLoadingAdvice {
                                ProgressView().tint(Color.App.darkGreen)
                                Text("AI 分析中...").font(.system(size: 15, weight: .bold)).foregroundColor(Color.App.darkGreen)
                            } else {
                                Text("立即生成深度报告").font(.system(size: 15, weight: .bold)).foregroundColor(Color.App.darkGreen)
                                Image(systemName: "arrow.right").font(.system(size: 13, weight: .bold)).foregroundColor(Color.App.darkGreen)
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
                Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundColor(titleColor)
                Text(title).font(.system(size: 15, weight: .heavy)).foregroundColor(titleColor)
            }
            Text(text)
                .font(.system(size: 14, weight: .medium))
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
    var monthYearDisplay: String {
        let f = DateFormatter(); f.dateFormat = "yyyy年M月"; return f.string(from: self)
    }
    var monthDisplay: String {
        let f = DateFormatter(); f.dateFormat = "M月"; return f.string(from: self)
    }
}

// MARK: - TabButton
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(isSelected ? Color.App.darkGreen : Color.App.textBlack.opacity(0.6))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(isSelected ? Color.App.cardBackground : Color.clear)
                .clipShape(Capsule())
                .shadow(color: isSelected ? Color.black.opacity(0.05) : Color.clear, radius: 2, x: 0, y: 1)
        }
    }
}

#Preview {
    AnalyticsView()
        .environmentObject(AppStore(modelContext: try! ModelContainer(for: Project.self, Transaction.self, Category.self, ChatHistory.self, MemoryRule.self).mainContext))
}
