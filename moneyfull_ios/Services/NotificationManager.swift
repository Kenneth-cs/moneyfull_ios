import Foundation
import UserNotifications

enum ReminderStyle: String, CaseIterable {
    case warm = "温馨陪伴"
    case simple = "简洁高效"
    case funny = "搞笑幽默"
    
    var messages: [String] {
        switch self {
        case .warm:
            return [
                "今天过得怎么样？别忘了记一笔哦 🦫",
                "小满在这里等你，和我说说今天的花销吧～",
                "再忙也别忘了记录，你的财务管家在提醒你 💚",
                "坚持记账第N天！每一笔都算数 📝",
                "花2秒记录今天的收支，月底复盘更从容～"
            ]
        case .simple:
            return [
                "记账提醒：请记录今日收支 📊",
                "今日账单尚未记录",
                "记一笔，保持财务清晰",
                "每日记账，掌控开支",
                "记录今天，规划明天"
            ]
        case .funny:
            return [
                "你的钱包想你了，快来记一笔 💸",
                "今天花钱了吗？快向小满汇报！🦫",
                "记账使我快乐，你呢？😄",
                "再不记账，钱就要偷偷溜走了～",
                "叮咚！您的财务小管家已上线 📱"
            ]
        }
    }
}

class NotificationManager {
    static let shared = NotificationManager()
    
    private let center = UNUserNotificationCenter.current()
    
