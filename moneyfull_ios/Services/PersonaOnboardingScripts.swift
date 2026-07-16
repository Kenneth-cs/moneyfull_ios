import Foundation

// MARK: - 数据结构

enum OnboardingCTAAction {
    case showBackTapSetup       // B/E画像：无痛记账授权
    case requestNotification    // C画像：通知权限
}

struct OnboardingMessageConfig {
    let text: String
    let animationItems: [String]?   // 非nil时显示配置动画
    let imageName: String?          // Assets.xcassets 图片名
    let ctaAction: OnboardingCTAAction?
    let delayBeforeShow: TimeInterval
}

// MARK: - 预制文案脚本

enum PersonaOnboardingScript {

    static func messages(for persona: PersonaType) -> [OnboardingMessageConfig] {
        switch persona {
        case .earner:      return earnerMessages
        case .efficiency:  return efficiencyMessages
        case .moonlight:   return moonlightMessages
        case .dataDriven:  return dataDrivenMessages
        case .steady:      return steadyMessages
        }
    }

    // MARK: A - 项目创收者

    private static let earnerMessages: [OnboardingMessageConfig] = [
        .init(
            text: "🎉 欢迎来到钱小满！\n\n根据你的测试，你属于「**项目创收者**」\n\n小满来帮你配置一下，只需要**3秒**",
            animationItems: ["创建默认项目", "创建分类", "创建预算配置", "配置语音记账", "开启利润统计"],
            imageName: nil,
            ctaAction: nil,
            delayBeforeShow: 0
        ),
        .init(
            text: "已经准备好了\n\n以后你所有的**收入和支出**，都会**自动进入日常项目（你也可以创建新的项目喔～）**",
            animationItems: nil,
            imageName: "onboarding_result_earner",
            ctaAction: nil,
            delayBeforeShow: 3.0
        ),
        .init(
            text: "你只需要开始记账，后续就能看到对应的 **ROI**\n\n也可以直接对我说：「**帮我建一个摄影接单的项目**」，或者点击下方「**无痛记账**」按钮设置快捷记账\n\n有任何问题，小满一直在这里陪着你喔～",
            animationItems: nil,
            imageName: nil,
            ctaAction: nil,
            delayBeforeShow: 3.5
        )
    ]

    // MARK: B - 效率优先者

    private static let efficiencyMessages: [OnboardingMessageConfig] = [
        .init(
            text: "🎉 欢迎来到钱小满！\n\n根据你的测试，你属于「**效率优先者**」\n\n对你来说，记账越快越好。小满帮你开启**极速记账模式**，只需**3秒**",
            animationItems: ["开启语音记账", "开启截图识别", "开启无痛记账", "配置默认项目", "准备完成"],
            imageName: nil,
            ctaAction: nil,
            delayBeforeShow: 0
        ),
        .init(
            text: "已经准备好了\n\n点击下方「**设置无痛记账**」按钮设置快捷记账\n\n以后**不用打开 App**，一句话、一张截图、一条语音，小满都能帮你记好",
            animationItems: nil,
            imageName: "onboarding_result_efficiency",
            ctaAction: .showBackTapSetup,
            delayBeforeShow: 3.0
        ),
        .init(
            text: "可以直接对我说：「**刚刚喝咖啡 28元**」\n\n或者通过**快捷键识别支付宝截图**，小满会自动完成记账\n\n越记越快，这才是你的记账方式",
            animationItems: nil,
            imageName: nil,
            ctaAction: nil,
            delayBeforeShow: 3.5
        )
    ]

    // MARK: C - 月光规划师

    private static let moonlightMessages: [OnboardingMessageConfig] = [
        .init(
            text: "🎉 欢迎来到钱小满！\n\n根据你的测试，你属于「**月光规划师**」\n\n你不是不会赚钱，只是花钱时少了一个提醒。小满帮你建立**预算守护**，只需**3秒**",
            animationItems: ["创建日常项目", "配置超支提醒", "开启每日预算", "配置消息提醒", "准备完成"],
            imageName: nil,
            ctaAction: nil,
            delayBeforeShow: 0
        ),
        .init(
            text: "已经准备好了\n\n以后每天还能花多少，小满会提前告诉你——不是花完以后，而是在**快超的时候提醒你**",
            animationItems: nil,
            imageName: "onboarding_result_moonlight",
            ctaAction: nil,
            delayBeforeShow: 3.0
        ),
        .init(
            text: "每消费一笔，预算会**自动更新**，随时都有数，不用等到月底算账\n\n如果快超预算，小满会**第一时间提醒你**\n\n也可以对我说：「**帮我看看在日常项目里开销最大部分是什么**」",
            animationItems: nil,
            imageName: nil,
            ctaAction: .requestNotification,
            delayBeforeShow: 3.5
        )
    ]

    // MARK: D - 数据控进阶者

    private static let dataDrivenMessages: [OnboardingMessageConfig] = [
        .init(
            text: "🎉 欢迎来到钱小满！\n\n根据你的测试，你属于「**数据控进阶者**」。\n\n你更想知道：钱到底去哪了，小满帮你建立**专属分析空间**，只需**3秒**～",
            animationItems: ["创建消费分析", "建立分类模型", "初始化趋势分析", "准备AI报告", "完成"],
            imageName: nil,
            ctaAction: nil,
            delayBeforeShow: 0
        ),
        .init(
            text: "已经准备好了。\n\n以后每记一笔，小满都会帮你分析，月底不用自己看数据，我直接告诉你**哪里花得值**、**哪里还能优化**",
            animationItems: nil,
            imageName: "onboarding_result_datadriven",
            ctaAction: nil,
            delayBeforeShow: 3.0
        ),
        .init(
            text: "记满**第一个月**，小满会自动生成属于你的**第一份消费分析**\n\n也可以直接问我：「**帮我分析一下最近为什么花这么多？**」\n\n剩下的，交给我～",
            animationItems: nil,
            imageName: nil,
            ctaAction: nil,
            delayBeforeShow: 3.5
        )
    ]

    // MARK: E - 稳健积累者

    private static let steadyMessages: [OnboardingMessageConfig] = [
        .init(
            text: "🎉 欢迎来到钱小满！\n\n根据你的测试，你属于「**稳健积累者**」\n\n你在意的不是少花一点，而是**慢慢实现自己的目标**，小满帮你准备好成长计划，只需**3秒**～",
            animationItems: ["开启极速记账", "激活卡皮健康系统", "设置每日提醒", "开启月度回顾", "准备完成"],
            imageName: nil,
            ctaAction: nil,
            delayBeforeShow: 0
        ),
        .init(
            text: "已经准备好了\n\n点击下方**无痛记账**按钮设置快捷记账\n\n以后只需要翻转手机、双击背面，**0.3 秒**记好一笔，不靠意志力，靠的是**门槛足够低**",
            animationItems: nil,
            imageName: "onboarding_result_steady",
            ctaAction: .showBackTapSetup,
            delayBeforeShow: 3.0
        ),
        .init(
            text: "每天坚持记，小满身上的卡皮会越来越精神\n\n也可以直接说：「**刚才买咖啡 28元**」\n\n慢慢来，**坚持才是你的超能力**",
            animationItems: nil,
            imageName: nil,
            ctaAction: nil,
            delayBeforeShow: 3.5
        )
    ]
}
