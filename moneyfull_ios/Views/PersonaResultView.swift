import SwiftUI

// MARK: - 画像结果页
struct PersonaResultView: View {
    let persona: PersonaType
    let healthScore: Int
    let habit: HabitTag
    let method: MethodTag
    let income: IncomeTag
    let jtbd: JTBDTag
    var onFinish: () -> Void

    @State private var animateScore = false
    @State private var displayedScore = 0
    @State private var showContent = false

    private let green      = Color(hex: "#2C6957")
    private let lightGreen = Color(hex: "#A8E6CF")
    private let bgGreen    = Color(hex: "#EBF7F2")

    /// 健康分：优先用传入值，为0时从 UserDefaults 读取（防止 ContentView 状态传递时序问题）
    private var effectiveScore: Int {
        healthScore > 0 ? healthScore : max(UserDefaults.standard.integer(forKey: "userHealthScore"), 0)
    }

    /// 画像：优先用传入值，若为默认值且已完成测评则从 UserDefaults 读取（同上时序保护）
    private var effectivePersona: PersonaType {
        if persona != .steady { return persona }
        guard UserDefaults.standard.bool(forKey: "hasCompletedAssessment"),
              let saved = UserDefaults.standard.string(forKey: "userPersonaType"),
              let type = PersonaType(rawValue: saved) else { return persona }
        return type
    }

    private var scoreLabel: HealthScoreLabel { HealthScoreLabel.from(score: effectiveScore) }
    private var features: [FeatureRecommendation] { effectivePersona.featureRecommendations(method: method) }

    var body: some View {
        GeometryReader { geo in
            let topInset    = geo.safeAreaInsets.top
            let bottomInset = geo.safeAreaInsets.bottom
            let imageWidth  = min(geo.size.width * 0.38, 148.0)

            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        heroSection(topInset: topInset, imageWidth: imageWidth)
                        healthScoreSection
                        painPointSection
                        featureSection
                        quoteSection
                        Color.clear.frame(height: 148)
                    }
                }
                .ignoresSafeArea()

