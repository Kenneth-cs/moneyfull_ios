import Foundation
import SwiftUI
import UserNotifications

/// Onboarding 配置动画完成后，执行真实的 App 状态写入操作
@MainActor
struct PersonaConfigExecutor {

    static func execute(for persona: PersonaType, store: AppStore) {
        switch persona {
        case .earner:      executeEarner(store: store)
        case .efficiency:  executeEfficiency()
        case .moonlight:   executeMoonlight(store: store)
        case .dataDriven:  executeDataDriven()
        case .steady:      executeSteady()
        }
    }

    // MARK: - A 项目创收者

    private static func executeEarner(store: AppStore) {
        let ud = UserDefaults.standard

        // 将日常项目设为活跃项目并初始化分类
        if let daily = store.activeProjects.first(where: { $0.name == "日常" }) {
            store.toggleActiveProject(daily)
        }

        // 初始化自由职业专用分类（如不存在）
        let freelanceCategories: [(String, String, String)] = [
            ("项目收入", "dollarsign.circle", "#9EE0C8"),
            ("差旅费", "airplane", "#7EC8E3"),
            ("设备采购", "desktopcomputer", "#C4B5FD"),
            ("外包费用", "person.2", "#F6D7A8")
        ]
        let existingNames = Set(store.categories.map(\.name))
        for (name, icon, color) in freelanceCategories {
            if !existingNames.contains(name) {
                store.addCategory(name: name, icon: icon, colorHex: color, groupName: "自由职业", transactionType: "both")
            }
        }

        ud.set(true, forKey: "voiceEntryEnabled")
        ud.set(true, forKey: "roiDashboardEnabled")
    }

    // MARK: - B 效率优先者

    private static func executeEfficiency() {
        let ud = UserDefaults.standard
        ud.set(true, forKey: "voiceEntryEnabled")
        ud.set(true, forKey: "screenshotRecognitionEnabled")
        // backTapEnabled 需要用户通过 CTA 按钮授权，此处仅标记 onboardingConfigCompleted
        ud.set(true, forKey: "onboardingConfigCompleted")
    }

    // MARK: - C 月光规划师

    private static func executeMoonlight(store: AppStore) {
        let ud = UserDefaults.standard

        // 在日常项目下创建默认生活预算（金额为0待用户填入）
        if let daily = store.activeProjects.first(where: { $0.name == "日常" }) {
            let existing = daily.budgetItems ?? []
            if !existing.contains(where: { $0.categoryName == "本月生活费" }) {
                store.addBudgetItem(to: daily, categoryName: "本月生活费",
                                    categoryIcon: "wallet.bifold",
                                    categoryColorHex: "#9EE0C8", amount: 0)
            }
        }

        ud.set(0.8, forKey: "overspendAlertThreshold")
        ud.set(true, forKey: "dailyBudgetEnabled")
        ud.set(true, forKey: "onboardingConfigCompleted")
    }

    // MARK: - D 数据控进阶者

    private static func executeDataDriven() {
        let ud = UserDefaults.standard
        ud.set(true, forKey: "analyticsEnabled")
        ud.set(true, forKey: "trendAnalysisEnabled")
        ud.set(true, forKey: "monthlyAIReportEnabled")
        ud.set(true, forKey: "onboardingConfigCompleted")
    }

    // MARK: - E 稳健积累者

    private static func executeSteady() {
        let ud = UserDefaults.standard
        // backTapEnabled 需要用户通过 CTA 按钮授权
        ud.set(true, forKey: "capybaraHealthEnabled")
        ud.set(true, forKey: "monthlyReviewEnabled")
        // 创建默认每日 21:00 记账提醒
        scheduleDailyReminder()
        ud.set(true, forKey: "onboardingConfigCompleted")
    }

    // MARK: - 通知调度

    private static func scheduleDailyReminder() {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "钱小满提醒"
        content.body = "今天记账了吗？花10秒记一下吧 💰"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 21
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_reminder", content: content, trigger: trigger)
        center.add(request)
    }
}
