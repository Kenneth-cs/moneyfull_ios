import SwiftUI

struct SpendingInsightCard: View {
    let data: SpendingInsightData
    var onViewDetail: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题行
            HStack(spacing: 8) {
                Text("🍴")
                    .font(.system(size: 18))
                HStack(spacing: 4) {
                    Text(data.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#1F2937"))
                    Text(data.emoji)
                        .font(.system(size: 14))
                }
                Spacer()
                // 环比变化指示
                if let mom = data.momChangePercent {
                    let isDown = mom <= 0
                    HStack(spacing: 2) {
                        Image(systemName: isDown ? "arrow.down.right" : "arrow.up.right")
                            .font(.system(size: 9, weight: .bold))
                        Text("\(abs(Int(mom)))%")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(isDown ? Color(hex: "#10B981") : Color(hex: "#EF4444"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((isDown ? Color(hex: "#10B981") : Color(hex: "#EF4444")).opacity(0.1))
                    .clipShape(Capsule())
                }
            }

            // 分项列表
            VStack(spacing: 12) {
                ForEach(data.items.prefix(4), id: \.name) { item in
                    InsightItemRow(item: item)
                }
            }

            // 查看完整明细按钮
            Button(action: { onViewDetail?() }) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("查看完整明细")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(Color(hex: "#226552"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(hex: "#9EE0C8").opacity(0.4), lineWidth: 1)
                        )
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: "#E1E3E2").opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - 分项行

private struct InsightItemRow: View {
    let item: InsightBreakdownItem

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(item.icon)
                    .font(.system(size: 16))
                Text(item.name)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "#374151"))
                Spacer()
                Text("¥\(item.amount.smartFormat()) (\(Int(item.ratio * 100))%)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "#1F2937"))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(hex: "#F3F4F6"))
                        .frame(height: 8)
                    Capsule()
                        .fill(Color(hex: item.barColorHex))
                        .frame(width: max(8, geo.size.width * item.ratio), height: 8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: item.ratio)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Amount formatter helper

private extension Double {
    func smartFormat() -> String {
        if truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", self)
        }
        return String(format: "%.2f", self)
    }
}

// MARK: - Preview

#Preview {
    SpendingInsightCard(
        data: SpendingInsightData(
            title: "餐饮支出洞察",
            emoji: "🍩",
            totalAmount: 1280,
            totalExpenseRatio: 0.15,
            momChangePercent: -5,
            period: .lastMonth,
            items: [
                InsightBreakdownItem(icon: "🍔", name: "外卖", amount: 650, ratio: 0.51, barColorHex: "#F9A8D4"),
                InsightBreakdownItem(icon: "🍱", name: "堂食", amount: 420, ratio: 0.33, barColorHex: "#FDE68A"),
                InsightBreakdownItem(icon: "🧋", name: "零食/饮品", amount: 210, ratio: 0.16, barColorHex: "#6EE7B7"),
            ]
        ),
        onViewDetail: {}
    )
    .padding()
}