                // 固定底部按钮
                startButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, max(bottomInset + 8, 28))
                    .background(
                        LinearGradient(colors: [bgGreen.opacity(0), bgGreen],
                                       startPoint: .top, endPoint: .bottom)
                        .frame(height: 120)
                        .ignoresSafeArea()
                    )
            }
        }
        // GeometryReader 本身不 ignoresSafeArea，这样 safeAreaInsets 才能正确读取
        // 背景色在这里单独延伸到屏幕边缘
        .background(bgGreen.ignoresSafeArea())
        .onAppear { startAnimations() }
    }

    // MARK: - Hero 区（人物插画 + 标题 + 描述）
    private func heroSection(topInset: CGFloat, imageWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // 白色背景卡
            Color.white

            // 淡叶子背景装饰
            Image(systemName: "leaf.fill")
                .font(.system(size: 120))
                .foregroundColor(lightGreen.opacity(0.12))
                .rotationEffect(.degrees(-20))
                .offset(x: -20, y: 60)

            VStack(alignment: .leading, spacing: 0) {
                // 字母标签条：顶部 padding 根据安全区动态计算
                HStack(spacing: 8) {
                    Text(effectivePersona.letter)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(green)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    Text(effectivePersona.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(green)
                }
                .padding(.horizontal, 20)
                .padding(.top, topInset + 16)

                // 内容行：文案 + 人物图（imageWidth 由外层 GeometryReader 计算传入）
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(effectivePersona.headline)
                            .font(.system(size: 26, weight: .heavy))
                            .foregroundColor(Color(hex: "#1A3A2E"))
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)

                        Text(effectivePersona.description(income: income))
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color(hex: "#1A3A2E").opacity(0.75))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.leading, 20)
                    .padding(.top, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(effectivePersona.personaImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: imageWidth)
                        .offset(y: -10)
                }

                Color.clear.frame(height: 20)
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.easeOut(duration: 0.5).delay(0.1), value: showContent)
    }

    // MARK: - 健康分区
    private var healthScoreSection: some View {
        HStack(spacing: 16) {
            // 圆形分数
            VStack(spacing: 12) {
                Text("财务健康分")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(green.opacity(0.8))

                ZStack {
                    Circle()
                        .stroke(lightGreen.opacity(0.3), lineWidth: 6)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: animateScore ? CGFloat(effectiveScore) / 100.0 : 0)
                        .stroke(green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 1.2), value: animateScore)

                    Text("\(displayedScore)")
                        .font(.system(size: 30, weight: .heavy))
                        .foregroundColor(green)
                        .monospacedDigit()
                }

                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 14))
                    .foregroundColor(green.opacity(0.6))
            }
            .frame(width: 90)

            // 说明文案
            VStack(alignment: .leading, spacing: 6) {
                Text(scoreLabel.label)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(green)
                Text(effectivePersona.healthScoreNote(income: income))
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#1A3A2E").opacity(0.75))
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 卡皮图
            Image(effectivePersona.capybaraImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 72)
                .offset(y: -4)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: green.opacity(0.06), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.easeOut(duration: 0.5).delay(0.2), value: showContent)
    }

    // MARK: - 核心痛点条
    private var painPointSection: some View {
        HStack(spacing: 12) {
            // 图标徽章
            ZStack {
                Circle()
                    .fill(green)
                    .frame(width: 36, height: 36)
                Image(systemName: "target")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text("你的核心痛点")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(green)
                .fixedSize()

            Text(effectivePersona.painPoint)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#1A3A2E"))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: green.opacity(0.05), radius: 8, x: 0, y: 3)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.easeOut(duration: 0.5).delay(0.3), value: showContent)
    }

    // MARK: - 功能推荐区（每个功能独立卡片，截图在下方横版展示）
    private var featureSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 标题行
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#F0B429"))
                Text("为你优先推荐")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(hex: "#1A3A2E"))
                Text("(按展示优先级)")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#1A3A2E").opacity(0.45))
                Spacer()
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundColor(lightGreen)
            }
            .padding(.bottom, 2)

            ForEach(features) { feat in
                featureCard(feat: feat)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.easeOut(duration: 0.5).delay(0.4), value: showContent)
    }

    /// 每个功能独立卡片：上方信息行 + 下方横版截图
    private func featureCard(feat: FeatureRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 上方信息行
            HStack(spacing: 12) {
                // 编号 + 圆形图标
                VStack(spacing: 3) {
                    Text(feat.number)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(green.opacity(0.6))
                    ZStack {
                        Circle()
                            .fill(lightGreen.opacity(0.3))
                            .frame(width: 40, height: 40)
                        Image(systemName: feat.sfSymbol)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(green)
                    }
                }

                // 名称 + Pro + 描述
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(feat.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#1A3A2E"))
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                        if feat.isPro {
                            Text("Pro")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(
                                    LinearGradient(colors: [Color(hex: "#4CAF50"), green],
                                                   startPoint: .leading, endPoint: .trailing)
                                )
                                .clipShape(Capsule())
                        }
                    }
                    Text(feat.description)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#1A3A2E").opacity(0.55))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#CCCCCC"))
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // 下方横版截图（420×240 比例，scaledToFit 保持完整不裁切）
            Image(feat.screenshotName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(lightGreen.opacity(0.25), lineWidth: 1)
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 14)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: green.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    // MARK: - 底部金句
    private var quoteSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "quote.opening")
                .font(.system(size: 16))
                .foregroundColor(lightGreen)

            Text(effectivePersona.bottomQuote)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "#1A3A2E").opacity(0.6))
                .italic()
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 20))
                .foregroundColor(green.opacity(0.4))
        }
        .padding(.horizontal, 20).padding(.vertical, 18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: green.opacity(0.04), radius: 8, x: 0, y: 3)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.easeOut(duration: 0.5).delay(0.5), value: showContent)
    }

    // MARK: - 开始使用按钮
    private var startButton: some View {
        Button(action: onFinish) {
            HStack(spacing: 8) {
                Text("开始使用小满")
                    .font(.system(size: 17, weight: .heavy))
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#4CAF50"), Color(hex: "#2C6957")],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: Color(hex: "#2C6957").opacity(0.35), radius: 14, x: 0, y: 7)
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.6), value: showContent)
    }

    // MARK: - 动画启动
    private func startAnimations() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            showContent = true
            animateScore = true

            let target = effectiveScore
            guard target > 0 else {
                displayedScore = 0
                return
            }
            // 分数滚动动画：从0到目标分数，共30帧
            let duration = 1.2
            let steps = 30
            let interval = duration / Double(steps)
            for i in 0...steps {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * interval) {
                    displayedScore = Int(Double(target) * Double(i) / Double(steps))
                    // 最后一帧确保精确
                    if i == steps { displayedScore = target }
                }
            }
        }
    }
}

#Preview {
    PersonaResultView(
        persona: .earner,
        healthScore: 68,
        habit: .lapsed,
        method: .otherApp,
        income: .freelance,
        jtbd: .roi,
        onFinish: {}
    )
}
