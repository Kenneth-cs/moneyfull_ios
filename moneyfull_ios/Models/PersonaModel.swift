import SwiftUI

// MARK: - Q1 记账习惯
enum HabitTag: String, CaseIterable {
    case none       = "habit_none"
    case lapsed     = "habit_lapsed"
    case sometimes  = "habit_sometimes"
    case daily      = "habit_daily"
    case consistent = "habit_consistent"

    var score: Int {
        switch self {
        case .none:       return 0
        case .lapsed:     return 12
        case .sometimes:  return 20
        case .daily:      return 32
        case .consistent: return 40
        }
    }
}

// MARK: - Q2 记录方法
enum MethodTag: String, CaseIterable {
    case none       = "method_none"
    case paymentApp = "method_payment_app"
    case excel      = "method_excel"
    case otherApp   = "method_other_app"
    case handwrite  = "method_handwrite"

    var score: Int {
        switch self {
        case .none:       return 5
        case .paymentApp: return 15
        case .handwrite:  return 20
        case .excel:      return 25
        case .otherApp:   return 28
        }
    }
}

// MARK: - Q3 收入来源
enum IncomeTag: String, CaseIterable {
    case salary    = "income_salary"
    case freelance = "income_freelance"
    case multi     = "income_multi"
    case student   = "income_student"

    var score: Int {
        switch self {
        case .freelance: return 18
        case .multi:     return 20
        case .student:   return 25
        case .salary:    return 30
        }
    }
}

// MARK: - Q4 JTBD 意图
enum JTBDTag: String, CaseIterable {
    case ease       = "jtbd_ease"
    case insight    = "jtbd_insight"
    case roi        = "jtbd_roi"
    case budget     = "jtbd_budget"
    case importData = "jtbd_import"

    var dashboardCTA: String {
        switch self {
        case .ease:       return "先翻转手机，试试背面双击记账"
        case .insight:    return "先记录今天的支出，看看分布"
        case .roi:        return "先建一个你正在进行的项目"
        case .budget:     return "先设一个本月的生活费预算"
        case .importData: return "先从 Excel 或其他 App 导入账单"
        }
    }
}

// MARK: - 用户画像类型
enum PersonaType: String, CaseIterable {
    case earner     = "persona_earner"
    case efficiency = "persona_efficiency"
    case moonlight  = "persona_moonlight"
    case dataDriven = "persona_datadriven"
    case steady     = "persona_steady"

    var letter: String {
        switch self {
        case .earner:     return "A"
        case .efficiency: return "B"
        case .moonlight:  return "C"
        case .dataDriven: return "D"
        case .steady:     return "E"
        }
    }

    var displayName: String {
        switch self {
        case .earner:     return "项目创收者"
        case .efficiency: return "效率优先者"
        case .moonlight:  return "月光规划师"
        case .dataDriven: return "数据控进阶者"
        case .steady:     return "稳健积累者"
        }
    }

    var personaImageName: String {
        switch self {
        case .earner:     return "persona_a"
        case .efficiency: return "persona_b"
        case .moonlight:  return "persona_c"
        case .dataDriven: return "persona_d"
        case .steady:     return "persona_e"
        }
    }

    var capybaraImageName: String {
        switch self {
        case .earner:     return "capybara_a"
        case .efficiency: return "capybara_b"
        case .moonlight:  return "capybara_c"
        case .dataDriven: return "capybara_d"
        case .steady:     return "capybara_e"
        }
    }

    var emoji: String {
        switch self {
        case .earner:     return "📊"
        case .efficiency: return "⚡"
        case .moonlight:  return "🎯"
        case .dataDriven: return "📈"
        case .steady:     return "🌱"
        }
    }

    var accentColor: Color { Color(hex: "#2C6957") }

    // MARK: 卡片文案
    var headline: String { "你是「\(displayName)」" }

