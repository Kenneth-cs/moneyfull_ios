# AI 复盘总结系统 PRD

> 版本：V1.0
> 作者：钱小满产品团队
> 更新日期：2026-07-15
> 状态：待评审

---

## 一、背景与目标

### 1.1 问题诊断

当前项目复盘的 AI 总结存在以下问题：

**数据输入过薄**：生活模式仅传 5 个数据点（总支出、预算、持续天数、日均花费、最大三笔支出），搞钱模式仅传 7 个。数据量不足以支撑有深度的分析。

**输出质量平庸**：由于输入数据有限，AI 只能生成"这次旅行预算控制得不错"之类的正确废话——用户自己看数字也能得出同样结论。

**缺乏结构化洞察**：当前输出为扁平的 `summary` 字符串，无法在 UI 上做层次化展示，视觉冲击力弱。

**专业度不足**：没有引入金融分析工具（如 HHI 指数、利润率基准线），无法体现产品的专业差异性。

### 1.2 设计目标

| 目标 | 指标 |
|------|------|
| 数据驱动 | 每条 AI 洞察必须引用 ≥1 个具体数字 |
| 专业可信 | 引入金融/统计分析工具，给出基准线对比 |
| 实用导向 | 输出可执行的下次行动建议 |
| 结构化展示 | 多维度卡片式洞察流，视觉层次分明 |
| 双模式覆盖 | 生活模式和搞钱模式各有针对性分析 |

### 1.3 核心设计原则

```
✅ 真专业（基于数据可验证）        ❌ 伪专业（胡编乱造）
─────────────────────────────────────────────────────────
"餐饮超预算 38%"                  "你可能在当地吃了太多特色美食"
"前 4 天花了 56%"                  "你的旅行节奏前松后紧"
"日均 ¥1,150，高于预算节奏"       "消费偏高，建议控制"
"利润率 29%，低于 40% 健康线"     "这个项目赚得不多"
"时间成本占 48%"                  "你在这个项目上花了很多时间"
```

**原则**：AI 只做两件事——① 把数据翻译成可读的话；② 给出有数据支撑的判断基准（如"40% 健康线"）。不做主观推测（"你可能…"），不做无法验证的评价。

---

## 二、分析维度总览

### 2.1 生活模式（旅行/装修/约会等）

| 维度 | 核心问题 | 数据来源 |
|------|----------|----------|
| 预算执行结构 | 各分类花得合理吗？ | `budgetItems` + `transactions` 按分类聚合 |
| 消费结构画像 | 钱花得均不均匀？ | 各分类占比 + HHI 指数 |
| 时间维度分析 | 消费节奏如何？ | transactions 按日期分组 |
| 历史对比 | 比上次花得多吗？ | 历史同类项目数据 |
| 行动建议 | 下次怎么花更好？ | 以上所有维度综合 |

### 2.2 搞钱模式（外包/副业/接单等）

| 维度 | 核心问题 | 数据来源 |
|------|----------|----------|
| 盈利能力评估 | 赚了多少？赚得好吗？ | `netProfit`、`roi`、利润率 |
| 时间价值分析 | 时间花得值吗？ | `effectiveHourlyRate`、`totalHourEquivalent` |
| 成本结构拆解 | 钱花在哪了？ | `totalTimeCost`、`fixedCosts`、分类支出 |
| 经营效率趋势 | 回款和支出节奏？ | transactions 按时间分布 |
| 报价建议 | 下次接单怎么报价？ | 以上所有维度综合 |

---

## 三、生活模式详细设计

### 3.1 维度一：预算执行结构

**核心洞察**：不只是总执行率，而是分类级别的预算执行拆解。

#### 数据计算逻辑

```swift
// 分类预算执行率
for item in budgetItems {
    let actual = transactions
        .filter { $0.type == .expense && $0.categoryName == item.categoryName }
        .reduce(0) { $0 + abs($1.amount) }
    let ratio = item.amount > 0 ? actual / item.amount : 0
    // ratio > 1 = 超支，ratio < 1 = 节余
}

// 超支/节余排序
let overruns = categoryBreakdown.filter { $0.ratio > 1 }.sorted { $0.ratio > $1.ratio }
let savings = categoryBreakdown.filter { $0.ratio < 1 }.sorted { $0.ratio < $1.ratio }

// 未分配预算占比
let unallocatedRatio = budgetUnallocated / budget
```

#### AI 输出示例

```
🎯 预算执行
─────────────────────────────
总执行率 92%（¥9,200 / ¥10,000）

分类明细：
  🏨 住宿  ¥2,400 / ¥3,000  → 省 ¥600（80%）
  🍜 餐饮  ¥1,380 / ¥1,000  → 超 ¥380（138%）⚠️
  🚗 交通  ¥2,100 / ¥2,500  → 省 ¥400（84%）
  🎫 门票  ¥1,800 / ¥2,000  → 省 ¥200（90%）
  🛍️ 购物  ¥1,520 / ¥1,500  → 基本持平（101%）

💡 最大惊喜：住宿省了 ¥600
⚠️ 最大缺口：餐饮超了 ¥380
```

#### JSON 输出结构

```json
{
  "budget_execution": {
    "overall_ratio": 0.92,
    "overall_label": "优秀",
    "categories": [
      {
        "name": "住宿",
        "budgeted": 3000,
        "actual": 2400,
        "ratio": 0.80,
        "status": "saving",
        "delta": -600
      },
      {
        "name": "餐饮",
        "budgeted": 1000,
        "actual": 1380,
        "ratio": 1.38,
        "status": "overrun",
        "delta": 380
      }
    ],
    "best_category": {"name": "住宿", "saved": 600},
    "worst_category": {"name": "餐饮", "overrun": 380},
    "unallocated_ratio": 0.0
  }
}
```

---

### 3.2 维度二：消费结构画像

**核心洞察**：钱花得均不均匀，消费是否"偏食"。

#### HHI 指数（赫芬达尔指数）

HHI 是金融领域衡量市场集中度的标准工具，这里用于衡量消费集中度：

```swift
// HHI = Σ(份额²)，范围 0~1
// < 0.15 = 分散（健康）
// 0.15~0.25 = 中等集中
// > 0.25 = 高度集中（偏食）
let segments = categoryBreakdown.map { $0.actual / totalSpent }
let hhi = segments.reduce(0) { $0 + $1 * $1 }
```

#### 大件 vs 日常消费比

```swift
// 大件识别：基于项目类型配置的关键词
let bigItemKeywords = projectTypeConfig.bigItemKeywords
let bigItemAmount = transactions
    .filter { tx in tx.type == .expense && bigItemKeywords.contains(where: { tx.categoryName.contains($0) }) }
    .reduce(0) { $0 + abs($1.amount) }
let bigItemRatio = bigItemAmount / totalSpent
let dailyFreeAmount = (totalSpent - bigItemAmount) / Double(totalDays)
```

#### 单笔消费分布

```swift
let amounts = transactions.filter { $0.type == .expense }.map { abs($0.amount) }
let maxSingle = amounts.max() ?? 0
let avgSingle = amounts.reduce(0, +) / Double(max(amounts.count, 1))
let medianSingle = amounts.sorted()[amounts.count / 2]
let volatility = maxSingle / avgSingle  // 波动系数
```

#### AI 输出示例

```
📊 消费结构
─────────────────────────────
消费集中度：0.18（中等分散）
→ 消费结构健康，没有单一分类独大

大件 vs 日常：
  大件消费（机票+住宿）¥4,500，占 49%
  日常自由消费 ¥460/天
  → 大件锁定后，每天有 ¥460 可灵活支配

单笔消费：
  最大单笔 ¥2,400（机票）
  平均单笔 ¥85
  中位数 ¥62
  → 波动系数 28x，消费跨度大，属正常旅行节奏
```

#### JSON 输出结构

```json
{
  "consumption_structure": {
    "hhi_index": 0.18,
    "hhi_label": "中等分散",
    "big_item_amount": 4500,
    "big_item_ratio": 0.49,
    "daily_free_amount": 460,
    "single_transaction": {
      "max": 2400,
      "max_category": "机票",
      "average": 85,
      "median": 62,
      "volatility": 28.2
    }
  }
}
```

---

### 3.3 维度三：时间维度分析

**核心洞察**：消费节奏——前松后紧还是前紧后松？

#### 前半段 vs 后半段

