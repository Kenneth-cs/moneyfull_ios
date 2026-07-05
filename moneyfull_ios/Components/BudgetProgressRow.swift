import SwiftUI

/// 单行预算分类进度条，复用项目详情页进度条相同视觉语言
struct BudgetProgressRow: View {
    let item: BudgetItemUI
    var showSpent: Bool = true   // false 时只显示预算金额（用于管理列表）

    private var barColor: Color {
        if item.isOverBudget  { return Color.App.redExpense }
        if item.isNearLimit   { return Color(hex: "#FFA500") }
        return Color(hex: item.categoryColorHex)
    }

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 10) {
                // 图标
                Circle()
                    .fill(Color(hex: item.categoryColorHex).opacity(0.25))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: item.categoryIcon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: item.categoryColorHex))
                    )

                Text(item.categoryName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.App.textBlack)

                Spacer()

                if showSpent {
                    Text("¥\(item.spent.formatted(.number.precision(.fractionLength(0))))/¥\(item.amount.formatted(.number.precision(.fractionLength(0))))")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(item.isOverBudget ? Color.App.redExpense : .gray)
                } else {
                    Text("¥\(item.amount.formatted(.number.precision(.fractionLength(0))))")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                }

                Text("\(Int(min(item.progress, 9.99) * 100))%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(barColor)
                    .frame(minWidth: 34, alignment: .trailing)

                if item.isNearLimit || item.isOverBudget {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(item.isOverBudget ? Color.App.redExpense : Color(hex: "#FFA500"))
                }
            }

            // 进度条
            ZStack(alignment: .leading) {
                Capsule().fill(Color.App.progressTrack).frame(height: 6)
                Capsule()
                    .fill(barColor)
                    .frame(maxWidth: .infinity)
                    .scaleEffect(x: max(0.001, CGFloat(min(item.progress, 1.0))), y: 1, anchor: .leading)
                    .frame(height: 6)
                    .animation(.easeInOut(duration: 0.4), value: item.progress)
            }
        }
    }
}
