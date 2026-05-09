import SwiftUI
import SwiftData

// MARK: - 财务统计页（全真实数据）
struct AnalyticsView: View {
    @EnvironmentObject var store: AppStore
    @State private var trendTab = "month"
    @State private var selectedMonth: Date = {
        // 默认展示本月
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
    }()
    @State private var showMonthPicker = false
    
    // 当前月的所有交易
    private var monthTransactions: [Transaction] {
        store.recentTransactions.filter {
            Calendar.current.isDate($0.date, equalTo: selectedMonth, toGranularity: .month)
        }
    }
    
    // 按项目汇总支出（用于环形图）
    private var projectExpenseSummary: [(name: String, amount: Double, colorHex: String)] {
        var dict: [String: (Double, String)] = [:]
        for tx in monthTransactions where tx.type == .expense {
            let pname = tx.project?.name ?? "未分类"
            let pcolor = tx.project?.colorHex ?? "#EEEEEE"
            let current = dict[pname]?.0 ?? 0
            dict[pname] = (current + tx.amount, pcolor)
        }
        return dict.map { (name: $0.key, amount: $0.value.0, colorHex: $0.value.1) }
            .sorted { $0.amount > $1.amount }
    }
    
    private var totalExpense: Double { projectExpenseSummary.reduce(0) { $0 + $1.amount } }
    
    // 近6个月每月支出数据（用于折线图）
    private var monthlyTrend: [(label: String, expense: Double, income: Double)] {
        var result: [(label: String, expense: Double, income: Double)] = []
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "M月"
        for i in stride(from: 5, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .month, value: -i, to: Date()) else { continue }
            let txs = store.recentTransactions.filter {
                calendar.isDate($0.date, equalTo: date, toGranularity: .month)
            }
            let expense = txs.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
            let income = txs.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
            result.append((label: formatter.string(from: date), expense: expense, income: income))
        }
        return result
    }
    
    // 有预算的项目（用于预算健康度）
    private var budgetProjects: [Project] {
        store.activeProjects.filter { $0.budget > 0 }
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // MARK: Header
                PageHeader(title: "财务统计")
                
                // MARK: 月份切换器
                VStack(spacing: 8) {
                    Text("点击切换统计月份")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    Button(action: { showMonthPicker = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .bold))
                            Text(selectedMonth.monthYearDisplay)
                                .font(.system(size: 14, weight: .bold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(Color.App.textBlack.opacity(0.8))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.App.tabBackground)
                        .clipShape(Capsule())
                    }
                }
                
                // MARK: 环形图卡片（真实数据）
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Text("项目支出占比")
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundColor(Color.App.textBlack)
                        Spacer()
                        Text("\(selectedMonth.monthDisplay)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                    }
                    
                    if totalExpense == 0 {
                        EmptyStateView(message: "本月暂无支出记录")
                    } else {
                        // 环形图
                        DonutChartView(segments: projectExpenseSummary, total: totalExpense)
                            .frame(height: 220)
                        
                        // 图例
                        VStack(spacing: 12) {
                            ForEach(projectExpenseSummary.prefix(4), id: \.name) { seg in
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
                
                // MARK: 近6月趋势折线图（真实数据）
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Text("收支趋势")
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundColor(Color.App.textBlack)
                        Spacer()
                        Text("近6个月")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                    }
                    
                    // 图例
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
                    
                    // 折线图
                    LineChartView(data: monthlyTrend)
                        .frame(height: 160)
                    
                    // X轴标签
                    HStack {
                        ForEach(monthlyTrend, id: \.label) { item in
                            Text(item.label)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(28)
                .background(Color.App.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 40))
                .padding(.horizontal, 24)
                
                // MARK: 预算健康度（真实数据）
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
                                BudgetHealthBar(project: project)
                            }
                        }
                    }
                }
                .padding(28)
                .background(Color.App.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 40))
                .padding(.horizontal, 24)
                
                // MARK: 豚言豚语（智能洞察）
                InsightCardView(transactions: monthTransactions, expense: totalExpense,
                                income: store.monthlyIncome)
                    .padding(.horizontal, 24)
                
                Spacer().frame(height: 16)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 110)
        }
        .background(Color.App.backgroundGray.ignoresSafeArea())
        .sheet(isPresented: $showMonthPicker) {
            MonthPickerSheet(selectedMonth: $selectedMonth)
                .onDisappear {
                    AnalyticsManager.shared.trackEvent(eventId: "analytics_change_month", eventName: "切换统计月份")
                }
        }
    }
}

