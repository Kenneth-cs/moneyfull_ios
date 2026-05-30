import SwiftUI

struct AppRatingPromptView: View {
    @Binding var isPresented: Bool
    let onRate: () -> Void
    let onFeedback: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
            
            VStack(spacing: 20) {
                Text("🦫")
                    .font(.system(size: 60))
                
                Text("用得还开心吗？")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundColor(Color(hex: "#1A5276"))
                
                Text("如果你喜欢钱小满，\n去 App Store 给我们一个好评吧！")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                
                VStack(spacing: 12) {
                    Button(action: {
                        onRate()
                        dismiss()
                    }) {
                        Text("去评分 ✨")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "#9EE0C8"), Color(hex: "#276956")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                    }
                    
                    Button(action: {
                        onFeedback()
                        dismiss()
                    }) {
                        Text("有点问题，反馈一下")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(hex: "#276956"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "#F0FAF5"))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color(hex: "#9EE0C8"), lineWidth: 1)
                                    )
                            )
                    }
                    
                    Button(action: { dismiss() }) {
                        Text("以后再说")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 8)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 32)
        }
    }
    
    private func dismiss() {
        AppRatingManager.shared.markAsDismissed()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isPresented = false
        }
    }
}

#Preview {
    AppRatingPromptView(
        isPresented: .constant(true),
        onRate: {},
        onFeedback: {}
    )
}
