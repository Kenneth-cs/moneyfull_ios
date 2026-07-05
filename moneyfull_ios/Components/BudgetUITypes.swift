import Foundation
import SwiftUI

// MARK: - UI-only stub structs（纯 UI 阶段，不依赖 SwiftData）

struct BudgetItemUI: Identifiable {
    var id = UUID()
    var categoryName: String
    var categoryIcon: String
    var categoryColorHex: String
    var amount: Double
    var alertThreshold: Double = 0   // 0 = 不预警；0.8 = 80% 提醒
    var spent: Double = 0            // UI 阶段 mock，接入数据层时改为计算属性

    var progress: Double {
        guard amount > 0 else { return 0 }
        return spent / amount
    }
    var isOverBudget: Bool { progress > 1.0 }
    var isNearLimit: Bool { alertThreshold > 0 && progress >= alertThreshold && !isOverBudget }
}

struct TimeEntryUI: Identifiable {
    var id = UUID()
    var duration: Double
    var granularity: String   // "hour" | "day"
    var rate: Double
    var note: String
    var date: Date

    var cost: Double { duration * rate }

    var displayDuration: String {
        granularity == "day"
            ? "\(duration.formatted(.number.precision(.fractionLength(1))))天"
            : "\(duration.formatted(.number.precision(.fractionLength(1))))h"
    }
}

// MARK: - 项目模式

enum ProjectMode: String, CaseIterable, Identifiable {
    case earning  = "earning"
    case lifestyle = "lifestyle"
    var id: String { rawValue }

    var title: String       { self == .earning ? "搞钱模式" : "生活模式" }
    var subtitle: String    { self == .earning ? "外包 / 副业 / 投资" : "旅行 / 装修 / 约会" }
    var description: String { self == .earning ? "算利润和真实时薪" : "看预算剩余和性价比" }
    var icon: String        { self == .earning ? "briefcase.fill" : "leaf.fill" }
}

// MARK: - 预算周期

enum BudgetCycle: String, CaseIterable, Identifiable {
    case project = "project"
    case monthly = "monthly"
    case custom  = "custom"
    var id: String { rawValue }

    var label: String {
        switch self {
        case .project: return "整个项目（不刷新）"
        case .monthly: return "按月自动刷新"
        case .custom:  return "自定义天数"
        }
    }
    var hint: String {
        switch self {
        case .project: return "预算从创建到归档一次性扣除"
        case .monthly: return "每月 1 日自动重置，适合长期副业"
        case .custom:  return "到期后自动开始新的周期"
        }
    }
}

// MARK: - Mock 工厂

extension BudgetItemUI {
    static func mockTravel(budget: Double = 10000) -> [BudgetItemUI] {
        [
            BudgetItemUI(categoryName: "交通", categoryIcon: "car.fill",
                         categoryColorHex: "#A8E0C2", amount: budget * 0.22, alertThreshold: 0.8, spent: budget * 0.18),
            BudgetItemUI(categoryName: "住宿", categoryIcon: "house.fill",
                         categoryColorHex: "#B3D1E6", amount: budget * 0.33, alertThreshold: 0.8, spent: budget * 0.24),
            BudgetItemUI(categoryName: "餐饮", categoryIcon: "fork.knife",
                         categoryColorHex: "#F6D7A8", amount: budget * 0.20, alertThreshold: 0.9, spent: budget * 0.19),
            BudgetItemUI(categoryName: "门票娱乐", categoryIcon: "ticket.fill",
                         categoryColorHex: "#D8C6E8", amount: budget * 0.15, alertThreshold: 0, spent: budget * 0.08),
            BudgetItemUI(categoryName: "购物", categoryIcon: "bag.fill",
                         categoryColorHex: "#F2B7C6", amount: budget * 0.10, alertThreshold: 0, spent: budget * 0.13),
        ]
    }

    static func mockEarning(budget: Double = 8000) -> [BudgetItemUI] {
        [
            BudgetItemUI(categoryName: "软件工具", categoryIcon: "desktopcomputer",
                         categoryColorHex: "#A8E0C2", amount: budget * 0.20, alertThreshold: 0, spent: budget * 0.12),
            BudgetItemUI(categoryName: "差旅", categoryIcon: "airplane",
                         categoryColorHex: "#B3D1E6", amount: budget * 0.30, alertThreshold: 0.8, spent: budget * 0.33),
            BudgetItemUI(categoryName: "外包协作", categoryIcon: "person.2.fill",
                         categoryColorHex: "#F6D7A8", amount: budget * 0.35, alertThreshold: 0, spent: budget * 0.20),
            BudgetItemUI(categoryName: "其他", categoryIcon: "ellipsis.circle.fill",
                         categoryColorHex: "#D8C6E8", amount: budget * 0.15, alertThreshold: 0, spent: budget * 0.05),
        ]
    }
}

extension TimeEntryUI {
    static func mockEntries() -> [TimeEntryUI] {
        let cal = Calendar.current
        let now = Date()
        return [
            TimeEntryUI(duration: 3,   granularity: "hour", rate: 100, note: "完成首页设计稿",
                        date: cal.date(byAdding: .day, value: -1, to: now) ?? now),
            TimeEntryUI(duration: 1.5, granularity: "hour", rate: 100, note: "客户沟通",
                        date: cal.date(byAdding: .day, value: -1, to: now) ?? now),
            TimeEntryUI(duration: 1,   granularity: "day",  rate: 800, note: "调研竞品",
                        date: cal.date(byAdding: .day, value: -3, to: now) ?? now),
            TimeEntryUI(duration: 4,   granularity: "hour", rate: 100, note: "修改第二轮反馈",
                        date: cal.date(byAdding: .day, value: -5, to: now) ?? now),
        ]
    }
}

// MARK: - 项目名称本地模式推断（UI 阶段，无需调 LLM）

func suggestProjectMode(for name: String, desc: String = "") -> ProjectMode {
    let text = (name + desc).lowercased()
    let earningKw = ["外包", "接单", "副业", "设计", "开发", "创业", "工作", "合同", "收入", "服务", "编程", "运营"]
    let lifestyleKw = ["旅行", "旅游", "出行", "装修", "约会", "恋爱", "购物", "生活", "度假", "婚礼", "游"]
    let earn = earningKw.filter { text.contains($0) }.count
    let life = lifestyleKw.filter { text.contains($0) }.count
    return earn > life ? .earning : .lifestyle
}
