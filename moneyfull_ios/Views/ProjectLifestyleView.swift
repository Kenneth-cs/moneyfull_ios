import SwiftUI

/// 预算防线全页（生活模式）
struct ProjectLifestyleView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var storeManager: StoreManager

    let project: Project
    var onShowPaywall: () -> Void = {}

    private var colorPair: ProgressColorPair { progressColorPair(for: project.colorHex) }
    private var accentColor: Color { Color(hex: colorPair.end) }

    private var budgetItems: [BudgetItem] { project.budgetItems ?? [] }
    private var totalBudget: Double { project.budget }
    private var totalSpent: Double { project.totalSpent }
    private var totalDays: Int { project.totalDays }
    private var remaining: Double { max(totalBudget - totalSpent, 0) }
    private var budgetProgress: Double { totalBudget > 0 ? min(totalSpent / totalBudget, 1) : 0 }

    // 大件识别：按分类名匹配交通/住宿关键词
    private var bigItemsAmount: Double {
        let bigKeywords = ["交通", "行", "住", "住宿", "机票", "酒店", "火车", "高铁", "飞机"]
        return (project.transactions ?? [])
            .filter { tx in tx.type == .expense && bigKeywords.contains(where: { kw in tx.categoryName.contains(kw) }) }
            .reduce(0) { $0 + abs($1.amount) }
    }
    private var dailyFree: Double {
        let free = totalSpent - bigItemsAmount
        return totalDays > 0 ? free / Double(totalDays) : 0
    }

    // 消费结构（甜甜圈）
    private var segments: [(name: String, amount: Double, colorHex: String, icon: String)] {
        if !budgetItems.isEmpty {
            return budgetItems.map { item in
                let spent = (project.transactions ?? [])
                    .filter { $0.type == .expense && $0.categoryName == item.categoryName }
                    .reduce(0) { $0 + abs($1.amount) }
                return (item.categoryName, spent > 0 ? spent : item.amount * 0.5,
                        item.categoryColorHex, item.categoryIcon)
            }
        }
        // 无预算分类时，按实际消费分类汇总
        let categorySpend = (project.transactions ?? [])
            .filter { $0.type == .expense }
            .reduce(into: [String: (amount: Double, color: String, icon: String)]()) {
                let existing = $0[$1.categoryName]?.amount ?? 0
                $0[$1.categoryName] = (existing + abs($1.amount), $1.categoryColorHex, $1.categoryIcon)
            }
        return categorySpend.map { ($0.key, $0.value.amount, $0.value.color, $0.value.icon) }
            .sorted { $0.1 > $1.1 }
    }

    // 每日消费（从 transactions 按日分组）
    private var dailyData: [(label: String, expense: Double, income: Double, saving: Double)] {
        let expenses = (project.transactions ?? []).filter { $0.type == .expense }.sorted { $0.date < $1.date }
        guard !expenses.isEmpty else { return [] }
        var groups: [String: Double] = [:]
        let df = DateFormatter()
        df.dateFormat = "M/d"
        for tx in expenses {
            let key = df.string(from: tx.date)
            groups[key, default: 0] += abs(tx.amount)
        }
        return groups.sorted { $0.key < $1.key }.map { ($0.key, $0.value, 0, 0) }
    }

    // IP 评论（基于进度）
    private var ipComment: (emoji: String, text: String) {
        if budgetProgress >= 1.0 {
            return ("🦫😰", "安全帽崩溃！预算已超支，快联系银行提额（开玩笑）！")
        } else if budgetProgress >= 0.85 {
            return ("🦫💦", "预算只剩 \(Int(remaining)) 元啦，节约模式启动！")
        } else if budgetProgress >= 0.5 {
            return ("🦫😎", "大交通住宿锁死在 50% 以内，接下来可以放心吃喝！")
        } else {
            return ("🦫🛌", "花得很克制，这次性价比拉满！")
        }
    }
    
    private func categorySpent(_ categoryName: String) -> Double {
        (project.transactions ?? [])
            .filter { $0.type == .expense && $0.categoryName == categoryName }
            .reduce(0) { $0 + abs($1.amount) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: 导航栏
            customNavBar

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    // MARK: 预算防线主卡
                    budgetDefenseCard

                    // MARK: 分类进度
                    categoryProgressCard

                    // MARK: 大件 vs 日常（Plus）
                    PlusLockedSection(
                        isLocked: !storeManager.isPremium,
                        title: "解锁大件分析",
                        onUnlock: onShowPaywall
                    ) {
                        bigItemAnalysisCard
                    }
                    .padding(.horizontal, 24)

                    // MARK: 每日消费走势（Plus）
                    PlusLockedSection(
                        isLocked: !storeManager.isPremium,
                        title: "解锁每日消费走势",
                        onUnlock: onShowPaywall
                    ) {
                        dailyTrendCard
                    }
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 120)
                }
                .padding(.top, 16)
            }
        }
        .background(Color.App.backgroundGray.ignoresSafeArea())
    }

    // MARK: - 子视图

    private var customNavBar: some View {
        ZStack {
            Text("预算防线")
                .font(.system(size: 18, weight: .heavy)).foregroundColor(Color.App.textBlack)
            HStack {
                Button { presentationMode.wrappedValue.dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold))
                        Text("返回").font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(accentColor)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 44).padding(.top, 8)
        .background(Color.App.backgroundGray)
    }

    private var budgetDefenseCard: some View {
        VStack(spacing: 16) {
            // 剩余预算 + IP
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("剩余预算")
                        .font(.system(size: 14, weight: .bold)).foregroundColor(.gray)
                    Text("¥\(Int(max(remaining, 0)))")
                        .font(.system(size: 40, weight: .heavy))
                        .foregroundColor(budgetProgress >= 0.9 ? Color.App.redExpense
                            : budgetProgress >= 0.7 ? Color(hex: "#FFA500") : accentColor)
                    Text("总预算 ¥\(Int(totalBudget))")
                        .font(.system(size: 12)).foregroundColor(.gray)
                }
                Spacer()
                VStack(spacing: 6) {
                    Text(ipComment.emoji).font(.system(size: 36))
                    Text(ipComment.text)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .frame(maxWidth: 120)
                }
            }
            // 渐变进度条
            VStack(spacing: 6) {
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.App.progressTrack).frame(height: 12)
                    Capsule()
                        .fill(LinearGradient(
                            colors: budgetProgress >= 0.9
                                ? [Color.App.redExpense.opacity(0.7), Color.App.redExpense]
                                : budgetProgress >= 0.7
                                    ? [Color(hex: "#FFDD57"), Color(hex: "#FFA500")]
                                    : [Color(hex: colorPair.start), Color(hex: colorPair.end)],
                            startPoint: .leading, endPoint: .trailing))
                        .scaleEffect(x: max(0.001, CGFloat(min(budgetProgress, 1))), y: 1, anchor: .leading)
                        .frame(height: 12)
                        .animation(.easeInOut(duration: 0.6), value: budgetProgress)
                }
                HStack {
                    Text("已用 ¥\(Int(totalSpent))")
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(.gray)
                    Spacer()
                    Text("\(Int(budgetProgress * 100))%")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(budgetProgress >= 0.9 ? Color.App.redExpense
                            : budgetProgress >= 0.7 ? Color(hex: "#FFA500") : accentColor)
                }
            }
        }
        .padding(24)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
        .padding(.horizontal, 24)
    }

    private var categoryProgressCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("分类进度")
                .font(.system(size: 20, weight: .heavy)).foregroundColor(Color.App.textBlack)
            if budgetItems.isEmpty {
                HStack(spacing: 10) {
                    Text("🦫").font(.system(size: 20))
                    Text("还没有预算分类").font(.system(size: 14, weight: .medium)).foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                VStack(spacing: 12) {
                    ForEach(budgetItems) { item in
                        BudgetProgressRow(item: BudgetItemUI(
                            categoryName: item.categoryName,
                            categoryIcon: item.categoryIcon,
                            categoryColorHex: item.categoryColorHex,
                            amount: item.amount,
                            alertThreshold: item.alertThreshold,
                            spent: categorySpent(item.categoryName)
                        ))
                    }
                }
            }
            Divider()
            // 消费结构甜甜圈
            Text("消费结构")
                .font(.system(size: 16, weight: .heavy)).foregroundColor(Color.App.textBlack)
            DonutChartView(segments: segments, total: totalSpent, centerLabel: "总支出")
                .frame(height: 160)
        }
        .padding(24)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
        .padding(.horizontal, 24)
    }

    private var bigItemAnalysisCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("大件 vs 日常")
                .font(.system(size: 20, weight: .heavy)).foregroundColor(Color.App.textBlack)
            Text("剔除大交通和住宿，看日常吃喝玩乐实际花了多少")
                .font(.system(size: 13)).foregroundColor(.gray)
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("大件（交通+住宿）")
                        .font(.system(size: 11, weight: .bold)).foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    Text("¥\(Int(bigItemsAmount))")
                        .font(.system(size: 20, weight: .heavy)).foregroundColor(Color.App.textBlack)
                    Text("\(totalSpent > 0 ? Int(bigItemsAmount / totalSpent * 100) : 0)%")
                        .font(.system(size: 12, weight: .bold)).foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                Divider().frame(height: 50)
                VStack(spacing: 4) {
                    Text("日常均摊 / 天")
                        .font(.system(size: 11, weight: .bold)).foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    Text("¥\(Int(dailyFree))")
                        .font(.system(size: 20, weight: .heavy)).foregroundColor(accentColor)
                    Text("特种兵 / 普通游")
                        .font(.system(size: 12, weight: .bold)).foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
            }
            // 特种兵指数条
            VStack(spacing: 6) {
                HStack {
                    Text("💤 极致穷游").font(.system(size: 11)).foregroundColor(.gray)
                    Spacer()
                    Text("👸 优质贵妇").font(.system(size: 11)).foregroundColor(.gray)
                }
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.App.progressTrack).frame(height: 8)
                    let indicator = min(dailyFree / 800, 1.0)
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color(hex: colorPair.start), accentColor],
                            startPoint: .leading, endPoint: .trailing))
                        .scaleEffect(x: CGFloat(max(0.02, indicator)), y: 1, anchor: .leading)
                        .frame(height: 8)
                }
                Text("日均自由消费 ¥\(Int(dailyFree))（对照：¥800/天 = 贵妇级别）")
                    .font(.system(size: 11)).foregroundColor(.gray)
            }
        }
        .padding(24)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
    }

    private var dailyTrendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("每日消费走势")
                .font(.system(size: 20, weight: .heavy)).foregroundColor(Color.App.textBlack)
            AreaChartView(data: dailyData).frame(height: 130)
            HStack {
                ForEach(dailyData, id: \.label) { d in
                    Text(d.label).font(.system(size: 10, weight: .bold)).foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
            }
            // 峰值提示
            let peak = dailyData.max(by: { $0.expense < $1.expense })
            if let p = peak {
                HStack(spacing: 6) {
                    Image(systemName: "flag.fill").font(.system(size: 12)).foregroundColor(Color(hex: "#FFA500"))
                    Text("消费峰值出现在 \(p.label)，花了 ¥\(Int(p.expense))，记得确认账单！")
                        .font(.system(size: 12)).foregroundColor(.gray)
                }
                .padding(.top, 4)
            }
        }
        .padding(24)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
    }
}
