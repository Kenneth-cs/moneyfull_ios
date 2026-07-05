import SwiftUI

/// 项目复盘 Sheet：基础数字免费 + AI 总结遮罩（Plus）+ 导出锁定（Plus）+ 确认归档
struct ProjectReviewSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var storeManager: StoreManager

    let project: Project
    let projectMode: ProjectMode
    var onArchive: () -> Void = {}
    var onShowPaywall: () -> Void = {}

    @State private var showArchiveConfirm = false
    @State private var reviewResult: ProjectReviewResult? = nil
    @State private var isLoadingReview: Bool = false

    private var colorPair: ProgressColorPair { progressColorPair(for: project.colorHex) }
    private var accentColor: Color { Color(hex: colorPair.end) }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: 项目头
                    projectHeader

                    // MARK: 基础数字（免费）
                    basicDataCard

                    // MARK: 预算执行率（免费）
                    budgetSummaryCard

                    // MARK: AI 总结（Plus 遮罩）
                    PlusLockedSection(
                        isLocked: !storeManager.isPremium,
                        title: "解锁 AI 复盘总结",
                        onUnlock: {
                            presentationMode.wrappedValue.dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onShowPaywall() }
                        }
                    ) {
                        aiSummaryCard
                    }
                    .padding(.horizontal, 24)

                    // MARK: 下次预算建议（Plus 遮罩）
                    PlusLockedSection(
                        isLocked: !storeManager.isPremium,
                        title: "解锁下次预算建议",
                        onUnlock: {
                            presentationMode.wrappedValue.dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onShowPaywall() }
                        }
                    ) {
                        nextBudgetCard
                    }
                    .padding(.horizontal, 24)

                    // MARK: 导出报告（Plus）
                    exportCard

                    // MARK: 归档确认
                    archiveButton

                    Spacer().frame(height: 30)
                }
                .padding(.top, 16)
            }
            .background(Color.App.backgroundGray.ignoresSafeArea())
            .navigationTitle("项目复盘")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .confirmationDialog(
                "确认归档「\(project.name)」？",
                isPresented: $showArchiveConfirm,
                titleVisibility: .visible
            ) {
                Button("归档项目", role: .destructive) { onArchive() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("归档后项目数据将保留，你可以随时查看复盘报告。")
            }
        }
    }

    // MARK: - 子视图

    private var projectHeader: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color(hex: project.colorHex).opacity(0.3))
                .frame(width: 60, height: 60)
                .overlay(
                    AppIconView(name: project.icon, size: 26,
                                color: Color.App.projectIconColor(for: project.colorHex))
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.system(size: 20, weight: .heavy)).foregroundColor(Color.App.textBlack)
                HStack(spacing: 8) {
                    Label(projectMode.title, systemImage: projectMode.icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(accentColor)
                    Text("·")
                    Text("项目复盘报告")
                        .font(.system(size: 12)).foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // 最大三笔支出
    private var topExpenses: [(name: String, amount: Double, colorHex: String, icon: String)] {
        (project.transactions ?? [])
            .filter { $0.type == .expense }
            .sorted { abs($0.amount) > abs($1.amount) }
            .prefix(3)
            .map { ($0.categoryName, abs($0.amount), $0.categoryColorHex, $0.categoryIcon) }
    }
    
    private var basicDataCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("总览").font(.system(size: 20, weight: .heavy)).foregroundColor(Color.App.textBlack)
            if projectMode == .earning {
                HStack(spacing: 12) {
                    reviewMetricCell("总收入", "¥\(Int(project.totalIncome))", color: Color.App.darkGreen)
                    reviewMetricCell("总成本", "¥\(Int(project.totalCost))", color: .gray)
                    reviewMetricCell("净利润", "¥\(Int(project.netProfit))",
                                     color: project.netProfit >= 0 ? Color.App.darkGreen : Color.App.redExpense)
                }
                HStack(spacing: 12) {
                    reviewMetricCell("ROI", "\(project.roi.formatted(.number.precision(.fractionLength(1))))%", color: accentColor)
                    reviewMetricCell("总工时", "\(project.totalHourEquivalent.formatted(.number.precision(.fractionLength(1))))h", color: .gray)
                    reviewMetricCell("真实时薪", "¥\(project.effectiveHourlyRate.formatted(.number.precision(.fractionLength(1))))/h", color: accentColor)
                }
            } else {
                HStack(spacing: 12) {
                    reviewMetricCell("总支出", "¥\(Int(project.totalSpent))", color: Color.App.redExpense)
                    reviewMetricCell("预算", "¥\(Int(project.budget))", color: .gray)
                    let overrun = max(project.totalSpent - project.budget, 0)
                    reviewMetricCell(overrun > 0 ? "超支" : "节省",
                                     "¥\(Int(abs(project.budget - project.totalSpent)))",
                                     color: overrun > 0 ? Color.App.redExpense : Color.App.darkGreen)
                }
            }
            Divider()
            // 最大三笔支出
            VStack(alignment: .leading, spacing: 8) {
                Text("最大三笔支出").font(.system(size: 14, weight: .bold)).foregroundColor(.gray)
                ForEach(Array(topExpenses.enumerated()), id: \.offset) { _, exp in
                    HStack {
                        Circle().fill(Color(hex: exp.colorHex)).frame(width: 8, height: 8)
                        Text(exp.name).font(.system(size: 13)).foregroundColor(Color.App.textBlack)
                        Spacer()
                        Text("¥\(Int(exp.amount))").font(.system(size: 13, weight: .bold)).foregroundColor(.gray)
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

    private func reviewMetricCell(_ title: String, _ value: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Text(title).font(.system(size: 11, weight: .bold)).foregroundColor(.gray)
            Text(value).font(.system(size: 15, weight: .heavy)).foregroundColor(color)
                .minimumScaleFactor(0.6).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var budgetSummaryCard: some View {
        let budgetProg = project.budget > 0 ? project.totalSpent / project.budget : 0
        let overrun = max(project.totalSpent - project.budget, 0)
        return VStack(alignment: .leading, spacing: 14) {
            Text("预算执行情况")
                .font(.system(size: 20, weight: .heavy)).foregroundColor(Color.App.textBlack)
            let prog = min(budgetProg, 1.0)
            let barColor: Color = budgetProg >= 1 ? Color.App.redExpense
                : budgetProg >= 0.85 ? Color(hex: "#FFA500") : accentColor
            VStack(spacing: 8) {
                HStack {
                    Text("执行率").font(.system(size: 13, weight: .bold)).foregroundColor(.gray)
                    Spacer()
                    Text("\(Int(budgetProg * 100))%")
                        .font(.system(size: 13, weight: .heavy)).foregroundColor(barColor)
                }
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.App.progressTrack).frame(height: 10)
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color(hex: colorPair.start), barColor],
                            startPoint: .leading, endPoint: .trailing))
                        .scaleEffect(x: max(0.001, CGFloat(prog)), y: 1, anchor: .leading)
                        .frame(height: 10)
                }
                HStack {
                    Text("已用 ¥\(Int(project.totalSpent))").font(.system(size: 11, weight: .semibold)).foregroundColor(.gray)
                    Spacer()
                    Text("预算 ¥\(Int(project.budget))").font(.system(size: 11, weight: .semibold)).foregroundColor(.gray)
                }
            }
            if overrun > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12)).foregroundColor(Color.App.redExpense)
                    Text("超出预算 ¥\(Int(overrun))，下次记得给意外项目留 10% 缓冲！")
                        .font(.system(size: 12, weight: .medium)).foregroundColor(.gray)
                }
                .padding(12)
                .background(Color.App.redExpense.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(24)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
        .padding(.horizontal, 24)
    }

    private var aiSummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").foregroundColor(accentColor)
                Text("AI 复盘总结")
                    .font(.system(size: 20, weight: .heavy)).foregroundColor(Color.App.textBlack)
                Spacer()
                if reviewResult == nil && !isLoadingReview {
                    Button {
                        isLoadingReview = true
                        Task {
                            do {
                                let result = try await LLMService.shared.generateProjectReview(
                                    project: project, mode: projectMode.rawValue
                                )
                                await MainActor.run {
                                    reviewResult = result
                                    isLoadingReview = false
                                }
                            } catch {
                                await MainActor.run { isLoadingReview = false }
                            }
                        }
                    } label: {
                        Text("生成总结").font(.system(size: 12, weight: .bold)).foregroundColor(accentColor)
                    }
                }
            }
            if isLoadingReview {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .padding(.vertical, 20)
            } else if let result = reviewResult {
                ForEach(result.aiSummary.components(separatedBy: "\n").filter { !$0.isEmpty }, id: \.self) { line in
                    aiInsightRow(line)
                }
            } else {
                Text("点击「生成总结」获取 AI 复盘分析").font(.system(size: 13)).foregroundColor(.gray)
            }
        }
        .padding(24)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
    }

    private func aiInsightRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6)).foregroundColor(accentColor)
                .padding(.top, 6)
            Text(text).font(.system(size: 13, weight: .medium)).foregroundColor(Color.App.textBlack.opacity(0.8))
                .lineSpacing(2)
        }
    }

    private var nextBudgetCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill").foregroundColor(Color(hex: "#FFA500"))
                Text("下次预算建议")
                    .font(.system(size: 20, weight: .heavy)).foregroundColor(Color.App.textBlack)
            }
            Text("基于本次数据，AI 为下次同类项目生成参考预算：")
                .font(.system(size: 13)).foregroundColor(.gray)
            if let result = reviewResult, !result.nextBudgetSuggestions.isEmpty {
                VStack(spacing: 10) {
                    ForEach(result.nextBudgetSuggestions, id: \.name) { item in
                        HStack {
                            Text(item.name).font(.system(size: 13, weight: .medium)).foregroundColor(Color.App.textBlack.opacity(0.8))
                            Spacer()
                            Text("¥\(Int(item.amount))").font(.system(size: 14, weight: .heavy)).foregroundColor(accentColor)
                        }
                        Divider()
                    }
                }
            } else {
                Text("生成 AI 复盘后，将自动显示预算建议").font(.system(size: 13)).foregroundColor(.gray)
            }
        }
        .padding(24)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
    }

    private var exportCard: some View {
        Button {
            if storeManager.isPremium {
                // TODO: 导出逻辑（接入数据层后实现）
            } else {
                presentationMode.wrappedValue.dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onShowPaywall() }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: storeManager.isPremium ? "square.and.arrow.up" : "lock.fill")
                    .font(.system(size: 16, weight: .bold))
                VStack(alignment: .leading, spacing: 2) {
                    Text(storeManager.isPremium ? "导出报告（图片/PDF）" : "导出报告  Plus")
                        .font(.system(size: 15, weight: .bold))
                    Text("生成精美复盘长图，发朋友圈 / 小红书")
                        .font(.system(size: 12)).foregroundColor(.white.opacity(0.8))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(20)
            .background(storeManager.isPremium ? accentColor : Color.gray.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 24)
        }
        .buttonStyle(.plain)
    }

    private var archiveButton: some View {
        Button { showArchiveConfirm = true } label: {
            Text("确认归档项目")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.App.redExpense)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.App.redExpense.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)
        }
        .buttonStyle(.plain)
    }

}
