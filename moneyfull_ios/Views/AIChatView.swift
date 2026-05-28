import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Design Tokens
private enum ChatDesign {
    static let background = Color(red: 0.98, green: 0.984, blue: 0.98)  // #FAFBFA
    static let primary = Color(red: 0.153, green: 0.412, blue: 0.337)   // #276956
    static let primaryContainer = Color(red: 0.620, green: 0.878, blue: 0.784) // #9EE0C8
    static let onPrimaryContainer = Color(red: 0.133, green: 0.396, blue: 0.322) // #226552
    static let onSurface = Color(red: 0.098, green: 0.110, blue: 0.110)  // #191C1C
    static let surfaceVariant = Color(red: 0.882, green: 0.890, blue: 0.886) // #E1E3E2
    static let aiBubbleBg = Color(red: 0.922, green: 0.976, blue: 0.953) // #EBF9F3
    static let aiBubbleBorder = Color(red: 0.620, green: 0.878, blue: 0.784).opacity(0.3)
    static let aiBubbleText = Color(red: 0.102, green: 0.302, blue: 0.243) // #1A4D3E
    static let headerTop = Color(hex: "#D6F0E5")
    static let headerBottom = Color(hex: "#F0FAF5")
    static let dotColor = Color.black.opacity(0.03)
    static let dotSpacing: CGFloat = 24
    static let dotRadius: CGFloat = 1
}

// MARK: - Dot Grid Background
struct DotGridBackground: View {
    var body: some View {
        Canvas { context, size in
            let spacing = ChatDesign.dotSpacing
            let radius = ChatDesign.dotRadius
            var x: CGFloat = 0
            while x < size.width {
                var y: CGFloat = 0
                while y < size.height {
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(ChatDesign.dotColor))
                    y += spacing
                }
                x += spacing
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Typing Indicator
struct TypingIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(ChatDesign.primaryContainer)
                    .frame(width: 7, height: 7)
                    .scaleEffect(isAnimating ? 1.0 : 0.6)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever().delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear { isAnimating = true }
    }
}

// MARK: - AI Avatar（小满）
struct AIChatAvatar: View {
    var size: CGFloat = 36

    var body: some View {
        Image("ai_chat_avatar")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Date Divider
struct ChatDateDivider: View {
    let date: Date

    var body: some View {
        HStack {
            Spacer()
            Text(dateLabel)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: "#9CA3AF"))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.8))
                        .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 2)
                )
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var dateLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return "今天 " + date.formatted(date: .omitted, time: .shortened) + " 🌸"
        } else if cal.isDateInYesterday(date) {
            return "昨天 " + date.formatted(date: .omitted, time: .shortened)
        } else {
            let fmt = DateFormatter()
            fmt.dateFormat = "M月d日"
            return fmt.string(from: date)
        }
    }
}

// MARK: - AI Chat View

