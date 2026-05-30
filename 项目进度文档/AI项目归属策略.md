# AI 项目归属策略（速查）

> 详细说明见 [AI项目归属策略说明.md](./AI项目归属策略说明.md)

---

## 4 层漏斗优先级

```
用户输入
   ↓
第1层：用户直接指令（"记到旅游里"）           ← 最高优先级
   ↓ 未命中
第2层：活跃项目 (当前活跃项目⭐)              ← 覆盖一切历史记忆
   ↓ 未命中
第3层：记忆规则（User Memory Rules 中的 project）
   ↓ 未命中
第4层：AI 语义推断（酒店→旅游、建材→装修）
   ↓ 未命中
兜底：归入"日常收支"
```

---

## 关键规则

- **活跃项目（⭐）** 的 `project` 优先级 **高于** 记忆规则的 `project`
- 记忆规则的 **分类（category）** 始终可参考，只忽略其 **project 字段**
- 活跃项目全局唯一，同时只能有一个
- 动态推断：最近 5 条账单中 ≥3 条属于同一非日常项目 → 自动标记为 `(近期高频活跃)`

---

## 涉及文件

| 文件 | 作用 |
|------|------|
| `Services/LLMService.swift` | `parseTransaction` / `parseOCRText` Prompt 中的 4 层优先级规则 |
| `Services/ContextManager.swift` | 构建上下文，标记活跃项目和高频项目 |
| `Models/Models.swift` | `Project.isActiveProject` 字段 |
| `Models/AppStore.swift` | `toggleActiveProject()` 互斥逻辑 |

---

## Bug 修复记录

| 日期 | 问题 | 修复 |
|------|------|------|
| 2026-05-31 | `parseTransaction` 缺少项目归属优先级规则，导致活跃项目被记忆规则覆盖 | 在 `parseTransaction` systemPrompt 补充第5条规则（项目归属4层优先级） |
