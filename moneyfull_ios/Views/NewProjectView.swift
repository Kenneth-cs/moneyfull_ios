import SwiftUI
import SwiftData
struct NewProjectView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var storeManager: StoreManager
    
    @State private var name = ""
    @State private var desc = ""
    @State private var budgetText = ""
    @State private var selectedIcon = "folder.fill"
    @State private var selectedColor = "#A8E0C2"
    @State private var showUpgradeAlert = false
    @State private var showPaywall = false
    
    @FocusState private var isAnyFieldFocused: Bool
    
    var canCreateProject: Bool {
        #if DEBUG
        print("🔍 项目创建检查:")
        print("  - isPremium: \(storeManager.isPremium)")
        print("  - customProjects: \(customProjectCount)")
        #endif
        
        // 1. 专业版用户无限制
        if storeManager.isPremium { return true }
        // 2. 免费版最多3个自定义项目
        return customProjectCount < 3
    }
    
    /// 自定义项目数量（排除"日常"默认项目）
    private var customProjectCount: Int {
        let activeCustom = store.activeProjects.filter { !$0.isActiveProject }.count
        return activeCustom + store.archivedProjects.count
    }
    
    var body: some View {
        NavigationView {
            ScrollView {

                VStack(spacing: 24) {
                    // MARK: 项目名称

                    VStack(alignment: .leading, spacing: 10) {
                        Text("项目名称").sectionTitle()
                        TextField("例如：新疆之旅、海景房装修...", text: $name)
                            .textFieldStyle()
                            .focused($isAnyFieldFocused)
                    }
                    
                    // MARK: 项目描述
                    VStack(alignment: .leading, spacing: 10) {
                        Text("项目描述（选填）").sectionTitle()
                        TextField("简单介绍一下这个项目...", text: $desc)
                            .textFieldStyle()
                            .focused($isAnyFieldFocused)
                    }
                    
                    // MARK: 预算
                    VStack(alignment: .leading, spacing: 10) {
                        Text("预算金额（选填，0=不限预算）").sectionTitle()
                        HStack {
                            Text("¥")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color.App.darkGreen)
                            TextField("0", text: $budgetText)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 18, weight: .bold))
                                .focused($isAnyFieldFocused)
                        }
                        .padding(16)
                        .background(Color.App.tabBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    
                    // MARK: 图标选择
                    VStack(alignment: .leading, spacing: 20) {
                        Text("选择图标").sectionTitle()
                        ForEach(CategoryIconLibrary.grouped, id: \.name) { group in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(group.name)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 4)
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                                    ForEach(group.icons, id: \.self) { icon in
                                        Button(action: {
                                            selectedIcon = icon
                                        }) {
                                            Circle()
                                                .fill(Color(hex: selectedColor).opacity(0.55))
                                                .frame(width: 56, height: 56)
                                                .overlay(
                                                    Image(systemName: icon)
                                                        .font(.system(size: 22))
                                                        .foregroundColor(Color(hex: progressColorPair(for: selectedColor).end))
                                                )
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.App.darkGreen, lineWidth: selectedIcon == icon ? 3 : 0)
                                                )
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // MARK: 颜色选择
                    VStack(alignment: .leading, spacing: 12) {
                        Text("选择颜色").sectionTitle()
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                            ForEach(Color.App.Morandi.allHexes, id: \.self) { hex in
                                Button(action: {
                                    selectedColor = hex
                                }) {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 56, height: 56)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.App.darkGreen, lineWidth: selectedColor == hex ? 3 : 0)
                                                .padding(2)
                                        )
                                }
                            }
                        }
                    }
                    
                    // MARK: 预览
                    VStack(alignment: .leading, spacing: 10) {
                        Text("预览").sectionTitle()
                        HStack(spacing: 14) {
                            Circle()
                                .fill(Color(hex: selectedColor).opacity(0.55))
                                .frame(width: 52, height: 52)
                                .overlay(
                                    Image(systemName: selectedIcon)
                                        .foregroundColor(Color(hex: progressColorPair(for: selectedColor).end))
                                        .font(.system(size: 22))
                                )
                            VStack(alignment: .leading, spacing: 4) {
                                Text(name.isEmpty ? "项目名称" : name)
                                    .font(.system(size: 18, weight: .heavy))
                                    .foregroundColor(name.isEmpty ? .gray : Color.App.textBlack)
                                if !desc.isEmpty {
                                    Text(desc)
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.App.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
                    }
                    
                    Spacer().frame(height: 20)
                }
                .padding(24)
            }
            .scrollDismissesKeyboard(.immediately)
            .onTapGesture { isAnyFieldFocused = false }
            .background(Color.App.backgroundGray.ignoresSafeArea())
            .navigationTitle("新建项目")
            .navigationBarTitleDisplayMode(.inline)
            .alert("升级到专业版", isPresented: $showUpgradeAlert) {
                Button("取消", role: .cancel) { }
                Button("查看订阅方案") {
                    showPaywall = true
                }
            } message: {
                Text("免费版最多可创建 3 个项目。升级到专业版即可解锁无限项目，还有更多高级功能等你探索！")
            }
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallView()
                    .environmentObject(storeManager)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        
                        if canCreateProject {
                            let budget = Double(budgetText) ?? 0
                            store.addProject(name: name, icon: selectedIcon, colorHex: selectedColor,
                                            desc: desc, budget: budget)
                            
                            AnalyticsManager.shared.trackEvent(
                                eventId: "project_create_success",
                                eventName: "成功创建项目",
                                params: [
                                    "has_budget": budget > 0,
                                    "icon_selected": selectedIcon
                                ]
                            )
                            
                            presentationMode.wrappedValue.dismiss()
                        } else {
                            showUpgradeAlert = true
                        }
                    }
                    .font(.system(size: 16, weight: .bold))
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - 便捷 View Modifier 扩展
extension View {
    func textFieldStyle() -> some View {
        self
            .padding(16)
            .background(Color.App.tabBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .font(.system(size: 16))
    }
}

extension Text {
    func sectionTitle() -> some View {
        self
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(Color.App.textBlack.opacity(0.7))
    }
}

#Preview {
    NewProjectView()
        .environmentObject(AppStore(modelContext: try! ModelContainer(for: Project.self, Transaction.self, Category.self, ChatHistory.self, MemoryRule.self).mainContext))
}
