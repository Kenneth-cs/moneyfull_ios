import SwiftUI

/// 通用长文段落渲染器：把一段"带 Markdown 风格前缀"的纯文字数组渲染成带层次的排版
///
/// 支持的段落前缀：
/// - `## ` 小标题
/// - `• ` 或 `* ` 列表项
/// - `💡 ` 提示框（绿色）
/// - `⚠️ ` 警示框（黄色）
/// - `⏰ ` 时间提醒框（橙色）
/// - `—— ` 落款/签名（右对齐斜体）
/// - 其余：普通段落
///
/// 段落内的 `**文字**` 会被解析成加粗高亮（复用 `RichChatTextView`），用于强调关键信息。
///
/// `ArticleDetailView`、感谢信弹窗、消息中心详情页共用同一份解析逻辑，避免各处重复实现。
struct NoticeParagraphRenderer: View {
    let paragraphs: [String]

    /// 各类文字的配色 / 字号，允许调用方按场景微调（默认取自 ArticleDetailView 原有样式）
    var headingColor: Color = Color(hex: "#226552")
    var bodyColor: Color = Color(hex: "#3A3A3A")
    var headingSize: CGFloat = 18
    var bodySize: CGFloat = 15
    var bulletDotColor: Color = Color(hex: "#9EE0C8")

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(paragraphs.indices, id: \.self) { index in
                paragraphView(paragraphs[index])
            }
        }
    }

    @ViewBuilder
    private func paragraphView(_ para: String) -> some View {
        if para.hasPrefix("## ") {
            RichChatTextView(
                text: String(para.dropFirst(3)),
                baseColor: headingColor,
                highlightColor: headingColor,
                baseSize: headingSize,
                highlightSize: headingSize
            )
            .font(.system(size: headingSize, weight: .bold))
            .padding(.top, 4)
        } else if para.hasPrefix("• ") || para.hasPrefix("* ") {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(bulletDotColor)
                    .frame(width: 6, height: 6)
                    .padding(.top, 7)
                RichChatTextView(
                    text: String(para.dropFirst(2)),
                    baseColor: bodyColor,
                    highlightColor: headingColor,
                    baseSize: bodySize,
                    highlightSize: bodySize
                )
                .lineSpacing(6)
            }
        } else if para.hasPrefix("💡 ") {
            calloutBox(text: String(para.dropFirst(2)), emoji: "💡",
                       fg: Color(hex: "#276956"), bg: Color(hex: "#F0FBF6"))
        } else if para.hasPrefix("⚠️ ") {
            calloutBox(text: String(para.dropFirst(2)), emoji: "⚠️",
                       fg: Color(hex: "#B8860B"), bg: Color(hex: "#FFF8E1"))
        } else if para.hasPrefix("⏰ ") {
            calloutBox(text: String(para.dropFirst(2)), emoji: "⏰",
                       fg: Color(hex: "#C0691E"), bg: Color(hex: "#FFF1E3"))
        } else if para.hasPrefix("—— ") {
            RichChatTextView(
                text: para,
                baseColor: bodyColor.opacity(0.7),
                highlightColor: headingColor,
                baseSize: bodySize - 1,
                highlightSize: bodySize - 1
            )
            .italic()
            .frame(maxWidth: .infinity, alignment: .trailing)
        } else {
            RichChatTextView(
                text: para,
                baseColor: bodyColor,
                highlightColor: headingColor,
                baseSize: bodySize,
                highlightSize: bodySize
            )
            .lineSpacing(7)
        }
    }

    private func calloutBox(text: String, emoji: String, fg: Color, bg: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(emoji)
                .font(.system(size: 14))
            RichChatTextView(
                text: text,
                baseColor: fg,
                highlightColor: fg,
                baseSize: bodySize - 1,
                highlightSize: bodySize - 1
            )
            .fontWeight(.medium)
            .lineSpacing(5)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ScrollView {
        NoticeParagraphRenderer(paragraphs: [
            "大家好，我们是钱小满的开发团队",
            "## 🎁 专属老朋友的\"小满心意\"",
            "作为第一批入驻\"钱小满\"的种子用户，我们为大家准备了**限时专属**的\"过渡期礼物\"：",
            "• 6个月专属免费体验：商业付费功能上线后，**所有老用户**都将免费获赠 6 个月的会员体验期。",
            "⏰ 温馨提示：这份专属福利领取截止时间为 2026年9月18日。",
            "—— \"钱小满\"产品开发团队 敬上"
        ])
        .padding()
    }
}
