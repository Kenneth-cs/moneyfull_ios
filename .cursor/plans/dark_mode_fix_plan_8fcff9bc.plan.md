---
name: Dark Mode Fix Plan
overview: Refactor Colors.swift to use dynamic colors that adapt to iOS Dark Mode, and update views to use correct semantic colors for contrast.
todos:
  - id: color-dynamic-helper
    content: 在 Colors.swift 中添加 dynamic 颜色辅助函数
    status: pending
  - id: color-palette-update
    content: 更新 Colors.swift 中的所有静态颜色为 dynamic 动态颜色，并新增 textOnPrimary 等语义色
    status: pending
  - id: dashboard-view-update
    content: 更新 DashboardView，替换顶部卡片文字颜色为 textOnPrimary，修复半透明玻璃背景和进度条底色
    status: pending
  - id: maintab-view-update
    content: 更新 MainTabView，修复「+」按钮图标颜色
    status: pending
  - id: other-views-update
    content: 更新 AddRecordView 和 ProfileView 等其他视图中的冲突颜色
    status: pending
isProject: false
---

# 深色模式（Dark Mode）修复与适配方案

## 1. 问题分析
根据截图和代码分析，当前深色模式显示异常的原因在于**颜色定义的混合使用**：
- 核心背景色（如 `backgroundGray` `#F9F9F9`）和文字颜色（如 `textBlack` `#1A1C1C`）是**写死的静态 Hex 颜色**，在深色模式下不会反转。
- 卡片背景色 `cardBackground` 使用了 `Color(.systemBackground)`，它**会**随系统变为黑色。
- 这导致了深色模式下：主背景依然是白色，卡片变成了黑色，而卡片上的文字依然是黑色，最终导致“黑底黑字”且背景刺眼的问题。

## 2. 解决思路
我们将重构 `Colors.swift`，引入动态颜色生成器，并为所有静态颜色分配深色模式下的对应色值。同时，拆分部分语义冲突的颜色（例如在浅色背景上的深绿 vs 在深色背景上的深绿）。

### 2.1 重构 `Colors.swift`
引入 `dynamic(light:dark:)` 辅助函数，利用 `UIColor` 的 `traitCollection` 动态返回颜色：
- `backgroundGray`: 浅色 `#F9F9F9` -> 深色 `#000000` (纯黑背景)
- `cardBackground`: 浅色 `#FFFFFF` -> 深色 `#1C1C1E` (深灰卡片)
- `tabBackground`: 浅色 `#F3F3F3` -> 深色 `#1C1C1E` (深灰底栏)
- `textBlack`: 浅色 `#1A1C1C` -> 深色 `#F5F5F5` (灰白文字)
- `redExpense`: 浅色 `#BA1A1A` -> 深色 `#FF6B6B` (亮红，适应深色底)

### 2.2 品牌绿色的语义拆分
顶部大卡片和「+」按钮使用的是 `primaryGreen`（浅亮绿色）。为了保持品牌调性，深色模式下大卡片和主按钮依然保持亮色。因此，其上面的文字必须**始终保持深色**。
- `primaryGreen`: 保持 `#A8E6CF`（始终亮绿）
- `darkGreen`: 浅色 `#2C6957` -> 深色 `#63C7A1`（动态主题绿，用于深色背景上的文字/图标，如“查看全部”）
- **新增** `textOnPrimary`: 浅色 `#2C6957` -> 深色 `#1A4034`（始终深绿，专用于在 `primaryGreen` 背景上的文字，如顶部卡片的“当前支出”）

### 2.3 视图层细节修复
- **DashboardView**: 
  - 顶部卡片文字、`FinanceInfoCard` 文字改为使用 `textOnPrimary`。
  - `FinanceInfoCard` 的背景从 `cardBackground.opacity(0.5)` 改为 `Color.white.opacity(0.4)`，确保在亮绿色卡片上始终呈现白色玻璃态。
  - 进度条底轨 `#F0F0F0` 替换为动态的 `progressTrack`（深色模式下为 `#333333`）。
- **MainTabView**: 底部中央「+」按钮的加号图标改为 `textOnPrimary`。
- **AddRecordView / ProfileView**: 保存按钮文字、统计卡片文字等根据背景色替换为对应的语义色。

## 3. 预期效果
修复后，深色模式下主背景将变为纯黑，卡片为深灰色，文字变为白色。顶部的绿色财务看板依然保持品牌亮绿色，但其上的文字会加深以保证极佳的对比度，整体视觉将非常和谐且符合 iOS 规范。