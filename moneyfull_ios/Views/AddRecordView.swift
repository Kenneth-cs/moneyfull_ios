import SwiftUI
import SwiftData

struct AddRecordView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var store: AppStore
    
    @State private var type: TransactionType = .expense
    @State private var amount: String = ""
    @State private var selectedCategory: Category? = nil
    @State private var selectedProject: Project? = nil
    @State private var note: String = ""
    @State private var date: Date = Date()
    @State private var showDatePicker = false
    @State private var showProjectPicker = false
    @State private var showQuickAddCategory = false
    @State private var showKeypad = true  // 控制数字键盘显示/收起
    @State private var selectedCategoryTab = "常用"  // 当前选中的分类 Tab
    @FocusState private var isNoteFocused: Bool
    
    // 触觉反馈生成器
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    private let successFeedback = UINotificationFeedbackGenerator()
    
    // 显示金额（有值则显示，否则显示"0"）
    private var displayAmount: String { amount.isEmpty ? "0" : amount }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: Header
            HStack {
                Button(action: {
                    AnalyticsManager.shared.trackEvent(eventId: "record_cancel", eventName: "取消记账", params: ["has_input_amount": !amount.isEmpty])
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color.App.textBlack)
                        .frame(width: 40, height: 40)
                }
                Spacer()
                Text("记一笔")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(Color.App.textBlack)
                Spacer()
                Button(action: handleSave) {
                    Text("完成")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(amount.isEmpty ? Color.gray : Color.App.darkGreen)
                        .clipShape(Capsule())
                }
                .disabled(amount.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // 点 ScrollView 空白区域可收起键盘
                    Color.clear.frame(height: 1)
                        .contentShape(Rectangle())
                        .onTapGesture { showKeypad = false }
                    // MARK: 收支切换
                    HStack(spacing: 0) {
                        typeButton(label: "支出", t: .expense)
                        typeButton(label: "收入", t: .income)
                    }
                    .padding(4)
                    .frame(width: 200)
                    .background(Color.App.tabBackground)
                    .clipShape(Capsule())
                    
                    // MARK: 金额展示区（包含日期选择）
                    ZStack(alignment: .topLeading) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 40)
                                .fill(Color.App.amountBg)
                            
                            VStack(spacing: 8) {
                                Text("输入金额")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(hex: "#484A07").opacity(0.6))
                                    .kerning(2)
                                
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("¥")
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(Color(hex: "#1C1D00"))
                                Text(displayAmount)
                                        .font(.system(size: 56, weight: .black))
                                        .foregroundColor(Color(hex: "#1C1D00"))
                                        .minimumScaleFactor(0.5)
                                        .lineLimit(1)
                                    // 键盘收起时不显示光标
                                    if showKeypad { BlinkingCursor() }
                                }
                            }
                            .padding(.vertical, 28)
                        }
                        
                        // MARK: 日期选择（浓缩悬浮版）
                        Button(action: { showDatePicker = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 12))
                                Text({
                                    let f = DateFormatter()
                                    f.dateFormat = "M月d日"
                                    return f.string(from: date)
                                }())
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(Color(hex: "#1C1D00").opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.6))
                            .clipShape(Capsule())
                        }
                        .padding(16)
                    }
                    .padding(.horizontal, 24)
                    // 点击金额区展开键盘
                    .onTapGesture { showKeypad = true }
                    
                    // MARK: 归属项目选择（横向卡片）
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("归属项目")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color.App.textBlack)
                            Spacer()
                            Button(action: { showProjectPicker = true }) {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(store.activeProjects) { project in
                                    let isSelected = selectedProject?.id == project.id
                                    Button(action: {
                                        impactFeedback.impactOccurred()
                                        selectedProject = project
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: project.icon)
                                                .font(.system(size: 14))
                                                .foregroundColor(Color(hex: project.colorHex))
                                            Text(project.name)
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(isSelected ? Color.App.textBlack : Color.gray)
                                                .lineLimit(1)
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(
                                            Capsule()
                                                .fill(isSelected ? Color(hex: project.colorHex).opacity(0.3) : Color.App.tabBackground)
                                        )
                                        .overlay(
                                            Capsule()
                                                .strokeBorder(isSelected ? Color.App.darkGreen : Color.clear, lineWidth: 2)
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                    
                    // MARK: 分类选择
                    CategorySelectionView(
                        selectedCategory: $selectedCategory,
                        type: type,
                        categories: store.categories,
                        onAddTapped: {
                            showQuickAddCategory = true
                        },
                        selectedTab: $selectedCategoryTab
                    )
                    
                    // MARK: 备注输入
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: "#E2E2E2"))
                            .frame(width: 40, height: 40)
                            .overlay(Image(systemName: "pencil").foregroundColor(.gray))
                        TextField("添加备注...", text: $note)
                            .font(.system(size: 14, weight: .medium))
                            .focused($isNoteFocused)
                    }
                    .padding(16)
                    .background(Color.App.tabBackground)
                    .clipShape(Capsule())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { showKeypad = false }
            .simultaneousGesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .local)
                    .onChanged { value in
                        let verticalAmount = abs(value.translation.height)
                        if verticalAmount > 10 {
                            showKeypad = false
                        }
                    }
            )
            
            // MARK: 数字键盘面板（可收起/展开）
            VStack(spacing: 0) {
                // 顶部收起/展开把手
                Button(action: { showKeypad.toggle() }) {
                    HStack(spacing: 6) {
                        Image(systemName: showKeypad ? "chevron.down" : "keyboard")
                            .font(.system(size: 12, weight: .bold))
                        Text(showKeypad ? "收起键盘" : "展开键盘")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(Color.App.darkGreen.opacity(0.7))
                    .padding(.vertical, 10)
                }
                
                if showKeypad {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            KeyButton(label: "1") { handleKey("1") }
                            KeyButton(label: "2") { handleKey("2") }
                            KeyButton(label: "3") { handleKey("3") }
                            KeyButton(label: "+") { handleKey("+") }
                        }
                        HStack(spacing: 12) {
                            KeyButton(label: "4") { handleKey("4") }
                            KeyButton(label: "5") { handleKey("5") }
                            KeyButton(label: "6") { handleKey("6") }
                            KeyButton(label: "-") { handleKey("-") }
                        }
                        HStack(spacing: 12) {
                            KeyButton(label: "7") { handleKey("7") }
                            KeyButton(label: "8") { handleKey("8") }
                            KeyButton(label: "9") { handleKey("9") }
                            KeyButton(label: ".") { handleKey(".") }
                        }
                        HStack(spacing: 12) {
                            KeyButton(icon: "delete.left.fill") { handleKey("del") }
                            KeyButton(label: "0") { handleKey("0") }
                            Button(action: { showKeypad = false }) {
                                Text("确认")
                                    .font(.system(size: 18, weight: .heavy))
                                    .foregroundColor(Color.App.darkGreen)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(Color.App.primaryGreen)
                                    .clipShape(RoundedRectangle(cornerRadius: 24))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showKeypad)
            .background(
                Color.App.cardBackground
                    .clipShape(RoundedRectangle(cornerRadius: 40))
                    .shadow(color: Color.black.opacity(0.05), radius: 20, x: 0, y: -10)
            )
        }
        .background(Color.App.backgroundGray.ignoresSafeArea())
        // 项目选择弹窗
        .sheet(isPresented: $showProjectPicker) {
            ProjectPickerView(selected: $selectedProject, projects: store.activeProjects)
        }
        // 日期选择弹窗
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(date: $date)
        }
        // 快速新增分类
        .sheet(isPresented: $showQuickAddCategory) {
            QuickAddCategorySheet(
                selectedTab: selectedCategoryTab,
                transactionType: type == .expense ? "expense" : "income",
                categories: store.categories
            ) { name, icon, colorHex, groupName in
                store.addCategory(name: name, icon: icon, colorHex: colorHex, groupName: groupName, transactionType: type == .expense ? "expense" : "income")
                if let newCat = store.categories.last {
                    selectedCategory = newCat
                }
            }
        }
        .onAppear {
            if selectedProject == nil {
                selectedProject = store.activeProjects.first
            }
            if selectedCategory == nil {
                selectedCategory = store.categories.first
            }
        }
        .onChange(of: isNoteFocused) { _, newValue in
            if newValue { showKeypad = false }
        }
        .onChange(of: showKeypad) { _, newValue in
            if newValue { isNoteFocused = false }
        }
    }
    
    // MARK: - 收支切换按钮
    @ViewBuilder
    private func typeButton(label: String, t: TransactionType) -> some View {
        Button(action: {
            impactFeedback.impactOccurred()
            type = t
        }) {
            Text(label)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(type == t ? Color.App.textBlack : Color.gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(type == t ? Color.App.cardBackground : Color.clear)
                .clipShape(Capsule())
                .shadow(color: type == t ? Color.black.opacity(0.05) : Color.clear, radius: 2, x: 0, y: 1)
        }
    }
    
    // MARK: - 键盘处理
    private func handleKey(_ key: String) {
        impactFeedback.impactOccurred()
        switch key {
        case "del":
            if !amount.isEmpty { amount.removeLast() }
        case ".":
            if !amount.contains(".") { amount += key }
        default:
            if let dotIndex = amount.firstIndex(of: ".") {
                let decimals = amount.distance(from: amount.index(after: dotIndex), to: amount.endIndex)
                if decimals >= 2 { return }
            }
            if amount.count < 10 { amount += key }
        }
        if let val = Double(amount), val > 1000 {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
    
    // MARK: - 保存账单
    private func handleSave() {
        guard let project = selectedProject,
              let category = selectedCategory,
              let amountValue = Double(amount), amountValue > 0 else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        
        store.addTransaction(
            to: project,
            amount: amountValue,
            type: type,
            categoryName: category.name,
            categoryIcon: category.icon,
            categoryColorHex: category.colorHex,
            note: note,
            date: date
        )
        
        // 保存记忆规则
        if !note.isEmpty {
            try? ContextManager.shared.saveMemoryRule(
                keyword: note,
                categoryName: category.name,
                projectName: project.name
            )
        }
        
        // 更新分类使用频率和最后使用时间
        category.useCount += 1
        category.lastUsedAt = Date()
        try? category.modelContext?.save()
        
        let amountLevel: String
        if amountValue < 100 { amountLevel = "level_1_under100" }
        else if amountValue < 500 { amountLevel = "level_2_100_500" }
        else if amountValue < 2000 { amountLevel = "level_3_500_2000" }
        else { amountLevel = "level_4_over2000" }
        
        AnalyticsManager.shared.trackEvent(
            eventId: "record_submit_success",
            eventName: "记账成功",
            params: [
                "type": type == .expense ? "expense" : "income",
                "category": category.name,
                "is_custom_project": project.name != "日常收支",
                "amount_level": amountLevel
            ]
        )
        
        successFeedback.notificationOccurred(.success)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - 分类 Item 组件
struct CategoryItem: View {
    let name: String
    let icon: String
    let colorHex: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: colorHex))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 22))
                            .foregroundColor(Color.App.textBlack.opacity(0.7))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.App.darkGreen, lineWidth: isSelected ? 3 : 0)
                    )
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3), value: isSelected)
                
                Text(name)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? Color.App.darkGreen : Color.App.textBlack.opacity(0.7))
            }
        }
    }
}