```swift
let sortedTxs = transactions.filter { $0.type == .expense }.sorted { $0.date < $1.date }
let midIndex = sortedTxs.count / 2
let firstHalfSpent = sortedTxs.prefix(midIndex).reduce(0) { $0 + abs($1.amount) }
let secondHalfSpent = sortedTxs.suffix(from: midIndex).reduce(0) { $0 + abs($1.amount) }
let firstHalfRatio = firstHalfSpent / totalSpent
```

#### 消费高峰日

```swift
let dailyExpenses = Dictionary(grouping: transactions.filter { $0.type == .expense }) { tx in
    Calendar.current.startOfDay(for: tx.date)
}
let dailyTotals = dailyExpenses.mapValues { txs in txs.reduce(0) { $0 + abs($1.amount) } }
let peakDay = dailyTotals.max { $0.value < $1.value }
```

#### 消费频率

```swift
let txCount = transactions.filter { $0.type == .expense }.count
let frequency = Double(txCount) / Double(totalDays)  // 日均记账笔数
```

#### AI 输出示例

```
⏱️ 消费节奏
─────────────────────────────
前半段（Day 1-4）：¥5,200（56%）
后半段（Day 5-8）：¥4,000（44%）
→ 越玩越省，后半段收敛了

消费高峰：第 3 天 ¥2,100
→ 那天花了全程最多的钱

消费频率：日均 3.2 笔
→ 记账习惯稳定，数据可信度高
```

#### JSON 输出结构

```json
{
  "time_analysis": {
    "first_half_spent": 5200,
    "first_half_ratio": 0.56,
    "second_half_spent": 4000,
    "second_half_ratio": 0.44,
    "trend_label": "越玩越省",
    "peak_day": {
      "day_number": 3,
      "amount": 2100,
      "top_category": "餐饮"
    },
    "avg_daily_transactions": 3.2
  }
}
```

---

### 3.4 维度四：历史对比

**核心洞察**：和自己比，才有意义。

#### 对比逻辑

```swift
// 查找历史同类项目（已归档、非默认项目）
let historicalProjects = allArchivedProjects.filter { $0.id != project.id }

// 如有同类项目，计算对比指标
if let similar = findSimilarProject(current: project, historical: historicalProjects) {
    let dailyDiff = (project.dailyAvgSpend - similar.dailyAvgSpend) / similar.dailyAvgSpend
    let budgetDiff = project.budgetProgress - similar.budgetProgress
    // ...
}
```

#### AI 输出示例

```
📈 历史对比
─────────────────────────────
对比「厦门之旅」（2025年国庆）：
  日均花费：¥1,150 vs ¥950 → 高 21%
  预算执行：92% vs 88% → 控制更好
  持续天数：8 天 vs 5 天 → 多玩了 3 天

→ 花得更多，但玩得更久，预算控制更精细
```

#### JSON 输出结构

```json
{
  "historical_comparison": {
    "has_comparison": true,
    "similar_project_name": "厦门之旅",
    "similar_project_date": "2025-10",
    "daily_avg_diff": 0.21,
    "budget_progress_diff": -0.04,
    "days_diff": 3,
    "summary": "花得更多，但玩得更久，预算控制更精细"
  }
}
```

---

### 3.5 维度五：行动建议

**核心洞察**：不只是"下次少花点"，而是具体到分类的可执行建议。

#### 建议生成逻辑

```swift
// 分类预算调整建议
for item in categoryBreakdown {
    let suggestedAmount: Double
    if item.ratio > 1 {
        // 超支分类：实际 × 1.05 缓冲
        suggestedAmount = item.actual * 1.05
    } else {
        // 节余分类：取实际和预算的加权平均
        suggestedAmount = item.actual * 0.7 + item.budgeted * 0.3
    }
    suggestions.append((name: item.name, amount: suggestedAmount, reason: reason))
}

// 总预算建议
let suggestedTotal = suggestions.reduce(0) { $0 + $1.amount }
```

#### AI 输出示例

```
💡 下次同类项目预算建议
─────────────────────────────
基于本次数据 × 1.05 缓冲系数：

  🍜 餐饮  ¥1,450（本次实际 ¥1,380 × 1.05）
  🏨 住宿  ¥2,520（本次实际 ¥2,400 × 1.05）
  🚗 交通  ¥2,200（本次实际 ¥2,100 × 1.05）
  🎫 门票  ¥1,890（本次实际 ¥1,800 × 1.05）
  🛍️ 购物  ¥1,596（本次实际 ¥1,520 × 1.05）

建议总预算：¥9,656（本次 ¥10,000 的 97%）
→ 下次可以稍微收紧预算，因为你已经知道怎么花了
```

---

## 四、搞钱模式详细设计

### 4.1 维度一：盈利能力评估

#### 核心指标

```swift
// 利润率
let profitMargin = totalIncome > 0 ? netProfit / totalIncome : 0

// ROI 评级
let roiRating: String
switch roi {
case ..<0: roiRating = "亏损"
case 0..<20: roiRating = "低回报"
case 20..<40: roiRating = "中等回报"
case 40..<60: roiRating = "良好回报"
default: roiRating = "高回报"
}

// 目标达成率
let targetAchievement = targetIncome > 0 ? totalIncome / targetIncome : nil
```

#### AI 输出示例

```
💰 盈利能力
─────────────────────────────
总收入：¥12,000
总支出：¥4,450
净利润：¥7,550

利润率：63%（优秀，高于 40% 健康线）
ROI：169.7%（投入 1 块赚回 2.7 块）
目标达成率：80%（目标 ¥15,000）

→ 这个项目赚钱效率很高，但没达到目标金额
```

#### JSON 输出结构

```json
{
  "profitability": {
    "total_income": 12000,
    "total_expense": 4450,
    "net_profit": 7550,
    "profit_margin": 0.629,
    "profit_margin_label": "优秀",
    "roi": 169.7,
    "roi_rating": "高回报",
    "target_income": 15000,
    "target_achievement": 0.80
  }
}
```

---

### 4.2 维度二：时间价值分析

#### 核心指标

```swift
// 真实时薪评级
let hourlyRateRating: String
switch effectiveHourlyRate {
case ..<30: hourlyRateRating = "偏低"
case 30..<80: hourlyRateRating = "中等"
case 80..<150: hourlyRateRating = "良好"
case 150..<300: hourlyRateRating = "优秀"
default: hourlyRateRating = "顶级"
}

// 工时效率（日均投入小时数）
let dailyHours = totalHourEquivalent / Double(effectiveWorkingDays)

// 工时集中度（是否有加班赶工）
let lastWeekRatio = lastWeekHours / totalHourEquivalent
```

#### AI 输出示例

```
⏱️ 时间价值
─────────────────────────────
总工时：40.5 小时
真实时薪：¥186.4/h（优秀，高于 ¥150 线）

日均投入：5.1 小时（中度投入）
工时分布：
  前半段：16 小时（40%）
  后半段：24.5 小时（60%）
  → 后期有赶工迹象

时间成本：¥4,050（占总成本 48%）
→ 这是劳动密集型项目，时间是主要成本
```

#### JSON 输出结构

```json
{
  "time_value": {
    "total_hours": 40.5,
    "effective_hourly_rate": 186.4,
    "hourly_rate_rating": "优秀",
    "daily_hours": 5.1,
    "daily_hours_label": "中度投入",
    "first_half_hours": 16,
    "second_half_hours": 24.5,
    "time_cost_ratio": 0.48,
    "time_cost_label": "劳动密集型"
  }
}
```

---

### 4.3 维度三：成本结构拆解

#### 核心指标

```swift
// 时间成本 vs 物质成本
let timeCostRatio = totalCost > 0 ? totalTimeCost / totalCost : 0

// 最大成本项贡献度
let topCostContribution = topExpense / totalSpent

// 固定成本占比
let fixedCostRatio = totalFixedCosts / totalSpent
```

#### AI 输出示例

```
📦 成本结构
─────────────────────────────
总成本：¥8,500
  ├─ 时间成本：¥4,050（48%）
  └─ 物质成本：¥4,450（52%）

最大支出项：设计素材 ¥1,200（占支出 27%）
→ 是最大的单一成本来源

固定成本：软件订阅 ¥200/月
→ 接更多单可以摊薄这部分
```

#### JSON 输出结构

```json
{
  "cost_structure": {
    "total_cost": 8500,
    "time_cost": 4050,
    "time_cost_ratio": 0.48,
    "material_cost": 4450,
    "material_cost_ratio": 0.52,
    "top_expense": {
      "name": "设计素材",
      "amount": 1200,
      "contribution": 0.27
    },
    "fixed_monthly_cost": 200
  }
}
```

---

### 4.4 维度四：经营效率趋势

