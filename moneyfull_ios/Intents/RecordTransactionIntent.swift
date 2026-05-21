import AppIntents
import SwiftData

struct RecordTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "用钱小满记一笔"
    static var description = IntentDescription("使用自然语言记录一笔交易")
    
    @Parameter(title: "记账内容")
    var text: String
    
    static var parameterSummary: some ParameterSummary {
        Summary("记账：\(\.$text)")
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // 获取ModelContext
        let modelContext = try await MainActor.run {
            let container = try ModelContainer(
                for: Project.self, Transaction.self, Category.self, ChatHistory.self, MemoryRule.self
            )
            return container.mainContext
        }
        
        // 初始化服务
        let contextManager = ContextManager.shared
        await MainActor.run {
            contextManager.setModelContext(modelContext)
        }
        
        // 构建上下文
        let context: String
        do {
            context = try await MainActor.run {
                try contextManager.buildContext()
            }
        } catch {
            return .result(dialog: IntentDialog(stringLiteral: "无法获取分类信息，请稍后再试"))
        }
        
        // 调用LLM解析
        let result: TransactionParseResult
        do {
            result = try await LLMService.shared.parseTransaction(from: text, context: context)
        } catch {
            return .result(dialog: IntentDialog(stringLiteral: "无法解析记账内容，请重试"))
        }
        
        // 处理结果
        switch result.status {
        case "success":
            // 保存交易
            let success = await MainActor.run {
                saveTransactionSync(result: result, modelContext: modelContext)
            }
            
            if success {
                let amount = result.amount ?? 0
                let category = result.categoryName ?? "未分类"
                let type = result.type == "income" ? "收入" : "支出"
                return .result(dialog: IntentDialog(stringLiteral: "已记入\(type) \(amount) 元（\(category)）"))
            } else {
                return .result(dialog: IntentDialog(stringLiteral: "保存失败，请重试"))
            }
            
        case "suggest_new_category":
            let suggested = result.suggestedCategory ?? "新分类"
            return .result(dialog: IntentDialog(stringLiteral: "发现新分类「\(suggested)」，请在App中确认"))
            
        case "need_clarification":
            let reply = result.reply ?? "请补充更多信息"
            return .result(dialog: IntentDialog(stringLiteral: reply))
            
        default:
            return .result(dialog: IntentDialog(stringLiteral: "无法理解记账内容，请重试"))
        }
    }
    
    @MainActor
    private func saveTransactionSync(result: TransactionParseResult, modelContext: ModelContext) -> Bool {
        // 获取或创建项目
        let project: Project
        let projectDescriptor = FetchDescriptor<Project>(predicate: #Predicate { !$0.isArchived })
        
        do {
            let projects = try modelContext.fetch(projectDescriptor)
            if let existingProject = projects.first(where: { $0.name == result.projectName }) {
                project = existingProject
            } else if let firstProject = projects.first {
                project = firstProject
            } else {
                // 创建默认项目
                project = Project(
                    name: "日常收支",
                    icon: "wallet.bifold.fill",
                    colorHex: "#A8E6CF",
                    desc: "日常收支记录",
                    budget: 0
                )
                modelContext.insert(project)
            }
        } catch {
            return false
        }
        
        // 创建交易
        let transactionType: TransactionType = result.type == "income" ? .income : .expense
        let transaction = Transaction(
            amount: result.amount ?? 0,
            type: transactionType,
            categoryName: result.categoryName ?? "未分类",
            categoryIcon: result.categoryIcon ?? "tag.fill",
            categoryColorHex: result.categoryColorHex ?? "#A8E6CF",
            note: result.note ?? "",
            source: .voice
        )
        
        transaction.project = project
        modelContext.insert(transaction)
        
        // 保存聊天记录
        let chatHistory = ChatHistory(role: "user", content: result.note ?? "")
        modelContext.insert(chatHistory)
        
        do {
            try modelContext.save()
            return true
        } catch {
            return false
        }
    }
}