    func description(income: IncomeTag) -> String {
        switch self {
        case .earner:
            if income == .multi {
                return "工资是底，副业是变量——\n但每个月算下来，副业到底赚了多少？\n\n小满帮你把两本账分开管，\n看清每一块收入的真实价值。"
            }
            return "收入靠接单，钱不固定，项目多了\n很难说清楚哪个赚了、哪个在亏。\n\n你需要的不是记流水，\n而是看清每个项目的真实回报。"
        case .efficiency:
            return "你知道记账有用，你试过，\n但每次打开 App 的那一秒，你放弃了。\n不是你不行——是工具不对。\n\n小满有一个功能是专门为你设计的。"
        case .moonlight:
            return "不是不想存钱，是每次看到余额\n都比预想的少。\n不是记账记漏了，是没人提醒你快超了。\n\n小满会在你还来得及的时候告诉你。"
        case .dataDriven:
            return "你已经在认真记账了，\n但你知道光有数据还不够。\n数字背后是什么模式？哪里可以优化？\n\n小满帮你从「记下来」跨越到「看出来」。"
        case .steady:
            return "收入稳定，但总是「钱没了，\n也不知道花在哪」。\n你不需要多复杂的功能，\n你需要的是一套真正坚持得下去的记账方式。\n\n小满帮你做到这件事：简单，但每天都能用。"
        }
    }

    func healthScoreNote(income: IncomeTag) -> String {
        switch self {
        case .earner:
            return "你的分数主要受收入不规律影响，这不是你的问题，而是这类收入结构的特点。\n\nROI 分析能帮你把不确定性变成可量化的数据。"
        case .efficiency:
            return "你曾经认真记过账，这说明你真正理解它的价值——这是最难的一步。\n\n现在只差一个不需要「打开 App」的工具。"
        case .moonlight:
            return "收入稳定是很大的优势，你已经赢在了起点。\n\n建立预警系统之后，这个分数会明显提升。"
        case .dataDriven:
            return "你的习惯分很高，这是最难养成的部分你已经做到了。\n\n现在是时候让这些数据为你工作了。"
        case .steady:
            return "收入稳定本身就是一个很大的优势。\n\n建立记录习惯之后，你会比大多数人更快看到财务改善。"
        }
    }

    var painPoint: String {
        switch self {
        case .earner:     return "知道接了多少钱，但搞不清实际利润"
        case .efficiency: return "打开 App 这个动作本身是最大障碍"
        case .moonlight:  return "事后才发现超支，改不了"
        case .dataDriven: return "有数据但缺分析洞察"
        case .steady:     return "记账坚持不下来，缺少动力"
        }
    }

    var bottomQuote: String {
        switch self {
        case .earner:     return "看清每个项目的真实回报，才能让每一次接单都更有价值。"
        case .efficiency: return "记账不应该打断生活，而应该融入生活。"
        case .moonlight:  return "每一次及时提醒，都是你离存下钱更近一步。"
        case .dataDriven: return "数据不只是记录过去，更用来指导更好的未来。"
        case .steady:     return "坚持记账，不是为了记住每一笔钱，而是为了过上自己想要的生活。"
        }
    }

    var dashboardGuide: String {
        switch self {
        case .earner:     return "先建一个你现在正在进行的接单项目\n它会告诉你这个单子到底赚了多少"
        case .efficiency: return "先试试翻转手机双击背面\n体验一次你就知道为什么这次能坚持下去"
        case .moonlight:  return "先设一个本月生活费预算\n小满会在你快超标时提前提醒你"
        case .dataDriven: return "先导入你现有的账单数据\n或直接开始记录，小满会帮你分析规律"
        case .steady:     return "今天先记第一笔\n坚持 7 天，看看你的钱都去哪了"
        }
    }