    private enum Keys {
        static let reminderEnabled = "reminderEnabled"
        static let reminderHour = "reminderHour"
        static let reminderMinute = "reminderMinute"
        static let reminderStyle = "reminderStyle"
        static let weekendDND = "weekendDND"
    }
    
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.reminderEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.reminderEnabled) }
    }
    
    var hour: Int {
        get { UserDefaults.standard.object(forKey: Keys.reminderHour) as? Int ?? 21 }
        set { UserDefaults.standard.set(newValue, forKey: Keys.reminderHour) }
    }
    
    var minute: Int {
        get { UserDefaults.standard.object(forKey: Keys.reminderMinute) as? Int ?? 0 }
        set { UserDefaults.standard.set(newValue, forKey: Keys.reminderMinute) }
    }
    
    var style: ReminderStyle {
        get {
            if let raw = UserDefaults.standard.string(forKey: Keys.reminderStyle),
               let s = ReminderStyle(rawValue: raw) {
                return s
            }
            return .warm
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.reminderStyle) }
    }
    
    var isWeekendDND: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.weekendDND) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.weekendDND) }
    }
    
    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            return false
        }
    }
    
    func scheduleReminder() {
        center.removePendingNotificationRequests(withIdentifiers: ["daily_reminder"])
        
        guard isEnabled else { return }
        
        let triggers = generateWorkdayTriggers(hour: hour, minute: minute, daysAhead: 14)
        
        for (index, trigger) in triggers.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "🦫 小满提醒你记账啦"
            content.body = style.messages[index % style.messages.count]
            content.sound = .default
            
            let request = UNNotificationRequest(
                identifier: "daily_reminder_\(index)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }
    
    func cancelReminder() {
        center.removePendingNotificationRequests(withIdentifiers: ["daily_reminder"])
        center.removePendingNotificationRequests(withIdentifiers: (0..<14).map { "daily_reminder_\($0)" })
    }
    
    func generateWorkdayTriggers(hour: Int, minute: Int, daysAhead: Int) -> [UNCalendarNotificationTrigger] {
        var triggers: [UNCalendarNotificationTrigger] = []
        let calendar = Calendar.current
        let now = Date()
        
        // 检查今天的提醒时间是否还没到
        var todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
        todayComponents.hour = hour
        todayComponents.minute = minute
        
        if let todayTarget = calendar.date(from: todayComponents), todayTarget > now {
            // 今天还没到提醒时间，添加今天的触发器
            if !(isWeekendDND && Self.isWeekend(date: now)) {
                let trigger = UNCalendarNotificationTrigger(dateMatching: todayComponents, repeats: false)
                triggers.append(trigger)
            }
        }
        
        // 从明天开始生成剩余天数的触发器
        var date = now
        for _ in 0..<daysAhead {
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            
            if isWeekendDND && Self.isWeekend(date: date) {
                continue
            }
            
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = hour
            components.minute = minute
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            triggers.append(trigger)
        }
        
        return triggers
    }
    
    static func isWeekend(date: Date) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }
    
    // MARK: - 预算预警推送
    
    private enum BudgetKeys {
        static let pushEnabled = "budget_push_enabled"
        static let passiveEnabled = "budget_passive_enabled"
        static func passiveLastDate(for projectID: UUID) -> String {
            "budget_passive_last_\(projectID.uuidString)"
        }
    }
    
    var isBudgetPushEnabled: Bool {
        get { UserDefaults.standard.object(forKey: BudgetKeys.pushEnabled) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: BudgetKeys.pushEnabled) }
    }
    
    var isBudgetPassiveEnabled: Bool {
        get { UserDefaults.standard.object(forKey: BudgetKeys.passiveEnabled) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: BudgetKeys.passiveEnabled) }
    }
    
    /// 记账触发型：schedule 5min 后推送
    func scheduleBudgetAlertPush(projectID: UUID, alerts: [BudgetAlertTrigger]) {
        guard isBudgetPushEnabled else { return }
        
        let identifier = "budget_alert_\(projectID.uuidString)"
        
        // 取消旧的同类推送
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        
        let content = UNMutableNotificationContent()
        content.title = "🦫 小满提醒你"
        content.sound = .default
        
        if alerts.count == 1 {
            content.body = alerts[0].message
        } else {
            let count = alerts.count
            content.body = "「\(alerts[0].projectName)」有 \(count) 个预算需要注意，进来看看？"
        }
        
        // 5分钟后触发
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 300, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        center.add(request)
    }
    
    /// 用户回前台时取消待发推送
    func cancelPendingBudgetPush(projectID: UUID) {
        let identifier = "budget_alert_\(projectID.uuidString)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    /// 被动扫描型：App 启动时 pre-schedule 未来 7 天
    func schedulePassiveBudgetChecks(projects: [Project]) {
        guard isBudgetPassiveEnabled else { return }
        
        // 取消旧的被动推送
        let identifiers = (0..<7).map { "budget_passive_\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        
        let calendar = Calendar.current
        let now = Date()
        
        // 检查是否有需要提醒的项目
        var alertProjects: [Project] = []
        for project in projects {
            guard project.budget > 0, !project.isArchived else { continue }
            
            // 检查24小时内是否有记账
            let lastDate = UserDefaults.standard.object(forKey: BudgetKeys.passiveLastDate(for: project.id)) as? Date
            if let lastDate = lastDate,
               now.timeIntervalSince(lastDate) < 86400 {
                continue
            }
            
            let progress = project.budgetProgress
            if progress >= project.budgetAlertThreshold || progress >= 0.9 {
                alertProjects.append(project)
            }
        }
        
        guard !alertProjects.isEmpty else { return }
        
        // 选择最紧急的项目
        let sortedProjects = alertProjects.sorted { $0.budgetProgress > $1.budgetProgress }
        let primaryProject = sortedProjects[0]
        
        // 生成未来7天的推送
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = 10
            components.minute = 0
            
            let content = UNMutableNotificationContent()
            content.title = "🦫 小满提醒你查看一下"
            
            let progress = Int(primaryProject.budgetProgress * 100)
            if primaryProject.budgetProgress >= 1.0 {
                content.body = "「\(primaryProject.name)」预算已超标 \(progress - 100)%，进来看看？"
            } else {
                content.body = "「\(primaryProject.name)」预算已用到 \(progress)%，进来看看？"
            }
            
            if sortedProjects.count > 1 {
                content.body += "另有 \(sortedProjects.count - 1) 个项目需关注"
            }
            
            content.sound = .default
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            
            let request = UNNotificationRequest(
                identifier: "budget_passive_\(dayOffset)",
                content: content,
                trigger: trigger
            )
            
            center.add(request)
        }
    }
    
    /// 更新项目的最后记账时间
    func updatePassiveLastDate(for projectID: UUID) {
        UserDefaults.standard.set(Date(), forKey: BudgetKeys.passiveLastDate(for: projectID))
    }
}
