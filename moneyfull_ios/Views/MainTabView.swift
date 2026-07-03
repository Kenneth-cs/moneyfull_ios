import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var theme: ThemeManager
    @State private var selectedTab = 0
    @State private var isAddRecordPresented = false
    @State private var isAIChatPresented = false
    @State private var projectNavResetID = UUID()
    @State private var aiInitialText: String?
    @State private var isFromShortcut: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                Color.App.backgroundGray.ignoresSafeArea()
                
                TabView(selection: $selectedTab) {
                    DashboardView(selectedTab: $selectedTab, onResetProjectNav: {
                        projectNavResetID = UUID()
                    })
                    .tag(0)
                    .toolbar(.hidden, for: .tabBar)
                    
                    ProjectsView()
                        .id(projectNavResetID)
                        .tag(1)
                        .toolbar(.hidden, for: .tabBar)
                    
                    Color.clear
                        .tag(2)
                        .toolbar(.hidden, for: .tabBar)
                    
                    AnalyticsView()
                        .tag(3)
                        .toolbar(.hidden, for: .tabBar)
                    
                    ProfileView()
                        .tag(4)
                        .toolbar(.hidden, for: .tabBar)
                }
                .background(Color.clear)
                
                CustomBottomTabBar(
                    selectedTab: $selectedTab,
                    isAddRecordPresented: $isAddRecordPresented,
                    isAIChatPresented: $isAIChatPresented,
                    aiInitialText: $aiInitialText
                )
                
                NavigationLink(isActive: $isAIChatPresented) {
                    AIChatView(initialText: aiInitialText, isFromShortcut: isFromShortcut)
                        .environmentObject(store)
                        .onDisappear {
                            aiInitialText = nil
                            isFromShortcut = false
                        }
                } label: {
                    EmptyView()
                }
                .hidden()
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .onChange(of: selectedTab) {
            if selectedTab == 3 {
                AnalyticsManager.shared.trackEvent(eventId: "analytics_view_page", eventName: "浏览统计页")
            }
        }
        .fullScreenCover(isPresented: $isAddRecordPresented) {
            AddRecordView()
                .environmentObject(store)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onReceive(NotificationCenter.default.publisher(for: .deepLinkReceived)) { notification in
            if let text = notification.object as? String {
                let todayKey = "ai_chat_usage_" + { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date()) }()
                let usage = UserDefaults.standard.integer(forKey: todayKey)
                guard usage < 15 else { return }
                
                if isAIChatPresented {
                    NotificationCenter.default.post(name: .newShortcutText, object: text)
                } else {
                    aiInitialText = text
                    isFromShortcut = true
                    isAIChatPresented = true
                }
            }
        }
        .onAppear {
            checkPendingOCRText()
        }
    }
    
    private func checkPendingOCRText() {
        if let text = UserDefaults(suiteName: "group.moneyfull.shared")?.string(forKey: "pendingOCRText"),
           !text.isEmpty {
            // 清除 UserDefaults 中的数据
            UserDefaults(suiteName: "group.moneyfull.shared")?.removeObject(forKey: "pendingOCRText")
            
            aiInitialText = text
            isFromShortcut = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isAIChatPresented = true
            }
        }
    }
}

// MARK: - 自定义底部导航栏
struct CustomBottomTabBar: View {
    @Binding var selectedTab: Int
    @Binding var isAddRecordPresented: Bool
    @Binding var isAIChatPresented: Bool
    @Binding var aiInitialText: String?
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let speechService = SpeechService.shared
    
