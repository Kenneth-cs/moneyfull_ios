import SwiftUI
import SwiftData
import PhotosUI

struct TypingIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.gray.opacity(0.5))
                .frame(width: 6, height: 6)
                .offset(y: isAnimating ? -4 : 0)
                .animation(.easeInOut(duration: 0.6).repeatForever().delay(0.0), value: isAnimating)
            
            Circle()
                .fill(Color.gray.opacity(0.5))
                .frame(width: 6, height: 6)
                .offset(y: isAnimating ? -4 : 0)
                .animation(.easeInOut(duration: 0.6).repeatForever().delay(0.2), value: isAnimating)
            
            Circle()
                .fill(Color.gray.opacity(0.5))
                .frame(width: 6, height: 6)
                .offset(y: isAnimating ? -4 : 0)
                .animation(.easeInOut(duration: 0.6).repeatForever().delay(0.4), value: isAnimating)
        }
        .onAppear {
            isAnimating = true
        }
    }
}
struct CapybaraAvatar: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            
            // 这里用一个简单的Emoji代替复杂的SVG，或者如果有的话可以用图片
            Text("🦫")
                .font(.system(size: 24))
        }
    }
}

struct AIChatView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var messageText = ""
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = false
    @State private var isRecording = false
    @State private var showVoiceInput = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    
    var initialText: String?
    var isFromShortcut: Bool = false
    
    private let speechService = SpeechService.shared
    private let llmService = LLMService.shared
    private let contextManager = ContextManager.shared
    private let visionService = VisionService.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // MARK: Header
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.25))
                            .clipShape(Circle())
                    }
                    
                    HStack(spacing: 12) {
                        ZStack(alignment: .bottomTrailing) {
                            CapybaraAvatar()
                                .frame(width: 40, height: 40)
                            
                            Circle()
                                .fill(Color(hex: "#34D399")) // 更明亮的在线绿点
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(Color(hex: "#10B981"), lineWidth: 2)) // 边框融入背景
                                .offset(x: 2, y: 2)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("AI 助手")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            Text("在线")
                                .font(.system(size: 12))
                                .foregroundColor(Color.white.opacity(0.9))
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        messages.removeAll()
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.25))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 16)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#10B981"), Color(hex: "#34D399")], // 加深顶部导航栏渐变 (emerald-500 to emerald-400)
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                
                // MARK: Chat Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(messages) { message in
                                ChatBubble(
                                    message: message,
                                    onConfirm: { cardData in
                                        handleTransactionConfirmed(cardData)
                                    },
                                    onCancel: {
                                        handleTransactionCancelled(message)
                                    },
                                    onSaveMemory: { keyword, categoryName, projectName in
                                        handleSaveMemory(keyword: keyword, categoryName: categoryName, projectName: projectName)
                                    },
                                    onCreateProject: { projectData in
                                        handleCreateProject(projectData)
                                    }
                                )
                                .id(message.id)
                            }
                            
                            if isLoading {
                                HStack(alignment: .center, spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 36, height: 36)
                                            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                                        CapybaraAvatar()
                                            .frame(width: 24, height: 24)
                                    }
                                    
                                    TypingIndicator()
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color.white)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .stroke(Color(hex: "#10B981").opacity(0.15), lineWidth: 1)
                                                )
                                                .shadow(color: Color(hex: "#10B981").opacity(0.08), radius: 8, x: 0, y: 4)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: messages.count) {
                        withAnimation {
                            proxy.scrollTo(messages.last?.id, anchor: .bottom)
                        }
                    }
                }
                
                // MARK: Input Area
                VStack(spacing: 0) {
                    Divider().background(Color.gray.opacity(0.1))
                    
                    HStack(spacing: 12) {
                        // 相册按钮
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Image(systemName: "photo")
                                .font(.system(size: 20))
                                .foregroundColor(Color.gray)
                                .frame(width: 36, height: 36)
                        }
                        .onChange(of: selectedPhotoItem) { oldValue, newValue in
                            Task {
                                if let data = try? await newValue?.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data) {
                                    selectedImage = image
                                    await processImage(image)
                                }
                            }
                        }
                        
                        // 语音/键盘切换按钮
                        Button(action: {
                            showVoiceInput.toggle()
                        }) {
                            Image(systemName: showVoiceInput ? "keyboard" : "mic")
                                .font(.system(size: 20))
                                .foregroundColor(Color.gray)
                                .frame(width: 36, height: 36)
                        }
                        
                        if showVoiceInput {
                            // 语音输入按钮
                            ZStack {
                                if isRecording {
                                    Text("松开发送")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color.App.redExpense)
                                        .clipShape(RoundedRectangle(cornerRadius: 20))
                                } else {
                                    Text("按住说话")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color.App.textBlack)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color.gray.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 20))
                                }
                            }
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in
                                        if !isRecording {
                                            startRecording()
                                        }
                                    }
                                    .onEnded { _ in
                                        if isRecording {
                                            stopRecording()
                                        }
                                    }
                            )
                        } else {
                            // 文字输入框
                            TextField("输入消息...", text: $messageText)
                                .font(.system(size: 14))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.gray.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                        
                        // 发送按钮
                        Button(action: {
                            sendMessage()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [Color(hex: "#10B981"), Color(hex: "#34D399")], // 加深发送按钮渐变
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 40, height: 40)
                                    .shadow(color: Color(hex: "#10B981").opacity(0.4), radius: 4, x: 0, y: 2)
                                
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .offset(x: -1, y: 1)
                            }
                        }
                        .disabled(messageText.isEmpty)
                        .opacity(messageText.isEmpty ? 0.5 : 1.0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color.white)
            }
            .background(
                LinearGradient(
                    colors: [Color.white, Color(hex: "#ECFDF5").opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                ).ignoresSafeArea()
            )
            .onAppear {
                loadChatHistory()
                if let text = initialText, !text.isEmpty {
                    if isFromShortcut {
                        // 快捷指令来源：不显示用户气泡，直接显示 AI 处理
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            processOCRText(text)
                        }
                    } else {
                        // 语音/手动输入：正常显示用户气泡
                        messageText = text
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            sendMessage()
                        }
                    }
                }
            }
        }
    }
    
    private func loadChatHistory() {
        // 从SwiftData加载最近的聊天记录
        // 这里简化处理，实际应该从ContextManager获取
    }
    
    private func handleTransactionConfirmed(_ cardData: TransactionCardData) {
        // 保存确认消息到聊天记录
        let confirmMessage = ChatMessage(
            role: .assistant,
            content: "已成功入账 \(cardData.type == "expense" ? "-" : "+")¥\(cardData.amount)（\(cardData.categoryName)）",
            timestamp: Date()
        )
        messages.append(confirmMessage)
        
        // 保存到SwiftData
        try? contextManager.saveChatHistory(role: "assistant", content: confirmMessage.content)
    }
    
    private func handleTransactionCancelled(_ message: ChatMessage) {
        // 更新消息显示为已取消
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index] = ChatMessage(
                role: .assistant,
                content: "已取消入账",
                timestamp: Date()
            )
        }
        
        // 保存到SwiftData
        try? contextManager.saveChatHistory(role: "assistant", content: "已取消入账")
    }
    
    private func handleSaveMemory(keyword: String, categoryName: String, projectName: String?) {
        do {
            try contextManager.saveMemoryRule(keyword: keyword, categoryName: categoryName, projectName: projectName)
            #if DEBUG
            print("✅ 记忆规则已保存: \(keyword) -> \(categoryName)")
            #endif
        } catch {
            #if DEBUG
            print("❌ 保存记忆规则失败: \(error)")
            #endif
        }
    }
    
    private func handleCreateProject(_ projectData: ProjectCreationData) {
        // 创建项目
        _ = store.addProject(
            name: projectData.projectName,
            icon: projectData.projectIcon,
            colorHex: projectData.projectColor,
            desc: "",
            budget: 0
        )
        
        // 添加确认消息
        let confirmMessage = ChatMessage(
            role: .assistant,
            content: "已成功创建项目「\(projectData.projectName)」",
            timestamp: Date()
        )
        messages.append(confirmMessage)
        
        // 保存到SwiftData
        try? contextManager.saveChatHistory(role: "assistant", content: confirmMessage.content)
        
        #if DEBUG
        print("✅ 项目已创建: \(projectData.projectName)")
        #endif
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        let userMessage = ChatMessage(
            role: .user,
            content: messageText,
            timestamp: Date()
        )
        messages.append(userMessage)
        
        let text = messageText
        messageText = ""
        
        // 保存用户消息到SwiftData
        try? contextManager.saveChatHistory(role: "user", content: text)
        
        // 调用LLM解析
        Task {
            await parseTransaction(from: text)
        }
    }
    
    private func processImage(_ image: UIImage) async {
        // 显示图片消息
        let imageMessage = ChatMessage(
            role: .user,
            content: "📷 [图片]",
            timestamp: Date(),
            image: image
        )
        
        await MainActor.run {
            messages.append(imageMessage)
            isLoading = true
        }
        
        // 显示识别中消息
        let processingMessage = ChatMessage(
            role: .assistant,
            content: "正在识别账单...",
            timestamp: Date()
        )
        
        await MainActor.run {
            messages.append(processingMessage)
        }
        
        do {
            // OCR提取文本
            let ocrText = try await visionService.extractCleanText(from: image)
            
            #if DEBUG
            print("📤 OCR提取文本: \(ocrText)")
            #endif
            
            // 获取context
            let context = try contextManager.buildContext()
            
            // 调用LLM解析OCR文本
            let result = try await llmService.parseOCRText(from: ocrText, context: context)
            
            await MainActor.run {
                // 移除"正在识别..."消息
                messages.removeAll { $0.id == processingMessage.id }
                
                // 处理结果
                handleParseResult(result)
                
                isLoading = false
            }
        } catch {
            await MainActor.run {
                // 移除"正在识别..."消息
                messages.removeAll { $0.id == processingMessage.id }
                
                let errorMessage = ChatMessage(
                    role: .assistant,
                    content: "图片识别失败：\(error.localizedDescription)",
                    timestamp: Date()
                )
                messages.append(errorMessage)
                
                isLoading = false
            }
        }
    }
    
    private func startRecording() {
        Task {
            let hasPermission = await speechService.requestPermission()
            guard hasPermission else {
                // 显示权限提示
                return
            }
            
            do {
                try speechService.startRecording()
                isRecording = true
            } catch {
                // 显示错误提示
            }
        }
    }
    
    private func stopRecording() {
        speechService.stopRecording()
        isRecording = false
        
        let transcribedText = speechService.transcribedText
        if !transcribedText.isEmpty {
            messageText = transcribedText
            sendMessage()
        }
    }
    
    private func parseTransaction(from text: String) async {
        isLoading = true
        
        do {
            let context = try contextManager.buildContext()
            let result = try await llmService.parseTransaction(from: text, context: context)
            
            await MainActor.run {
                handleParseResult(result)
                isLoading = false
            }
        } catch {
            await MainActor.run {
                let errorMessage = ChatMessage(
                    role: .assistant,
                    content: "抱歉，处理消息时出现错误，请重试。",
                    timestamp: Date()
                )
                messages.append(errorMessage)
                isLoading = false
            }
        }
    }
    
    private func processOCRText(_ ocrText: String) {
        Task {
            await MainActor.run {
                isLoading = true
                
                // 显示"正在识别账单..."消息
                let processingMessage = ChatMessage(
                    role: .assistant,
                    content: "正在识别账单...",
                    timestamp: Date()
                )
                messages.append(processingMessage)
            }
            
            do {
                // 获取context
                let context = try contextManager.buildContext()
                
                // 调用LLM解析OCR文本
                let result = try await llmService.parseOCRText(from: ocrText, context: context)
                
                await MainActor.run {
                    // 移除"正在识别..."消息
                    messages.removeAll { $0.role == .assistant && $0.content == "正在识别账单..." }
                    
                    // 处理结果
                    handleParseResult(result)
                    
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    // 移除"正在识别..."消息
                    messages.removeAll { $0.role == .assistant && $0.content == "正在识别账单..." }
                    
                    let errorMessage = ChatMessage(
                        role: .assistant,
                        content: "识别失败，请重试",
                        timestamp: Date()
                    )
                    messages.append(errorMessage)
                    
                    isLoading = false
                }
            }
        }
    }
    
    private func handleParseResult(_ result: TransactionParseResult) {
        if result.status == "success" {
            // 创建交易确认卡片
            let cardMessage = ChatMessage(
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
            messages.append(cardMessage)
            
            // 保存助手消息到SwiftData
            try? contextManager.saveChatHistory(role: "assistant", content: "交易确认卡片")
        } else if result.status == "suggest_new_category" {
            // 创建新分类建议卡片
            let cardMessage = ChatMessage(
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
            messages.append(cardMessage)
            
            // 保存助手消息到SwiftData
            try? contextManager.saveChatHistory(role: "assistant", content: "新分类建议卡片")
        } else if result.status == "need_clarification" {
            // 显示追问消息
            let clarificationMessage = ChatMessage(
                role: .assistant,
                content: result.reply ?? "请补充更多信息",
                timestamp: Date()
            )
            messages.append(clarificationMessage)
            
            // 保存助手消息到SwiftData
            try? contextManager.saveChatHistory(role: "assistant", content: result.reply ?? "请补充更多信息")
        } else if result.status == "chat" {
            // 闲聊回复
            let chatMessage = ChatMessage(
                role: .assistant,
                content: result.reply ?? "我主要负责帮您记账和管理财务哦～",
                timestamp: Date()
            )
            messages.append(chatMessage)
            
            // 保存助手消息到SwiftData
            try? contextManager.saveChatHistory(role: "assistant", content: result.reply ?? "我主要负责帮您记账和管理财务哦～")
        } else if result.status == "project_creation_requested" {
            // 项目创建请求
            let projectName = result.projectName ?? "新项目"
            let projectMessage = ChatMessage(
                role: .assistant,
                content: "已为您创建项目「\(projectName)」",
                timestamp: Date(),
                projectCreation: ProjectCreationData(projectName: projectName)
            )
            messages.append(projectMessage)
            
            // 保存助手消息到SwiftData
            try? contextManager.saveChatHistory(role: "assistant", content: "已创建项目：\(projectName)")
        }
    }
}

// MARK: - Chat Message Model
struct ChatMessage: Identifiable {
    let id = UUID()
    let role: ChatRole
    let content: String
    let timestamp: Date
    var transactionCard: TransactionCardData?
    var projectCreation: ProjectCreationData?
    var image: UIImage?
}

enum ChatRole {
    case user
    case assistant
}

// MARK: - Project Creation Data
struct ProjectCreationData {
    let projectName: String
    let projectIcon: String
    let projectColor: String
    
    init(projectName: String, projectIcon: String = "folder.fill", projectColor: String = "#A8E6CF") {
        self.projectName = projectName
        self.projectIcon = projectIcon
        self.projectColor = projectColor
    }
}

// MARK: - Transaction Card Data
struct TransactionCardData {
    let amount: Double
    let type: String
    let groupName: String
    let categoryName: String
    let categoryIcon: String
    let categoryColorHex: String
    let note: String
    let projectName: String?
    let isNewCategory: Bool
    let suggestedCategory: String?
    let parentGroup: String?
    
    init(amount: Double, type: String, groupName: String = "", categoryName: String, categoryIcon: String, categoryColorHex: String, note: String, projectName: String? = nil, isNewCategory: Bool = false, suggestedCategory: String? = nil, parentGroup: String? = nil) {
        self.amount = amount
        self.type = type
        self.groupName = groupName
        self.categoryName = categoryName
        self.categoryIcon = categoryIcon
        self.categoryColorHex = categoryColorHex
        self.note = note
        self.projectName = projectName
        self.isNewCategory = isNewCategory
        self.suggestedCategory = suggestedCategory
        self.parentGroup = parentGroup
    }
}

// MARK: - Chat Bubble
struct ChatBubble: View {
    let message: ChatMessage
    var onConfirm: ((TransactionCardData) -> Void)?
    var onCancel: (() -> Void)?
    var onSaveMemory: ((String, String, String?) -> Void)?
    var onCreateProject: ((ProjectCreationData) -> Void)?
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .user {
                Spacer()
            } else {
                // AI 头像
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 36, height: 36)
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                    CapybaraAvatar()
                        .frame(width: 24, height: 24)
                }
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if let cardData = message.transactionCard {
                    TransactionConfirmCard(cardData: cardData, onConfirm: onConfirm, onCancel: onCancel, onSaveMemory: onSaveMemory)
                } else if let projectData = message.projectCreation {
                    ProjectCreationCard(projectData: projectData, onCreateProject: onCreateProject)
                } else if let image = message.image {
                    // 图片消息
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 200, maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Text(message.content)
                        .font(.system(size: 15))
                        .foregroundColor(message.role == .user ? .white : Color(hex: "#1F2937"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            message.role == .user ?
                            AnyView(LinearGradient(
                                colors: [Color(hex: "#10B981"), Color(hex: "#34D399")], // 加深用户气泡渐变
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )) :
                            AnyView(
                                // AI 气泡：纯白背景 + 微弱的绿色边框 + 柔和阴影，拉开与背景的层次
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color(hex: "#10B981").opacity(0.15), lineWidth: 1)
                                    )
                                    .shadow(color: Color(hex: "#10B981").opacity(0.08), radius: 8, x: 0, y: 4)
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                // 时间
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundColor(Color.gray.opacity(0.6))
                    .padding(.horizontal, 4)
            }
            
            if message.role == .assistant {
                Spacer()
            }
        }
    }
}

#Preview {
    AIChatView()
        .environmentObject(AppStore(modelContext: try! ModelContainer(for: Project.self, Transaction.self, Category.self, ChatHistory.self, MemoryRule.self).mainContext))
}