---
name: Phase 3 GUI Optimization and Automation Plan
overview: Implement Phase 3 of the Moneyfull v2.0 AI Native upgrade, including traditional GUI optimizations (smart category recommendations, keyboard dismissal), recurring bills, AI memory management, and LLM-powered financial insights.
todos:
  - id: update-category-selection
    content: Update CategorySelectionView to add smart recommendations
    status: pending
  - id: improve-keyboard-dismissal
    content: Improve keyboard dismissal in AddRecordView
    status: pending
  - id: add-recurring-bill-model
    content: Add RecurringBill model to Models.swift and ModelContainers
    status: pending
  - id: create-memory-management
    content: Create MemoryManagementView and add entry to ProfileView
    status: pending
  - id: integrate-llm-analytics
    content: Integrate LLMService into AnalyticsView for financial advice
    status: pending
isProject: false
---

# Phase 3: 传统 GUI 优化与自动化 实施计划

## 1. 传统记账面板优化
- **修改文件**: `moneyfull_ios/Views/CategorySelectionView.swift`
  - 在分类网格的最上方新增一行专属的 **“✨ 智能推荐”** 区域（仅展示 3 个 Icon）。
  - 实现基于时间/场景的推荐逻辑：例如早上 6:00-9:00 推荐“早餐、交通”，周末推荐“娱乐、购物”。保持下方原有分类网格顺序绝对固定，不破坏肌肉记忆。
- **修改文件**: `moneyfull_ios/Views/AddRecordView.swift`
  - 完善键盘收起逻辑：在 `ScrollView` 添加 `simultaneousGesture(DragGesture().onChanged { _ in showKeypad = false })`，并在空白区域添加点击手势，确保滑动或点击空白处时收起底部的自定义数字键盘。

## 2. 自动化与洞察
- **修改文件**: `moneyfull_ios/Models/Models.swift`
  - 新增 `@Model final class RecurringBill` 模型，包含字段：`id`, `amount`, `type`, `categoryName`, `project`, `frequency` (如 monthly, weekly), `nextDueDate`, `isAutoRecord`, `createdAt`。
- **修改文件**: `moneyfull_ios/moneyfull_iosApp.swift` 及相关 View 的 `#Preview`
  - 更新 `ModelContainer` 初始化代码，将 `RecurringBill.self` 加入注册列表。
- **新建文件**: `moneyfull_ios/Views/MemoryManagementView.swift`
  - 开发“AI 记忆管理”页面，使用 `@Query` 读取所有的 `MemoryRule`。
  - 列表展示 AI 学习到的纠错规则（例如：“当我说'瑞幸'时，记入'咖啡'”），并支持左滑删除规则。
- **修改文件**: `moneyfull_ios/Views/ProfileView.swift`
  - 在“账户管理”菜单区域（如“分类管理”下方），新增“AI 记忆管理”的 `MenuItem` 入口，点击跳转至 `MemoryManagementView`。
- **修改文件**: `moneyfull_ios/Views/AnalyticsView.swift`
  - 升级 `InsightCardView`（豚言豚语）模块。
  - 将原有的“生成报告占位按钮”接入 `LLMService`。点击后，将当月的总支出、总收入、各分类支出占比等数据拼接为 Prompt 发送给 LLM，获取并展示 AI 生成的月度财务建议与规划。