// MARK: - 键盘按钮组件
struct KeyButton: View {
    var label: String? = nil
    var icon: String? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Group {
                if let label = label {
                    Text(label)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color.App.textBlack)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(Color.App.textBlack)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.App.tabBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
}

// MARK: - 光标闪烁动画
struct BlinkingCursor: View {
    @State private var visible = true
    var body: some View {
        Rectangle()
            .fill(Color(hex: "#1C1D00"))
            .frame(width: 3, height: 44)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
                    visible.toggle()
                }
            }
    }
}

// MARK: - 项目选择弹窗
struct ProjectPickerView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selected: Project?
    let projects: [Project]
    
    var body: some View {
        NavigationView {
            List(projects) { project in
                Button(action: {
                    selected = project
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(Color(hex: project.colorHex).opacity(0.3))
                            .frame(width: 44, height: 44)
                            .overlay(
                                AppIconView(name: project.icon, size: 20,
                                            color: Color(hex: project.colorHex))
                            )
                        Text(project.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color.App.textBlack)
                        Spacer()
                        if selected?.id == project.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color.App.darkGreen)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("选择归属项目")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - 日期选择弹窗
struct DatePickerSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var date: Date
    
    var body: some View {
        NavigationView {
            DatePicker("选择日期", selection: $date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .padding()
                .navigationTitle("选择日期")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("确定") { presentationMode.wrappedValue.dismiss() }
                    }
                }
        }
    }
}

// MARK: - 快速新增分类 Sheet
struct QuickAddCategorySheet: View {
    @Environment(\.presentationMode) var presentationMode
    let selectedTab: String
    let transactionType: String
    let categories: [Category]
    let onSave: (String, String, String, String) -> Void
    
    @State private var name = ""
    @State private var selectedIcon = "tag.fill"
    @State private var selectedColor = "#A8E0C2"
    @State private var selectedGroupName: String = ""
    @State private var showCustomGroupInput = false
    @State private var customGroupName = ""
    
    private let iconOptions = CategoryIconLibrary.all
    
    // 预设的核心分组（按优先级排序）
    private let coreGroups = ["吃喝", "居家", "出行", "娱乐", "成长", "人情", "其他"]
    private let incomeCoreGroups = ["工资", "额外", "临时", "其他"]
    
    // 动态获取所有已存在的分组名
    private var existingGroupNames: [String] {
        let allGroups = Set(categories.compactMap { cat -> String? in
            if transactionType == "income" && !cat.incomeGroupName.isEmpty {
                return cat.incomeGroupName
            }
            return cat.groupName.isEmpty ? nil : cat.groupName
        })
        return Array(allGroups).sorted()
    }
    
    // 获取当前类型下的所有可用分组（核心 + 动态）
    private var availableGroups: [String] {
        let core = transactionType == "income" ? incomeCoreGroups : coreGroups
        let dynamic = existingGroupNames.filter { !core.contains($0) }
        return core + dynamic.sorted()
    }
    
    init(selectedTab: String, transactionType: String, categories: [Category], onSave: @escaping (String, String, String, String) -> Void) {
        self.selectedTab = selectedTab
        self.transactionType = transactionType
        self.categories = categories
        self.onSave = onSave
        
        // 计算默认选中的分组
        let defaultGroup: String
        if selectedTab == "常用" || selectedTab == "全部" {
            defaultGroup = transactionType == "income" ? "工资" : "吃喝"
        } else {
            defaultGroup = selectedTab
        }
        _selectedGroupName = State(initialValue: defaultGroup)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("分类名称")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.gray)
                        TextField("输入分类名称", text: $name)
                            .padding(14)
                            .background(Color.App.tabBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .font(.system(size: 15))
                    }
                    
                    // 所属分组选择
                    VStack(alignment: .leading, spacing: 10) {
                        Text("所属分组")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.gray)
                        
                        if showCustomGroupInput {
                            HStack {
                                TextField("输入新分组名称", text: $customGroupName)
                                    .padding(14)
                                    .background(Color.App.tabBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .font(.system(size: 15))
                                
                                Button(action: {
                                    showCustomGroupInput = false
                                    customGroupName = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 20))
                                }
                            }
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(availableGroups, id: \.self) { group in
                                        Button(action: {
                                            selectedGroupName = group
                                        }) {
                                            Text(group)
                                                .font(.system(size: 14, weight: selectedGroupName == group ? .bold : .medium))
                                                .foregroundColor(selectedGroupName == group ? Color.App.darkGreen : .gray)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(selectedGroupName == group ? Color.App.primaryGreen.opacity(0.3) : Color.App.tabBackground)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    
                                    // 自定义新分组按钮
                                    Button(action: {
                                        showCustomGroupInput = true
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "plus")
                                                .font(.system(size: 12))
                                            Text("自定义")
                                                .font(.system(size: 14, weight: .medium))
                                        }
                                        .foregroundColor(Color.App.darkGreen)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Color.App.primaryGreen.opacity(0.2))
                                        .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("图标")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.gray)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                            ForEach(iconOptions, id: \.self) { icon in
                                Button(action: { selectedIcon = icon }) {
                                    Image(systemName: icon)
                                        .font(.system(size: 18))
                                        .foregroundColor(selectedIcon == icon ? Color.App.darkGreen : .gray)
                                        .frame(width: 40, height: 40)
                                        .background(selectedIcon == icon ? Color.App.primaryGreen.opacity(0.3) : Color.App.tabBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("颜色")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.gray)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                            ForEach(Color.App.morandiColorOptions, id: \.self) { color in
                                Button(action: { selectedColor = color }) {
                                    Circle()
                                        .fill(Color(hex: color))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.App.darkGreen, lineWidth: selectedColor == color ? 2.5 : 0)
                                                .padding(2)
                                        )
                                }
                            }
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: selectedColor))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: selectedIcon)
                                    .foregroundColor(Color.App.textBlack.opacity(0.7))
                                    .font(.system(size: 18))
                            )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(name.isEmpty ? "分类名称" : name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(name.isEmpty ? .gray : Color.App.textBlack)
                            Text("分组: \(showCustomGroupInput ? (customGroupName.isEmpty ? "新分组" : customGroupName) : selectedGroupName)")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(Color.App.tabBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    
                    Spacer().frame(height: 20)
                }
                .padding(20)
            }
            .background(Color.App.backgroundGray.ignoresSafeArea())
            .navigationTitle("快速新增分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        let finalGroupName = showCustomGroupInput ? customGroupName.trimmingCharacters(in: .whitespaces) : selectedGroupName
                        onSave(trimmed, selectedIcon, selectedColor, finalGroupName)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 16, weight: .bold))
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    AddRecordView()
        .environmentObject(AppStore(modelContext: try! ModelContainer(for: Project.self, Transaction.self, Category.self, ChatHistory.self, MemoryRule.self).mainContext))
}
