import Foundation

// MARK: - 经营看板（V7 Dashboard）一次性聚合统计

/// DashboardProjectStats 把 ProjectDashboardView 所需的所有派生指标收敛到一次遍历，
/// 消除原计算属性级联（读一次 disposableIncome 底层扫 4~6 遍 transactions）的开销。
struct DashboardProjectStats {
    // 基础
    let totalSpent: Double
    let totalIncome: Double
    let availableCash: Double

    // 现金流维度（本月）
    let monthlyNetCashFlow: Double
    let operatingCashFlow: Double
    let personalCashFlow: Double
    let upcomingFixedCosts: Double

    // 收入维度（本月）
    let monthlyIncome: Double
    let totalReceivable: Double
    let overdueReceivable: Double
    let overdueRatio: Double
    let incomeByCategory: [(categoryName: String, amount: Double, percentage: Double)]

    // 成本维度（本月）
    let directCost: Double
    let fixedCostMonthly: Double
    let personalCost: Double
    let costPercentage: (direct: Double, fixed: Double, personal: Double)

    // 利润维度（本月）
    let grossProfit: Double
    let grossMargin: Double
    let operatingNetProfit: Double
    let taxReserve: Double
    let disposableIncome: Double
}

extension DashboardProjectStats {
    /// 按指定周期/维度返回趋势数据（用于现金流/收入/成本/利润折线/堆叠图）
    static func trend(
        for project: Project,
        period: ProjectDashboardPeriod,
        dimension: DashboardDimension
    ) -> [(date: Date, amount: Double)] {
        let calendar = Calendar.current
        let now = Date()
        var data: [(date: Date, amount: Double)] = []
        let periodsToShow = 6

        // 辅助：返回某个 Date 所在周期的起始日
        func startDate(for date: Date) -> Date {
            switch period {
            case .month:
                return calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
            case .quarter:
                let month = calendar.component(.month, from: date)
                let quarterStartMonth = ((month - 1) / 3) * 3 + 1
                return calendar.date(from: DateComponents(year: calendar.component(.year, from: date), month: quarterStartMonth, day: 1)) ?? date
            case .year:
                return calendar.date(from: DateComponents(year: calendar.component(.year, from: date), month: 1, day: 1)) ?? date
            }
        }

        func endDate(from start: Date) -> Date {
            switch period {
            case .month:
                return calendar.date(byAdding: .month, value: 1, to: start) ?? start
            case .quarter:
                return calendar.date(byAdding: .month, value: 3, to: start) ?? start
            case .year:
                return calendar.date(byAdding: .year, value: 1, to: start) ?? start
            }
        }

        let transactions = project.transactions ?? []
        for i in 0..<periodsToShow {
            let rawDate: Date
            switch period {
            case .month:
                rawDate = calendar.date(byAdding: .month, value: -i, to: now) ?? now
            case .quarter:
                rawDate = calendar.date(byAdding: .month, value: -i * 3, to: now) ?? now
            case .year:
                rawDate = calendar.date(byAdding: .year, value: -i, to: now) ?? now
            }
            let start = startDate(for: rawDate)
            let end = endDate(from: start)

            var income: Double = 0
            var expense: Double = 0
            for tx in transactions where tx.date >= start && tx.date < end {
                if tx.type == .income {
                    income += abs(tx.amount)
                } else if tx.type == .expense {
                    expense += abs(tx.amount)
                }
            }

            let amount: Double
            switch dimension {
            case .cashFlow: amount = income - expense
            case .income:   amount = income
            case .cost:     amount = expense
            case .profit:   amount = income - expense
            }
            data.append((date: start, amount: amount))
        }
        return data.reversed()
    }

