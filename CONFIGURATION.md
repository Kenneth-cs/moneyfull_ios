# API 配置说明

## 安全配置 API 密钥

### 方法 1：使用环境变量（推荐）

1. **在 Xcode 中配置环境变量**：
   - 打开 Xcode 项目
   - 选择 "Product" → "Scheme" → "Edit Scheme"
   - 选择 "Run" 选项
   - 点击 "Arguments" 标签
   - 在 "Environment Variables" 部分添加：
     - `LLM_API_KEY` = 你的千问 API 密钥
     - `LLM_BASE_URL` = `https://dashscope.aliyuncs.com/compatible-mode/v1`
     - `LLM_MODEL` = `qwen-turbo`

2. **或者在终端中设置**：
   ```bash
   export LLM_API_KEY="sk-你的密钥"
   export LLM_BASE_URL="https://dashscope.aliyuncs.com/compatible-mode/v1"
   export LLM_MODEL="qwen-turbo"
   ```

### 方法 2：直接配置（不推荐用于生产环境）

1. 复制 `Config.example.swift` 为 `Config.swift`
2. 在 `Config.swift` 中替换 `your_api_key_here` 为真实密钥
3. **注意**：`Config.swift` 已被 `.gitignore` 排除，不会提交到版本控制

## 千问 API 模型选择

| 模型 | 特点 | 适用场景 |
|------|------|----------|
| `qwen-turbo` | 速度快，成本低 | 日常记账解析 |
| `qwen-plus` | 平衡性能与成本 | 复杂语义理解 |
| `qwen-max` | 最强能力 | 复杂场景，成本较高 |

## 测试 API 连接

在 `LLMService.swift` 中可以添加测试方法：

```swift
func testConnection() async -> Bool {
    do {
        let result = try await parseTransaction(from: "买咖啡花了25元", context: "")
        return true
    } catch {
        print("API 连接测试失败: \(error)")
        return false
    }
}
```

## 安全提醒

1. **永远不要**将 API 密钥提交到版本控制系统
2. **定期轮换** API 密钥
3. **限制 API 密钥权限**，只授予必要的访问权限
4. **监控 API 使用情况**，防止滥用