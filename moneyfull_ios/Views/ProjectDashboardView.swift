import SwiftUI
import SwiftData
import Charts

/// 经营看板主视图（替代 ProjectEarningView）
struct ProjectDashboardView: View {
    let project: Project
    
    @EnvironmentObject private var store: AppStore
    @State private var selectedDimension: DashboardDimension = .cashFlow
    @State private var selectedPeriod: ProjectDashboardPeriod = .month
    @State private var stats: DashboardProjectStats?
    
    private var safeStats: DashboardProjectStats {
        stats ?? ProjectStatsCalculator.calculateDashboardStats(project: project)
    }
    
    private func loadStats() {
        stats = ProjectStatsCalculator.calculateDashboardStats(project: project)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 顶部现金流总览卡
                cashFlowOverviewCard
                
                // 维度选择器
                dimensionPicker
                
                // 时间周期选择器
                periodPicker
                
                // 动态维度卡
                dimensionCard
                
                // 趋势图
                trendChart
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("经营看板")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                PresentationBackButton()
            }
        }
        .task(id: store.dataVersion) {
            loadStats()
        }
        .onChange(of: selectedPeriod) { _, _ in
            // 周期变化时趋势图会自动用静态方法重算，但保险起见刷新一次 stats
            loadStats()
        }
        .onChange(of: selectedDimension) { _, _ in
            loadStats()
        }
    }
    
    // MARK: - 现金流总览卡
    
    private var cashFlowOverviewCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("现金流总览")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text(selectedPeriod.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 20) {
                // 可用资金
                VStack(alignment: .leading, spacing: 4) {
                    Text("累计可用资金")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(safeStats.availableCash))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(safeStats.availableCash >= 0 ? .green : .red)
                }
                
                Spacer()
                
                // 本月净现金流
                VStack(alignment: .trailing, spacing: 4) {
                    Text("本月净现金流")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(safeStats.monthlyNetCashFlow))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(safeStats.monthlyNetCashFlow >= 0 ? .green : .red)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - 维度选择器
    
    private var dimensionPicker: some View {
        Picker("维度", selection: $selectedDimension) {
            ForEach(DashboardDimension.allCases, id: \.self) { dimension in
                Text(dimension.displayName).tag(dimension)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal, 4)
    }
    
    // MARK: - 时间周期选择器
    
    private var periodPicker: some View {
        HStack(spacing: 12) {
            ForEach(ProjectDashboardPeriod.allCases, id: \.self) { period in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPeriod = period
                    }
                }) {
                    Text(period.displayName)
                        .font(.subheadline)
                        .fontWeight(selectedPeriod == period ? .semibold : .regular)
                        .foregroundColor(selectedPeriod == period ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedPeriod == period ? Color.accentColor : Color(.systemBackground))
                        .cornerRadius(20)
                }
            }
            Spacer()
        }
    }
    
    // MARK: - 动态维度卡
    
    @ViewBuilder
    private var dimensionCard: some View {
        switch selectedDimension {
        case .cashFlow:
            CashFlowDimensionCard(stats: safeStats, period: selectedPeriod)
        case .income:
            IncomeDimensionCard(stats: safeStats, period: selectedPeriod, project: project)
        case .cost:
            CostDimensionCard(stats: safeStats, period: selectedPeriod, project: project)
        case .profit:
            ProfitDimensionCard(stats: safeStats, period: selectedPeriod)
        }
    }
    
    // MARK: - 趋势图
    
    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(selectedDimension.displayName)趋势")
                .font(.headline)
                .foregroundColor(.primary)
            
            switch selectedDimension {
            case .cashFlow:
                cashFlowTrendChart
            case .income:
                incomeTrendChart
            case .cost:
                costTrendChart
            case .profit:
                profitTrendChart
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // 现金流趋势 - 折线图
    private var cashFlowTrendChart: some View {
        let data = DashboardProjectStats.trend(for: project, period: selectedPeriod, dimension: .cashFlow)
        return Chart {
            ForEach(data, id: \.date) { item in
                LineMark(
                    x: .value("日期", item.date),
                    y: .value("金额", item.amount)
                )
                .foregroundStyle(Color.accentColor.gradient)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("日期", item.date),
                    y: .value("金额", item.amount)
                )
                .foregroundStyle(Color.accentColor.opacity(0.1).gradient)
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis { trendXAxis }
        .chartYAxis { trendYAxis }
        .frame(height: 200)
    }

    // 收入趋势 - 柱状图
    private var incomeTrendChart: some View {
        let data = DashboardProjectStats.trend(for: project, period: selectedPeriod, dimension: .income)
        return Chart {
            ForEach(data, id: \.date) { item in
                BarMark(
                    x: .value("日期", item.date, unit: .month),
                    y: .value("金额", item.amount)
                )
                .foregroundStyle(Color.green.gradient)
                .cornerRadius(4)
            }
        }
        .chartXAxis { trendXAxis }
        .chartYAxis { trendYAxis }
        .frame(height: 200)
    }

    // 成本趋势 - 三类成本堆叠图
    private var costTrendChart: some View {
        let data = DashboardProjectStats.stackedCostTrend(for: project, period: selectedPeriod)
        return Chart {
            ForEach(data, id: \.date) { item in
                BarMark(
                    x: .value("日期", item.date, unit: .month),
                    y: .value("金额", item.amount)
                )
                .foregroundStyle(by: .value("类型", item.type))
            }
        }
        .chartForegroundStyleScale([
            "直接成本": Color.blue,
            "固定成本": Color.orange,
            "生活成本": Color.purple
        ])
        .chartXAxis { trendXAxis }
        .chartYAxis { trendYAxis }
        .frame(height: 200)
    }

    // 利润趋势 - 三层利润折线图
    private var profitTrendChart: some View {
        let data = DashboardProjectStats.profitTrend(for: project, period: selectedPeriod)
        return Chart {
            ForEach(data, id: \.date) { item in
                ForEach(item.values, id: \.type) { value in
                    LineMark(
                        x: .value("日期", item.date),
                        y: .value("金额", value.amount)
                    )
                    .foregroundStyle(by: .value("类型", value.type))
                    .interpolationMethod(.catmullRom)
                }
            }
        }
        .chartForegroundStyleScale([
            "毛利": Color.green,
            "经营净利润": Color.blue,
            "可支配收入": Color.purple
        ])
        .chartXAxis { trendXAxis }
        .chartYAxis { trendYAxis }
        .frame(height: 200)
    }

    // 公共X轴
    private var trendXAxis: some AxisContent {
        AxisMarks(values: .stride(by: .month, count: 1)) { value in
            AxisGridLine()
            AxisValueLabel(centered: true) {
                if let date = value.as(Date.self) {
                    let month = Calendar.current.component(.month, from: date)
                    Text("\(month)月")
                }
            }
        }
    }

    // 公共Y轴
    private var trendYAxis: some AxisContent {
        AxisMarks { value in
            AxisGridLine()
            AxisValueLabel {
                Text(formatCurrency(value.as(Double.self) ?? 0))
            }
        }
    }

    // MARK: - 工具方法

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "¥0"
    }
}

