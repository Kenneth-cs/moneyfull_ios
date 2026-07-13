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
}
