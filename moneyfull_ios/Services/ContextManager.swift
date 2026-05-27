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
        
        // 获取最近5条聊天记录
        let chatDescriptor = FetchDescriptor<ChatHistory>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        let allChats = try modelContext.fetch(chatDescriptor)
        let recentChats = Array(allChats.prefix(5))
        
        // 构建上下文字符串
        var context = ""
        
        // 分类列表（按一级分类分组）
        context += "Available Categories (grouped by groupName):\n"
        let groupedCategories = Dictionary(grouping: categories) { $0.groupName.isEmpty ? "其他" : $0.groupName }
        for (groupName, groupCategories) in groupedCategories.sorted(by: { $0.key < $1.key }) {
            context += "【\(groupName)】\n"
            for category in groupCategories {
                context += "  - \(category.name) (icon: \(category.icon), color: \(category.colorHex))\n"
            }
        }
        
        // 项目列表
        context += "\nAvailable Projects:\n"
        for project in projects {
            context += "- \(project.name)\n"
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
    
    func saveChatHistory(role: String, content: String) throws {
        guard let modelContext = modelContext else {
            throw ContextError.noModelContext
        }
        
        let chat = ChatHistory(role: role, content: content)
        modelContext.insert(chat)
        try modelContext.save()
    }
    
    func fetchChatHistory(limit: Int = 50) -> [ChatHistory] {
        guard let modelContext = modelContext else { return [] }
        var descriptor = FetchDescriptor<ChatHistory>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
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