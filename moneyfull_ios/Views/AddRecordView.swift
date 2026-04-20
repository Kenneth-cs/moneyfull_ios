import SwiftUI
import SwiftData

struct AddRecordView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var store: AppStore
    
    @State private var type: TransactionType = .expense
    @State private var amount: String = ""
    @State private var selectedCategory = categories[0]
    @State private var selectedProject: Project? = nil
    @State private var note: String = ""
    @State private var date: Date = Date()
    @State private var showDatePicker = false
    @State private var showProjectPicker = false
    @State private var showKeypad = true  // 控制数字键盘显示/收起
    
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
                        .background(amount.isEmpty ? Color.gray : Color(hex: "#546073"))
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
                    
                    // MARK: 金额展示区（点击可展开键盘）
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
                    .padding(.horizontal, 24)
                    // 点击金额区展开键盘
                    .onTapGesture { showKeypad = true }
                    
                    // MARK: 分类选择
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("分类")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color.App.textBlack)
                            Spacer()
                        }
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 20) {
                            ForEach(categories, id: \.name) { cat in
                                CategoryItem(cat: cat, isSelected: selectedCategory.name == cat.name) {
                                    impactFeedback.impactOccurred()
                                    selectedCategory = cat
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // MARK: 归属项目选择
                    Button(action: { showProjectPicker = true }) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(hex: "#E2E2E2"))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: selectedProject?.icon ?? "folder.fill")
                                        .foregroundColor(.gray)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("归属项目")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.gray)
                                    .kerning(1)
                                Text(selectedProject?.name ?? "请选择项目")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(selectedProject == nil ? .gray : Color.App.textBlack)
                            }
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.gray)
                                .font(.system(size: 14))
                        }
                        .padding(16)
                        .background(Color.App.tabBackground)
                        .clipShape(Capsule())
                        .padding(.horizontal, 24)
                    }
                    
                    // MARK: 备注输入
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: "#E2E2E2"))
                            .frame(width: 40, height: 40)
                            .overlay(Image(systemName: "pencil").foregroundColor(.gray))
                        TextField("添加备注...", text: $note)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding(16)
                    .background(Color.App.tabBackground)
                    .clipShape(Capsule())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                }
            }
            
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
                            KeyButton(icon: "calendar") { showDatePicker = true }
                        }
                        HStack(spacing: 12) {
                            KeyButton(label: "4") { handleKey("4") }
                            KeyButton(label: "5") { handleKey("5") }
                            KeyButton(label: "6") { handleKey("6") }
                            KeyButton(label: "+") { handleKey("+") }
                        }
                        HStack(spacing: 12) {
                            KeyButton(label: "7") { handleKey("7") }
                            KeyButton(label: "8") { handleKey("8") }
                            KeyButton(label: "9") { handleKey("9") }
                            KeyButton(label: "-") { handleKey("-") }
                        }
                        HStack(spacing: 12) {
                            KeyButton(label: ".") { handleKey(".") }
                            KeyButton(label: "0") { handleKey("0") }
                            KeyButton(icon: "delete.left.fill") { handleKey("del") }
                            // 「确认」仅收起键盘，不提交表单（顶部"完成"按钮才是提交）
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
                Color.white
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
        .onAppear {
            // 默认选中第一个项目（通常是日常收支）
            if selectedProject == nil {
                selectedProject = store.activeProjects.first
            }
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
                .background(type == t ? Color.white : Color.clear)
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
            // 不允许输入两个小数点
            if !amount.contains(".") { amount += key }
        default:
            // 限制总长度、小数点后最多2位
            if let dotIndex = amount.firstIndex(of: ".") {
                let decimals = amount.distance(from: amount.index(after: dotIndex), to: amount.endIndex)
                if decimals >= 2 { return }
            }
            if amount.count < 10 { amount += key }
        }
    }
    
    // MARK: - 保存账单
    private func handleSave() {
        guard let project = selectedProject,
              let amountValue = Double(amount), amountValue > 0 else {
            // 如果项目未选或金额为0，震动提示错误
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        
        store.addTransaction(
            to: project,
            amount: amountValue,
            type: type,
            categoryName: selectedCategory.name,
            categoryIcon: selectedCategory.icon,
            categoryColorHex: selectedCategory.colorHex,
            note: note,
            date: date
        )
        
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
                "category": selectedCategory.name,
                "is_custom_project": project.name != "日常收支",
                "amount_level": amountLevel
            ]
        )
        
        successFeedback.notificationOccurred(.success)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - 全局通用分类数据
struct CategoryInfo {
    let name: String
    let icon: String
    let colorHex: String
}

let categories: [CategoryInfo] = [
    CategoryInfo(name: "餐饮", icon: "fork.knife",       colorHex: "#A8E6CF"),
    CategoryInfo(name: "购物", icon: "bag.fill",         colorHex: "#FDD1B4"),
    CategoryInfo(name: "交通", icon: "car.fill",         colorHex: "#DCDE8D"),
    CategoryInfo(name: "居家", icon: "house.fill",       colorHex: "#DBEAFE"),
    CategoryInfo(name: "娱乐", icon: "gamecontroller.fill", colorHex: "#F3E8FF"),
    CategoryInfo(name: "医疗", icon: "heart.text.square.fill", colorHex: "#FCE7F3"),
    CategoryInfo(name: "教育", icon: "graduationcap.fill", colorHex: "#FFEDD5"),
    CategoryInfo(name: "其他", icon: "ellipsis.circle.fill", colorHex: "#EEEEEE"),
]

// MARK: - 分类 Item 组件
struct CategoryItem: View {
    let cat: CategoryInfo
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: cat.colorHex))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: cat.icon)
                            .font(.system(size: 22))
                            .foregroundColor(.black.opacity(0.7))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.App.darkGreen, lineWidth: isSelected ? 3 : 0)
                    )
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3), value: isSelected)
                
                Text(cat.name)
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
                                Image(systemName: project.icon)
                                    .foregroundColor(Color(hex: project.colorHex))
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

#Preview {
    AddRecordView()
        .environmentObject(AppStore(modelContext: try! ModelContainer(for: Project.self, Transaction.self, Category.self).mainContext))
}