// MARK: - 维度枚举

enum DashboardDimension: String, CaseIterable {
    case cashFlow = "cashFlow"
    case income = "income"
    case cost = "cost"
    case profit = "profit"
    
    var displayName: String {
        switch self {
        case .cashFlow: return "现金流"
        case .income: return "收入"
        case .cost: return "成本"
        case .profit: return "利润"
        }
    }
}

// MARK: - 经营看板时间周期枚举

enum ProjectDashboardPeriod: String, CaseIterable {
    case month = "month"
    case quarter = "quarter"
    case year = "year"
    
    var displayName: String {
        switch self {
        case .month: return "本月"
        case .quarter: return "本季"
        case .year: return "本年"
        }
    }
}

// MARK: - 现金流维度卡

struct CashFlowDimensionCard: View {
    let stats: DashboardProjectStats
    let period: ProjectDashboardPeriod

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("现金流分析")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text(period.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("累计可用资金")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(stats.availableCash))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(stats.availableCash >= 0 ? .green : .red)
                }
                Spacer()
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("本月净现金流")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(stats.monthlyNetCashFlow))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(stats.monthlyNetCashFlow >= 0 ? .green : .red)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("经营/个人现金流拆分")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("经营支出")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatCurrency(stats.operatingCashFlow))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("个人支出")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatCurrency(stats.personalCashFlow))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }

                GeometryReader { geometry in
                    let total = abs(stats.operatingCashFlow) + abs(stats.personalCashFlow)
                    let operatingWidth = total > 0 ? geometry.size.width * (abs(stats.operatingCashFlow) / total) : geometry.size.width * 0.5

                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue)
                            .frame(width: operatingWidth)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.orange)
                            .frame(width: geometry.size.width - operatingWidth - 2)
                    }
                }
                .frame(height: 8)
            }

            if stats.upcomingFixedCosts > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("未来30天刚性支出")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(formatCurrency(stats.upcomingFixedCosts))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("固定成本")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "¥0"
    }
}

