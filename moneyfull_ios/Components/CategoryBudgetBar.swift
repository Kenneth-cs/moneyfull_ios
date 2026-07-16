import SwiftUI

/// 分类预算执行进度条
struct CategoryBudgetBar: View {
    let name: String
    let icon: String
    let colorHex: String
    let budgeted: Double
    let actual: Double
    let ratio: Double

    private var barColor: Color {
        if ratio > 1.05 { return Color.App.redExpense }
        else if ratio > 0.85 { return .orange }
        else { return Color(hex: colorHex) }
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: colorHex))
                    .frame(width: 20)
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.App.textBlack)
                Spacer()
                Text("¥\(Int(actual))")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.App.textBlack)
                Text("/ ¥\(Int(budgeted))")
                    .font(.system(size: 12))
                    .foregroundColor(Color.App.textSecondary)
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