    /// 成本堆叠趋势：直接成本 / 固定成本 / 生活成本
    static func stackedCostTrend(
        for project: Project,
        period: ProjectDashboardPeriod
    ) -> [(date: Date, type: String, amount: Double)] {
        let calendar = Calendar.current
        let now = Date()
        var data: [(date: Date, type: String, amount: Double)] = []
        let periodsToShow = 6
        let fixedCostMonthly = (project.fixedCosts ?? []).filter { $0.isActive }.reduce(0) { $0 + $1.monthlyAmount }

        func startDate(for date: Date) -> Date {
            switch period {
            case .month:
                return calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
            case .quarter:
                let month = calendar.component(.month, from: date)
                let quarterStartMonth = ((month - 1) / 3) * 3 + 1
                return calendar.date(from: DateComponents(year: calendar.component(.year, from: date), month: quarterStartMonth, day: 1)) ?? date
            case .year:
                return calendar.date(from: DateComponents(year: calendar.component(.year, from: date), month: 1, day: 1)) ?? date
            }
        }
        func endDate(from start: Date) -> Date {
            switch period {
            case .month:
                return calendar.date(byAdding: .month, value: 1, to: start) ?? start
            case .quarter:
                return calendar.date(byAdding: .month, value: 3, to: start) ?? start
            case .year:
                return calendar.date(byAdding: .year, value: 1, to: start) ?? start
            }
        }

        let transactions = project.transactions ?? []
        for i in 0..<periodsToShow {
            let rawDate: Date
            switch period {
            case .month:
                rawDate = calendar.date(byAdding: .month, value: -i, to: now) ?? now
            case .quarter:
                rawDate = calendar.date(byAdding: .month, value: -i * 3, to: now) ?? now
            case .year:
                rawDate = calendar.date(byAdding: .year, value: -i, to: now) ?? now
            }
            let start = startDate(for: rawDate)
            let end = endDate(from: start)

            var directCost: Double = 0
            var personalCost: Double = 0
            for tx in transactions where tx.date >= start && tx.date < end && tx.type == .expense {
                if tx.cashFlowType == "operating" {
                    directCost += abs(tx.amount)
                } else if tx.cashFlowType == "personal" {
                    personalCost += abs(tx.amount)
                }
            }
            data.append((date: start, type: "直接成本", amount: directCost))
            data.append((date: start, type: "固定成本", amount: fixedCostMonthly))
            data.append((date: start, type: "生活成本", amount: personalCost))
        }
        return data.reversed()
    }

    /// 利润三层趋势：毛利 / 经营净利润 / 可支配收入
    static func profitTrend(
        for project: Project,
        period: ProjectDashboardPeriod
    ) -> [(date: Date, values: [(type: String, amount: Double)])] {
        let calendar = Calendar.current
        let now = Date()
        var data: [(date: Date, values: [(type: String, amount: Double)])] = []
        let periodsToShow = 6
        let fixedCostMonthly = (project.fixedCosts ?? []).filter { $0.isActive }.reduce(0) { $0 + $1.monthlyAmount }

        func startDate(for date: Date) -> Date {
            switch period {
            case .month:
                return calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
            case .quarter:
                let month = calendar.component(.month, from: date)
                let quarterStartMonth = ((month - 1) / 3) * 3 + 1
                return calendar.date(from: DateComponents(year: calendar.component(.year, from: date), month: quarterStartMonth, day: 1)) ?? date
            case .year:
                return calendar.date(from: DateComponents(year: calendar.component(.year, from: date), month: 1, day: 1)) ?? date
            }
        }
        func endDate(from start: Date) -> Date {
            switch period {
            case .month:
                return calendar.date(byAdding: .month, value: 1, to: start) ?? start
            case .quarter:
                return calendar.date(byAdding: .month, value: 3, to: start) ?? start
            case .year:
                return calendar.date(byAdding: .year, value: 1, to: start) ?? start
            }
        }

        let transactions = project.transactions ?? []
        for i in 0..<periodsToShow {
            let rawDate: Date
            switch period {
            case .month:
                rawDate = calendar.date(byAdding: .month, value: -i, to: now) ?? now
            case .quarter:
                rawDate = calendar.date(byAdding: .month, value: -i * 3, to: now) ?? now
            case .year:
                rawDate = calendar.date(byAdding: .year, value: -i, to: now) ?? now
            }
            let start = startDate(for: rawDate)
            let end = endDate(from: start)

            var income: Double = 0
            var directCost: Double = 0
            var personalCost: Double = 0
            for tx in transactions where tx.date >= start && tx.date < end {
                if tx.type == .income {
                    income += abs(tx.amount)
                } else if tx.type == .expense {
                    if tx.cashFlowType == "operating" {
                        directCost += abs(tx.amount)
                    } else if tx.cashFlowType == "personal" {
                        personalCost += abs(tx.amount)
                    }
                }
            }
            let grossProfit = income - directCost
            let operatingNetProfit = grossProfit - fixedCostMonthly
            let taxReserve = max(0, operatingNetProfit * project.taxRate)
            let disposableIncome = operatingNetProfit - personalCost - taxReserve
            data.append((date: start, values: [
                (type: "毛利", amount: grossProfit),
                (type: "经营净利润", amount: operatingNetProfit),
                (type: "可支配收入", amount: disposableIncome)
            ]))
        }
        return data.reversed()
    }
}

