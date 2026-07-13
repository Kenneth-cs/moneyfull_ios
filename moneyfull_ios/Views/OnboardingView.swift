import SwiftUI

// MARK: - 欢迎页（首次安装时展示，点击按钮直接进测评）
struct WelcomeView: View {
    /// 点击「一键领取专属方案」后的回调，由 ContentView 控制跳转测评
    var onStart: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {

            // MARK: 全屏背景图
            GeometryReader { geo in
                Image("welcome_bg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
            .ignoresSafeArea()

            // MARK: 悬浮按钮区（底部，自适应 safe area）
            VStack(spacing: 14) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    AnalyticsManager.shared.trackEvent(
                        eventId: "welcome_click_start",
                        eventName: "点击领取专属方案",
                        params: [:]
                    )
                    onStart()
                } label: {
                    HStack(spacing: 10) {
                        Text("一键领取专属方案")
                            .font(.system(size: 18, weight: .heavy))
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#5BAF8A"), Color(hex: "#2C6957")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color(hex: "#2C6957").opacity(0.35), radius: 18, x: 0, y: 8)
                }
                .padding(.horizontal, 32)
                .buttonStyle(PressableButtonStyle())

                Text("30秒即可完成  ·  完全免费")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#2C6957").opacity(0.55))
            }
            // safeAreaInsets 让按钮在刘海屏/Dynamic Island/SE 上都距底部相同视觉距离
            .padding(.bottom, max(28, (UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.windows.first?.safeAreaInsets.bottom ?? 0) + 12))
        }
        .onAppear {
            AnalyticsManager.shared.trackEvent(
                eventId: "welcome_view",
                eventName: "展示欢迎页",
                params: [:]
            )
        }
    }
}

// MARK: - 按压弹性样式
private struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    WelcomeView(onStart: {})
}
