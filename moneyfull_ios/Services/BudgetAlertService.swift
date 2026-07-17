import Foundation
import SwiftUI
import Combine

/// 预算预警触发对象
struct BudgetAlertTrigger: Identifiable {
    let id: UUID
    let projectID: UUID
    let projectName: String
    let categoryID: UUID?
    let categoryName: String?
    let progress: Double
    let checkpoint: Int
    let emoji: String
    let message: String
    
    var isProjectLevel: Bool { categoryID == nil }
}

/// 卡皮情绪分级
enum CapyMood: CaseIterable {
    case mild       // 首次越过阈值
    case moderate   // 越过100%
    case severe     // 越过120%
    case extreme    // 越过150%
    
    var emoji: String {
        switch self {
        case .mild: return "🍊"
        case .moderate: return "🍊💦"
        case .severe: return "🦫💦"
        case .extreme: return "🫧"
        }
    }
    
    var message: String {
        switch self {
        case .mild: return "有点超了，还在可控范围，没关系~"
        case .moderate: return "超预算啦，深呼吸，下个月调整回来就好"
        case .severe: return "超了很多，要不要考虑调整一下预算呢？"
        case .extreme: return "钱嘛，乃身外之物。但还是记录一下比较好~"
        }
    }
    
    static func from(progress: Double) -> CapyMood {
        switch progress {
        case ..<1.0: return .mild
        case 1.0..<1.2: return .moderate
        case 1.2..<1.5: return .severe
        default: return .extreme
        }
    }
}

/// 预算预警核心服务
@MainActor
final class BudgetAlertService: ObservableObject {
    static let shared = BudgetAlertService()
    
    @Published var pendingAlerts: [BudgetAlertTrigger] = []
    @Published var showAlertSheet: Bool = false
    @Published var showBanner: Bool = false
    
    private let userDefaults = UserDefaults.standard
    
    // UserDefaults keys
    private enum Keys {
        static func projectCheckpoint(for projectID: UUID) -> String {
            "budget_alert_project_\(projectID.uuidString)"
        }
        static func categoryCheckpoint(for categoryID: UUID) -> String {
            "budget_alert_category_\(categoryID.uuidString)"
        }
    }
    
    private init() {}
    
    // MARK: - 主检查入口
    
    /// 检查预算预警，在记账保存后调用
    func check(after transaction: Transaction, in project: Project) {
        guard project.budgetAlertThreshold > 0 else { return }
        
        var triggers: [BudgetAlertTrigger] = []
        
        // 检查总预算
        if project.budget > 0 {
            let progress = project.budgetProgress
            let checkpoint = getProjectCheckpoint(for: project.id)
            let newCheckpoints = crossedCheckpoints(
                current: progress,
                previous: checkpoint,
                threshold: project.budgetAlertThreshold,
                step: project.budgetAlertStep
            )
            
            if let highestNew = newCheckpoints.max() {
                let mood = CapyMood.from(progress: progress)
                let remaining = max(0, project.budget - project.totalSpent)
                let percentText = String(format: "%.0f", progress * 100)
                let message = "「\(project.name)」总预算已用到 \(percentText)%，还剩 ¥\(Int(remaining))"
                
                triggers.append(BudgetAlertTrigger(
                    id: UUID(),
                    projectID: project.id,
                    projectName: project.name,
                    categoryID: nil,
                    categoryName: nil,
                    progress: progress,
                    checkpoint: highestNew,
                    emoji: mood.emoji,
                    message: message
                ))
                
                setProjectCheckpoint(highestNew, for: project.id)
            }
        }
        
        // 检查分类预算
        let categoryName = transaction.categoryName
        if !categoryName.isEmpty,
           let budgetItems = project.budgetItems,
           let budgetItem = budgetItems.first(where: { $0.categoryName == categoryName }),
           budgetItem.amount > 0 {
            
            let categorySpent = calculateCategorySpent(
                categoryName: categoryName,
                in: project,
                startDate: project.currentCycleStartDate
            )
            let progress = categorySpent / budgetItem.amount
            let checkpoint = getCategoryCheckpoint(for: budgetItem.id)
            let newCheckpoints = crossedCheckpoints(
                current: progress,
                previous: checkpoint,
                threshold: project.budgetAlertThreshold,
                step: project.budgetAlertStep
            )
            
            if let highestNew = newCheckpoints.max() {
                let mood = CapyMood.from(progress: progress)
                let remaining = max(0, budgetItem.amount - categorySpent)
                let percentText = String(format: "%.0f", progress * 100)
                let message = "「\(categoryName)」预算已用到 \(percentText)%，还剩 ¥\(Int(remaining))"
                
                triggers.append(BudgetAlertTrigger(
                    id: UUID(),
                    projectID: project.id,
                    projectName: project.name,
                    categoryID: budgetItem.id,
                    categoryName: categoryName,
                    progress: progress,
                    checkpoint: highestNew,
                    emoji: mood.emoji,
                    message: message
                ))
                
                setCategoryCheckpoint(highestNew, for: budgetItem.id)
            }
        }
        
        // 更新UI状态
        if !triggers.isEmpty {
            pendingAlerts = triggers
            
            if triggers.count == 1 {
                showBanner = true
            } else {
                showAlertSheet = true
            }
            
            // Schedule system push
            scheduleSystemPush(for: project.id, triggers: triggers)
        }
    }
    