extension ProjectStatsCalculator {
    /// 一次性产出 DashboardProjectStats。内部只做 3 次遍历：transactions、fixedCosts、receivables。
    static func calculateDashboardStats(project: Project) -> DashboardProjectStats {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let thirtyDaysLater = calendar.date(byAdding: .day, value: 30, to: now) ?? now

        let transactions = project.transactions ?? []
        let fixedCosts = project.fixedCosts ?? []
        let receivables = project.receivables ?? []

        // 1. 遍历 transactions：累计总收支 + 本月收支/成本 + 分类收入
        var totalSpent: Double = 0
        var totalIncome: Double = 0
        var monthlyIncome: Double = 0
        var directCost: Double = 0
        var personalCost: Double = 0
        var categoryIncome: [String: Double] = [:]

        for tx in transactions {
            let amount = abs(tx.amount)
            if tx.type == .expense {
                totalSpent += amount
                if tx.date >= startOfMonth {
                    if tx.cashFlowType == "operating" {
                        directCost += amount
                    } else if tx.cashFlowType == "personal" {
                        personalCost += amount
                    }
                }
            } else if tx.type == .income {
                totalIncome += amount
                if tx.date >= startOfMonth {
                    monthlyIncome += amount
                }
                categoryIncome[tx.categoryName, default: 0] += amount
            }
        }

        // 2. 遍历 fixedCosts：月度固定成本 + 未来30天刚性支出
        var fixedCostMonthly: Double = 0
        var upcomingFixedCosts: Double = 0
        for cost in fixedCosts where cost.isActive {
            fixedCostMonthly += cost.monthlyAmount
            if let due = cost.nextDueDate, due >= now, due <= thirtyDaysLater {
                upcomingFixedCosts += cost.monthlyAmount
            }
        }

        // 3. 遍历 receivables：待回款 + 逾期
        var totalReceivable: Double = 0
        var overdueReceivable: Double = 0
        for r in receivables where r.status == .pending {
            totalReceivable += r.amount
            if r.isOverdue { overdueReceivable += r.amount }
        }

        // 派生指标
        let availableCash = totalIncome - totalSpent
        let monthlyExpense = directCost + personalCost
        let monthlyNetCashFlow = monthlyIncome - monthlyExpense
        let operatingCashFlow = -directCost
        let personalCashFlow = -personalCost
        let overdueRatio = totalReceivable > 0 ? overdueReceivable / totalReceivable : 0

        let incomeTotalAmount = categoryIncome.values.reduce(0, +)
        let incomeByCategory: [(categoryName: String, amount: Double, percentage: Double)] = incomeTotalAmount > 0
            ? categoryIncome.map { (categoryName: $0.key, amount: $0.value, percentage: $0.value / incomeTotalAmount) }
                .sorted { $0.amount > $1.amount }
            : []

        let totalCost = directCost + fixedCostMonthly + personalCost
        let costPercentage: (direct: Double, fixed: Double, personal: Double) = totalCost > 0
            ? (direct: directCost / totalCost, fixed: fixedCostMonthly / totalCost, personal: personalCost / totalCost)
            : (direct: 0, fixed: 0, personal: 0)

        let grossProfit = monthlyIncome - directCost
        let grossMargin = monthlyIncome > 0 ? grossProfit / monthlyIncome : 0
        let operatingNetProfit = grossProfit - fixedCostMonthly
        let taxReserve = max(0, operatingNetProfit * project.taxRate)
        let disposableIncome = operatingNetProfit - personalCost - taxReserve

        return DashboardProjectStats(
            totalSpent: totalSpent,
            totalIncome: totalIncome,
            availableCash: availableCash,
            monthlyNetCashFlow: monthlyNetCashFlow,
            operatingCashFlow: operatingCashFlow,
            personalCashFlow: personalCashFlow,
            upcomingFixedCosts: upcomingFixedCosts,
            monthlyIncome: monthlyIncome,
            totalReceivable: totalReceivable,
            overdueReceivable: overdueReceivable,
            overdueRatio: overdueRatio,
            incomeByCategory: incomeByCategory,
            directCost: directCost,
            fixedCostMonthly: fixedCostMonthly,
            personalCost: personalCost,
            costPercentage: costPercentage,
            grossProfit: grossProfit,
            grossMargin: grossMargin,
            operatingNetProfit: operatingNetProfit,
            taxReserve: taxReserve,
            disposableIncome: disposableIncome
        )
    }
}

