import SwiftUI

/// 解析 **text** 语法并渲染加粗高亮的聊天气泡文本
struct RichChatTextView: View {
    let text: String
    var baseColor: Color = Color(hex: "#1A4D3E")
    var highlightColor: Color = Color(hex: "#226552")
    var baseSize: CGFloat = 15
    var highlightSize: CGFloat = 16

    var body: some View {
        buildText()
            .font(.system(size: baseSize, design: .rounded))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func buildText() -> Text {
        let segments = parseSegments(text)
        var result = Text("")
        for seg in segments {
            if seg.isHighlighted {
                result = result + Text(seg.content)
                    .font(.system(size: highlightSize, weight: .bold, design: .rounded))
                    .foregroundColor(highlightColor)
            } else {
                result = result + Text(seg.content)
                    .font(.system(size: baseSize, design: .rounded))
                    .foregroundColor(baseColor)
            }
        }
        return result
    }

    /// 将含有 **...** 标记的字符串解析为段落列表
    private func parseSegments(_ input: String) -> [(content: String, isHighlighted: Bool)] {
        var segments: [(content: String, isHighlighted: Bool)] = []
        var remaining = input[input.startIndex...]
        
        while !remaining.isEmpty {
            if let openRange = remaining.range(of: "**") {
                // 普通文本
                let before = String(remaining[remaining.startIndex..<openRange.lowerBound])
                if !before.isEmpty {
                    segments.append((before, false))
                }
                let afterOpen = remaining[openRange.upperBound...]
                if let closeRange = afterOpen.range(of: "**") {
                    // 高亮文本
                    let highlighted = String(afterOpen[afterOpen.startIndex..<closeRange.lowerBound])
                    if !highlighted.isEmpty {
                        segments.append((highlighted, true))
                    }
                    remaining = afterOpen[closeRange.upperBound...]
                } else {
                    // 没有闭合符，剩余作普通文本
                    segments.append(("**" + String(afterOpen), false))
                    break
                }
            } else {
                segments.append((String(remaining), false))
                break
            }
        }
        return segments
    }
}

#Preview {
    RichChatTextView(text: "嗨！上个月您的餐饮支出共计 **¥1,280**，占总支出的 **15%**，相比上月下降了 **5%**，表现超棒！🎉")
        .padding()
}
