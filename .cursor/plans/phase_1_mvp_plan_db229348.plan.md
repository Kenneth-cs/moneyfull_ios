---
name: Phase 1 MVP Plan
overview: Implement Phase 1 of the Moneyfull v2.0 AI Native upgrade, including SwiftData model updates, AI service layer foundations, and the new Chat UI with TabBar refactoring.
todos:
  - id: update-models
    content: Update SwiftData models in Models.swift and ModelContainers
    status: pending
  - id: create-services
    content: Create LLMService, ContextManager, and SpeechService
    status: pending
  - id: update-dashboard
    content: Update DashboardView to add the traditional '+ 记一笔' button
    status: pending
  - id: update-tabbar
    content: Refactor MainTabView TabBar for the AI Assistant button
    status: pending
  - id: implement-chat-ui
    content: Implement AIChatView and TransactionConfirmCard
    status: pending
isProject: false
---

# Phase 1: 核心架构与 AI 基础体验 (MVP) 实施计划

## 1. 数据模型升级 (SwiftData)
- **修改文件**: `moneyfull_ios/Models/Models.swift`
  - 在 `Transaction` 模型中新增 `source` 字段，用于区分记录来源 (manual, voice, image, auto)。
  - 新增 `@Model final class ChatHistory`，包含 `id`, `role` (user/assistant), `content`, `timestamp`。
  - 新增 `@Model final class MemoryRule`，包含 `id`, `keyword`, `targetCategoryName`, `targetProjectName`, `weight`, `createdAt`。
- **修改文件**: `moneyfull_ios/moneyfull_iosApp.swift` 及各个 View 的 `#Preview`
  - 更新 `ModelContainer` 初始化代码，包含 `ChatHistory.self` 和 `MemoryRule.self`。

## 2. 核心 AI 服务层 (Agent Service)
- **新建文件**: `moneyfull_ios/Services/LLMService.swift`
  - 封装与大模型 API 的通信逻辑，定义 System Prompt（小满人设和 JSON 输出格式）。
  - **Prompt 优化：** 强制要求 AI 提取并返回“一级分类 (groupName)”和“二级分类 (name)”。如果用户提到的二级分类不存在，AI 应返回 `{"status": "suggest_new_category", "suggested_category": "咖啡", "parent_group": "餐饮"}`。
- **新建文件**: `moneyfull_ios/Services/ContextManager.swift`
  - 负责从 SwiftData 读取当前的分类列表、项目列表、记忆规则（`MemoryRule`）和最近的对话记录（`ChatHistory`），拼接成 Prompt Context。
- **新建文件**: `moneyfull_ios/Services/SpeechService.swift`
  - 封装 `SFSpeechRecognizer`，提供开始录音、停止录音和实时语音转文字的回调。

## 3. UI 重构与交互
- **修改文件**: `moneyfull_ios/Views/DashboardView.swift`
  - 增加 `@Binding var isAddRecordPresented: Bool`。
  - 在顶部财务看板的收入/储蓄卡片下方，新增一个横向的 `+ 记一笔` 长按钮，点击触发 `isAddRecordPresented = true`。
- **修改文件**: `moneyfull_ios/Views/MainTabView.swift`
  - 将 `$isAddRecordPresented` 传递给 `DashboardView`。
  - 修改底部 TabBar 的中央按钮：图标改为 `mic.fill`，背景色和样式调整以符合 AI 助手设定。
  - 为 AI 按钮添加手势：短按打开 `AIChatView`，长按触发语音输入。
- **新建文件**: `moneyfull_ios/Views/AIChatView.swift`
  - 搭建类似微信的聊天气泡流 UI。
  - 底部实现语音/键盘切换的输入框。
  - 监听语音输入结果并调用 `LLMService`。
- **新建文件**: `moneyfull_ios/Components/TransactionConfirmCard.swift`
  - 在 Chat UI 中渲染 LLM 返回的 JSON 数据。
  - 支持点击修改分类/项目，修改后触发写入 `MemoryRule`。
  - **新分类创建交互：** 如果 LLM 建议了新二级分类（如“咖啡”），卡片上显示 `✨ 咖啡 (新)`。用户点击确认保存时，底层自动在“餐饮”一级分类下创建“咖啡”分类并入账。
  - **实现 3 秒倒计时自动保存入账的逻辑。**
  - **包含“确认”和“取消”按钮，支持手动立即保存或放弃。**