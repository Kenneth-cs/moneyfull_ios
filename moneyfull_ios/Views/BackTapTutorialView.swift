import SwiftUI

// MARK: - 快捷指令安装页（仿竞品风格）
struct BackTapTutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var expandedMethod: Int? = 1 // 默认展开方法一
    @Environment(\.openURL) private var openURL
    
    private let shortcutURL = URL(string: "https://www.icloud.com/shortcuts/1b5541113ab745b69a06049192de3dd1")!
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景渐变
                LinearGradient(
                    colors: [Color(hex: "#E8F8F0"), Color(hex: "#F0FAF5"), Color.white],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // MARK: 如何开启无疼记账
                        SectionCard {
                            VStack(alignment: .leading, spacing: 20) {
                                HStack(spacing: 10) {
                                    Text("✋")
                                        .font(.system(size: 22))
                                    Text("如何开启无痛记账？")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(Color(hex: "#1A3C2E"))
                                }
                                
                                Divider()
                                
                                // 第一步
                                VStack(alignment: .leading, spacing: 14) {
                                    Text("第一步：安装「钱小满自动记账」快捷指令")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Color(hex: "#1A3C2E"))
                                    
                                    Button(action: { openURL(shortcutURL) }) {
                                        Text("点我安装")
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 16)
                                            .background(
                                                LinearGradient(
                                                    colors: [Color(hex: "#34A873"), Color(hex: "#2E9B68")],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 14))
                                            .shadow(color: Color(hex: "#34A873").opacity(0.4), radius: 8, x: 0, y: 4)
                                    }
                                }
                                
                                Divider()
                                
                                // 第二步
                                VStack(alignment: .leading, spacing: 14) {
                                    Text("第二步：设置触发自动记账的方式")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Color(hex: "#1A3C2E"))
                                    
                                    // 方法一：轻点背面
                                    TriggerMethodRow(
                                        index: 1,
                                        title: "使用轻触手机背部触发",
                                        expanded: expandedMethod == 1
                                    ) {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            expandedMethod = expandedMethod == 1 ? nil : 1
                                        }
                                    } content: {
                                        VStack(alignment: .leading, spacing: 8) {
                                            RichChatTextView(
                                                text: "1、打开手机**「设置」** → 选择**「辅助功能」** → 选择**「触控」** → 选择**「轻点背面」** → 选择**「轻点两下」** → 选择**「钱小满自动记账」**",
                                                baseColor: Color(hex: "#4A7A5E"),
                                                highlightColor: Color(hex: "#1A3C2E"),
                                                baseSize: 13,
                                                highlightSize: 13
                                            )
                                            .lineSpacing(4)
                                            Text("2、设置完成，付款后轻点两下手机背面即可自动记账～")
                                                .font(.system(size: 13))
                                                .foregroundColor(Color(hex: "#4A7A5E"))
                                                .lineSpacing(4)
                                        }
                                    }

                                    // 方法二：操作按钮（iPhone 15 Pro+）
                                    TriggerMethodRow(
                                        index: 2,
                                        title: "一键快捷记账（侧边按钮触发）",
                                        expanded: expandedMethod == 2
                                    ) {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            expandedMethod = expandedMethod == 2 ? nil : 2
                                        }
                                    } content: {
                                        VStack(alignment: .leading, spacing: 8) {
                                            RichChatTextView(
                                                text: "适用于 iPhone 15 Pro 及以上机型（配备**「操作按钮」**，位于机身左侧最上方）。你可以将按钮绑定钱小满快捷记账指令，**长按按键**即可快速进入记账页面，**无需解锁打开 App**，消费后随手记更便捷。",
                                                baseColor: Color(hex: "#4A7A5E"),
                                                highlightColor: Color(hex: "#1A3C2E"),
                                                baseSize: 13,
                                                highlightSize: 13
                                            )
                                            .lineSpacing(4)
                                            Divider()
                                            Text("设置步骤：")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(Color(hex: "#1A3C2E"))
                                            Text("1、先在「快捷指令」App 中添加钱小满快捷记账指令")
                                                .font(.system(size: 13))
                                                .foregroundColor(Color(hex: "#4A7A5E"))
                                                .lineSpacing(4)
                                            RichChatTextView(
                                                text: "2、打开系统**「设置 → 操作按钮」**",
                                                baseColor: Color(hex: "#4A7A5E"),
                                                highlightColor: Color(hex: "#1A3C2E"),
                                                baseSize: 13,
                                                highlightSize: 13
                                            )
                                            .lineSpacing(4)
                                            Text("3、滑动选择「快捷指令」，选取「钱小满快捷记账」即可")
                                                .font(.system(size: 13))
                                                .foregroundColor(Color(hex: "#4A7A5E"))
                                                .lineSpacing(4)
                                        }
                                    }

                                    // 方法三：辅助触控
                                    TriggerMethodRow(
                                        index: 3,
                                        title: "使用辅助触控（小白点）触发",
                                        expanded: expandedMethod == 3
                                    ) {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            expandedMethod = expandedMethod == 3 ? nil : 3
                                        }
                                    } content: {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("1、手机设置 → 辅助功能 → 触控 → 辅助触控 → 开启「辅助触控」")
                                                .font(.system(size: 13))
                                                .foregroundColor(Color(hex: "#4A7A5E"))
                                                .lineSpacing(4)
                                            Text("2、点击小白点 → 选择顶层菜单或自定 → 添加「钱小满自动记账」")
                                                .font(.system(size: 13))
                                                .foregroundColor(Color(hex: "#4A7A5E"))
                                                .lineSpacing(4)
                                        }
                                    }

                                    // 方法四：Siri 语音
                                    TriggerMethodRow(
                                        index: 4,
                                        title: "使用 Siri 语音触发",
                                        expanded: expandedMethod == 4
                                    ) {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            expandedMethod = expandedMethod == 4 ? nil : 4
                                        }
                                    } content: {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("直接对 Siri 说「钱小满自动记账」，即可触发截图记账流程。")
                                                .font(.system(size: 13))
                                                .foregroundColor(Color(hex: "#4A7A5E"))
                                                .lineSpacing(4)
                                            Text("提示：也可以在「快捷指令」App 中为该指令添加 Siri 短语。")
                                                .font(.system(size: 13))
                                                .foregroundColor(Color(hex: "#4A7A5E"))
                                                .lineSpacing(4)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        
                        // MARK: 常见问题
                        SectionCard {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(spacing: 10) {
                                    Text("🦶")
                                        .font(.system(size: 22))
                                    Text("常见问题")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(Color(hex: "#1A3C2E"))
                                }
                                
                                Divider()
                                
                                FAQItem(
                                    question: "1、无痛记账是什么？",
                                    answer: "当您支付完成或查看账单详情时，触发预先设置好的快捷指令，能够自动识别当前页面的文字内容并转化成账单信息，同时唤起钱小满记账并自动填入账单信息。"
                                )
                                
                                FAQItem(
                                    question: "2、为什么识别不到金额？",
                                    answer: "快捷指令会截取当前屏幕内容进行识别。请确保：\n① 先打开微信/支付宝的「支付成功页面」或「账单详情页面」\n② 确保页面显示了金额、商户名称等关键信息\n③ 然后再触发快捷指令\n\n⚠️ 注意：如果截取的是 App 列表页或其他页面，可能无法识别到账单信息。\n\n💡 提示：建议在快捷指令中使用「复制到剪贴板」方式传递数据，避免 URL 长度限制。"
                                )
                                
                                FAQItem(
                                    question: "3、快捷指令安装后找不到？",
                                    answer: "打开「快捷指令」App，在「我的快捷指令」中查找「钱小满自动记账」。如需重新安装，请重新点击「点我安装」按钮。"
                                )
                                
                                FAQItem(
                                    question: "4、轻点背面没有反应？",
                                    answer: "请检查是否已在「设置→辅助功能→触控→轻点背面→轻点两下」中选择了「钱小满自动记账」。戴厚保护壳时可能需要稍用力点击。"
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("无痛记账")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "#34A873"))
                    }
                }
            }
        }
    }
}

// MARK: - Section Card
private struct SectionCard<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Trigger Method Row（手风琴折叠）
private struct TriggerMethodRow<Content: View>: View {
    let index: Int
    let title: String
    let expanded: Bool
    let onTap: () -> Void
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack {
                    Text("方法\(["一", "二", "三", "四"][index - 1])：\(title)")
                        .font(.system(size: 14, weight: expanded ? .semibold : .regular))
                        .foregroundColor(expanded ? Color(hex: "#1A3C2E") : Color(hex: "#4A7A5E"))
                    Spacer()
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "#34A873"))
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 14)
                .background(
                    expanded ? Color(hex: "#E8F8F0") : Color(hex: "#F5FBF8")
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            if expanded {
                VStack(alignment: .leading, spacing: 0) {
                    content
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }
                .background(Color(hex: "#F0FAF5"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - FAQ Item
private struct FAQItem: View {
    let question: String
    let answer: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "#1A3C2E"))
            Text(answer)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#5A7A6A"))
                .lineSpacing(4)
        }
    }
}

#Preview {
    BackTapTutorialView()
}