    // MARK: 功能推荐列表
    func featureRecommendations(method: MethodTag) -> [FeatureRecommendation] {
        switch self {
        case .earner:
            return [
                FeatureRecommendation(number: "01", sfSymbol: "chart.bar.doc.horizontal", name: "项目 ROI 分析看板", isPro: true,
                                      description: "为每个接单项目单独建账本，小满帮你算时间成本、总收入、实际利润", screenshotName: "feat_roi_dashboard"),
                FeatureRecommendation(number: "02", sfSymbol: "tray.2.fill", name: "无限项目抽屉", isPro: true,
                                      description: "每个合同、每个客户都有独立账本，不混账", screenshotName: "feat_project_drawer"),
                FeatureRecommendation(number: "03", sfSymbol: "mic.fill", name: "AI 语音记账", isPro: false,
                                      description: "在外跑单时说一句话就能记，不打断工作节奏", screenshotName: "feat_voice_entry"),
                FeatureRecommendation(number: "04", sfSymbol: "bell.badge.fill", name: "财务预警", isPro: false,
                                      description: "某个项目成本快超了，提前提醒你", screenshotName: "feat_alert"),
            ]
        case .efficiency:
            return [
                FeatureRecommendation(number: "01", sfSymbol: "hand.tap.fill", name: "双击手机背面极速记账", isPro: true,
                                      description: "不需要解锁，不需要打开 App，翻过手机双击背面，0.3 秒记好", screenshotName: "feat_back_tap"),
                FeatureRecommendation(number: "02", sfSymbol: "mic.fill", name: "AI 语音记账", isPro: true,
                                      description: "说一句话就完成，出门在外不需要停下来操作", screenshotName: "feat_voice_entry"),
                FeatureRecommendation(number: "03", sfSymbol: "waveform", name: "Siri 快捷指令", isPro: true,
                                      description: "嘿 Siri，记一笔 → 完成", screenshotName: "feat_siri"),
                FeatureRecommendation(number: "04", sfSymbol: "bell.fill", name: "智能记账提醒", isPro: true,
                                      description: "小满会在你消费后提醒你记账，不靠自律靠系统", screenshotName: "feat_smart_reminder"),
            ]
        case .moonlight:
            return [
                FeatureRecommendation(number: "01", sfSymbol: "bell.badge.fill", name: "超支预警 / 预算设置", isPro: true,
                                      description: "设一个本月生活费上限，小满在你花到 80% 的时候提醒你", screenshotName: "feat_alert"),
                FeatureRecommendation(number: "02", sfSymbol: "hand.tap.fill", name: "双击背面极速记账", isPro: true,
                                      description: "每笔消费 0.3 秒记下来，不给自己找借口不记", screenshotName: "feat_back_tap"),
                FeatureRecommendation(number: "03", sfSymbol: "chart.bar.xaxis", name: "首页看板实时支出", isPro: true,
                                      description: "随时能看本月花了多少，不用等月底算账", screenshotName: "feat_dashboard_live"),
                FeatureRecommendation(number: "04", sfSymbol: "bubble.left.fill", name: "AI 聊天记账", isPro: false,
                                      description: "餐后说一句「刚才吃饭花了68」，小满帮你记好", screenshotName: "feat_voice_entry"),
            ]
        case .dataDriven:
            if method == .excel || method == .otherApp {
                return [
                    FeatureRecommendation(number: "01", sfSymbol: "square.and.arrow.down.fill", name: "账单导入", isPro: false,
                                          description: "把你在 Excel / 其他 App 的数据一键迁移，不用重新开始", screenshotName: "feat_import"),
                    FeatureRecommendation(number: "02", sfSymbol: "chart.xyaxis.line", name: "全维度统计看板", isPro: false,
                                          description: "导入后自动生成分类趋势、环比对比，比 Excel 更直观", screenshotName: "feat_analytics"),
                    FeatureRecommendation(number: "03", sfSymbol: "chart.bar.doc.horizontal", name: "项目 ROI 分析", isPro: true,
                                          description: "多个支出维度，直接看哪个回报最高", screenshotName: "feat_roi_dashboard"),
                    FeatureRecommendation(number: "04", sfSymbol: "square.and.arrow.up.fill", name: "数据导出", isPro: false,
                                          description: "数据永远属于你，随时可以导回 Excel", screenshotName: "feat_export"),
                ]
            }
            return [
                FeatureRecommendation(number: "01", sfSymbol: "chart.xyaxis.line", name: "全维度统计看板（Analytics）", isPro: false,
                                      description: "分类趋势、环比对比、支出占比，全部自动生成", screenshotName: "feat_analytics"),
                FeatureRecommendation(number: "02", sfSymbol: "square.and.arrow.down.fill", name: "账单导入", isPro: false,
                                      description: "把你现有的 Excel 数据一键导入，不用重新开始", screenshotName: "feat_import"),
                FeatureRecommendation(number: "03", sfSymbol: "chart.bar.doc.horizontal", name: "项目 ROI 分析", isPro: true,
                                      description: "如果你有多个支出项目，直接看哪个回报最高", screenshotName: "feat_roi_dashboard"),
                FeatureRecommendation(number: "04", sfSymbol: "square.and.arrow.up.fill", name: "数据导出", isPro: false,
                                      description: "支持导出到 Excel，你的数据永远属于你", screenshotName: "feat_export"),
            ]
        case .steady:
            return [
                FeatureRecommendation(number: "01", sfSymbol: "hand.tap.fill", name: "双击背面极速记账", isPro: false,
                                      description: "养成习惯最难的地方是打开 App，翻面就记，门槛降到最低", screenshotName: "feat_back_tap"),
                FeatureRecommendation(number: "02", sfSymbol: "pawprint.fill", name: "卡皮健康度系统", isPro: false,
                                      description: "你每天记账，小满就会变得越来越精神；停了它就蔫了", screenshotName: "feat_capybara_health"),
                FeatureRecommendation(number: "03", sfSymbol: "bell.fill", name: "预算提醒", isPro: false,
                                      description: "设一个月度生活费目标，小满帮你守住", screenshotName: "feat_alert"),
                FeatureRecommendation(number: "04", sfSymbol: "calendar.badge.clock", name: "每月账单回顾", isPro: false,
                                      description: "月底自动生成消费总结，看一眼就够了", screenshotName: "feat_monthly_review"),
            ]
        }
    }
}

