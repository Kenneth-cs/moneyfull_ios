import SwiftUI

// MARK: - 测评主视图
struct AssessmentView: View {
    var onComplete: (PersonaType, Int, HabitTag, MethodTag, IncomeTag, JTBDTag) -> Void

    @State private var currentStep = 0
    @State private var selectedHabit: HabitTag?
    @State private var selectedMethod: MethodTag?
    @State private var selectedIncome: IncomeTag?
    @State private var selectedJTBD: JTBDTag?

    private let green      = Color(hex: "#2C6957")
    private let lightGreen = Color(hex: "#A8E6CF")
    private let bgGreen    = Color(hex: "#EBF7F2")
    private let totalSteps = 4

    private var currentSelectionTag: String? {
        switch currentStep {
        case 0: return selectedHabit?.rawValue
        case 1: return selectedMethod?.rawValue
        case 2: return selectedIncome?.rawValue
        case 3: return selectedJTBD?.rawValue
        default: return nil
        }
    }

    private var canProceed: Bool { currentSelectionTag != nil }

    var body: some View {
        // 两段式布局：上方绿色区（固定高度）+ 下方白色区（自适应）
        VStack(spacing: 0) {
            greenZone
            whiteZone
        }
        .background(bgGreen.ignoresSafeArea())
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - 上方绿色区（标题 + 进度 + 插画）
    private var greenZone: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题
            Text("让小满定制你的记账体验")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color(hex: "#1A3A2E"))
                .padding(.horizontal, 24)
                .padding(.top, 20)