// MARK: - 分类预算执行

struct CategoryBudgetExecution {
    let name: String
    let icon: String
    let colorHex: String
    let budgeted: Double
    let actual: Double
    let ratio: Double
    let status: String   // "saving" | "overrun" | "on_track"
    let delta: Double    // 正数=超支，负数=节余
}

// MARK: - 生活模式统计数据

struct LifestyleProjectStats {
    // 基础
    let totalSpent: Double
    let budget: Double
    let totalDays: Int
    let dailyAvgSpend: Double
    let budgetProgress: Double

    // 分类预算执行
    let categoryBreakdown: [CategoryBudgetExecution]

    // 消费结构
    let hhiIndex: Double
    let hhiLabel: String
    let bigItemAmount: Double
    let bigItemRatio: Double
    let dailyFreeAmount: Double
    let maxSingleAmount: Double
    let maxSingleCategory: String
    let avgSingleAmount: Double
    let medianSingleAmount: Double
    let volatility: Double

    // 时间分布
    let firstHalfSpent: Double
    let firstHalfRatio: Double
    let secondHalfSpent: Double
    let secondHalfRatio: Double
    let trendLabel: String
    let peakDayNumber: Int
    let peakDayAmount: Double
    let peakDayCategory: String
    let avgDailyTransactions: Double
}

// MARK: - 搞钱模式统计数据

struct EarningProjectStats {
    // 盈利能力
    let totalIncome: Double
    let totalExpense: Double
    let timeCost: Double
    let totalCost: Double
    let netProfit: Double
    let profitMargin: Double
    let profitMarginLabel: String
    let roi: Double
    let roiRating: String
    let targetIncome: Double
    let targetAchievement: Double?

    // 时间价值
    let totalHours: Double
    let effectiveHourlyRate: Double
    let hourlyRateLabel: String
    let dailyHours: Double
    let dailyHoursLabel: String
    let firstHalfHours: Double
    let secondHalfHours: Double

    // 成本结构
    let timeCostRatio: Double
    let materialCostRatio: Double
    let topExpenseName: String
    let topExpenseAmount: Double
    let topExpenseContribution: Double
    let fixedMonthlyCost: Double

    // 经营效率
    let incomeFirstHalf: Double
    let incomeFirstHalfRatio: Double
    let incomeSecondHalf: Double
    let incomeSecondHalfRatio: Double
    let incomeTimingLabel: String
    let expenseFirstHalf: Double
    let expenseFirstHalfRatio: Double
    let expenseSecondHalf: Double
    let expenseSecondHalfRatio: Double
    let expenseTimingLabel: String
    let monthlyNetCashFlow: Double
    let cashFlowStatus: String
}

// MARK: - 计算器

struct ProjectStatsCalculator {

    // MARK: - 生活模式

