import SwiftUI

/// 主题偏好：跟随系统 / 强制浅色 / 强制深色
enum ThemeMode: String, CaseIterable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"
    
    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light:  return "浅色模式"
        case .dark:   return "深色模式"
        }
    }
    
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.stars.fill"
        }
    }
    
    /// 转换为 SwiftUI 的 ColorScheme（nil = 跟随系统）
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

/// 全局主题管理器（ObservableObject，注入到 App 根节点）
class ThemeManager: ObservableObject {
    private let key = "themeMode"
    
    @Published var mode: ThemeMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: key)
        }
    }
    
    init() {
        let raw = UserDefaults.standard.string(forKey: "themeMode") ?? ThemeMode.light.rawValue
        mode = ThemeMode(rawValue: raw) ?? .light
    }
    
    var colorScheme: ColorScheme? { mode.colorScheme }
}

// MARK: - 数据埋点管理器
class AnalyticsManager {
    static let shared = AnalyticsManager()
    
    private let projectId = "cmo9qaxjq0002wpz0k7spw409"
    private let apiKey = "cplt_02a1149fa805ba4a1a43b928a2d974816e106bc094b3fa1c98bc460e27e16917"
    // 不管本地测试还是线上，都统一上传到生产环境
    private let endpoint = "https://www.superindividual.originapex.cn/api/events"
    
    private init() {}
    
    func trackEvent(eventId: String, eventName: String, params: [String: Any]? = nil) {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        let body: [String: Any] = [
            "projectId": projectId,
            "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            "eventId": eventId,
            "eventName": eventName,
            "params": params ?? [:],
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            "osVersion": UIDevice.current.systemVersion,
            "occurredAt": formatter.string(from: Date())
        ]
        
        guard let url = URL(string: endpoint) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: req) { data, response, error in
            #if DEBUG
            if let error = error {
                print("Analytics trackEvent failed: \(error.localizedDescription)")
            } else if let httpResponse = response as? HTTPURLResponse {
                if !(200...299).contains(httpResponse.statusCode) {
                    print("Analytics trackEvent failed with status code: \(httpResponse.statusCode)")
                } else {
                    print("Analytics trackEvent success: \(eventId)")
                }
            }
            #endif
        }.resume()
    }
    
    // MARK: - 金额脱敏辅助
    
    /// 将金额转为脱敏区间字符串
    func amountLevel(_ amount: Double) -> String {
        switch abs(amount) {
        case 0..<100:      return "under100"
        case 100..<500:    return "100to500"
        case 500..<2000:   return "500to2000"
        case 2000..<10000: return "2000to10000"
        default:           return "over10000"
        }
    }
    
    /// 将金额转为预算金额区间字符串
    func budgetAmountLevel(_ amount: Double) -> String {
        switch amount {
        case 0..<1000:     return "under1k"
        case 1000..<3000:  return "1kto3k"
        case 3000..<6000:  return "3kto6k"
        case 6000..<10000: return "6kto10k"
        default:           return "over10k"
        }
    }
    
    /// 将成员数转为区间字符串
    func memberCountLevel(_ count: Int) -> String {
        switch count {
        case 2...3: return "2-3"
        case 4...6: return "4-6"
        default:    return "7+"
        }
    }
    
    /// 将新增条数转为区间字符串
    func syncCountLevel(_ count: Int) -> String {
        switch count {
        case 0:     return "0"
        case 1...5: return "1-5"
        case 6...20: return "6-20"
        default:    return "20+"
        }
    }
}

// MARK: - V3.0 共享记账埋点
extension AnalyticsManager {
    
    // ── 共享项目管理 ──
    
    func trackSharedProjectCreateClick() {
        trackEvent(eventId: "shared_project_create_click", eventName: "点击创建共享项目")
    }
    
    func trackSharedProjectCreateSuccess(projectNameLength: Int) {
        let length: String
        switch projectNameLength {
        case 0...4:  length = "short"
        case 5...10: length = "medium"
        default:     length = "long"
        }
        trackEvent(eventId: "shared_project_create_success", eventName: "创建共享项目成功",
                    params: ["project_name_length": length])
    }
    
    func trackSharedProjectCreateFail(errorType: String) {
        trackEvent(eventId: "shared_project_create_fail", eventName: "创建共享项目失败",
                    params: ["error_type": errorType])
    }
    
    func trackSharedProjectJoinClick() {
        trackEvent(eventId: "shared_project_join_click", eventName: "点击加入共享项目")
    }
    
    func trackSharedProjectJoinSuccess(memberCount: Int) {
        trackEvent(eventId: "shared_project_join_success", eventName: "加入共享项目成功",
                    params: ["member_count": memberCountLevel(memberCount)])
    }
    
    func trackSharedProjectJoinFail(errorType: String) {
        trackEvent(eventId: "shared_project_join_fail", eventName: "加入共享项目失败",
                    params: ["error_type": errorType])
    }
    