            // 进度行
            HStack(spacing: 10) {
                Text("\(currentStep + 1) / \(totalSteps) 题")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(green)
                    .monospacedDigit()

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(lightGreen.opacity(0.35)).frame(height: 6)
                        Capsule().fill(green)
                            .frame(width: geo.size.width * CGFloat(currentStep + 1) / CGFloat(totalSteps),
                                   height: 6)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStep)
                    }
                }
                .frame(height: 6)
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)

            // 插画区：两张图贴底对齐，各占左右
            Spacer(minLength: 8)

            HStack(alignment: .bottom, spacing: 0) {
                Image("quiz_calendar")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 8)

                Image("quiz_kapi")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160)
                    .padding(.trailing, 0)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 220)     // 绿色区固定高度
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bgGreen)
    }

    // MARK: - 下方白色区（题目卡 + 底栏）
    private var whiteZone: some View {
        VStack(spacing: 0) {
            // 题目内容（带切换动画）
            questionContent
                .id(currentStep)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)
                    )
                )

            Spacer(minLength: 0)

            // 底栏
            bottomBar
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24,
                                          bottomLeadingRadius: 0,
                                          bottomTrailingRadius: 0,
                                          topTrailingRadius: 24))
        .shadow(color: green.opacity(0.08), radius: 16, x: 0, y: -4)
    }

    // MARK: - 题目内容（在白色区内）
    private var questionContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 题目标题 + 副标题
            VStack(alignment: .leading, spacing: 14) {
                Text(questions[currentStep].title)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(Color(hex: "#1A3A2E"))
                    .fixedSize(horizontal: false, vertical: true)

                Text(questions[currentStep].subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#1A3A2E").opacity(0.5))
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 18)

            Divider().opacity(0.1).padding(.horizontal, 20)

            // 选项列表
            VStack(spacing: 0) {
                ForEach(questions[currentStep].options) { option in
                    optionRow(option: option)
                    if option.id != questions[currentStep].options.last?.id {
                        Divider().opacity(0.08).padding(.horizontal, 20)
                    }
                }
            }
        }
    }

    // MARK: - 选项行（整行可点击，emoji 无背景框）
    private func optionRow(option: AssessmentOption) -> some View {
        let isSelected = currentSelectionTag == option.tag

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectOption(tag: option.tag)
            }
        } label: {
            HStack(spacing: 14) {
                Text(option.icon)
                    .font(.system(size: 22))
                    .frame(width: 32)

                Text(option.text)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? green : Color(hex: "#1A3A2E"))
                    .multilineTextAlignment(.leading)

                Spacer()

                ZStack {
                    Circle()
                        .stroke(isSelected ? green : Color(hex: "#CCCCCC"), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(green).frame(width: 12, height: 12)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            .background(isSelected ? green.opacity(0.05) : Color.clear)
            .contentShape(Rectangle())
            .animation(.easeInOut(duration: 0.18), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 底栏
    private var bottomBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 11))
                    .foregroundColor(green.opacity(0.55))
                Text("所有数据仅用于个性化推荐")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#1A3A2E").opacity(0.4))
            }
            Spacer()
            Button(action: goNext) {
                HStack(spacing: 6) {
                    Text(currentStep < totalSteps - 1 ? "下一题" : "查看结果")
                        .font(.system(size: 15, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 22).padding(.vertical, 12)
                .background(Capsule().fill(canProceed ? green : Color(hex: "#BBBBBB")))
            }
            .disabled(!canProceed)
            .animation(.easeInOut(duration: 0.2), value: canProceed)
        }
    }

    // MARK: - 选项选取 & 跳转
    private func selectOption(tag: String) {
        switch currentStep {
        case 0: selectedHabit  = HabitTag(rawValue: tag)
        case 1: selectedMethod = MethodTag(rawValue: tag)
        case 2: selectedIncome = IncomeTag(rawValue: tag)
        case 3: selectedJTBD   = JTBDTag(rawValue: tag)
        default: break
        }
    }

    private func goNext() {
        guard canProceed else { return }
        if currentStep < totalSteps - 1 {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                currentStep += 1
            }
        } else {
            finishAssessment()
        }
    }

    private func habitLabel(_ tag: HabitTag) -> String {
        switch tag {
        case .none:       return "一次都没记过"
        case .lapsed:     return "记过一段时间，后来放弃了"
        case .sometimes:  return "偶尔记一下"
        case .daily:      return "大多数天都有记"
        case .consistent: return "一直都有记录"
        }
    }

    private func methodLabel(_ tag: MethodTag) -> String {
        switch tag {
        case .none:       return "不记录"
        case .paymentApp: return "微信/支付宝账单"
        case .excel:      return "Excel/数字表格"
        case .otherApp:   return "其他记账App"
        case .handwrite:  return "手写/手帐"
        }
    }

    private func incomeLabel(_ tag: IncomeTag) -> String {
        switch tag {
        case .salary:    return "固定工资"
        case .freelance: return "自由职业/接单"
        case .multi:     return "工资+副业/多种收入"
        case .student:   return "学生/生活费固定"
        }
    }

    private func jtbdLabel(_ tag: JTBDTag) -> String {
        switch tag {
        case .ease:      return "更方便快捷地记账"
        case .insight:   return "看清钱都花去哪了"
        case .roi:       return "管理多个项目ROI"
        case .budget:    return "做预算，避免超支"
        case .importData: return "导入已有账单统一管理"
        }
    }

    private func finishAssessment() {
        guard let habit = selectedHabit,
              let method = selectedMethod,
              let income = selectedIncome,
              let jtbd = selectedJTBD else { return }
        let score   = AssessmentEngine.calculateHealthScore(habit: habit, method: method, income: income)
        let persona = AssessmentEngine.determinePersona(habit: habit, method: method, income: income)
        AssessmentEngine.saveToUserDefaults(persona: persona, healthScore: score,
                                            habit: habit, method: method, income: income, jtbd: jtbd)

        // V2.0 埋点：测评完成
        AnalyticsManager.shared.trackEvent(
            eventId: "assessment_completed",
            eventName: "测评完成",
            params: [
                "记账习惯": habitLabel(habit),
                "记录方法": methodLabel(method),
                "收入来源": incomeLabel(income),
                "核心诉求": jtbdLabel(jtbd),
                "健康分": score
            ]
        )

        // V2.0 埋点：画像生成
        AnalyticsManager.shared.trackEvent(
            eventId: "persona_generated",
            eventName: "画像生成",
            params: [
                "画像类型": persona.displayName,
                "画像字母": persona.letter,
                "健康分": score,
                "记账习惯": habitLabel(habit),
                "记录方法": methodLabel(method),
                "收入来源": incomeLabel(income),
                "核心诉求": jtbdLabel(jtbd)
            ]
        )

        onComplete(persona, score, habit, method, income, jtbd)
    }
}