    // MARK: - 检查点计算
    
    /// 计算被跨越的检查点
    func crossedCheckpoints(current: Double, previous: Int, threshold: Double, step: Double) -> [Int] {
        guard step > 0 else { return [] }
        
        let currentPercent = Int(current * 100)
        let thresholdPercent = Int(threshold * 100)
        let stepPercent = max(1, Int(step * 100))
        
        var checkpoints: [Int] = []
        var checkpoint = thresholdPercent
        
        // 生成检查点列表
        while checkpoint <= 200 { // 最高检查到200%
            if checkpoint > previous && checkpoint <= currentPercent {
                checkpoints.append(checkpoint)
            }
            checkpoint += stepPercent
        }
        
        return checkpoints
    }
    
    // MARK: - 分类花费计算
    
    /// 计算指定分类在周期内的花费
    func calculateCategorySpent(categoryName: String, in project: Project, startDate: Date) -> Double {
        guard let transactions = project.transactions else { return 0 }
        
        return transactions.filter { tx in
            tx.type == .expense &&
            tx.categoryName == categoryName &&
            tx.date >= startDate
        }.reduce(0) { $0 + abs($1.amount) }
    }
    
    // MARK: - UserDefaults 读写
    
    func getProjectCheckpoint(for projectID: UUID) -> Int {
        userDefaults.integer(forKey: Keys.projectCheckpoint(for: projectID))
    }
    
    func setProjectCheckpoint(_ checkpoint: Int, for projectID: UUID) {
        userDefaults.set(checkpoint, forKey: Keys.projectCheckpoint(for: projectID))
    }
    
    func getCategoryCheckpoint(for categoryID: UUID) -> Int {
        userDefaults.integer(forKey: Keys.categoryCheckpoint(for: categoryID))
    }
    
    func setCategoryCheckpoint(_ checkpoint: Int, for categoryID: UUID) {
        userDefaults.set(checkpoint, forKey: Keys.categoryCheckpoint(for: categoryID))
    }
    
    // MARK: - 重置检查点
    
    func resetProjectCheckpoint(for projectID: UUID) {
        userDefaults.removeObject(forKey: Keys.projectCheckpoint(for: projectID))
    }
    
    func resetCategoryCheckpoint(for categoryID: UUID) {
        userDefaults.removeObject(forKey: Keys.categoryCheckpoint(for: categoryID))
    }
    
    func resetAllCheckpoints(for project: Project) {
        resetProjectCheckpoint(for: project.id)
        if let budgetItems = project.budgetItems {
            for item in budgetItems {
                resetCategoryCheckpoint(for: item.id)
            }
        }
    }
    
    // MARK: - 系统推送调度
    
    private func scheduleSystemPush(for projectID: UUID, triggers: [BudgetAlertTrigger]) {
        // 延迟5分钟推送
        NotificationManager.shared.scheduleBudgetAlertPush(
            projectID: projectID,
            alerts: triggers
        )
    }
    
    /// 取消待发推送（用户回到前台时调用）
    func cancelPendingPush(for projectID: UUID) {
        NotificationManager.shared.cancelPendingBudgetPush(projectID: projectID)
    }
    
    // MARK: - UI 辅助
    
    func dismissAlerts() {
        pendingAlerts = []
        showBanner = false
        showAlertSheet = false
    }
    
    func handleBannerTap(projectID: UUID) {
        dismissAlerts()
        // 跳转到预算详情的逻辑由View层处理
    }
    
    func handleSheetViewDetail(projectID: UUID) {
        dismissAlerts()
        // 跳转到预算详情的逻辑由View层处理
    }
}
