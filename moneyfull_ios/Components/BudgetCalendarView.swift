import SwiftUI

// MARK: - 预算日历主视图
struct BudgetCalendarView: View {
    @EnvironmentObject var store: AppStore

    // 当前展示的月份（默认本月）
    @State private var displayMonth: Date = {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
    }()
    // 点击选中的日期（nil = 默认今日）
    @State private var selectedDay: Int? = nil

    // MARK: - 真实数据缓存
    @State private var dailyExpenses: [Int: Double] = [:]
    @State private var monthlyBudget: Double? = nil
    @State private var monthlyExpenseTotal: Double = 0
    @State private var todayExpense: Double = 0

    private let cal = Calendar.current
    private let weekSymbols = ["日", "一", "二", "三", "四", "五", "六"]

    // MARK: 便捷属性
    private var displayYear:  Int { cal.component(.year,  from: displayMonth) }
    private var displayMonthN: Int { cal.component(.month, from: displayMonth) }

    private var daysInMonth: Int {
        cal.range(of: .day, in: .month, for: displayMonth)!.count
    }
    // 本月第一天是星期几（0=日, 6=六）
    private var firstWeekdayOffset: Int {
        let firstDay = cal.date(from: DateComponents(year: displayYear, month: displayMonthN, day: 1))!
        return cal.component(.weekday, from: firstDay) - 1
    }
    // 是否为当前自然月
    private var isCurrentMonth: Bool {
        let now = Date()
        return displayYear == cal.component(.year, from: now)
            && displayMonthN == cal.component(.month, from: now)
    }
    // 是否为历史月（displayMonth < 当前月）
    private var isHistoryMonth: Bool {
        let now = Date()
        let currentYM = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        return displayMonth < currentYM
    }
    // 是否为未来月
    private var isFutureMonth: Bool {
        !isCurrentMonth && !isHistoryMonth
    }
    // 今日日期序号（仅当月有效）
    private var todayDay: Int? { isCurrentMonth ? cal.component(.day, from: Date()) : nil }
    // 底部摘要使用的日期（选中 > 今日 > 月末）
    private var activeDayForStats: Int { selectedDay ?? todayDay ?? daysInMonth }

    // MARK: 计算属性
    private var dailyBudget: Double {
        guard let budget = monthlyBudget else { return 0 }
        return budget / Double(daysInMonth)
    }

    /// BudgetStats（仅当前月有效）
    private var stats: BudgetStats? {
        guard let budget = monthlyBudget, isCurrentMonth else { return nil }
        return HomeBudgetService.calcStats(
            budget: budget,
            dailyExpenses: dailyExpenses,
            todayExpense: todayExpense
        )
    }

    // MARK: Body
    var body: some View {
        VStack(spacing: 0) {
            monthHeaderRow
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
            
            weekdayHeaderRow
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            
            calendarGridView
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            
            bottomSummaryCard
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
        .onAppear { loadMonthData() }
        .onChange(of: displayMonth) { loadMonthData() }
        // dataVersion 变化时刷新（新记录写入后自动更新）
        .task(id: store.dataVersion) {
            loadMonthData()
        }
    }

    // MARK: - 数据加载
    private func loadMonthData() {
        dailyExpenses = store.dailyExpenses(year: displayYear, month: displayMonthN)
        monthlyBudget = HomeBudgetService.budget(year: displayYear, month: displayMonthN)
        monthlyExpenseTotal = store.monthlyExpense(year: displayYear, month: displayMonthN)
        if isCurrentMonth {
            todayExpense = store.todayExpense()
        } else {
            todayExpense = 0
        }
    }

    // MARK: - 月份导航行
    private var monthHeaderRow: some View {
        HStack(spacing: 2) {
            Button { shiftMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.App.darkGreen)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

            Text("\(String(displayYear))年\(displayMonthN)月")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color.App.textBlack)

            Button { shiftMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.App.darkGreen)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

            Spacer()

            // 节奏状态胶囊
            if let stats = stats {
                PacePill(text: stats.paceLabel, isAlert: stats.isAlert)
            } else if isCurrentMonth && monthlyBudget == nil {
                // 未设置预算
                PacePill(text: "未设预算", isAlert: false)
            }
        }
    }