#### 核心指标

```swift
// 收入节奏
let incomeTxs = transactions.filter { $0.type == .income }.sorted { $0.date < $1.date }
let incomeMidPoint = incomeTxs.count / 2
let lateIncomeRatio = incomeTxs.suffix(from: incomeMidPoint).reduce(0) { $0 + $1.amount } / totalIncome

// 支出节奏
let expenseTxs = transactions.filter { $0.type == .expense }.sorted { $0.date < $1.date }
let earlyExpenseRatio = expenseTxs.prefix(expenseTxs.count / 2).reduce(0) { $0 + abs($1.amount) } / totalSpent

// 月度现金流
let monthlyNetCashFlow = monthlyIncome - monthlyExpense
```

#### AI 输出示例

```
📈 经营效率
─────────────────────────────
收入节奏：
  前半段收入：¥2,400（20%）
  后半段收入：¥9,600（80%）
  → 回款集中在后期，注意现金流管理

支出节奏：
  前半段支出：¥3,200（72%）
  后半段支出：¥1,250（28%）
  → 启动阶段投入大，后期支出收敛

本月净现金流：+¥3,500
→ 经营状态健康
```

#### JSON 输出结构

```json
{
  "operating_efficiency": {
    "income_timing": {
      "first_half": 2400,
      "first_half_ratio": 0.20,
      "second_half": 9600,
      "second_half_ratio": 0.80,
      "label": "回款集中在后期"
    },
    "expense_timing": {
      "first_half": 3200,
      "first_half_ratio": 0.72,
      "second_half": 1250,
      "second_half_ratio": 0.28,
      "label": "启动阶段投入大"
    },
    "monthly_net_cash_flow": 3500,
    "cash_flow_status": "健康"
  }
}
```

---

### 4.5 维度五：报价/预算建议

#### 建议生成逻辑

```swift
// 建议报价 = 总成本 × (1 + 目标利润率)
let targetProfitMargin = 0.40  // 40% 利润率
let suggestedQuote = totalCost * (1 + targetProfitMargin)

// 建议预算 = 实际支出 × 缓冲系数
let bufferFactor = 1.10  // 10% 缓冲
let suggestedBudget = totalSpent * bufferFactor

// 时薪优化建议
if effectiveHourlyRate < 100 {
    suggestion = "真实时薪偏低，建议提高报价或减少沟通轮次"
} else if dailyHours > 8 {
    suggestion = "日均投入超过 8 小时，注意劳逸平衡"
}
```

#### AI 输出示例

```
💡 下次接单建议
─────────────────────────────
基于本次数据：

建议报价：¥11,900
  计算逻辑：总成本 ¥8,500 × 1.4（维持 40% 利润率）

建议预算：¥9,350
  计算逻辑：实际支出 ¥4,450 × 1.1（10% 缓冲）+ 时间成本

时薪优化：
  当前真实时薪 ¥186.4/h，表现优秀
  如想进一步提升，建议：
  · 减少沟通轮次（本次工时 60% 集中在后期）
  · 使用模板化交付流程
```

---

## 五、AI Prompt 设计

### 5.1 设计原则

1. **数据先行**：Swift 侧预计算所有统计数据，一次性传给 LLM
2. **角色明确**：设定为"财务复盘顾问"角色
3. **约束行为**：明确要求"每条洞察必须引用具体数字"
4. **结构化输出**：要求返回标准 JSON 格式
5. **温度控制**：使用 `temperature: 0.3` 保证输出稳定

### 5.2 生活模式 Prompt

```swift
let systemPrompt = """
你是「\(project.name)」项目的财务复盘顾问。请基于以下数据生成复盘报告。

## 项目基础信息
- 项目名称：\(project.name)
- 项目类型：生活模式
- 持续天数：\(project.totalDays) 天
- 创建日期：\(formatDate(project.createdAt))

## 预算执行
- 总预算：¥\(Int(project.budget))
- 总支出：¥\(Int(project.totalSpent))
- 预算执行率：\(Int(project.budgetProgress * 100))%
- 节省/超支：¥\(Int(abs(project.budget - project.totalSpent)))

## 分类预算明细
\(categoryBreakdownText)

## 消费结构
- 消费集中度（HHI）：\(hhiValue)（\(hhiLabel)）
- 大件消费：¥\(Int(bigItemAmount))（\(Int(bigItemRatio * 100))%）
- 日常自由消费：¥\(Int(dailyFreeAmount))/天
- 最大单笔：¥\(Int(maxSingle))（\(maxSingleCategory)）
- 平均单笔：¥\(Int(avgSingle))
- 中位数单笔：¥\(Int(medianSingle))

## 时间分布
- 前半段消费：¥\(Int(firstHalfSpent))（\(Int(firstHalfRatio * 100))%）
- 后半段消费：¥\(Int(secondHalfSpent))（\(Int(secondHalfRatio * 100))%）
- 消费高峰日：第 \(peakDayNumber) 天，¥\(Int(peakDayAmount))
- 日均记账笔数：\(avgDailyTx)

## 历史对比
\(historicalComparisonText)

## 要求
1. 生成 4 个维度的洞察（预算执行、消费结构、时间分析、历史对比）
2. 每条洞察必须引用 ≥1 个具体数字
3. 不要做主观推测（如"你可能…"）
4. 给出下次同类项目的具体预算建议（分类级别）
5. 返回严格 JSON 格式，不要添加其他文字

## 输出格式
{
  "highlights": [
    {"icon": "🎯", "label": "预算控制", "text": "..."},
    {"icon": "📊", "label": "消费结构", "text": "..."},
    {"icon": "⏱️", "label": "消费节奏", "text": "..."},
    {"icon": "🏆", "label": "最佳表现", "text": "..."}
  ],
  "one_liner": "一句话总结（15字以内）",
  "next_budget": [
    {"name": "分类名", "amount": 1000, "reason": "计算逻辑"}
  ]
}
"""
```

### 5.3 搞钱模式 Prompt

```swift
let systemPrompt = """
你是「\(project.name)」项目的经营复盘顾问。请基于以下数据生成复盘报告。

## 项目基础信息
- 项目名称：\(project.name)
- 项目类型：搞钱模式
- 持续天数：\(project.effectiveWorkingDays) 天
- 创建日期：\(formatDate(project.createdAt))

## 盈利能力
- 总收入：¥\(Int(project.totalIncome))
- 总支出（物质成本）：¥\(Int(project.totalSpent))
- 时间成本：¥\(Int(project.totalTimeCost))
- 总成本：¥\(Int(project.totalCost))
- 净利润：¥\(Int(project.netProfit))
- 利润率：\(Int(profitMargin * 100))%
- ROI：\(project.roi.formatted(.number.precision(.fractionLength(1))))%
- 目标收入：¥\(Int(project.targetIncome))
- 目标达成率：\(targetAchievementText)

## 时间价值
- 总工时：\(project.totalHourEquivalent.formatted(.number.precision(.fractionLength(1))))h
- 真实时薪：¥\(project.effectiveHourlyRate.formatted(.number.precision(.fractionLength(1))))/h
- 日均投入：\(dailyHours.formatted(.number.precision(.fractionLength(1))))h
- 工时分布：前半段 \(firstHalfHours)h / 后半段 \(secondHalfHours)h

## 成本结构
- 时间成本占比：\(Int(timeCostRatio * 100))%
- 物质成本占比：\(Int(materialCostRatio * 100))%
- 最大支出项：\(topExpenseName) ¥\(Int(topExpenseAmount))
- 固定成本：¥\(Int(fixedMonthlyCost))/月

## 经营效率
- 收入节奏：前半段 \(Int(incomeFirstHalfRatio * 100))% / 后半段 \(Int(incomeSecondHalfRatio * 100))%
- 支出节奏：前半段 \(Int(expenseFirstHalfRatio * 100))% / 后半段 \(Int(expenseSecondHalfRatio * 100))%
- 本月净现金流：¥\(Int(monthlyNetCashFlow))

## 要求
1. 生成 4 个维度的洞察（盈利能力、时间价值、成本结构、经营效率）
2. 每条洞察必须引用 ≥1 个具体数字
3. 给出利润率/时薪的行业基准线对比
4. 不要做主观推测（如"你可能…"）
5. 给出下次接单的具体报价和预算建议
6. 返回严格 JSON 格式，不要添加其他文字

## 输出格式
{
  "highlights": [
    {"icon": "💰", "label": "盈利能力", "text": "..."},
    {"icon": "⏱️", "label": "时间价值", "text": "..."},
    {"icon": "📦", "label": "成本结构", "text": "..."},
    {"icon": "📈", "label": "经营效率", "text": "..."}
  ],
  "one_liner": "一句话总结（15字以内）",
  "next_quote": {
    "suggested_amount": 11900,
    "reason": "计算逻辑"
  },
  "next_budget": [
    {"name": "成本项", "amount": 1000, "reason": "计算逻辑"}
  ]
}
"""
```

