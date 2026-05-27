import Foundation

class LLMService {
    static let shared = LLMService()
    
    private let apiKey: String
    private let baseURL: String
    private let model: String
    
    private init() {
        // 从Config中读取千问API配置
        self.apiKey = Config.llmAPIKey
        self.baseURL = Config.llmBaseURL
        self.model = Config.llmModel
    }
    
    func parseTransaction(from text: String, context: String) async throws -> TransactionParseResult {
        let systemPrompt = """
        你是用户的专属财务管家"小满"，语气专业、温暖、简洁。
        
        任务：从用户的自然语言中提取记账信息或分析意图，并严格按照JSON格式输出。
        
        核心规则：
        1. **精细化分类识别**：必须识别到一级分类(groupName)和二级分类(name)。
           - 例如"买咖啡花了25元"，必须识别出 groupName: "餐饮" 和 name: "咖啡"
           - 例如"打车花了30元"，必须识别出 groupName: "出行" 和 name: "交通"
        
        2. **分类匹配优先**：优先使用Context中提供的现有分类。
           - 如果二级分类完全匹配，使用现有分类
           - 如果二级分类部分匹配，使用最接近的现有分类
        
        3. **新分类建议**：如果用户提到的二级分类不存在，但属于合理的高频场景：
           - 返回状态 "suggest_new_category"
           - 提供 suggested_category（建议的二级分类名）
           - 提供 parent_group（建议的一级分类名）
        
        4. **模糊表达处理**：如果用户表达模糊（如"花了50"没说干嘛），不要猜测，返回：
           {"status": "need_clarification", "reply": "追问话术"}
        
        5. **完整信息输出**：如果信息完整且分类存在，输出：
           {"status": "success", "amount": 数字, "type": "expense/income", "groupName": "一级分类", "categoryName": "二级分类", "categoryIcon": "图标名", "categoryColorHex": "#颜色代码", "note": "备注", "project_name": "项目名或null"}
        
        6. **消费分析意图**：如果用户询问支出分析（如"分析餐饮支出"、"本月花了多少"），返回：
           {"status": "insight", "insight_type": "category_group", "target_group": "餐饮", "period": "last_month", "reply": "友好文案"}
           - insight_type 可选值：category_group（分类分析）、monthly_overview（月度概览）
           - period 可选值：last_month（上月）、this_month（本月）
           - reply 中可用 **双星号** 包裹需要强调的数字或关键词，例如：**¥1,280**、**15%**
           - 注意：reply 中不要编造具体金额，只写分析意图和引导语
        
        7. **富文本规则**：status 为 chat、need_clarification 时，reply 中可用 **双星号** 强调关键词。
        
        Context:
        \(context)
        """
        
        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": text]
        ]
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.1,
            "max_tokens": 500,
            "stream": false
        ]
        
        let url = URL(string: Config.chatCompletionsURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30 // 设置超时时间
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        #if DEBUG
        print("📤 API Request URL: \(url)")
        print("📤 API Request Headers: \(request.allHTTPHeaderFields ?? [:])")
        print("📤 API Request Body: \(String(data: request.httpBody!, encoding: .utf8) ?? "")")
        #endif
        
        // 使用自定义的URLSession配置
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        let session = URLSession(configuration: config)
        
        let (data, response) = try await session.data(for: request)
        
        #if DEBUG
        print("📥 API Response Status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        print("📥 API Response Data: \(String(data: data, encoding: .utf8) ?? "")")
        #endif
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.apiError
        }
        
        if httpResponse.statusCode != 200 {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            #if DEBUG
            print("❌ API Error: \(errorString)")
            #endif
            throw LLMError.apiError
        }
        
        let llmResponse = try JSONDecoder().decode(LLMResponse.self, from: data)
        guard let content = llmResponse.choices.first?.message.content else {
            throw LLMError.noContent
        }
        
        // 尝试解析JSON响应
        guard let jsonData = content.data(using: .utf8) else {
            throw LLMError.invalidJSON
        }
        
        // 先尝试解析为TransactionParseResult
        if let parseResult = try? JSONDecoder().decode(TransactionParseResult.self, from: jsonData) {
            return parseResult
        }
        
        // 如果JSON解析失败，说明是闲聊回复，返回chat状态
        return TransactionParseResult(
            status: "chat",
            amount: nil,
            type: nil,
            groupName: nil,
            categoryName: nil,
            categoryIcon: nil,
            categoryColorHex: nil,
            note: nil,
            projectName: nil,
            reply: content,
            suggestedCategory: nil,
            parentGroup: nil
        )
    }
    
    /// 解析OCR提取的账单文本
    func parseOCRText(from text: String, context: String) async throws -> TransactionParseResult {
        let systemPrompt = """
        你是用户的专属财务管家"小满"，语气专业、温暖、简洁。
        
        任务：从OCR提取的账单/支付截图文本中提取记账信息，并严格按照JSON格式输出。
        
        核心规则：
        1. **OCR文本容错**：输入文本来自iOS系统OCR识别，可能存在以下问题，请智能容错：
           - 字符误识别：如 "の" 实际是 "0"，"l" 是 "1"，"O" 是 "0"
           - 文本乱序：金额、商户名、时间可能不按阅读顺序排列
           - 包含无关内容：广告、界面按钮文字、导航栏文字等，请忽略
        
        2. **关键信息提取优先级**：
           - 金额（最重要）：寻找最大的数字，通常带¥或元符号，格式如 "¥25.00" "25元"
           - 商户/商品名：寻找有意义的中文名称（商家名、商品名）
           - 交易类型：支付宝/微信支付通常为支出，收款/转账收入为收入
        
        3. **分类识别**：
           - 根据商户/商品名推断一级分类(groupName)和二级分类(categoryName)
           - 例如：星巴克 → groupName: "吃喝", categoryName: "咖啡"
           - 例如：滴滴出行 → groupName: "出行", categoryName: "打车"
        
        4. **输出格式**：
           - 成功：{"status": "success", "amount": 数字, "type": "expense", "groupName": "一级分类", "categoryName": "二级分类", "categoryIcon": "图标名", "categoryColorHex": "#颜色代码", "note": "商户名/商品名", "projectName": null}
           - 无法识别：{"status": "need_clarification", "reply": "无法识别账单信息，请手动输入"}
        
        Context:
        \(context)
        """
        
        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": "以下是OCR提取的账单文本，请帮我提取记账信息：\n\n\(text)"]
        ]
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.1,
            "max_tokens": 500,
            "stream": false
        ]
        
        let url = URL(string: Config.chatCompletionsURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        let session = URLSession(configuration: config)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw LLMError.apiError
        }
        
        let llmResponse = try JSONDecoder().decode(LLMResponse.self, from: data)
        guard let content = llmResponse.choices.first?.message.content else {
            throw LLMError.noContent
        }
        
        guard let jsonData = content.data(using: .utf8) else {
            throw LLMError.invalidJSON
        }
        
        if let parseResult = try? JSONDecoder().decode(TransactionParseResult.self, from: jsonData) {
            return parseResult
        }
        
        return TransactionParseResult(
            status: "chat",
            amount: nil,
            type: nil,
            groupName: nil,
            categoryName: nil,
            categoryIcon: nil,
            categoryColorHex: nil,
            note: nil,
            projectName: nil,
            reply: content,
            suggestedCategory: nil,
            parentGroup: nil
        )
    }
    
    /// 生成月度财务建议
    func generateFinancialAdvice(expense: Double, income: Double, topCategories: [(name: String, amount: Double)]) async throws -> String {
        let categoryInfo = topCategories.prefix(5).map { "\($0.name): ¥\(Int($0.amount))" }.joined(separator: ", ")
        
        let systemPrompt = """
        你是用户的专属财务管家"小满"，语气专业、温暖、简洁。
        
        任务：根据用户的月度财务数据，给出个性化的财务建议和规划。
        
        要求：
        1. 分析支出结构，指出主要消费方向
        2. 如果支出过高，给出具体的节省建议（2-3条）
        3. 如果有结余，给出理财或储蓄建议
        4. 语气鼓励，不要批评用户
        5. 回复控制在150字以内
        """
        
        let userPrompt = """
        本月财务数据：
        - 总支出：¥\(Int(expense))
        - 总收入：¥\(Int(income))
        - 结余：¥\(Int(income - expense))
        - 主要支出类别：\(categoryInfo.isEmpty ? "暂无数据" : categoryInfo)
        
        请给出财务建议。
        """
        
        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userPrompt]
        ]
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 300,
            "stream": false
        ]
        
        let url = URL(string: Config.chatCompletionsURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        let session = URLSession(configuration: config)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw LLMError.apiError
        }
        
        let llmResponse = try JSONDecoder().decode(LLMResponse.self, from: data)
        guard let content = llmResponse.choices.first?.message.content else {
            throw LLMError.noContent
        }
        
        return content
    }
}

enum LLMError: Error {
    case apiError
    case noContent
    case invalidJSON
}

struct LLMResponse: Codable {
    let choices: [Choice]
}

struct Choice: Codable {
    let message: Message
}

struct Message: Codable {
    let content: String?
}

struct TransactionParseResult: Codable {
    let status: String
    let amount: Double?
    let type: String?
    let groupName: String?
    let categoryName: String?
    let categoryIcon: String?
    let categoryColorHex: String?
    let note: String?
    let projectName: String?
    let reply: String?
    let suggestedCategory: String?
    let parentGroup: String?
    // 消费洞察字段（可选，有默认值）
    var insightType: String? = nil  // "category_group" | "monthly_overview"
    var targetGroup: String? = nil  // 目标一级分类名，如 "餐饮"
    var period: String? = nil       // "last_month" | "this_month"
    
    enum CodingKeys: String, CodingKey {
        case status, amount, type, groupName, categoryName
        case categoryIcon, categoryColorHex, note, reply
        case projectName = "project_name"
        case suggestedCategory = "suggested_category"
        case parentGroup = "parent_group"
        case insightType = "insight_type"
        case targetGroup = "target_group"
        case period
    }
}