// MARK: - 收入维度卡

struct IncomeDimensionCard: View {
    let stats: DashboardProjectStats
    let period: ProjectDashboardPeriod
    let project: Project

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("收入分析")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text(period.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("已到账收入")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(stats.monthlyIncome))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                Spacer()
            }

            if stats.totalReceivable > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("应收账款")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        NavigationLink(destination: ReceivableListView(project: project)) {
                            Text("管理 →")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("待回款总额")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatCurrency(stats.totalReceivable))
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }

                        Spacer()

                        if stats.overdueReceivable > 0 {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("逾期金额")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                Text(formatCurrency(stats.overdueReceivable))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }

            if !stats.incomeByCategory.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("业务线收入占比")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Chart(stats.incomeByCategory.prefix(5), id: \.categoryName) { item in
                        SectorMark(
                            angle: .value("金额", item.amount),
                            innerRadius: .ratio(0.6),
                            angularInset: 1.5
                        )
                        .foregroundStyle(colorForCategory(item.categoryName))
                        .cornerRadius(3)
                    }
                    .frame(height: 150)
                    .overlay {
                        VStack {
                            Text("收入构成")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(stats.incomeByCategory.count)个分类")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    VStack(spacing: 8) {
                        ForEach(stats.incomeByCategory.prefix(5), id: \.categoryName) { item in
                            HStack {
                                Circle()
                                    .fill(colorForCategory(item.categoryName))
                                    .frame(width: 10, height: 10)
                                Text(item.categoryName)
                                    .font(.caption)
                                Spacer()
                                Text(formatCurrency(item.amount))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("\(Int(item.percentage * 100))%")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "¥0"
    }

    private func colorForCategory(_ category: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red, .yellow, .cyan]
        let index = abs(category.hashValue) % colors.count
        return colors[index]
    }
}

// MARK: - 成本维度卡

struct CostDimensionCard: View {
    let stats: DashboardProjectStats
    let period: ProjectDashboardPeriod
    let project: Project

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("成本分析")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text(period.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("直接成本")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(stats.directCost))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    Text("\(Int(stats.costPercentage.direct))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)

                VStack(spacing: 4) {
                    Text("固定成本")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(stats.fixedCostMonthly))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                    Text("\(Int(stats.costPercentage.fixed))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)

                VStack(spacing: 4) {
                    Text("生活成本")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(stats.personalCost))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                    Text("\(Int(stats.costPercentage.personal))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
            }

            if !costByCategory.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("直接成本明细")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    VStack(spacing: 8) {
                        ForEach(costByCategory.prefix(5), id: \.categoryName) { item in
                            HStack {
                                Circle()
                                    .fill(colorForCategory(item.categoryName))
                                    .frame(width: 10, height: 10)
                                Text(item.categoryName)
                                    .font(.caption)
                                Spacer()
                                Text(formatCurrency(item.amount))
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("固定经营成本明细")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    NavigationLink(destination: FixedCostListView(project: project)) {
                        Text("管理 →")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                }

                if stats.fixedCostMonthly > 0 {
                    ForEach(project.fixedCosts?.prefix(3) ?? [], id: \.id) { cost in
                        HStack {
                            Image(systemName: "building.2.fill")
                                .foregroundColor(.orange)
                            Text(cost.name)
                                .font(.caption)
                            Spacer()
                            Text("\(formatCurrency(cost.amount))/月")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }

                    HStack {
                        Text("合计")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(formatCurrency(stats.fixedCostMonthly))/月")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                } else {
                    Text("暂无固定成本，点击管理添加")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if stats.personalCost > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("生活成本明细")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    VStack(spacing: 8) {
                        ForEach(personalCostByCategory.prefix(5), id: \.categoryName) { item in
                            HStack {
                                Circle()
                                    .fill(colorForCategory(item.categoryName))
                                    .frame(width: 10, height: 10)
                                Text(item.categoryName)
                                    .font(.caption)
                                Spacer()
                                Text(formatCurrency(item.amount))
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // 直接成本按分类聚合（仍按本月）
    private var costByCategory: [(categoryName: String, amount: Double)] {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now

        var categoryMap: [String: Double] = [:]
        for tx in (project.transactions ?? []) {
            if tx.date >= startOfMonth && tx.type == .expense && tx.cashFlowType == "operating" {
                categoryMap[tx.categoryName, default: 0] += abs(tx.amount)
            }
        }

        return categoryMap.map { (categoryName: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }

    // 生活成本按分类聚合（仍按本月）
    private var personalCostByCategory: [(categoryName: String, amount: Double)] {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now

        var categoryMap: [String: Double] = [:]
        for tx in (project.transactions ?? []) {
            if tx.date >= startOfMonth && tx.type == .expense && tx.cashFlowType == "personal" {
                categoryMap[tx.categoryName, default: 0] += abs(tx.amount)
            }
        }

        return categoryMap.map { (categoryName: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }

    private func colorForCategory(_ category: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red, .yellow, .cyan]
        let index = abs(category.hashValue) % colors.count
        return colors[index]
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "¥0"
    }
}

// MARK: - 利润维度卡

struct ProfitDimensionCard: View {
    let stats: DashboardProjectStats
    let period: ProjectDashboardPeriod

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("利润分析")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text(period.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 12) {
                HStack {
                    Text("总收入")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatCurrency(stats.monthlyIncome))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                GeometryReader { geometry in
                    let maxValue = max(stats.monthlyIncome, 1)
                    let directCostWidth = geometry.size.width * (stats.directCost / maxValue)
                    let fixedCostWidth = geometry.size.width * (stats.fixedCostMonthly / maxValue)
                    let personalCostWidth = geometry.size.width * (stats.personalCost / maxValue)
                    let taxWidth = geometry.size.width * (stats.taxReserve / maxValue)

                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.green)
                            .frame(width: geometry.size.width, height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue)
                            .frame(width: directCostWidth, height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.orange)
                            .frame(width: fixedCostWidth, height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.purple)
                            .frame(width: personalCostWidth, height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.red)
                            .frame(width: taxWidth, height: 8)
                    }
                }
                .frame(height: 50)

                HStack {
                    Text("= 毛利")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(formatCurrency(stats.grossProfit))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(stats.grossProfit >= 0 ? .green : .red)
                }

                HStack {
                    Text("毛利率")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(stats.grossMargin * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(stats.grossMargin >= 0 ? .green : .red)
                }

                HStack {
                    Text("- 固定成本")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatCurrency(stats.fixedCostMonthly))
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }

                HStack {
                    Text("= 经营净利润")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(formatCurrency(stats.operatingNetProfit))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(stats.operatingNetProfit >= 0 ? .green : .red)
                }

                HStack {
                    Text("- 生活成本 - 税费")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatCurrency(stats.personalCost + stats.taxReserve))
                        .font(.subheadline)
                        .foregroundColor(.purple)
                }

                HStack {
                    Text("= 可支配收入")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(formatCurrency(stats.disposableIncome))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(stats.disposableIncome >= 0 ? .green : .red)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "¥0"
    }
}

// MARK: - 中文返回按钮

struct PresentationBackButton: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Button(action: {
            dismiss()
        }) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                Text("返回")
                    .font(.system(size: 16))
            }
            .foregroundColor(.primary)
        }
    }
}

// MARK: - 预览

#Preview {
    NavigationView {
        ProjectDashboardView(project: Project(name: "预览项目", icon: "folder.fill", colorHex: "#A8E6CF"))
    }
    .environmentObject(AppStore(modelContext: try! ModelContainer(for: Project.self, Transaction.self, Category.self, ChatHistory.self, MemoryRule.self, RecurringBill.self, BudgetItem.self, TimeEntry.self, Receivable.self, FixedCost.self).mainContext))
}