import SwiftUI

/// 预算预警底部Sheet（多触发时显示）
struct BudgetAlertSheet: View {
    let triggers: [BudgetAlertTrigger]
    let onViewDetail: (UUID) -> Void
    let onDismiss: () -> Void
    
    @State private var show = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部拖拽指示器
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 16)
            
            // 卡皮头部
            VStack(spacing: 8) {
                Text(maxMood.emoji)
                    .font(.system(size: 48))
                
                Text("有几个预算需要注意一下")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .padding(.bottom, 20)
            
            // 触发列表
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(triggers) { trigger in
                        BudgetAlertRow(trigger: trigger)
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(maxHeight: 300)
            
            // 卡皮文案
            Text(maxMood.message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            
            // 按钮区域
            VStack(spacing: 12) {
                Button(action: {
                    if let firstTrigger = triggers.first {
                        onViewDetail(firstTrigger.projectID)
                    }
                }) {
                    Text("查看预算详情")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                
                Button(action: onDismiss) {
                    Text("知道了")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: -5)
        )
        .offset(y: show ? 0 : UIScreen.main.bounds.height)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: show)
        .onAppear {
            show = true
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 100 {
                        dismiss()
                    }
                }
        )
    }
    
    private var maxMood: CapyMood {
        let maxProgress = triggers.map(\.progress).max() ?? 0
        return CapyMood.from(progress: maxProgress)
    }
    
    private func dismiss() {
        show = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onDismiss()
        }
    }
}

/// 单个预算预警行
struct BudgetAlertRow: View {
    let trigger: BudgetAlertTrigger
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Text(trigger.emoji)
                .font(.title3)
            
            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(trigger.categoryName ?? trigger.projectName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(trigger.isProjectLevel ? "总预算" : "分类预算")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 进度条
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(trigger.progress * 100))%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(progressColor)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(.systemGray5))
                            .frame(height: 4)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(progressColor)
                            .frame(width: min(geometry.size.width, geometry.size.width * CGFloat(trigger.progress)), height: 4)
                    }
                }
                .frame(width: 80, height: 4)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private var progressColor: Color {
        switch trigger.progress {
        case ..<0.8: return .green
        case 0.8..<1.0: return .orange
        case 1.0..<1.2: return .red
        default: return .red
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()
        
        BudgetAlertSheet(
            triggers: [
                BudgetAlertTrigger(
                    id: UUID(),
                    projectID: UUID(),
                    projectName: "新疆游",
                    categoryID: nil,
                    categoryName: nil,
                    progress: 0.85,
                    checkpoint: 85,
                    emoji: "🍊",
                    message: "「新疆游」总预算已用到 85%，还剩 ¥1500"
                ),
                BudgetAlertTrigger(
                    id: UUID(),
                    projectID: UUID(),
                    projectName: "新疆游",
                    categoryID: UUID(),
                    categoryName: "餐饮",
                    progress: 0.92,
                    checkpoint: 90,
                    emoji: "🍊💦",
                    message: "「餐饮」预算已用到 92%，还剩 ¥80"
                )
            ],
            onViewDetail: { _ in },
            onDismiss: {}
        )
    }
}
