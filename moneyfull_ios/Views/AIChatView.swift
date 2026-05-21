import SwiftUI
import SwiftData
import PhotosUI

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
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color.App.textBlack)
                            .frame(width: 40, height: 40)
                    }
                    
                    Spacer()
                    
                    Text("AI 助手")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(Color.App.textBlack)
                    
                    Spacer()
                    
                    Button(action: {
                        // 清空聊天记录
                        messages.removeAll()
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 18))
                            .foregroundColor(Color.App.textBlack)
                            .frame(width: 40, height: 40)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
                
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
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
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
                VStack(spacing: 12) {
                    Divider()
                    
                    HStack(spacing: 12) {
                        // 图片选择按钮
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Image(systemName: "photo")
                                .font(.system(size: 20))
                                .foregroundColor(Color.App.darkGreen)
                                .frame(width: 40, height: 40)
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
                            Image(systemName: showVoiceInput ? "keyboard" : "mic.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color.App.darkGreen)
                                .frame(width: 40, height: 40)
                        }
                        
                        if showVoiceInput {
                            // 语音输入按钮
                            Button(action: {
                                if isRecording {
                                    stopRecording()
                                } else {
                                    startRecording()
                                }
                            }) {
                                Text(isRecording ? "松开发送" : "按住说话")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(isRecording ? Color.red : Color.App.darkGreen)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
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
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.App.tabBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                        
                        // 发送按钮
                        Button(action: {
                            sendMessage()
                        }) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(messageText.isEmpty ? Color.gray : Color.App.darkGreen)
                        }
                        .disabled(messageText.isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .background(Color.App.cardBackground)
            }
            .background(Color.App.backgroundGray.ignoresSafeArea())
            .onAppear {
                loadChatHistory()
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
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
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
                        .font(.system(size: 16))
                        .foregroundColor(message.role == .user ? .white : Color.App.textBlack)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(message.role == .user ? Color.App.darkGreen : Color.App.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
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