    var body: some View {
        // 悬浮胶囊，直接浮在背景色上，不加任何底部填充块
        HStack {
            TabBarItem(icon: "house.fill", title: "首页", isSelected: selectedTab == 0) { selectionFeedback.selectionChanged(); selectedTab = 0 }
            Spacer()
            TabBarItem(icon: "square.grid.2x2.fill", title: "项目", isSelected: selectedTab == 1) { selectionFeedback.selectionChanged(); selectedTab = 1 }
            Spacer()
            
                // 中央AI助手按钮（与其他图标平齐）
                AIAssistantButton(
                    onShortTap: {
                        AnalyticsManager.shared.trackEvent(eventId: "ai_chat_open", eventName: "打开AI助手", params: ["source": "tab_bar"])
                        aiInitialText = nil
                        isAIChatPresented = true
                    },
                    onLongPressStart: {
                        AnalyticsManager.shared.trackEvent(eventId: "ai_voice_start", eventName: "长按语音记账", params: ["source": "tab_bar"])
                        Task {
                            let granted = await speechService.requestPermission()
                            if granted {
                                try? speechService.startRecording()
                            }
                        }
                    },
                    onLongPressEnd: {
                        speechService.stopRecording()
                        let transcribed = speechService.transcribedText
                        if !transcribed.isEmpty {
                            aiInitialText = transcribed
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                isAIChatPresented = true
                            }
                        }
                    }
                )
            
            Spacer()
            TabBarItem(icon: "chart.bar.fill", title: "统计", isSelected: selectedTab == 3) { selectionFeedback.selectionChanged(); selectedTab = 3 }
            Spacer()
            TabBarItem(icon: "person.fill", title: "我的", isSelected: selectedTab == 4) { selectionFeedback.selectionChanged(); selectedTab = 4 }
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 14)
        .background(
            // 用不透明卡片背景代替实时毛玻璃（.ultraThinMaterial）。
            // 实时模糊会在滚动时每帧重算背后移动的内容，是滚动卡顿的主因；
            // 原本上层已盖了 0.8 不透明卡片，外观几乎一致。
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.App.cardBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: -4)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - AI 助手麦克风按钮
struct AIAssistantButton: View {
    var onShortTap: () -> Void
    var onLongPressStart: () -> Void
    var onLongPressEnd: () -> Void
    
    @State private var isAnimating = false
    @State private var isPressed = false
    @State private var isRecording = false
    @State private var pressTimer: Timer?
    
    var body: some View {
        ZStack {
            // 录音时的外发光扩散效果
            if isRecording {
                Circle()
                    .stroke(Color(hex: "#10B981"), lineWidth: 2) // 加深波纹颜色
                    .frame(width: 84, height: 84)
                    .scaleEffect(isAnimating ? 1.4 : 1.0)
                    .opacity(isAnimating ? 0 : 0.6)
                    .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: isAnimating)
                
                Circle()
                    .stroke(Color(hex: "#34D399"), lineWidth: 2)
                    .frame(width: 84, height: 84)
                    .scaleEffect(isAnimating ? 1.4 : 1.0)
                    .opacity(isAnimating ? 0 : 0.6)
                    .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false).delay(0.4), value: isAnimating)
            }
            
            // 呼吸光晕效果
            Circle()
                .fill(Color(hex: "#10B981")) // 加深光晕颜色
                .frame(width: 64, height: 64)
                .scaleEffect(isAnimating && !isRecording ? 1.3 : 1.0)
                .opacity(isAnimating && !isRecording ? 0 : 0.25)
            
            // 主体按钮渐变背景
            Circle()
                .fill(Color.App.cardBackground)
                .frame(width: 64, height: 64)
                .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 8)
            
            // 麦克风图标 (使用自定义图片)
            Image("ai_button") // 假设图片名为 ai_button，请确保 Assets.xcassets 中有此图片
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(Circle())
            
            // 录音状态提示文字
            if isRecording {
                Text("正在录音...")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.App.primaryGreen)
                    .clipShape(Capsule())
                    .offset(y: -50)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isPressed)
        .onAppear {
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        // 启动长按计时器
                        pressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                            isRecording = true
                            onLongPressStart()
                        }
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    pressTimer?.invalidate()
                    pressTimer = nil
                    
                    if isRecording {
                        isRecording = false
                        onLongPressEnd()
                    } else {
                        onShortTap()
                    }
                }
        )
    }
}

// MARK: - Tab 图标 + 文字
struct TabBarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Color.App.primaryGreen.opacity(0.3))
                            .frame(width: 44, height: 44)
                    }
                    AppIconView(
                        name: icon,
                        size: 22,
                        color: isSelected ? Color.App.darkGreen : Color.gray.opacity(0.5),
                        weight: isSelected ? .bold : .regular
                    )
                }
                .frame(width: 44, height: 44)
                
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isSelected ? Color.App.darkGreen : Color.gray.opacity(0.5))
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(ThemeManager())
}
