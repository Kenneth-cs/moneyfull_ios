# AI 项目归属策略自动化测试方案

## 一、测试目标

验证 AI 自动识别账单项目归属的 4 层漏斗机制是否正确工作：
1. **第一层**：用户直接指令（最高优先级）
2. **第二层**：MemoryRule 记忆规则
3. **第三层**：活跃项目/置顶项目
4. **第四层**：AI 语义推断

---

## 二、测试范围

### 2.1 单元测试

| 测试模块 | 测试类 | 测试内容 |
|----------|--------|----------|
| 上下文构建 | `ContextManagerTests` | 置顶项目标记、动态活跃项目推断 |
| LLM Prompt | `LLMPromptTests` | 项目归属规则、冲突解决规则 |
| 记忆规则 | `MemoryRuleTests` | 规则保存、规则匹配、规则优先级 |

### 2.2 集成测试

| 测试场景 | 测试内容 |
|----------|----------|
| 完整识别流程 | 从用户输入到项目归属的端到端测试 |
| 冲突解决 | 多个活跃项目时的归属决策 |
| 学习闭环 | 用户纠正后的记忆规则生成 |

---

## 三、测试用例设计

### 3.1 第一层：用户直接指令

| 用例ID | 输入 | 预期输出 | 说明 |
|--------|------|----------|------|
| D1-01 | "打车50，记到旅游里" | project: "旅游" | 明确指定项目 |
| D1-02 | "午饭35记到装修" | project: "装修" | 明确指定项目 |
| D1-03 | "买水10块" | 根据其他规则判断 | 无明确指令 |

### 3.2 第二层：MemoryRule 记忆规则

| 用例ID | 前置条件 | 输入 | 预期输出 | 说明 |
|--------|----------|------|----------|------|
| M2-01 | 已学习"全季酒店→旅游" | "全季酒店500" | project: "旅游" | 记忆规则匹配 |
| M2-02 | 已学习"星巴克→日常" | "星巴克30" | project: "日常收支" | 记忆规则匹配 |
| M2-03 | 无相关记忆 | "瑞幸咖啡25" | 根据其他规则判断 | 无匹配规则 |

### 3.3 第三层：活跃项目/置顶项目

| 用例ID | 前置条件 | 输入 | 预期输出 | 说明 |
|--------|----------|------|----------|------|
| A3-01 | "旅游"项目已置顶 | "买水10块" | project: "旅游" | 置顶项目优先 |
| A3-02 | "装修"项目已置顶 | "买建材500" | project: "装修" | 置顶项目优先 |
| A3-03 | 最近5条中3条属于"旅游" | "吃饭50" | project: "旅游" | 动态活跃项目 |
| A3-04 | 无置顶项目，无高频项目 | "打车30" | project: "日常收支" | 兜底默认 |

### 3.4 第四层：AI 语义推断

| 用例ID | 前置条件 | 输入 | 预期输出 | 说明 |
|--------|----------|------|----------|------|
| S4-01 | 存在"旅游"项目 | "携程订酒店500" | project: "旅游" | 语义匹配 |
| S4-02 | 存在"装修"项目 | "买瓷砖2000" | project: "装修" | 语义匹配 |
| S4-03 | 存在"结婚"项目 | "婚庆公司报价" | project: "结婚" | 语义匹配 |
| S4-04 | 无相关项目 | "买机票1000" | project: "日常收支" | 无匹配项目 |

### 3.5 冲突解决测试

| 用例ID | 前置条件 | 输入 | 预期输出 | 说明 |
|--------|----------|------|----------|------|
| C5-01 | "旅游"+"装修"都置顶 | "买机票1000" | project: "旅游" | 语义匹配解决冲突 |
| C5-02 | "旅游"+"装修"都置顶 | "买建材500" | project: "装修" | 语义匹配解决冲突 |
| C5-03 | "旅游"+"装修"都置顶 | "吃饭50" | need_clarification | 通用消费追问用户 |
| C5-04 | "旅游"+"装修"都置顶 | "打车30" | need_clarification | 通用消费追问用户 |

---

## 四、测试实现

### 4.1 ContextManager 测试

```swift
class ContextManagerTests: XCTestCase {
    
    func testBuildContext_WithPinnedProject() {
        // 测试置顶项目标记
        let projects = [
            Project(name: "日常收支", isPinned: false),
            Project(name: "旅游", isPinned: true)
        ]
        let context = ContextManager.shared.buildContext(projects: projects)
        
        XCTAssertTrue(context.contains("旅游 (当前活跃/置顶)"))
        XCTAssertFalse(context.contains("日常收支 (当前活跃/置顶)"))
    }
    
    func testBuildContext_WithHighFrequencyProject() {
        // 测试动态活跃项目推断
        // 最近5条中3条属于"旅游"
        let transactions = createRecentTransactions(projectName: "旅游", count: 3)
        let context = ContextManager.shared.buildContext(transactions: transactions)
        
        XCTAssertTrue(context.contains("旅游 (近期高频活跃)"))
    }
    
    func testBuildContext_WithoutHighFrequency() {
        // 测试无高频项目
        let transactions = createRecentTransactions(projectName: "日常收支", count: 5)
        let context = ContextManager.shared.buildContext(transactions: transactions)
        
        XCTAssertFalse(context.contains("(近期高频活跃)"))
    }
}
```

