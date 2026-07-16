import SwiftUI

/// 经营看板全页（搞钱模式）
/// 核心体系：日均收益/成本（零门槛），记工时为可选增强
struct ProjectEarningView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var storeManager: StoreManager

    let project: Project
    var onShowPaywall: () -> Void = {}

    @State private var showTimeEntry = false
    @State private var showWorkingDaysPicker = false
    @State private var editingWorkingDays: String = ""

    private var colorPair: ProgressColorPair { progressColorPair(for: project.colorHex) }
    private var accentColor: Color { Color(hex: colorPair.end) }

    // 成本结构（按账单分类汇总，无时间成本栏）
    private var costSegments: [(name: String, amount: Double, colorHex: String, icon: String)] {
        let colors = ["#A8E0C2", "#B3D1E6", "#F6D7A8", "#D8C6E8", "#F2B7C6"]
        let categorySpend = (project.transactions ?? [])
            .filter { $0.type == .expense }
            .reduce(into: [String: (Double, String, String)]()) { dict, tx in
                dict[tx.categoryName] = (
                    (dict[tx.categoryName]?.0 ?? 0) + abs(tx.amount),
                    tx.categoryColorHex,
                    tx.categoryIcon
                )
            }
        return categorySpend.sorted(by: { $0.value.0 > $1.value.0 }).prefix(5).enumerated().map { i, entry in
            (entry.key, entry.value.0, colors[i % colors.count], entry.value.2)
        }
    }

    // 每日支出走势（按天分组）
    private var dailyData: [(label: String, expense: Double, income: Double, saving: Double)] {
        let txs = (project.transactions ?? []).sorted { $0.date < $1.date }
        var grouped: [String: Double] = [:]
        let fmt = DateFormatter()
        fmt.dateFormat = "M/d"
        for tx in txs where tx.type == .expense {
            let key = fmt.string(from: tx.date)
            grouped[key, default: 0] += abs(tx.amount)
        }
        return grouped.sorted { $0.key < $1.key }.suffix(7).map { ($0.key, $0.value, 0, 0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            customNavBar

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    // MARK: ① 核心指标（净利润 + ROI + 日均收益）
                    coreMetricCard

                    // MARK: ② 收支总览
                    incomeOverviewCard

                    // MARK: ③ 工作周期（日均体系核心，零门槛）
                    workingCycleCard

                    // MARK: ④ 成本结构（甜甜圈）
                    if !costSegments.isEmpty {
                        costStructureCard
                    }

                    // MARK: ⑤ 真实时薪（仅有工时记录时展示，可选增强）
                    if project.hasTimeEntries {
                        hourlyRateCard
                    }

                    // MARK: ⑥ 趋势月环比（Pro）
                    ProLockedSection(
                        isLocked: !storeManager.isPremium,
                        title: "解锁趋势月环比",
                        onUnlock: onShowPaywall
                    ) {
                        trendCard
                    }
                    .padding(.horizontal, 24)

                    // MARK: ⑦ AI 洞察（Pro）
                    ProLockedSection(
                        isLocked: !storeManager.isPremium,
                        title: "解锁 AI 经营洞察",
                        onUnlock: onShowPaywall
                    ) {
                        aiInsightCard
                    }
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 120)
                }
                .padding(.top, 16)
            }
        }
        .background(Color.App.backgroundGray.ignoresSafeArea())
        .sheet(isPresented: $showTimeEntry) {
            TimeEntrySheet(defaultRate: project.defaultRate) { entry in
                store.addTimeEntry(
                    to: project,
                    duration: entry.duration,
                    granularity: entry.granularity,
                    rate: entry.rate,
                    note: entry.note,
                    date: entry.date
                )
            }
        }
        // 记工时 FAB（可选功能，右下角）
        .overlay(alignment: .bottomTrailing) {
            Button { showTimeEntry = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "clock.badge.plus")
                        .font(.system(size: 15, weight: .bold))
                    Text("记工时")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(accentColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.App.cardBackground)
                .clipShape(Capsule())
                .shadow(color: accentColor.opacity(0.2), radius: 8, x: 0, y: 4)
                .overlay(
                    Capsule().stroke(accentColor.opacity(0.3), lineWidth: 1)
                )
            }
            .padding(.trailing, 24)
            .padding(.bottom, 36)
        }
    }

    // MARK: - 导航栏

    private var customNavBar: some View {
        ZStack {
            Text("经营看板")
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(Color.App.textBlack)
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

    // MARK: - ① 核心指标卡

    private var coreMetricCard: some View {
        VStack(spacing: 16) {
            // 净利润（最大字号主角）
            VStack(spacing: 6) {
                Text("净利润").font(.system(size: 14, weight: .bold)).foregroundColor(.gray)
                Text("¥\(project.netProfit.formatted(.number.precision(.fractionLength(0))))")
                    .font(.system(size: 40, weight: .heavy))
                    .foregroundColor(project.netProfit >= 0 ? Color.App.darkGreen : Color.App.redExpense)

                // 目标收入进度（有设置时展示）
                if project.targetIncome > 0 {
                    let prog = min(project.totalIncome / project.targetIncome, 1.0)
                    HStack(spacing: 8) {
                        Text("目标 ¥\(Int(project.targetIncome))")
                            .font(.system(size: 12)).foregroundColor(.gray)
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.App.progressTrack).frame(height: 6)
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [Color(hex: colorPair.start), accentColor],
                                    startPoint: .leading, endPoint: .trailing))
                                .scaleEffect(x: max(0.01, CGFloat(prog)), y: 1, anchor: .leading)
                                .frame(height: 6)
                        }
                        .frame(maxWidth: 100)
                        Text("\(Int(prog * 100))%")
                            .font(.system(size: 12, weight: .bold)).foregroundColor(accentColor)
                    }
                }
            }

            Divider()

            // ROI + 日均收益（两格次要数字）
            HStack(spacing: 0) {
                metricCell(
                    title: "ROI",
                    value: "\(project.roi.formatted(.number.precision(.fractionLength(1))))%",
                    color: project.roi >= 0 ? accentColor : Color.App.redExpense
                )
                Divider().frame(height: 40)
                metricCell(
                    title: "日均收益",
                    value: "¥\(project.dailyProfit.formatted(.number.precision(.fractionLength(0))))/天",
                    color: project.dailyProfit >= 0 ? accentColor : Color.App.redExpense
                )
            }
        }
        .padding(24)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
        .padding(.horizontal, 24)
    }

    // MARK: - ② 收支总览

    private var incomeOverviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("收支总览")
                .font(.system(size: 20, weight: .heavy)).foregroundColor(Color.App.textBlack)
            HStack(spacing: 12) {
                StatCard(title: "总收入", value: project.totalIncome, color: Color.App.darkGreen)
                StatCard(title: "总支出", value: project.totalSpent, color: .gray)
                StatCard(title: "净利润", value: project.netProfit,
                         color: project.netProfit >= 0 ? Color.App.darkGreen : Color.App.redExpense)
            }
        }
        .padding(24)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
        .padding(.horizontal, 24)
    }

    // MARK: - ③ 工作周期（零门槛核心）

    private var workingCycleCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("工作周期")
                    .font(.system(size: 20, weight: .heavy)).foregroundColor(Color.App.textBlack)
                Spacer()
                // 设置工作天数（内联编辑）
                Button {
                    editingWorkingDays = project.workingDays > 0 ? "\(project.workingDays)" : ""
                    withAnimation { showWorkingDaysPicker.toggle() }
                } label: {
                    Text(project.workingDays > 0 ? "已设 \(project.workingDays) 天" : "设置工作天数")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                }
            }

            // 天数设置内联表单
            if showWorkingDaysPicker {
                HStack(spacing: 10) {
                    Text("实际工作天数")
                        .font(.system(size: 13)).foregroundColor(.gray)
                    TextField("0", text: $editingWorkingDays)
                        .keyboardType(.numberPad)
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 60)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.App.tabBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Text("天（0 = 自动）")
                        .font(.system(size: 13)).foregroundColor(.gray)
                    Spacer()
                    Button("确定") {
                        let days = Int(editingWorkingDays) ?? 0
                        store.updateProjectWorkingDays(project, days: days)
                        withAnimation { showWorkingDaysPicker = false }
                    }
                    .font(.system(size: 13, weight: .bold)).foregroundColor(accentColor)
                }
                .padding(12)
                .background(Color.App.tabBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // 三格数字
            HStack(spacing: 0) {
                metricCell(
                    title: "自然天数",
                    value: "\(Calendar.current.dateComponents([.day], from: project.createdAt, to: Date()).day ?? 0)天",
                    color: Color.App.textBlack
                )
                Divider().frame(height: 40)
                metricCell(
                    title: "计算天数",
                    value: "\(project.effectiveWorkingDays)天",
                    color: accentColor
                )
                Divider().frame(height: 40)
                metricCell(
                    title: "日均成本",
                    value: "¥\(project.dailyCost.formatted(.number.precision(.fractionLength(0))))",
                    color: Color.App.textBlack
                )
            }

            // 每日支出走势（有账单时显示）
            if !dailyData.isEmpty {
                Divider()
                Text("支出走势（近 7 天）")
                    .font(.system(size: 13, weight: .bold)).foregroundColor(.gray)
                AreaChartView(data: dailyData).frame(height: 100)
                HStack {
                    ForEach(dailyData, id: \.label) { d in
                        Text(d.label).font(.system(size: 9, weight: .bold)).foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            // 记工时引导（无工时记录时显示）
            if !project.hasTimeEntries {
                Divider()
                Button { showTimeEntry = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "clock.badge.plus")
                            .font(.system(size: 14)).foregroundColor(accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("可选：记录工时获取真实时薪")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.App.textBlack)
                            Text("记录每次工作时长，精确算出你真正值多少钱/小时")
                                .font(.system(size: 11)).foregroundColor(.gray)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold)).foregroundColor(.gray)
                    }
                    .padding(12)
                    .background(accentColor.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
        .padding(.horizontal, 24)
    }

    // MARK: - ④ 成本结构

    private var costStructureCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("支出结构")
                .font(.system(size: 20, weight: .heavy)).foregroundColor(Color.App.textBlack)
            DonutChartView(segments: costSegments, total: project.totalSpent, centerLabel: "总支出")
                .frame(height: 180)
            VStack(spacing: 10) {
                ForEach(costSegments, id: \.name) { seg in
                    HStack(spacing: 10) {
                        Circle().fill(Color(hex: seg.colorHex)).frame(width: 10, height: 10)
                        Image(systemName: seg.icon)
                            .font(.system(size: 12)).foregroundColor(Color(hex: seg.colorHex))
                        Text(seg.name).font(.system(size: 13, weight: .medium)).foregroundColor(Color.App.textBlack.opacity(0.8))
                        Spacer()
                        Text("¥\(Int(seg.amount))").font(.system(size: 13, weight: .bold)).foregroundColor(Color.App.textBlack)
                        let pct = project.totalSpent > 0 ? Int(seg.amount / project.totalSpent * 100) : 0
                        Text("(\(pct)%)").font(.system(size: 11)).foregroundColor(.gray)
                    }
                }
            }
        }
        .padding(24)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
        .padding(.horizontal, 24)
    }

    // MARK: - ⑤ 真实时薪（有工时记录才显示）

    private var hourlyRateCard: some View {
        let timeEntries = project.timeEntries ?? []
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 14, weight: .bold)).foregroundColor(accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("真实时薪")
                            .font(.system(size: 20, weight: .heavy)).foregroundColor(Color.App.textBlack)
                        Text("= (收入 - 支出) ÷ 工时")
                            .font(.system(size: 11, weight: .medium)).foregroundColor(.gray)
                    }
                }
                Spacer()
                Text("已记录 \(timeEntries.count) 条").font(.system(size: 12)).foregroundColor(.gray)
            }

            HStack(spacing: 0) {
                metricCell(
                    title: "真实时薪",
                    value: "¥\(project.effectiveHourlyRate.formatted(.number.precision(.fractionLength(1))))/h",
                    color: project.defaultRate > 0 && project.effectiveHourlyRate < project.defaultRate
                        ? Color.App.redExpense : accentColor
                )
                Divider().frame(height: 40)
                metricCell(
                    title: "累计工时",
                    value: "\(project.totalHourEquivalent.formatted(.number.precision(.fractionLength(1))))h",
                    color: Color.App.textBlack
                )
                if project.defaultRate > 0 {
                    Divider().frame(height: 40)
                    let diff = project.effectiveHourlyRate - project.defaultRate
                    metricCell(
                        title: "vs 目标",
                        value: (diff >= 0 ? "+" : "") + "¥\(Int(diff))/h",
                        color: diff >= 0 ? Color.App.darkGreen : Color.App.redExpense
                    )
                }
            }

            // 工时列表（最近 3 条，支持左滑删除）
            if !timeEntries.isEmpty {
                Divider()
                List {
                    ForEach(timeEntries.sorted { $0.date > $1.date }.prefix(3)) { entry in
                        HStack(spacing: 12) {
                            Circle().fill(Color.App.primaryGreen.opacity(0.25)).frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: "clock.fill").font(.system(size: 12))
                                        .foregroundColor(Color.App.darkGreen)
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.note.isEmpty ? "工时记录" : entry.note)
                                    .font(.system(size: 13, weight: .bold)).foregroundColor(Color.App.textBlack)
                                Text(entry.date, style: .date).font(.system(size: 11)).foregroundColor(.gray)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                let hours = entry.granularity == "day" ? "\(entry.duration.formatted(.number.precision(.fractionLength(1))))天" : "\(entry.duration.formatted(.number.precision(.fractionLength(1))))h"
                                Text(hours).font(.system(size: 13, weight: .heavy)).foregroundColor(Color.App.textBlack)
                                Text("¥\(Int(entry.duration * entry.rate))").font(.system(size: 11)).foregroundColor(.gray)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                store.deleteTimeEntry(entry)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .listRowSeparator(.hidden)
                .frame(height: CGFloat(min(timeEntries.count, 3)) * 70)
                if timeEntries.count > 3 {
                    Text("共 \(timeEntries.count) 条记录").font(.system(size: 12)).foregroundColor(.gray)
                }
            }
        }
        .padding(24)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
        .padding(.horizontal, 24)
    }

    // MARK: - ⑥ 趋势月环比（Pro）

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("趋势月环比")
                .font(.system(size: 20, weight: .heavy)).foregroundColor(Color.App.textBlack)
            HStack(spacing: 0) {
                metricCell(title: "ROI", value: "\(project.roi.formatted(.number.precision(.fractionLength(1))))%")
                Divider().frame(height: 50)
                metricCell(title: "净利润", value: "¥\(Int(project.netProfit))")
                Divider().frame(height: 50)
                metricCell(title: "日均收益", value: "¥\(Int(project.dailyProfit))")
            }
        }
        .padding(24)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
    }

    // MARK: - ⑦ AI 洞察（Pro）

    @State private var aiInsightText: String = ""
    @State private var isLoadingInsight: Bool = false

    private var aiInsightCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").foregroundColor(accentColor)
                Text("AI 洞察").font(.system(size: 20, weight: .heavy)).foregroundColor(Color.App.textBlack)
                Spacer()
                if aiInsightText.isEmpty {
                    Button {
                        isLoadingInsight = true
                        Task {
                            do {
                                let text = try await LLMService.shared.generateEarningInsight(project: project)
                                await MainActor.run { aiInsightText = text; isLoadingInsight = false }
                            } catch {
                                await MainActor.run { isLoadingInsight = false }
                            }
                        }
                    } label: {
                        if isLoadingInsight {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text("生成洞察").font(.system(size: 12, weight: .bold)).foregroundColor(accentColor)
                        }
                    }
                }
            }
            if aiInsightText.isEmpty && !isLoadingInsight {
                Text("点击生成 AI 经营洞察").font(.system(size: 13)).foregroundColor(.gray)
            } else if !aiInsightText.isEmpty {
                Text(aiInsightText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.App.textBlack.opacity(0.8))
                    .lineSpacing(3)
            }
        }
        .padding(24)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
    }

    // MARK: - 通用

    private func metricCell(title: String, value: String, color: Color = Color.App.textBlack) -> some View {
        VStack(spacing: 5) {
            Text(title).font(.system(size: 11, weight: .bold)).foregroundColor(.gray)
            Text(value).font(.system(size: 16, weight: .heavy)).foregroundColor(color)
                .minimumScaleFactor(0.6).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}