    static func calculateLifestyleStats(project: Project) -> LifestyleProjectStats {
        let expenses = (project.transactions ?? []).filter { $0.type == .expense }

        let categoryBreakdown = calculateCategoryBudgetExecution(
            budgetItems: project.budgetItems ?? [], expenses: expenses
        )

        let hhi = calculateHHI(expenses: expenses, totalSpent: project.totalSpent)
        let bigItem = calculateBigItemStats(project: project, expenses: expenses)
        let singleStats = calculateSingleTransactionStats(expenses: expenses)
        let timeStats = calculateTimeDistribution(expenses: expenses, totalDays: project.totalDays)

        return LifestyleProjectStats(
            totalSpent: project.totalSpent,
            budget: project.budget,
            totalDays: project.totalDays,
            dailyAvgSpend: project.dailyAvgSpend,
            budgetProgress: project.budgetProgress,
            categoryBreakdown: categoryBreakdown,
            hhiIndex: hhi.value,
            hhiLabel: hhi.label,
            bigItemAmount: bigItem.amount,
            bigItemRatio: bigItem.ratio,
            dailyFreeAmount: bigItem.dailyFree,
            maxSingleAmount: singleStats.max,
            maxSingleCategory: singleStats.maxCategory,
            avgSingleAmount: singleStats.avg,
            medianSingleAmount: singleStats.median,
            volatility: singleStats.volatility,
            firstHalfSpent: timeStats.firstHalf,
            firstHalfRatio: timeStats.firstHalfRatio,
            secondHalfSpent: timeStats.secondHalf,
            secondHalfRatio: timeStats.secondHalfRatio,
            trendLabel: timeStats.trendLabel,
            peakDayNumber: timeStats.peakDayNumber,
            peakDayAmount: timeStats.peakDayAmount,
            peakDayCategory: timeStats.peakDayCategory,
            avgDailyTransactions: timeStats.avgDailyTx
        )
    }

    // MARK: - 搞钱模式

    static func calculateEarningStats(project: Project) -> EarningProjectStats {
        let expenses = (project.transactions ?? []).filter { $0.type == .expense }
        let incomes  = (project.transactions ?? []).filter { $0.type == .income }

        // 盈利能力
        let profitMargin = project.totalIncome > 0 ? project.netProfit / project.totalIncome : 0
        let profitMarginLabel = rateLabel(profitMargin, thresholds: [0, 0.2, 0.4, 0.6],
                                          labels: ["亏损", "低回报", "中等", "良好", "优秀"])
        let roiRating = rateLabel(project.roi / 100, thresholds: [0, 0.2, 0.4, 0.6],
                                  labels: ["亏损", "低回报", "中等回报", "良好回报", "高回报"])
        let targetAchievement: Double? = project.targetIncome > 0 ? project.totalIncome / project.targetIncome : nil

        // 时间价值
        let dailyHours = project.effectiveWorkingDays > 0
            ? project.totalHourEquivalent / Double(project.effectiveWorkingDays) : 0
        let hourlyRateLabel = rateLabel(project.effectiveHourlyRate, thresholds: [30, 80, 150, 300],
                                        labels: ["偏低", "中等", "良好", "优秀", "顶级"])
        let dailyHoursLabel: String
        switch dailyHours {
        case ..<4: dailyHoursLabel = "轻度投入"
        case 4..<8: dailyHoursLabel = "中度投入"
        default: dailyHoursLabel = "高强度投入"
        }

        // 工时前后半段
        let sortedTimeEntries = (project.timeEntries ?? []).sorted { $0.date < $1.date }
        let timeMid = sortedTimeEntries.count / 2
        let firstHalfHours = sortedTimeEntries.prefix(max(timeMid, 0))
            .reduce(0) { $0 + ($1.granularity == "day" ? $1.duration * 8 : $1.duration) }
        let secondHalfHours = sortedTimeEntries.suffix(from: timeMid)
            .reduce(0) { $0 + ($1.granularity == "day" ? $1.duration * 8 : $1.duration) }

        // 成本结构
        let timeCostRatio = project.totalCost > 0 ? project.totalTimeCost / project.totalCost : 0
        let materialCostRatio = project.totalCost > 0 ? project.totalSpent / project.totalCost : 0
        let topExpense = expenses.max(by: { abs($0.amount) < abs($1.amount) })
        let topExpenseAmount = topExpense.map { abs($0.amount) } ?? 0
        let topExpenseContribution = project.totalSpent > 0 ? topExpenseAmount / project.totalSpent : 0
        let fixedMonthlyCost = project.fixedCostMonthly

        // 经营效率（收入/支出前后半段节奏）
        let incomeStats = calculateIOTimeDistribution(transactions: incomes, total: project.totalIncome)
        let expenseStats = calculateIOTimeDistribution(transactions: expenses, total: project.totalSpent)

        return EarningProjectStats(
            totalIncome: project.totalIncome,
            totalExpense: project.totalSpent,
            timeCost: project.totalTimeCost,
            totalCost: project.totalCost,
            netProfit: project.netProfit,
            profitMargin: profitMargin,
            profitMarginLabel: profitMarginLabel,
            roi: project.roi,
            roiRating: roiRating,
            targetIncome: project.targetIncome,
            targetAchievement: targetAchievement,
            totalHours: project.totalHourEquivalent,
            effectiveHourlyRate: project.effectiveHourlyRate,
            hourlyRateLabel: hourlyRateLabel,
            dailyHours: dailyHours,
            dailyHoursLabel: dailyHoursLabel,
            firstHalfHours: firstHalfHours,
            secondHalfHours: secondHalfHours,
            timeCostRatio: timeCostRatio,
            materialCostRatio: materialCostRatio,
            topExpenseName: topExpense?.categoryName ?? "暂无",
            topExpenseAmount: topExpenseAmount,
            topExpenseContribution: topExpenseContribution,
            fixedMonthlyCost: fixedMonthlyCost,
            incomeFirstHalf: incomeStats.firstHalf,
            incomeFirstHalfRatio: incomeStats.firstHalfRatio,
            incomeSecondHalf: incomeStats.secondHalf,
            incomeSecondHalfRatio: incomeStats.secondHalfRatio,
            incomeTimingLabel: incomeStats.timingLabel,
            expenseFirstHalf: expenseStats.firstHalf,
            expenseFirstHalfRatio: expenseStats.firstHalfRatio,
            expenseSecondHalf: expenseStats.secondHalf,
            expenseSecondHalfRatio: expenseStats.secondHalfRatio,
            expenseTimingLabel: expenseStats.timingLabel,
            monthlyNetCashFlow: project.monthlyNetCashFlow,
            cashFlowStatus: project.monthlyNetCashFlow >= 0 ? "健康" : "需关注"
        )
    }

