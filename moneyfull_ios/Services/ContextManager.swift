import SwiftData
import Foundation

class ContextManager {
    static let shared = ContextManager()
    
    private var modelContext: ModelContext?
    
    private init() {}
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    func buildContext() throws -> String {
        guard let modelContext = modelContext else {
            throw ContextError.noModelContext
        }
        
        // 获取所有分类
        let categoryDescriptor = FetchDescriptor<Category>()
        let categories = try modelContext.fetch(categoryDescriptor)
        
        // 获取所有项目
        let projectDescriptor = FetchDescriptor<Project>(predicate: #Predicate { !$0.isArchived })
        let projects = try modelContext.fetch(projectDescriptor)
        
        // 获取记忆规则
        let memoryDescriptor = FetchDescriptor<MemoryRule>(sortBy: [SortDescriptor(\.weight, order: .reverse)])
        let memoryRules = try modelContext.fetch(memoryDescriptor)
        
        // 获取最近5条真实聊天记录（过滤预制消息）
        let chatDescriptor = FetchDescriptor<ChatHistory>(
            predicate: #Predicate { !$0.isPrescripted },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        let allChats = try modelContext.fetch(chatDescriptor)
        let recentChats = Array(allChats.prefix(5))
        
        // 构建上下文字符串
        var context = ""

        // 注入画像系统 Prompt（如有）
        if let systemPrompt = UserDefaults.standard.string(forKey: "aiPersonaSystemPrompt") {
            context += "System Context:\n\(systemPrompt)\n\n"
        }
        
        // 分类列表（按一级分类分组）
        context += "Available Categories (grouped by groupName):\n"
        let groupedCategories = Dictionary(grouping: categories) { $0.groupName.isEmpty ? "其他" : $0.groupName }
        for (groupName, groupCategories) in groupedCategories.sorted(by: { $0.key < $1.key }) {
            context += "【\(groupName)】\n"
            for category in groupCategories {
                context += "  - \(category.name) (icon: \(category.icon), color: \(category.colorHex))\n"
            }
        }
        
        // 获取最近5条交易记录，用于动态推断活跃项目
        let transactionDescriptor = FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let allTransactions = try modelContext.fetch(transactionDescriptor)
        let recentTransactions = Array(allTransactions.prefix(5))
        
        // 统计最近交易中各项目的出现次数
        var projectFrequency: [String: Int] = [:]
        for transaction in recentTransactions {
            if let projectName = transaction.project?.name, projectName != "日常收支" {
                projectFrequency[projectName, default: 0] += 1
            }
        }
        
        // 找出高频活跃项目（最近5条中3条及以上）
        let highFrequencyProjects = projectFrequency.filter { $0.value >= 3 }.map { $0.key }
        
        // 项目列表（带活跃标记）
        context += "\nAvailable Projects:\n"
        for project in projects {
            var marker = ""
            if project.isActiveProject {
                marker = " (当前活跃项目⭐)"
            } else if highFrequencyProjects.contains(project.name) {
                marker = " (近期高频活跃)"
            }
            context += "- \(project.name)\(marker)\n"
        }
        
        // 记忆规则
        if !memoryRules.isEmpty {
            context += "\nUser Memory Rules:\n"
            for rule in memoryRules {
                context += "- keyword: \(rule.keyword), category: \(rule.targetCategoryName)"
                if !rule.targetProjectName.isEmpty {
                    context += ", project: \(rule.targetProjectName)"
                }
                context += "\n"
            }
        }
        
        // 最近聊天记录
        if !recentChats.isEmpty {
            context += "\nRecent Chat History:\n"
            for chat in recentChats.reversed() {
                let role = chat.role == "user" ? "User" : "Assistant"
                context += "\(role): \(chat.content)\n"
            }
        }
        
        return context
    }
    
    /// 保存聊天记录，返回新建记录的 UUID（可忽略）
    /// 调用方可存储此 ID，用于后续通过 updateChatHistoryContent 同步修改记录内容
    @discardableResult
    func saveChatHistory(role: String, content: String, isPrescripted: Bool = false) throws -> UUID {
        guard let modelContext = modelContext else {
            throw ContextError.noModelContext
        }
        
        let chat = ChatHistory(role: role, content: content, isPrescripted: isPrescripted)
        modelContext.insert(chat)
        try modelContext.save()
        #if DEBUG
        print("💾 saveChatHistory: 已保存 \(role) 消息: \(content.prefix(50))\(isPrescripted ? " [预制]" : "")")
        #endif
        return chat.id
    }

    /// 通过记录 ID 更新聊天历史的文本内容（用于修改账单后同步气泡文字）
    func updateChatHistoryContent(id: UUID, newContent: String) {
        guard let modelContext = modelContext else { return }
        let descriptor = FetchDescriptor<ChatHistory>(predicate: #Predicate { $0.id == id })
        guard let record = (try? modelContext.fetch(descriptor))?.first else {
            #if DEBUG
            print("⚠️ updateChatHistoryContent: 未找到 id=\(id) 的记录")
            #endif
            return
        }
        record.content = newContent
        try? modelContext.save()
        #if DEBUG
        print("✏️ updateChatHistoryContent: 已更新记录内容 → \(newContent.prefix(50))")
        #endif
    }
    
    func fetchChatHistory(limit: Int = 50) -> [ChatHistory] {
        guard let modelContext = modelContext else {
            #if DEBUG
            print("⚠️ fetchChatHistory: modelContext 为 nil")
            #endif
            return []
        }
        var descriptor = FetchDescriptor<ChatHistory>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]  // 最新的先取
        )
        descriptor.fetchLimit = limit
        let result = (try? modelContext.fetch(descriptor)) ?? []
        #if DEBUG
        print("📋 fetchChatHistory: 从数据库获取到 \(result.count) 条记录")
        #endif
        return result.reversed()  // 翻转回正序，UI 从上到下显示旧→新
    }
    
    func clearChatHistory() {
        guard let modelContext = modelContext else { return }
        try? modelContext.delete(model: ChatHistory.self)
        try? modelContext.save()
    }
    
    func saveMemoryRule(keyword: String, categoryName: String, projectName: String?) throws {
        guard let modelContext = modelContext else {
            throw ContextError.noModelContext
        }
        
        // 检查是否已存在相同关键词的规则
        let keyword = keyword.lowercased()
        let descriptor = FetchDescriptor<MemoryRule>(predicate: #Predicate { $0.keyword == keyword })
        let existingRules = try modelContext.fetch(descriptor)
        
        if let existingRule = existingRules.first {
            // 更新现有规则的权重
            existingRule.weight += 1
            existingRule.targetCategoryName = categoryName
            if let projectName = projectName {
                existingRule.targetProjectName = projectName
            }
        } else {
            // 创建新规则
            let rule = MemoryRule(
                keyword: keyword,
                targetCategoryName: categoryName,
                targetProjectName: projectName ?? ""
            )
            modelContext.insert(rule)
        }
        
        try modelContext.save()
    }
}

enum ContextError: Error {
    case noModelContext
}