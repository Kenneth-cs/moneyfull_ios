import Foundation

// MARK: - Insight Period

enum InsightPeriod: String, Codable {
    case thisMonth = "this_month"
    case lastMonth = "last_month"
}

// MARK: - Spending Insight Data

struct SpendingInsightData: Codable {
    let title: String
    let emoji: String
    let totalAmount: Double
    let totalExpenseRatio: Double       // 占当期总支出比例
    let momChangePercent: Double?       // 环比变化（可选）
    let period: InsightPeriod
    let items: [InsightBreakdownItem]
}

struct InsightBreakdownItem: Codable {
    let icon: String
    let name: String
    let amount: Double
    let ratio: Double           // 相对于该分组的占比 0~1
    let barColorHex: String
}

// MARK: - Analytics Engine

class AnalyticsEngine {
    static let shared = AnalyticsEngine()
    private init() {}

    private let barColors = [
        "#F9A8D4", "#FDE68A", "#6EE7B7",
        "#A5B4FC", "#FCA5A5", "#7DD3FC", "#D9F99D",
    ]

    /// 按一级分类名 + 时间段，聚合二级分类支出
    func insightForCategoryGroup(
        groupName: String,
        period: InsightPeriod,
        transactions allTx: [Transaction]
    ) -> SpendingInsightData? {
        let periodTxs = filteredTxs(period: period, from: allTx)
        let groupTxs = periodTxs.filter {
            $0.type == .expense &&
            $0.categoryName.localizedCaseInsensitiveContains(groupName)
        }
        guard !groupTxs.isEmpty else { return nil }

        let total = groupTxs.reduce(0.0) { $0 + $1.amount }
        let totalAllExpense = periodTxs.filter { $0.type == .expense }.reduce(0.0) { $0 + $1.amount }
        let ratio = totalAllExpense > 0 ? total / totalAllExpense : 0.0

        // 按 categoryName 聚合
        var byCategory: [String: Double] = [:]
        for tx in groupTxs {
            byCategory[tx.categoryName, default: 0.0] += tx.amount
        }
        let sorted = byCategory.sorted { $0.value > $1.value }
        let items = sorted.enumerated().map { idx, pair in
            InsightBreakdownItem(
                icon: categoryEmoji(pair.key),
                name: pair.key,
                amount: pair.value,
                ratio: total > 0 ? pair.value / total : 0.0,
                barColorHex: barColors[idx % barColors.count]
            )
        }

        let mom = momChangePercent(groupName: groupName, period: period, allTx: allTx)

        return SpendingInsightData(
            title: "\(groupName)支出洞察",
            emoji: groupEmoji(groupName),
            totalAmount: total,
            totalExpenseRatio: ratio,
            momChangePercent: mom,
            period: period,
            items: items
        )
    }

    /// 整体月度概览（按一级分类名聚合，使用 `categoryName` 作为 key）
    func monthlyOverview(
        period: InsightPeriod,
        transactions allTx: [Transaction]
    ) -> SpendingInsightData? {
        let periodTxs = filteredTxs(period: period, from: allTx)
        let expenseTxs = periodTxs.filter { $0.type == .expense }
        guard !expenseTxs.isEmpty else { return nil }

        let total = expenseTxs.reduce(0.0) { $0 + $1.amount }
        var byCategory: [String: Double] = [:]
        for tx in expenseTxs {
            byCategory[tx.categoryName, default: 0.0] += tx.amount
        }
        let sorted = byCategory.sorted { $0.value > $1.value }
        let items = sorted.prefix(6).enumerated().map { idx, pair in
            InsightBreakdownItem(
                icon: categoryEmoji(pair.key),
                name: pair.key,
                amount: pair.value,
                ratio: total > 0 ? pair.value / total : 0.0,
                barColorHex: barColors[idx % barColors.count]
            )
        }

        let periodLabel = period == .thisMonth ? "本月" : "上月"
        return SpendingInsightData(
            title: "\(periodLabel)支出概览",
            emoji: "📊",
            totalAmount: total,
            totalExpenseRatio: 1.0,
            momChangePercent: nil,
            period: period,
            items: items
        )
    }

    // MARK: - Private Helpers

    private func filteredTxs(period: InsightPeriod, from allTx: [Transaction]) -> [Transaction] {
        let cal = Calendar.current
        let now = Date()
        switch period {
        case .thisMonth:
            return allTx.filter { cal.isDate($0.date, equalTo: now, toGranularity: .month) }
        case .lastMonth:
            guard let lastMonth = cal.date(byAdding: .month, value: -1, to: now) else { return [] }
            return allTx.filter { cal.isDate($0.date, equalTo: lastMonth, toGranularity: .month) }
        }
    }

    private func momChangePercent(
        groupName: String,
        period: InsightPeriod,
        allTx: [Transaction]
    ) -> Double? {
        let cal = Calendar.current
        let now = Date()

        let refDate: Date?
        switch period {
        case .thisMonth: refDate = now
        case .lastMonth: refDate = cal.date(byAdding: .month, value: -1, to: now)
        }
        guard let ref = refDate,
              let prev = cal.date(byAdding: .month, value: -1, to: ref) else { return nil }

        let currentTotal = allTx.filter {
            $0.type == .expense &&
            cal.isDate($0.date, equalTo: ref, toGranularity: .month) &&
            $0.categoryName.localizedCaseInsensitiveContains(groupName)
        }.reduce(0.0) { $0 + $1.amount }

        let prevTotal = allTx.filter {
            $0.type == .expense &&
            cal.isDate($0.date, equalTo: prev, toGranularity: .month) &&
            $0.categoryName.localizedCaseInsensitiveContains(groupName)
        }.reduce(0.0) { $0 + $1.amount }

        guard prevTotal > 0 else { return nil }
        return (currentTotal - prevTotal) / prevTotal * 100.0
    }

    private func groupEmoji(_ name: String) -> String {
        let map: [String: String] = [
            "餐饮": "🍜", "吃喝": "🍜", "购物": "🛍️", "出行": "🚗",
            "娱乐": "🎮", "医疗": "💊", "教育": "📚", "居家": "🏠",
            "运动": "🏃", "美容": "💄", "通讯": "📱", "其他": "📦",
        ]
        return map[name] ?? "💰"
    }

    private func categoryEmoji(_ name: String) -> String {
        let map: [String: String] = [
            "外卖": "🍔", "堂食": "🍱", "咖啡": "☕", "零食": "🧋",
            "饮品": "🧃", "打车": "🚕", "地铁": "🚇", "超市": "🛒",
            "服装": "👕", "数码": "💻", "游戏": "🎮",
        ]
        return map[name] ?? "📌"
    }
}
