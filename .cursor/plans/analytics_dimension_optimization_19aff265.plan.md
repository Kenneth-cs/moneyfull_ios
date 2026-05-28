---
name: Analytics Dimension Optimization
overview: Refactor the AnalyticsView and ProjectDetailView to support flexible time ranges, custom date pickers, multi-dimensional donut charts (project vs. category), and adaptive line charts.
todos:
  - id: setup-models-state
    content: Create TimeRange and ChartDimension enums, update AnalyticsView state
    status: pending
  - id: create-custom-pickers
    content: Implement MonthYearPicker and CustomDateRangePicker views
    status: pending
  - id: update-analytics-ui
    content: Update AnalyticsView UI to include TimeRange and ChartDimension toggles
    status: pending
  - id: implement-analytics-logic
    content: Implement data aggregation logic for multi-dimensional DonutChart and adaptive LineChart in AnalyticsView
    status: pending
  - id: update-project-detail-view
    content: Refactor ProjectDetailView to include category DonutChart and project trend LineChart
    status: pending
isProject: false
---

# 财务统计维度优化方案

## 1. 核心模型与状态设计 (Models & State)
- **`TimeRange` 枚举**: 定义 `day, week, month, year, custom` 五个维度。
- **`ChartDimension` 枚举**: 定义 `byProject` (按项目), `allCategories` (全部分类), `projectCategories` (项目内分类) 三个维度。
- 在 `AnalyticsView` 中引入这些状态变量，并实现一个根据当前时间维度动态过滤 `transactions` 的通用计算属性。

## 2. 月份选择器与自定义周期 (Custom Pickers)
- **重写 `MonthPickerSheet`**: 移除系统默认的 `.graphical` 样式，改为使用两个原生的 `Picker`（带有 `.pickerStyle(.wheel)`）并排显示年份和月份。
- **新增 `CustomDateRangeSheet`**: 提供“开始日期”和“结束日期”的设定，并加入“按发薪日周期 (15号 - 次月14号)”等快捷预设按钮，提升用户体验。

## 3. 全局统计多维度分析 (AnalyticsView Enhancements)
- **头部控制栏**: 在原有的月份选择器位置上方，加入 `TimeRange` 的横向分段选择器（Segmented Control）。
- **动态环形图 (`DonutChartView`)**: 
  - 增加顶部 `ChartDimension` 的切换选项。
  - 数据源计算逻辑重构：
    - `byProject`：按照已有逻辑，按 `project.name` 汇总。
    - `allCategories`：按照 `categoryName` 汇总本期所有的支出记录。
    - `projectCategories`：当选中此项时，下方展现一个项目下拉菜单，选中后按照该项目的 `categoryName` 汇总支出。
- **自适应趋势图 (`LineChartView`)**:
  - 根据选中的 `TimeRange` 决定 X 轴展示什么（例如：如果是“年”，则按 12 个月聚合；如果是“月”，按天或周聚合）。

## 4. 项目详情页升级 (ProjectDetailView Enhancements)
- **引入微观报表**: 提取并在项目详情的时间轴上方增加图表分析功能。
- **项目内分类占比**: 复用 `DonutChartView`，传入当前项目 `project.transactions` 按 `categoryName` 聚合后的数据，让用户对单项目的花费结构一目了然。
- **项目收支趋势**: 复用 `LineChartView`，传入当前项目随时间变化的收支聚合数据，展示该项目的资金投入/产出趋势。

## 5. 代码复用与重构 (Refactoring)
- 确保 `DonutChartView` 和 `LineChartView` 保持纯展示组件（Dumb Components）的特性，只接收传入的数据数组，由父视图（`AnalyticsView` 或 `ProjectDetailView`）负责聚合数据的计算。