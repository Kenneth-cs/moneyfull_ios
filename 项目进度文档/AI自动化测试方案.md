# 钱小满 AI 自动化测试方案

> 版本: v1.0 | 日期: 2026-05-30

---

## 一、文档问题审查

> 以下为对《三个功能的现状分析与实现方案》的问题分析，修复建议紧接每条问题。

---

### 🔴 问题 1 — 章节编号错误（第三部分）

**位置**: 第三部分 § 6.7 / § 6.8

**问题描述**: 第三部分（每日订阅提醒记账）的小节编号跳变为 `6.7` / `6.8`，明显是复制自其他文档后未修正，应为 `3.7` / `3.8`。

**修复**:
```
6.7 首次安装引导  →  3.7 首次安装引导
6.8 需要修改的文件 →  3.8 需要修改的文件
```

---

### 🔴 问题 2 — 自定义评分弹窗存在 App Review 合规风险

**位置**: § 2.2 智能评分弹窗设计

**问题描述**: 苹果 [App Review 指南 3.2.2(vi)](https://developer.apple.com/app-store/review/guidelines/#3.2.2) 明确规定：**不得使用自定义 UI 诱导用户评分**，只能使用系统提供的 `SKStoreReviewController.requestReview()`。当前方案的「⭐⭐⭐⭐⭐ 可点击动画 + 去评分按钮」属于自定义评分弹窗，有拒审风险。

**修复建议**:
```
保留内部「满意度确认」流程：
  1. 弹出简单弹窗（文案+两个按钮）："用得还开心吗？"
     → [开心！] → 调用 SKStoreReviewController.requestReview()
     → [有点问题] → 跳转内部反馈渠道（邮件/消息）
  2. 去掉自定义的星级打分交互
  3. ProfileView 中「给个好评」按钮可以继续保留，直接跳 App Store 链接
```

**相关代码改动**:
```swift
// 合规写法
import StoreKit

// 触发系统评分弹窗（每年最多弹3次，iOS自动管理频次）
if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
    SKStoreReviewController.requestReview(in: windowScene)
}
```

---

### 🔴 问题 3 — Info.plist 字段名称错误

**位置**: § 3.1 权限请求 / § 3.8 需要修改的文件

**问题描述**: 文档写的是 `NSUserNotificationsUsageDescription`（多了一个 `s`），正确字段名是 `NSUserNotificationUsageDescription`。

> 补充：iOS 的 UserNotifications 框架实际上**不强制要求**在 Info.plist 中声明此 key；运行时 `requestAuthorization` 即可。需要在 plist 中声明的是相机、相册、麦克风等隐私权限。提醒功能只需关注能力配置（Push Notifications Capability）即可，无需修改 plist。

---

### 🟡 问题 4 — 周末免打扰「方案A」技术上不可行

**位置**: § 3.6 周末免打扰 — 方案A（推荐）

**问题描述**: 方案A 说「通过 Notification Extension 或 `UNUserNotificationCenterDelegate` 在展示前过滤」——

- `UNUserNotificationCenterDelegate.willPresent` 只在 **App 处于前台** 时触发，无法过滤后台通知推送。
- Notification Content Extension 只能修改展示样式，**无法取消或屏蔽通知**。

因此方案A实际上**无法实现**周末过滤，推荐改为：

```
推荐实现（改良方案B）:
  - 每次 app 启动或用户修改设置时，调用 removeAllPendingNotificationRequests()
  - 重新注册未来 14 天内所有「工作日」的 UNCalendarNotificationTrigger（repeats: false）
  - 在 Background App Refresh 中定期续期注册，防止通知序列过期
```

---

### 🟡 问题 5 — `recentTransactions.count` 数据源说明不足

**位置**: § 2.3 触发时机与逻辑

**问题描述**: `AppStore.recentTransactions` 在代码中被注释为「最多50条」，文档中直接用它的 `.count` 来判断「记账 ≥ 15 笔」。当用户记账超过50笔时 count 仍为50，虽然不影响 ≥15 的判断结果，但文档应明确说明或改用真实总笔数查询：

```swift
// 建议改为查询总数（不受50条限制）
let descriptor = FetchDescriptor<Transaction>()
let totalCount = (try? modelContext.fetchCount(descriptor)) ?? 0
```

---

### 🟡 问题 6 — ReminderStyle 枚举代码未完整填充

**位置**: § 3.5 文案随机策略

**问题描述**: `ReminderStyle.simple` 和 `ReminderStyle.funny` 的 `messages` 数组使用了 `...` 占位，是未完成的伪代码，在正式文档中应填充完整内容，否则执行开发时容易被遗漏。

**建议补充**:
```swift
case .simple:
    return [
        "记账提醒：请记录今日收支 📊",
        "今日账单待记录，点击开始",
        "记录收支，掌握财务数据",
        "今天的账记了吗？",
        "1分钟，记录今天的每一笔"
    ]
case .funny:
    return [
        "你的钱包想你了，快来记一笔 💸",
        "钱去哪儿了？小满替你盯着呢 👀",
        "今天没记账？明天的你会恨今天的你",
        "记账一时爽，月底复盘更爽 🔥",
        "你赚的钱在等你交代去向 🧐"
    ]
```

---

### 🟢 问题 7 — App Store 跳转链接建议使用 https

**位置**: § 2.1 / § 2.2

**问题描述**: `itms-apps://` 协议在 iOS 17+ 依然有效，但 Apple 官方文档推荐使用 `https://apps.apple.com` 格式，兼容性和稳定性更好：

```
推荐: https://apps.apple.com/app/id{APP_ID}?action=write-review
当前: itms-apps://itunes.apple.com/app/id{APP_ID}?action=write-review
```

---

## 二、AI 自动化测试方案

---

## 2.1 测试目标与范围

钱小满的核心差异化能力是**自然语言记账（LLM 解析）**，AI 测试的重心在于：

1. 验证 LLM 对各类账单语句的理解准确率
2. 防止迭代过程中记账解析能力退化（回归）
3. 覆盖 Onboarding、评分、通知三个新功能的逻辑正确性
4. 端到端流程验证（从用户输入到数据落库）

---

## 2.2 测试架构总览

```
┌─────────────────────────────────────────────────────────┐
│                    测试金字塔                            │
│                                                         │
│               ┌──────────────┐                          │
│               │  E2E Tests   │  ← XCUITest 模拟真实用户 │
│               └──────────────┘                          │
│           ┌──────────────────────┐                      │
│           │  Integration Tests   │  ← LLM+Store 联动    │
│           └──────────────────────┘                      │
│       ┌──────────────────────────────┐                  │
│       │       Unit Tests             │  ← 逻辑/解析/工具 │
│       └──────────────────────────────┘                  │
│   ┌──────────────────────────────────────┐              │
│   │    AI Prompt Regression Suite        │  ← 核心       │
│   └──────────────────────────────────────┘              │
└─────────────────────────────────────────────────────────┘
```

---

## 2.3 AI 记账解析回归测试（核心）

### 测试数据集设计

将测试用例按难度分为三级，共 **60 条**黄金测试集：

#### Level 1 — 基础识别（25条，期望通过率 100%）

| ID | 输入语句 | 期望 amount | 期望 type | 期望 groupName | 期望 categoryName |
|----|---------|------------|-----------|---------------|-----------------|
| L1-01 | 午餐花了35块 | 35 | expense | 餐饮 | 午餐 |
| L1-02 | 打车28元 | 28 | expense | 出行 | 交通 |
| L1-03 | 买了瓶矿泉水2块钱 | 2 | expense | 餐饮 | 饮料 |
| L1-04 | 今天收到工资12000 | 12000 | income | 收入 | 工资 |
| L1-05 | 咖啡拿铁38 | 38 | expense | 餐饮 | 咖啡 |
| L1-06 | 超市购物花了220 | 220 | expense | 购物 | 超市 |
| L1-07 | 电影票两张共96元 | 96 | expense | 娱乐 | 电影 |
| L1-08 | 房租转了3500 | 3500 | expense | 居家 | 房租 |
| L1-09 | 地铁坐了5块 | 5 | expense | 出行 | 地铁 |
| L1-10 | 给妈妈买了礼物188 | 188 | expense | 购物 | 礼品 |
| ... | （共25条） | | | | |

#### Level 2 — 模糊/复合表达（20条，期望通过率 ≥ 90%）

| ID | 输入语句 | 期望 status | 关键验证点 |
|----|---------|------------|----------|
| L2-01 | 花了50 | need_clarification | 触发追问，不瞎猜分类 |
| L2-02 | 今天买东西花了好多钱 | need_clarification | 金额模糊，触发追问 |
| L2-03 | 订阅了一年的爱奇艺，198 | success | groupName=娱乐/订阅 |
| L2-04 | 报销了上周的出差费600 | success | type=income |
| L2-05 | 帮同事垫付了午饭，三个人一共90 | success | amount=90，note含"垫付" |
| L2-06 | 停车费忘了多少，大概十几块 | need_clarification | 金额不明确 |
| L2-07 | 买了个充电宝，京东上的 | need_clarification | 缺金额 |
| L2-08 | 还款了信用卡3000 | success | type=expense, groupName=金融 |
| L2-09 | 奖金到账了5000，发工资的那种 | success | type=income, groupName=收入 |
| L2-10 | 今天买了好多东西，零食、文具、护肤品各一堆 | need_clarification | 多品类无单一金额 |
| ... | （共20条） | | |

#### Level 3 — 分析意图 & 复杂推理（15条，期望通过率 ≥ 85%）

| ID | 输入语句 | 期望 status | 期望 insight_type / 关键验证点 | 期望 period |
|----|---------|------------|-------------------------------|-----------|
| L3-01 | 这个月我花了多少 | insight | monthly_overview | this_month |
| L3-02 | 帮我分析一下餐饮支出 | insight | category_group | this_month |
| L3-03 | 上个月总支出是多少 | insight | monthly_overview | last_month |
| L3-04 | 我平时在哪里花钱最多 | insight | category_group | this_month |
| L3-05 | 帮我看看购物花了多少钱 | insight | category_group | this_month |
| L3-06 | 最近三个月的收入是多少 | insight | monthly_overview | — |
| L3-07 | 你好呀（闲聊） | chat | reply 非空 | — |
| L3-08 | 跟朋友AA了，我付了120，但他们要还我60 | success | amount=60，推理净额 | — |
| L3-09 | 买了个滑雪装备，花了2800 | suggest_new_category | 返回 suggested_category + parent_group | — |
| L3-10 | 宠物美容花了280 | suggest_new_category | 分类不在预设列表，应建议新分类 | — |
| ... | （共15条） | | | |

> **说明**: `suggest_new_category` 是 LLMService Prompt 规则3明确定义的状态，必须在测试集中覆盖，否则该路径无回归保护。

---

### 测试执行框架（Swift）

```swift
// LLMRegressionTests.swift
// 放在 moneyfull_iosTests Target 中

import XCTest
@testable import moneyfull_ios

/// AI 解析回归测试套件
/// 每次 LLMService / Prompt 变更后必须全量跑一遍
class LLMRegressionTests: XCTestCase {
    
    // 必须声明 Decodable，否则 JSONDecoder().decode 无法编译
    struct TestCase: Decodable {
        let id: String
        let input: String
        let expectedStatus: String
        let expectedAmount: Double?
        let expectedType: String?
        let expectedGroupName: String?
        let expectedCategoryName: String?
        let toleranceAmount: Double  // 金额容差，默认 0
    }
    
    // 黄金测试集（从 JSON 文件加载，方便 PM 维护）
    var testCases: [TestCase] = []
    
    override func setUpWithError() throws {
        let url = Bundle(for: type(of: self)).url(forResource: "llm_test_cases", withExtension: "json")!
        let data = try Data(contentsOf: url)
        testCases = try JSONDecoder().decode([TestCase].self, from: data)
    }
    
    /// 运行全量回归，输出通过率报告
    func testLLMParseAccuracy() async throws {
        let mockContext = "categories: ..."  // 使用标准测试上下文
        
        var passed = 0
        var failed: [(id: String, reason: String)] = []
        
        for tc in testCases {
            do {
                let result = try await LLMService.shared.parseTransaction(
                    from: tc.input,
                    context: mockContext
                )
                
                // 验证 status
                guard result.status == tc.expectedStatus else {
                    failed.append((tc.id, "status: \(result.status) ≠ \(tc.expectedStatus)"))
                    continue
                }
                
                // 验证 amount（带容差）
                if let expected = tc.expectedAmount, let actual = result.amount {
                    XCTAssertEqual(actual, expected, accuracy: tc.toleranceAmount,
                                   "[\(tc.id)] amount mismatch")
                }
                
                // 验证分类
                if let expectedGroup = tc.expectedGroupName {
                    XCTAssertEqual(result.groupName, expectedGroup,
                                   "[\(tc.id)] groupName mismatch for: \(tc.input)")
                }
                
                passed += 1
                
            } catch {
                failed.append((tc.id, "API error: \(error)"))
            }
        }
        
        let passRate = Double(passed) / Double(testCases.count) * 100
        
        // 输出测试报告
        print("""
        ====== LLM 回归测试报告 ======
        总用例: \(testCases.count)
        通过: \(passed)
        失败: \(failed.count)
        通过率: \(String(format: "%.1f", passRate))%
        
        失败用例:
        \(failed.map { "  [\($0.id)] \($0.reason)" }.joined(separator: "\n"))
        ==============================
        """)
        
        // L1 必须 100% 通过
        let l1Cases = testCases.filter { $0.id.hasPrefix("L1") }
        let l1Passed = l1Cases.filter { tc in !failed.contains(where: { $0.id == tc.id }) }
        XCTAssertEqual(l1Passed.count, l1Cases.count, "L1 基础用例必须 100% 通过")
        
        // 总体通过率 ≥ 88%
        XCTAssertGreaterThanOrEqual(passRate, 88.0, "总体通过率不得低于 88%")
    }
    
    /// 性能测试：单次解析延迟
    func testLLMResponseLatency() async throws {
        let start = Date()
        _ = try await LLMService.shared.parseTransaction(
            from: "午餐花了35块",
            context: "categories: ..."
        )
        let elapsed = Date().timeIntervalSince(start) * 1000
        
        print("LLM 单次解析耗时: \(Int(elapsed))ms")
        XCTAssertLessThan(elapsed, 5000, "LLM 解析不应超过 5 秒（网络正常情况下）")
    }
}
```

---

### 测试数据文件格式

`moneyfull_iosTests/Resources/llm_test_cases.json`:

```json
[
  {
    "id": "L1-01",
    "input": "午餐花了35块",
    "expectedStatus": "success",
    "expectedAmount": 35,
    "expectedType": "expense",
    "expectedGroupName": "餐饮",
    "expectedCategoryName": "午餐",
    "toleranceAmount": 0
  },
  {
    "id": "L2-01",
    "input": "花了50",
    "expectedStatus": "need_clarification",
    "expectedAmount": null,
    "expectedType": null,
    "expectedGroupName": null,
    "expectedCategoryName": null,
    "toleranceAmount": 0
  }
]
```

> **维护说明**: 测试数据使用 JSON 文件，PM 和开发均可直接编辑，无需修改 Swift 代码。每次 Prompt 调整后在 CI 中自动运行并对比基线通过率。

---

## 2.4 单元测试（Unit Tests）

### AppRatingManager 测试

```swift
// AppRatingManagerTests.swift
class AppRatingManagerTests: XCTestCase {
    
    var sut: AppRatingManager!
    var defaults: UserDefaults!
    
    override func setUp() {
        super.setUp()
        // 必须先清除再初始化，否则 sut 会读到上一轮测试遗留的脏数据
        defaults = UserDefaults(suiteName: "test_rating")!
        defaults.removePersistentDomain(forName: "test_rating")
        sut = AppRatingManager(defaults: defaults)
    }
    
    // ✅ 满足所有条件 → 应该弹出
    func testShouldShowRating_WhenAllConditionsMet() {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        defaults.set(sevenDaysAgo, forKey: "firstLaunchDate")
        defaults.set(false, forKey: "hasRatedApp")
        defaults.set(0, forKey: "ratingDismissCount")
        
        XCTAssertTrue(sut.shouldShowRating(transactionCount: 15))
    }
    
    // ❌ 已评过分 → 不弹
    func testShouldNotShowRating_WhenAlreadyRated() {
        setupValidConditions()
        defaults.set(true, forKey: "hasRatedApp")
        
        XCTAssertFalse(sut.shouldShowRating(transactionCount: 20))
    }
    
    // ❌ 记账不足15笔 → 不弹
    func testShouldNotShowRating_WhenTransactionCountInsufficient() {
        setupValidConditions()
        
        XCTAssertFalse(sut.shouldShowRating(transactionCount: 14))
    }
    
    // ❌ 使用天数不足7天 → 不弹
    func testShouldNotShowRating_WhenUsageDaysInsufficient() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -6, to: Date())!
        defaults.set(yesterday, forKey: "firstLaunchDate")
        defaults.set(false, forKey: "hasRatedApp")
        defaults.set(0, forKey: "ratingDismissCount")
        
        XCTAssertFalse(sut.shouldShowRating(transactionCount: 20))
    }
    
    // ❌ 拒绝次数 ≥ 3 → 不弹
    func testShouldNotShowRating_WhenDismissedTooManyTimes() {
        setupValidConditions()
        defaults.set(3, forKey: "ratingDismissCount")
        
        XCTAssertFalse(sut.shouldShowRating(transactionCount: 20))
    }
    
    // ❌ 冷却期内（上次弹出距今 < 14天）→ 不弹
    func testShouldNotShowRating_WithinCooldownPeriod() {
        setupValidConditions()
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        defaults.set(tenDaysAgo, forKey: "lastRatingPromptDate")
        
        XCTAssertFalse(sut.shouldShowRating(transactionCount: 20))
    }
    
    // ✅ 冷却期结束（≥ 14天）→ 可以弹
    func testShouldShowRating_AfterCooldown() {
        setupValidConditions()
        let fifteenDaysAgo = Calendar.current.date(byAdding: .day, value: -15, to: Date())!
        defaults.set(fifteenDaysAgo, forKey: "lastRatingPromptDate")
        
        XCTAssertTrue(sut.shouldShowRating(transactionCount: 20))
    }
    
    private func setupValidConditions() {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        defaults.set(sevenDaysAgo, forKey: "firstLaunchDate")
        defaults.set(false, forKey: "hasRatedApp")
        defaults.set(0, forKey: "ratingDismissCount")
    }
}
```

### NotificationManager 测试

```swift
// NotificationManagerTests.swift
class NotificationManagerTests: XCTestCase {
    
    // 验证工作日判断逻辑
    func testIsWeekend() {
        let calendar = Calendar.current
        
        // 已知的某个周六
        let saturday = DateComponents(year: 2026, month: 5, day: 30)
        let saturdayDate = calendar.date(from: saturday)!
        XCTAssertTrue(NotificationManager.isWeekend(date: saturdayDate))
        
        // 已知的某个周一
        let monday = DateComponents(year: 2026, month: 6, day: 1)
        let mondayDate = calendar.date(from: monday)!
        XCTAssertFalse(NotificationManager.isWeekend(date: mondayDate))
    }
    
    // 验证未来14天工作日计算（周末免打扰）
    func testGenerateWorkdayTriggers_ExcludesWeekends() {
        let triggers = NotificationManager.shared.generateWorkdayTriggers(
            hour: 21, minute: 0, daysAhead: 14
        )
        
        // 确保所有触发日期都是工作日
        for trigger in triggers {
            let date = Calendar.current.date(from: trigger.dateComponents)!
            XCTAssertFalse(NotificationManager.isWeekend(date: date),
                           "通知不应在周末触发: \(date)")
        }
    }
    
    // 验证文案随机性（同一风格多次调用不都相同）
    func testReminderMessageRandomness() {
        let style = ReminderStyle.warm
        var messages = Set<String>()
        for _ in 0..<20 {
            messages.insert(NotificationManager.shared.randomMessage(for: style))
        }
        // 5条文案随机20次，至少应该出现3种不同文案
        XCTAssertGreaterThan(messages.count, 2, "文案随机性不足")
    }
}
```

---

## 2.5 UI 测试（XCUITest）

### Onboarding 流程测试

```swift
// OnboardingUITests.swift
class OnboardingUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        app = XCUIApplication()
        // 重置 Onboarding 状态，模拟首次安装
        app.launchArguments = ["--reset-onboarding"]
        app.launch()
    }
    
    // 验证 Onboarding 4页全部可以滑动通过
    func testOnboardingCanBeCompleted() {
        // 页1
        XCTAssertTrue(app.staticTexts["欢迎使用钱小满"].waitForExistence(timeout: 3))
        app.buttons["下一步"].tap()
        
        // 页2
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '项目'"))
            .firstMatch.waitForExistence(timeout: 2))
        app.buttons["下一步"].tap()
        
        // 页3
        app.buttons["下一步"].tap()
        
        // 页4（新增 AI 对话介绍页）
        XCTAssertTrue(app.staticTexts["跟小满聊天，轻松记账"].waitForExistence(timeout: 2))
        app.buttons["开始使用"].tap()
        
        // 验证进入主界面
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 3))
    }
    
    // 验证通知权限弹窗在 Onboarding 完成后出现
    func testNotificationPermissionPromptAfterOnboarding() {
        // 快速跳过所有页面
        skipToLastOnboardingPage()
        app.buttons["开始使用"].tap()
        
        // 验证提醒开启弹窗（自定义弹窗，非系统弹窗）
        XCTAssertTrue(app.staticTexts["要不要开启每日记账提醒？"].waitForExistence(timeout: 3))
    }
    
    // 验证 Onboarding 只展示一次
    func testOnboardingShownOnlyOnce() {
        skipAllOnboarding()
        
        // 重启 App（不重置状态）
        app.terminate()
        app = XCUIApplication()
        app.launch()
        
        // 验证直接进入主界面，不再显示 Onboarding
        XCTAssertFalse(app.staticTexts["欢迎使用钱小满"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 3))
    }
}
```

### AI 对话页引导测试

> ⚠️ **重要**: AI 对话页**不是**标准 Tab 页面。根据 `MainTabView.swift`，AI 对话通过底部栏的**自定义中央圆形按钮**（`AIAssistantButton`）点击触发，经 `NavigationLink` push 进入 `AIChatView`。底部 Tab 标签实际只有：「首页」「项目」「统计」「我的」四项，**不存在「AI对话」Tab**。测试中所有 `app.tabBars.buttons["AI对话"]` 都是错误的，应改为点击中央 AI 按钮。

```swift
// AIChatUITests.swift
class AIChatUITests: XCTestCase {
    
    // 辅助方法：点击底部中央 AI 助手按钮，进入 AIChatView
    // 按钮是自定义 View，无文字 label，通过 accessibilityIdentifier 定位
    // 需要在 AIAssistantButton 中添加: .accessibilityIdentifier("ai_assistant_button")
    private func openAIChat(app: XCUIApplication) {
        let aiButton = app.buttons["ai_assistant_button"]
        XCTAssertTrue(aiButton.waitForExistence(timeout: 3), "AI助手按钮应存在于底部导航栏")
        aiButton.tap()
    }
    
    // 辅助方法：返回主页（NavigationLink push 需要用 back 按钮或 swipe）
    private func closeAIChat(app: XCUIApplication) {
        // AIChatView 是 push 进来的，通过左滑手势返回
        app.swipeRight()
    }
    
    // 验证首次进入 AI 对话页出现引导 Overlay
    func testAIChatGuideOverlayOnFirstEntry() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-ai-guide"]
        app.launch()
        skipOnboarding(app: app)
        
        // 点击中央 AI 助手按钮（短按）
        openAIChat(app: app)
        
        // 验证引导 Overlay 出现
        XCTAssertTrue(app.staticTexts["小满在这里等你！"].waitForExistence(timeout: 3))
        
        // 点击「知道了」
        app.buttons["知道了"].tap()
        
        // 验证 Overlay 消失
        XCTAssertFalse(app.staticTexts["小满在这里等你！"].exists)
    }
    
    // 验证引导 Overlay 第二次进入不再显示
    func testAIChatGuideNotShownOnSecondEntry() {
        let app = XCUIApplication()
        app.launch()
        skipOnboarding(app: app)
        
        // 第一次进入，关掉引导
        openAIChat(app: app)
        if app.buttons["知道了"].waitForExistence(timeout: 2) {
            app.buttons["知道了"].tap()
        }
        
        // 返回主页再次进入
        closeAIChat(app: app)
        openAIChat(app: app)
        
        // 验证 Overlay 不再出现
        XCTAssertFalse(app.staticTexts["小满在这里等你！"].waitForExistence(timeout: 2))
    }
    
    // 验证空状态推荐话术气泡可点击并自动发送
    func testSuggestedPromptChipsFillAndSend() {
        let app = XCUIApplication()
        app.launch()
        skipOnboarding(app: app)
        openAIChat(app: app)
        dismissGuideIfPresent(app: app)
        
        // 话术 chip 应在 messages 为空时出现
        // 如果不存在则报失败（用 XCTAssertTrue 而非 if，防止静默跳过）
        let chip = app.buttons["午餐外卖35块"]
        XCTAssertTrue(chip.waitForExistence(timeout: 3), "空状态下推荐话术应显示")
        chip.tap()
        
        // 实现方案说「点击后自动填入输入框并发送」
        // 验证用户消息气泡已出现在聊天区（发送成功标志）
        XCTAssertTrue(app.staticTexts["午餐外卖35块"].waitForExistence(timeout: 3),
                      "点击话术后应自动发送，聊天气泡中应出现该文字")
    }
    
    // 验证语音输入（长按 AI 助手按钮触发录音）
    func testVoiceInputByLongPress() {
        let app = XCUIApplication()
        app.launch()
        skipOnboarding(app: app)
        
        let aiButton = app.buttons["ai_assistant_button"]
        XCTAssertTrue(aiButton.waitForExistence(timeout: 3))
        
        // 长按触发录音（500ms 阈值，按住1秒）
        aiButton.press(forDuration: 1.0)
        
        // 验证录音状态提示出现
        XCTAssertTrue(app.staticTexts["正在录音..."].waitForExistence(timeout: 2),
                      "长按后应显示录音状态提示")
    }
}
```

---

## 2.6 端到端集成测试

### 记账全流程（E2E）

```swift
// RecordTransactionE2ETests.swift
class RecordTransactionE2ETests: XCTestCase {
    
    // 完整流程：输入 → LLM 解析 → 确认卡片展示 → 确认保存 → 数据持久化
    func testCompleteRecordingFlow() async throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--clear-data"]
        app.launch()
        skipOnboarding(app: app)
        
        // 进入 AI 对话页（点击中央 AI 助手按钮，非标准 Tab）
        let aiButton = app.buttons["ai_assistant_button"]
        XCTAssertTrue(aiButton.waitForExistence(timeout: 3))
        aiButton.tap()
        dismissGuideIfPresent(app: app)
        
        // 输入记账语句
        let textField = app.textFields["说点什么..."]
        textField.tap()
        textField.typeText("午餐花了35块")
        app.buttons["发送"].tap()
        
        // 等待 LLM 响应（最多10秒）
        let confirmCard = app.otherElements["TransactionConfirmCard"]
        XCTAssertTrue(confirmCard.waitForExistence(timeout: 10), "应显示交易确认卡片")
        
        // 验证卡片内容
        XCTAssertTrue(app.staticTexts["¥35"].exists, "金额应为35元")
        XCTAssertTrue(app.staticTexts["餐饮"].exists, "分类应为餐饮")
        
        // 点击确认
        app.buttons["确认记账"].tap()
        
        // 验证成功状态
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '记好了'"))
            .firstMatch.waitForExistence(timeout: 3))
        
        // 返回主页（AIChatView 是 push 进来的，左滑返回）
        app.swipeRight()
        // 「首页」是真实的 Tab 标签（MainTabView 中定义为 title: "首页"）
        app.tabBars.buttons["首页"].tap()
        XCTAssertTrue(app.staticTexts["¥35.00"].waitForExistence(timeout: 3),
                      "首页应显示刚记录的交易")
    }
}
```

---

## 2.7 Mock 策略（避免 CI 中真实调用 LLM API）

```swift
// MockLLMService.swift（仅在 Test Target 中使用）
class MockLLMService: LLMServiceProtocol {
    
    // 预置的响应映射（输入关键词 → 固定输出）
    private let mockResponses: [String: TransactionParseResult] = [
        "午餐": TransactionParseResult(status: "success", amount: 35, type: "expense",
                                      groupName: "餐饮", categoryName: "午餐"),
        "打车": TransactionParseResult(status: "success", amount: 28, type: "expense",
                                      groupName: "出行", categoryName: "交通"),
        "花了50": TransactionParseResult(status: "need_clarification",
                                        reply: "你花的50块是用在哪里的呢？"),
    ]
    
    func parseTransaction(from text: String, context: String) async throws -> TransactionParseResult {
        for (keyword, result) in mockResponses {
            if text.contains(keyword) {
                return result
            }
        }
        return TransactionParseResult(status: "chat", reply: "我不太理解，能再说一遍吗？")
    }
}
```

> **注意**: 单元测试和 UI 测试默认使用 Mock；只有「AI 解析回归测试套件」才真实调用 LLM API（在专用 CI Job 中运行，非每次提交触发）。

---

## 2.8 CI/CD 集成方案

### GitHub Actions 配置（`.github/workflows/test.yml`）

```yaml
name: iOS Tests

# ⚠️ 一个 YAML 文件只能有一个 on: 块，schedule 必须合并进来
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 2 * * *'  # 每天 UTC 02:00（北京时间 10:00）触发 LLM 回归

jobs:
  unit-and-ui-tests:
    name: Unit & UI Tests
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.app
      
      - name: Run Unit Tests (with Mock LLM)
        run: |
          xcodebuild test \
            -project moneyfull_ios.xcodeproj \
            -scheme moneyfull_ios \
            -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4' \
            -testPlan UnitAndUITests \
            -resultBundlePath TestResults.xcresult
      
      - name: Upload Test Results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results
          path: TestResults.xcresult

  llm-regression:
    name: LLM Regression (Daily Only)
    runs-on: macos-15
    # 只在 main 分支的每日定时任务中运行，避免 API 费用
    if: github.ref == 'refs/heads/main' && github.event_name == 'schedule'
    steps:
      - uses: actions/checkout@v4
      
      - name: Run LLM Regression Tests
        env:
          LLM_API_KEY: ${{ secrets.LLM_API_KEY }}
        run: |
          xcodebuild test \
            -project moneyfull_ios.xcodeproj \
            -scheme moneyfull_ios \
            -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4' \
            -testPlan LLMRegression
      
      - name: Report Accuracy to Slack
        if: always()
        uses: slackapi/slack-github-action@v1
        with:
          payload: '{"text": "LLM 回归测试完成，通过率见 Actions"}'
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

---

## 2.9 测试覆盖率目标

| 模块 | 目标覆盖率 | 关键文件 |
|------|----------|---------|
| AppRatingManager | ≥ 95% | 全部条件分支必须覆盖 |
| NotificationManager | ≥ 90% | 注册/取消/周末判断 |
| LLMService 解析逻辑 | ≥ 85% | parseTransaction + JSON解析 |
| OnboardingView 流程 | ≥ 80% | UI 流程主路径 |
| AIChatView 交互 | ≥ 75% | 发送/接收/确认卡片 |
| AppStore 数据层 | ≥ 70% | CRUD 基础操作 |

---

## 2.10 测试执行计划

| 阶段 | 触发时机 | 测试类型 | 预计耗时 |
|------|---------|---------|---------|
| 本地开发 | 每次 `Cmd+U` | Unit Tests | < 30s |
| PR 提交 | push / PR | Unit + UI Tests | 5–8 min |
| 每日构建 | 凌晨定时 | 全量 + LLM 回归 | 15–20 min |
| 上线前 | 手动触发 | E2E 全流程 | 30 min |

---

## 2.11 快速开始

```bash
# 1. 在 Xcode 中新建 Test Target（如未创建）
# File → New → Target → iOS Unit Testing Bundle → 命名 moneyfull_iosTests

# 2. 在 Xcode 中新建 UI Test Target
# File → New → Target → iOS UI Testing Bundle → 命名 moneyfull_iosUITests

# 3. 运行全部测试
xcodebuild test \
  -project moneyfull_ios.xcodeproj \
  -scheme moneyfull_ios \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4'

# 4. 仅运行 AppRatingManager 测试
xcodebuild test \
  -project moneyfull_ios.xcodeproj \
  -scheme moneyfull_ios \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4' \
  -only-testing:moneyfull_iosTests/AppRatingManagerTests
```

---

---

## 2.12 开发接入前置工作

在运行测试之前，需要对代码做少量改动（仅测试辅助性，不影响业务逻辑）：

| 改动 | 位置 | 说明 |
|------|------|------|
| 定义 `LLMServiceProtocol` | `LLMService.swift` | 新增协议，让 `LLMService` 遵从，Mock 才能替换 |
| 添加 `accessibilityIdentifier` | `AIAssistantButton` | 加 `.accessibilityIdentifier("ai_assistant_button")`，XCUITest 才能定位 |
| 支持 `launchArguments` | `moneyfull_iosApp.swift` | 检测 `--reset-onboarding` / `--reset-ai-guide` / `--clear-data` 参数并重置对应 UserDefaults |
| `AppRatingManager` 支持注入 `UserDefaults` | `AppRatingManager.swift` | 构造函数改为 `init(defaults: UserDefaults = .standard)` |
| 创建 `LLMRegression` Test Plan | Xcode | `Product → Test Plan → New Test Plan`，仅包含 `LLMRegressionTests` |

---

*文档持续维护，每次新功能上线前更新黄金测试集。*
