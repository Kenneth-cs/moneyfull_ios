import SwiftUI
import SwiftData

/// 项目复盘分析页（独立页面，通过 NavigationLink push 进入）
struct ProjectReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let project: Project
    let projectMode: ProjectMode
    let onArchive: () -> Void
    let onShowPaywall: () -> Void

    private var colorPair: ProgressColorPair { progressColorPair(for: project.colorHex) }
    private var accentColor: Color { Color(hex: colorPair.end) }
    
    @State private var showDeleteAlert = false
    @State private var deleteError: String?
    @State private var showError = false
    
    // MARK: - AI 复盘
    
    @State private var reviewResult: ProjectReviewResult?
    @State private var isLoadingReview = false
    @State private var reviewError: ReviewError?
    @State private var showDataUpdatedHint = false
    @State private var isRefreshing = false
    
    // MARK: - 导出报告
    
    @State private var isExporting = false
    @State private var exportedFileURL: URL?
    @State private var exportedImage: UIImage?
    @State private var showShareSheet = false
    @State private var exportError: String?
    @State private var showExportErrorAlert = false
    
    private var overrun: Double { max(project.totalSpent - project.budget, 0) }
    private var isOverBudget: Bool { project.totalSpent > project.budget }
    
    var body: some View {
        ZStack {
            Color.App.backgroundGray.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // 总览数字
                    basicDataCard

                    if projectMode == .earning {
                        // 搞钱模式核心指标
                        earningMetricsCard
                    } else {
                        // 生活模式预算概况（含分类明细）
                        budgetSummaryCard
                    }

                    // AI 洞察
                    aiSummaryCard

                    // 下次预算建议
                    nextBudgetCard

                    // 导出报告
                    exportCard

                    // 删除按钮
                    deleteButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("复盘分析")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("返回")
                            .font(.system(size: 17))
                    }
                    .foregroundColor(Color.App.textBlack)
                }
            }
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    deleteProject()
                }
            } message: {
                Text("确定要删除「\(project.name)」吗？此操作不可恢复。")
            }
            .alert("错误", isPresented: $showError) {
                Button("好的", role: .cancel) { }
            } message: {
                Text(deleteError ?? "未知错误")
            }
            .alert("导出失败", isPresented: $showExportErrorAlert) {
                Button("好的", role: .cancel) { }
            } message: {
                Text(exportError ?? "未知错误")
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = exportedImage {
                    ShareSheet(activityItems: [image])
                } else if let url = exportedFileURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .onAppear {
            checkDataUpdated()
            loadCachedResult()
        }
    }
    
    // MARK: - 总览数字
    
    private var basicDataCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: project.icon)
                    .font(.system(size: 24))
                    .foregroundColor(accentColor)
                    .frame(width: 48, height: 48)
                    .background(accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(Color.App.textBlack)
                    
                    HStack(spacing: 4) {
                        Text(projectMode.title)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(accentColor)
                        
                        Text("·")
                            .foregroundColor(Color.App.textSecondary)
                        
                        Text(formatDateRange())
                            .font(.system(size: 12))
                            .foregroundColor(Color.App.textSecondary)
                    }
                }
                
                Spacer()
            }
            
            Divider()
            
            if projectMode == .earning {
                // 搞钱模式：核心财务指标
                HStack(spacing: 12) {
                    metricBox("总收入", "¥\(formatAmount(project.totalIncome))", Color.App.darkGreen)
                    metricBox("总成本", "¥\(formatAmount(project.totalCost))", Color.App.textSecondary)
                    metricBox("净利润", "¥\(formatAmount(project.netProfit))", project.netProfit >= 0 ? Color.App.darkGreen : Color.App.redExpense)
                }
            } else {
                // 生活模式：预算指标
                HStack(spacing: 12) {
                    metricBox("总支出", "¥\(formatAmount(project.totalSpent))", Color.App.redExpense)
                    metricBox("预算", "¥\(formatAmount(project.budget))", Color.App.textSecondary)
                    metricBox(
                        isOverBudget ? "超支" : "节省",
                        "¥\(formatAmount(abs(project.budget - project.totalSpent)))",
                        isOverBudget ? Color.App.redExpense : Color.App.darkGreen
                    )
                }
            }
        }
        .padding(20)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
    }
    
    private func metricBox(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.App.textSecondary)
            Text(value)
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - 搞钱模式核心指标
    
    private var earningMetricsCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(accentColor)
                Text("核心指标")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(Color.App.textBlack)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // ROI 进度条
            progressRow("ROI", progress: min(project.roi / 100, 1),
                        color: project.roi >= 0 ? Color.App.darkGreen : Color.App.redExpense,
                        rightText: "\(project.roi.formatted(.number.precision(.fractionLength(1))))%")
            
            // 真实时薪
            progressRow("真实时薪", progress: min(project.effectiveHourlyRate / 500, 1),
                        color: accentColor,
                        rightText: "¥\(project.effectiveHourlyRate.formatted(.number.precision(.fractionLength(1))))/h")
            
            Divider()
            
            // 详细指标网格
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                detailMetric("总工时", value: "\(project.totalHourEquivalent.formatted(.number.precision(.fractionLength(1))))h")
                detailMetric("工作天数", value: "\(project.effectiveWorkingDays)天")
                detailMetric("时间成本", value: "¥\(formatAmount(project.totalTimeCost))")
                detailMetric("固定成本", value: "¥\(formatAmount(project.fixedCostMonthly))/月")
                detailMetric("目标收入", value: project.targetIncome > 0 ? "¥\(formatAmount(project.targetIncome))" : "未设置")
                detailMetric("本月现金流", value: "¥\(formatAmount(project.monthlyNetCashFlow))")
            }
        }
        .padding(20)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
    }
    
    private func progressRow(_ title: String, progress: Double, color: Color, rightText: String) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.App.textSecondary)
                Spacer()
                Text(rightText)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(color)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.App.progressTrack)
                        .frame(height: 10)
                    Capsule()
                        .fill(color)
                        .frame(width: geometry.size.width * progress, height: 10)
                }
            }
            .frame(height: 10)
        }
    }
    
    private func detailMetric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(Color.App.textSecondary)
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.App.textBlack)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.App.backgroundGray)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 生活模式预算概况（含分类明细）
    
    private var budgetSummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "chart.pie")
                    .foregroundColor(accentColor)
                Text("预算概况")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(Color.App.textBlack)
            }
            
            // 预算进度条
            HStack {
                Text("预算使用")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.App.textSecondary)
                Spacer()
                Text("\(formatPercent(project.budgetProgress))%")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(isOverBudget ? Color.App.redExpense : accentColor)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.App.progressTrack)
                        .frame(height: 10)
                    Capsule()
                        .fill(isOverBudget ? Color.App.redExpense : accentColor)
                        .frame(width: geometry.size.width * min(project.budgetProgress, 1), height: 10)
                }
            }
            .frame(height: 10)
            
            // 超支/节省提示
            if isOverBudget {
                Label("超出预算 ¥\(formatAmount(overrun))", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.App.redExpense)
            } else if project.budget > 0 {
                Label("预算剩余 ¥\(formatAmount(project.budget - project.totalSpent))", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.App.darkGreen)
            }
            
            Divider()
            
            // 分类预算明细（免费展示，纯数据）
            let stats = ProjectStatsCalculator.calculateLifestyleStats(project: project)
            if !stats.categoryBreakdown.isEmpty {
                Text("分类预算")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.App.textSecondary)
                
                ForEach(stats.categoryBreakdown, id: \.name) { item in
                    CategoryBudgetBar(
                        name: item.name,
                        icon: item.icon,
                        colorHex: item.colorHex,
                        budgeted: item.budgeted,
                        actual: item.actual,
                        ratio: item.ratio
                    )
                }
            }
            
            // 消费集中度 & 日均
            Divider()
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("消费集中度")
                        .font(.system(size: 12))
                        .foregroundColor(Color.App.textSecondary)
                    Text(stats.hhiLabel)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.App.textBlack)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("日均花费")
                        .font(.system(size: 12))
                        .foregroundColor(Color.App.textSecondary)
                    Text("¥\(formatAmount(stats.dailyAvgSpend))")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.App.textBlack)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
    }
    
    // MARK: - AI 洞察卡片
    
    private var aiSummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundColor(accentColor)
                Text("AI 复盘总结")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(Color.App.textBlack)
                Spacer()
                
                // 刷新按钮（仅有缓存时显示）
                if reviewResult != nil {
                    Button {
                        AnalyticsManager.shared.trackEvent(
                            eventId: "review_refresh_tapped",
                            eventName: "刷新复盘"
                        )
                        refreshReview()
                    } label: {
                        HStack(spacing: 4) {
                            if isRefreshing {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text("刷新")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isRefreshing ? .gray : accentColor)
                    }
                    .disabled(isRefreshing)
                }
            }
            
            // 数据更新提示
            if showDataUpdatedHint {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.orange)
                    Text("项目数据已更新，点击「刷新」获取最新分析")
                        .font(.system(size: 12))
                        .foregroundColor(Color.App.textSecondary)
                }
                .padding(10)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            Group {
                if isLoadingReview || isRefreshing {
                    HStack { Spacer(); ProgressView(); Spacer() }
                        .padding(.vertical, 20)
                } else if let error = reviewError {
                    reviewErrorView(error)
                } else if let result = reviewResult {
                    // 洞察卡片列表
                    ForEach(result.highlights) { highlight in
                        AIInsightCard(
                            icon: highlight.icon,
                            label: highlight.label,
                            text: highlight.text,
                            accentColor: accentColor
                        )
                    }
                    
                    // 一句话总结
                    Text(result.oneLiner)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(accentColor)
                        .padding(.top, 4)
                } else {
                    // 生成按钮
                    Button {
                        AnalyticsManager.shared.trackEvent(
                            eventId: "review_ai_generate_tapped",
                            eventName: "生成AI复盘",
                            params: ["project_name": project.name]
                        )
                        generateReview()
                    } label: {
                        Text("生成 AI 总结")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .padding(24)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
    }
    
    @ViewBuilder
    private func reviewErrorView(_ error: ReviewError) -> some View {
        VStack(spacing: 12) {
            Image(systemName: error == .dailyLimitReached ? "clock.fill" : "lock.fill")
                .font(.system(size: 32))
                .foregroundColor(error == .dailyLimitReached ? .orange : .gray)
            Text(error.localizedDescription)
                .font(.system(size: 14))
                .foregroundColor(Color.App.textSecondary)
                .multilineTextAlignment(.center)
            if error == .dailyLimitReached {
                Text("剩余次数：0/1")
                    .font(.system(size: 12))
                    .foregroundColor(Color.App.textSecondary)
            }
            if error == .proRequired {
                Button("升级 Pro") {
                    onShowPaywall()
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
    
    // MARK: - 下次预算建议
    
    private var nextBudgetCard: some View {
        Group {
            if let result = reviewResult, !result.nextBudgetSuggestions.isEmpty || result.nextQuoteSuggestion != nil {
                ProLockedSection(isLocked: !StoreManager.shared.isPremium, title: "升级 Pro 解锁 AI 预算建议", onUnlock: onShowPaywall) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 6) {
                            Image(systemName: "lightbulb")
                                .foregroundColor(accentColor)
                            Text("下次预算建议")
                                .font(.system(size: 20, weight: .heavy))
                                .foregroundColor(Color.App.textBlack)
                        }
                        
                        // 搞钱模式报价建议
                        if let quote = result.nextQuoteSuggestion {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("建议报价")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color.App.darkGreen)
                                    Text(quote.reason)
                                        .font(.system(size: 12))
                                        .foregroundColor(Color.App.textSecondary)
                                }
                                Spacer()
                                Text("¥\(formatAmount(quote.suggestedAmount))")
                                    .font(.system(size: 22, weight: .heavy))
                                    .foregroundColor(Color.App.darkGreen)
                            }
                            .padding(16)
                            .background(Color.App.darkGreen.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        
                        // 分类预算建议
                        ForEach(result.nextBudgetSuggestions) { suggestion in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.name)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color.App.textBlack)
                                    if !suggestion.reason.isEmpty {
                                        Text(suggestion.reason)
                                            .font(.system(size: 11))
                                            .foregroundColor(Color.App.textSecondary)
                                    }
                                }
                                Spacer()
                                Text("¥\(formatAmount(suggestion.amount))")
                                    .font(.system(size: 16, weight: .heavy))
                                    .foregroundColor(accentColor)
                            }
                            .padding(12)
                            .background(Color.App.backgroundGray)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 导出报告
    
    private var exportCard: some View {
        VStack(spacing: 12) {
            ProLockedSection(isLocked: !StoreManager.shared.isPremium, title: "升级 Pro 解锁导出功能", onUnlock: onShowPaywall) {
                // 两个并排导出按钮
                HStack(spacing: 12) {
                    // 导出长图
                    Button {
                        AnalyticsManager.shared.trackEvent(eventId: "review_export_image", eventName: "导出复盘图片")
                        exportAsImage()
                    } label: {
                        HStack(spacing: 6) {
                            if isExporting {
                                ProgressView().tint(.white).scaleEffect(0.8)
                            } else {
                                Image(systemName: "photo")
                            }
                            Text("导出长图")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(reviewResult == nil || isExporting)
                    .opacity(reviewResult == nil ? 0.6 : 1)

                    // 导出 PDF
                    Button {
                        AnalyticsManager.shared.trackEvent(eventId: "review_export_pdf", eventName: "导出复盘PDF")
                        exportAsPDF()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.richtext")
                            Text("导出 PDF")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(accentColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(accentColor.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .disabled(reviewResult == nil || isExporting)
                    .opacity(reviewResult == nil ? 0.6 : 1)
                }
            }

            if reviewResult == nil {
                Text("请先生成 AI 复盘总结")
                    .font(.system(size: 12))
                    .foregroundColor(Color.App.textSecondary)
            }
        }
    }
    
    // MARK: - 删除按钮

    private var deleteButton: some View {
        VStack(spacing: 8) {
            Button {
                showDeleteAlert = true
            } label: {
                Text("删除项目")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.App.redExpense)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.App.redExpense.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            
            Text("删除后数据无法恢复")
                .font(.system(size: 12))
                .foregroundColor(Color.App.textSecondary)
        }
    }
    
    // MARK: - 缓存与生成逻辑
    
    private func loadCachedResult() {
        if let cache = fetchCache(projectID: project.id),
           let data = cache.resultJSON.data(using: .utf8),
           let result = try? JSONDecoder().decode(ProjectReviewResult.self, from: data) {
            reviewResult = result
        }
    }
    
    private func checkDataUpdated() {
        showDataUpdatedHint = ProjectReviewService.shared.isDataUpdated(project: project, modelContext: modelContext)
    }
    
    private func generateReview() {
        isLoadingReview = true
        reviewError = nil
        
        Task {
            do {
                let result = try await ProjectReviewService.shared.getReviewResult(
                    project: project,
                    mode: projectMode.rawValue,
                    modelContext: modelContext
                )
                await MainActor.run {
                    reviewResult = result
                    isLoadingReview = false
                    showDataUpdatedHint = false
                    AnalyticsManager.shared.trackEvent(
                        eventId: "review_ai_generate_success",
                        eventName: "AI复盘生成成功",
                        params: ["project_name": project.name]
                    )
                }
            } catch let error as ReviewError {
                await MainActor.run {
                    reviewError = error
                    isLoadingReview = false
                    if error == .dailyLimitReached {
                        AnalyticsManager.shared.trackEvent(
                            eventId: "review_ai_daily_limit_hit",
                            eventName: "复盘每日次数限制",
                            params: ["project_name": project.name]
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    reviewError = .insufficientData
                    isLoadingReview = false
                }
            }
        }
    }
    
    private func refreshReview() {
        isRefreshing = true
        reviewError = nil
        
        Task {
            do {
                let result = try await ProjectReviewService.shared.getReviewResult(
                    project: project,
                    mode: projectMode.rawValue,
                    forceRefresh: true,
                    modelContext: modelContext
                )
                await MainActor.run {
                    reviewResult = result
                    isRefreshing = false
                    showDataUpdatedHint = false
                }
            } catch let error as ReviewError {
                await MainActor.run {
                    reviewError = error
                    isRefreshing = false
                }
            } catch {
                await MainActor.run {
                    reviewError = .insufficientData
                    isRefreshing = false
                }
            }
        }
    }
    
    private func fetchCache(projectID: UUID) -> ProjectReviewCache? {
        let pid = projectID
        let descriptor = FetchDescriptor<ProjectReviewCache>(
            predicate: #Predicate { $0.projectID == pid }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    // MARK: - 导出逻辑
    
    private func exportAsImage() {
        guard let result = reviewResult else { return }
        isExporting = true

        Task {
            do {
                guard let image = await ReportExportService.exportAsImage(
                    project: project, reviewResult: result, projectMode: projectMode
                ) else {
                    throw ExportError.renderFailed
                }
                exportedImage = image
                exportedFileURL = nil
                showShareSheet = true
                isExporting = false
            } catch {
                isExporting = false
                exportError = error.localizedDescription
                showExportErrorAlert = true
            }
        }
    }

    private func exportAsPDF() {
        guard let result = reviewResult else { return }
        isExporting = true

        Task {
            do {
                guard let pdfData = await ReportExportService.exportAsPDF(
                    project: project, reviewResult: result, projectMode: projectMode
                ) else {
                    throw ExportError.renderFailed
                }
                let filename = "\(project.name)_复盘报告_\(formatShortDate()).pdf"
                let fileURL = try ReportExportService.saveToFile(pdfData, filename: filename)
                exportedImage = nil
                exportedFileURL = fileURL
                showShareSheet = true
                isExporting = false
            } catch {
                isExporting = false
                exportError = error.localizedDescription
                showExportErrorAlert = true
            }
        }
    }

    private func formatShortDate() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd"
        return fmt.string(from: Date())
    }
    
    // MARK: - 辅助
    
    private func formatDateRange() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        let start = formatter.string(from: project.createdAt)
        let end = formatter.string(from: Date())
        return "\(start) - \(end)"
    }
    
    private func formatPercent(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value * 100)) ?? "\(value * 100)"
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount))"
    }

    private func deleteProject() {
        do {
            let transactions = project.transactions ?? []
            for transaction in transactions {
                modelContext.delete(transaction)
            }
            
            // 删除关联的复盘缓存
            let pid = project.id
            let cacheDescriptor = FetchDescriptor<ProjectReviewCache>(
                predicate: #Predicate { $0.projectID == pid }
            )
            let caches = (try? modelContext.fetch(cacheDescriptor)) ?? []
            for cache in caches { modelContext.delete(cache) }
            
            modelContext.delete(project)
            try modelContext.save()
            onArchive()
        } catch {
            deleteError = "删除失败：\(error.localizedDescription)"
            showError = true
        }
    }
}
