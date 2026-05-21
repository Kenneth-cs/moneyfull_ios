# 钱小满 v2.0 - 阶段一 AI 交互策略文档

## 1. 概述

阶段一实现了核心的"语音/文字 → LLM 解析 → 结构化数据"链路，建立了完整的 AI Agent 交互体系。

---

## 2. 输入策略

### 2.1 输入方式

| 输入方式 | 触发方式 | 技术实现 |
|---------|---------|---------|
| **文字输入** | 点击底部麦克风按钮 → 打开AI对话页面 → 键盘输入 | SwiftUI TextField |
| **语音输入** | 长按底部麦克风按钮 → 开始录音 → 松开发送 | SFSpeechRecognizer |

### 2.2 输入预处理

```swift
// 语音转文字
SpeechService.shared.transcribedText

// 文字直接传递
messageText
```

---

## 3. LLM 调用策略

### 3.1 模型选择

| 配置项 | 值 |
|-------|-----|
| 模型 | `qwen-plus` |
| API地址 | `https://dashscope.aliyuncs.com/compatible-mode/v1` |
| Temperature | `0.1`（低随机性，保证输出稳定） |
| Max Tokens | `500` |

### 3.2 System Prompt 策略

**核心规则：**

1. **精细化分类识别**：必须识别到一级分类(groupName)和二级分类(categoryName)
2. **关键词精确匹配优先**：用户提到的具体项目必须精确匹配
3. **宽泛匹配作为兜底**：只有用户没有明确提到具体项目时才使用宽泛分类
4. **新分类建议**：不存在的分类返回`suggest_new_category`状态
5. **模糊表达处理**：表达模糊时返回`need_clarification`状态
6. **闲聊处理**：非记账内容返回普通文本

### 3.3 Context 注入策略

每次调用LLM时，注入以下上下文：

```
Available Categories (grouped by groupName):
【吃喝】
  - 咖啡 (icon: cup.and.saucer.fill, color: #A8E6CF)
  - 外卖 (icon: takeoutbag.and.cup.and.straw.fill, color: #A8E6CF)
【出行】
  - 交通 (icon: car.fill, color: #B3D1E6)

Available Projects:
- 日常收支
- 旅行基金

User Memory Rules:
- keyword: 瑞幸, category: 咖啡

Recent Chat History:
User: 买咖啡花了25元
Assistant: 交易确认卡片
```

---

## 4. 输出解析策略

### 4.1 输出状态定义

| 状态 | 说明 | 处理方式 |
|-----|------|---------|
| `success` | 信息完整，分类存在 | 显示交易确认卡片 |
| `suggest_new_category` | 二级分类不存在，建议创建 | 显示新分类建议卡片 |
| `need_clarification` | 信息模糊，需要追问 | 显示追问消息 |
| `chat` | 闲聊回复 | 直接显示文本 |

### 4.2 JSON 输出格式

**成功状态：**
```json
{
  "status": "success",
  "amount": 25,
  "type": "expense",
  "groupName": "吃喝",
  "categoryName": "咖啡",
  "categoryIcon": "cup.and.saucer.fill",
  "categoryColorHex": "#A8E6CF",
  "note": "买咖啡",
  "projectName": "日常收支"
}
```

**新分类建议状态：**
```json
{
  "status": "suggest_new_category",
  "suggested_category": "咖啡",
  "parent_group": "吃喝",
  "amount": 25,
  "type": "expense"
}
```

**追问状态：**
```json
{
  "status": "need_clarification",
  "reply": "这50元是花在什么地方了呢？"
}
```

**闲聊状态（非JSON，直接返回文本）：**
```
我主要负责帮您记账和管理财务哦～如果您有消费、收入需要记录，或者想查账、分析支出，随时告诉我！😊
```

### 4.3 容错处理

```swift
// 先尝试解析为JSON
if let parseResult = try? JSONDecoder().decode(TransactionParseResult.self, from: jsonData) {
    return parseResult
}

// 如果JSON解析失败，说明是闲聊回复
return TransactionParseResult(status: "chat", reply: content)
```

---

## 5. UI 交互策略

### 5.1 交易确认卡片

