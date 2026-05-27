---
name: Phase1 非付费功能开发
overview: 实现 v2.0 规划中所有与 IAP/付费无关的功能：分类持久化、交易编辑删除、iCloud CloudKit 备份、体验打磨（Haptic/深色模式/空状态）、隐私政策页。
todos:
  - id: step1-category-appstore
    content: "Step 1: AppStore 新增 categories Published + fetchCategories + seedDefaultCategories + addCategory + deleteCategory"
    status: pending
  - id: step1-category-addrecord
    content: "Step 1: AddRecordView 改为从 store.categories 读取，删除硬编码 CategoryInfo 数组"
    status: pending
  - id: step1-category-management-view
    content: "Step 1: 新建 CategoryManagementView，ProfileView 加入分类管理入口"
    status: pending
  - id: step2-transaction-appstore
    content: "Step 2: AppStore 新增 updateTransaction 方法"
    status: pending
  - id: step2-transaction-detail
    content: "Step 2: ProjectDetailView 加 swipeActions 删除/编辑，新建 EditTransactionView"
    status: pending
  - id: step3-models-cloudkit
    content: "Step 3: Models.swift 所有属性加默认值，@Relationship 改为 .nullify，deleteProject 手动删关联 transactions"
    status: pending
  - id: step3-app-cloudkit
    content: "Step 3: moneyfull_iosApp.swift 切换为 CloudKit ModelConfiguration + 启动错误处理"
    status: pending
  - id: step3-backup-ui
    content: "Step 3: AppStore 加备份状态追踪，ProfileView 加「数据安全」section"
    status: pending
  - id: step4-haptic
    content: "Step 4: 全局补充 Haptic 反馈（Tab切换、删除、大额输入）"
    status: pending
  - id: step4-darkmode-emptystate
    content: "Step 4: 深色模式适配 + 空状态卡皮引导文案"
    status: pending
isProject: false
---

# Phase 1：非付费功能开发计划

## 当前代码关键现状

- `Category` 模型已在 SwiftData schema 注册，但 `AppStore` 从未读写它；`AddRecordView` 用文件级常量 `let categories: [CategoryInfo]` 硬编码 8 个分类
- `AppStore.deleteTransaction` 已实现，但 `ProjectDetailView` 中 `TimelineTxRow` 无删除/编辑 UI
- `ProfileView` 导出按钮是一个空 alert，无分类管理入口
- `.modelContainer(for: [Project.self, Transaction.self, Category.self])` 当前无 CloudKit

---

## Step 1 — 分类持久化（约 1 天）

**目标**：把硬编码分类替换为 SwiftData 持久化，支持自定义增删。

### AppStore.swift 改动

- 新增 `@Published var categories: [Category] = []`
- 新增 `fetchCategories()`：`FetchDescriptor<Category>` 按 `createdAt` 排序
- `setupDefaultDataIfNeeded()` 中补充 `seedDefaultCategories()`：检查 `categories.count == 0` 时插入 11 个系统预设（餐饮/交通/购物/娱乐/住房/医疗/教育/通讯/服饰/日用/其他），`isGlobal: true`
- 新增 `addCategory(name:icon:colorHex:)` 和 `deleteCategory(_:)`
- `refresh()` 中加入 `fetchCategories()`

### AddRecordView.swift 改动

- 删除文件底部 `struct CategoryInfo` 和 `let categories` 常量
- `@State private var selectedCategory` 初始值改为 `store.categories.first ?? Category(...)` （需在 `onAppear` 中设置，因为 `store` 是 `@EnvironmentObject`）
- 分类 Grid 改为遍历 `store.categories`

### ProfileView.swift 改动

- 新增 "分类管理" `MenuItem`，点击 → `CategoryManagementView`（新文件）
- `CategoryManagementView`：列表展示 `store.categories`，支持滑动删除（`isGlobal: false` 的才可删）；底部"添加自定义分类" Sheet，输入名称 + 选 SF Symbol 图标

---

## Step 2 — 交易记录编辑 / 删除（约 1 天）

**目标**：ProjectDetailView 的 Timeline 支持删除和编辑。

### AppStore.swift 改动

新增 `updateTransaction(_:amount:type:categoryName:categoryIcon:categoryColorHex:note:date:)` 方法，修改字段后调用 `save()` + `refresh()`。

### ProjectDetailView.swift 改动

- 将 `ForEach(group.value)` 中的 `TimelineTxRow` 包裹进 swipe action：

```swift
TimelineTxRow(transaction: tx, accentColor: ...)
    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
        Button(role: .destructive) {
            store.deleteTransaction(tx)
        } label: { Label("删除", systemImage: "trash") }
    }
    .swipeActions(edge: .leading) {
        Button { editingTransaction = tx } label: {
            Label("编辑", systemImage: "pencil")
        }.tint(.orange)
    }
```

- 新增 `@State private var editingTransaction: Transaction?`，`.sheet(item: $editingTransaction)` → `EditTransactionView`

### EditTransactionView.swift（新文件）

- 与 `AddRecordView` 同结构，但接收一个 `Transaction` 作为初始值，完成后调用 `store.updateTransaction(...)`

---

## Step 3 — iCloud CloudKit 备份（约 2 天）

**目标**：用户换机/重装后数据不丢失，ProfileView 展示备份状态。

