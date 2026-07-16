import Foundation
import SwiftData

/// 复盘错误
enum ReviewError: LocalizedError {
    case proRequired
    case dailyLimitReached
    case insufficientData

    var errorDescription: String? {
        switch self {
        case .proRequired:
            return "AI 复盘总结为 Pro 专属功能"
        case .dailyLimitReached:
            return "今天的 AI 复盘次数已用完（每天 1 次），明天再来吧！"
        case .insufficientData:
            return "记录较少，暂不生成深度分析"
        }
    }
}

/// 复盘服务：管理缓存与每日额度
@MainActor
class ProjectReviewService {
    static let shared = ProjectReviewService()

    // MARK: - 每日额度 key（独立于 AI 聊天额度）

    static var todayReviewUsageKey: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return "ai_review_usage_" + fmt.string(from: Date())
    }

    // MARK: - 获取复盘结果（优先缓存）

    func getReviewResult(
        project: Project,
        mode: String,
        forceRefresh: Bool = false,
        modelContext: ModelContext
    ) async throws -> ProjectReviewResult {
        let projectID = project.id

        // 1. 查找缓存（非强制刷新时直接返回）
        if !forceRefresh, let cache = fetchCache(projectID: projectID, modelContext: modelContext),
           let data = cache.resultJSON.data(using: .utf8),
           let result = try? JSONDecoder().decode(ProjectReviewResult.self, from: data) {
            return result
        }

        // 2. 需要调用 AI：检查额度 → 计算统计 → 调 LLM → 写缓存
        return try await generateNewReview(project: project, mode: mode, modelContext: modelContext)
    }

    // MARK: - 检查数据是否已更新（仅提示，不自动刷新）

    func isDataUpdated(project: Project, modelContext: ModelContext) -> Bool {
        guard let cache = fetchCache(projectID: project.id, modelContext: modelContext) else {
            return false
        }
        return cache.dataHash != calculateDataHash(project: project)
    }

    // MARK: - 私有方法

    private func generateNewReview(
        project: Project,
        mode: String,
        modelContext: ModelContext
    ) async throws -> ProjectReviewResult {
        // 检查今日次数
        let todayUsage = getTodayUsage(modelContext: modelContext)
        let maxDaily = StoreManager.shared.isPremium ? 1 : 0

        if todayUsage >= maxDaily {
            throw maxDaily == 0 ? ReviewError.proRequired : ReviewError.dailyLimitReached
        }

        // 数据量门槛
        let txCount = (project.transactions ?? []).count
        if txCount < ProjectStatsCalculator.minimumTransactionsForAI {
            throw ReviewError.insufficientData
        }

        // 预计算统计数据
        let lifestyleStats: LifestyleProjectStats?
        let earningStats: EarningProjectStats?
        if mode == "earning" {
            earningStats = ProjectStatsCalculator.calculateEarningStats(project: project)
            lifestyleStats = nil
        } else {
            lifestyleStats = ProjectStatsCalculator.calculateLifestyleStats(project: project)
            earningStats = nil
        }

        // 调用 LLM
        let result = try await LLMService.shared.generateProjectReview(
            projectName: project.name,
            mode: mode,
            lifestyleStats: lifestyleStats,
            earningStats: earningStats
        )

        // 序列化并保存/更新缓存
        if let data = try? JSONEncoder().encode(result),
           let jsonString = String(data: data, encoding: .utf8)
        {
            let dataHash = calculateDataHash(project: project)
            if let existing = fetchCache(projectID: project.id, modelContext: modelContext) {
                existing.resultJSON = jsonString
                existing.dataHash = dataHash
                existing.dailyUsageDate = Date()
            } else {
                let cache = ProjectReviewCache(
                    projectID: project.id,
                    resultJSON: jsonString,
                    dataHash: dataHash
                )
                modelContext.insert(cache)
            }
            try? modelContext.save()
        }

        return result
    }

    private func fetchCache(projectID: UUID, modelContext: ModelContext) -> ProjectReviewCache? {
        let pid = projectID
        let descriptor = FetchDescriptor<ProjectReviewCache>(
            predicate: #Predicate { $0.projectID == pid }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func getTodayUsage(modelContext: ModelContext) -> Int {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<ProjectReviewCache>(
            predicate: #Predicate { $0.dailyUsageDate >= startOfDay }
        )
        return (try? modelContext.fetch(descriptor).count) ?? 0
    }

    /// 数据指纹：交易数量 + 总支出 + 总收入 + 预算 + 分类数
    private func calculateDataHash(project: Project) -> String {
        let txs = project.transactions ?? []
        let txCount = txs.count
        let spent = Int(project.totalSpent)
        let income = Int(project.totalIncome)
        let budget = Int(project.budget)
        let itemsCount = project.budgetItems?.count ?? 0
        return "\(txCount)-\(spent)-\(income)-\(budget)-\(itemsCount)"
    }
}
