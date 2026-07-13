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
            text: "🎉 欢迎来到钱小满\n\n根据你的测试\n你属于：\n「项目创收者」\n\n下面\n\n小满立刻帮你配置一下！\n\n只需要3秒。",
            animationItems: ["创建默认项目", "创建分类", "创建预算配置", "配置语音记账", "开启利润统计"],
            imageName: nil,
            ctaAction: nil,
            delayBeforeShow: 0
        ),
        .init(
            text: "已经准备好了。\n\n以后，\n你所有收入支出，\n都会自动进入项目。",
            animationItems: nil,
            imageName: "onboarding_result_earner",
            ctaAction: nil,
            delayBeforeShow: 3.0
        ),
        .init(
            text: "你只需要开始记账，后续就能看到对应的 ROI。\n\n你也可以直接对我说：\n\n\"帮我建一个摄影接单的项目，预算8000\"\n\n有任何问题，小满会一直在这陪着你喔～",
            animationItems: nil,
            imageName: nil,
            ctaAction: nil,
            delayBeforeShow: 2.5
        )
    ]

    // MARK: B - 效率优先者

    private static let efficiencyMessages: [OnboardingMessageConfig] = [
        .init(
            text: "🎉 欢迎来到钱小满\n\n根据你的测试\n你属于：\n「效率优先者」\n\n记账对你来说，\n\n越快越好。\n\n下面，\n\n小满帮你开启\n\n极速记账模式。\n\n只需要3秒。",
            animationItems: ["开启语音记账", "开启截图识别", "开启无痛记账", "配置默认分类", "准备完成"],
            imageName: nil,
            ctaAction: nil,
            delayBeforeShow: 0
        ),
        .init(
            text: "已经准备好了。\n\n以后，\n\n不用打开 App，\n\n一句话、\n\n一张截图、\n\n一条语音，\n\n小满都能帮你记好。",
            animationItems: nil,
            imageName: "onboarding_result_efficiency",
            ctaAction: .showBackTapSetup,
            delayBeforeShow: 3.0
        ),
        .init(
            text: "以后你可以直接对我说：\n\n\"刚刚喝咖啡28\"\n\n或者通过快捷键识别支付宝截图。\n\n小满会自动完成记账。\n\n越记越快，\n\n这才是你的记账方式。",
            animationItems: nil,
            imageName: nil,
            ctaAction: nil,
            delayBeforeShow: 2.5
        )
    ]

    // MARK: C - 月光规划师

    private static let moonlightMessages: [OnboardingMessageConfig] = [
        .init(
            text: "🎉 欢迎来到钱小满\n\n根据你的测试\n你属于：\n「月光规划师」\n\n你不是不会赚钱，\n\n只是花钱的时候\n\n少了一个提醒。\n\n下面，\n\n小满帮你建立\n\n预算守护。\n\n只需要3秒。",
            animationItems: ["创建生活预算", "设置超支提醒", "开启每日预算", "配置消息提醒", "准备完成"],
            imageName: nil,
            ctaAction: nil,
            delayBeforeShow: 0
        ),
        .init(
            text: "已经准备好了。\n\n以后，\n\n每天还能花多少钱，\n\n小满都会提前告诉你。\n\n不是花完以后，\n\n而是在快超的时候提醒你。",
            animationItems: nil,
            imageName: "onboarding_result_moonlight",
            ctaAction: nil,
            delayBeforeShow: 3.0
        ),
        .init(
            text: "每消费一笔，预算都会自动更新。\n\n以后每天心里都清楚：\n\n今天还能花多少，\n\n不是月底才算账，\n\n而是随时都有数。\n\n如果快超预算，小满会第一时间提醒你。\n\n你也可以对我说：\n\n\"帮我设一个本月餐饮预算1500\"",
            animationItems: nil,
            imageName: nil,
            ctaAction: .requestNotification,
            delayBeforeShow: 2.5
        )
    ]

    // MARK: D - 数据控进阶者

    private static let dataDrivenMessages: [OnboardingMessageConfig] = [
        .init(
            text: "🎉 欢迎来到钱小满\n\n根据你的测试\n你属于：\n「数据控进阶者」\n\n你更喜欢知道：\n\n钱到底去哪了。\n\n下面，\n\n小满帮你建立\n\n专属分析空间。\n\n只需要3秒。",
            animationItems: ["创建消费分析", "建立分类模型", "初始化趋势分析", "准备AI报告", "完成"],
            imageName: nil,
            ctaAction: nil,
            delayBeforeShow: 0
        ),
        .init(
            text: "已经准备好了。\n\n以后，\n\n每记一笔账，\n\n小满都会帮你分析。\n\n月底，\n\n你不用自己看数据。\n\n我直接告诉你：\n\n哪些地方花得最值，\n\n哪些地方还能优化。",
            animationItems: nil,
            imageName: "onboarding_result_datadriven",
            ctaAction: nil,
            delayBeforeShow: 3.0
        ),
        .init(
            text: "记满第一个月以后，\n\n小满会自动生成\n\n属于你的第一份消费分析。\n\n你也可以直接问：\n\n\"帮我分析一下最近为什么花这么多？\"\n\n剩下的，\n\n交给我。",
            animationItems: nil,
            imageName: nil,
            ctaAction: nil,
            delayBeforeShow: 2.5
        )
    ]

    // MARK: E - 稳健积累者

    private static let steadyMessages: [OnboardingMessageConfig] = [
        .init(
            text: "🎉 欢迎来到钱小满\n\n根据你的测试\n你属于：\n「稳健积累者」\n\n你在意的，\n\n不是少花一点。\n\n而是慢慢实现自己的目标。\n\n下面，\n\n小满帮你准备好\n\n成长计划。\n\n只需要3秒。",
            animationItems: ["开启极速记账", "激活卡皮健康系统", "设置每日提醒", "开启月度回顾", "准备完成"],
            imageName: nil,
            ctaAction: nil,
            delayBeforeShow: 0
        ),
        .init(
            text: "已经准备好了。\n\n以后，\n\n你只需要翻转手机，\n\n双击背面，\n\n0.3秒记好一笔。\n\n不靠意志力，\n\n靠的是门槛足够低。",
            animationItems: nil,
            imageName: "onboarding_result_steady",
            ctaAction: .showBackTapSetup,
            delayBeforeShow: 3.0
        ),
        .init(
            text: "每天坚持记，\n\n小满身上的卡皮\n\n会越来越精神。\n\n你也可以直接说：\n\n\"刚才买咖啡28块\"\n\n慢慢来，\n\n坚持才是你的超能力。",
            animationItems: nil,
            imageName: nil,
            ctaAction: nil,
            delayBeforeShow: 2.5
        )
    ]
}
