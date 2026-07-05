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

    // 新增表单
    @State private var newName = ""
    @State private var newAmountText = ""
    @State private var newIcon = "tag.fill"
    @State private var newColorHex = "#A8E0C2"

    private var items: [BudgetItem] { project.budgetItems ?? [] }
    private var totalBudget: Double { project.budget }
    private var allocated: Double { items.reduce(0) { $0 + $1.amount } }
    private var unallocated: Double { totalBudget - allocated }

    var body: some View {
        NavigationView {
            List {
                // MARK: 汇总
                if totalBudget > 0 {
                    Section {
                        HStack {
                            Label("总预算", systemImage: "dollarsign.circle.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color.App.darkGreen)
                            Spacer()
                            Text("¥\(Int(totalBudget))")
                                .font(.system(size: 16, weight: .heavy))
                                .foregroundColor(Color.App.textBlack)
                        }
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
                }

                // MARK: 分类列表
                Section {
                    if items.isEmpty {
                        Text("还没有预算分类，点击下方添加")
                            .font(.system(size: 14)).foregroundColor(.gray)
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(items) { item in
                            BudgetItemEditRow(item: item, onUpdate: { newAmount in
                                store.updateBudgetItem(item, amount: newAmount)
                            })
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                store.deleteBudgetItem(items[index])
                            }
                        }
                    }
                    // 添加按钮行
                    Button {
                        showAddForm = true
                        newName = ""; newAmountText = ""; newIcon = "tag.fill"; newColorHex = "#A8E0C2"
                    } label: {
                        Label("添加分类", systemImage: "plus.circle.fill")
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
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        if cycle == .custom && project.budgetCycle == cycle.rawValue {
                            HStack {
                                Text("刷新周期")
                                    .font(.system(size: 14)).foregroundColor(.gray)
                                Spacer()
                                TextField("30", value: Binding(
                                    get: { project.budgetCycleDays },
                                    set: { project.budgetCycleDays = $0 }
                                ), format: .number)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .font(.system(size: 14, weight: .bold))
                                    .frame(width: 60)
                                Text("天")
                                    .font(.system(size: 14)).foregroundColor(.gray)
                            }
                        }
                    }
                } header: { Text("预算周期") }

                // MARK: 预算预警（Plus）
                Section {
                    if storeManager.isPremium {
                        Toggle(isOn: Binding(
                            get: { project.budgetAlertThreshold > 0 },
                            set: { newVal in
                                project.budgetAlertThreshold = newVal ? 0.8 : 0
                            }
                        )) {
                            Label("开启预算预警", systemImage: "bell.badge.fill")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .tint(Color.App.darkGreen)
                        if project.budgetAlertThreshold > 0 {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("总预算达到 \(Int(project.budgetAlertThreshold * 100))% 时推送提醒")
                                    .font(.system(size: 13)).foregroundColor(.gray)
                                Slider(value: Binding(
                                    get: { project.budgetAlertThreshold },
                                    set: { project.budgetAlertThreshold = $0 }
                                ), in: 0.5...1.0, step: 0.05)
                                    .tint(Color.App.darkGreen)
                                HStack {
                                    Text("50%").font(.system(size: 10)).foregroundColor(.gray)
                                    Spacer()
                                    Text("100%").font(.system(size: 10)).foregroundColor(.gray)
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
                                    Text("Plus").font(.system(size: 12, weight: .heavy))
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
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { presentationMode.wrappedValue.dismiss() }
                        .font(.system(size: 16, weight: .bold))
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
        }
    }

    // MARK: 新增表单（内联）
    private var addFormSection: some View {
        Section {
            TextField("分类名称（如：交通）", text: $newName)
                .font(.system(size: 15))
            HStack {
                Text("¥").foregroundColor(Color.App.darkGreen)
                TextField("预算金额", text: $newAmountText).keyboardType(.decimalPad)
            }
            // 图标简选（常用 8 个）
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(["tag.fill","car.fill","fork.knife","house.fill","bag.fill",
                             "ticket.fill","airplane","desktopcomputer"], id: \.self) { icon in
                        Button { newIcon = icon } label: {
                            Image(systemName: icon)
                                .font(.system(size: 18))
                                .frame(width: 40, height: 40)
                                .background(newIcon == icon
                                            ? Color.App.primaryGreen.opacity(0.3)
                                            : Color.App.tabBackground)
                                .clipShape(Circle())
                                .foregroundColor(newIcon == icon ? Color.App.darkGreen : .gray)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            HStack {
                Button("取消") { showAddForm = false }
                    .foregroundColor(.gray).font(.system(size: 14, weight: .bold))
                Spacer()
                Button("添加") {
                    guard !newName.isEmpty, let amt = Double(newAmountText), amt > 0 else { return }
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

    @State private var amountText: String = ""
    @FocusState private var amountFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: item.categoryColorHex).opacity(0.25))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: item.categoryIcon)
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: item.categoryColorHex))
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
                    .focused($amountFocused)
                    .onAppear { amountText = "\(Int(item.amount))" }
                    .onChange(of: amountFocused) { _, focused in
                        if !focused, let val = Double(amountText), val > 0 {
                            onUpdate(val)
                        }
                    }
            }
        }
    }
}
