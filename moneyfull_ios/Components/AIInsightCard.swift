import SwiftUI

/// AI 洞察卡片组件
struct AIInsightCard: View {
    let icon: String
    let label: String
    let text: String
    let accentColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(icon)
                .font(.system(size: 22))

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(accentColor)

                Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(Color.App.textBlack)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
