import SwiftUI

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

// MARK: - 应用色板（与原设计稿完全一致）
extension Color {
    struct App {
        // ── 绿色系
        static let primaryGreen    = Color(hex: "#A8E6CF")
        static let darkGreen       = Color(hex: "#2C6957")
        static let lightGreen      = Color(hex: "#DCEDC1")

        // ── 橙色系
        static let lightOrange     = Color(hex: "#FDD1B4")
        static let darkOrange      = Color(hex: "#D97736")
        static let darkOrangeBrown = Color(hex: "#795841")

        // ── 黄色系
        static let lightYellow     = Color(hex: "#DCDE8D")
        static let darkYellow      = Color(hex: "#5F621F")

        // ── 中性色
        static let textBlack       = Color(hex: "#1A1C1C")
        static let backgroundGray  = Color(hex: "#F9F9F9")
        static let tabBackground   = Color(hex: "#F3F3F3")

        // ── 功能色
        static let amountBg        = Color(hex: "#E5E796")
        static let redExpense      = Color(hex: "#BA1A1A")
    }
}
