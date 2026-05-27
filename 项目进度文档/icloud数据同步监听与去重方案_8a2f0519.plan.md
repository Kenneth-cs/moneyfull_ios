---
name: iCloud数据同步监听与去重方案
overview: 本项目计划解决 iCloud 数据同步后界面不刷新以及可能的重复数据问题。首先通过监听 `NSManagedObjectContextObjectsDidChange` 通知自动刷新界面，其次改进默认数据生成逻辑，避免本地创建的默认数据与云端拉取的默认数据重复。
todos:
  - id: add_notification_listener
    content: 在 AppStore.swift 的 init 中添加 NotificationCenter 监听 NSManagedObjectContextObjectsDidChange 以触发 refresh()
    status: pending
  - id: write_dedup_logic
    content: 在 AppStore.swift 中编写 deduplicateDefaultProjects() 和 deduplicateCategories() 方法
    status: pending
  - id: integrate_dedup_logic
    content: 在 AppStore.refresh() 或其他合适的时机调用去重方法，确保界面展示正确无重复的数据
    status: pending
isProject: false
---

# iCloud 数据同步监听与去重方案

## 背景

当前应用使用 SwiftData 并开启了 CloudKit 支持。当用户重新安装应用或在新设备上登录时，CloudKit 会在后台静默下载数据。由于 `AppStore` 没有监听底层数据变化，导致界面无法及时刷新。同时，本地的 `setupDefaultDataIfNeeded` 逻辑在空数据时会创建默认的“日常收支”项目和预设分类，当云端的默认数据同步下来后，会出现数据重复的问题。

## 方案目标

1.  **自动刷新界面：** 监听底层数据库变化通知，当 CloudKit 同步新数据时自动调用 `AppStore.refresh()` 更新界面。
2.  **避免默认数据重复：** 引入数据去重逻辑，确保系统生成的默认分类和“日常收支”项目在本地和云端数据合并时不会产生冗余副本。

## 详细实施步骤

### 1. 添加后台数据变化监听 (`AppStore.swift`)

由于 SwiftData 目前底层基于 Core Data，我们可以通过监听 `NSManagedObjectContextObjectsDidChange` 或相关通知来捕获数据的变化。

*   **修改点:** 在 `AppStore` 的 `init(modelContext:)` 方法中添加 `NotificationCenter` 观察者。
*   **动作:** 当收到通知时，调用 `self.refresh()` 以获取最新数据。为避免频繁刷新，可以考虑加一个短暂的 debounce。

### 2. 改进默认分类生成与去重 (`AppStore.swift`)

默认分类的生成逻辑 `seedDefaultCategoriesIfNeeded` 需要更智能，不只是检查数量为 0。

*   **修改点 1:** 在 `seedDefaultCategoriesIfNeeded` 执行之前，检查当前是否已经存在同名同类型的分类。
*   **修改点 2:** 对于分类迁移逻辑 (如 `migrateV2Categories`, `migrateV3Categories`)，确保查找逻辑能正确识别并更新已有的云端分类。

### 3. 处理“日常收支”项目的去重 (`AppStore.swift` & `Models.swift`)

当 iCloud 数据同步下来时，如果本地在刚安装时已经创建了一个新的“日常收支”，可能会出现两个“日常收支”。

*   **修改点:** 可以给 `Project` 模型添加一个标识，或者根据名字 "日常收支" 来判断。如果发现多个“日常收支”，进行合并或删除本地新创建的无数据的副本。更安全的做法是，在应用刚启动发现无数据准备创建“日常收支”时，可以利用 `UserDefaults` 记录“本地首次生成”的状态。但考虑到 CloudKit 的延迟，最好在 `refresh()` 拉取到数据时，做一次**项目去重检查**。

*   **去重逻辑:** 在 `fetchProjects()` 或 `refresh()` 的最后，检查 `activeProjects`。如果发现多个名字为“日常收支”的项目，保留最早创建（或有交易记录的）那一个，并将其他冗余的“日常收支”删除，并把对应的账单（如果有）转移到保留的那个项目中。

## 核心代码参考

**监听通知：**

```swift
NotificationCenter.default.addObserver(
    forName: .NSManagedObjectContextObjectsDidChange,
    object: nil,
    queue: .main
) { [weak self] notification in
    // 检查是否有实质性变化再刷新，或者简单粗暴直接刷新
    self?.refresh()
}
```

**简单的去重逻辑框架（项目）：**

```swift
private func deduplicateDefaultProjects() {
    // 查找所有名为“日常收支”的项目
    let dailyProjects = activeProjects.filter { $0.name == "日常收支" }
    if dailyProjects.count > 1 {
        // 找到有数据的，或者创建时间最早的作为主项目
        let sorted = dailyProjects.sorted { ($0.transactions?.count ?? 0) > ($1.transactions?.count ?? 0) }
        let mainProject = sorted.first!
        let duplicates = sorted.dropFirst()
        
        for duplicate in duplicates {
            // 转移交易记录到主项目
            if let txs = duplicate.transactions {
                for tx in txs {
                    tx.project = mainProject
                    mainProject.transactions?.append(tx)
                }
            }
            // 删除重复项目
            modelContext.delete(duplicate)
        }
        try? modelContext.save()
        // 重新拉取
        fetchProjects()
    }
}
```