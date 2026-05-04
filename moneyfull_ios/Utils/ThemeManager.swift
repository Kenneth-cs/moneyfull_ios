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
        let raw = UserDefaults.standard.string(forKey: "themeMode") ?? ThemeMode.system.rawValue
        mode = ThemeMode(rawValue: raw) ?? .system
    }
    
    var colorScheme: ColorScheme? { mode.colorScheme }
}

// MARK: - 数据埋点管理器
class AnalyticsManager {
    static let shared = AnalyticsManager()
    
    private let projectId = "cmo9qaxjq0002wpz0k7spw409"
    private let apiKey = "cplt_02a1149fa805ba4a1a43b928a2d974816e106bc094b3fa1c98bc460e27e16917"
    // Debug：本地 Next.js；Release：正式域名（HTTPS）
    #if DEBUG
    private let endpoint = "http://localhost:3000/api/events"
    #else
    private let endpoint = "https://www.superindividual.youqukeji.cn/api/events"
    #endif
    
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
}
