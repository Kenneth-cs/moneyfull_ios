import SwiftUI

struct APITestDetailView: View {
    @State private var testResult = ""
    @State private var isLoading = false
    @State private var testInput = "买咖啡花了25元"
    @State private var showRawResponse = false
    @State private var rawResponse = ""
    
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
                        Text(Config.chatCompletionsURL)
                            .foregroundColor(.secondary)
                            .font(.caption)
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
                        Text(Config.llmAPIKey.prefix(15) + "...")
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
                            showRawResponse.toggle()
                        }) {
                            Text(showRawResponse ? "隐藏原始响应" : "显示原始响应")
                                .font(.caption)
                        }
                    }
                    
                    ScrollView {
                        if showRawResponse {
                            Text(rawResponse)
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
            .navigationTitle("API 详细测试")
        }
    }
    
    private func testAPI() {
        isLoading = true
        testResult = "开始测试...\n"
        rawResponse = ""
        
        Task {
            do {
                let context = """
                Available Categories:
                - 餐饮 (icon: fork.knife, color: #A8E6CF)
                - 交通 (icon: car.fill, color: #B3D1E6)
                - 购物 (icon: bag.fill, color: #F6D7A8)
                
                Available Projects:
                - 日常开销
                - 旅行基金
                """
                
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
                        testResult += "分类: \(result.categoryName ?? "未知")\n"
                        testResult += "图标: \(result.categoryIcon ?? "未知")\n"
                        testResult += "颜色: \(result.categoryColorHex ?? "未知")\n"
                        testResult += "备注: \(result.note ?? "无")\n"
                        testResult += "项目: \(result.projectName ?? "无")\n"
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
                            testResult += "5. iOS 网络权限限制\n"
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
                    testResult += "\n可能的解决方案:\n"
                    testResult += "1. 检查网络连接\n"
                    testResult += "2. 验证 API Key 是否有效\n"
                    testResult += "3. 尝试使用 VPN 或代理\n"
                    testResult += "4. 检查 iOS 网络权限设置\n"
                    
                    rawResponse = "错误详情: \(error)"
                    
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    APITestDetailView()
}