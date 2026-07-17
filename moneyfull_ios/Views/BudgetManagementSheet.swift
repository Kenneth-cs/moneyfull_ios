import SwiftUI

/// 预算分类管理 Sheet：增删改分类 + 周期 + 预警
struct BudgetManagementSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var storeManager: StoreManager

    let project: Project
    var onShowPaywall: () -> Void = {}

    @State private var showAddForm = false
    @State private var editingItem: BudgetItem? = nil
    @State private var showPaywall = false

    // 新增表单
    @State private var newName = ""
    @State private var newAmountText = ""
    @State private var newIcon = "tag.fill"
    @State private var newColorHex = "#A8E0C2"
    @FocusState private var isInputFocused: Bool
    @State private var isEditingBudget = false
    @State private var editBudgetText = ""
    @State private var isGeneratingAI = false

    private let budgetIcons = [
        "tag.fill", "car.fill", "fork.knife", "house.fill",
        "bag.fill", "ticket.fill", "airplane", "desktopcomputer",
        "cart.fill", "tshirt.fill", "sofa.fill", "tv.fill",
        "bolt.fill", "hammer.fill", "gamecontroller.fill", "film.fill",
        "figure.run", "cross.case.fill", "book.fill", "person.3.fill",
        "gift.fill", "chart.line.uptrend.xyaxis", "phone.fill", "pawprint.fill"
    ]

    private var items: [BudgetItem] { project.budgetItems ?? [] }
    private var totalBudget: Double { project.budget }
    private var allocated: Double { items.reduce(0) { $0 + $1.amount } }
    private var unallocated: Double { totalBudget - allocated }

    var body: some View {
        List {
            // MARK: 汇总
            Section {
                Button(action: {
                    editBudgetText = totalBudget > 0 ? "\(Int(totalBudget))" : ""
                    isEditingBudget = true
                    isInputFocused = true
                }) {
                    HStack {
                        Label("总预算", systemImage: "dollarsign.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.App.darkGreen)
                        Spacer()
                        if isEditingBudget {
                            HStack(spacing: 2) {
                                Text("¥").font(.system(size: 16, weight: .heavy))
                                    .foregroundColor(Color.App.darkGreen)
                                TextField("设置总预算", text: $editBudgetText)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 16, weight: .heavy))
                                    .frame(width: 80)
                                    .multilineTextAlignment(.trailing)
                                    .focused($isInputFocused)
                                    .onChange(of: isInputFocused) { _, focused in
                                        if !focused {
                                            saveBudget()
                                        }
                                    }
                            }
                        } else {
                            HStack(spacing: 4) {
                                Text("¥\(Int(totalBudget))")
                                    .font(.system(size: 16, weight: .heavy))
                                    .foregroundColor(Color.App.textBlack)
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.App.darkGreen.opacity(0.6))
                            }
                        }
                    }
                }
                .buttonStyle(.plain)

                HStack {
                    Label("已分配", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("¥\(Int(allocated))")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.App.textBlack)
                }
                HStack {
                    Label(unallocated >= 0 ? "未分配" : "超出预算",
                          systemImage: unallocated >= 0 ? "minus.circle" : "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(unallocated >= 0 ? Color(hex: "#FFA500") : Color.App.redExpense)
                    Spacer()
                    Text("¥\(Int(abs(unallocated)))")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(unallocated >= 0 ? Color(hex: "#FFA500") : Color.App.redExpense)
                }
            } header: { Text("预算汇总") }

            // MARK: 分类列表
            Section {
                if items.isEmpty {
                    VStack(spacing: 12) {
                        Text("还没有预算分类")
                            .font(.system(size: 14)).foregroundColor(.gray)
                        
                        HStack(spacing: 12) {
                            // AI 生成按钮
                            Button {
                                if storeManager.isPremium {
                                    generateAIBudget()
                                } else {
                                    showPaywall = true
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    if isGeneratingAI {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .tint(.white)
                                    } else {
                                        Image(systemName: storeManager.isPremium ? "sparkles" : "lock.fill")
                                            .font(.system(size: 12, weight: .bold))
                                    }
                                    Text(isGeneratingAI ? "规划中..." : (storeManager.isPremium ? "小满帮你规划" : "小满帮你规划  Pro"))
                                        .font(.system(size: 13, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16).padding(.vertical, 9)
                                .background(storeManager.isPremium ? Color.App.darkGreen : Color.gray.opacity(0.5))
                                .clipShape(Capsule())
                            }
                            .disabled(isGeneratingAI)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(items) { item in
                        BudgetItemEditRow(
                            item: item,
                            onUpdate: { newAmount in
                                store.updateBudgetItem(item, amount: newAmount)
                            },
                            onDelete: {
                                withAnimation {
                                    store.deleteBudgetItem(item)
                                }
                            },
                            isInputFocused: $isInputFocused
                        )
                    }
                }
                // 添加按钮行（免费用户最多3个分类）
                Button {
                    if !storeManager.isPremium && items.count >= 3 {
                        showPaywall = true
                    } else {
                        isInputFocused = false
                        showAddForm = true
                        newName = ""; newAmountText = ""; newIcon = "tag.fill"; newColorHex = "#A8E0C2"
                    }
                } label: {
                    HStack {
                        Label("添加分类", systemImage: "plus.circle.fill")
                        if !storeManager.isPremium && items.count >= 3 {
                            Text("（Pro）")
                                .font(.system(size: 11, weight: .bold))
                        }
                    }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.App.darkGreen)
                }
            } header: { Text("预算分类") }

            // 内联新增表单
            if showAddForm {
                addFormSection
            }

            // MARK: 预算周期
            Section {
                ForEach(BudgetCycle.allCases) { cycle in
                    Button {
                        withAnimation {
                            project.budgetCycle = cycle.rawValue
                            store.updateProject(project, name: project.name, icon: project.icon,
                                               colorHex: project.colorHex, desc: project.desc,
                                               budget: project.budget, budgetCycle: cycle.rawValue)
                        }
                    } label: {
                        HStack {
                            Image(systemName: project.budgetCycle == cycle.rawValue ? "largecircle.fill.circle" : "circle")
                                .foregroundColor(project.budgetCycle == cycle.rawValue ? Color.App.darkGreen : .gray)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cycle.label)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color.App.textBlack)
                                Text(cycle.hint)
                                    .font(.system(size: 11)).foregroundColor(.gray)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: { Text("预算周期") }

            // MARK: 预算预警（Pro）
            Section {
                if storeManager.isPremium {
                    Toggle(isOn: Binding(
                        get: { project.budgetAlertThreshold > 0 },
                        set: { newVal in
                            project.budgetAlertThreshold = newVal ? 0.8 : 0
                            BudgetAlertService.shared.resetProjectCheckpoint(for: project.id)
                        }
                    )) {
                        Label("开启预算预警", systemImage: "bell.badge.fill")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .tint(Color.App.darkGreen)
                    
                    if project.budgetAlertThreshold > 0 {
                        // 预警阈值
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("预警阈值")
                                    .font(.system(size: 13, weight: .medium))
                                Spacer()
                                Text("\(Int(project.budgetAlertThreshold * 100))%")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color.App.darkGreen)
                            }
                            
                            Slider(value: Binding(
                                get: { project.budgetAlertThreshold },
                                set: { 
                                    project.budgetAlertThreshold = $0
                                    BudgetAlertService.shared.resetProjectCheckpoint(for: project.id)
                                }
                            ), in: 0.5...1.0, step: 0.01)
                            .tint(Color.App.darkGreen)
                            
                            HStack {
                                Text("50%").font(.system(size: 10)).foregroundColor(.gray)
                                Spacer()
                                Text("100%").font(.system(size: 10)).foregroundColor(.gray)
                            }
                        }
                        
                        // 超出X%再次提醒
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("超出X%再次提醒")
                                    .font(.system(size: 13, weight: .medium))
                                Spacer()
                                Text("\(Int(project.budgetAlertStep * 100))%")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color.App.darkGreen)
                            }
                            
                            Slider(value: Binding(
                                get: { project.budgetAlertStep },
                                set: { project.budgetAlertStep = $0 }
                            ), in: 0.01...0.20, step: 0.01)
                            .tint(Color.App.darkGreen)
                            
                            HStack {
                                Text("1%").font(.system(size: 10)).foregroundColor(.gray)
                                Spacer()
                                Text("20%").font(.system(size: 10)).foregroundColor(.gray)
                            }
                        }
                    }
                } else {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onShowPaywall() }
                    } label: {
                        HStack {
                            Label("预算预警", systemImage: "bell.badge.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color.App.textBlack)
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "lock.fill").font(.system(size: 11))
                                Text("Pro").font(.system(size: 12, weight: .heavy))
                            }
                            .foregroundColor(Color.App.darkGreen)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color.App.primaryGreen.opacity(0.2))
                            .clipShape(Capsule())
                        }
                    }
                    .buttonStyle(.plain)
                    Text("开启后，分类或总预算超过设定阈值时 IP 小满会提醒你。")
                        .font(.system(size: 12)).foregroundColor(.gray)
                }
            } header: { Text("预算预警") }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("预算管理")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
        )
        .simultaneousGesture(
            DragGesture()
                .onChanged { _ in
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
        )
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .font(.system(size: 14, weight: .bold))
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(storeManager)
        }
    }

    private func saveBudget() {
        if let value = Double(editBudgetText), value >= 0 {
            store.updateProject(project, name: project.name, icon: project.icon,
                               colorHex: project.colorHex, desc: project.desc,
                               budget: value, budgetCycle: project.budgetCycle)
        }
        isEditingBudget = false
    }

    private func generateAIBudget() {
        isGeneratingAI = true
        Task {
            do {
                let items = try await LLMService.shared.generateBudgetBreakdown(
                    name: project.name,
                    desc: project.desc,
                    supplement: "",
                    totalBudget: project.budget > 0 ? project.budget : 5000,
                    mode: "生活"
                )
                await MainActor.run {
                    for (index, item) in items.enumerated() {
                        store.addBudgetItem(
                            to: project,
                            categoryName: item.categoryName,
                            categoryIcon: item.categoryIcon,
                            categoryColorHex: item.categoryColorHex,
                            amount: item.amount,
                            sortOrder: index,
                            alertThreshold: 0.8
                        )
                    }
                    isGeneratingAI = false
                }
            } catch {
                await MainActor.run {
                    isGeneratingAI = false
                }
            }
        }
    }

    // MARK: 新增表单（内联）
    private var addFormSection: some View {
        Section {
            TextField("分类名称（如：交通）", text: $newName)
                .font(.system(size: 15))
                .focused($isInputFocused)
                .onChange(of: newName) { _, newValue in
                    // 智能推荐图标和颜色
                    let suggestedIcon = suggestCategoryIcon(for: newValue)
                    let suggestedColor = suggestCategoryColor(for: newValue)
                    if suggestedIcon != "tag.fill" {
                        newIcon = suggestedIcon
                    }
                    if suggestedColor != "#A8E0C2" {
                        newColorHex = suggestedColor
                    }
                }
            HStack {
                Text("¥").foregroundColor(Color.App.darkGreen)
                TextField("预算金额", text: $newAmountText)
                    .keyboardType(.decimalPad)
                    .focused($isInputFocused)
            }
            // 图标选择（24个常用图标）
            VStack(alignment: .leading, spacing: 8) {
                Text("选择图标")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 8), spacing: 10) {
                    ForEach(budgetIcons, id: \.self) { icon in
                        Button {
                            isInputFocused = false
                            newIcon = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.system(size: 18))
                                .frame(width: 40, height: 40)
                                .background(newIcon == icon
                                            ? Color.App.primaryGreen.opacity(0.3)
                                            : Color.App.tabBackground)
                                .clipShape(Circle())
                                .foregroundColor(newIcon == icon ? Color.App.darkGreen : .gray)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, 4)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            HStack {
                Button("取消") {
                    isInputFocused = false
                    showAddForm = false
                }
                .foregroundColor(.gray).font(.system(size: 14, weight: .bold))
                Spacer()
                Button("添加") {
                    guard !newName.isEmpty, let amt = Double(newAmountText), amt > 0 else { return }
                    isInputFocused = false
                    withAnimation {
                        store.addBudgetItem(
                            to: project,
                            categoryName: newName,
                            categoryIcon: newIcon,
                            categoryColorHex: newColorHex,
                            amount: amt,
                            sortOrder: items.count
                        )
                        showAddForm = false
                    }
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color.App.darkGreen)
                .disabled(newName.isEmpty || Double(newAmountText) == nil)
            }
        } header: { Text("新增分类") }
    }
}

// MARK: - 分类编辑行
private struct BudgetItemEditRow: View {
    let item: BudgetItem
    var onUpdate: (Double) -> Void
    var onDelete: () -> Void

    @State private var amountText: String = ""
    @FocusState.Binding var isInputFocused: Bool

    // 智能获取图标和颜色
    private var displayIcon: String {
        getCategoryIcon(icon: item.categoryIcon, name: item.categoryName)
    }
    private var displayColor: String {
        getCategoryColor(color: item.categoryColorHex, name: item.categoryName)
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: displayColor).opacity(0.25))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: displayIcon)
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: displayColor))
                )
            Text(item.categoryName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.App.textBlack)
            Spacer()
            HStack(spacing: 2) {
                Text("¥").font(.system(size: 13)).foregroundColor(.gray)
                TextField("0", text: $amountText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 70)
                    .focused($isInputFocused)
                    .onAppear { amountText = "\(Int(item.amount))" }
                    .onChange(of: isInputFocused) { _, focused in
                        if !focused, let val = Double(amountText), val > 0 {
                            onUpdate(val)
                        }
                    }
            }
            // 删除按钮
            Button {
                isInputFocused = false
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(.red.opacity(0.8))
                    .frame(width: 32, height: 32)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
}