### 4.2 MemoryRule 测试

```swift
class MemoryRuleTests: XCTestCase {
    
    func testSaveMemoryRule() {
        // 测试保存记忆规则
        ContextManager.shared.saveMemoryRule(
            keyword: "全季酒店",
            categoryName: "住宿",
            projectName: "旅游"
        )
        
        let rules = ContextManager.shared.loadMemoryRules()
        XCTAssertTrue(rules.contains { $0.keyword == "全季酒店" && $0.projectName == "旅游" })
    }
    
    func testMemoryRulePriority() {
        // 测试记忆规则优先级高于活跃项目
        ContextManager.shared.saveMemoryRule(
            keyword: "星巴克",
            categoryName: "咖啡",
            projectName: "日常收支"
        )
        
        // 即使"旅游"项目置顶，星巴克也应该归入"日常收支"
        let result = parseTransaction("星巴克30")
        XCTAssertEqual(result.projectName, "日常收支")
    }
}
```

### 4.3 冲突解决测试

```swift
class ConflictResolutionTests: XCTestCase {
    
    func testConflictResolution_SemanticMatch() {
        // 测试语义匹配解决冲突
        setupPinnedProjects(["旅游", "装修"])
        
        let result = parseTransaction("买机票1000")
        XCTAssertEqual(result.projectName, "旅游")
    }
    
    func testConflictResolution_AskUser() {
        // 测试通用消费追问用户
        setupPinnedProjects(["旅游", "装修"])
        
        let result = parseTransaction("吃饭50")
        XCTAssertEqual(result.status, "need_clarification")
    }
}
```

---

## 五、测试数据准备

### 5.1 Mock 数据

```swift
struct TestData {
    static let projects = [
        Project(name: "日常收支", isPinned: false),
        Project(name: "旅游", isPinned: true),
        Project(name: "装修", isPinned: false)
    ]
    
    static let memoryRules = [
        MemoryRule(keyword: "全季酒店", categoryName: "住宿", projectName: "旅游"),
        MemoryRule(keyword: "星巴克", categoryName: "咖啡", projectName: "日常收支")
    ]
    
    static let testCases = [
        // 直接指令
        ("打车50，记到旅游里", "旅游"),
        // 记忆规则
        ("全季酒店500", "旅游"),
        // 活跃项目
        ("买水10块", "旅游"),
        // 语义推断
        ("携程订酒店500", "旅游")
    ]
}
```

---

## 六、测试执行策略

### 6.1 执行顺序

1. **单元测试**：先运行独立的组件测试
2. **集成测试**：再运行端到端的流程测试
3. **回归测试**：每次修改后运行完整测试套件

### 6.2 测试覆盖率目标

| 模块 | 目标覆盖率 |
|------|-----------|
| ContextManager | 90% |
| LLMService (Prompt) | 80% |
| MemoryRule | 90% |
| 冲突解决 | 85% |

---

## 七、测试报告模板

```
测试执行报告
============

执行时间：2026-05-30 20:30:00
执行环境：iPhone 16 Pro Simulator

测试结果汇总：
- 总用例数：25
- 通过：23
- 失败：2
- 跳过：0

失败用例：
1. C5-03：通用消费追问用户 - 预期 need_clarification，实际返回 "旅游"
2. S4-04：无相关项目时语义推断 - 预期 "日常收支"，实际返回 nil

建议：
1. 检查冲突解决逻辑
2. 完善兜底规则
```

---

## 八、持续集成

### 8.1 CI 配置

```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run tests
        run: xcodebuild test -scheme moneyfull_ios -destination 'platform=iOS Simulator,name=iPhone 16'
```

### 8.2 测试触发条件

- 每次代码提交
- 每次 Pull Request
- 每日定时运行（回归测试）

---

## 九、附录

### 9.1 相关文件

- `ContextManager.swift` - 上下文构建
- `LLMService.swift` - LLM 服务和 Prompt
- `Models.swift` - 数据模型
- `AppStore.swift` - 业务逻辑

### 9.2 参考文档

- [AI自动识别账单项目归属策略.md](../AI自动识别账单项目归属策略.md)
- [ai_project_attribution_strategy_3d8d7e3b.plan.md](../.cursor/plans/ai_project_attribution_strategy_3d8d7e3b.plan.md)
