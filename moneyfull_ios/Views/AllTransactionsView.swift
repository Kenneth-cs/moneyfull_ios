import SwiftUI

// 智能金额格式化：整数不显示小数，有小数才保留2位
private func smartFormat(_ value: Double) -> String {
    if value.truncatingRemainder(dividingBy: 1) == 0 {
        return value.formatted(.number.precision(.fractionLength(0)))
    }
    return value.formatted(.number.precision(.fractionLength(2)))
}

struct AllTransactionsView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var editingTransaction: Transaction?
    @State private var viewingTransaction: Transaction?
    
    // 筛选状态
    @State private var selectedProject: Project? = nil
    @State private var selectedCategory: String? = nil
    @State private var selectedPeriod: FilterPeriod = .all
    @State private var showCustomDatePicker = false
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    
    // 筛选选项
    enum FilterPeriod: String, CaseIterable {
        case all = "全部"
        case today = "今天"
        case thisWeek = "本周"
        case thisMonth = "本月"
        case lastMonth = "上月"
        case thisYear = "今年"
        case custom = "自定义"
    }
    
    // 筛选后的交易记录
    private var filteredTransactions: [Transaction] {
        var transactions = store.fetchAllTransactions()
        
        // 按项目筛选
        if let project = selectedProject {
            transactions = transactions.filter { $0.project?.id == project.id }
        }
        
        // 按分类筛选
        if let category = selectedCategory {
            transactions = transactions.filter { $0.categoryName == category }
        }
        
        // 按时间筛选
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedPeriod {
        case .all:
            break
        case .today:
            let startOfDay = calendar.startOfDay(for: now)
            transactions = transactions.filter { $0.date >= startOfDay }
        case .thisWeek:
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            transactions = transactions.filter { $0.date >= startOfWeek }
        case .thisMonth:
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            transactions = transactions.filter { $0.date >= startOfMonth }
        case .lastMonth:
            let startOfThisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfThisMonth)!
            transactions = transactions.filter { $0.date >= startOfLastMonth && $0.date < startOfThisMonth }
        case .thisYear:
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now))!
            transactions = transactions.filter { $0.date >= startOfYear }
        case .custom:
            let startOfDay = calendar.startOfDay(for: customStartDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: customEndDate))!
            transactions = transactions.filter { $0.date >= startOfDay && $0.date < endOfDay }
        }
        
        return transactions
    }
    
    // 按日期分组的交易记录
    private var groupedTransactions: [(key: String, value: [Transaction])] {
        let sorted = filteredTransactions.sorted { $0.date > $1.date }
        var groups: [String: [Transaction]] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        for tx in sorted {
            let key = formatter.string(from: tx.date)
            groups[key, default: []].append(tx)
        }
        return groups.sorted { $0.key > $1.key }
    }
    
    // 获取所有分类名称
    private var allCategories: [String] {
        let transactions = store.fetchAllTransactions()
        return Array(Set(transactions.map { $0.categoryName })).sorted()
    }
    
    // 统计数据
    private var totalExpense: Double {
        filteredTransactions.filter { $0.type == .expense }.reduce(0) { $0 + abs($1.amount) }
    }
    
    private var totalIncome: Double {
        filteredTransactions.filter { $0.type == .income }.reduce(0) { $0 + abs($1.amount) }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 筛选栏
                filterBar
                
                // 统计卡片
                statsCard
                
                // 交易列表
                transactionList
            }
            .background(Color.App.backgroundGray.ignoresSafeArea())
            .navigationTitle("全部账单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $editingTransaction) { tx in
            EditTransactionView(transaction: tx)
                .environmentObject(store)
        }
        .sheet(item: $viewingTransaction) { tx in
            TransactionDetailView(transaction: tx)
                .environmentObject(store)
        }
        .sheet(isPresented: $showCustomDatePicker) {
            CustomDatePickerSheet(
                startDate: $customStartDate,
                endDate: $customEndDate,
                onConfirm: {
                    selectedPeriod = .custom
                }
            )
        }
    }
    
    // 自定义日期范围显示文本
    private var customDateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return "\(formatter.string(from: customStartDate))-\(formatter.string(from: customEndDate))"
    }
    
    // MARK: - 筛选栏
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // 时间筛选
                Menu {
                    ForEach(FilterPeriod.allCases, id: \.self) { period in
                        if period == .custom {
                            Button("自定义时间") {
                                showCustomDatePicker = true
                            }
                        } else {
                            Button(period.rawValue) {
                                selectedPeriod = period
                            }
                        }
                    }
                } label: {
                    FilterChip(
                        title: selectedPeriod == .custom ? customDateRangeText : selectedPeriod.rawValue,
                        isSelected: selectedPeriod != .all
                    )
                }
                
                // 项目筛选
                Menu {
                    Button("全部项目") {
                        selectedProject = nil
                    }
                    ForEach(store.activeProjects) { project in
                        Button(project.name) {
                            selectedProject = project
                        }
                    }
                } label: {
                    FilterChip(
                        title: selectedProject?.name ?? "项目",
                        isSelected: selectedProject != nil
                    )
                }
                
                // 分类筛选
                Menu {
                    Button("全部分类") {
                        selectedCategory = nil
                    }
                    ForEach(allCategories, id: \.self) { category in
                        Button(category) {
                            selectedCategory = category
                        }
                    }
                } label: {
                    FilterChip(
                        title: selectedCategory ?? "分类",
                        isSelected: selectedCategory != nil
                    )
                }
                
                // 清除筛选
                if selectedPeriod != .all || selectedProject != nil || selectedCategory != nil {
                    Button("清除筛选") {
                        selectedPeriod = .all
                        selectedProject = nil
                        selectedCategory = nil
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.App.darkGreen)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.App.cardBackground)
    }
    
    // MARK: - 统计卡片
    private var statsCard: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("支出")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                Text("-¥\(smartFormat(totalExpense))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.App.redExpense)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .center, spacing: 4) {
                Text("收入")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                Text("+¥\(smartFormat(totalIncome))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.App.darkGreen)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("净收入")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                let net = totalIncome - totalExpense
                Text("\(net >= 0 ? "+" : "-")¥\(smartFormat(abs(net)))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(net >= 0 ? Color.App.darkGreen : Color.App.redExpense)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - 交易列表
    private var transactionList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if groupedTransactions.isEmpty {
                    VStack(spacing: 16) {
                        Text("🦫")
                            .font(.system(size: 48))
                        Text("没有找到匹配的账单")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    ForEach(groupedTransactions, id: \.key) { group in
                        VStack(alignment: .leading, spacing: 0) {
                            // 日期标题
                            HStack {
                                Text(group.key)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.gray)
                                Spacer()
                                let dayExpense = group.value.filter { $0.type == .expense }.reduce(0) { $0 + abs($1.amount) }
                                Text("-¥\(dayExpense.formatted(.number.precision(.fractionLength(2))))")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.App.backgroundGray)
                            
                            // 交易记录
                            VStack(spacing: 0) {
                                ForEach(group.value) { tx in
                                    SwipeActionView(
                                        onEdit: { editingTransaction = tx },
                                        onDelete: { store.deleteTransaction(tx) }
                                    ) {
                                        TransactionRow(transaction: tx)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                viewingTransaction = tx
                                            }
                                    }
                                    
                                    if tx.id != group.value.last?.id {
                                        Divider()
                                            .padding(.leading, 60)
                                    }
                                }
                            }
                            .background(Color.App.cardBackground)
                        }
                        .padding(.bottom, 8)
                    }
                }
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - 筛选标签组件
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .bold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.App.darkGreen : Color.App.tabBackground)
        .foregroundColor(isSelected ? .white : Color.App.textBlack)
        .clipShape(Capsule())
    }
}

// MARK: - 交易记录行
struct TransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 12) {
            // 分类图标
            Circle()
                .fill(Color(hex: transaction.categoryColorHex).opacity(0.3))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: transaction.categoryIcon)
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: transaction.categoryColorHex))
                )
            
            // 分类和备注
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.categoryName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.App.textBlack)
                
                if !transaction.note.isEmpty {
                    Text(transaction.note)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // 金额和时间
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(transaction.type == .expense ? "-" : "+")¥\(transaction.amount.formatted(.number.precision(.fractionLength(2))))")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(transaction.type == .expense ? Color.App.redExpense : Color.App.darkGreen)
                
                Text(transaction.date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - 自定义日期选择器
struct CustomDatePickerSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var startDate: Date
    @Binding var endDate: Date
    var onConfirm: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("开始日期")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("结束日期")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        DatePicker("结束日期", selection: $endDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                    }
                }
                .padding(.horizontal, 16)
                
                Spacer()
            }
            .navigationTitle("自定义时间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        onConfirm()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
