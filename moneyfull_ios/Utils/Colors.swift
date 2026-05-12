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

// MARK: - 动态颜色辅助函数
extension Color {
    /// 根据系统外观动态返回颜色
    static func dynamic(light: Color, dark: Color) -> Color {
        return Color(uiColor: UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }
}

// MARK: - 应用色板（与原设计稿完全一致）
extension Color {
    struct App {
        // ── 绿色系
        static let primaryGreen    = Color(hex: "#A8E6CF")
        static let darkGreen       = Color.dynamic(light: Color(hex: "#2C6957"), dark: Color(hex: "#63C7A1"))
        static let lightGreen      = Color(hex: "#DCEDC1")

        // ── 橙色系
        static let lightOrange     = Color(hex: "#FDD1B4")
        static let darkOrange      = Color.dynamic(light: Color(hex: "#D97736"), dark: Color(hex: "#FFB07A"))
        static let darkOrangeBrown = Color(hex: "#795841")

        // ── 黄色系
        static let lightYellow     = Color(hex: "#DCDE8D")
        static let darkYellow      = Color.dynamic(light: Color(hex: "#5F621F"), dark: Color(hex: "#D4D86A"))

        // ── 中性色
        static let textBlack       = Color.dynamic(light: Color(hex: "#1A1C1C"), dark: Color(hex: "#F5F5F5"))
        static let backgroundGray  = Color.dynamic(light: Color(hex: "#F9F9F9"), dark: Color(hex: "#000000"))
        static let tabBackground   = Color.dynamic(light: Color(hex: "#F3F3F3"), dark: Color(hex: "#1C1C1E"))

        // ── 功能色
        static let amountBg        = Color(hex: "#E5E796")
        static let redExpense      = Color.dynamic(light: Color(hex: "#BA1A1A"), dark: Color(hex: "#FF6B6B"))
        
        // ── 深色模式适配
        static let cardBackground  = Color.dynamic(light: Color.white, dark: Color(hex: "#1C1C1E"))
        
        // ── 语义色
        static let textOnPrimary   = Color.dynamic(light: Color(hex: "#2C6957"), dark: Color(hex: "#1A4034"))
        static let progressTrack   = Color.dynamic(light: Color(hex: "#F0F0F0"), dark: Color(hex: "#333333"))
        
        static func projectIconColor(for colorHex: String) -> Color {
            Color.dynamic(
                light: Color(hex: progressColorPair(for: colorHex).end),
                dark: Color(hex: colorHex)
            )
        }
        
        // ── 莫兰迪色盘（项目颜色）
        struct Morandi {
            // 原始 8 色
            static let mint        = Color(hex: "#A8E0C2")  // 薄荷绿
            static let mistBlue    = Color(hex: "#B3D1E6")  // 雾蓝
            static let apricot     = Color(hex: "#F6D7A8")  // 杏橙
            static let pink        = Color(hex: "#F2B7C6")  // 玫粉
            static let lavender    = Color(hex: "#D8C6E8")  // 薰衣草紫
            static let cyan        = Color(hex: "#BFE6EA")  // 浅青
            static let green       = Color(hex: "#C8E6C9")  // 浅绿
            static let beige       = Color(hex: "#DCCFC4")  // 米棕

            // 扩展 8 色
            static let warmAmber   = Color(hex: "#EDD9A3")  // 暖琥珀黄
            static let periwinkle  = Color(hex: "#C4B8E8")  // 矢车菊蓝紫
            static let dustyRose   = Color(hex: "#E8C2C2")  // 灰玫瑰
            static let sageMint    = Color(hex: "#B8D8C4")  // 鼠尾草绿
            static let softPeach   = Color(hex: "#F0D0B8")  // 柔桃橙
            static let powderBlue  = Color(hex: "#C8D4E8")  // 粉雾蓝
            static let dustyMauve  = Color(hex: "#D4C0D8")  // 灰藕紫
            static let paleSage    = Color(hex: "#D4E4D0")  // 淡灰绿

            static let allHexes: [String] = [
                // 冷色调
                "#A8E0C2", "#C8E6C9", "#BFE6EA", "#B8D8C4", "#D4E4D0",
                "#B3D1E6", "#C8D4E8",
                // 紫色调
                "#D8C6E8", "#C4B8E8", "#D4C0D8",
                // 暖色调
                "#F6D7A8", "#EDD9A3", "#F0D0B8",
                "#F2B7C6", "#E8C2C2",
                // 中性
                "#DCCFC4",
            ]
        }

        static let morandiColorOptions = Morandi.allHexes
    }
}

// MARK: - 自定义房子图形（替代 house.fill）

struct HouseIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let r = w * 0.12          // 墙底圆角半径

        var path = Path()

        // ── 屋顶峰
        path.move(to: CGPoint(x: w * 0.50, y: h * 0.04))

        // ── 右屋檐端 → 右肩（檐口内收）
        path.addLine(to: CGPoint(x: w * 0.97, y: h * 0.50))
        path.addLine(to: CGPoint(x: w * 0.85, y: h * 0.50))

        // ── 右墙：垂直到圆角起点
        path.addLine(to: CGPoint(x: w * 0.85, y: h * 0.96 - r))

        // ── 右下圆角
        path.addArc(
            center: CGPoint(x: w * 0.85 - r, y: h * 0.96 - r),
            radius: r,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )

        // ── 底边 → 左下圆角起点
        path.addLine(to: CGPoint(x: w * 0.15 + r, y: h * 0.96))

        // ── 左下圆角
        path.addArc(
            center: CGPoint(x: w * 0.15 + r, y: h * 0.96 - r),
            radius: r,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )

        // ── 左墙 → 左肩
        path.addLine(to: CGPoint(x: w * 0.15, y: h * 0.50))
        path.addLine(to: CGPoint(x: w * 0.03, y: h * 0.50))

        path.closeSubpath()

        // ── 拱形门洞（even-odd 挖空）
        let doorW = w * 0.26
        let doorH = h * 0.28
        let doorX = (w - doorW) * 0.5
        let doorY = h * 0.96 - doorH
        path.addRoundedRect(
            in: CGRect(x: doorX, y: doorY, width: doorW, height: doorH),
            cornerSize: CGSize(width: doorW * 0.50, height: doorH * 0.50),
            style: .continuous
        )

        return path
    }
}

/// SF Symbol 通用渲染，遇到 "house.fill" 自动切换为自定义矢量图形
struct AppIconView: View {
    let name: String
    let size: CGFloat
    let color: Color
    var weight: Font.Weight = .semibold

    var body: some View {
        if name == "house.fill" {
            HouseIconShape()
                .fill(color, style: FillStyle(eoFill: true))
                .frame(width: size, height: size)
        } else {
            Image(systemName: name)
                .font(.system(size: size, weight: weight))
                .foregroundColor(color)
        }
    }
}

// MARK: -

struct CategoryIconLibrary {
    static let all: [String] = [
        "fork.knife", "bag.fill", "tram.fill", "leaf.fill", "book.closed.fill",
        "ellipsis.circle.fill", "basket.fill", "leaf.circle.fill", "cup.and.saucer.fill",
        "popcorn.fill", "tshirt.fill", "takeoutbag.and.cup.and.straw.fill",
        "cart.fill", "figure.run", "gamecontroller.fill", "phone.fill",
        "sparkles", "building.2.fill", "banknote.fill", "house.fill",
        "person.2.fill", "gift.fill", "airplane", "wineglass.fill",
        "shippingbox.fill", "star.fill", "dice.fill", "desktopcomputer",
        "film.fill", "car.fill", "scooter", "fuelpump.fill",
        "cross.fill", "book.fill", "pawprint.fill", "drop.fill",
        "bolt.fill", "flame.fill", "figure.and.child.holdinghands", "person.fill",
        "key.fill", "briefcase.fill", "wrench.and.screwdriver.fill",
        "envelope.fill", "ticket.fill", "heart.fill", "arrow.left.arrow.right",
        "creditcard.fill", "arrow.up.forward.circle.fill", "paintbrush.fill", "washer.fill",
        "dollarsign.circle.fill", "clock.fill", "wallet.pass.fill",
        "star.circle.fill", "graduationcap.fill", "chart.pie.fill",
        "chart.line.uptrend.xyaxis", "arrow.uturn.backward", "arrow.down.circle.fill",
        "tag.fill", "rosette", "banknote", "square.grid.3x3.fill",
    ]

    static let project: [String] = [
        "folder.fill", "house.fill", "airplane", "car.fill",
        "cart.fill", "briefcase.fill", "heart.fill", "book.fill",
        "gamecontroller.fill", "paintbrush.fill", "wrench.and.screwdriver.fill", "graduationcap.fill",
        "star.fill", "gift.fill", "bag.fill", "pawprint.fill",
        "film.fill", "figure.run", "bolt.fill", "leaf.fill",
        "envelope.fill", "cross.fill", "fork.knife", "creditcard.fill",
    ]

    struct IconGroup {
        let name: String
        let icons: [String]
    }

    static let grouped: [IconGroup] = [
        IconGroup(name: "餐饮美食", icons: [
            "fork.knife", "cup.and.saucer.fill", "wineglass.fill",
            "takeoutbag.and.cup.and.straw.fill", "popcorn.fill",
        ]),
        IconGroup(name: "出行交通", icons: [
            "tram.fill", "car.fill", "scooter", "fuelpump.fill", "airplane",
        ]),
        IconGroup(name: "购物消费", icons: [
            "bag.fill", "cart.fill", "creditcard.fill", "banknote.fill",
            "shippingbox.fill", "tag.fill",
        ]),
        IconGroup(name: "居家生活", icons: [
            "house.fill", "basket.fill", "building.2.fill", "key.fill",
            "paintbrush.fill", "washer.fill", "wrench.and.screwdriver.fill",
        ]),
        IconGroup(name: "健康运动", icons: [
            "figure.run", "cross.fill", "drop.fill", "bolt.fill", "flame.fill",
            "pawprint.fill", "heart.fill",
        ]),
        IconGroup(name: "学习工作", icons: [
            "book.closed.fill", "book.fill", "graduationcap.fill",
            "briefcase.fill", "desktopcomputer", "phone.fill",
        ]),
        IconGroup(name: "娱乐社交", icons: [
            "gamecontroller.fill", "film.fill", "dice.fill",
            "person.2.fill", "gift.fill", "envelope.fill", "ticket.fill",
            "star.fill", "square.grid.3x3.fill",
        ]),
        IconGroup(name: "时尚美容", icons: [
            "tshirt.fill", "sparkles",
        ]),
        IconGroup(name: "财务收入", icons: [
            "dollarsign.circle.fill", "wallet.pass.fill", "chart.pie.fill",
            "chart.line.uptrend.xyaxis", "star.circle.fill", "clock.fill",
            "arrow.down.circle.fill", "arrow.uturn.backward",
        ]),
        IconGroup(name: "家人育儿", icons: [
            "figure.and.child.holdinghands", "person.fill",
        ]),
        IconGroup(name: "其他通用", icons: [
            "ellipsis.circle.fill", "leaf.fill", "leaf.circle.fill",
            "arrow.up.forward.circle.fill", "arrow.left.arrow.right",
            "rosette", "banknote",
        ]),
    ]
}