    func trackSharedProjectViewDetail(memberCount: Int) {
        trackEvent(eventId: "shared_project_view_detail", eventName: "查看共享项目详情",
                    params: ["member_count": memberCountLevel(memberCount)])
    }
    
    func trackSharedProjectLeave(isCreator: Bool) {
        trackEvent(eventId: "shared_project_leave", eventName: "退出共享项目",
                    params: ["is_creator": isCreator])
    }
    
    // ── 共享记账操作 ──
    
    func trackSharedRecordClickAdd() {
        trackEvent(eventId: "shared_record_click_add", eventName: "点击共享记一笔")
    }
    
    func trackSharedRecordSubmitSuccess(amount: Double, category: String, participantsCount: Int) {
        trackEvent(eventId: "shared_record_submit_success", eventName: "共享记账成功",
                    params: [
                        "amount_level": amountLevel(amount),
                        "category": category,
                        "participants_count": participantsCount
                    ])
    }
    
    func trackSharedRecordSubmitFail(errorType: String) {
        trackEvent(eventId: "shared_record_submit_fail", eventName: "共享记账失败",
                    params: ["error_type": errorType])
    }
    
    func trackSharedRecordSync(newCount: Int) {
        trackEvent(eventId: "shared_record_sync", eventName: "同步共享流水",
                    params: ["new_count": syncCountLevel(newCount)])
    }
    
    // ── 邀请与分享（共享项目）──
    
    func trackSharedInviteViewPanel(source: String) {
        trackEvent(eventId: "shared_invite_view_panel", eventName: "查看邀请面板",
                    params: ["source": source])
    }
    
    func trackSharedInviteCopyCode() {
        trackEvent(eventId: "shared_invite_copy_code", eventName: "复制邀请码")
    }
    
    func trackSharedInviteShare(shareMethod: String) {
        trackEvent(eventId: "shared_invite_share", eventName: "分享共享邀请",
                    params: ["share_method": shareMethod])
    }
}

// MARK: - V3.0 预算日历埋点
extension AnalyticsManager {
    
    func trackBudgetClickSetup(source: String, hasExisting: Bool) {
        trackEvent(eventId: "budget_click_setup", eventName: "点击设置预算",
                    params: ["source": source, "has_existing": hasExisting])
    }
    
    func trackBudgetSetupSuccess(amount: Double) {
        trackEvent(eventId: "budget_setup_success", eventName: "设置预算成功",
                    params: ["amount_level": budgetAmountLevel(amount)])
    }
    
    func trackBudgetRemove() {
        trackEvent(eventId: "budget_remove", eventName: "移除预算")
    }
    
    func trackBudgetCalendarTabSwitch() {
        trackEvent(eventId: "budget_calendar_tab_switch", eventName: "切换到预算日历")
    }
    
    func trackBudgetCalendarMonthNavigate(direction: String, isCurrentMonth: Bool) {
        trackEvent(eventId: "budget_calendar_month_navigate", eventName: "日历翻月",
                    params: ["direction": direction, "is_current_month": isCurrentMonth])
    }
    
    func trackBudgetCalendarDayClick(isToday: Bool, hasExpense: Bool, isOverDailyBudget: Bool) {
        trackEvent(eventId: "budget_calendar_day_click", eventName: "点击日历某天",
                    params: [
                        "is_today": isToday,
                        "has_expense": hasExpense,
                        "is_over_daily_budget": isOverDailyBudget
                    ])
    }
    
    func trackBudgetPaceView(paceStatus: String) {
        trackEvent(eventId: "budget_pace_view", eventName: "查看节奏状态",
                    params: ["pace_status": paceStatus])
    }
}

// MARK: - V3.0 分享功能埋点
extension AnalyticsManager {
    
    /// 个人项目分享海报 — 点击分享按钮
    func trackShareProjectPosterClick(projectMode: String) {
        trackEvent(eventId: "share_project_poster_click", eventName: "点击个人项目分享",
                    params: ["project_mode": projectMode])
    }
    
    /// 个人项目分享海报 — 海报生成成功
    func trackShareProjectPosterSuccess(projectMode: String) {
        trackEvent(eventId: "share_project_poster_success", eventName: "海报生成成功",
                    params: ["project_mode": projectMode])
    }
    
    /// 个人项目分享海报 — 分享完成
    func trackShareProjectPosterShared(shareMethod: String) {
        trackEvent(eventId: "share_project_poster_shared", eventName: "海报分享完成",
                    params: ["share_method": shareMethod])
    }
    
    /// 共享项目 — 点击分享按钮
    func trackShareSharedProjectClick() {
        trackEvent(eventId: "share_shared_project_click", eventName: "点击共享项目分享")
    }
    
    /// 共享项目 — 分享完成
    func trackShareSharedProjectShared(shareMethod: String) {
        trackEvent(eventId: "share_shared_project_shared", eventName: "共享项目分享完成",
                    params: ["share_method": shareMethod])
    }
}