---

## 六、数据预计算层设计

### 6.1 统计数据结构

```swift
/// 生活模式统计数据
struct LifestyleProjectStats {
    // 基础数据
    let totalSpent: Double
    let budget: Double
    let totalDays: Int
    let dailyAvgSpend: Double
    let budgetProgress: Double
    
    // 分类预算执行
    let categoryBreakdown: [CategoryBudgetExecution]
    
    // 消费结构
    let hhiIndex: Double
    let hhiLabel: String
    let bigItemAmount: Double
    let bigItemRatio: Double
    let dailyFreeAmount: Double
    let maxSingleAmount: Double
    let maxSingleCategory: String
    let avgSingleAmount: Double
    let medianSingleAmount: Double
    let volatility: Double
    
    // 时间分布
    let firstHalfSpent: Double
    let firstHalfRatio: Double
    let secondHalfSpent: Double
    let secondHalfRatio: Double
    let trendLabel: String
    let peakDayNumber: Int
    let peakDayAmount: Double
    let peakDayCategory: String
    let avgDailyTransactions: Double
    
    // 历史对比
    let historicalComparison: HistoricalComparison?
}

/// 搞钱模式统计数据
struct EarningProjectStats {
    // 盈利能力
    let totalIncome: Double
    let totalExpense: Double
    let timeCost: Double
    let totalCost: Double
    let netProfit: Double
    let profitMargin: Double
    let profitMarginLabel: String
    let roi: Double
    let roiRating: String
    let targetIncome: Double
    let targetAchievement: Double?
    
    // 时间价值
    let totalHours: Double
    let effectiveHourlyRate: Double
    let hourlyRateLabel: String
    let dailyHours: Double
    let dailyHoursLabel: String
    let firstHalfHours: Double
    let secondHalfHours: Double
    
    // 成本结构
    let timeCostRatio: Double
    let materialCostRatio: Double
    let topExpenseName: String
    let topExpenseAmount: Double
    let topExpenseContribution: Double
    let fixedMonthlyCost: Double
    
    // 经营效率
    let incomeFirstHalf: Double
    let incomeFirstHalfRatio: Double
    let incomeSecondHalf: Double
    let incomeSecondHalfRatio: Double
    let incomeTimingLabel: String
    let expenseFirstHalf: Double
    let expenseFirstHalfRatio: Double
    let expenseSecondHalf: Double
    let expenseSecondHalfRatio: Double
    let expenseTimingLabel: String
    let monthlyNetCashFlow: Double
    let cashFlowStatus: String
}

/// 分类预算执行
struct CategoryBudgetExecution {
    let name: String
    let icon: String
    let colorHex: String
    let budgeted: Double
    let actual: Double
    let ratio: Double
    let status: String  // "saving" | "overrun" | "on_track"
    let delta: Double   // 正数=超支，负数=节余
}

/// 历史对比
struct HistoricalComparison {
    let projectName: String
    let projectDate: String
    let dailyAvgDiff: Double
    let budgetProgressDiff: Double
    let daysDiff: Int
    let summary: String
}
```

### 6.2 统计计算服务

```swift
/// 项目统计数据计算服务
class ProjectStatsCalculator {
    
    /// 计算生活模式统计数据
    static func calculateLifestyleStats(project: Project) -> LifestyleProjectStats {
        let transactions = project.transactions ?? []
        let expenses = transactions.filter { $0.type == .expense }
        
        // 分类预算执行
        let categoryBreakdown = calculateCategoryBudgetExecution(
            budgetItems: project.budgetItems ?? [],
            expenses: expenses
        )
        
        // 消费结构
        let hhi = calculateHHI(expenses: expenses, totalSpent: project.totalSpent)
        let bigItem = calculateBigItemStats(project: project, expenses: expenses)
        let singleStats = calculateSingleTransactionStats(expenses: expenses)
        
        // 时间分布
        let timeStats = calculateTimeDistribution(expenses: expenses, totalDays: project.totalDays)
        
        // 历史对比（需要从 AppStore 获取历史项目）
        let historical = findHistoricalComparison(current: project)
        
        return LifestyleProjectStats(
            totalSpent: project.totalSpent,
            budget: project.budget,
            totalDays: project.totalDays,
            dailyAvgSpend: project.dailyAvgSpend,
            budgetProgress: project.budgetProgress,
            categoryBreakdown: categoryBreakdown,
            hhiIndex: hhi.value,
            hhiLabel: hhi.label,
            bigItemAmount: bigItem.amount,
            bigItemRatio: bigItem.ratio,
            dailyFreeAmount: bigItem.dailyFree,
            maxSingleAmount: singleStats.max,
            maxSingleCategory: singleStats.maxCategory,
            avgSingleAmount: singleStats.avg,
            medianSingleAmount: singleStats.median,
            volatility: singleStats.volatility,
            firstHalfSpent: timeStats.firstHalf,
            firstHalfRatio: timeStats.firstHalfRatio,
            secondHalfSpent: timeStats.secondHalf,
            secondHalfRatio: timeStats.secondHalfRatio,
            trendLabel: timeStats.trendLabel,
            peakDayNumber: timeStats.peakDayNumber,
            peakDayAmount: timeStats.peakDayAmount,
            peakDayCategory: timeStats.peakDayCategory,
            avgDailyTransactions: timeStats.avgDailyTx,
            historicalComparison: historical
        )
    }
    
    /// 计算搞钱模式统计数据
    static func calculateEarningStats(project: Project) -> EarningProjectStats {
        // ... 类似实现
    }
    
    // MARK: - 私有计算方法
    
    private static func calculateCategoryBudgetExecution(
        budgetItems: [BudgetItem],
        expenses: [Transaction]
    ) -> [CategoryBudgetExecution] {
        return budgetItems.map { item in
            let actual = expenses
                .filter { $0.categoryName == item.categoryName }
                .reduce(0) { $0 + abs($1.amount) }
            let ratio = item.amount > 0 ? actual / item.amount : 0
            let delta = actual - item.amount
            let status: String
            if ratio > 1.05 {
                status = "overrun"
            } else if ratio < 0.95 {
                status = "saving"
            } else {
                status = "on_track"
            }
            return CategoryBudgetExecution(
                name: item.categoryName,
                icon: item.categoryIcon,
                colorHex: item.categoryColorHex,
                budgeted: item.amount,
                actual: actual,
                ratio: ratio,
                status: status,
                delta: delta
            )
        }
    }
    
    private static func calculateHHI(expenses: [Transaction], totalSpent: Double) -> (value: Double, label: String) {
        guard totalSpent > 0 else { return (0, "无数据") }
        
        let categoryAmounts = Dictionary(grouping: expenses) { $0.categoryName }
            .mapValues { txs in txs.reduce(0) { $0 + abs($1.amount) } }
        
        let hhi = categoryAmounts.values.reduce(0) { sum, amount in
            let share = amount / totalSpent
            return sum + share * share
        }
        
        let label: String
        switch hhi {
        case ..<0.15: label = "分散"
        case 0.15..<0.25: label = "中等集中"
        default: label = "高度集中"
        }
        
        return (hhi, label)
    }
    
    private static func calculateBigItemStats(
        project: Project,
        expenses: [Transaction]
    ) -> (amount: Double, ratio: Double, dailyFree: Double) {
        let config = ProjectTypeConfigManager.shared.getConfig(name: project.name, description: project.desc)
        let bigKeywords = config.bigItemKeywords
        
        let bigAmount = expenses
            .filter { tx in bigKeywords.contains(where: { tx.categoryName.contains($0) }) }
            .reduce(0) { $0 + abs($1.amount) }
        
        let ratio = project.totalSpent > 0 ? bigAmount / project.totalSpent : 0
        let dailyFree = project.totalDays > 0 ? (project.totalSpent - bigAmount) / Double(project.totalDays) : 0
        
        return (bigAmount, ratio, dailyFree)
    }
    
    private static func calculateSingleTransactionStats(
        expenses: [Transaction]
    ) -> (max: Double, maxCategory: String, avg: Double, median: Double, volatility: Double) {
        let amounts = expenses.map { abs($0.amount) }
        guard !amounts.isEmpty else {
            return (0, "", 0, 0, 0)
        }
        
        let sorted = amounts.sorted()
        let max = sorted.last ?? 0
        let maxCategory = expenses.first(where: { abs($0.amount) == max })?.categoryName ?? ""
        let avg = amounts.reduce(0, +) / Double(amounts.count)
        let median = sorted[sorted.count / 2]
        let volatility = avg > 0 ? max / avg : 0
        
        return (max, maxCategory, avg, median, volatility)
    }
    
    private static func calculateTimeDistribution(
        expenses: [Transaction],
        totalDays: Int
    ) -> (firstHalf: Double, firstHalfRatio: Double,
          secondHalf: Double, secondHalfRatio: Double,
          trendLabel: String, peakDayNumber: Int, peakDayAmount: Double,
          peakDayCategory: String, avgDailyTx: Double) {
        
        let sorted = expenses.sorted { $0.date < $1.date }
        let midIndex = sorted.count / 2
        
        let firstHalf = sorted.prefix(midIndex).reduce(0) { $0 + abs($1.amount) }
        let secondHalf = sorted.suffix(from: midIndex).reduce(0) { $0 + abs($1.amount) }
        let total = firstHalf + secondHalf
        
        let firstHalfRatio = total > 0 ? firstHalf / total : 0.5
        let secondHalfRatio = total > 0 ? secondHalf / total : 0.5
        
        let trendLabel: String
        if firstHalfRatio > 0.6 {
            trendLabel = "前紧后松"
        } else if secondHalfRatio > 0.6 {
            trendLabel = "前松后紧"
        } else {
            trendLabel = "节奏平稳"
        }
        
        // 计算高峰日
        let dailyExpenses = Dictionary(grouping: expenses) { tx in
            Calendar.current.startOfDay(for: tx.date)
        }
        let dailyTotals = dailyExpenses.mapValues { txs in txs.reduce(0) { $0 + abs($1.amount) } }
        let peakDay = dailyTotals.max { $0.value < $1.value }
        
        let peakDayNumber: Int
        if let peak = peakDay?.key, let firstDate = sorted.first?.date {
            peakDayNumber = max(1, Calendar.current.dateComponents([.day], from: firstDate, to: peak).day ?? 0 + 1)
        } else {
            peakDayNumber = 0
        }
        
        let peakDayAmount = peakDay?.value ?? 0
        let peakDayCategory = expenses
            .filter { Calendar.current.isDate($0.date, inSameDayAs: peakDay?.key ?? Date()) }
            .max(by: { abs($0.amount) < abs($1.amount) })?.categoryName ?? ""
        
        let avgDailyTx = totalDays > 0 ? Double(expenses.count) / Double(totalDays) : 0
        
        return (firstHalf, firstHalfRatio, secondHalf, secondHalfRatio,
                trendLabel, peakDayNumber, peakDayAmount, peakDayCategory, avgDailyTx)
    }
}
```

