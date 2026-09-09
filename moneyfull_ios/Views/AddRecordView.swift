import SwiftUI
import SwiftData

struct AddRecordView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var store: AppStore
    
    // 预填参数
    var project: Project? = nil
    var sharedProject: JoinedSharedProject? = nil
    var prefilledAmount: String = ""
    var prefilledNote: String = ""
    var prefilledType: TransactionType? = nil
    
    // 统一项目类型，用于记一笔页面选择
    enum UnifiedProject: Equatable, Hashable {
        case local(Project)
        case shared(JoinedSharedProject)
        
        var id: String {
            switch self {
            case .local(let p): return p.id.uuidString
            case .shared(let p): return p.projectId
            }
        }
        
        var name: String {
            switch self {
            case .local(let p): return p.name
            case .shared(let p): return p.name
            }
        }
        
        var icon: String {
            switch self {
            case .local(let p): return p.icon
            case .shared(_): return "person.2.fill" // 共享项目默认图标
            }
        }
        
        var colorHex: String {
            switch self {
            case .local(let p): return p.colorHex
            case .shared(_): return "#4A90E2" // 共享项目默认蓝色
            }
        }
        
        var isShared: Bool {
            switch self {
            case .local(_): return false
            case .shared(_): return true
            }
        }
    }
    
    @State private var selectedUnifiedProject: UnifiedProject? = nil
    @State private var allProjects: [UnifiedProject] = []
    
    @State private var type: TransactionType = .expense
    @State private var amount: String = ""
    @State private var selectedCategory: Category? = nil
    @State private var note: String = ""
    @State private var date: Date = Date()
    @State private var showDatePicker = false
    @State private var showProjectPicker = false
    @State private var showQuickAddCategory = false
    @State private var showKeypad = true  // 控制数字键盘显示/收起
    @State private var selectedCategoryTab = "常用"  // 当前选中的分类 Tab
    @FocusState private var isNoteFocused: Bool
    
    // V7 新增：现金流类型覆盖
    @State private var showMoreOptions = false
    @State private var cashFlowType: String = "operating" // "operating" | "personal"
    
    // 共享记账字段（仅共享项目时显示）
    @State private var payerName: String = ""
    @State private var selectedParticipants: [String] = []
    @State private var splitMethod: String = "equal"
    @State private var showParticipantPicker = false
    
    // 表达式计算状态
    @State private var expression: String = ""  // 完整表达式，如 "100+50"
    @State private var hasOperator: Bool = false  // 是否已输入运算符
    @State private var calculatedResult: String = ""  // 计算结果
    @State private var showEquals: Bool = false  // 是否显示等号按钮
    
    // 触觉反馈生成器
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    private let successFeedback = UINotificationFeedbackGenerator()
    
    // 显示金额（有值则显示，否则显示"0"）
    private var displayAmount: String {
        if hasOperator && !expression.isEmpty {
            // 显示表达式 + 当前输入
            return expression + (amount.isEmpty ? "" : amount)
        }
        return amount.isEmpty ? "0" : amount
    }
    
    private var isSharedProject: Bool {
        return selectedUnifiedProject?.isShared ?? false
    }
    
    private var currentSharedProject: JoinedSharedProject? {
        if case .shared(let sp) = selectedUnifiedProject {
            return sp
        }
        return nil
    }
    
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
                                ForEach(allProjects, id: \.id) { project in
                                    let isSelected = selectedUnifiedProject?.id == project.id
                                    Button(action: {
                                        impactFeedback.impactOccurred()
                                        selectedUnifiedProject = project
                                        // 切换到搞钱模式项目时自动展开更多选项
                                        if type == .expense, case .local(let p) = project, p.projectMode == "earning" {
                                            showMoreOptions = true
                                        } else {
                                            showMoreOptions = false
                                        }
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
                    
                    // MARK: 共享项目额外字段（归属项目下方，分类上方）
                    if isSharedProject, let sp = currentSharedProject {
                        VStack(spacing: 0) {
                            payerRow(sp: sp)
                            Divider().padding(.leading, 24)
                            participantsRow(sp: sp)
                            Divider().padding(.leading, 24)
                            splitMethodRow()
                        }
                        .background(Color.App.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 24)
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
                    
                    // MARK: 更多选项（仅在搞钱模式项目下的支出录入中出现）
                    if case .local(let lp) = selectedUnifiedProject, type == .expense && lp.projectMode == "earning" {
                        VStack(spacing: 12) {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showMoreOptions.toggle()
                                }
                            }) {
                                HStack {
                                    Text("更多选项")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Image(systemName: showMoreOptions ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal, 24)
                            }
                            
                            if showMoreOptions {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("成本性质")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.gray)
                                    
                                    HStack(spacing: 12) {
                                        cashFlowTypeButton(label: "经营支出", type: "operating")
                                        cashFlowTypeButton(label: "个人支出", type: "personal")
                                    }
                                    
                                    Text("💡 已根据分类自动判断，通常无需修改")
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray.opacity(0.7))
                                }
                                .padding(16)
                                .background(Color.App.tabBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .padding(.horizontal, 24)
                            }
                        }
                        .padding(.bottom, 8)
                    } else {
                        Spacer().frame(height: 8)
                    }
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
                            KeyButton(label: "×") { handleKey("×") }
                        }
                        HStack(spacing: 12) {
                            KeyButton(label: ".") { handleKey(".") }
                            KeyButton(label: "0") { handleKey("0") }
                            KeyButton(label: "÷") { handleKey("÷") }
                            KeyButton(icon: "delete.left.fill") { handleKey("del") }
                        }
                        // 确认/等号按钮
                        Button(action: {
                            if showEquals {
                                calculateResult()
                            } else {
                                showKeypad = false
                            }
                        }) {
                            Text(showEquals ? "=" : "确认")
                                .font(.system(size: 18, weight: .heavy))
                                .foregroundColor(Color.App.darkGreen)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.App.primaryGreen)
                                .clipShape(RoundedRectangle(cornerRadius: 24))
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
            ProjectPickerView(selected: $selectedUnifiedProject, projects: allProjects)
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
        // 参与人选择
        .sheet(isPresented: $showParticipantPicker) {
            if let sp = currentSharedProject {
                ParticipantPickerSheet(members: sp.memberNames, selectedParticipants: $selectedParticipants)
            }
        }
        .onAppear {
            // 初始化项目列表
            var projects: [UnifiedProject] = []
            projects.append(contentsOf: store.activeProjects.map { .local($0) })
            projects.append(contentsOf: SharedProjectService.shared.joinedProjects.map { .shared($0) })
            allProjects = projects

            // 使用预填参数
            if let sp = sharedProject {
                selectedUnifiedProject = .shared(sp)
            } else if let project = project {
                selectedUnifiedProject = .local(project)
            } else if selectedUnifiedProject == nil {
                selectedUnifiedProject = allProjects.first
            }
            if !prefilledAmount.isEmpty {
                amount = prefilledAmount
            }
            if !prefilledNote.isEmpty {
                note = prefilledNote
            }
            if let prefilledType = prefilledType {
                type = prefilledType
            }
            if selectedCategory == nil {
                selectedCategory = store.categories.first
            }

            // 初始化共享项目字段：使用该项目绑定的昵称（不受全局昵称影响）
            if let sp = currentSharedProject {
                if payerName.isEmpty {
                    payerName = sp.participantName
                }
                if selectedParticipants.isEmpty {
                    selectedParticipants = sp.memberNames
                }
            }
        }
        .onChange(of: selectedUnifiedProject) { _, newProject in
            // 每次切换项目都强制重置付款人和参与人，避免旧项目数据残留
            if case .shared(let sp) = newProject {
                payerName = sp.participantName
                selectedParticipants = sp.memberNames   // 无条件覆盖
            } else {
                // 切回本地项目时清空共享专属字段
                payerName = ""
                selectedParticipants = []
            }
        }
        .onChange(of: selectedCategory) { _, newCat in
            // 分类切换时自动更新现金流类型
            if case .local(let lp) = selectedUnifiedProject, let cat = newCat, type == .expense && lp.projectMode == "earning" {
                cashFlowType = cat.isDirectCost ? "operating" : "personal"
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
            // 切换到收入时隐藏更多选项
            if t == .income { showMoreOptions = false }
            // 切换到支出且是搞钱模式时自动展开
            if case .local(let lp) = selectedUnifiedProject, t == .expense && lp.projectMode == "earning" { showMoreOptions = true }
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
    
    // MARK: - 付款人行
    @ViewBuilder
    private func payerRow(sp: JoinedSharedProject) -> some View {
        HStack {
            Text("付款人")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color.App.textBlack)
            Spacer()
            Menu {
                ForEach(sp.memberNames, id: \.self) { name in
                    Button(action: { payerName = name }) {
                        if (payerName.isEmpty ? sp.participantName : payerName) == name {
                            Label(name, systemImage: "checkmark")
                        } else {
                            Text(name)
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 22, height: 22)
                        .overlay(Image(systemName: "person.fill").font(.system(size: 10)).foregroundColor(.orange))
                    Text(payerName.isEmpty ? sp.participantName : payerName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right").font(.system(size: 11)).foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    // MARK: - 参与人行（可点击，弹出多选 sheet）
    @ViewBuilder
    private func participantsRow(sp: JoinedSharedProject) -> some View {
        Button(action: { showParticipantPicker = true }) {
            HStack {
                Text("参与人")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.App.textBlack)
                Spacer()
                HStack(spacing: 4) {
                    let isAll = selectedParticipants.isEmpty ||
                                Set(selectedParticipants) == Set(sp.memberNames)
                    Text(isAll
                         ? "全部成员 (\(sp.memberCount)人)"
                         : selectedParticipants.joined(separator: "、"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 分摊方式行（Menu 选择）
    @ViewBuilder
    private func splitMethodRow() -> some View {
        HStack {
            Text("分摊方式")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color.App.textBlack)
            Spacer()
            Menu {
                Button { splitMethod = "equal" } label: {
                    if splitMethod == "equal" { Label("平均分摊", systemImage: "checkmark") }
                    else { Text("平均分摊") }
                }
                Button { splitMethod = "payer_full" } label: {
                    if splitMethod == "payer_full" { Label("全由付款人", systemImage: "checkmark") }
                    else { Text("全由付款人") }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(splitMethod == "payer_full" ? "全由付款人" : "平均分摊")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    // MARK: - 现金流类型切换按钮
    @ViewBuilder
    private func cashFlowTypeButton(label: String, type: String) -> some View {
        Button(action: {
            impactFeedback.impactOccurred()
            cashFlowType = type
        }) {
            Text(label)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(cashFlowType == type ? Color.App.darkGreen : Color.gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(cashFlowType == type ? Color.App.primaryGreen.opacity(0.3) : Color.clear)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(cashFlowType == type ? Color.App.darkGreen : Color.clear, lineWidth: 1)
                )
        }
    }
    
    // MARK: - 键盘处理
    private func handleKey(_ key: String) {
        impactFeedback.impactOccurred()
        
        // 如果已有计算结果，按数字键重新开始
        if !calculatedResult.isEmpty && !showEquals {
            if "0123456789".contains(key) {
                amount = ""
                expression = ""
                calculatedResult = ""
                hasOperator = false
            }
        }
        
        switch key {
        case "del":
            if !amount.isEmpty {
                amount.removeLast()
                // 如果删除后没有数字了，清除运算符状态
                if amount.isEmpty {
                    hasOperator = false
                    showEquals = false
                    expression = ""
                }
            } else if hasOperator && !expression.isEmpty {
                // 如果没有数字但有运算符，删除运算符回到第一个数字
                amount = String(expression.dropLast())  // 移除运算符
                hasOperator = false
                showEquals = false
                expression = ""
            }
        case ".":
            if !amount.contains(".") { amount += key }
        case "+", "-", "×", "÷":
            // 如果已有运算符，先计算之前的结果
            if hasOperator && !amount.isEmpty {
                calculateResult()
            }
            // 如果已有运算符但没有新数字，只更新运算符
            if hasOperator && amount.isEmpty && !expression.isEmpty {
                expression = String(expression.dropLast()) + key
                return
            }
            // 设置运算符
            if !amount.isEmpty {
                expression = amount + key
                hasOperator = true
                showEquals = true
                amount = ""
            }
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
    
    // MARK: - 计算结果
    private func calculateResult() {
        guard !expression.isEmpty, !amount.isEmpty else { return }
        
        // 提取运算符和第一个数字
        let operatorChar: String
        let firstNumberStr: String
        
        if expression.hasSuffix("+") {
            operatorChar = "+"
            firstNumberStr = String(expression.dropLast())
        } else if expression.hasSuffix("-") {
            operatorChar = "-"
            firstNumberStr = String(expression.dropLast())
        } else if expression.hasSuffix("×") {
            operatorChar = "×"
            firstNumberStr = String(expression.dropLast())
        } else if expression.hasSuffix("÷") {
            operatorChar = "÷"
            firstNumberStr = String(expression.dropLast())
        } else {
            return
        }
        
        guard let firstNumber = Double(firstNumberStr),
              let secondNumber = Double(amount) else { return }
        
        var result: Double
        
        switch operatorChar {
        case "+":
            result = firstNumber + secondNumber
        case "-":
            result = firstNumber - secondNumber
        case "×":
            result = firstNumber * secondNumber
        case "÷":
            guard secondNumber != 0 else {
                // 除以0的错误处理
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }
            result = firstNumber / secondNumber
        default:
            return
        }
        
        // 格式化结果（保留最多2位小数）
        if result == result.rounded() {
            amount = String(Int(result))
        } else {
            amount = String(format: "%.2f", result)
            // 去除末尾的0
            while amount.hasSuffix("0") {
                amount = String(amount.dropLast())
            }
            if amount.hasSuffix(".") {
                amount = String(amount.dropLast())
            }
        }
        
        // 重置状态
        expression = ""
        hasOperator = false
        showEquals = false
        calculatedResult = amount
        
        // 成功反馈
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    // MARK: - 保存账单
    private func handleSave() {
        guard let unifiedProject = selectedUnifiedProject,
              let category = selectedCategory,
              let amountValue = Double(amount), amountValue > 0 else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        
        switch unifiedProject {
        case .local(let project):
            // 根据分类自动判断现金流类型（如果用户没有手动覆盖）
            let finalCashFlowType: String
            if type == .expense && project.projectMode == "earning" {
                // 如果用户没有展开更多选项，则根据分类自动判断
                if !showMoreOptions {
                    finalCashFlowType = category.isDirectCost ? "operating" : "personal"
                } else {
                    finalCashFlowType = cashFlowType
                }
            } else {
                finalCashFlowType = "operating" // 非搞钱模式或收入默认为经营
            }
            
            store.addTransaction(
                to: project,
                amount: amountValue,
                type: type,
                categoryName: category.name,
                categoryIcon: category.icon,
                categoryColorHex: category.colorHex,
                note: note,
                date: date,
                cashFlowType: finalCashFlowType
            )
            
            // 保存记忆规则
            if !note.isEmpty {
                try? ContextManager.shared.saveMemoryRule(
                    keyword: note,
                    categoryName: category.name,
                    projectName: project.name
                )
            }
            
        case .shared(let sp):
            // 保存到共享账本（fire-and-forget，成功后通知详情页刷新）
            Task {
                do {
                    let actualAmount = type == .expense ? -amountValue : amountValue
                    let finalPayer = payerName.isEmpty ? "我" : payerName
                    let isoDate = ISO8601DateFormatter().string(from: date)
                    let txDict: [String: Any] = [
                        "id": UUID().uuidString,
                        "amount": actualAmount,
                        "category": category.name,
                        "note": note,
                        "transactionAt": isoDate,
                        "payerName": finalPayer,
                        "participants": selectedParticipants,
                        "splitMethod": splitMethod
                    ]
                    _ = try await SharedProjectService.shared.writeTransactions(
                        inviteCode: sp.inviteCode,
                        transactions: [txDict]
                    )
                    // 写入成功：通知详情页刷新
                    NotificationCenter.default.post(
                        name: .sharedTransactionDidWrite,
                        object: nil,
                        userInfo: ["projectId": sp.projectId]
                    )
                } catch {
                    print("保存共享账单失败: \(error)")
                }
            }
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
                "is_custom_project": unifiedProject.name != "日常收支",
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
    @Binding var selected: AddRecordView.UnifiedProject?
    let projects: [AddRecordView.UnifiedProject]
    
    var body: some View {
        NavigationView {
            List(projects, id: \.id) { project in
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

// MARK: - 参与人多选 Sheet
struct ParticipantPickerSheet: View {
    let members: [String]
    @Binding var selectedParticipants: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(members, id: \.self) { member in
                Button(action: {
                    if selectedParticipants.contains(member) {
                        // 至少保留一人
                        if selectedParticipants.count > 1 {
                            selectedParticipants.removeAll { $0 == member }
                        }
                    } else {
                        selectedParticipants.append(member)
                    }
                }) {
                    HStack {
                        Circle()
                            .fill(Color(hex: "#E6F5EC"))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Text(String(member.prefix(1)))
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color(hex: "#2E8B57"))
                            )
                        Text(member)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: selectedParticipants.contains(member)
                              ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundColor(selectedParticipants.contains(member)
                                             ? Color(hex: "#2E8B57") : Color.gray.opacity(0.3))
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("选择参与人")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("全选") { selectedParticipants = members }
                        .foregroundColor(Color(hex: "#2E8B57"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .font(.system(size: 16, weight: .bold))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
