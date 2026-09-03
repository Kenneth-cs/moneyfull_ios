import Foundation

/// 预算统计结果（纯值类型，无副作用）
struct BudgetStats {
    /// 固定日均预算 = monthlyBudget / daysInMonth
    let dailyBudget: Double
    /// 剩余预算 = monthlyBudget - monthlyExpense
    let remainingBudget: Double
    /// 预算使用率 = monthlyExpense / monthlyBudget (0~N)
    let budgetProgress: Double
    /// 时间进度 = currentDay / daysInMonth (0~1)
    let timeProgress: Double
    /// 节奏差值（百分点）= budgetProgress - timeProgress
    let paceDifference: Double
    /// 节奏文案
    let paceLabel: String
    /// 是否告警（胶囊颜色控制）
    let isAlert: Bool
    /// 本月预计支出
    let projectedMonthlyExpense: Double?
    /// 动态今日预算额度 = remainingBudget / remainingDays
    let dynamicDailyBudget: Double
    /// 今日还能花 = max(dynamicDailyBudget - todayExpense, 0)
    let todayRemainingSpend: Double
    /// 截至今日累计
    let cumulativeExpense: AverageDailyExpense
    /// 本月至今平均日支出
    let averageDailyExpense: Double
}

// 类型别名，用于命名语义清晰
typealias AverageDailyExpense = Double

/// 首页预算服务：UserDefaults 存取 + 计算引擎
enum HomeBudgetService {

    // MARK: - UserDefaults 存取

    /// 读取指定年月的月预算
    static func budget(year: Int, month: Int) -> Double? {
        let key = budgetKey(year: year, month: month)
        let value = UserDefaults.standard.double(forKey: key)
        // double(forKey:) 对不存在的 key 返回 0，需区分"未设置"和"设置为0"
        guard UserDefaults.standard.object(forKey: key) != nil else { return nil }
        return value > 0 ? value : nil
    }

    /// 写入指定年月的月预算
    static func setBudget(_ amount: Double, year: Int, month: Int) {
        let key = budgetKey(year: year, month: month)
        UserDefaults.standard.set(amount, forKey: key)
    }

    // MARK: - 计算引擎

    /// 计算预算统计（当前月）
    /// - Parameters:
    ///   - budget: 月预算金额
    ///   - dailyExpenses: [日期序号: 当日支出]
    ///   - todayExpense: 今日支出
    ///   - referenceDate: 参考日期（默认今天）
    static func calcStats(
        budget: Double,
        dailyExpenses: [Int: Double],
        todayExpense: Double,
        referenceDate: Date = Date()
    ) -> BudgetStats {
        let calendar = Calendar.current
        let currentDay = calendar.component(.day, from: referenceDate)
        let daysInMonth = calendar.range(of: .day, in: .month, for: referenceDate)!.count

        // 累计支出（截至今日）
        let cumulativeExpense: Double = dailyExpenses
            .filter { $0.key <= currentDay }
            .reduce(0) { $0 + $1.value }

        // 固定日均预算
        let dailyBudget = budget / Double(daysInMonth)

        // 剩余预算
        let remainingBudget = budget - cumulativeExpense

        // 预算使用率
        let budgetProgress = budget > 0 ? cumulativeExpense / budget : 0

        // 时间进度
        let timeProgress = Double(currentDay) / Double(daysInMonth)

        // 节奏差值（百分点）
        let paceDifference = budgetProgress - timeProgress

        // 节奏档位
        let (paceLabel, isAlert) = paceJudgment(
            budgetProgress: budgetProgress,
            paceDifference: paceDifference
        )

        // 本月至今平均日支出
        let averageDailyExpense = currentDay > 0 ? cumulativeExpense / Double(currentDay) : 0

        // 本月预计
        let projectedMonthlyExpense: Double? = currentDay > 0
            ? averageDailyExpense * Double(daysInMonth)
            : nil

        // 剩余天数（包含今天）
        let remainingDays = daysInMonth - currentDay + 1

        // 动态今日预算额度：用"今日之前"的累计支出来计算今天的份额
        // 注意：不能用 cumulativeExpense（已含今日），否则会把今日支出扣两遍
        let prevDaysExpense: Double = dailyExpenses
            .filter { $0.key < currentDay }
            .reduce(0) { $0 + $1.value }
        let remainingBudgetForToday = budget - prevDaysExpense
        let dynamicDailyBudget = remainingDays > 0 ? remainingBudgetForToday / Double(remainingDays) : 0

        // 今日还能花 = 今日份额 - 今日已花
        let todayRemainingSpend = max(dynamicDailyBudget - todayExpense, 0)

        return BudgetStats(
            dailyBudget: dailyBudget,
            remainingBudget: remainingBudget,
            budgetProgress: budgetProgress,
            timeProgress: timeProgress,
            paceDifference: paceDifference,
            paceLabel: paceLabel,
            isAlert: isAlert,
            projectedMonthlyExpense: projectedMonthlyExpense,
            dynamicDailyBudget: dynamicDailyBudget,
            todayRemainingSpend: todayRemainingSpend,
            cumulativeExpense: cumulativeExpense,
            averageDailyExpense: averageDailyExpense
        )
    }

    /// 历史月统计（整月数据）
    static func calcHistoryStats(
        budget: Double,
        monthlyExpense: Double
    ) -> (expense: Double, budget: Double, balance: Double, isOverBudget: Bool) {
        let balance = budget - monthlyExpense
        return (monthlyExpense, budget, balance, balance < 0)
    }

    // MARK: - 节奏判断（5档 + 超预算）

    private static func paceJudgment(budgetProgress: Double, paceDifference: Double) -> (label: String, isAlert: Bool) {
        // 已超预算优先
        if budgetProgress >= 1.0 {
            return ("已超预算", true)
        }

        switch paceDifference {
        case ..<(-0.10):
            return ("花得比较省", false)
        case -0.10...0.10:
            return ("节奏正常", false)
        case 0.10...0.20:
            return ("稍微偏快", true)
        case 0.20...0.35:
            return ("花得有点快", true)
        default:
            return ("预算告急", true)
        }
    }

    // MARK: - 工具

    private static func budgetKey(year: Int, month: Int) -> String {
        "homeBudget_\(year)_\(String(format: "%02d", month))"
    }
}