---

## 七、UI 展示设计

### 7.1 复盘报告卡片结构

```
┌──────────────────────────────────────┐
│  项目头：图标 + 名称 + 模式标签       │
└──────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────┐
│  总览数字卡片（已有，保持不变）        │
│  · 生活：总支出 / 预算 / 节省或超支   │
│  · 搞钱：总收入 / 总成本 / 净利润     │
└──────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────┐
│  预算执行卡片（生活模式）/            │
│  盈利能力卡片（搞钱模式）             │
│  · 进度条 + 分类明细                  │
└──────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────┐
│  AI 洞察卡片流（Plus 遮罩）           │
│  ┌────────────────────────────────┐  │
│  │ 🎯 预算控制                     │  │
│  │ 总执行率 92%，住宿省了 ¥600    │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │ 📊 消费结构                     │  │
│  │ HHI 0.18，大件占 49%           │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │ ⏱️ 消费节奏                     │  │
│  │ 前半段 56%，越玩越省           │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │ 🏆 最佳表现                     │  │
│  │ 住宿分类预算使用率 80%         │  │
│  └────────────────────────────────┘  │
└──────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────┐
│  一句话总结（Plus 遮罩）              │
│  "8天新疆之旅，预算执行优秀"          │
└──────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────┐
│  下次预算建议（Plus 遮罩）            │
│  · 分类级别建议金额 + 计算逻辑        │
└──────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────┐
│  [导出精美图片 🔒]  [确认归档]        │
└──────────────────────────────────────┘
```

### 7.2 洞察卡片组件

```swift
/// AI 洞察卡片
struct AIInsightCard: View {
    let icon: String
    let label: String
    let text: String
    let accentColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(accentColor)
            }
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(Color.App.textBlack)
                .lineSpacing(4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
```

### 7.3 分类预算执行组件

```swift
/// 分类预算执行条
struct CategoryBudgetBar: View {
    let name: String
    let icon: String
    let colorHex: String
    let budgeted: Double
    let actual: Double
    let ratio: Double
    
    private var barColor: Color {
        if ratio > 1.05 {
            return Color.App.redExpense
        } else if ratio > 0.85 {
            return Color.orange
        } else {
            return Color(hex: colorHex)
        }
    }
    
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(icon)
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Text("¥\(Int(actual))")
                    .font(.system(size: 13, weight: .bold))
                Text("/ ¥\(Int(budgeted))")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.App.progressTrack)
                        .frame(height: 8)
                    Capsule()
                        .fill(barColor)
                        .frame(width: geometry.size.width * min(ratio, 1), height: 8)
                }
            }
            .frame(height: 8)
            
            HStack {
                if ratio > 1 {
                    Text("超支 ¥\(Int(actual - budgeted))")
                        .font(.system(size: 11))
                        .foregroundColor(Color.App.redExpense)
                } else {
                    Text("节省 ¥\(Int(budgeted - actual))")
                        .font(.system(size: 11))
                        .foregroundColor(Color.App.darkGreen)
                }
                Spacer()
                Text("\(Int(ratio * 100))%")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(barColor)
            }
        }
    }
}
```

---

## 八、输出数据结构

### 8.1 更新后的 ProjectReviewResult

```swift
/// 项目复盘结果
struct ProjectReviewResult {
    /// 洞察卡片列表
    let highlights: [InsightHighlight]
    /// 一句话总结
    let oneLiner: String
    /// 下次预算建议（生活模式）
    let nextBudgetSuggestions: [BudgetSuggestion]
    /// 下次报价建议（搞钱模式）
    let nextQuoteSuggestion: QuoteSuggestion?
}

/// 洞察卡片
struct InsightHighlight: Codable {
    let icon: String
    let label: String
    let text: String
}

/// 预算建议
struct BudgetSuggestion: Codable {
    let name: String
    let amount: Double
    let reason: String
}

/// 报价建议（搞钱模式）
struct QuoteSuggestion: Codable {
    let suggestedAmount: Double
    let reason: String
}
```

### 8.2 JSON 解析

```swift
// 解析 AI 返回的 JSON
func parseReviewResult(from jsonString: String) throws -> ProjectReviewResult {
    guard let data = jsonString.data(using: .utf8),
          let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw LLMError.invalidJSON
    }
    
    // 解析 highlights
    let highlights = (json["highlights"] as? [[String: Any]])?.compactMap { dict -> InsightHighlight? in
        guard let icon = dict["icon"] as? String,
              let label = dict["label"] as? String,
              let text = dict["text"] as? String else { return nil }
        return InsightHighlight(icon: icon, label: label, text: text)
    } ?? []
    
    // 解析 one_liner
    let oneLiner = json["one_liner"] as? String ?? "暂无总结"
    
    // 解析 next_budget
    let nextBudget = (json["next_budget"] as? [[String: Any]])?.compactMap { dict -> BudgetSuggestion? in
        guard let name = dict["name"] as? String,
              let amount = dict["amount"] as? Double,
              let reason = dict["reason"] as? String else { return nil }
        return BudgetSuggestion(name: name, amount: amount, reason: reason)
    } ?? []
    
    // 解析 next_quote（搞钱模式）
    var quoteSuggestion: QuoteSuggestion? = nil
    if let quoteDict = json["next_quote"] as? [String: Any],
       let amount = quoteDict["suggested_amount"] as? Double,
       let reason = quoteDict["reason"] as? String {
        quoteSuggestion = QuoteSuggestion(suggestedAmount: amount, reason: reason)
    }
    
    return ProjectReviewResult(
        highlights: highlights,
        oneLiner: oneLiner,
        nextBudgetSuggestions: nextBudget,
        nextQuoteSuggestion: quoteSuggestion
    )
}
```