    // MARK: - 星期表头
    private var weekdayHeaderRow: some View {
        HStack(spacing: 0) {
            ForEach(weekSymbols, id: \.self) { sym in
                Text(sym)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.App.textOnPrimary.opacity(0.5))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - 日历格子区
    private var calendarGridView: some View {
        let totalCells = firstWeekdayOffset + daysInMonth
        let rows = (totalCells + 6) / 7

        return VStack(spacing: 0) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        dayCellView(index: row * 7 + col)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dayCellView(index: Int) -> some View {
        let day        = index - firstWeekdayOffset + 1
        let inMonth    = (day >= 1 && day <= daysInMonth)
        let isToday    = (day == todayDay)
        let isSelected = (day == selectedDay)
        let highlighted = isSelected || (selectedDay == nil && isToday)
        let expense: Double? = inMonth ? dailyExpenses[day] : nil
        let isOver     = (expense ?? 0) > dailyBudget && expense != nil && dailyBudget > 0

        // 上/下月补位日期数字
        let prevDays = cal.range(of: .day, in: .month,
            for: cal.date(byAdding: .month, value: -1, to: displayMonth)!)!.count
        let displayNum: Int = day < 1 ? (prevDays + day)
                            : day > daysInMonth ? (day - daysInMonth)
                            : day

        Button {
            guard inMonth else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedDay = (isSelected && isToday) ? nil : day
            }
        } label: {
            VStack(spacing: 2) {
                Text("\(displayNum)")
                    .font(.system(size: 13, weight: highlighted ? .bold : .medium))
                    .foregroundColor(
                        highlighted ? .white : (inMonth ? Color.App.textBlack : Color.App.textBlack.opacity(0.22))
                    )

                if inMonth {
                    if let exp = expense {
                        Text("¥\(Int(exp))")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(
                                highlighted ? .white.opacity(0.9) : (isOver ? Color.App.redExpense : Color(hex: "#20AE73"))
                            )
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                    } else {
                        Text("-")
                            .font(.system(size: 10))
                            .foregroundColor(highlighted ? .white.opacity(0.9) : Color.App.textOnPrimary.opacity(0.22))
                    }
                } else {
                    Text("-")
                        .font(.system(size: 10))
                        .foregroundColor(Color.App.textOnPrimary.opacity(0.22))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(
                Group {
                    if highlighted && inMonth {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(hex: "#20AE73"))
                    } else {
                        Color.clear
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .disabled(!inMonth)
    }

    // MARK: - 底部数据摘要卡
    @ViewBuilder
    private var bottomSummaryCard: some View {
        if isHistoryMonth {
            historyMonthSummary
        } else if isFutureMonth {
            futureMonthSummary
        } else {
            currentMonthSummary
        }
    }

    /// 当前月摘要
    private var currentMonthSummary: some View {
        let dayExp     = dailyExpenses[activeDayForStats] ?? 0
        let diff       = dayExp - dailyBudget
        let hasDayData = dayExp > 0
        let dayLabel   = (activeDayForStats == todayDay) ? "今日支出" : "\(activeDayForStats)日支出"

        return VStack(spacing: 8) {
            HStack(spacing: 0) {
                CalStatCell(
                    label: dayLabel,
                    value: hasDayData ? "¥\(Int(dayExp))" : "-",
                    color: Color(hex: "#1A1C1C")
                )
                calDivider(height: 36)
                CalStatCell(
                    label: "日均预算",
                    value: monthlyBudget != nil ? "¥\(Int(dailyBudget))" : "-",
                    color: Color(hex: "#1A1C1C"),
                    helpText: "月预算 ÷ 本月天数\n例：3000 ÷ 30 = 100"
                )
                calDivider(height: 36)

                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        Text(diff > 0 ? "超支" : "节省")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(diff > 0 ? Color.App.redExpense.opacity(0.7) : Color(hex: "#20AE73").opacity(0.7))
                            .lineLimit(1)
                        HelpTooltip(text: "今日支出 - 日均预算\n正数=超支，负数=节省")
                    }

                    if hasDayData {
                        Text("¥\(abs(Int(diff)))")
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundColor(diff > 0 ? Color.App.redExpense : Color(hex: "#20AE73"))
                            .minimumScaleFactor(0.75)
                            .lineLimit(1)
                        Text(diff > 0 ? "已超支 ¥\(abs(Int(diff)))" : "已节省 ¥\(abs(Int(diff)))")
                            .font(.system(size: 9))
                            .foregroundColor(diff > 0 ? Color.App.redExpense.opacity(0.5) : Color(hex: "#20AE73").opacity(0.5))
                    } else {
                        Text("-")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(Color(hex: "#1A1C1C"))
                        Text(" ")
                            .font(.system(size: 9))
                    }
                }
                .frame(maxWidth: .infinity)
            }

            Rectangle()
                .fill(Color.App.darkGreen.opacity(0.08))
                .frame(height: 0.5)
                .padding(.horizontal, 16)

            HStack(spacing: 0) {
                CalStatCell(
                    label: "截至今日累计",
                    value: "¥\(Int(monthlyExpenseTotal))",
                    color: Color(hex: "#1A1C1C"),
                    helpText: "本月1日到今天的\n总支出金额"
                )
                calDivider(height: 36)
                if let stats = stats, let projected = stats.projectedMonthlyExpense {
                    CalStatCell(
                        label: "本月预计开支",
                        value: "¥\(Int(projected))",
                        color: Color(hex: "#1A1C1C"),
                        helpText: "截至今日累计 ÷ 已过天数\n× 本月总天数"
                    )
                } else {
                    CalStatCell(
                        label: "本月预计开支",
                        value: "--",
                        color: Color(hex: "#1A1C1C"),
                        helpText: "截至今日累计 ÷ 已过天数\n× 本月总天数"
                    )
                }
            }
        }
    }

    /// 历史月摘要
    private var historyMonthSummary: some View {
        let budget = monthlyBudget ?? 0
        let result = HomeBudgetService.calcHistoryStats(
            budget: budget,
            monthlyExpense: monthlyExpenseTotal
        )

        return VStack(spacing: 8) {
            HStack(spacing: 0) {
                CalStatCell(
                    label: "整月支出",
                    value: "¥\(Int(monthlyExpenseTotal))",
                    color: Color(hex: "#1A1C1C")
                )
                calDivider(height: 36)
                CalStatCell(
                    label: "月预算",
                    value: budget > 0 ? "¥\(Int(budget))" : "-",
                    color: Color(hex: "#1A1C1C")
                )
                calDivider(height: 36)

                VStack(spacing: 2) {
                    Text(result.isOverBudget ? "超支" : "节省")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(result.isOverBudget ? Color.App.redExpense.opacity(0.7) : Color(hex: "#20AE73").opacity(0.7))
                        .lineLimit(1)

                    if budget > 0 {
                        Text("¥\(abs(Int(result.balance)))")
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundColor(result.isOverBudget ? Color.App.redExpense : Color(hex: "#20AE73"))
                            .minimumScaleFactor(0.75)
                            .lineLimit(1)
                        Text(result.isOverBudget ? "已超支 ¥\(abs(Int(result.balance)))" : "已节省 ¥\(abs(Int(result.balance)))")
                            .font(.system(size: 9))
                            .foregroundColor(result.isOverBudget ? Color.App.redExpense.opacity(0.5) : Color(hex: "#20AE73").opacity(0.5))
                    } else {
                        Text("-")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(Color(hex: "#1A1C1C"))
                        Text(" ")
                            .font(.system(size: 9))
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    /// 未来月摘要
    private var futureMonthSummary: some View {
        VStack(spacing: 8) {
            Text("暂无消费记录")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
                .padding(.vertical, 12)
        }
    }

    // MARK: 辅助：分割线
    private func calDivider(height: CGFloat) -> some View {
        Rectangle()
            .fill(Color.App.darkGreen.opacity(0.12))
            .frame(width: 0.5, height: height)
    }

    // MARK: 月份切换
    private func shiftMonth(by n: Int) {
        guard let newDate = cal.date(byAdding: .month, value: n, to: displayMonth) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            displayMonth = newDate
            selectedDay  = nil
        }
    }
}

// MARK: - 节奏状态胶囊（可复用）
struct PacePill: View {
    let text: String
    let isAlert: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isAlert ? Color.App.redExpense : Color(hex: "#20AE73"))
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isAlert ? Color.App.redExpense : Color(hex: "#20AE73"))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isAlert ? Color.App.redExpense.opacity(0.12) : Color(hex: "#20AE73").opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - 摘要数值格子（日历底部）
private struct CalStatCell: View {
    let label: String
    let value: String
    let color: Color
    var isBold: Bool = false
    var helpText: String? = nil

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "#2C6957").opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                if let helpText = helpText {
                    HelpTooltip(text: helpText)
                }
            }
            
            Text(value)
                .font(.system(size: 17, weight: isBold ? .heavy : .bold))
                .foregroundColor(color)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
            Text(" ") // 对齐占位
                .font(.system(size: 9))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 帮助提示组件（点击或长按显示气泡）
struct HelpTooltip: View {
    let text: String
    @State private var showTooltip = false

    var body: some View {
        Image(systemName: "questionmark.circle")
            .font(.system(size: 12))
            .foregroundColor(.gray.opacity(0.5))
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showTooltip = true
                }
            }
            .onLongPressGesture(minimumDuration: 0.3) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showTooltip = true
                }
            }
            .popover(isPresented: $showTooltip) {
                Text(text)
                    .font(.system(size: 12))
                    .padding(12)
                    .presentationCompactAdaptation(.popover)
            }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        LinearGradient(
            colors: [Color(hex: "#A8E6CF"), Color(hex: "#DCEDC1")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        BudgetCalendarView()
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
    }
}
