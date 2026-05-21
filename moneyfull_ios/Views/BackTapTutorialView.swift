import SwiftUI

struct BackTapTutorialView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 头部图标
                    VStack(spacing: 16) {
                        Image(systemName: "iphone.radiowaves.left.and.right")
                            .font(.system(size: 60))
                            .foregroundColor(Color.App.darkGreen)
                        
                        Text("轻点背面快捷记账")
                            .font(.system(size: 24, weight: .bold))
                        
                        Text("双击手机背面，快速打开钱小满记账")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 20)
                    
                    // 步骤说明
                    VStack(alignment: .leading, spacing: 20) {
                        TutorialStep(
                            number: 1,
                            title: "打开快捷指令App",
                            description: "在iPhone上找到并打开「快捷指令」App",
                            icon: "square.grid.2x2"
                        )
                        
                        TutorialStep(
                            number: 2,
                            title: "创建新快捷指令",
                            description: "点击右上角「+」号创建新的快捷指令",
                            icon: "plus.circle"
                        )
                        
                        TutorialStep(
                            number: 3,
                            title: "添加操作",
                            description: "搜索并添加「打开App」操作，选择「钱小满」",
                            icon: "app.badge.checkmark"
                        )
                        
                        TutorialStep(
                            number: 4,
                            title: "命名快捷指令",
                            description: "点击顶部名称，将其命名为「钱小满记账」",
                            icon: "pencil"
                        )
                        
                        TutorialStep(
                            number: 5,
                            title: "打开系统设置",
                            description: "前往「设置」→「辅助功能」→「触控」→「轻点背面」",
                            icon: "gear"
                        )
                        
                        TutorialStep(
                            number: 6,
                            title: "绑定快捷指令",
                            description: "选择「轻点两下」或「轻点三下」，找到并选择「钱小满记账」",
                            icon: "hand.tap"
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // 使用提示
                    VStack(alignment: .leading, spacing: 12) {
                        Text("使用提示")
                            .font(.system(size: 18, weight: .bold))
                        
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 16))
                            
                            Text("双击手机背面时，确保手机已解锁，钱小满将自动打开并进入记账模式")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 16))
                            
                            Text("如果手机装有保护壳，可能需要稍微用力双击")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(16)
                    .background(Color.App.tabBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)
                    
                    // Siri 提示
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Siri 语音记账")
                            .font(.system(size: 18, weight: .bold))
                        
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "mic.fill")
                                .foregroundColor(Color.App.darkGreen)
                                .font(.system(size: 16))
                            
                            Text("您也可以直接对Siri说：「用钱小满记一笔，打车50块」")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(16)
                    .background(Color.App.tabBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
            }
            .background(Color.App.backgroundGray.ignoresSafeArea())
            .navigationTitle("快捷记账设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Tutorial Step
struct TutorialStep: View {
    let number: Int
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // 步骤编号
            ZStack {
                Circle()
                    .fill(Color.App.darkGreen)
                    .frame(width: 32, height: 32)
                
                Text("\(number)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(Color.App.darkGreen)
                        .font(.system(size: 16))
                    
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                }
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
    }
}

#Preview {
    BackTapTutorialView()
}