---

## 九、复盘次数与缓存策略

### 9.1 核心原则

**生成后即为静态数据，只在用户主动操作时消耗 Token。**

```
┌─────────────────────────────────────────────────────────┐
│                    复盘数据流                            │
├─────────────────────────────────────────────────────────┤
│  首次生成 → 缓存到本地数据库 → 每次打开直接显示缓存     │
│                ↓                                        │
│      数据变化时只显示"数据已更新"提示                    │
│                ↓                                        │
│      用户手动点击「刷新」才消耗 Token                   │
└─────────────────────────────────────────────────────────┘
```

**关键点**：
- ❌ 不会自动刷新（即使项目数据变化）
- ❌ 不会静默消耗 Token
- ✅ 只有用户主动点击「刷新」按钮才触发 AI 调用
- ✅ 生成后持久化到本地，Sheet 关闭不丢失

### 9.2 每日限额

| 用户类型 | 每日限额 | 说明 |
|----------|----------|------|
| 免费用户 | 0 次 | 只能看基础数字，AI 总结遮罩 |
| Pro 用户 | 1 次/天 | 所有项目共享 1 次额度 |

**限额重置**：每天 00:00 自动重置（基于设备本地时间）

### 9.3 缓存机制

#### 数据模型

```swift
/// 复盘缓存模型
@Model
final class ProjectReviewCache {
    var id: UUID = UUID()
    var projectID: UUID           // 关联项目
    var resultJSON: String        // 缓存的 AI 结果（JSON 字符串）
    var createdAt: Date           // 生成时间
    var dataHash: String          // 数据指纹（用于显示"数据已更新"提示）
    var dailyUsageDate: Date      // 使用日期（用于判断是否新的一天）
    
    init(projectID: UUID, resultJSON: String, dataHash: String) {
        self.id = UUID()
        self.projectID = projectID
        self.resultJSON = resultJSON
        self.createdAt = Date()
        self.dataHash = dataHash
        self.dailyUsageDate = Date()
    }
}
```

#### 数据指纹计算

```swift
/// 计算项目数据指纹（用于判断数据是否变化）
func calculateDataHash(project: Project) -> String {
    let transactions = project.transactions ?? []
    let txCount = transactions.count
    let totalSpent = project.totalSpent
    let totalIncome = project.totalIncome
    let budget = project.budget
    let budgetItemsCount = project.budgetItems?.count ?? 0
    
    // 简单指纹：交易数量 + 总金额 + 预算
    let hashInput = "\(txCount)-\(totalSpent)-\(totalIncome)-\(budget)-\(budgetItemsCount)"
    return hashInput.hashValue.description
}
```

### 9.4 复盘服务层

```swift
/// 复盘服务（管理缓存和次数）
class ProjectReviewService {
    static let shared = ProjectReviewService()
    
    /// 获取复盘结果（优先缓存）
    func getReviewResult(
        project: Project,
        mode: String,
        forceRefresh: Bool = false,
        modelContext: ModelContext
    ) async throws -> ProjectReviewResult {
        let projectID = project.id
        
        // 1. 查找缓存
        if let cache = fetchCache(projectID: projectID, modelContext: modelContext),
           !forceRefresh {
            // 直接返回缓存（不检查数据变化，不自动刷新）
            return try parseResult(from: cache.resultJSON)
        }
        
        // 2. 需要调用 AI（首次或强制刷新）
        return try await generateNewReview(
            project: project,
            mode: mode,
            existingCache: fetchCache(projectID: projectID, modelContext: modelContext),
            modelContext: modelContext
        )
    }
    
    /// 生成新复盘（首次或刷新）
    private func generateNewReview(
        project: Project,
        mode: String,
        existingCache: ProjectReviewCache?,
        modelContext: ModelContext
    ) async throws -> ProjectReviewResult {
        // 检查今日次数
        let todayUsage = getTodayUsage(modelContext: modelContext)
        let maxDaily = StoreManager.shared.isPremium ? 1 : 0
        
        if todayUsage >= maxDaily {
            if maxDaily == 0 {
                throw ReviewError.proRequired
            } else {
                throw ReviewError.dailyLimitReached
            }
        }
        
        // 调用 AI
        let result = try await LLMService.shared.generateProjectReview(project: project, mode: mode)
        
        // 保存/更新缓存
        let resultJSON = serializeResult(result)
        let dataHash = calculateDataHash(project: project)
        
        if let cache = existingCache {
            // 更新现有缓存
            cache.resultJSON = resultJSON
            cache.dataHash = dataHash
            cache.dailyUsageDate = Date()
        } else {
            // 创建新缓存
            let cache = ProjectReviewCache(
                projectID: project.id,
                resultJSON: resultJSON,
                dataHash: dataHash
            )
            modelContext.insert(cache)
        }
        
        try modelContext.save()
        return result
    }
    
    /// 检查数据是否已更新（用于显示提示）
    func isDataUpdated(project: Project, modelContext: ModelContext) -> Bool {
        guard let cache = fetchCache(projectID: project.id, modelContext: modelContext) else {
            return false
        }
        let currentHash = calculateDataHash(project: project)
        return cache.dataHash != currentHash
    }
    
    /// 获取今日使用次数
    private func getTodayUsage(modelContext: ModelContext) -> Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        
        let descriptor = FetchDescriptor<ProjectReviewCache>(
            predicate: #Predicate { $0.dailyUsageDate >= startOfDay }
        )
        return (try? modelContext.fetch(descriptor).count) ?? 0
    }
}

/// 复盘错误
enum ReviewError: LocalizedError {
    case proRequired
    case dailyLimitReached
    
    var errorDescription: String? {
        switch self {
        case .proRequired:
            return "AI 复盘总结为 Pro 专属功能"
        case .dailyLimitReached:
            return "今天的 AI 复盘次数已用完（每天 1 次），明天再来吧！"
        }
    }
}
```

### 9.5 UI 层处理

```swift
// ProjectReviewSheet.swift 中的 AI 总结卡片
private var aiSummaryCard: some View {
    VStack(alignment: .leading, spacing: 14) {
        HStack(spacing: 6) {
            Image(systemName: "sparkles").foregroundColor(accentColor)
            Text("AI 复盘总结")
                .font(.system(size: 20, weight: .heavy)).foregroundColor(Color.App.textBlack)
            Spacer()
            
            // 刷新按钮（仅在有缓存时显示）
            if reviewResult != nil {
                Button {
                    refreshReview()
                } label: {
                    HStack(spacing: 4) {
                        if isRefreshing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("刷新")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isRefreshing ? .gray : accentColor)
                }
                .disabled(isRefreshing)
            }
        }
        
        // 数据更新提示（不自动刷新，只提示）
        if showDataUpdatedHint {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.orange)
                Text("项目数据已更新，点击「刷新」获取最新分析")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .padding(10)
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        
        // 状态显示
        if isLoadingReview {
            HStack { Spacer(); ProgressView(); Spacer() }
                .padding(.vertical, 20)
        } else if let error = reviewError {
            // 显示错误（如次数用完）
            VStack(spacing: 12) {
                Image(systemName: error == .dailyLimitReached ? "clock.fill" : "lock.fill")
                    .font(.system(size: 32))
                    .foregroundColor(error == .dailyLimitReached ? .orange : .gray)
                Text(error.localizedDescription)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                
                if error == .dailyLimitReached {
                    Text("剩余次数：0/1")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        } else if let result = reviewResult {
            // 显示结果
            ForEach(result.highlights, id: \.label) { highlight in
                aiInsightCard(highlight)
            }
            
            // 一句话总结
            Text(result.oneLiner)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(accentColor)
                .padding(.top, 8)
        } else {
            // 首次生成按钮
            Button {
                generateReview()
            } label: {
                Text("生成 AI 总结")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    .padding(24)
    .background(Color.App.cardBackground)
    .clipShape(RoundedRectangle(cornerRadius: 32))
    .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
}
```

### 9.6 数据流示意

```
用户打开复盘 Sheet
        ↓
┌─────────────────────────────────────┐
│ 检查本地是否有缓存                   │
└─────────────────────────────────────┘
        ↓
   ┌────┴────┐
   │         │
有缓存    无缓存
   │         │
   ↓         ↓
显示缓存  显示「生成 AI 总结」按钮
   │         │
   │         ↓
   │    用户点击按钮
   │         │
   │         ↓
   │    检查今日次数（Pro: 0/1）
   │         │
   │    ┌────┴────┐
   │    │         │
   │  有次数    无次数
   │    │         │
   │    ↓         ↓
   │  调用 AI   显示「明天再来」
   │    │
   │    ↓
   │  缓存到本地
   │    │
   ↓    ↓
 显示结果 + 刷新按钮
        │
        ↓
   检查数据是否变化
        │
   ┌────┴────┐
   │         │
 已变化    未变化
   │         │
   ↓         ↓
显示提示   隐藏提示
"数据已更新"
   │
   ↓
用户点击「刷新」
   │
   ↓
再次检查次数 → 调用 AI → 更新缓存
```

