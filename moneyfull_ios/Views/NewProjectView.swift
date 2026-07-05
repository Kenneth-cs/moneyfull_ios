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

    // MARK: 新增：项目模式 & 预算规划
    @State private var projectMode: ProjectMode = .lifestyle
    @State private var uiBudgetItems: [BudgetItemUI] = []
    @State private var budgetSupplement: String = ""        // AI 生成前的补充说明
    @State private var isGeneratingBudget: Bool = false
    @State private var showBudgetManagement: Bool = false

    // MARK: 新增：预算周期
    @State private var budgetCycle: BudgetCycle = .project
    @State private var customCycleDays: Int = 30

    // MARK: 新增：预算预警（Plus）
    @State private var budgetAlertEnabled: Bool = false
    @State private var budgetAlertThreshold: Double = 0.8

    @FocusState private var isAnyFieldFocused: Bool

    private var totalBudget: Double { Double(budgetText) ?? 0 }
    private var allocatedBudget: Double { uiBudgetItems.reduce(0) { $0 + $1.amount } }
    private var unallocatedBudget: Double { totalBudget - allocatedBudget }

    private var aiSuggestion: String {
        guard !name.isEmpty else { return "" }
        let mode = suggestProjectMode(for: name, desc: desc)
        return "根据「\(name)」，建议选「\(mode.title)」"
    }
    
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
                    projectNameSection
                    projectDescSection
                    projectModeSection
                    budgetSection
                    if totalBudget > 0 { budgetPlanningSection }
                    previewSection
                    iconSection
                    colorSection
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
                Button("查看订阅方案") { showPaywall = true }
            } message: {
                Text("免费版最多可创建 3 个项目。升级到专业版即可解锁无限项目，还有更多高级功能等你探索！")
            }
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallView().environmentObject(storeManager)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { presentationMode.wrappedValue.dismiss() }
                        .font(.system(size: 16, weight: .medium))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        if canCreateProject {
                            let budget = Double(budgetText) ?? 0
                            let project = store.addProject(
                                name: name, icon: selectedIcon, colorHex: selectedColor,
                                desc: desc, budget: budget,
                                projectMode: projectMode.rawValue,
                                budgetCycle: budgetCycle.rawValue
                            )
                            for (index, item) in uiBudgetItems.enumerated() {
                                store.addBudgetItem(to: project, categoryName: item.categoryName,
                                                   categoryIcon: item.categoryIcon, categoryColorHex: item.categoryColorHex,
                                                   amount: item.amount, sortOrder: index, alertThreshold: item.alertThreshold)
                            }
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

// MARK: - 提取的子视图
extension NewProjectView {
    var projectNameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("项目名称").sectionTitle()
            TextField("例如：新疆之旅、海景房装修...", text: $name)
                .textFieldStyle()
                .focused($isAnyFieldFocused)
        }
    }

    var projectDescSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("项目描述（选填）").sectionTitle()
            TextField("简单介绍一下这个项目...", text: $desc)
                .textFieldStyle()
                .focused($isAnyFieldFocused)
        }
    }

    var projectModeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("项目模式").sectionTitle()
            HStack(spacing: 12) {
                ForEach(ProjectMode.allCases) { mode in
                    ProjectModeCard(mode: mode, isSelected: projectMode == mode)
                        .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { projectMode = mode } }
                }
            }
            if !aiSuggestion.isEmpty {
                Text(aiSuggestion).font(.system(size: 11)).foregroundColor(.gray).padding(.top, 2)
            }
        }
    }

    var budgetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("预算金额（选填，0=不限预算）").sectionTitle()
            HStack {
                Text("¥").font(.system(size: 18, weight: .bold)).foregroundColor(Color.App.darkGreen)
                TextField("0", text: $budgetText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 18, weight: .bold))
                    .focused($isAnyFieldFocused)
            }
            .padding(16)
            .background(Color.App.tabBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    var previewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("预览").sectionTitle()
            HStack(spacing: 14) {
                Circle()
                    .fill(Color(hex: selectedColor).opacity(0.55))
                    .frame(width: 52, height: 52)
                    .overlay(Image(systemName: selectedIcon)
                        .foregroundColor(Color(hex: progressColorPair(for: selectedColor).end))
                        .font(.system(size: 22)))
                VStack(alignment: .leading, spacing: 4) {
                    Text(name.isEmpty ? "项目名称" : name)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(name.isEmpty ? .gray : Color.App.textBlack)
                    if !desc.isEmpty {
                        Text(desc).font(.system(size: 12)).foregroundColor(.gray).lineLimit(1)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.App.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
        }
    }

    var iconSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("选择图标").sectionTitle()
            ForEach(CategoryIconLibrary.grouped, id: \.name) { group in
                VStack(alignment: .leading, spacing: 10) {
                    Text(group.name).font(.system(size: 13, weight: .bold)).foregroundColor(.gray).padding(.horizontal, 4)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                        ForEach(group.icons, id: \.self) { icon in
                            iconCell(icon: icon, selectedColor: selectedColor, isSelected: selectedIcon == icon)
                                .onTapGesture { selectedIcon = icon }
                        }
                    }
                }
            }
        }
    }

    var colorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择颜色").sectionTitle()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(Color.App.Morandi.allHexes, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 56, height: 56)
                        .overlay(Circle().stroke(Color.App.darkGreen, lineWidth: selectedColor == hex ? 3 : 0).padding(2))
                        .onTapGesture { selectedColor = hex }
                }
            }
        }
    }
}