struct AIChatView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var messageText = ""
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = false
    @State private var isRecording = false
    @State private var showVoiceInput = false
    @State private var showPlusMenu = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var editingTransaction: Transaction?
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var showBackTapTutorial = false
    @State private var showFinancialAcademy = false
    @FocusState private var isInputFocused: Bool
    
    private static let dailyLimit = 15
    @State private var dailyUsageCount = 0
    private var isLimitReached: Bool { dailyUsageCount >= Self.dailyLimit }
    private var remainingCount: Int { max(0, Self.dailyLimit - dailyUsageCount) }
    
    private static var todayKey: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return "ai_chat_usage_" + fmt.string(from: Date())
    }

    var initialText: String?
    var isFromShortcut: Bool = false

    private let speechService = SpeechService.shared
    private let llmService = LLMService.shared
    private let contextManager = ContextManager.shared
    private let visionService = VisionService.shared
    private let analyticsEngine = AnalyticsEngine.shared

    private let quickActions: [(emoji: String, label: String)] = [
        ("✋", "无疼记账"),
        ("📚", "财商学堂"),
        ("💡", "省钱建议"),
        ("📊", "导出报告"),
    ]

    var body: some View {
        ZStack {
            ChatDesign.background.ignoresSafeArea()
            DotGridBackground()

            VStack(spacing: 0) {
                headerView
                chatArea
                inputArea
            }
            .gesture(
                DragGesture(minimumDistance: 30, coordinateSpace: .local)
                    .onEnded { value in
                        if value.translation.width > 60 && abs(value.translation.height) < 40 {
                            dismiss()
                        }
                    }
            )
            
            if showToast {
                VStack {
                    Spacer()
                    Text(toastMessage)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Capsule())
                        .padding(.bottom, 160)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                .animation(.easeInOut(duration: 0.3), value: showToast)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            dailyUsageCount = UserDefaults.standard.integer(forKey: Self.todayKey)
            loadChatHistory()
            if let text = initialText, !text.isEmpty {
                if isFromShortcut {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { processOCRText(text) }
                } else {
                    messageText = text
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { sendMessage() }
                }
            }
        }
        .onDisappear {
            messages = []
            editingTransaction = nil
        }
        .sheet(item: $editingTransaction) { tx in
            EditTransactionView(transaction: tx)
                .environmentObject(store)
        }
        .sheet(isPresented: $showBackTapTutorial) {
            BackTapTutorialView()
        }
        .background {
            NavigationLink(isActive: $showFinancialAcademy) {
                FinancialAcademyView()
                    .environmentObject(store)
            } label: {
                EmptyView()
            }
            .hidden()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "arrow.backward")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(ChatDesign.onPrimaryContainer)
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.7))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
            }

            Spacer()

            VStack(spacing: 2) {
                Text("✨ 小满-您的财务管家 ✨")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(ChatDesign.onPrimaryContainer)
                
                if isLimitReached {
                    Text("今日次数已用完，明天再来～")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: "#EF4444"))
                } else {
                    Text("今日剩余 \(remainingCount)/\(AIChatView.dailyLimit) 次")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(ChatDesign.onPrimaryContainer.opacity(0.5))
                }
            }

            Spacer()

            Button(action: { clearChatHistory() }) {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ChatDesign.onPrimaryContainer.opacity(0.5))
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.5))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background {
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [ChatDesign.headerTop, ChatDesign.headerBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .top)

                // 装饰小图标
                headerDecorations
            }
        }
        .overlay(
            Rectangle()
                .fill(ChatDesign.surfaceVariant.opacity(0.15))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var headerDecorations: some View {
        GeometryReader { geo in
            let w = geo.size.width
            Group {
                Text("✦").font(.system(size: 11)).foregroundColor(ChatDesign.primary.opacity(0.25))
                    .position(x: w * 0.82, y: 14)
                Text("✦").font(.system(size: 7)).foregroundColor(ChatDesign.primaryContainer.opacity(0.5))
                    .position(x: w * 0.88, y: 36)
                Text("🌿").font(.system(size: 10)).opacity(0.3)
                    .position(x: w * 0.12, y: 12)
                Text("✦").font(.system(size: 8)).foregroundColor(ChatDesign.primary.opacity(0.2))
                    .position(x: w * 0.06, y: 40)
                Text("🌸").font(.system(size: 9)).opacity(0.25)
                    .position(x: w * 0.75, y: 46)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Chat Area

    private var chatArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        // 日期分割线
                        if index == 0 || !Calendar.current.isDate(
                            message.timestamp,
                            inSameDayAs: messages[index - 1].timestamp
                        ) {
                            ChatDateDivider(date: message.timestamp)
                        }

                        ChatBubble(
                            message: message,
                            onConfirm: { handleTransactionConfirmed($0) },
                            onCancel: { handleTransactionCancelled(message) },
                            onSaveMemory: { handleSaveMemory(keyword: $0, categoryName: $1, projectName: $2) },
                            onCreateProject: { handleCreateProject($0) },
                            onEdit: { editingTransaction = $0 },
                            onDelete: { handleDeleteTransaction($0, message: message) },
                            onViewInsightDetail: { dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                NotificationCenter.default.post(name: .navigateToAnalytics, object: nil)
                            }}
                        )
                        .environmentObject(store)
                        .id(message.id)
                    }

                    if isLoading { loadingIndicator }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .onChange(of: messages.count) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    proxy.scrollTo(messages.last?.id, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Loading Indicator

    private var loadingIndicator: some View {
        HStack(alignment: .bottom, spacing: 10) {
            AIChatAvatar(size: 36)

            TypingIndicator()
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    ChatDesign.aiBubbleBg
                        .clipShape(UnevenRoundedRectangle(
                            topLeadingRadius: 8, bottomLeadingRadius: 20,
                            bottomTrailingRadius: 20, topTrailingRadius: 20
                        ))
                        .overlay(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 8, bottomLeadingRadius: 20,
                                bottomTrailingRadius: 20, topTrailingRadius: 20
                            ).stroke(ChatDesign.aiBubbleBorder, lineWidth: 1)
                        )
                        .shadow(color: ChatDesign.primaryContainer.opacity(0.15), radius: 12, x: 0, y: 4)
                )

            Spacer()
        }
    }

    // MARK: - Input Area

    private var inputArea: some View {
        VStack(spacing: 10) {
            // Quick Action Chips（纯 UI，v2.2 暂不绑定逻辑）
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(quickActions, id: \.label) { action in
                        Button(action: {
                            switch action.label {
                            case "无疼记账":
                                showBackTapTutorial = true
                            case "财商学堂":
                                showFinancialAcademy = true
                            default:
                                toastMessage = "「\(action.label)」功能正在开发中～"
                                showToast = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    showToast = false
                                }
                            }
                        }) {
                            HStack(spacing: 6) {
                                Text(action.emoji).font(.system(size: 14))
                                Text(action.label)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(ChatDesign.onSurface)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.85))
                                    .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
                            )
                            .overlay(Capsule().stroke(ChatDesign.surfaceVariant.opacity(0.15), lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 2)
            }

            // Input Bar
            HStack(spacing: 10) {
                // "+" 按钮区域
                Group {
                    if showPlusMenu {
                        HStack(spacing: 6) {
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(ChatDesign.onPrimaryContainer)
                                    .frame(width: 36, height: 36)
                                    .background(ChatDesign.aiBubbleBg)
                                    .clipShape(Circle())
                            }
                            .onChange(of: selectedPhotoItem) { _, newValue in
                                Task {
                                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                                       let image = UIImage(data: data) {
                                        selectedImage = image
                                        showPlusMenu = false
                                        await processImage(image)
                                    }
                                }
                            }

                            Button(action: { showVoiceInput.toggle(); showPlusMenu = false }) {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(ChatDesign.onPrimaryContainer)
                                    .frame(width: 36, height: 36)
                                    .background(ChatDesign.aiBubbleBg)
                                    .clipShape(Circle())
                            }

                            Button(action: { withAnimation(.spring(response: 0.25)) { showPlusMenu = false } }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color.gray)
                                    .frame(width: 28, height: 28)
                            }
                        }
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    } else {
                        Button(action: { withAnimation(.spring(response: 0.25)) { showPlusMenu = true } }) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(ChatDesign.onPrimaryContainer)
                                .frame(width: 40, height: 40)
                                .background(ChatDesign.aiBubbleBg.opacity(0.7))
                                .clipShape(Circle())
                        }
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: showPlusMenu)

                // 输入框
                if showVoiceInput {
                    voiceInputButton
                } else {
                    TextField(isLimitReached ? "今日次数已用完" : "问我任何财务问题吧...", text: $messageText)
                        .font(.system(size: 15, design: .rounded))
                        .focused($isInputFocused)
                        .disabled(isLimitReached)
                }

                // 发送按钮
                Button(action: { sendMessage() }) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#002118"))
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill((messageText.isEmpty && !showVoiceInput) || isLimitReached
                                      ? ChatDesign.primaryContainer.opacity(0.5)
                                      : ChatDesign.primaryContainer)
                                .shadow(color: ChatDesign.primaryContainer.opacity(0.4), radius: 12, x: 0, y: 4)
                        )
                }
                .disabled((messageText.isEmpty && !showVoiceInput) || isLimitReached)
                .scaleEffect(messageText.isEmpty ? 0.93 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: messageText.isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.95))
                    .shadow(color: Color.black.opacity(0.04), radius: 20, x: 0, y: 4)
                    .overlay(Capsule().stroke(ChatDesign.surfaceVariant.opacity(0.2), lineWidth: 1))
            )
            .padding(.horizontal, 16)
        }
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 36, topTrailingRadius: 36)
                .fill(Color.white.opacity(0.75).shadow(.inner(color: .clear, radius: 0)))
                .background(
                    UnevenRoundedRectangle(topLeadingRadius: 36, topTrailingRadius: 36)
                        .fill(.ultraThinMaterial)
                )
                .shadow(color: Color.black.opacity(0.03), radius: 24, x: 0, y: -4)
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(
            UnevenRoundedRectangle(topLeadingRadius: 36, topTrailingRadius: 36)
                .stroke(ChatDesign.surfaceVariant.opacity(0.12), lineWidth: 1),
            alignment: .top
        )
    }

    // MARK: - Voice Input Button

    private var voiceInputButton: some View {
        ZStack {
            if isRecording {
                Text("松开发送")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#EF4444"))
                    .clipShape(Capsule())
            } else {
                Text("按住说话")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(ChatDesign.onSurface)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(ChatDesign.aiBubbleBg)
                    .clipShape(Capsule())
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !isRecording { startRecording() } }
                .onEnded   { _ in if  isRecording { stopRecording()  } }
        )
    }

    // MARK: - Business Logic
    private func incrementUsage() {
        dailyUsageCount += 1
        UserDefaults.standard.set(dailyUsageCount, forKey: Self.todayKey)
    }
    
    private func clearChatHistory() {
        messages = []
        contextManager.clearChatHistory()
    }
    
    private func loadChatHistory() {
        let histories = contextManager.fetchChatHistory(limit: 60)
        guard !histories.isEmpty else { return }

        messages = histories.compactMap { history in
            // 尝试还原消费洞察卡片
            if history.content.hasPrefix("__INSIGHT__:"),
               let jsonStr = String(history.content.dropFirst("__INSIGHT__:".count)) as String?,
               let data = jsonStr.data(using: .utf8),
               let insight = try? JSONDecoder().decode(SpendingInsightData.self, from: data) {
                return ChatMessage(
                    role: .assistant,
                    content: "",
                    timestamp: history.timestamp,
                    spendingInsight: insight,
                    usesRichText: false
                )
            }
            // 普通文本消息
            return ChatMessage(
                role: history.role == "user" ? .user : .assistant,
                content: history.content,
                timestamp: history.timestamp,
                usesRichText: history.role == "assistant"
            )
        }
    }

    private func handleTransactionConfirmed(_ cardData: TransactionCardData) {
        let project: Project
        if let name = cardData.projectName,
           let found = store.activeProjects.first(where: { $0.name == name }) {
            project = found
        } else {
            project = store.activeProjects.first ?? store.addProject(
                name: "日常收支", icon: "wallet.bifold.fill",
                colorHex: "#A8E6CF", desc: "日常收支记录", budget: 0
            )
        }
        let txType: TransactionType = cardData.type == "income" ? .income : .expense
        let tx = store.addTransaction(
            to: project, amount: cardData.amount, type: txType,
            categoryName: cardData.categoryName, categoryIcon: cardData.categoryIcon,
            categoryColorHex: cardData.categoryColorHex, note: cardData.note
        )
        let prefix = cardData.type == "expense" ? "-" : "+"
        let content = "已成功入账 \(prefix)¥\(cardData.amount)（\(cardData.categoryName)）"
        messages.append(ChatMessage(
            role: .assistant, content: content,
            timestamp: Date(), confirmedTransaction: tx
        ))
        try? contextManager.saveChatHistory(role: "assistant", content: content)
    }

    private func handleTransactionCancelled(_ message: ChatMessage) {
        if let idx = messages.firstIndex(where: { $0.id == message.id }) {
            messages[idx] = ChatMessage(role: .assistant, content: "已取消入账", timestamp: Date())
        }
        try? contextManager.saveChatHistory(role: "assistant", content: "已取消入账")
    }

    private func handleDeleteTransaction(_ tx: Transaction, message: ChatMessage) {
        store.deleteTransaction(tx)
        if let idx = messages.firstIndex(where: { $0.id == message.id }) {
            messages[idx].isDeleted = true
            messages[idx].confirmedTransaction = nil
        }
        try? contextManager.saveChatHistory(role: "assistant", content: "🗑️ 已删除")
    }

    private func handleSaveMemory(keyword: String, categoryName: String, projectName: String?) {
        try? contextManager.saveMemoryRule(
            keyword: keyword, categoryName: categoryName, projectName: projectName
        )
    }

    private func handleCreateProject(_ projectData: ProjectCreationData) {
        _ = store.addProject(
            name: projectData.projectName, icon: projectData.projectIcon,
            colorHex: projectData.projectColor, desc: "", budget: 0
        )
        let content = "已成功创建项目「\(projectData.projectName)」"
        messages.append(ChatMessage(role: .assistant, content: content, timestamp: Date()))
        try? contextManager.saveChatHistory(role: "assistant", content: content)
    }

    private func sendMessage() {
        guard !messageText.isEmpty, !isLimitReached else { return }
        let text = messageText
        messages.append(ChatMessage(role: .user, content: text, timestamp: Date()))
        messageText = ""
        isInputFocused = false
        showPlusMenu = false
        try? contextManager.saveChatHistory(role: "user", content: text)
        Task { await parseTransaction(from: text) }
    }

    private func processImage(_ image: UIImage) async {
        let imgMsg = ChatMessage(role: .user, content: "📷 [图片]", timestamp: Date(), image: image)
        await MainActor.run { messages.append(imgMsg); isLoading = true }
        let processingMsg = ChatMessage(role: .assistant, content: "正在识别账单...", timestamp: Date())
        await MainActor.run { messages.append(processingMsg) }
        do {
            let ocrText = try await visionService.extractCleanText(from: image)
            let context = try contextManager.buildContext()
            let result = try await llmService.parseOCRText(from: ocrText, context: context)
            await MainActor.run {
                messages.removeAll { $0.id == processingMsg.id }
                handleParseResult(result)
                incrementUsage()
                isLoading = false
            }
        } catch {
            await MainActor.run {
                messages.removeAll { $0.id == processingMsg.id }
                messages.append(ChatMessage(role: .assistant,
                    content: "图片识别失败：\(error.localizedDescription)", timestamp: Date()))
                isLoading = false
            }
        }
    }

    private func startRecording() {
        Task {
            guard await speechService.requestPermission() else { return }
            try? speechService.startRecording()
            isRecording = true
        }
    }

    private func stopRecording() {
        speechService.stopRecording()
        isRecording = false
        let t = speechService.transcribedText
        if !t.isEmpty { messageText = t; sendMessage() }
    }

    private func parseTransaction(from text: String) async {
        isLoading = true
        do {
            let context = try contextManager.buildContext()
            let result = try await llmService.parseTransaction(from: text, context: context)
            await MainActor.run {
                handleParseResult(result)
                incrementUsage()
                isLoading = false
            }
        } catch {
            await MainActor.run {
                messages.append(ChatMessage(role: .assistant,
                    content: "抱歉，处理消息时出现错误，请重试。", timestamp: Date()))
                isLoading = false
            }
        }
    }

    private func processOCRText(_ ocrText: String) {
        Task {
            await MainActor.run {
                isLoading = true
                messages.append(ChatMessage(role: .assistant, content: "正在识别账单...", timestamp: Date()))
            }
            do {
                let context = try contextManager.buildContext()
                let result = try await llmService.parseOCRText(from: ocrText, context: context)
                await MainActor.run {
                    messages.removeAll { $0.role == .assistant && $0.content == "正在识别账单..." }
                    handleParseResult(result)
                    incrementUsage()
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    messages.removeAll { $0.role == .assistant && $0.content == "正在识别账单..." }
                    messages.append(ChatMessage(role: .assistant, content: "识别失败，请重试", timestamp: Date()))
                    isLoading = false
                }
            }
        }
    }

    private func handleParseResult(_ result: TransactionParseResult) {
        if result.status == "success" {
            let card = ChatMessage(
                role: .assistant,
                content: "我帮你记录了这笔交易：",
                timestamp: Date(),
                transactionCard: TransactionCardData(
                    amount: result.amount ?? 0,
                    type: result.type ?? "expense",
                    groupName: result.groupName ?? "",
                    categoryName: result.categoryName ?? "",
                    categoryIcon: result.categoryIcon ?? "tag.fill",
                    categoryColorHex: result.categoryColorHex ?? "#A8E6CF",
                    note: result.note ?? "",
                    projectName: result.projectName
                )
            )
            messages.append(card)
            try? contextManager.saveChatHistory(role: "assistant", content: "交易确认卡片")

        } else if result.status == "suggest_new_category" {
            let card = ChatMessage(
                role: .assistant,
                content: "我发现了一个新分类建议：",
                timestamp: Date(),
                transactionCard: TransactionCardData(
                    amount: result.amount ?? 0,
                    type: result.type ?? "expense",
                    groupName: result.parentGroup ?? "其他",
                    categoryName: result.suggestedCategory ?? "",
                    categoryIcon: "sparkles",
                    categoryColorHex: "#FFD700",
                    note: result.note ?? "",
                    projectName: result.projectName,
                    isNewCategory: true,
                    suggestedCategory: result.suggestedCategory,
                    parentGroup: result.parentGroup
                )
            )
            messages.append(card)
            try? contextManager.saveChatHistory(role: "assistant", content: "新分类建议卡片")

        } else if result.status == "insight" {
            // 消费洞察：AI 回复文案 + 本地计算卡片数据
            let reply = result.reply ?? "为您分析支出情况～"
            let targetGroup = result.targetGroup ?? ""
            let period: InsightPeriod = result.period == "this_month" ? .thisMonth : .lastMonth
            let allTx = store.recentTransactions

            // 根据类型选择聚合方式
            let insightData: SpendingInsightData?
            if result.insightType == "monthly_overview" {
                insightData = analyticsEngine.monthlyOverview(period: period, transactions: allTx)
            } else {
                insightData = analyticsEngine.insightForCategoryGroup(
                    groupName: targetGroup.isEmpty ? "餐饮" : targetGroup,
                    period: period,
                    transactions: allTx
                )
            }

            // AI 文字气泡（富文本）
            let replyMsg = ChatMessage(
                role: .assistant, content: reply,
                timestamp: Date(), usesRichText: true
            )
            messages.append(replyMsg)

            // 洞察卡片
            if let data = insightData {
                let insightMsg = ChatMessage(
                    role: .assistant, content: "",
                    timestamp: Date(), spendingInsight: data
                )
                messages.append(insightMsg)

                // 持久化（折中方案：JSON 编码存入 ChatHistory）
                if let encoded = try? JSONEncoder().encode(data),
                   let jsonStr = String(data: encoded, encoding: .utf8) {
                    try? contextManager.saveChatHistory(role: "assistant", content: "__INSIGHT__:\(jsonStr)")
                }
            }
            try? contextManager.saveChatHistory(role: "assistant", content: reply)

        } else if result.status == "need_clarification" {
            let msg = ChatMessage(
                role: .assistant, content: result.reply ?? "请补充更多信息",
                timestamp: Date(), usesRichText: true
            )
            messages.append(msg)
            try? contextManager.saveChatHistory(role: "assistant", content: msg.content)

        } else if result.status == "chat" {
            let msg = ChatMessage(
                role: .assistant,
                content: result.reply ?? "我主要负责帮您记账和管理财务哦～",
                timestamp: Date(), usesRichText: true
            )
            messages.append(msg)
            try? contextManager.saveChatHistory(role: "assistant", content: msg.content)

        } else if result.status == "project_creation_requested" {
            let name = result.projectName ?? "新项目"
            let msg = ChatMessage(
                role: .assistant,
                content: "已为您创建项目「\(name)」",
                timestamp: Date(),
                projectCreation: ProjectCreationData(projectName: name)
            )
            messages.append(msg)
            try? contextManager.saveChatHistory(role: "assistant", content: "已创建项目：\(name)")
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let navigateToAnalytics = Notification.Name("navigateToAnalytics")
}

// MARK: - Chat Message Model

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: ChatRole
    var content: String
    let timestamp: Date
    var transactionCard: TransactionCardData?
    var projectCreation: ProjectCreationData?
    var image: UIImage?
    var confirmedTransaction: Transaction?
    var isDeleted: Bool = false
    var spendingInsight: SpendingInsightData?
    var usesRichText: Bool = false

    init(role: ChatRole, content: String, timestamp: Date,
         transactionCard: TransactionCardData? = nil,
         projectCreation: ProjectCreationData? = nil,
         image: UIImage? = nil,
         confirmedTransaction: Transaction? = nil,
         isDeleted: Bool = false,
         spendingInsight: SpendingInsightData? = nil,
         usesRichText: Bool = false) {
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.transactionCard = transactionCard
        self.projectCreation = projectCreation
        self.image = image
        self.confirmedTransaction = confirmedTransaction
        self.isDeleted = isDeleted
        self.spendingInsight = spendingInsight
        self.usesRichText = usesRichText
    }
}

