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

// MARK: - 项目模式卡片

struct ProjectModeCard: View {
    let mode: ProjectMode
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.system(size: 14, weight: .bold))
                Text(mode.title)
                    .font(.system(size: 15, weight: .heavy))
            }
            Text(mode.subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)
            Text(mode.description)
                .font(.system(size: 11))
                .foregroundColor(.gray)
        }
        .foregroundColor(isSelected ? Color.App.darkGreen : Color.App.textBlack)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(isSelected ? Color.App.primaryGreen.opacity(0.18) : Color.App.tabBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? Color.App.darkGreen : Color.clear, lineWidth: 1.5))
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

// MARK: - 智能图标推荐（三级兜底）

/// 获取分类图标：AI返回值 > 名称智能推荐 > 默认图标
func getCategoryIcon(icon: String?, name: String) -> String {
    if let icon = icon, !icon.isEmpty {
        return icon
    }
    return suggestCategoryIcon(for: name)
}

/// 获取分类颜色：AI返回值 > 名称智能推荐 > 默认颜色
func getCategoryColor(color: String?, name: String) -> String {
    if let color = color, !color.isEmpty, color != "#A8E0C2" {
        return color
    }
    return suggestCategoryColor(for: name)
}

/// 根据分类名称推荐图标
func suggestCategoryIcon(for categoryName: String) -> String {
    let name = categoryName.lowercased()
    
    // 交通出行
    if name.contains("交通") || name.contains("出行") || name.contains("打车") || name.contains("滴滴") { return "car.fill" }
    if name.contains("地铁") || name.contains("公交") { return "tram.fill" }
    if name.contains("飞机") || name.contains("机票") || name.contains("航空") { return "airplane" }
    if name.contains("火车") || name.contains("高铁") { return "train.side.front.car" }
    if name.contains("加油") || name.contains("油费") { return "fuelpump.fill" }
    if name.contains("停车") { return "parkingsign" }
    
    // 餐饮美食
    if name.contains("餐饮") || name.contains("吃饭") || name.contains("正餐") || name.contains("外卖") { return "fork.knife" }
    if name.contains("咖啡") || name.contains("奶茶") || name.contains("饮料") { return "cup.and.saucer.fill" }
    if name.contains("早餐") { return "sunrise.fill" }
    if name.contains("晚餐") || name.contains("夜宵") { return "moon.fill" }
    if name.contains("水果") { return "leaf.fill" }
    if name.contains("零食") || name.contains("小吃") { return "birthday.cake.fill" }
    
    // 购物消费
    if name.contains("购物") || name.contains("超市") || name.contains("商场") { return "cart.fill" }
    if name.contains("衣服") || name.contains("服装") || name.contains("穿搭") { return "tshirt.fill" }
    if name.contains("数码") || name.contains("电子") || name.contains("手机") { return "smartphone" }
    if name.contains("家具") || name.contains("家居") { return "sofa.fill" }
    if name.contains("家电") || name.contains("电器") { return "tv.fill" }
    if name.contains("日用") || name.contains("百货") { return "bag.fill" }
    
    // 居住相关
    if name.contains("房租") || name.contains("租金") || name.contains("住房") { return "house.fill" }
    if name.contains("水电") || name.contains("物业") || name.contains("燃气") { return "bolt.fill" }
    if name.contains("装修") || name.contains("建材") { return "hammer.fill" }
    if name.contains("网费") || name.contains("宽带") { return "wifi" }
    
    // 娱乐休闲
    if name.contains("娱乐") || name.contains("游戏") { return "gamecontroller.fill" }
    if name.contains("电影") || name.contains("影院") { return "film.fill" }
    if name.contains("音乐") || name.contains("会员") { return "music.note" }
    if name.contains("健身") || name.contains("运动") || name.contains("锻炼") { return "figure.run" }
    if name.contains("旅行") || name.contains("旅游") || name.contains("度假") { return "airplane" }
    if name.contains("景点") || name.contains("门票") { return "ticket.fill" }
    
    // 医疗健康
    if name.contains("医疗") || name.contains("看病") || name.contains("医院") { return "cross.case.fill" }
    if name.contains("药品") || name.contains("药费") { return "pill.fill" }
    if name.contains("体检") || name.contains("保健") { return "heart.text.square.fill" }
    if name.contains("牙齿") || name.contains("口腔") { return "mouth.fill" }
    
    // 教育学习
    if name.contains("教育") || name.contains("学习") || name.contains("培训") { return "book.fill" }
    if name.contains("书籍") || name.contains("图书") { return "books.vertical.fill" }
    if name.contains("课程") || name.contains("网课") { return "person.fill.checkmark" }
    
    // 社交人情
    if name.contains("社交") || name.contains("聚会") || name.contains("聚餐") { return "person.3.fill" }
    if name.contains("礼物") || name.contains("礼品") { return "gift.fill" }
    if name.contains("红包") || name.contains("份子") { return "envelope.fill" }
    
    // 金融理财
    if name.contains("投资") || name.contains("理财") || name.contains("基金") { return "chart.line.uptrend.xyaxis" }
    if name.contains("保险") { return "shield.fill" }
    if name.contains("还贷") || name.contains("贷款") || name.contains("房贷") { return "building.columns.fill" }
    
    // 通讯网络
    if name.contains("通讯") || name.contains("话费") || name.contains("流量") { return "phone.fill" }
    
    // 宠物相关
    if name.contains("宠物") || name.contains("猫") || name.contains("狗") { return "pawprint.fill" }
    
    // 美容护肤
    if name.contains("美容") || name.contains("护肤") || name.contains("化妆") { return "sparkles" }
    if name.contains("理发") || name.contains("美发") { return "scissors" }
    
    // 兜底默认
    return "tag.fill"
}

