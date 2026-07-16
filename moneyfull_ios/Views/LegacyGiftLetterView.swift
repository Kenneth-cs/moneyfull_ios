import SwiftUI

/// "给陪伴的你"——老用户会员福利感谢信
///
/// 全屏信件风格页面，两处复用：
/// 1. ContentView：老用户首次启动新版本，自动作为 fullScreenCover 展示一次
/// 2. NoticeCenterView：消息中心点开后作为 sheet 可随时回看
struct LegacyGiftLetterView: View {
    var onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            // 整体背景：信封牛皮纸感的暖白色
            Color(hex: "#F7F9F7").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    compactHeader
                    letterPaper
                    Spacer().frame(height: 100)
                }
            }
            .ignoresSafeArea(edges: .top)

            // 固定底部按钮
            bottomButton
        }
    }

    // MARK: - 紧凑 Header

    private var compactHeader: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#BFEBD6"), Color(hex: "#E2F5EA"), Color(hex: "#F7F9F7")],
                startPoint: .top, endPoint: .bottom
            )

            HStack(alignment: .bottom, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Spacer()
                    Text("给陪伴的你")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(hex: "#1A3C2E"))
                    Text("🩷")
                        .font(.system(size: 18))
                    Text("关于钱小满会员付费服务的说明")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: "#5A8A6E"))
                    Spacer().frame(height: 16)
                }
                .padding(.leading, 24)

                Spacer()

                // 水獭插画，底部对齐，自然"站"在header底边
                Image("legacy_gift_otter")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 130, height: 130)
                    .padding(.trailing, 12)
            }

            // 右上角关闭按钮
            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: "#4A7A5E"))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.8))
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
                    }
                    .padding(.top, 54)
                    .padding(.trailing, 18)
                }
                Spacer()
            }
        }
        .frame(height: 200)
    }

    // MARK: - 信件纸张主体

    private var letterPaper: some View {
        VStack(spacing: 0) {
            // 纸张顶部：信封装饰
            letterTopDecoration

            // 正文内容
            VStack(alignment: .leading, spacing: 0) {
                // 开场白（斜体，灰色，小一些）
                openingSection

                divider

                // 正文第一段：背景说明（浅绿色背景块）
                contextSection

                divider

                // 第1条：基础功能免费
                section1

                divider

                // 第2条：付费解锁
                section2

                divider

                // 专属老用户福利（高亮色块，最重要的内容）
                giftSection

                divider

                // 征集反馈
                feedbackSection

                divider

                // 结束语 + 签名 + 波浪
                closingSection
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color.white)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 24, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 24
            )
        )
        .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: -4)
        .padding(.top, -16) // 与 header 底部轻微叠压，有连续感
    }

    // MARK: - 信封顶部装饰

    private var letterTopDecoration: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "envelope.open.fill")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#34A873"))
                Text("一封信")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "#34A873"))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(hex: "#E8F9F0"))
            .clipShape(Capsule())

            Spacer()

            // 日期戳
            Text("2026 · 7")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: "#A0B8AC"))
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    // MARK: - 开场白

    private var openingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("致各位陪伴钱小满一路走来的见证者：")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: "#7A9A88"))
                .italic()

            Text("大家好，我们是钱小满的开发团队。")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(Color(hex: "#2A4A38"))
        }
        .padding(.bottom, 20)
    }

    // MARK: - 背景说明（浅绿色背景块）

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("自\"钱小满\"上线以来，我们始终坚持全功能免费开放，遇见了最早一批愿意相信我们、陪着产品一起打磨的你；")
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(Color(hex: "#3A5A48"))
                .lineSpacing(6)

            Text("每一条留言、每一次反馈、每一个默默使用的日夜，对我们来说都是**最珍贵的底气**。")
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(Color(hex: "#3A5A48"))
                .lineSpacing(6)

            Spacer().frame(height: 4)

            HStack(alignment: .top, spacing: 10) {
                Text("为了让钱小满能健康、长久地走下去，我们决定在接下来的新版本中，")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(Color(hex: "#3A5A48"))
                    .lineSpacing(6)
            }

            // 关键信息加大加绿
            Text("正式推出会员付费服务。")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(Color(hex: "#1A7A50"))
        }
        .padding(18)
        .background(Color(hex: "#F0FBF5"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.bottom, 20)
    }

    // MARK: - 第1条

    private var section1: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(number: "1", title: "基础功能，坚持免费")

            Text("现有的**项目制记账、核心统计图表**等基础功能将持续免费开放！")
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(Color(hex: "#3A5A48"))
                .lineSpacing(6)

            Text("我们绝不会在原有免费功能上\"切一刀\"来强迫付费，即使不选择付费，也完全不影响日常顺畅使用。")
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(Color(hex: "#6A8A78"))
                .lineSpacing(5)
        }
        .padding(.bottom, 20)
    }

    // MARK: - 第2条

    private var section2: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(number: "2", title: "付费解锁，增量体验")

            Text("付费功能将聚焦于**更高级的资产管理、深度数据分析以及专属财务方案**，旨在满足有更高阶需求的用户自愿选择。")
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(Color(hex: "#3A5A48"))
                .lineSpacing(6)
        }
        .padding(.bottom, 20)
    }

    // MARK: - 🎁 专属福利（最重要，视觉最突出）

    private var giftSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(emoji: "🎁", title: "专属老朋友的\"小满心意\"")

            Text("作为第一批入驻\"钱小满\"的种子用户，你们对我们来说无比珍贵。为了感谢大家的包容与陪伴，我们为大家准备了限时专属的\"过渡期礼物\"：")
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(Color(hex: "#3A5A48"))
                .lineSpacing(6)

            // 核心福利：大字凸显
            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("6")
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(hex: "#1A7A50"))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("个月")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundColor(Color(hex: "#1A7A50"))
                        Text("高级会员体验")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(hex: "#4A9A68"))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("完全免费")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(hex: "#34A873"))
                            .clipShape(Capsule())
                        Text("不自动扣费")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(Color(hex: "#5A9A78"))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Rectangle()
                    .fill(Color(hex: "#D0EFE0"))
                    .frame(height: 1)
                    .padding(.horizontal, 16)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#7AAA90"))
                    Text("领取截止 2026年9月18日")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: "#6A9A80"))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(hex: "#F0FBF5"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color(hex: "#B0E0C8"), lineWidth: 1.5)
                    )
            )
        }
        .padding(.bottom, 20)
    }

    // MARK: - 反馈

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(emoji: "💬", title: "我们想听听你的声音")

            Text("由于这是我们第一次尝试商业化，新功能和体验上肯定还会有不够完善的地方。")
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(Color(hex: "#3A5A48"))
                .lineSpacing(6)

            (
                Text("无论遇到 Bug，还是对新功能有任何吐槽、建议，都欢迎随时通过")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(Color(hex: "#3A5A48"))
                + Text(" [APP内 · 帮助反馈] ")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#1A7A50"))
                + Text("告诉我们，每一个问题我们都会认真记录！")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(Color(hex: "#3A5A48"))
            )
            .lineSpacing(6)
        }
        .padding(.bottom, 20)
    }

    // MARK: - 结束语

    private var closingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("能陪大家一起打理生活、记录收支，是我们做这款产品的初心。")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: "#2A4A38"))
                .lineSpacing(6)
                .italic()

            Text("感谢大家的理解、包容与一路同行。")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(Color(hex: "#1A7A50"))
                .lineSpacing(6)

            // 签名
            HStack {
                Spacer()
                Text("—— \"钱小满\" 产品开发团队 敬上")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "#7A9A88"))
                    .italic()
            }
            .padding(.top, 4)

            // 波浪装饰线（信件结尾感）
            waveDivider
                .padding(.top, 12)
        }
    }

    // MARK: - 复用组件

    /// 带编号的节标题（1. / 2.）
    private func sectionHeader(number: String, title: String) -> some View {
        HStack(spacing: 10) {
            Text(number)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color(hex: "#34A873"))
                .clipShape(Circle())
            Text(title)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundColor(Color(hex: "#1A5C40"))
        }
    }

    /// 带 emoji 的节标题（🎁 / 💬）
    private func sectionHeader(emoji: String, title: String) -> some View {
        HStack(spacing: 8) {
            Text(emoji)
                .font(.system(size: 18))
            Text(title)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundColor(Color(hex: "#1A5C40"))
        }
    }

    /// 节间分隔线
    private var divider: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(Color(hex: "#C8E8D8"))
                    .frame(width: 4, height: 4)
            }
            Rectangle()
                .fill(Color(hex: "#D8F0E4"))
                .frame(height: 1)
        }
        .padding(.vertical, 4)
        .padding(.bottom, 16)
    }

    /// 底部波浪装饰（信件结尾感）
    private var waveDivider: some View {
        Canvas { context, size in
            var path = Path()
            let waveHeight: CGFloat = 5
            let wavelength: CGFloat = 20
            path.move(to: CGPoint(x: 0, y: size.height / 2))
            var x: CGFloat = 0
            while x <= size.width {
                let y = size.height / 2 + waveHeight * sin((x / wavelength) * .pi)
                path.addLine(to: CGPoint(x: x, y: y))
                x += 1
            }
            context.stroke(path, with: .color(Color(hex: "#B0E0C8")), lineWidth: 1.5)
        }
        .frame(height: 14)
    }

    // MARK: - 底部按钮

    private var bottomButton: some View {
        VStack(spacing: 0) {
            // 渐变遮罩
            LinearGradient(
                colors: [Color(hex: "#F7F9F7").opacity(0), Color(hex: "#F7F9F7")],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 24)

            Button(action: onDismiss) {
                HStack(spacing: 8) {
                    Text("❤️")
                        .font(.system(size: 16))
                    Text("点击领取")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#1A7A50"), Color(hex: "#34A873")],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: Color(hex: "#1A7A50").opacity(0.35), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
            .background(Color(hex: "#F7F9F7"))
        }
    }
}

// MARK: - Text 加粗扩展（支持 **text** 语法，简单场景）

extension Text {
    /// 把含有 `**文字**` 的字符串渲染成局部加粗的 Text（不依赖外部组件，轻量级）
    static func richText(_ raw: String, baseColor: Color, boldColor: Color, size: CGFloat) -> Text {
        var result = Text("")
        let parts = raw.components(separatedBy: "**")
        for (i, part) in parts.enumerated() {
            if i % 2 == 0 {
                result = result + Text(part)
                    .font(.system(size: size, design: .rounded))
                    .foregroundColor(baseColor)
            } else {
                result = result + Text(part)
                    .font(.system(size: size, weight: .bold, design: .rounded))
                    .foregroundColor(boldColor)
            }
        }
        return result
    }
}

#Preview {
    LegacyGiftLetterView(onDismiss: {})
}
