import SwiftUI
import SwiftData
import Charts

/// 经营看板主视图（替代 ProjectEarningView）
struct ProjectDashboardView: View {
    let project: Project
    
    @EnvironmentObject private var store: AppStore
    @State private var selectedDimension: DashboardDimension = .cashFlow
    @State private var selectedPeriod: ProjectDashboardPeriod = .month
    
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
                    Text(formatCurrency(project.availableCash))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(project.availableCash >= 0 ? .green : .red)
                }
                
                Spacer()
                
                // 本月净现金流
                VStack(alignment: .trailing, spacing: 4) {
                    Text("本月净现金流")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(project.monthlyNetCashFlow))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(project.monthlyNetCashFlow >= 0 ? .green : .red)
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
            CashFlowDimensionCard(project: project, period: selectedPeriod)
        case .income:
            IncomeDimensionCard(project: project, period: selectedPeriod)
        case .cost:
            CostDimensionCard(project: project, period: selectedPeriod)
        case .profit:
            ProfitDimensionCard(project: project, period: selectedPeriod)
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
        Chart {
            ForEach(trendData, id: \.date) { item in
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
        Chart {
            ForEach(trendData, id: \.date) { item in
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
        Chart {
            ForEach(stackedCostData, id: \.date) { item in
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
        Chart {
            ForEach(profitTrendData, id: \.date) { item in
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
    
    // MARK: - 趋势数据
    
    private var trendData: [(date: Date, amount: Double)] {
        let calendar = Calendar.current
        let now = Date()
        var data: [(date: Date, amount: Double)] = []
        
        // 根据选择的时间周期生成过去6个周期的数据
        let periodsToShow = 6
        for i in 0..<periodsToShow {
            let date: Date
            switch selectedPeriod {
            case .month:
                date = calendar.date(byAdding: .month, value: -i, to: now) ?? now
            case .quarter:
                date = calendar.date(byAdding: .month, value: -i * 3, to: now) ?? now
            case .year:
                date = calendar.date(byAdding: .year, value: -i, to: now) ?? now
            }
            
            let amount = calculateAmountForPeriod(date: date, dimension: selectedDimension, period: selectedPeriod)
            data.append((date: date, amount: amount))
        }
        
        return data.reversed()
    }
    
    private func calculateAmountForPeriod(date: Date, dimension: DashboardDimension, period: ProjectDashboardPeriod) -> Double {
        let calendar = Calendar.current
        let startDate: Date
        
        switch period {
        case .month:
            startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
        case .quarter:
            let month = calendar.component(.month, from: date)
            let quarterStartMonth = ((month - 1) / 3) * 3 + 1
            startDate = calendar.date(from: DateComponents(year: calendar.component(.year, from: date), month: quarterStartMonth, day: 1)) ?? date
        case .year:
            startDate = calendar.date(from: DateComponents(year: calendar.component(.year, from: date), month: 1, day: 1)) ?? date
        }
        
        let endDate = calendar.date(byAdding: .month, value: 1, to: startDate) ?? date
        
        let transactions = (project.transactions ?? []).filter { $0.date >= startDate && $0.date < endDate }
        
        switch dimension {
        case .cashFlow:
            let income = transactions.filter { $0.type == .income }.reduce(0) { $0 + abs($1.amount) }
            let expense = transactions.filter { $0.type == .expense }.reduce(0) { $0 + abs($1.amount) }
            return income - expense
        case .income:
            return transactions.filter { $0.type == .income }.reduce(0) { $0 + abs($1.amount) }
        case .cost:
            return transactions.filter { $0.type == .expense }.reduce(0) { $0 + abs($1.amount) }
        case .profit:
            let income = transactions.filter { $0.type == .income }.reduce(0) { $0 + abs($1.amount) }
            let expense = transactions.filter { $0.type == .expense }.reduce(0) { $0 + abs($1.amount) }
            return income - expense
        }
    }
    
    // 成本堆叠数据
    private var stackedCostData: [(date: Date, type: String, amount: Double)] {
        let calendar = Calendar.current
        let now = Date()
        var data: [(date: Date, type: String, amount: Double)] = []
        
        let periodsToShow = 6
        for i in 0..<periodsToShow {
            let startDate: Date
            switch selectedPeriod {
            case .month:
                let monthDate = calendar.date(byAdding: .month, value: -i, to: now) ?? now
                startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate)) ?? monthDate
            case .quarter:
                let monthDate = calendar.date(byAdding: .month, value: -i * 3, to: now) ?? now
                let month = calendar.component(.month, from: monthDate)
                let quarterStartMonth = ((month - 1) / 3) * 3 + 1
                startDate = calendar.date(from: DateComponents(year: calendar.component(.year, from: monthDate), month: quarterStartMonth, day: 1)) ?? monthDate
            case .year:
                let yearDate = calendar.date(byAdding: .year, value: -i, to: now) ?? now
                startDate = calendar.date(from: DateComponents(year: calendar.component(.year, from: yearDate), month: 1, day: 1)) ?? yearDate
            }
            
            let endDate = calendar.date(byAdding: .month, value: 1, to: startDate) ?? startDate
            let transactions = (project.transactions ?? []).filter { $0.date >= startDate && $0.date < endDate && $0.type == .expense }
            
            let directCost = transactions.filter { $0.cashFlowType == "operating" }.reduce(0) { $0 + abs($1.amount) }
            let personalCost = transactions.filter { $0.cashFlowType == "personal" }.reduce(0) { $0 + abs($1.amount) }
            
            // 固定成本按月计算
            let fixedCostMonthly = (project.fixedCosts ?? []).filter { $0.isActive }.reduce(0) { $0 + $1.monthlyAmount }
            
            data.append((date: startDate, type: "直接成本", amount: directCost))
            data.append((date: startDate, type: "固定成本", amount: fixedCostMonthly))
            data.append((date: startDate, type: "生活成本", amount: personalCost))
        }
        
        return data.reversed()
    }
    
    // 利润趋势数据
    private var profitTrendData: [(date: Date, values: [(type: String, amount: Double)])] {
        let calendar = Calendar.current
        let now = Date()
        var data: [(date: Date, values: [(type: String, amount: Double)])] = []
        
        let periodsToShow = 6
        for i in 0..<periodsToShow {
            let startDate: Date
            switch selectedPeriod {
            case .month:
                let monthDate = calendar.date(byAdding: .month, value: -i, to: now) ?? now
                startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate)) ?? monthDate
            case .quarter:
                let monthDate = calendar.date(byAdding: .month, value: -i * 3, to: now) ?? now
                let month = calendar.component(.month, from: monthDate)
                let quarterStartMonth = ((month - 1) / 3) * 3 + 1
                startDate = calendar.date(from: DateComponents(year: calendar.component(.year, from: monthDate), month: quarterStartMonth, day: 1)) ?? monthDate
            case .year:
                let yearDate = calendar.date(byAdding: .year, value: -i, to: now) ?? now
                startDate = calendar.date(from: DateComponents(year: calendar.component(.year, from: yearDate), month: 1, day: 1)) ?? yearDate
            }
            
            let endDate = calendar.date(byAdding: .month, value: 1, to: startDate) ?? startDate
            let transactions = (project.transactions ?? []).filter { $0.date >= startDate && $0.date < endDate }
            
            let income = transactions.filter { $0.type == .income }.reduce(0) { $0 + abs($1.amount) }
            let directCost = transactions.filter { $0.type == .expense && $0.cashFlowType == "operating" }.reduce(0) { $0 + abs($1.amount) }
            let personalCost = transactions.filter { $0.type == .expense && $0.cashFlowType == "personal" }.reduce(0) { $0 + abs($1.amount) }
            let fixedCostMonthly = (project.fixedCosts ?? []).filter { $0.isActive }.reduce(0) { $0 + $1.monthlyAmount }
            
            let grossProfit = income - directCost
            let operatingNetProfit = grossProfit - fixedCostMonthly
            let taxReserve = max(0, operatingNetProfit * project.taxRate)
            let disposableIncome = operatingNetProfit - personalCost - taxReserve
            
            data.append((date: startDate, values: [
                (type: "毛利", amount: grossProfit),
                (type: "经营净利润", amount: operatingNetProfit),
                (type: "可支配收入", amount: disposableIncome)
            ]))
        }
        
        return data.reversed()
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
    let project: Project
    let period: ProjectDashboardPeriod
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Text("现金流分析")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text(period.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 累计可用资金
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("累计可用资金")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(project.availableCash))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(project.availableCash >= 0 ? .green : .red)
                }
                Spacer()
            }
            
            // 本月净现金流
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("本月净现金流")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(project.monthlyNetCashFlow))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(project.monthlyNetCashFlow >= 0 ? .green : .red)
                }
                Spacer()
            }
            
            // 经营/个人拆分
            VStack(alignment: .leading, spacing: 8) {
                Text("经营/个人现金流拆分")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 20) {
                    // 经营现金流
                    VStack(alignment: .leading, spacing: 4) {
                        Text("经营支出")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatCurrency(project.operatingCashFlow))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    // 个人现金流
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("个人支出")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatCurrency(project.personalCashFlow))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                
                // 进度条
                GeometryReader { geometry in
                    let total = project.operatingCashFlow + project.personalCashFlow
                    let operatingWidth = total > 0 ? geometry.size.width * (project.operatingCashFlow / total) : geometry.size.width * 0.5
                    
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
            
            // 未来30天刚性支出
            if project.upcomingFixedCosts > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("未来30天刚性支出")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(formatCurrency(project.upcomingFixedCosts))
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
    let project: Project
    let period: ProjectDashboardPeriod
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Text("收入分析")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text(period.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 已到账收入
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("已到账收入")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(project.monthlyIncome))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                Spacer()
            }
            
            // 应收账款摘要
            if project.totalReceivable > 0 {
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
                            Text(formatCurrency(project.totalReceivable))
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        if project.overdueReceivable > 0 {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("逾期金额")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                Text(formatCurrency(project.overdueReceivable))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            
            // 业务线收入占比
            if !project.incomeByCategory.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("业务线收入占比")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // 环形图
                    Chart(project.incomeByCategory.prefix(5), id: \.categoryName) { item in
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
                            Text("\(project.incomeByCategory.count)个分类")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // 分类明细
                    VStack(spacing: 8) {
                        ForEach(project.incomeByCategory.prefix(5), id: \.categoryName) { item in
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
    let project: Project
    let period: ProjectDashboardPeriod
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Text("成本分析")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text(period.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 三类成本三格卡
            HStack(spacing: 12) {
                // 直接成本
                VStack(spacing: 4) {
                    Text("直接成本")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(project.directCost))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    Text("\(Int(costPercentage.direct))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                
                // 固定成本
                VStack(spacing: 4) {
                    Text("固定成本")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(project.fixedCostMonthly))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                    Text("\(Int(costPercentage.fixed))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                
                // 个人成本
                VStack(spacing: 4) {
                    Text("生活成本")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(project.personalCost))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                    Text("\(Int(costPercentage.personal))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
            }
            
            // 直接成本明细（按分类）
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
            
            // 固定经营成本明细
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
                
                if project.fixedCostMonthly > 0 {
                    // 显示固定成本列表
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
                        Text("\(formatCurrency(project.fixedCostMonthly))/月")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                } else {
                    Text("暂无固定成本，点击管理添加")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 生活成本明细（按分类）
            if project.personalCost > 0 {
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
    
    // 直接成本按分类聚合
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
    
    // 生活成本按分类聚合
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
    
    private var costPercentage: (direct: Double, fixed: Double, personal: Double) {
        let total = project.directCost + project.fixedCostMonthly + project.personalCost
        guard total > 0 else { return (0, 0, 0) }
        return (
            direct: (project.directCost / total) * 100,
            fixed: (project.fixedCostMonthly / total) * 100,
            personal: (project.personalCost / total) * 100
        )
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
    let project: Project
    let period: ProjectDashboardPeriod
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Text("利润分析")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text(period.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 利润瀑布（进度条式）
            VStack(spacing: 12) {
                // 总收入
                HStack {
                    Text("总收入")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatCurrency(project.monthlyIncome))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                // 进度条
                GeometryReader { geometry in
                    let maxValue = max(project.monthlyIncome, 1)
                    let directCostWidth = geometry.size.width * (project.directCost / maxValue)
                    let fixedCostWidth = geometry.size.width * (project.fixedCostMonthly / maxValue)
                    let personalCostWidth = geometry.size.width * (project.personalCost / maxValue)
                    let taxWidth = geometry.size.width * (project.taxReserve / maxValue)
                    
                    VStack(spacing: 4) {
                        // 总收入条
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.green)
                            .frame(width: geometry.size.width, height: 8)
                        
                        // 直接成本条
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue)
                            .frame(width: directCostWidth, height: 8)
                        
                        // 固定成本条
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.orange)
                            .frame(width: fixedCostWidth, height: 8)
                        
                        // 个人成本条
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.purple)
                            .frame(width: personalCostWidth, height: 8)
                        
                        // 税费条
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.red)
                            .frame(width: taxWidth, height: 8)
                    }
                }
                .frame(height: 50)
                
                // 毛利
                HStack {
                    Text("= 毛利")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(formatCurrency(project.grossProfit))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(project.grossProfit >= 0 ? .green : .red)
                }
                
                // 毛利率
                HStack {
                    Text("毛利率")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(project.grossMargin * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(project.grossMargin >= 0 ? .green : .red)
                }
                
                // 经营净利润
                HStack {
                    Text("- 固定成本")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatCurrency(project.fixedCostMonthly))
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
                
                HStack {
                    Text("= 经营净利润")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(formatCurrency(project.operatingNetProfit))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(project.operatingNetProfit >= 0 ? .green : .red)
                }
                
                // 可支配收入
                HStack {
                    Text("- 生活成本 - 税费")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatCurrency(project.personalCost + project.taxReserve))
                        .font(.subheadline)
                        .foregroundColor(.purple)
                }
                
                HStack {
                    Text("= 可支配收入")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(formatCurrency(project.disposableIncome))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(project.disposableIncome >= 0 ? .green : .red)
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