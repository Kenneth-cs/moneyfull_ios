import SwiftUI
import SwiftData

/// 应收账款管理视图
struct ReceivableListView: View {
    let project: Project
    
    @EnvironmentObject private var store: AppStore
    @State private var showAddReceivable = false
    @State private var editingReceivable: Receivable?
    @State private var showMarkReceived = false
    @State private var markingReceivable: Receivable?
    @State private var showAddRecord = false
    @State private var prefilledAmount: String = ""
    @State private var prefilledNote: String = ""
    
    var body: some View {
        List {
            // 顶部汇总
            summarySection
            
            // 逾期部分
            if !overdueReceivables.isEmpty {
                Section("逾期") {
                    ForEach(overdueReceivables, id: \.id) { receivable in
                        receivableRow(receivable, isOverdue: true)
                    }
                }
            }
            
            // 进行中部分
            if !pendingReceivables.isEmpty {
                Section("进行中") {
                    ForEach(pendingReceivables, id: \.id) { receivable in
                        receivableRow(receivable, isOverdue: false)
                    }
                }
            }
            
            // 空状态
            if project.receivables?.isEmpty ?? true {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("暂无应收账款")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("点击右上角 + 添加新的应收账款")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            }
        }
        .navigationTitle("应收账款管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddReceivable = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddReceivable) {
            ReceivableFormSheet(project: project, receivable: nil)
        }
        .sheet(item: $editingReceivable) { receivable in
            ReceivableFormSheet(project: project, receivable: receivable)
        }
        .alert("确认到账", isPresented: $showMarkReceived) {
            Button("取消", role: .cancel) { }
            Button("确认到账") {
                if let receivable = markingReceivable {
                    store.markReceivable(receivable, received: true)
                    // 预填金额和备注，跳转到记收入页面
                    prefilledAmount = String(Int(receivable.amount))
                    prefilledNote = "\(receivable.clientName) - \(receivable.projectName) 回款"
                    showAddRecord = true
                }
            }
        } message: {
            if let receivable = markingReceivable {
                Text("确认已收到 \(receivable.clientName) 的 ¥\(Int(receivable.amount)) 款项？")
            }
        }
        .sheet(isPresented: $showAddRecord) {
            AddRecordView(
                project: project,
                prefilledAmount: prefilledAmount,
                prefilledNote: prefilledNote,
                prefilledType: .income
            )
        }
    }
    
    // MARK: - 汇总部分
    
    private var summarySection: some View {
        Section {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("待回款总额")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("¥\(Int(totalPending))")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("逾期金额")
                            .font(.caption)
                            .foregroundColor(.red)
                        Text("¥\(Int(totalOverdue))")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                }
                
                if totalOverdue > 0 {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("有 \(overdueReceivables.count) 笔应收账款已逾期")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Spacer()
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - 应收账款行
    
    private func receivableRow(_ receivable: Receivable, isOverdue: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(receivable.clientName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if !receivable.projectName.isEmpty {
                    Text(receivable.projectName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let expectedDate = receivable.expectedDate {
                    Text("预计回款: \(expectedDate, style: .date)")
                        .font(.caption)
                        .foregroundColor(isOverdue ? .red : .secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("¥\(Int(receivable.amount))")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if isOverdue {
                    Text("已逾期")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                store.deleteReceivable(receivable)
            } label: {
                Label("删除", systemImage: "trash")
            }
            
            Button {
                editingReceivable = receivable
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            .tint(.blue)
            
            if receivable.status == .pending {
                Button {
                    markingReceivable = receivable
                    showMarkReceived = true
                } label: {
                    Label("标记到账", systemImage: "checkmark.circle")
                }
                .tint(.green)
            }
        }
        .contextMenu {
            Button {
                markingReceivable = receivable
                showMarkReceived = true
            } label: {
                Label("标记到账", systemImage: "checkmark.circle")
            }
            
            Button {
                editingReceivable = receivable
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                store.deleteReceivable(receivable)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
    
    // MARK: - 计算属性
    
    private var pendingReceivables: [Receivable] {
        (project.receivables ?? []).filter { $0.status == .pending && !$0.isOverdue }
    }
    
    private var overdueReceivables: [Receivable] {
        (project.receivables ?? []).filter { $0.isOverdue }
    }
    
    private var totalPending: Double {
        (project.receivables ?? []).filter { $0.status == .pending }.reduce(0) { $0 + $1.amount }
    }
    
    private var totalOverdue: Double {
        (project.receivables ?? []).filter { $0.isOverdue }.reduce(0) { $0 + $1.amount }
    }
}

// MARK: - 应收账款表单

struct ReceivableFormSheet: View {
    let project: Project
    let receivable: Receivable?
    
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var clientName = ""
    @State private var projectName = ""
    @State private var amount = ""
    @State private var expectedDate = Date()
    @State private var note = ""
    @State private var hasExpectedDate = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("客户名称", text: $clientName)
                    TextField("业务描述", text: $projectName)
                    TextField("应收金额", text: $amount)
                        .keyboardType(.decimalPad)
                }
                
                Section("预计回款日期") {
                    Toggle("设置预计回款日", isOn: $hasExpectedDate)
                    
                    if hasExpectedDate {
                        DatePicker("预计回款日", selection: $expectedDate, displayedComponents: .date)
                    }
                }
                
                Section("备注") {
                    TextField("备注信息", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(receivable == nil ? "新增应收账款" : "编辑应收账款")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveReceivable()
                    }
                    .disabled(clientName.isEmpty || amount.isEmpty)
                }
            }
            .onAppear {
                if let receivable = receivable {
                    clientName = receivable.clientName
                    projectName = receivable.projectName
                    amount = String(Int(receivable.amount))
                    note = receivable.note
                    if let expected = receivable.expectedDate {
                        expectedDate = expected
                        hasExpectedDate = true
                    }
                }
            }
        }
    }
    
    private func saveReceivable() {
        guard let amountValue = Double(amount) else { return }
        
        if let receivable = receivable {
            // 更新
            store.updateReceivable(receivable, clientName: clientName, projectName: projectName,
                                   amount: amountValue, expectedDate: hasExpectedDate ? expectedDate : nil,
                                   note: note)
        } else {
            // 新增
            store.addReceivable(to: project, clientName: clientName, projectName: projectName,
                               amount: amountValue, expectedDate: hasExpectedDate ? expectedDate : nil,
                               note: note)
        }
        
        dismiss()
    }
}

// MARK: - 预览

#Preview {
    NavigationView {
        ReceivableListView(project: Project(name: "预览项目", icon: "folder.fill", colorHex: "#A8E6CF"))
    }
    .environmentObject(AppStore(modelContext: try! ModelContainer(for: Project.self, Transaction.self, Category.self, ChatHistory.self, MemoryRule.self, RecurringBill.self, BudgetItem.self, TimeEntry.self, Receivable.self, FixedCost.self).mainContext))
}