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
