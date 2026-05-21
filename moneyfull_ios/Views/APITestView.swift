import SwiftUI

struct APITestView: View {
    @State private var testResult = ""
    @State private var isLoading = false
    @State private var testInput = "买咖啡花了25元"
    @State private var showContext = false
    @State private var contextText = ""
    
    private let contextManager = ContextManager.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 配置信息
                VStack(alignment: .leading, spacing: 10) {
                    Text("当前配置")
                        .font(.headline)
                    
                    HStack {
                        Text("API 地址:")
                        Spacer()
                        Text(Config.llmBaseURL)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("模型:")
                        Spacer()
                        Text(Config.llmModel)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("API Key:")
                        Spacer()
                        Text(Config.llmAPIKey.prefix(10) + "...")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.App.tabBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // 测试输入
                VStack(alignment: .leading, spacing: 10) {
                    Text("测试输入")
                        .font(.headline)
                    
                    TextField("输入测试文本", text: $testInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding()
                .background(Color.App.tabBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // 测试按钮
                Button(action: {
                    testAPI()
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                        Text(isLoading ? "测试中..." : "测试 API 连接")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.App.darkGreen)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isLoading)
                
                // 测试结果
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("测试结果")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: {
                            showContext.toggle()
                        }) {
                            Text(showContext ? "隐藏Context" : "显示Context")
                                .font(.caption)
                        }
                    }
                    
                    ScrollView {
                        if showContext && !contextText.isEmpty {
                            Text("📤 发送给AI的Context:\n")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.blue)
                            Text(contextText)
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text(testResult)
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(height: 200)
                    .padding()
                    .background(Color.black.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
                .background(Color.App.tabBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Spacer()
            }
            .padding()
            .navigationTitle("API 测试")
        }
    }
    
    private func testAPI() {
        isLoading = true
        testResult = "开始测试...\n"
        
        Task {
            do {
                // 使用contextManager获取真实context
                let context: String
                do {
                    context = try contextManager.buildContext()
                    await MainActor.run {
                        contextText = context
                    }
                } catch {
                    // 如果contextManager失败，使用默认context
                    context = """
                    Available Categories (grouped by groupName):
                    【餐饮】
                      - 咖啡 (icon: cup.and.saucer.fill, color: #A8E6CF)
                      - 外卖 (icon: takeoutbag.and.cup.and.straw.fill, color: #A8E6CF)
                    【出行】
                      - 交通 (icon: car.fill, color: #B3D1E6)
                    【购物】
                      - 购物 (icon: bag.fill, color: #F6D7A8)
                    
                    Available Projects:
                    - 日常开销
                    - 旅行基金
                    """
                }
                
                testResult += "📤 发送请求...\n\n"
                
                let result = try await LLMService.shared.parseTransaction(
                    from: testInput,
                    context: context
                )
                
                await MainActor.run {
                    testResult += "✅ API 调用成功\n\n"
                    testResult += "解析结果:\n"
                    testResult += "状态: \(result.status)\n"
                    
                    if result.status == "success" {
                        testResult += "金额: \(result.amount ?? 0)\n"
                        testResult += "类型: \(result.type ?? "未知")\n"
                        testResult += "一级分类: \(result.groupName ?? "未识别")\n"
                        testResult += "二级分类: \(result.categoryName ?? "未识别")\n"
                        testResult += "图标: \(result.categoryIcon ?? "未知")\n"
                        testResult += "颜色: \(result.categoryColorHex ?? "未知")\n"
                        testResult += "备注: \(result.note ?? "无")\n"
                        testResult += "项目: \(result.projectName ?? "无")\n"
                    } else if result.status == "suggest_new_category" {
                        testResult += "建议新分类:\n"
                        testResult += "建议分类名: \(result.suggestedCategory ?? "未知")\n"
                        testResult += "归属一级分类: \(result.parentGroup ?? "未知")\n"
                        testResult += "金额: \(result.amount ?? 0)\n"
                    } else if result.status == "need_clarification" {
                        testResult += "追问: \(result.reply ?? "无")\n"
                    }
                    
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    testResult += "❌ API 调用失败\n\n"
                    testResult += "错误信息: \(error.localizedDescription)\n"
                    
                    if let llmError = error as? LLMError {
                        switch llmError {
                        case .apiError:
                            testResult += "错误类型: API 请求失败\n"
                            testResult += "可能原因:\n"
                            testResult += "1. API Key 无效或过期\n"
                            testResult += "2. 网络连接问题\n"
                            testResult += "3. API 端点 URL 错误\n"
                            testResult += "4. 请求格式不正确\n"
                        case .noContent:
                            testResult += "错误类型: 无返回内容\n"
                        case .invalidJSON:
                            testResult += "错误类型: JSON 解析失败\n"
                        }
                    }
                    
                    // 显示详细的调试信息
                    testResult += "\n调试信息:\n"
                    testResult += "请求 URL: \(Config.chatCompletionsURL)\n"
                    testResult += "API Key: \(Config.llmAPIKey.prefix(15))...\n"
                    testResult += "模型: \(Config.llmModel)\n"
                    
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    APITestView()
}