### 前提：Xcode 手动操作（非代码）

1. Target → Signing & Capabilities → "+" → iCloud → 勾选 CloudKit → 新建容器 `iCloud.com.yourapp.moneyfull`
2. 同页面 → "+" → Background Modes → 勾选 Remote notifications

### Models.swift 改动（CloudKit 兼容性要求）

CloudKit 要求所有属性有默认值，需为每个属性添加默认值：

```swift
// 修改前
var name: String

// 修改后
var name: String = ""
var icon: String = ""
var colorHex: String = "#A8E6CF"
// ... 其他属性同理
```

`Project` 中的关系需改为 `.nullify`：

```swift
// CloudKit 不支持 cascade deleteRule，改为 nullify
@Relationship(deleteRule: .nullify)
var transactions: [Transaction] = []
```

（注意：删除 Project 时需手动删除其 transactions，在 `AppStore.deleteProject` 中补充）

### moneyfull_iosApp.swift 改动

```swift
.modelContainer(
    for: [Project.self, Transaction.self, Category.self],
    configurations: ModelConfiguration(cloudKitDatabase: .automatic)
)
```

包裹在 `do/catch` 中，容器创建失败时展示错误视图而非崩溃。

### AppStore.swift 改动

- `save()` 成功后更新 `UserDefaults` 的 `lastBackupDate`
- 新增 `var lastBackupDate: Date?`（从 UserDefaults 读取）
- 新增 `func dataStats() -> (projectCount: Int, transactionCount: Int)`

### ProfileView.swift 新增「数据安全」section

```
上次备份：今天 14:30（或"未备份"）
数据量：XX 个项目 · XX 笔账单
[立即备份] 按钮 → 触发 store.save() + 更新 lastBackupDate
```

### ContentView.swift 改动

App 启动时 SwiftData 容器加载异常时，展示 "数据加载失败" 视图 + 联系支持按钮，而非白屏。

---

## Step 4 — 体验打磨（约 1 天）

### Haptic 反馈

- Tab 切换：`UISelectionFeedbackGenerator().selectionChanged()`（`CustomBottomTabBar` 的 `onTapGesture`）
- 记账保存成功：`UINotificationFeedbackGenerator().notificationOccurred(.success)`（已有，确认保留）
- 删除交易：`UINotificationFeedbackGenerator().notificationOccurred(.warning)`
- 大额输入 >1000：`UIImpactFeedbackGenerator(style: .medium).impactOccurred()`（`AddRecordView` 的数字键盘 onChange）

### 深色模式

- `Color.App` 已有 token，需为以下情况加深色 variant：
  - 白色卡片背景 `Color.white` → `Color(.systemBackground)`
  - 浅灰背景 `Color(.systemGray6)` 已适配，确认统一使用
  - 渐变卡片颜色（Dashboard 看板、项目卡片）在深色下加深底色
- 逐视图检查：DashboardView、ProjectsView、ProjectDetailView、AnalyticsView、ProfileView

### 空状态

- `ProjectsView` 进行中列表为空：展示 `GreetingMascotView` + "慢慢规划，不着急，我在这儿陪你。"
- `DashboardView` 无近期交易：展示 "还没有记录，点 + 开始吧" + 小卡皮图

---

## Step 5 — 隐私政策页（约 0.5 天）

- 新建 `PrivacyPolicyView`，用 `SafariServices.SFSafariViewController` 包裹外链（或本地 HTML WKWebView）
- `ProfileView` 的「帮助与反馈」MenuItem 下方新增「隐私政策」MenuItem

---

## 文件改动汇总

| 文件 | 操作 |
|------|------|
| [`Models/Models.swift`](moneyfull_ios/Models/Models.swift) | 所有属性加默认值；`@Relationship` 改为 `.nullify` |
| [`Models/AppStore.swift`](moneyfull_ios/Models/AppStore.swift) | 分类 CRUD、`updateTransaction`、备份状态、`dataStats` |
| [`moneyfull_iosApp.swift`](moneyfull_ios/moneyfull_iosApp.swift) | CloudKit ModelConfiguration + 错误处理 |
| [`Views/AddRecordView.swift`](moneyfull_ios/Views/AddRecordView.swift) | 分类从 store 读取；删除 hardcode |
| [`Views/ProjectDetailView.swift`](moneyfull_ios/Views/ProjectDetailView.swift) | swipeActions 删除/编辑；editingTransaction state |
| [`Views/ProfileView.swift`](moneyfull_ios/Views/ProfileView.swift) | 分类管理入口；数据安全 section；隐私政策入口 |
| [`Views/EditTransactionView.swift`](moneyfull_ios/Views/EditTransactionView.swift) | 新建：编辑交易 Sheet |
| [`Views/CategoryManagementView.swift`](moneyfull_ios/Views/CategoryManagementView.swift) | 新建：分类管理页 |
| [`Views/PrivacyPolicyView.swift`](moneyfull_ios/Views/PrivacyPolicyView.swift) | 新建：隐私政策 WebView |

---

## 开发顺序建议

```
Day 1    : Step 1 分类持久化
Day 2    : Step 2 交易编辑删除
Day 3-4  : Step 3 CloudKit备份（Xcode 配置 + 代码）
Day 5    : Step 4 体验打磨 + Step 5 隐私政策
```