---

## 十、导出报告设计

### 10.1 功能概述

**导出精美复盘报告**是 Pro 核心付费点，用户可将复盘结果导出为图片或 PDF，分享到社交媒体。

**导出内容**：
- 项目概览（名称、模式、时间）
- 核心数字（总支出/收入、预算执行率等）
- AI 洞察卡片
- 一句话总结
- 下次预算/报价建议
- 品牌水印（钱小满 logo + 二维码）

### 10.2 导出格式

| 格式 | 适用场景 | 技术实现 |
|------|----------|----------|
| 长图（PNG） | 小红书、朋友圈、微博 | `ImageRenderer`（iOS 16+） |
| PDF | 存档、打印、正式分享 | `PDFKit` + `UIGraphicsPDFRenderer` |

### 10.3 UI 设计

#### 导出按钮

```swift
// ProjectReviewSheet.swift 底部
private var exportCard: some View {
    VStack(spacing: 12) {
        // 导出按钮
        Button {
            showExportOptions = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                Text("导出报告")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [accentColor, accentColor.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(reviewResult == nil)  // 未生成 AI 总结时禁用
        
        // 提示文字
        if reviewResult == nil {
            Text("请先生成 AI 复盘总结")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
    }
    .padding(.horizontal, 24)
    .confirmationDialog("选择导出格式", isPresented: $showExportOptions) {
        Button("导出长图（适合分享）") {
            exportAsImage()
        }
        Button("导出 PDF（适合存档）") {
            exportAsPDF()
        }
        Button("取消", role: .cancel) {}
    }
}
```

#### 导出报告长图布局

```swift
/// 复盘报告长图（用于 ImageRenderer 渲染）
struct ProjectReviewReportView: View {
    let project: Project
    let reviewResult: ProjectReviewResult
    let projectMode: ProjectMode
    
    private var colorPair: ProgressColorPair { progressColorPair(for: project.colorHex) }
    private var accentColor: Color { Color(hex: colorPair.end) }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - 顶部品牌区
            headerSection
            
            // MARK: - 项目概览
            projectOverviewSection
            
            // MARK: - 核心数字
            coreMetricsSection
            
            // MARK: - AI 洞察
            aiInsightsSection
            
            // MARK: - 一句话总结
            oneLinerSection
            
            // MARK: - 下次建议
            nextBudgetSection
            
            // MARK: - 底部品牌
            footerSection
        }
        .background(Color.white)
        .frame(width: 375)  // 固定宽度，高度自适应
    }
    
    // MARK: - 顶部品牌区
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Logo
            HStack {
                Image("app_logo")  // 使用 App Logo
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                Text("钱小满")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                Spacer()
                Text("项目复盘报告")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            // 分割线
            LinearGradient(
                colors: [accentColor, accentColor.opacity(0.3)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 3)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }
    
    // MARK: - 项目概览
    private var projectOverviewSection: some View {
        VStack(spacing: 16) {
            // 项目图标 + 名称
            HStack(spacing: 12) {
                Image(systemName: project.icon)
                    .font(.system(size: 28))
                    .foregroundColor(accentColor)
                    .frame(width: 56, height: 56)
                    .background(accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundColor(.black)
                    
                    HStack(spacing: 8) {
                        Label(projectMode.title, systemImage: projectMode.icon)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(accentColor)
                        
                        Text("·")
                        
                        Text(formatDateRange(project.createdAt, to: Date()))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
    
    // MARK: - 核心数字
    private var coreMetricsSection: some View {
        VStack(spacing: 16) {
            if projectMode == .earning {
                // 搞钱模式
                HStack(spacing: 12) {
                    metricCell("总收入", "¥\(Int(project.totalIncome))", color: .green)
                    metricCell("总成本", "¥\(Int(project.totalCost))", color: .gray)
                    metricCell("净利润", "¥\(Int(project.netProfit))", color: project.netProfit >= 0 ? .green : .red)
                }
                HStack(spacing: 12) {
                    metricCell("ROI", "\(project.roi.formatted(.number.precision(.fractionLength(1))))%", color: accentColor)
                    metricCell("总工时", "\(project.totalHourEquivalent.formatted(.number.precision(.fractionLength(1))))h", color: .gray)
                    metricCell("真实时薪", "¥\(project.effectiveHourlyRate.formatted(.number.precision(.fractionLength(1))))/h", color: accentColor)
                }
            } else {
                // 生活模式
                HStack(spacing: 12) {
                    metricCell("总支出", "¥\(Int(project.totalSpent))", color: .red)
                    metricCell("预算", "¥\(Int(project.budget))", color: .gray)
                    let overrun = max(project.totalSpent - project.budget, 0)
                    metricCell(overrun > 0 ? "超支" : "节省", "¥\(Int(abs(project.budget - project.totalSpent)))", color: overrun > 0 ? .red : .green)
                }
                
                // 预算进度条
                VStack(spacing: 8) {
                    HStack {
                        Text("预算执行率")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(Int(project.budgetProgress * 100))%")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundColor(accentColor)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 12)
                            Capsule()
                                .fill(accentColor)
                                .frame(width: geometry.size.width * min(project.budgetProgress, 1), height: 12)
                        }
                    }
                    .frame(height: 12)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.gray.opacity(0.05))
    }
    
    // MARK: - AI 洞察
    private var aiInsightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(accentColor)
                Text("AI 复盘洞察")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(.black)
            }
            
            ForEach(reviewResult.highlights, id: \.label) { highlight in
                insightCard(highlight)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
    
    private func insightCard(_ highlight: InsightHighlight) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(highlight.icon)
                .font(.system(size: 24))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(highlight.label)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(accentColor)
                
                Text(highlight.text)
                    .font(.system(size: 14))
                    .foregroundColor(.black.opacity(0.8))
                    .lineSpacing(4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - 一句话总结
    private var oneLinerSection: some View {
        VStack(spacing: 12) {
            Divider()
            
            Text(reviewResult.oneLiner)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(accentColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            Divider()
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - 下次建议
    private var nextBudgetSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.orange)
                Text("下次预算建议")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(.black)
            }
            
            if let quote = reviewResult.nextQuoteSuggestion {
                // 搞钱模式：报价建议
                HStack {
                    Text("建议报价")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("¥\(Int(quote.suggestedAmount))")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(.green)
                }
                .padding(16)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Text(quote.reason)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            // 分类预算建议
            ForEach(reviewResult.nextBudgetSuggestions, id: \.name) { suggestion in
                HStack {
                    Text(suggestion.name)
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                    Spacer()
                    Text("¥\(Int(suggestion.amount))")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                    Text(suggestion.reason)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
    
    // MARK: - 底部品牌
    private var footerSection: some View {
        VStack(spacing: 12) {
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("生成时间：\(formatDate(Date()))")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Text("by 钱小满 · 一切皆项目")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // 二维码（可选）
                // Image("qrcode")
                //     .resizable()
                //     .scaledToFit()
                //     .frame(width: 60, height: 60)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .padding(.bottom, 24)
    }
    
    // MARK: - 辅助方法
    private func metricCell(_ title: String, _ value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
    
    private func formatDateRange(_ start: Date, to end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}
```

### 10.4 导出服务

```swift
/// 报告导出服务
class ReportExportService {
    
    /// 导出为图片
    @MainActor
    static func exportAsImage(
        project: Project,
        reviewResult: ProjectReviewResult,
        projectMode: ProjectMode
    ) -> UIImage? {
        let reportView = ProjectReviewReportView(
            project: project,
            reviewResult: reviewResult,
            projectMode: projectMode
        )
        
        // 使用 ImageRenderer 渲染（iOS 16+）
        let renderer = ImageRenderer(content: reportView)
        renderer.scale = 3.0  // 3x 分辨率，保证清晰度
        
        return renderer.uiImage
    }
    
    /// 导出为 PDF
    @MainActor
    static func exportAsPDF(
        project: Project,
        reviewResult: ProjectReviewResult,
        projectMode: ProjectMode
    ) -> Data? {
        let reportView = ProjectReviewReportView(
            project: project,
            reviewResult: reviewResult,
            projectMode: projectMode
        )
        
        // 先渲染为图片
        guard let image = exportAsImage(
            project: project,
            reviewResult: reviewResult,
            projectMode: projectMode
        ) else {
            return nil
        }
        
        // 转换为 PDF
        let pageRect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        return renderer.pdfData { context in
            context.beginPage()
            image.draw(at: .zero)
        }
    }
    
    /// 保存到相册
    static func saveToPhotos(_ image: UIImage) async throws {
        try await UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
    
    /// 保存到文件
    static func saveToFile(_ data: Data, filename: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        try data.write(to: fileURL)
        return fileURL
    }
}
```

