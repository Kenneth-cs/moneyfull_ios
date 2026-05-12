---
name: capybara_interactions
overview: 实现首页小满的智能场景文案、点击交互动效（震动+弹跳）以及基于 Canvas 的眨眼微动效，提升 App 的情绪价值。
todos:
  - id: add-blinking-animation
    content: 在 CapybaraView 中加入 isBlinking 状态和 Timer，并在 Canvas 中根据状态更新眼睛的绘制路径以实现眨眼动效。
    status: pending
  - id: add-tap-interaction
    content: 在 GreetingMascotView 中添加 onTapGesture，集成软震动反馈 (UIImpactFeedbackGenerator) 以及点击弹跳 (scaleEffect + spring) 的动效。
    status: pending
  - id: add-smart-quotes
    content: 在 GreetingMascotView 中接入 AppStore 数据，编写场景化文案生成逻辑（按时间、按最新记账状态等）。
    status: pending
  - id: integrate-quotes-and-taps
    content: 结合点击事件，实现点击时随机切换互动专属文案的逻辑，覆盖当前的智能文案。
    status: pending
isProject: false
---

# 小满交互动效与智能文案开发规划

为了让首页的小满更加生动有趣，我们将从**智能文案**、**点击互动**和**微动效**三个维度对其进行升级。以下是具体的开发方案：

### 1. 🤖 场景化智能文案 (Smart Quotes)
目前 `GreetingMascotView` 中的气泡文案是静态的。我们将注入 `@EnvironmentObject var store: AppStore`，并编写一个文案生成引擎，使其能感知上下文：
*   **动作感知优先**：检查 `store.recentTransactions.first` 的时间，如果是刚记完账（如 1 分钟内），提示：“记账+1，离财务自由又近了一步✨”。
*   **时间感知**：根据当前时段输出不同问候：
    *   早上 (06:00-10:00)：“早安，新的一天也要佛系理财哦～”
    *   中午 (11:00-14:00)：“午餐吃了什么好吃的？记得记一笔呀🍱”
    *   深夜 (22:00-05:00)：“夜深啦，橘子要掉了，快睡吧💤”
*   **随机兜底**：如果没有触发特定条件，则从一个日常“佛系语录”数组中随机抽取。

### 2. 👆 趣味点击互动 (Tap to Interact)
为小满增加“解压玩具”的属性：
*   **震动与视觉反馈**：在 `GreetingMascotView` 为小满添加 `onTapGesture`。点击时触发 `UIImpactFeedbackGenerator(style: .soft)` 提供轻微物理震动，同时使用 `.spring` 动画让 `CapybaraView` 的 `scaleEffect` 瞬间变小（被按扁）再弹回。
*   **文案打断机制**：每次点击时，覆盖当前的智能文案，从“互动语录库”（如：“别戳我，橘子会掉的🍊”、“再戳我要收撸豚费了！”）中随机展示一句。

### 3. 👀 微动效升级 (Micro-animations)
由于现在的 `CapybaraView` 是用纯 `Canvas` 绘制的，我们可以通过传入动态变量让它“活”起来：
*   **随机眨眼**：在 `CapybaraView` 中新增 `@State private var isBlinking = false`，通过 `Timer.publish(every: 4.0, ...)` 随机触发眨眼。在 Canvas 绘制眼睛 `Path` 时，根据 `isBlinking` 的状态将弧度压平，实现闭眼的视觉效果。
*   **动效融合**：眨眼动效与原有的呼吸上下浮动 (`isBreathing`) 可以完美叠加，互不干扰。

### 涉及修改的文件
- `[moneyfull_ios/Components/CommonViews.swift](moneyfull_ios/Components/CommonViews.swift)`：修改 `CapybaraView` 添加眨眼绘制参数；修改 `GreetingMascotView` 添加点击事件、震动、AppStore 数据接入和文案生成逻辑。
- `[moneyfull_ios/Views/DashboardView.swift](moneyfull_ios/Views/DashboardView.swift)`：目前 DashboardView 在调用 `GreetingMascotView()` 时尚未传入数据环境，如有需要将确保环境连通。

---
**确认该规划后，我将依次为你实现上述三个模块的代码！**