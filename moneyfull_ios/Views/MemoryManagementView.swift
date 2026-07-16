import SwiftUI
import SwiftData

struct MemoryManagementView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MemoryRule.createdAt, order: .reverse) private var memoryRules: [MemoryRule]
    @State private var showDeleteAlert = false
    @State private var ruleToDelete: MemoryRule?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.App.textBlack)
                            .frame(width: 40, height: 40)
                    }
                    Spacer()
                    Text("小满记忆管理")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(Color.App.textBlack)
                    Spacer()
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                if memoryRules.isEmpty {
                    // 空状态
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.4))
                        Text("暂无记忆规则")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.gray)
                        Text("当您在记账时修改AI推荐的分类，\nAI会自动学习并记住您的偏好")
                            .font(.system(size: 14))
                            .foregroundColor(.gray.opacity(0.7))
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                } else {
                    // 说明文字
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                            Text("AI会根据这些规则自动调整分类推荐")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }
                        
                        Text("左滑可删除规则")
                            .font(.system(size: 12))
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                    
                    // 规则列表
                    List {
                        ForEach(memoryRules) { rule in
                            MemoryRuleRow(rule: rule)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .padding(.vertical, 4)
                        }
                        .onDelete { indexSet in
                            if let index = indexSet.first {
                                ruleToDelete = memoryRules[index]
                                showDeleteAlert = true
                            }
                        }
                    }
                    .listStyle(.plain)
                    .background(Color.App.backgroundGray)
                }
            }
            .background(Color.App.backgroundGray.ignoresSafeArea())
            .alert("确认删除", isPresented: $showDeleteAlert) {
                Button("删除", role: .destructive) {
                    if let rule = ruleToDelete {
                        deleteRule(rule)
                    }
                }
                Button("取消", role: .cancel) {
                    ruleToDelete = nil
                }
            } message: {
                if let rule = ruleToDelete {
                    Text("确定要删除规则「当提到\(rule.keyword)时，记入\(rule.targetCategoryName)」吗？")
                }
            }
        }
    }
    
    private func deleteRule(_ rule: MemoryRule) {
        modelContext.delete(rule)
        try? modelContext.save()
        ruleToDelete = nil
    }
}

// MARK: - 记忆规则行
struct MemoryRuleRow: View {
    let rule: MemoryRule
    
    var body: some View {
        HStack(spacing: 16) {
            // 图标
            ZStack {
                Circle()
                    .fill(Color.App.primaryGreen.opacity(0.3))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "brain")
                    .font(.system(size: 20))
                    .foregroundColor(Color.App.darkGreen)
            }
            
            // 规则描述
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text("当提到")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    
                    Text("「\(rule.keyword)」")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.App.textBlack)
                    
                    Text("时")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                HStack(spacing: 4) {
                    Text("记入")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    
                    Text("「\(rule.targetCategoryName)」")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.App.darkGreen)
                    
                    if !rule.targetProjectName.isEmpty {
                        Text("·")
                            .foregroundColor(.gray)
                        Text(rule.targetProjectName)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                
                Text(formatDate(rule.createdAt))
                    .font(.system(size: 11))
                    .foregroundColor(.gray.opacity(0.6))
            }
            
            Spacer()
            
            // 权重指示
            VStack(spacing: 4) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(rule.weight > 1 ? .orange : .gray.opacity(0.4))
                
                if rule.weight > 1 {
                    Text("权重\(rule.weight)")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(16)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: date)
    }
}

#Preview {
    MemoryManagementView()
        .modelContainer(for: MemoryRule.self, inMemory: true)
}
