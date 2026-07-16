import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var store: AppStore?

    // MARK: - 首次用户流程状态
    /// true = 需要显示欢迎页（从未看过）
    @State private var showWelcome = !UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
    /// true = 正在进行测评流程
    @State private var showAssessment = false

    // MARK: - 测评内部步骤状态
    @State private var assessmentStep: AssessmentStep = .quiz
    @State private var assessmentPersona: PersonaType = .steady
    @State private var assessmentScore: Int = 0
    @State private var assessmentHabit: HabitTag = .none
    @State private var assessmentMethod: MethodTag = .none
    @State private var assessmentIncome: IncomeTag = .salary
    @State private var assessmentJTBD: JTBDTag = .ease
    @State private var loadingRotation: Double = 0

    @State private var deepLinkText: String?
    @State private var showRatingPrompt = false
    @State private var showLegacyGiftLetter = false
    @State private var pendingLegacyGiftLetter = false

    private enum AssessmentStep {
        case quiz, loading, result
    }

    var body: some View {
        Group {
            // 首次用户：欢迎页 → 测评，始终在最前，不在主页背后弹出
            if showWelcome || showAssessment {
                firstLaunchFlow
            } else if let store = store {
                MainTabView()
                    .environmentObject(store)
            } else {
                // store 初始化中（通常极短暂）
                Color.App.backgroundGray.ignoresSafeArea()
            }
        }
        .onAppear {
            // store 在后台初始化，欢迎页显示时就开始，测评结束后必然就绪
            if store == nil {
                store = AppStore(modelContext: modelContext)
                store?.initialize()

                // 老用户会员福利：标记待弹出，等测评完成后再展示
                if UserDefaults.standard.bool(forKey: "legacyGiftShouldAutoPresent") {
                    UserDefaults.standard.set(false, forKey: "legacyGiftShouldAutoPresent")
                    pendingLegacyGiftLetter = true
                }
            }

            if let store = store, AppRatingManager.shared.shouldShowRating(transactionCount: store.recentTransactions.count) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    showRatingPrompt = true
                }
            }
        }
        .fullScreenCover(isPresented: $showLegacyGiftLetter) {
            LegacyGiftLetterView(onDismiss: {
                showLegacyGiftLetter = false
                if let store {
                    store.markLegacyGiftNoticeAsRead()
                }
            })
        }
        .overlay {
            if showRatingPrompt {
                AppRatingPromptView(
                    isPresented: $showRatingPrompt,
                    onRate: {
                        AppRatingManager.shared.openAppStore()
                    },
                    onFeedback: {
                        NotificationCenter.default.post(name: .showFeedback, object: nil)
                    }
                )
            }
        }
        // MARK: - URL Scheme 处理（备选方案，主要方案是 App Intent）
        // 保留此代码作为备选方案，如果 App Intent 效果不好可以回退到此方案
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }
    
    // MARK: - 首次启动流程：欢迎页 + 测评（整体替代主页，无 MainTabView 背景）
    @ViewBuilder
    private var firstLaunchFlow: some View {
        ZStack {
            if showWelcome {
                WelcomeView {
                    // 按钮点击：标记已看，直接进测评
                    UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showWelcome = false
                        showAssessment = true
                    }
                }
                .transition(.opacity)
                .zIndex(0)
            }

            if showAssessment {
                ZStack {
                    Color(hex: "#EBF7F2").ignoresSafeArea()

                    switch assessmentStep {
                    case .quiz:
                        AssessmentView { persona, score, habit, method, income, jtbd in
                            assessmentPersona = persona
                            assessmentScore   = score
                            assessmentHabit   = habit
                            assessmentMethod  = method
                            assessmentIncome  = income
                            assessmentJTBD    = jtbd
                            withAnimation(.easeInOut(duration: 0.35)) {
                                assessmentStep = .loading
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                                withAnimation(.easeInOut(duration: 0.35)) {
                                    assessmentStep = .result
                                }
                            }
                        }
                        .transition(.opacity)

                    case .loading:
                        personaLoadingView
                            .transition(.opacity)

                    case .result:
                        PersonaResultView(
                            persona:     assessmentPersona,
                            healthScore: assessmentScore,
                            habit:       assessmentHabit,
                            method:      assessmentMethod,
                            income:      assessmentIncome,
                            jtbd:        assessmentJTBD
                        ) {
                            // 测评完成 → 进入主页
                            showAssessment = false
                            assessmentStep = .quiz
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                NotificationCenter.default.post(name: .navigateToOnboardingChat, object: nil)
                            }
                            // 测评完成后弹出老用户感谢信
                            if pendingLegacyGiftLetter {
                                pendingLegacyGiftLetter = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                    showLegacyGiftLetter = true
                                }
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.35), value: assessmentStep)
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showWelcome)
        .animation(.easeInOut(duration: 0.3), value: showAssessment)
    }

    // MARK: - 画像生成加载动画
    private var personaLoadingView: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color(hex: "#A8E6CF").opacity(0.3), lineWidth: 4)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color(hex: "#2C6957"), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(loadingRotation))
                    .onAppear {
                        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                            loadingRotation = 360
                        }
                    }

                Image("capybara_a")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
            }

            VStack(spacing: 8) {
                Text("小满正在分析你的财务画像...")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(hex: "#1A3A2E"))

                Text("基于你的回答，为你定制专属体验")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#1A3A2E").opacity(0.6))
            }

            Spacer()
        }
    }

    private func handleDeepLink(_ url: URL) {
        #if DEBUG
        print("📱 Deep Link received: \(url)")
        #endif
        
        guard url.scheme == "moneyfull",
              url.host == "ai",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            #if DEBUG
            print("❌ Deep Link: scheme/host/components 解析失败")
            #endif
            return
        }
        
        let queryItems = components.queryItems ?? []
        #if DEBUG
        print("📱 Deep Link queryItems: \(queryItems.map { "\($0.name)=\($0.value?.prefix(50) ?? "nil")" })")
        #endif
        
        // 优先处理 clipboard 参数（从剪贴板读取 OCR 文本）
        if queryItems.first(where: { $0.name == "clipboard" }) != nil {
            if let clipboardText = UIPasteboard.general.string, !clipboardText.isEmpty {
                #if DEBUG
                print("✅ Deep Link: 从剪贴板读取文本，长度: \(clipboardText.count)")
                #endif
                deepLinkText = clipboardText
                NotificationCenter.default.post(name: .deepLinkReceived, object: clipboardText)
                return
            }
        }
        
        // 处理 image 参数（Base64 编码的 OCR 文本）
        if let item = queryItems.first(where: { $0.name == "image" }),
           let base64Value = item.value, !base64Value.isEmpty {
            #if DEBUG
            print("📱 Deep Link: 找到 image 参数，长度: \(base64Value.count)")
            #endif
            
            // 修复 Base64 中的空格（URL 会把 + 变成空格）
            let fixedBase64 = base64Value.replacingOccurrences(of: " ", with: "+")
            
            // 尝试 Base64 解码
            if let data = Data(base64Encoded: fixedBase64),
               let decoded = String(data: data, encoding: .utf8), !decoded.isEmpty {
                #if DEBUG
                print("✅ Deep Link: Base64 解码成功，文本: \(decoded.prefix(100))")
                #endif
                deepLinkText = decoded
                NotificationCenter.default.post(name: .deepLinkReceived, object: decoded)
                return
            }
            
            // Base64 解码失败，尝试直接 URL 解码（兼容非 Base64 格式）
            let urlDecoded = base64Value.removingPercentEncoding ?? base64Value
            if !urlDecoded.isEmpty {
                #if DEBUG
                print("✅ Deep Link: 使用 URL 解码，文本: \(urlDecoded.prefix(100))")
                #endif
                deepLinkText = urlDecoded
                NotificationCenter.default.post(name: .deepLinkReceived, object: urlDecoded)
                return
            }
        }
        
        // 兼容旧的 text / ocr_text 参数
        if let item = queryItems.first(where: { $0.name == "text" || $0.name == "ocr_text" }),
           let rawText = item.value, !rawText.isEmpty {
            let decoded = rawText.removingPercentEncoding ?? rawText
            #if DEBUG
            print("✅ Deep Link: text 参数解码成功，文本: \(decoded.prefix(100))")
            #endif
            deepLinkText = decoded
            NotificationCenter.default.post(name: .deepLinkReceived, object: decoded)
        } else {
            #if DEBUG
            print("❌ Deep Link: 未找到有效的 text/image 参数")
            #endif
        }
    }
}

extension Notification.Name {
    static let deepLinkReceived = Notification.Name("deepLinkReceived")
    static let showFeedback = Notification.Name("showFeedback")
    static let newShortcutText = Notification.Name("newShortcutText")
    static let navigateToOnboardingChat = Notification.Name("navigateToOnboardingChat")
    /// 老用户会员福利发放成功时广播，StoreManager 借此重新计算 isPremium
    static let legacyGiftGranted = Notification.Name("legacyGiftGranted")
}

#Preview {
    ContentView()
        .modelContainer(for: [Project.self, Transaction.self, Category.self, ChatHistory.self, MemoryRule.self, LegacyGiftGrant.self, AppNotice.self], inMemory: true)
}