/// 根据分类名称推荐颜色
func suggestCategoryColor(for categoryName: String) -> String {
    let name = categoryName.lowercased()
    
    // 交通出行 - 蓝色系
    if name.contains("交通") || name.contains("出行") || name.contains("打车") ||
       name.contains("地铁") || name.contains("公交") || name.contains("飞机") ||
       name.contains("火车") || name.contains("高铁") || name.contains("加油") {
        return "#5B9BD5"
    }
    
    // 餐饮美食 - 橙色系
    if name.contains("餐饮") || name.contains("吃饭") || name.contains("正餐") ||
       name.contains("咖啡") || name.contains("奶茶") || name.contains("早餐") ||
       name.contains("晚餐") || name.contains("水果") || name.contains("外卖") {
        return "#F4A460"
    }
    
    // 购物消费 - 粉色系
    if name.contains("购物") || name.contains("超市") || name.contains("衣服") ||
       name.contains("数码") || name.contains("家具") || name.contains("家电") {
        return "#E8A0BF"
    }
    
    // 居住相关 - 绿色系
    if name.contains("房租") || name.contains("水电") || name.contains("物业") ||
       name.contains("装修") || name.contains("建材") {
        return "#7BC67E"
    }
    
    // 娱乐休闲 - 紫色系
    if name.contains("娱乐") || name.contains("游戏") || name.contains("电影") ||
       name.contains("音乐") || name.contains("健身") || name.contains("旅行") {
        return "#9B72CF"
    }
    
    // 医疗健康 - 红色系
    if name.contains("医疗") || name.contains("药品") || name.contains("体检") ||
       name.contains("牙齿") {
        return "#E67E7E"
    }
    
    // 教育学习 - 深蓝色
    if name.contains("教育") || name.contains("学习") || name.contains("书籍") ||
       name.contains("课程") {
        return "#4A7FB5"
    }
    
    // 社交人情 - 金色
    if name.contains("社交") || name.contains("礼物") || name.contains("红包") {
        return "#D4A76A"
    }
    
    // 金融理财 - 深绿色
    if name.contains("投资") || name.contains("理财") || name.contains("保险") ||
       name.contains("还贷") {
        return "#2E8B57"
    }
    
    // 默认颜色
    return "#A8E0C2"
}
