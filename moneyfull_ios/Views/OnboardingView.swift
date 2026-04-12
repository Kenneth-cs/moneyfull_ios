import SwiftUI

// MARK: - 新手引导页（首次安装时展示，之后不再出现）
struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            emoji: "🦫",
            title: "你好，我是钱小满",
            subtitle: "一只懒洋洋的卡皮巴拉，\n专门帮你管好每一分钱。",
            tip: "不用焦虑，慢慢来，钱的事交给我～",
            bgColor: "#A8E6CF",
            darkColor: "#2C6957"
        ),
        OnboardingPage(
            emoji: "📁",
            title: "用「项目」管理你的钱",
            subtitle: "装修、旅行、日常开销...\n每件事都有自己的账本。",
            tip: "先建一个项目，再记录里面的每笔支出收入",
            bgColor: "#DCEDC1",
            darkColor: "#2C6957"
        ),
        OnboardingPage(
            emoji: "✏️",
            title: "记一笔，很简单",
            subtitle: "点底部的「+」号，\n输入金额选好分类就完成了。",
            tip: "每天花2秒记录，月底心里有底",
            bgColor: "#DCDE8D",
            darkColor: "#5F621F"
        ),
    ]
    
    var body: some View {
        ZStack {
            Color(hex: pages[currentPage].bgColor).opacity(0.25)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.4), value: currentPage)
            
            VStack(spacing: 0) {
                // 跳过按钮
                HStack {
                    Spacer()
                    Button(action: finish) {
                        Text("跳过")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: pages[currentPage].darkColor).opacity(0.6))
                            .padding(.horizontal, 16).padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer()
                
                // 卡皮巴拉/图标大展示区
                ZStack {
                    Circle()
                        .fill(Color(hex: pages[currentPage].bgColor).opacity(0.5))
                        .frame(width: 180, height: 180)
                        .animation(.easeInOut(duration: 0.4), value: currentPage)
                    
                    Text(pages[currentPage].emoji)
                        .font(.system(size: 90))
                        .scaleEffect(currentPage == 0 ? 1.0 : 0.85)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: currentPage)
                }
                .padding(.bottom, 40)
                
                // 文案区
                VStack(spacing: 16) {
                    Text(pages[currentPage].title)
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundColor(Color(hex: pages[currentPage].darkColor))
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut, value: currentPage)
                    
                    Text(pages[currentPage].subtitle)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Color.App.textBlack.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                    
                    // 小提示气泡
                    HStack(spacing: 8) {
                        Text("🦫")
                            .font(.system(size: 14))
                        Text(pages[currentPage].tip)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: pages[currentPage].darkColor))
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color(hex: pages[currentPage].bgColor).opacity(0.4))
                    .clipShape(Capsule())
                    .padding(.top, 4)
                }
                .padding(.horizontal, 40)
                .animation(.easeInOut(duration: 0.3), value: currentPage)
                
                Spacer()
                
                // 页码指示器 + 按钮
                VStack(spacing: 32) {
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { i in
                            Capsule()
                                .fill(i == currentPage
                                      ? Color(hex: pages[currentPage].darkColor)
                                      : Color(hex: pages[currentPage].darkColor).opacity(0.2))
                                .frame(width: i == currentPage ? 24 : 8, height: 8)
                                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentPage)
                        }
                    }
                    
                    Button(action: nextOrFinish) {
                        HStack(spacing: 8) {
                            Text(currentPage == pages.count - 1 ? "开始记账" : "下一步")
                                .font(.system(size: 18, weight: .heavy))
                            Image(systemName: currentPage == pages.count - 1 ? "checkmark" : "arrow.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: pages[currentPage].bgColor),
                                         Color(hex: pages[currentPage].darkColor)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color(hex: pages[currentPage].darkColor).opacity(0.3),
                                radius: 12, x: 0, y: 6)
                    }
                    .padding(.horizontal, 40)
                    .animation(.easeInOut, value: currentPage)
                }
                .padding(.bottom, 50)
            }
        }
    }
    
    private func nextOrFinish() {
        if currentPage < pages.count - 1 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                currentPage += 1
            }
        } else {
            finish()
        }
    }
    
    private func finish() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        withAnimation(.easeInOut(duration: 0.4)) {
            isPresented = false
        }
    }
}

// MARK: - 引导页数据模型
struct OnboardingPage {
    let emoji: String
    let title: String
    let subtitle: String
    let tip: String
    let bgColor: String
    let darkColor: String
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