    // MARK: - 最少交易数门槛

    static let minimumTransactionsForAI = 5

    // MARK: - 私有计算

    private static func calculateCategoryBudgetExecution(
        budgetItems: [BudgetItem], expenses: [Transaction]
    ) -> [CategoryBudgetExecution] {
        budgetItems.map { item in
            let actual = expenses
                .filter { $0.categoryName == item.categoryName }
                .reduce(0) { $0 + abs($1.amount) }
            let ratio = item.amount > 0 ? actual / item.amount : 0
            let delta = actual - item.amount
            let status: String
            if ratio > 1.05 { status = "overrun" }
            else if ratio < 0.95 { status = "saving" }
            else { status = "on_track" }
            return CategoryBudgetExecution(
                name: item.categoryName, icon: item.categoryIcon,
                colorHex: item.categoryColorHex, budgeted: item.amount,
                actual: actual, ratio: ratio, status: status, delta: delta
            )
        }
    }

    private static func calculateHHI(expenses: [Transaction], totalSpent: Double)
        -> (value: Double, label: String)
    {
        guard totalSpent > 0 else { return (0, "无数据") }
        var categoryAmounts: [String: Double] = [:]
        for tx in expenses { categoryAmounts[tx.categoryName, default: 0] += abs(tx.amount) }
        let hhi = categoryAmounts.values.reduce(0.0) { sum, amount in
            let share = amount / totalSpent
            return sum + share * share
        }
        let label: String
        switch hhi {
        case ..<0.15: label = "分散"
        case 0.15..<0.25: label = "中等集中"
        default: label = "高度集中"
        }
        return (hhi, label)
    }

    private static func calculateBigItemStats(project: Project, expenses: [Transaction])
        -> (amount: Double, ratio: Double, dailyFree: Double)
    {
        let config = ProjectTypeConfigManager.shared.getConfig(name: project.name, description: project.desc)
        let bigKeywords = config.bigItemKeywords
        let bigAmount = expenses
            .filter { tx in bigKeywords.contains(where: { tx.categoryName.contains($0) }) }
            .reduce(0) { $0 + abs($1.amount) }
        let ratio = project.totalSpent > 0 ? bigAmount / project.totalSpent : 0
        let dailyFree = project.totalDays > 0
            ? (project.totalSpent - bigAmount) / Double(project.totalDays) : 0
        return (bigAmount, ratio, dailyFree)
    }