// MARK: - 环形图（Canvas 绘制，无外部依赖）
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
                        
                        let color = i < segments.count
                            ? Color(hex: seg.colorHex)
                            : Color(hex: chartColors[i % chartColors.count])
                        
                        var arc = Path()
                        arc.addArc(center: center, radius: radius,
                                   startAngle: startAngle, endAngle: startAngle + sweep,
                                   clockwise: false)
                        context.stroke(arc, with: .color(color),
                                       style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                        startAngle += sweep
                    }
                    // 中间圆（镂空效果）
                    let innerR = radius - lineWidth / 2 - 4
                    context.fill(Circle().path(in: CGRect(
                        x: center.x - innerR, y: center.y - innerR,
                        width: innerR * 2, height: innerR * 2
                    )), with: .color(Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(Color(hex: "#1C1C1E")) : UIColor.white })))
                }
                
                // 中心文字
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
            let count = max(data.count, 2) // 至少2个点，防止除零
            
            Canvas { context, size in
                func pt(_ i: Int, _ val: Double, _ padding: CGFloat = 20) -> CGPoint {
                    let x = w * CGFloat(i) / CGFloat(count - 1)
                    let y = h - h * CGFloat(val / maxVal) - padding
                    return CGPoint(x: x, y: max(padding, y))
                }
                
                // 支出线
                var expPath = Path()
                for (i, item) in data.enumerated() {
                    let p = pt(i, item.expense)
                    if i == 0 { expPath.move(to: p) } else { expPath.addLine(to: p) }
                }
                context.stroke(expPath, with: .color(Color.App.primaryGreen),
                               style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                
                // 收入线
                var incPath = Path()
                for (i, item) in data.enumerated() {
                    let p = pt(i, item.income)
                    if i == 0 { incPath.move(to: p) } else { incPath.addLine(to: p) }
                }
                context.stroke(incPath, with: .color(Color.App.lightOrange),
                               style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                
                // 数据点
                let innerDotColor = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(Color(hex: "#1C1C1E")) : UIColor.white })
                for (i, item) in data.enumerated() {
                    let ep = pt(i, item.expense)
                    context.fill(Circle().path(in: CGRect(x: ep.x-5, y: ep.y-5, width: 10, height: 10)),
                                 with: .color(Color.App.darkGreen))
                    context.fill(Circle().path(in: CGRect(x: ep.x-3, y: ep.y-3, width: 6, height: 6)),
                                 with: .color(innerDotColor))

                    let ip = pt(i, item.income)
                    context.fill(Circle().path(in: CGRect(x: ip.x-5, y: ip.y-5, width: 10, height: 10)),
                                 with: .color(Color.App.darkOrange))
                    context.fill(Circle().path(in: CGRect(x: ip.x-3, y: ip.y-3, width: 6, height: 6)),
                                 with: .color(innerDotColor))
                }
            }
        }
    }
}

// MARK: - 预算健康度条（真实 Project）
struct BudgetHealthBar: View {
    let project: Project
    
    private var progress: Double { min(project.budgetProgress, 1.0) }
    private var progressColor: Color {
        if project.budgetProgress >= 1.0 { return Color.App.redExpense }
        if project.budgetProgress >= 0.8 { return Color(hex: "#FFA500") }
        return Color.App.darkGreen
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: project.colorHex).opacity(0.3))
                        .frame(width: 28, height: 28)
                        .overlay(
                            AppIconView(name: project.icon, size: 12,
                                        color: Color(hex: project.colorHex))
                        )
                    Text(project.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.App.textBlack)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("¥\(project.totalSpent.formatted(.number.precision(.fractionLength(0)))) / ¥\(project.budget.formatted(.number.precision(.fractionLength(0))))")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(progressColor)
                    Text("\(Int(project.budgetProgress * 100))%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.08)).frame(height: 12)
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color(hex: project.colorHex).opacity(0.6), progressColor],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * progress, height: 12)
                }
            }
            .frame(height: 12)
        }
    }
}

// MARK: - 智能洞察卡片（豚言豚语）
struct InsightCardView: View {
    let transactions: [Transaction]
    let expense: Double
    let income: Double
    