enum ChatRole { case user, assistant }

// MARK: - Shared Data Structs

struct ProjectCreationData {
    let projectName: String
    let projectIcon: String
    let projectColor: String
    init(projectName: String, projectIcon: String = "folder.fill", projectColor: String = "#A8E6CF") {
        self.projectName = projectName; self.projectIcon = projectIcon; self.projectColor = projectColor
    }
}

struct TransactionCardData {
    let amount: Double; let type: String; let groupName: String
    let categoryName: String; let categoryIcon: String; let categoryColorHex: String
    let note: String; let projectName: String?
    let isNewCategory: Bool; let suggestedCategory: String?; let parentGroup: String?
    init(amount: Double, type: String, groupName: String = "",
         categoryName: String, categoryIcon: String, categoryColorHex: String,
         note: String, projectName: String? = nil,
         isNewCategory: Bool = false, suggestedCategory: String? = nil, parentGroup: String? = nil) {
        self.amount = amount; self.type = type; self.groupName = groupName
        self.categoryName = categoryName; self.categoryIcon = categoryIcon; self.categoryColorHex = categoryColorHex
        self.note = note; self.projectName = projectName
        self.isNewCategory = isNewCategory; self.suggestedCategory = suggestedCategory; self.parentGroup = parentGroup
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage
    var onConfirm: ((TransactionCardData) -> Void)?
    var onCancel: (() -> Void)?
    var onSaveMemory: ((String, String, String?) -> Void)?
    var onCreateProject: ((ProjectCreationData) -> Void)?
    var onEdit: ((Transaction) -> Void)?
    var onDelete: ((Transaction) -> Void)?
    var onViewInsightDetail: (() -> Void)?

    @EnvironmentObject var store: AppStore
    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // AI 头像（左侧）
            if !isUser {
                AIChatAvatar(size: 36)
            } else {
                Spacer(minLength: 56)
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                // 消费洞察卡片
                if let insight = message.spendingInsight {
                    SpendingInsightCard(data: insight, onViewDetail: onViewInsightDetail)
                        .frame(maxWidth: UIScreen.main.bounds.width - 90)
                }
                // 交易确认卡片
                else if let card = message.transactionCard {
                    TransactionConfirmCard(
                        cardData: card,
                        onConfirm: onConfirm, onCancel: onCancel, onSaveMemory: onSaveMemory
                    )
                }
                // 项目创建卡片
                else if let proj = message.projectCreation {
                    ProjectCreationCard(projectData: proj, onCreateProject: onCreateProject)
                }
                // 图片
                else if let img = message.image {
                    Image(uiImage: img)
                        .resizable().scaledToFit()
                        .frame(maxWidth: 200, maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                }
                // 已删除
                else if message.isDeleted {
                    Text("🗑️ 已删除")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(Color.gray.opacity(0.6))
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(
                            UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 18, bottomTrailingRadius: 18, topTrailingRadius: 18)
                                .fill(ChatDesign.aiBubbleBg)
                        )
                }
                // 文本气泡（支持富文本）
                else if !message.content.isEmpty {
                    bubbleContent
                    // 入账后操作按钮
                    if let tx = message.confirmedTransaction {
                        confirmedActionButtons(tx: tx)
                    }
                }

                // 时间戳（洞察卡片跳过时间戳，其余都显示）
                if message.spendingInsight == nil && !message.content.isEmpty || message.isDeleted {
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(ChatDesign.surfaceVariant)
                        .padding(.horizontal, 4)
                }
            }

            if !isUser {
                Spacer(minLength: 40)
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        ))
    }

    // MARK: - Bubble Text Content

    @ViewBuilder
    private var bubbleContent: some View {
        Group {
            if isUser {
                Text(message.content)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(ChatDesign.onSurface)
            } else if message.usesRichText {
                RichChatTextView(text: message.content)
            } else {
                Text(message.content)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(ChatDesign.aiBubbleText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(bubbleBackground)
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if isUser {
            Color.white.opacity(0.92)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 22, bottomLeadingRadius: 22,
                    bottomTrailingRadius: 22, topTrailingRadius: 6
                ))
                .shadow(color: Color.black.opacity(0.03), radius: 12, x: 0, y: 2)
                .overlay(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 22, bottomLeadingRadius: 22,
                        bottomTrailingRadius: 22, topTrailingRadius: 6
                    ).stroke(ChatDesign.surfaceVariant.opacity(0.12), lineWidth: 1)
                )
        } else {
            ChatDesign.aiBubbleBg
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 6, bottomLeadingRadius: 22,
                    bottomTrailingRadius: 22, topTrailingRadius: 22
                ))
                .overlay(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 6, bottomLeadingRadius: 22,
                        bottomTrailingRadius: 22, topTrailingRadius: 22
                    ).stroke(ChatDesign.aiBubbleBorder, lineWidth: 1)
                )
                .shadow(color: ChatDesign.primaryContainer.opacity(0.12), radius: 10, x: 0, y: 3)
        }
    }

    // MARK: - Confirmed Action Buttons

    @ViewBuilder
    private func confirmedActionButtons(tx: Transaction) -> some View {
        HStack(spacing: 10) {
            Button(action: { onEdit?(tx) }) {
                HStack(spacing: 4) {
                    Image(systemName: "pencil").font(.system(size: 11, weight: .semibold))
                    Text("修改账单").font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundColor(ChatDesign.onPrimaryContainer)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(ChatDesign.primaryContainer.opacity(0.15))
                .clipShape(Capsule())
            }

            Button(action: { onDelete?(tx) }) {
                HStack(spacing: 4) {
                    Image(systemName: "trash").font(.system(size: 11, weight: .semibold))
                    Text("删除账单").font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundColor(Color(hex: "#EF4444"))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Color(hex: "#EF4444").opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .padding(.top, 2)
    }
}

// MARK: - Preview

#Preview {
    AIChatView()
        .environmentObject(AppStore(modelContext: try! ModelContainer(
            for: Project.self, Transaction.self, Category.self, ChatHistory.self, MemoryRule.self
        ).mainContext))
}
