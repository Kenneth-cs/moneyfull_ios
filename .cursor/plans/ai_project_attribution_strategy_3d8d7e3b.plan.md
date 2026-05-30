---
name: AI Project Attribution Strategy
overview: Implement a 4-level AI project attribution strategy (Explicit Instruction, Memory Rules, Active Projects, Semantic Inference) with dynamic active project detection and conflict resolution.
todos:
  - id: context-manager
    content: Update ContextManager.swift to append active/pinned markers and dynamically infer high-frequency projects
    status: pending
  - id: llm-prompt
    content: Update LLMService.swift system prompts with the 4-level project attribution rules and conflict resolution
    status: pending
  - id: memory-rule
    content: Add saveMemoryRule calls to EditTransactionView.swift and AddRecordView.swift
    status: pending
isProject: false
---

# AI 自动识别账单项目归属策略实施计划

根据策略文档，我们将通过 4 个层级的漏斗机制（直接指令 -> 记忆规则 -> 活跃项目 -> 语义推断）来提升 AI 识别项目归属的准确率。

## 1. 强化上下文与动态活跃项目 (Strategy 1)
修改 `moneyfull_ios/Services/ContextManager.swift` 中的 `buildContext()` 方法：
- 遍历 `projects` 时，如果 `project.isPinned` 为 `true`，在项目名称后追加 `(当前活跃/置顶)` 标记。
- **动态推断活跃项目**：查询最近 5 条 `Transaction`，如果其中有 3 条及以上属于同一个非“日常收支”的项目，则将该项目在上下文中标记为 `(近期高频活跃)`。

## 2. 升级大模型 Prompt 规则 (Strategy 2 & 4 & 冲突解决)
修改 `moneyfull_ios/Services/LLMService.swift` 中的 `parseTransaction` 和 `parseOCRText` 方法的 `systemPrompt`，在“核心规则”中增加：
- **项目归属规则 (project_name)**，按以下优先级匹配：
  1. **明确指令**：用户明确提及项目名称（如“记到旅游里”）。
  2. **记忆规则**：Context 中的 User Memory Rules 包含匹配的商户/关键词。
  3. **活跃项目**：优先归入标记为 `(当前活跃/置顶)` 或 `(近期高频活跃)` 的项目。
     * **冲突处理**：若存在多个活跃项目，根据消费语义匹配（如机票->旅游，建材->装修）。若消费非常通用（如吃饭、打车）且无法判断，返回 `need_clarification` 追问用户。
  4. **语义推断**：消费特征明显（如酒店、景区）且存在相关名称项目，自动推断归入。

## 3. 完善 MemoryRule 自适应学习闭环 (Strategy 3)
目前的 `TransactionConfirmCard.swift` 已经在确认时保存了记忆规则。为了让学习闭环更完整，我们需要在用户手动记账和修改账单时也触发学习：
- 修改 `moneyfull_ios/Views/EditTransactionView.swift`：在 `store.updateTransaction` 后，如果 `note` 不为空，调用 `try? ContextManager.shared.saveMemoryRule(keyword: note, categoryName: category.name, projectName: selectedProject?.name)`。
- 修改 `moneyfull_ios/Views/AddRecordView.swift`：在 `store.addTransaction` 后，如果 `note` 不为空，同样调用 `saveMemoryRule` 记录用户的分类和项目偏好。