// MARK: - 预算规划区块
extension NewProjectView {
    var budgetPlanningSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题行
            HStack {
                Text("预算规划").sectionTitle()
                Spacer()
                if !uiBudgetItems.isEmpty {
                    Button("管理分类 ›") { showBudgetManagement = true }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                }
            }

            // 已有分类时显示列表预览
            if !uiBudgetItems.isEmpty {
                VStack(spacing: 12) {
                    ForEach(uiBudgetItems.prefix(4)) { item in
                        BudgetProgressRow(item: item, showSpent: false)
                    }
                    if uiBudgetItems.count > 4 {
                        Text("还有 \(uiBudgetItems.count - 4) 个分类...")
                            .font(.system(size: 12)).foregroundColor(.gray)
                    }
                }
                // 已分配 / 未分配提示
                HStack {
                    Label("已分配 ¥\(Int(allocatedBudget))", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.App.darkGreen)
                    Spacer()
                    if unallocatedBudget > 0.01 {
                        Label("未分配 ¥\(Int(unallocatedBudget))", systemImage: "exclamationmark.circle")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: "#FFA500"))
                    } else if unallocatedBudget < -0.01 {
                        Label("超出 ¥\(Int(-unallocatedBudget))", systemImage: "xmark.circle")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.App.redExpense)
                    }
                }
                .padding(.top, 4)
            }

            // 操作按钮
            HStack(spacing: 12) {
                // AI 生成（Plus 锁定）
                Button {
                    if storeManager.isPremium {
                        generateAIBudget()
                    } else {
                        showPaywall = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isGeneratingBudget {
                            ProgressView().tint(.white).scaleEffect(0.8)
                        } else {
                            Image(systemName: storeManager.isPremium ? "sparkles" : "lock.fill")
                                .font(.system(size: 13, weight: .bold))
                        }
                        Text(storeManager.isPremium ? "AI 一键生成" : "AI 生成  Plus")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(storeManager.isPremium ? Color.App.darkGreen : Color.gray.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isGeneratingBudget)

                // 手动添加
                Button { showBudgetManagement = true } label: {
                    Text("手动添加")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.App.darkGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.App.primaryGreen.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.App.primaryGreen.opacity(0.4), lineWidth: 1)
                        )
                }
            }

            // AI 生成前补充（可选）
            if uiBudgetItems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("补充说明（可选，让 AI 生成更准确）")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    TextField("例如：两人同行，7天，自驾为主...", text: $budgetSupplement)
                        .font(.system(size: 14))
                        .padding(12)
                        .background(Color.App.tabBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .focused($isAnyFieldFocused)
                }
            }

            Divider()

            // 预算周期
            VStack(alignment: .leading, spacing: 10) {
                Text("预算周期").sectionTitle()
                ForEach(BudgetCycle.allCases) { cycle in
                    Button { budgetCycle = cycle } label: {
                        HStack(spacing: 10) {
                            Image(systemName: budgetCycle == cycle ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 18))
                                .foregroundColor(budgetCycle == cycle ? Color.App.darkGreen : .gray)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cycle.label)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color.App.textBlack)
                                Text(cycle.hint)
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    if cycle == .custom && budgetCycle == .custom {
                        HStack {
                            Spacer().frame(width: 28)
                            Text("每")
                                .font(.system(size: 14)).foregroundColor(.gray)
                            TextField("30", value: $customCycleDays, format: .number)
                                .keyboardType(.numberPad)
                                .font(.system(size: 14, weight: .bold))
                                .frame(width: 50)
                                .padding(.horizontal, 8).padding(.vertical, 6)
                                .background(Color.App.tabBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Text("天自动刷新")
                                .font(.system(size: 14)).foregroundColor(.gray)
                        }
                        .padding(.top, 4)
                    }
                }
            }

            Divider()

            // 预算预警（Plus）
            PlusLockedSection(
                isLocked: !storeManager.isPremium,
                title: "解锁预算预警",
                onUnlock: { showPaywall = true }
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "bell.badge.fill")
                            .foregroundColor(Color(hex: "#FFA500"))
                        Text("预算预警").sectionTitle()
                        Spacer()
                        Toggle("", isOn: $budgetAlertEnabled).labelsHidden()
                    }
                    if budgetAlertEnabled {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("总预算超过 \(Int(budgetAlertThreshold * 100))% 时提醒")
                                .font(.system(size: 13)).foregroundColor(.gray)
                            Slider(value: $budgetAlertThreshold, in: 0.5...1.0, step: 0.05)
                                .tint(Color.App.darkGreen)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
    }

    private func generateAIBudget() {
        isGeneratingBudget = true
        Task {
            do {
                let items = try await LLMService.shared.generateBudgetBreakdown(
                    name: name,
                    desc: desc,
                    supplement: budgetSupplement,
                    totalBudget: totalBudget,
                    mode: projectMode.title
                )
                await MainActor.run {
                    withAnimation {
                        uiBudgetItems = items
                        isGeneratingBudget = false
                    }
                }
            } catch {
                #if DEBUG
                print("AI预算生成失败: \(error)")
                #endif
                await MainActor.run {
                    isGeneratingBudget = false
                }
            }
        }
    }
}

// MARK: - 项目模式卡片
private struct ProjectModeCard: View {
    let mode: ProjectMode
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.system(size: 14, weight: .bold))
                Text(mode.title)
                    .font(.system(size: 15, weight: .heavy))
            }
            Text(mode.subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)
            Text(mode.description)
                .font(.system(size: 11))
                .foregroundColor(.gray)
        }
        .foregroundColor(isSelected ? Color.App.darkGreen : Color.App.textBlack)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(isSelected ? Color.App.primaryGreen.opacity(0.18) : Color.App.tabBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? Color.App.darkGreen : Color.clear, lineWidth: 1.5))
    }
}

// MARK: - 图标单元格
private struct iconCell: View {
    let icon: String
    let selectedColor: String
    let isSelected: Bool

    var body: some View {
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
                    .stroke(Color.App.darkGreen, lineWidth: isSelected ? 3 : 0)
            )
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