**普通交易确认：**
```
┌─────────────────────────────────┐
│ ✓ 交易确认                    8s │
├─────────────────────────────────┤
│ ☕ 咖啡                        │
│ 归属：吃喝                      │
│                                 │
│ 买咖啡                          │
│                                 │
│              -¥25.00            │
├─────────────────────────────────┤
│  [取消]        [确认入账]        │
└─────────────────────────────────┘
```

**新分类建议卡片：**
```
┌─────────────────────────────────┐
│ ✨ 新分类建议                    │
├─────────────────────────────────┤
│ ✨ 咖啡 (新分类)                │
│ 归属：吃喝                      │
│                                 │
│              -¥25.00            │
│                                 │
│ 点击"创建并入账"将在「吃喝」下   │
│ 创建新分类「咖啡」              │
├─────────────────────────────────┤
│  [取消]      [创建并入账]        │
└─────────────────────────────────┘
```

### 5.2 自动保存机制

| 场景 | 倒计时 | 行为 |
|-----|--------|------|
| 普通交易确认 | 8秒 | 倒计时结束自动保存 |
| 新分类建议 | 无倒计时 | 必须用户手动确认 |

### 5.3 按钮行为

| 按钮 | 行为 |
|-----|------|
| 确认入账 | 保存交易 + 保存记忆规则 |
| 创建并入账 | 创建新分类 + 保存交易 + 保存记忆规则 |
| 取消 | 取消入账，显示"已取消入账" |

---

## 6. 记忆捕获策略

### 6.1 记忆规则存储

```swift
MemoryRule {
    id: UUID
    keyword: String        // 用户输入中的关键词
    targetCategoryName: String  // AI识别的分类名
    targetProjectName: String?  // 项目名
    weight: Int            // 权重（每次命中+1）
    createdAt: Date
}
```

### 6.2 记忆触发时机

- 用户确认交易时，使用`note`作为关键词保存记忆规则
- 下次用户提到相同关键词时，AI会参考记忆规则

### 6.3 记忆注入策略

每次调用LLM时，将记忆规则注入Context：
```
User Memory Rules:
- keyword: 瑞幸, category: 咖啡
- keyword: 星巴克, category: 咖啡
```

---

## 7. 状态流转图

```
用户输入
    │
    ▼
┌─────────────┐
│  LLM 解析   │
└─────────────┘
    │
    ├─ success ──────────► 显示交易确认卡片 (8秒倒计时)
    │                          │
    │                          ├─ 确认 ──► 保存交易 + 记忆
    │                          ├─ 取消 ──► 显示"已取消"
    │                          └─ 超时 ──► 自动保存
    │
    ├─ suggest_new_category ─► 显示新分类建议卡片 (无倒计时)
    │                          │
    │                          ├─ 创建并入账 ──► 创建分类 + 保存交易 + 记忆
    │                          └─ 取消 ──► 显示"已取消"
    │
    ├─ need_clarification ──► 显示追问消息
    │                          │
    │                          └─ 用户补充 ──► 重新解析
    │
    └─ chat ────────────────► 直接显示闲聊回复
```

---

## 8. 数据流向

```
用户输入 (文字/语音)
    │
    ▼
ContextManager.buildContext()
    │ (注入分类/项目/记忆/历史)
    ▼
LLMService.parseTransaction()
    │ (调用千问API)
    ▼
TransactionParseResult
    │ (解析JSON或处理闲聊)
    ▼
AIChatView (显示消息/卡片)
    │
    ▼
TransactionConfirmCard (用户确认)
    │
    ├─► AppStore.addTransaction() (保存交易)
    ├─► AppStore.addCategory() (创建新分类)
    └─► ContextManager.saveMemoryRule() (保存记忆)
```

---

## 9. 关键配置

### 9.1 时间配置

| 配置项 | 值 |
|-------|-----|
| 交易确认倒计时 | 8秒 |
| 聊天历史注入条数 | 最近5条 |

### 9.2 模型配置

| 配置项 | 值 |
|-------|-----|
| 模型 | qwen-plus |
| Temperature | 0.1 |
| Max Tokens | 500 |

---

## 10. 后续优化方向

1. **分类修改功能**：支持在卡片上点击修改分类
2. **项目选择功能**：支持在卡片上选择项目
3. **批量记账**：支持一次输入多笔交易
4. **智能推荐**：根据时间/场景推荐分类
5. **语音优化**：支持实时语音转文字预览