    private static func calculateSingleTransactionStats(expenses: [Transaction])
        -> (max: Double, maxCategory: String, avg: Double, median: Double, volatility: Double)
    {
        let amounts = expenses.map { abs($0.amount) }
        guard !amounts.isEmpty else { return (0, "", 0, 0, 0) }
        let sorted = amounts.sorted()
        let max = sorted.last ?? 0
        let maxCategory = expenses.first(where: { abs($0.amount) == max })?.categoryName ?? ""
        let avg = amounts.reduce(0, +) / Double(amounts.count)
        let median = sorted[sorted.count / 2]
        let volatility = avg > 0 ? max / avg : 0
        return (max, maxCategory, avg, median, volatility)
    }

    private static func calculateTimeDistribution(expenses: [Transaction], totalDays: Int)
        -> (firstHalf: Double, firstHalfRatio: Double, secondHalf: Double, secondHalfRatio: Double,
            trendLabel: String, peakDayNumber: Int, peakDayAmount: Double,
            peakDayCategory: String, avgDailyTx: Double)
    {
        let sorted = expenses.sorted { $0.date < $1.date }
        let midIndex = sorted.count / 2
        let firstHalf = sorted.prefix(midIndex).reduce(0) { $0 + abs($1.amount) }
        let secondHalf = sorted.suffix(from: midIndex).reduce(0) { $0 + abs($1.amount) }
        let total = firstHalf + secondHalf
        let fhRatio = total > 0 ? firstHalf / total : 0.5
        let shRatio = total > 0 ? secondHalf / total : 0.5
        let trendLabel: String
        if fhRatio > 0.6 { trendLabel = "前紧后松" }
        else if shRatio > 0.6 { trendLabel = "前松后紧" }
        else { trendLabel = "节奏平稳" }

        // 高峰日
        let calendar = Calendar.current
        var dailyTotals: [Date: Double] = [:]
        var dailyTopCategory: [Date: (String, Double)] = [:]
        for tx in expenses {
            let day = calendar.startOfDay(for: tx.date)
            dailyTotals[day, default: 0] += abs(tx.amount)
            let current = dailyTopCategory[day]
            if current == nil || abs(tx.amount) > current!.1 {
                dailyTopCategory[day] = (tx.categoryName, abs(tx.amount))
            }
        }
        let peakDay = dailyTotals.max { $0.value < $1.value }
        let peakDayNumber: Int
        if let peak = peakDay?.key, let firstDate = sorted.first?.date {
            peakDayNumber = max(1, (calendar.dateComponents([.day], from: firstDate, to: peak).day ?? 0) + 1)
        } else { peakDayNumber = 0 }
        let peakDayAmount = peakDay?.value ?? 0
        let peakDayCategory = peakDay.flatMap { dailyTopCategory[$0.key]?.0 } ?? ""

        let avgDailyTx = totalDays > 0 ? Double(expenses.count) / Double(totalDays) : 0
        return (firstHalf, fhRatio, secondHalf, shRatio, trendLabel,
                peakDayNumber, peakDayAmount, peakDayCategory, avgDailyTx)
    }

    /// 收入/支出前后半段节奏（搞钱模式）
    private static func calculateIOTimeDistribution(transactions: [Transaction], total: Double)
        -> (firstHalf: Double, firstHalfRatio: Double,
            secondHalf: Double, secondHalfRatio: Double, timingLabel: String)
    {
        let sorted = transactions.sorted { $0.date < $1.date }
        let mid = sorted.count / 2
        let fh = sorted.prefix(mid).reduce(0) { $0 + abs($1.amount) }
        let sh = sorted.suffix(from: mid).reduce(0) { $0 + abs($1.amount) }
        let fhR = total > 0 ? fh / total : 0.5
        let shR = total > 0 ? sh / total : 0.5
        let label: String
        if fhR > 0.6 { label = "前半段集中" }
        else if shR > 0.6 { label = "后半段集中" }
        else { label = "节奏平稳" }
        return (fh, fhR, sh, shR, label)
    }

    /// 通用评级
    private static func rateLabel(_ value: Double, thresholds: [Double], labels: [String]) -> String {
        for (i, t) in thresholds.enumerated() where value < t { return labels[i] }
        return labels.last ?? ""
    }
}