### 10.5 完整导出流程

```swift
// ProjectReviewSheet.swift 中的导出逻辑
extension ProjectReviewSheet {
    
    /// 导出为图片
    private func exportAsImage() {
        guard let result = reviewResult else { return }
        
        isExporting = true
        
        Task {
            do {
                // 1. 渲染图片
                guard let image = await ReportExportService.exportAsImage(
                    project: project,
                    reviewResult: result,
                    projectMode: projectMode
                ) else {
                    throw ExportError.renderFailed
                }
                
                // 2. 保存到相册
                try await ReportExportService.saveToPhotos(image)
                
                await MainActor.run {
                    isExporting = false
                    exportSuccess = true
                    showExportSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    exportError = error.localizedDescription
                    showExportErrorAlert = true
                }
            }
        }
    }
    
    /// 导出为 PDF
    private func exportAsPDF() {
        guard let result = reviewResult else { return }
        
        isExporting = true
        
        Task {
            do {
                // 1. 渲染 PDF
                guard let pdfData = await ReportExportService.exportAsPDF(
                    project: project,
                    reviewResult: result,
                    projectMode: projectMode
                ) else {
                    throw ExportError.renderFailed
                }
                
                // 2. 保存到临时文件
                let filename = "\(project.name)_复盘报告_\(formatDate(Date())).pdf"
                let fileURL = try ReportExportService.saveToFile(pdfData, filename: filename)
                
                await MainActor.run {
                    isExporting = false
                    exportedFileURL = fileURL
                    showShareSheet = true
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    exportError = error.localizedDescription
                    showExportErrorAlert = true
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmm"
        return formatter.string(from: date)
    }
}

/// 导出错误
enum ExportError: LocalizedError {
    case renderFailed
    
    var errorDescription: String? {
        switch self {
        case .renderFailed:
            return "报告渲染失败，请重试"
        }
    }
}
```

---

## 十一、权限与商业化

### 11.1 权限分层

| 功能 | 免费版 | Pro |
|------|--------|-----|
| 总览数字卡片 | ✅ | ✅ |
| 预算执行卡片 | ✅ | ✅ |
| AI 洞察卡片流 | ❌（遮罩） | ✅ |
| 一句话总结 | ❌（遮罩） | ✅ |
| 下次预算建议 | ❌（遮罩） | ✅ |
| AI 复盘次数 | 0 次/天 | 1 次/天 |
| 导出精美图片 | ❌（按钮锁定） | ✅ |
| 导出 PDF | ❌（按钮锁定） | ✅ |

### 11.2 免费用户体验设计

```
┌──────────────────────────────────────┐
│  总览数字卡片（完整显示）             │
│  总支出 ¥9,200 / 预算 ¥10,000        │
└──────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────┐
│  预算执行卡片（完整显示）             │
│  执行率 92%，住宿省了 ¥600           │
└──────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────┐
│  AI 洞察              Pro 🔒         │
│  ┌────────────────────────────────┐  │
│  │ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │  │
│  │ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │  │
│  │ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │  │
│  └────────────────────────────────┘  │
│  [升级解锁 AI 复盘总结]              │
└──────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────┐
│  [导出精美图片 🔒]  [确认归档]        │
└──────────────────────────────────────┘
```

**转化逻辑**：用户看到真实数字 → 好奇 AI 会说什么 → 升级解锁

---

## 十二、开发任务清单

### Phase 1：数据预计算层（1-2 天）

- [ ] 创建 `ProjectStatsCalculator` 服务类
- [ ] 实现生活模式统计计算方法
- [ ] 实现搞钱模式统计计算方法
- [ ] 单元测试覆盖核心计算逻辑

### Phase 2：AI Prompt 重构（1 天）

- [ ] 更新 `LLMService.generateProjectReview` 方法
- [ ] 生活模式 Prompt 重写
- [ ] 搞钱模式 Prompt 重写
- [ ] JSON 输出格式解析

### Phase 3：UI 组件开发（1-2 天）

- [ ] 创建 `AIInsightCard` 洞察卡片组件
- [ ] 创建 `CategoryBudgetBar` 分类预算执行组件
- [ ] 更新 `ProjectReviewSheet` 布局
- [ ] Pro 遮罩和付费墙集成

### Phase 4：联调与优化（1 天）

- [ ] LLM 输出稳定性测试
- [ ] 边界情况处理（无数据、单条记录等）
- [ ] UI 渲染性能优化
- [ ] 深色模式适配

---

## 十三、验收标准

### 13.1 数据准确性

- [ ] 分类预算执行率计算正确，与手动计算误差 < 1%
- [ ] HHI 指数计算正确，范围 0~1
- [ ] 时间分布百分比之和 = 100%
- [ ] 历史对比数据准确，差异计算正确

### 13.2 AI 输出质量

- [ ] 每条洞察包含 ≥1 个具体数字
- [ ] 无主观推测语句（"你可能…"）
- [ ] 输出 JSON 格式解析成功率 > 95%
- [ ] 一句话总结 ≤ 15 字

### 13.3 UI 展示

- [ ] 洞察卡片在 iPhone SE 和 Pro Max 上正常显示
- [ ] Pro 遮罩正确覆盖 AI 内容
- [ ] 免费用户可看到总览数字和预算执行
- [ ] 点击升级按钮正确跳转付费墙

### 13.4 性能

- [ ] 统计数据计算耗时 < 100ms（1000 条交易）
- [ ] LLM 请求超时 30s，有 loading 状态
- [ ] 复盘 Sheet 打开到展示 < 2s（不含 LLM 时间）

---

## 十四、风险与应对

| 风险 | 概率 | 影响 | 应对方案 |
|------|------|------|----------|
| LLM 输出格式不稳定 | 中 | 高 | 增加 JSON 格式校验，失败时使用默认文案 |
| 数据量过少时洞察无意义 | 中 | 中 | 设置最小数据阈值（≥5 条交易）才生成 AI 洞察 |
| 统计计算性能问题 | 低 | 中 | 预计算 + 缓存，避免重复遍历 |
| 用户不理解专业指标 | 低 | 低 | UI 上添加解释性文案（如"HHI：消费集中度指标"） |

---

## 十五、附录

### A. HHI 指数说明

赫芬达尔-赫希曼指数（Herfindahl-Hirschman Index），原用于衡量市场集中度，这里用于衡量消费集中度：

- **计算公式**：HHI = Σ(各分类份额²)
- **范围**：0 ~ 1
- **解读**：
  - < 0.15：消费分散，结构健康
  - 0.15 ~ 0.25：中等集中，有单一分类占比偏高
  - > 0.25：高度集中，消费"偏食"

### B. 利润率基准线

| 利润率 | 评级 | 说明 |
|--------|------|------|
| < 0% | 亏损 | 需要重新评估项目可行性 |
| 0% ~ 20% | 低回报 | 低于自由职业者平均水平 |
| 20% ~ 40% | 中等 | 自由职业者平均水平 |
| 40% ~ 60% | 良好 | 高于平均水平 |
| > 60% | 优秀 | 顶级自由职业者水平 |

### C. 真实时薪基准线

| 时薪 | 评级 | 参考 |
|------|------|------|
| < ¥30 | 偏低 | 低于兼职平均水平 |
| ¥30 ~ ¥80 | 中等 | 兼职到初级自由职业 |
| ¥80 ~ ¥150 | 良好 | 中级自由职业者 |
| ¥150 ~ ¥300 | 优秀 | 高级自由职业者 |
| > ¥300 | 顶级 | 资深专家水平 |

---

**文档版本记录**

| 版本 | 日期 | 修改内容 |
|------|------|----------|
| V1.0 | 2026-07-15 | 初版，完成五维度分析框架设计 |
| V1.1 | 2026-07-15 | 新增复盘次数策略（Pro每日1次）、缓存机制、导出报告设计（图片/PDF）|
