import SwiftUI
import UIKit

// MARK: - Hex 解析扩展
extension Color {
    /// 从十六进制字符串创建颜色（支持 #RGB / #RRGGBB / #AARRGGBB）
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red:     Double(r) / 255,
                  green:   Double(g) / 255,
                  blue:    Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - 动态颜色工具（自动适配深色 / 浅色模式）
extension UIColor {
    /// 创建一个自动在 Light / Dark 模式间切换的 UIColor
    static func dynamic(light: String, dark: String) -> UIColor {
        UIColor(dynamicProvider: { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(hex: dark)
                : UIColor(hex: light)
        })
    }

    /// 从十六进制字符串创建 UIColor
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch hex.count {
        case 3:  (r, g, b, a) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17, 255)
        case 6:  (r, g, b, a) = (int >> 16, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8:  (r, g, b, a) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF, int >> 24)
        default: (r, g, b, a) = (0, 0, 0, 255)
        }
        self.init(red:   CGFloat(r) / 255,
                  green: CGFloat(g) / 255,
                  blue:  CGFloat(b) / 255,
                  alpha: CGFloat(a) / 255)
    }
}

// MARK: - 应用色板（Light ↔ Dark 自动切换）
extension Color {
    struct App {
        // ── 绿色系 ──────────────────────────────────────
        /// 主绿（背景/卡片强调），Dark: 深墨绿
        static let primaryGreen   = Color(uiColor: .dynamic(light: "#A8E6CF", dark: "#1E4D3A"))
        /// 深绿（主要文字/图标），Dark: 薄荷绿
        static let darkGreen      = Color(uiColor: .dynamic(light: "#2C6957", dark: "#6FCFA8"))
        /// 浅绿（浅背景/装饰），Dark: 深绿底
        static let lightGreen     = Color(uiColor: .dynamic(light: "#DCEDC1", dark: "#2A3D20"))

        // ── 橙色系 ──────────────────────────────────────
        /// 浅橙（Tag 背景/卡片），Dark: 深棕橙底
        static let lightOrange    = Color(uiColor: .dynamic(light: "#FDD1B4", dark: "#4A2510"))
        /// 深橙（强调文字），Dark: 柔和橙
        static let darkOrange     = Color(uiColor: .dynamic(light: "#D97736", dark: "#FFB07A"))
        /// 深橙褐（Tag 文字），Dark: 奶油橙
        static let darkOrangeBrown = Color(uiColor: .dynamic(light: "#795841", dark: "#E8C4A0"))

        // ── 黄色系 ──────────────────────────────────────
        /// 浅黄（装饰/归档 Tag），Dark: 深黄底
        static let lightYellow    = Color(uiColor: .dynamic(light: "#DCDE8D", dark: "#35370A"))
        /// 深黄（归档文字），Dark: 亮黄
        static let darkYellow     = Color(uiColor: .dynamic(light: "#5F621F", dark: "#C8CA5A"))

        // ── 中性色 ──────────────────────────────────────
        /// 主文字色，Dark: 近白
        static let textBlack      = Color(uiColor: .dynamic(light: "#1A1C1C", dark: "#E6E8E8"))
        /// 页面底色，Dark: 深灰黑
        static let backgroundGray = Color(uiColor: .dynamic(light: "#F9F9F9", dark: "#111314"))
        /// Tab / 输入框背景，Dark: 深卡片色
        static let tabBackground  = Color(uiColor: .dynamic(light: "#F3F3F3", dark: "#1F2223"))

        // ── 功能色 ──────────────────────────────────────
        /// 金额输入框背景，Dark: 深橄榄
        static let amountBg       = Color(uiColor: .dynamic(light: "#E5E796", dark: "#2E3000"))
        /// 支出红，Dark: 柔和红
        static let redExpense     = Color(uiColor: .dynamic(light: "#BA1A1A", dark: "#FFB4AB"))
        
        /// 卡片白（Light: 白色，Dark: 深卡片灰）
        static let cardBackground = Color(uiColor: .dynamic(light: "#FFFFFF", dark: "#1C1F20"))
        /// 分割线 / 描边，Dark: 深描边
        static let divider        = Color(uiColor: .dynamic(light: "#E8E8E8", dark: "#2A2D2E"))
    }
}