// MARK: - 题目数据模型
struct AssessmentQuestion: Identifiable {
    let id: Int
    let title: String
    let typeBadge: String
    let subtitle: String
    let options: [AssessmentOption]
}

struct AssessmentOption: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
    let tag: String
}

// MARK: - 4 道题目数据
private let questions: [AssessmentQuestion] = [
    AssessmentQuestion(
        id: 0,
        title: "过去一周，你的记账情况是？",
        typeBadge: "行为题",
        subtitle: "没有对错，只是想知道从哪里开始帮你。",
        options: [
            AssessmentOption(icon: "📱", text: "一次都没记过",           tag: HabitTag.none.rawValue),
            AssessmentOption(icon: "💔", text: "记过一段时间，后来放弃了", tag: HabitTag.lapsed.rawValue),
            AssessmentOption(icon: "📝", text: "偶尔记一下",             tag: HabitTag.sometimes.rawValue),
            AssessmentOption(icon: "📊", text: "大多数天都有记",          tag: HabitTag.daily.rawValue),
            AssessmentOption(icon: "🗂️", text: "一直都有记录",           tag: HabitTag.consistent.rawValue),
        ]
    ),
    AssessmentQuestion(
        id: 1,
        title: "你现在主要用什么方式记录消费？",
        typeBadge: "方法题",
        subtitle: "了解你现在的工具，才能知道小满能从哪里帮到你。",
        options: [
            AssessmentOption(icon: "🚫", text: "不记录",             tag: MethodTag.none.rawValue),
            AssessmentOption(icon: "📱", text: "微信 / 支付宝账单",   tag: MethodTag.paymentApp.rawValue),
            AssessmentOption(icon: "📊", text: "Excel / 数字表格",   tag: MethodTag.excel.rawValue),
            AssessmentOption(icon: "📲", text: "其他记账 App",        tag: MethodTag.otherApp.rawValue),
            AssessmentOption(icon: "✍️", text: "手写 / 手帐",         tag: MethodTag.handwrite.rawValue),
        ]
    ),
    AssessmentQuestion(
        id: 2,
        title: "你的主要收入来源是？",
        typeBadge: "收入题",
        subtitle: "不同收入结构，管钱的方式完全不一样。",
        options: [
            AssessmentOption(icon: "🏢", text: "固定工资",             tag: IncomeTag.salary.rawValue),
            AssessmentOption(icon: "💼", text: "自由职业 / 接单",       tag: IncomeTag.freelance.rawValue),
            AssessmentOption(icon: "🚀", text: "工资 + 副业 / 多种收入", tag: IncomeTag.multi.rawValue),
            AssessmentOption(icon: "🎓", text: "学生 / 生活费固定",     tag: IncomeTag.student.rawValue),
        ]
    ),
    AssessmentQuestion(
        id: 3,
        title: "如果小满只能先帮你做一件事，你最希望是哪件？",
        typeBadge: "意图题",
        subtitle: "你来决定第一步。",
        options: [
            AssessmentOption(icon: "⚡", text: "更方便快捷地记账（无痛记账）", tag: JTBDTag.ease.rawValue),
            AssessmentOption(icon: "🔍", text: "看清钱都花去哪了",       tag: JTBDTag.insight.rawValue),
            AssessmentOption(icon: "📊", text: "管理多个项目 ROI",       tag: JTBDTag.roi.rawValue),
            AssessmentOption(icon: "🎯", text: "做预算，避免超支",        tag: JTBDTag.budget.rawValue),
            AssessmentOption(icon: "📥", text: "导入已有账单统一管理",    tag: JTBDTag.importData.rawValue),
        ]
    ),
]

#Preview {
    AssessmentView { _, _, _, _, _, _ in }
}
