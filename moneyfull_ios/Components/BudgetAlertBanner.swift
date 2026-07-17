import SwiftUI

/// 预算预警顶部Banner（单触发时显示）
struct BudgetAlertBanner: View {
    let trigger: BudgetAlertTrigger
    let onTap: () -> Void
    let onDismiss: () -> Void
    
    @State private var show = false
    @State private var opacity: Double = 0
    
    var body: some View {
        VStack {
            if show {
                HStack(spacing: 12) {
                    // 卡皮emoji
                    Text(trigger.emoji)
                        .font(.title2)
                    
                    // 消息内容
                    VStack(alignment: .leading, spacing: 2) {
                        Text(trigger.categoryName ?? trigger.projectName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text(trigger.message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    // 跳转箭头
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .onTapGesture {
                    onTap()
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            if value.translation.height < -20 {
                                dismiss()
                            }
                        }
                )
            }
            
            Spacer()
        }
        .opacity(opacity)
        .onChange(of: show) { _, newValue in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                opacity = newValue ? 1 : 0
            }
        }
        .onAppear {
            show = true
            
            // 3.5秒后自动消失
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                dismiss()
            }
        }
    }
    
    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            show = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()
        
        BudgetAlertBanner(
            trigger: BudgetAlertTrigger(
                id: UUID(),
                projectID: UUID(),
                projectName: "新疆游",
                categoryID: nil,
                categoryName: "餐饮",
                progress: 0.85,
                checkpoint: 85,
                emoji: "🍊",
                message: "「餐饮」预算已用到 85%，还剩 ¥150"
            ),
            onTap: {},
            onDismiss: {}
        )
    }
}
