import SwiftUI

/// 复盘报告长图（用于 ImageRenderer 渲染导出）
struct ProjectReviewReportView: View {
    let project: Project
    let reviewResult: ProjectReviewResult
    let projectMode: ProjectMode

    private var colorPair: ProgressColorPair { progressColorPair(for: project.colorHex) }
    private var accentColor: Color { Color(hex: colorPair.end) }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            projectOverviewSection
            coreMetricsSection
            aiInsightsSection
            oneLinerSection
            nextBudgetSection
            footerSection
        }
        .background(Color.white)
        .frame(width: 375)
    }

    // MARK: - 顶部品牌

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(accentColor)
                Text("钱小满")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                Spacer()
                Text("项目复盘报告")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            LinearGradient(
                colors: [accentColor, accentColor.opacity(0.3)],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 3)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    // MARK: - 项目概览

    private var projectOverviewSection: some View {
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
                    Text(projectMode.title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(accentColor)
                    Text("·")
                    Text(formatDateRange())
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - 核心数字

    private var coreMetricsSection: some View {
        VStack(spacing: 12) {
            if projectMode == .earning {
                HStack(spacing: 12) {
                    metricCell("总收入", "¥\(Int(project.totalIncome))", .green)
                    metricCell("总成本", "¥\(Int(project.totalCost))", .gray)
                    metricCell("净利润", "¥\(Int(project.netProfit))", project.netProfit >= 0 ? .green : .red)
                }
                HStack(spacing: 12) {
                    metricCell("ROI", "\(project.roi.formatted(.number.precision(.fractionLength(1))))%", accentColor)
                    metricCell("总工时", "\(project.totalHourEquivalent.formatted(.number.precision(.fractionLength(1))))h", .gray)
                    metricCell("真实时薪", "¥\(project.effectiveHourlyRate.formatted(.number.precision(.fractionLength(1))))/h", accentColor)
                }
            } else {
                HStack(spacing: 12) {
                    metricCell("总支出", "¥\(Int(project.totalSpent))", .red)
                    metricCell("预算", "¥\(Int(project.budget))", .gray)
                    let overrun = max(project.totalSpent - project.budget, 0)
                    metricCell(overrun > 0 ? "超支" : "节省", "¥\(Int(abs(project.budget - project.totalSpent)))", overrun > 0 ? .red : .green)
                }

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
                    Canvas { ctx, size in
                        let trackPath = Capsule().path(in: CGRect(origin: .zero, size: size))
                        ctx.fill(trackPath, with: .color(.gray.opacity(0.2)))
                        let w = size.width * min(project.budgetProgress, 1)
                        let fillPath = Capsule().path(in: CGRect(origin: .zero, size: CGSize(width: w, height: size.height)))
                        ctx.fill(fillPath, with: .color(accentColor))
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
                Image(systemName: "sparkles").foregroundColor(accentColor)
                Text("AI 复盘洞察")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(.black)
            }
            ForEach(reviewResult.highlights) { highlight in
                reportInsightCard(highlight)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    private func reportInsightCard(_ h: InsightHighlight) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(h.icon).font(.system(size: 24))
            VStack(alignment: .leading, spacing: 4) {
                Text(h.label)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(accentColor)
                Text(h.text)
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
                Image(systemName: "lightbulb.fill").foregroundColor(.orange)
                Text("下次预算建议")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(.black)
            }

            if let quote = reviewResult.nextQuoteSuggestion {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("建议报价").font(.system(size: 14)).foregroundColor(.gray)
                        Text(quote.reason).font(.system(size: 12)).foregroundColor(.gray)
                    }
                    Spacer()
                    Text("¥\(Int(quote.suggestedAmount))")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(.green)
                }
                .padding(16)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            ForEach(reviewResult.nextBudgetSuggestions) { s in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.name).font(.system(size: 14)).foregroundColor(.black)
                        if !s.reason.isEmpty {
                            Text(s.reason).font(.system(size: 12)).foregroundColor(.gray)
                        }
                    }
                    Spacer()
                    Text("¥\(Int(s.amount))")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
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
                    Text("生成时间：\(formatFullDate(Date()))")
                        .font(.system(size: 11)).foregroundColor(.gray)
                    Text("by 钱小满 · 一切皆项目")
                        .font(.system(size: 11)).foregroundColor(.gray)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .padding(.bottom, 24)
    }

    // MARK: - 辅助

    private func metricCell(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.system(size: 12, weight: .bold)).foregroundColor(.gray)
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

    private func formatDateRange() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy.MM.dd"
        return "\(fmt.string(from: project.createdAt)) - \(fmt.string(from: Date()))"
    }

    private func formatFullDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm"
        return fmt.string(from: date)
    }
}