    private var surplus: Double { income - expense }
    
    // MARK: 节省方案文案（绿卡）
    private var savingTitle: String { "节省方案" }
    private var savingText: String {
        if transactions.isEmpty {
            return "这个月还没有记录，先记一笔开始吧～"
        }
        // 找出支出最多的类别
        let expenseTx = transactions.filter { $0.type == .expense }
        let byCategory = Dictionary(grouping: expenseTx, by: { $0.categoryName })
        if let topCat = byCategory.max(by: { a, b in
            a.value.reduce(0) { $0 + $1.amount } < b.value.reduce(0) { $0 + $1.amount }
        }) {
            let topAmt = topCat.value.reduce(0) { $0 + $1.amount }
            return "「\(topCat.key)」是本月最大支出项（¥\(Int(topAmt))）。适当规划一下，下个月会更从容～"
        }
        return "记录越多，水豚越了解你的财务习惯，快去记一笔吧！"
    }
    
    // MARK: 健康提醒文案（橙卡）
    private var healthTitle: String { "健康提醒" }
    private var healthText: String {
        if transactions.isEmpty {
            return "财务数据还是空白，保持平静的心情，慢慢记录起来吧 🌿"
        }
        if surplus > 0 {
            return "干得漂亮！本月结余 ¥\(Int(surplus))，财务状态就像泡在温泉里一样舒适 ♨️"
        } else if income == 0 {
            return "本月支出 ¥\(Int(expense))，还没有录入收入，记得补上哦，水豚在等你～"
        } else {
            return "本月支出超出收入 ¥\(Int(abs(surplus)))，不过偶尔犒劳自己也没关系，下个月慢慢调整回来就好 🦫"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标题行
            HStack(spacing: 8) {
                Text("豚言豚语")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(Color.App.textBlack)
                Text("🦫")
                    .font(.system(size: 22))
            }
            
            // 节省方案卡（绿色）
            InsightMiniCard(
                icon: "lightbulb",
                title: savingTitle,
                text: savingText,
                bgColor: Color.App.primaryGreen.opacity(0.35),
                titleColor: Color.App.darkGreen
            )
            
            // 健康提醒卡（橙色）
            InsightMiniCard(
                icon: "chart.line.uptrend.xyaxis",
                title: healthTitle,
                text: healthText,
                bgColor: Color.App.lightOrange.opacity(0.45),
                titleColor: Color.App.darkOrangeBrown
            )
            
            // CTA 深绿卡
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.App.darkGreen)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("优化财务结构，\n让增长更自然。")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(.white)
                        .lineSpacing(4)
                    
                    // 生成报告占位按钮（后续可接 AI 报告功能）
                    Button(action: {
                        AnalyticsManager.shared.trackEvent(eventId: "analytics_click_report", eventName: "点击深度报告")
                    }) {
                        HStack {
                            Text("立即生成深度报告")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Color.App.darkGreen)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.App.darkGreen)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                    }
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - 豚言豚语子卡片
struct InsightMiniCard: View {
    let icon: String
    let title: String
    let text: String
    let bgColor: Color
    let titleColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(titleColor)
                Text(title)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(titleColor)
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

// MARK: - 空状态
struct EmptyStateView: View {
    let message: String
    var body: some View {
        HStack(spacing: 10) {
            Text("🦫")
                .font(.system(size: 20))
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - 月份选择弹窗
struct MonthPickerSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedMonth: Date
    
    var body: some View {
        NavigationView {
            DatePicker("选择月份", selection: $selectedMonth, displayedComponents: [.date])
                .datePickerStyle(.graphical)
                .padding()
                .navigationTitle("选择统计月份")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("确定") { presentationMode.wrappedValue.dismiss() }
                    }
                }
        }
    }
}

// MARK: - Date 扩展
extension Date {
    var monthYearDisplay: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy年M月"
        return f.string(from: self)
    }
    var monthDisplay: String {
        let f = DateFormatter()
        f.dateFormat = "M月"
        return f.string(from: self)
    }
}

// MARK: - TabButton（供 AnalyticsView 使用）
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
        .environmentObject(AppStore(modelContext: try! ModelContainer(for: Project.self, Transaction.self, Category.self).mainContext))
}
