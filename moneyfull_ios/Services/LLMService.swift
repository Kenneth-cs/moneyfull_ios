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
        
        5. **项目归属规则 (project_name)**，按以下优先级匹配（非常重要，必须严格执行）：
           - **第一层（最高优先级）：用户直接指令**
             * 如果用户明确提及项目名称（如"记到旅游里"、"记在装修"），直接归入该项目
           - **第二层：活跃项目（⭐标星项目）**
             * 检查 Context 中是否有标记为 `(当前活跃项目⭐)` 或 `(近期高频活跃)` 的项目
             * 如果有，**无论 User Memory Rules 中记录了什么项目，都必须将 project_name 设为该活跃项目**
             * 活跃项目代表用户当前的记账意图，优先级高于一切历史记忆规则
           - **第三层：记忆规则**
             * 只有在没有任何活跃项目的情况下，才参考 User Memory Rules 中的 project 字段
             * 注意：记忆规则中的 category 信息（分类）始终可以参考，但 project 字段在有活跃项目时忽略
           - **第四层：语义推断**
             * 只在无活跃项目时，根据消费特征（如酒店、机票、景区）推断项目
           - **兜底**：以上都不满足时，project_name 设为 null（系统自动归入"日常收支"）
        
        6. **备注规则 (note)**：
           - 备注是用户消费的简短描述，**不包含金额信息**
           - 例如：用户说"买咖啡花了25元"，note 应为 "买咖啡"
           - 例如：用户说"打车花了30块"，note 应为 "打车"
           - 例如：用户说"星巴克拿铁，给朋友买的"，note 应为 "星巴克拿铁，给朋友买的"
           - 如果用户没有提供额外描述，note 可以为分类名称（如 "咖啡"）

        7. **完整信息输出**：如果信息完整且分类存在，输出：
           {"status": "success", "amount": 数字, "type": "expense/income", "groupName": "一级分类", "categoryName": "二级分类", "categoryIcon": "图标名", "categoryColorHex": "#颜色代码", "note": "备注（不含金额）", "project_name": "项目名或null"}

        8. **消费分析意图**：如果用户询问支出分析（如"分析餐饮支出"、"本月花了多少"），返回：
           {"status": "insight", "insight_type": "category_group", "target_group": "餐饮", "period": "last_month", "reply": "友好文案"}
           - insight_type 可选值：category_group（分类分析）、monthly_overview（月度概览）
           - period 可选值：last_month（上月）、this_month（本月）
           - reply 中可用 **双星号** 包裹需要强调的数字或关键词，例如：**¥1,280**、**15%**
           - 注意：reply 中不要编造具体金额，只写分析意图和引导语
        
        9. **富文本规则**：status 为 chat、need_clarification 时，reply 中可用 **双星号** 强调关键词。

        10. **工时记录识别**：如果用户提到工时/工作时间（如"今天干了3小时"、"昨天工作8小时"），识别为 time_entry：
           {"status": "success", "time_entry_hours": 数字, "time_entry_rate": 时薪数字或null, "time_entry_note": "任务描述", "project_name": "项目名或null", "reply": "已记录工时"}
           - time_entry_hours：工时数量（小时）
           - time_entry_rate：时薪（如果用户提到的话，否则为 null）
           - time_entry_note：任务简述
           - 注意：工时记录时 amount/type/categoryName 等字段都设为 null
        
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
        
        // 记录Token使用量
        if let usage = llmResponse.usage {
            TokenMonitor.shared.record(tokens: usage.totalTokens)
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
           - 交易类型判断（非常重要）：
             * 金额前有 **加号 +** 或标注"收入"/"收款"/"转账收入" → type: "income"
             * 金额前有 **减号 -** 或标注"支出"/"付款"/"消费" → type: "expense"
             * 商品说明包含"转入"/"收款"/"到账"/"退款" → type: "income"
             * 商品说明包含"转出"/"付款"/"消费" → type: "expense"
             * 支付宝/微信支付默认为支出
             * 示例："+19.90" 表示收入，"-25.00" 或 "25元" 表示支出
             * 示例："余额宝-单次转入" 表示收入，"余额宝-单次转出" 表示支出
        
        3. **分类识别**：
           - 根据商户/商品名推断一级分类(groupName)和二级分类(categoryName)
           - 例如：星巴克 → groupName: "吃喝", categoryName: "咖啡"
           - 例如：滴滴出行 → groupName: "出行", categoryName: "打车"
           - 收入类：工资、红包、退款、转账收入、转入等
        
        4. **项目归属规则 (project_name)**，按以下优先级匹配（非常重要）：
           - **第一层（最高优先级）：用户直接指令**
             * 如果用户明确提及项目名称（如"记到旅游里"、"记在装修"），直接归入该项目
           - **第二层：活跃项目（⭐标星项目）**
             * 优先归入标记为 `(当前活跃项目⭐)` 的项目
             * 活跃项目是用户主动设置的，代表用户当前的记账意图，优先级高于记忆规则
             * **重要**：如果有活跃项目，所有消费（包括星巴克、机票等）都优先记入活跃项目
           - **第三层：记忆规则**
             * 检查 Context 中的 User Memory Rules，如果关键词匹配，归入对应项目
             * 注意：记忆规则优先级低于活跃项目，因为活跃项目代表用户当前意图
           - **第四层：语义推断**
             * 消费特征明显（如酒店、景区、机票）且存在相关名称项目，自动推断归入
             * 注意：仅在无活跃项目时才使用语义推断
           - **兜底**：如果以上都不满足，project_name 设为 null（归入默认的"日常收支"）
        
        5. **输出格式**：
           - 支出成功：{"status": "success", "amount": 数字, "type": "expense", "groupName": "一级分类", "categoryName": "二级分类", "categoryIcon": "图标名", "categoryColorHex": "#颜色代码", "note": "商户名/商品名", "project_name": "项目名或null"}
           - 收入成功：{"status": "success", "amount": 数字, "type": "income", "groupName": "收入", "categoryName": "工资/红包/退款等", "categoryIcon": "图标名", "categoryColorHex": "#颜色代码", "note": "备注", "project_name": "项目名或null"}
           - 无法识别：{"status": "need_clarification", "reply": "无法识别账单信息，请手动输入"}
           - 需要澄清项目：{"status": "need_clarification", "reply": "这笔支出是记在旅游还是装修里呢？"}
        
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
        
        // 记录Token使用量
        if let usage = llmResponse.usage {
            TokenMonitor.shared.record(tokens: usage.totalTokens)
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
    
    // MARK: - 预算分类 AI 生成
    
    /// 生成预算分类明细
    func generateBudgetBreakdown(name: String, desc: String, supplement: String,
                                  totalBudget: Double, mode: String) async throws -> [BudgetItemUI] {
        let systemPrompt = """
        你是一个预算规划专家。用户正在创建一个「\(mode)」类项目，请根据信息生成合理的预算分类明细。

        项目名称：\(name)
        项目描述：\(desc.isEmpty ? "根据名字推断" : desc)
        用户补充：\(supplement.isEmpty ? "无" : supplement)
        总预算：¥\(Int(totalBudget))
        项目模式：\(mode)

        要求：
        1. 生成 5-8 个分类，覆盖该类项目的主要花销场景
        2. 所有分类金额之和 = 总预算（必须严格相等）
        3. 比例合理，参考真实消费习惯；金额规模不同比例也不同
        4. 使用合适的 SF Symbol 图标名（v5+）和莫兰迪色系 hex
        5. 搞钱模式重点考虑：工具/软件、差旅、外包等成本项

        返回严格 JSON，无其他内容：
        {
          "budget_items": [
            {"name": "交通", "icon": "car.fill", "colorHex": "#A8E0C2", "amount": 800},
            ...
          ],
          "reasoning": "一句话说明分配逻辑"
        }
        """
        
        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": "请为我生成预算分类"]
        ]
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.1,
            "max_tokens": 800,
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
        
        // 记录Token使用量
        if let usage = llmResponse.usage {
            TokenMonitor.shared.record(tokens: usage.totalTokens)
        }
        
        guard let jsonData = content.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let items = json["budget_items"] as? [[String: Any]] else {
            throw LLMError.invalidJSON
        }
        
        return items.compactMap { dict in
            guard let name = dict["name"] as? String,
                  let icon = dict["icon"] as? String,
                  let colorHex = dict["colorHex"] as? String,
                  let amount = dict["amount"] as? Double else { return nil }
            return BudgetItemUI(categoryName: name, categoryIcon: icon,
                               categoryColorHex: colorHex, amount: amount)
        }
    }
    
    // MARK: - 经营洞察（搞钱模式）
    
    /// 生成经营洞察
    func generateEarningInsight(project: Project) async throws -> String {
        let categorySpend = (project.transactions ?? [])
            .filter { $0.type == .expense }
            .reduce(into: [String: Double]()) { $0[$1.categoryName, default: 0] + abs($1.amount) }
            .map { "\($0.key): ¥\(Int($0.value))" }
            .joined(separator: ", ")
        
        let systemPrompt = """
        你是项目财务顾问，分析以下接单项目数据，给出 2-3 条简洁洞察。

        项目：\(project.name)
        总收入：¥\(Int(project.totalIncome))（目标：¥\(Int(project.targetIncome))）
        时间成本：¥\(Int(project.totalTimeCost))（\(project.totalHourEquivalent.formatted(.number.precision(.fractionLength(1))))h，平均时薪 ¥\(Int(project.defaultRate))/h）
        其他支出：¥\(Int(project.totalSpent))（细目：\(categorySpend.isEmpty ? "暂无" : categorySpend)）
        净利润：¥\(Int(project.netProfit))
        实际时薪：¥\(project.effectiveHourlyRate.formatted(.number.precision(.fractionLength(1))))/h（目标：¥\(Int(project.defaultRate))/h）

        请用中文给出洞察，语气鼓励，不用嘲讽，格式：
        - 关键发现（一句话）
        - 原因分析（一句话）
        - 下次建议（一句话）
        """
        
        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": "请分析我的项目经营状况"]
        ]
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.5,
            "max_tokens": 400,
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
        
        // 记录Token使用量
        if let usage = llmResponse.usage {
            TokenMonitor.shared.record(tokens: usage.totalTokens)
        }
        
        return content
    }
    
    // MARK: - 项目复盘（结构化版本）
    
    /// 生成项目复盘总结（接收预计算统计数据）
    func generateProjectReview(
        projectName: String,
        mode: String,
        lifestyleStats: LifestyleProjectStats? = nil,
        earningStats: EarningProjectStats? = nil
    ) async throws -> ProjectReviewResult {
        let systemPrompt: String
        if mode == "earning", let s = earningStats {
            let achievementText = s.targetAchievement.map { "\(Int($0 * 100))%" } ?? "未设目标"
            systemPrompt = """
            你是「\(projectName)」项目的经营复盘顾问。请基于以下数据生成复盘报告。

            ## 项目基础信息
            - 项目名称：\(projectName)
            - 项目类型：搞钱模式

            ## 盈利能力
            - 总收入：¥\(Int(s.totalIncome))
            - 总支出（物质成本）：¥\(Int(s.totalExpense))
            - 时间成本：¥\(Int(s.timeCost))
            - 总成本：¥\(Int(s.totalCost))
            - 净利润：¥\(Int(s.netProfit))
            - 利润率：\(Int(s.profitMargin * 100))%（\(s.profitMarginLabel)）
            - ROI：\(s.roi.formatted(.number.precision(.fractionLength(1))))%（\(s.roiRating)）
            - 目标收入：¥\(Int(s.targetIncome))
            - 目标达成率：\(achievementText)

            ## 时间价值
            - 总工时：\(s.totalHours.formatted(.number.precision(.fractionLength(1))))h
            - 真实时薪：¥\(s.effectiveHourlyRate.formatted(.number.precision(.fractionLength(1))))/h（\(s.hourlyRateLabel)）
            - 日均投入：\(s.dailyHours.formatted(.number.precision(.fractionLength(1))))h（\(s.dailyHoursLabel)）
            - 工时分布：前半段 \(s.firstHalfHours.formatted(.number.precision(.fractionLength(1))))h / 后半段 \(s.secondHalfHours.formatted(.number.precision(.fractionLength(1))))h

            ## 成本结构
            - 时间成本占比：\(Int(s.timeCostRatio * 100))%
            - 物质成本占比：\(Int(s.materialCostRatio * 100))%
            - 最大支出项：\(s.topExpenseName) ¥\(Int(s.topExpenseAmount))（占比 \(Int(s.topExpenseContribution * 100))%）
            - 固定成本：¥\(Int(s.fixedMonthlyCost))/月

            ## 经营效率
            - 收入节奏：前半段 \(Int(s.incomeFirstHalfRatio * 100))% / 后半段 \(Int(s.incomeSecondHalfRatio * 100))%（\(s.incomeTimingLabel)）
            - 支出节奏：前半段 \(Int(s.expenseFirstHalfRatio * 100))% / 后半段 \(Int(s.expenseSecondHalfRatio * 100))%（\(s.expenseTimingLabel)）
            - 本月净现金流：¥\(Int(s.monthlyNetCashFlow))（\(s.cashFlowStatus)）

            ## 要求
            1. 生成 4 个维度的洞察（盈利能力、时间价值、成本结构、经营效率）
            2. 每条洞察必须引用 ≥1 个具体数字
            3. 给出利润率/时薪的行业基准线对比
            4. 不要做主观推测（如"你可能…"）
            5. 给出下次接单的具体报价和预算建议
            6. 返回严格 JSON 格式，不要添加其他文字

            ## 输出格式
            {
              "highlights": [
                {"icon": "💰", "label": "盈利能力", "text": "..."},
                {"icon": "⏱️", "label": "时间价值", "text": "..."},
                {"icon": "📦", "label": "成本结构", "text": "..."},
                {"icon": "📈", "label": "经营效率", "text": "..."}
              ],
              "one_liner": "一句话总结（15字以内）",
              "next_quote": {
                "suggested_amount": 11900,
                "reason": "计算逻辑"
              },
              "next_budget": [
                {"name": "成本项", "amount": 1000, "reason": "计算逻辑"}
              ]
            }
            """
        } else if let s = lifestyleStats {
            // 分类明细文本
            let catText = s.categoryBreakdown.map { c in
                let deltaText = c.delta >= 0 ? "超支 ¥\(Int(c.delta))" : "节省 ¥\(Int(abs(c.delta)))"
                return "- \(c.name)：预算 ¥\(Int(c.budgeted))，实际 ¥\(Int(c.actual))，执行率 \(Int(c.ratio * 100))%，\(deltaText)"
            }.joined(separator: "\n")

            systemPrompt = """
            你是「\(projectName)」项目的财务复盘顾问。请基于以下数据生成复盘报告。

            ## 项目基础信息
            - 项目名称：\(projectName)
            - 项目类型：生活模式
            - 持续天数：\(s.totalDays) 天

            ## 预算执行
            - 总预算：¥\(Int(s.budget))
            - 总支出：¥\(Int(s.totalSpent))
            - 预算执行率：\(Int(s.budgetProgress * 100))%
            - 节省/超支：¥\(Int(abs(s.budget - s.totalSpent)))

            ## 分类预算明细
            \(catText.isEmpty ? "暂无分类预算" : catText)

            ## 消费结构
            - 消费集中度（HHI）：\(String(format: "%.2f", s.hhiIndex))（\(s.hhiLabel)）
            - 大件消费：¥\(Int(s.bigItemAmount))（\(Int(s.bigItemRatio * 100))%）
            - 日常自由消费：¥\(Int(s.dailyFreeAmount))/天
            - 最大单笔：¥\(Int(s.maxSingleAmount))（\(s.maxSingleCategory)）
            - 平均单笔：¥\(Int(s.avgSingleAmount))
            - 中位数单笔：¥\(Int(s.medianSingleAmount))
            - 波动系数：\(String(format: "%.1f", s.volatility))x

            ## 时间分布
            - 前半段消费：¥\(Int(s.firstHalfSpent))（\(Int(s.firstHalfRatio * 100))%）
            - 后半段消费：¥\(Int(s.secondHalfSpent))（\(Int(s.secondHalfRatio * 100))%）
            - 消费高峰日：第 \(s.peakDayNumber) 天，¥\(Int(s.peakDayAmount))
            - 日均记账笔数：\(String(format: "%.1f", s.avgDailyTransactions))

            ## 要求
            1. 生成 4 个维度的洞察（预算执行、消费结构、时间分析、最佳表现）
            2. 每条洞察必须引用 ≥1 个具体数字
            3. 不要做主观推测（如"你可能…"）
            4. 给出下次同类项目的具体预算建议（分类级别）
            5. 返回严格 JSON 格式，不要添加其他文字

            ## 输出格式
            {
              "highlights": [
                {"icon": "🎯", "label": "预算控制", "text": "..."},
                {"icon": "📊", "label": "消费结构", "text": "..."},
                {"icon": "⏱️", "label": "消费节奏", "text": "..."},
                {"icon": "🏆", "label": "最佳表现", "text": "..."}
              ],
              "one_liner": "一句话总结（15字以内）",
              "next_budget": [
                {"name": "分类名", "amount": 1000, "reason": "计算逻辑"}
              ]
            }
            """
        } else {
            return .fallback(message: "数据不足，无法生成复盘")
        }

        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": "请生成项目复盘总结"]
        ]
        let requestBody: [String: Any] = [
            "model": model, "messages": messages,
            "temperature": 0.3, "max_tokens": 900, "stream": false
        ]

        let url = URL(string: Config.chatCompletionsURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30
        sessionConfig.timeoutIntervalForResource = 60
        let session = URLSession(configuration: sessionConfig)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw LLMError.apiError
        }

        let llmResponse = try JSONDecoder().decode(LLMResponse.self, from: data)
        guard let content = llmResponse.choices.first?.message.content else {
            throw LLMError.noContent
        }

        if let usage = llmResponse.usage {
            TokenMonitor.shared.record(tokens: usage.totalTokens)
        }

        // 使用加固解析器
        if let result = ProjectReviewJSONParser.parse(content: content) {
            return result
        }
        // 解析失败降级，而非抛错
        return .fallback(message: "AI 暂时无法生成分析，请稍后重试")
    }
}

enum LLMError: Error {
    case apiError
    case noContent
    case invalidJSON
}

struct LLMResponse: Codable {
    let choices: [Choice]
    let usage: Usage?
}

struct Usage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
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
    // 工时记录字段（可选）
    var timeEntryHours: Double? = nil
    var timeEntryRate: Double? = nil
    var timeEntryNote: String? = nil
    
    enum CodingKeys: String, CodingKey {
        case status, amount, type, groupName, categoryName
        case categoryIcon, categoryColorHex, note, reply
        case projectName = "project_name"
        case suggestedCategory = "suggested_category"
        case parentGroup = "parent_group"
        case insightType = "insight_type"
        case targetGroup = "target_group"
        case period
        case timeEntryHours = "time_entry_hours"
        case timeEntryRate = "time_entry_rate"
        case timeEntryNote = "time_entry_note"
    }
}