// MARK: - 功能推荐项
struct FeatureRecommendation: Identifiable {
    let id = UUID()
    let number: String
    let sfSymbol: String
    let name: String
    let isPro: Bool
    let description: String
    let screenshotName: String
}

// MARK: - 健康分分段文案
struct HealthScoreLabel {
    let label: String
    let description: String

    static func from(score: Int) -> HealthScoreLabel {
        switch score {
        case 0..<40:
            return .init(label: "财务萌新", description: "还没有建立财务感知，从零开始没关系，重要的是迈出第一步")
        case 40..<60:
            return .init(label: "财务摸索期", description: "有意识但还缺少工具和习惯，小满正好能帮你建立这套系统")
        case 60..<80:
            return .init(label: "财务觉醒者", description: "已经有一定基础，小满帮你从「记下来」跨越到「看清楚」")
        default:
            return .init(label: "财务掌控者", description: "习惯和意识都不错，小满帮你把效率再推高一层")
        }
    }
}

// MARK: - 测评引擎
struct AssessmentEngine {

    static func calculateHealthScore(habit: HabitTag, method: MethodTag, income: IncomeTag) -> Int {
        return habit.score + method.score + income.score
    }

    static func determinePersona(habit: HabitTag, method: MethodTag, income: IncomeTag) -> PersonaType {
        if income == .freelance || income == .multi {
            return .earner
        }
        if habit == .lapsed {
            return .efficiency
        }
        if (habit == .none || habit == .sometimes) && (income == .salary || income == .student) {
            return .moonlight
        }
        if (habit == .daily || habit == .consistent) && (income == .salary || income == .student) {
            return .dataDriven
        }
        return .steady
    }

    static func saveToUserDefaults(persona: PersonaType, healthScore: Int, habit: HabitTag, method: MethodTag, income: IncomeTag, jtbd: JTBDTag) {
        let ud = UserDefaults.standard
        ud.set(persona.rawValue,         forKey: "userPersonaType")
        ud.set(persona.displayName,      forKey: "userPersonaName")
        ud.set(healthScore,              forKey: "userHealthScore")
        ud.set(jtbd.rawValue,            forKey: "userJTBDChoice")
        ud.set(income.rawValue,          forKey: "userIncomeType")
        ud.set(method.rawValue,          forKey: "userRecordMethod")
        ud.set(Date(),                   forKey: "userPersonaSetDate")
        ud.set(true,                     forKey: "hasCompletedAssessment")
    }
}
