import SwiftUI
import SwiftData

/// 固定成本管理视图
struct FixedCostListView: View {
    let project: Project
    
    @EnvironmentObject private var store: AppStore
    @State private var showAddFixedCost = false
    @State private var editingFixedCost: FixedCost?
    @State private var showDeleteConfirm = false
    @State private var deletingFixedCost: FixedCost?
    
    var body: some View {
        List {
            // 顶部汇总
            summarySection
            
            // 固定成本列表
            if !activeFixedCosts.isEmpty {
                Section("启用中") {
                    ForEach(activeFixedCosts, id: \.id) { fixedCost in
                        fixedCostRow(fixedCost)
                    }
                }
            }
            
            if !inactiveFixedCosts.isEmpty {
                Section("已停用") {
                    ForEach(inactiveFixedCosts, id: \.id) { fixedCost in
                        fixedCostRow(fixedCost)
                    }
                }
            }
            
            // 空状态
            if project.fixedCosts?.isEmpty ?? true {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("暂无固定成本")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("点击右上角 + 添加固定成本项目\n如：社保、房租、软件会员等")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            }
        }
        .navigationTitle("固定成本管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddFixedCost = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddFixedCost) {
            FixedCostFormSheet(project: project, fixedCost: nil)
        }
        .sheet(item: $editingFixedCost) { fixedCost in
            FixedCostFormSheet(project: project, fixedCost: fixedCost)
        }
        .alert("确认删除", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                if let fixedCost = deletingFixedCost {
                    store.deleteFixedCost(fixedCost)
                }
            }
        } message: {
            if let fixedCost = deletingFixedCost {
                Text("确定要删除「\(fixedCost.name)」吗？此操作不可恢复。")
            }
        }
    }
    
    // MARK: - 汇总部分
    
    private var summarySection: some View {
        Section {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("月度合计")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("¥\(Int(monthlyTotal))")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("未来30天到期")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("¥\(Int(upcoming30Days))")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("年度预算")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("¥\(Int(monthlyTotal * 12))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("启用中项目")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(activeFixedCosts.count)个")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - 固定成本行
    
    private func fixedCostRow(_ fixedCost: FixedCost) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(fixedCost.name)
                        .font(.headline)
                        .foregroundColor(fixedCost.isActive ? .primary : .secondary)
                    
                    if !fixedCost.isActive {
                        Text("已停用")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .cornerRadius(4)
                    }
                }
                
                HStack(spacing: 8) {
                    Text("¥\(Int(fixedCost.amount))")
                        .font(.subheadline)
                        .foregroundColor(fixedCost.isActive ? .primary : .secondary)
                    
                    Text(fixedCost.frequency.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray6))
                        .cornerRadius(4)
                    
                    if let nextDue = fixedCost.nextDueDate {
                        Text("下次: \(nextDue, style: .date)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("¥\(Int(fixedCost.monthlyAmount))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("/月")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                deletingFixedCost = fixedCost
                showDeleteConfirm = true
            } label: {
                Label("删除", systemImage: "trash")
            }
            
            Button {
                editingFixedCost = fixedCost
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            .tint(.blue)
            
            Button {
                store.toggleFixedCost(fixedCost)
            } label: {
                Label(fixedCost.isActive ? "停用" : "启用",
                      systemImage: fixedCost.isActive ? "pause.circle" : "play.circle")
            }
            .tint(fixedCost.isActive ? .orange : .green)
        }
        .contextMenu {
            Button {
                store.toggleFixedCost(fixedCost)
            } label: {
                Label(fixedCost.isActive ? "停用" : "启用",
                      systemImage: fixedCost.isActive ? "pause.circle" : "play.circle")
            }
            
            Button {
                editingFixedCost = fixedCost
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                deletingFixedCost = fixedCost
                showDeleteConfirm = true
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
    
    // MARK: - 计算属性
    
    private var activeFixedCosts: [FixedCost] {
        (project.fixedCosts ?? []).filter { $0.isActive }
    }
    
    private var inactiveFixedCosts: [FixedCost] {
        (project.fixedCosts ?? []).filter { !$0.isActive }
    }
    
    private var monthlyTotal: Double {
        (project.fixedCosts ?? []).filter { $0.isActive }.reduce(0) { $0 + $1.monthlyAmount }
    }
    
    private var upcoming30Days: Double {
        let now = Date()
        let thirtyDaysLater = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now
        
        return (project.fixedCosts ?? [])
            .filter { $0.isActive }
            .filter { cost in
                guard let dueDate = cost.nextDueDate else { return false }
                return dueDate >= now && dueDate <= thirtyDaysLater
            }
            .reduce(0) { $0 + $1.amount }
    }
}

// MARK: - 固定成本表单

struct FixedCostFormSheet: View {
    let project: Project
    let fixedCost: FixedCost?
    
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var amount = ""
    @State private var frequency: FixedCostFrequency = .monthly
    @State private var category = ""
    @State private var nextDueDate = Date()
    @State private var hasNextDueDate = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("成本名称", text: $name)
                    TextField("金额", text: $amount)
                        .keyboardType(.decimalPad)
                    
                    Picker("频率", selection: $frequency) {
                        ForEach(FixedCostFrequency.allCases, id: \.self) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                }
                
                Section("分类") {
                    TextField("分类标签", text: $category)
                }
                
                Section("下次扣款日期") {
                    Toggle("设置下次扣款日", isOn: $hasNextDueDate)
                    
                    if hasNextDueDate {
                        DatePicker("下次扣款日", selection: $nextDueDate, displayedComponents: .date)
                    }
                }
                
                Section("预览") {
                    HStack {
                        Text("月度成本")
                        Spacer()
                        Text("¥\(Int(monthlyPreview))")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("年度成本")
                        Spacer()
                        Text("¥\(Int(monthlyPreview * 12))")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(fixedCost == nil ? "新增固定成本" : "编辑固定成本")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveFixedCost()
                    }
                    .disabled(name.isEmpty || amount.isEmpty)
                }
            }
            .onAppear {
                if let fixedCost = fixedCost {
                    name = fixedCost.name
                    amount = String(Int(fixedCost.amount))
                    frequency = fixedCost.frequency
                    category = fixedCost.category
                    if let nextDue = fixedCost.nextDueDate {
                        nextDueDate = nextDue
                        hasNextDueDate = true
                    }
                }
            }
        }
    }
    
    private var monthlyPreview: Double {
        guard let amountValue = Double(amount) else { return 0 }
        switch frequency {
        case .monthly:
            return amountValue
        case .quarterly:
            return amountValue / 3.0
        case .yearly:
            return amountValue / 12.0
        }
    }
    
    private func saveFixedCost() {
        guard let amountValue = Double(amount) else { return }
        
        if let fixedCost = fixedCost {
            // 更新
            store.updateFixedCost(fixedCost, name: name, amount: amountValue,
                                  frequency: frequency, category: category,
                                  nextDueDate: hasNextDueDate ? nextDueDate : nil)
        } else {
            // 新增
            store.addFixedCost(to: project, name: name, amount: amountValue,
                              frequency: frequency, category: category,
                              nextDueDate: hasNextDueDate ? nextDueDate : nil)
        }
        
        dismiss()
    }
}

// MARK: - 扩展

extension FixedCostFrequency: CaseIterable {
    public static var allCases: [FixedCostFrequency] {
        [.monthly, .quarterly, .yearly]
    }
    
    var displayName: String {
        switch self {
        case .monthly: return "每月"
        case .quarterly: return "每季度"
        case .yearly: return "每年"
        }
    }
}

// MARK: - 预览

#Preview {
    NavigationView {
        FixedCostListView(project: Project(name: "预览项目", icon: "folder.fill", colorHex: "#A8E6CF"))
    }
    .environmentObject(AppStore(modelContext: try! ModelContainer(for: Project.self, Transaction.self, Category.self, ChatHistory.self, MemoryRule.self, RecurringBill.self, BudgetItem.self, TimeEntry.self, Receivable.self, FixedCost.self).mainContext))
}