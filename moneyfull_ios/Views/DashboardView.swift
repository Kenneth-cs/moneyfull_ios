import SwiftUI
import SwiftData

// 智能金额格式化：整数不显示小数，有小数才保留2位
private func smartFormat(_ value: Double) -> String {
    if value.truncatingRemainder(dividingBy: 1) == 0 {
        return value.formatted(.number.precision(.fractionLength(0)))
    }
    return value.formatted(.number.precision(.fractionLength(2)))
}

// MARK: - 首页看板时间维度
enum DashboardPeriod: String, CaseIterable {
    case week = "本周"
    case month = "本月"
    case year = "本年"
    case all = "累计"
}

struct DashboardView: View {
    @EnvironmentObject var store: AppStore
    @Binding var selectedTab: Int
    var onResetProjectNav: (() -> Void)? = nil
    @State private var detailProject: Project? = nil
    @State private var editingTransaction: Transaction?
    @State private var viewingTransaction: Transaction?
    @State private var isAddRecordPresented = false
    @State private var selectedPeriod: DashboardPeriod = .month
    @State private var showPeriodPicker = false

    // 根据选中维度获取统计数据
    private var currentStats: (expense: Double, income: Double, saving: Double) {
        store.stats(for: selectedPeriod)
    }

    // 进行中项目按创建时间倒序（最新在前）
    private var sortedActiveProjects: [Project] {
        store.activeProjects.sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // MARK: Header
                PageHeader(title: "首页看板")
                
                // MARK: 顶部财务看板（真实数据）
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 32)
                        .fill(LinearGradient(
                            colors: [Color.App.primaryGreen, Color.App.lightGreen],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .shadow(color: Color.App.primaryGreen.opacity(0.4), radius: 20, x: 0, y: 10)
                    
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 160, height: 160)
                        .blur(radius: 20)
                        .offset(x: 40, y: -40)
                    
                    // 卡皮 + 气泡（气泡贴顶，卡皮在下）
                    GreetingMascotView()
                        .padding(.trailing, 12)
                        .padding(.top, 8)
                    
                    // 财务数据
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text("\(selectedPeriod.rawValue)支出")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color.App.textOnPrimary.opacity(0.8))
                                Button(action: { showPeriodPicker = true }) {
                                    Image(systemName: "chevron.down.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color.App.textOnPrimary.opacity(0.6))
                                }
                            }
                            Text("¥ \(smartFormat(currentStats.expense))")
                                .font(.system(size: 34, weight: .heavy))
                                .foregroundColor(Color.App.textOnPrimary)
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                        }
                        
                        HStack(spacing: 12) {
                            FinanceInfoCard(title: "收入", value: currentStats.income)
                            FinanceInfoCard(title: "储蓄", value: currentStats.saving)
                        }
                        .frame(maxWidth: 240)
                        
                        // 嵌入卡片内部的记一笔按钮
                        Button(action: {
                            AnalyticsManager.shared.trackEvent(eventId: "record_click_add", eventName: "点击记一笔入口", params: ["source": "dashboard"])
                            isAddRecordPresented = true
                        }) {
                            HStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 24, height: 24)
                                    Image(systemName: "plus")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color(hex: "#34A873")) // 调整为更明快、更接近图二的绿色
                                }
                                Text("记一笔")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "#34A873")) // 调整为更明快、更接近图二的绿色
                            .clipShape(Capsule())
                            .shadow(color: Color(hex: "#34A873").opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                        .padding(.top, -5) // 稍微拉近与上方卡片的距离
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                }
                .padding(.horizontal, 24)
                
                // MARK: 进行中的项目（横向滑动，最新在前）
                VStack(spacing: 16) {
                    HStack {
                        Text("进行中的项目")
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundColor(Color.App.textBlack)
                        Spacer()
                        Button(action: {
                            AnalyticsManager.shared.trackEvent(eventId: "dashboard_view_all_projects", eventName: "首页查看全部项目")
                            onResetProjectNav?()
                            withAnimation { selectedTab = 1 }
                        }) {
                            HStack(spacing: 4) {
                                Text("查看全部")
                                    .font(.system(size: 14, weight: .bold))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(Color.App.darkGreen)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    if sortedActiveProjects.isEmpty {
                        // 空状态：小满引导新建项目
                        VStack(spacing: 12) {
                            Text("🦫")
                                .font(.system(size: 40))
                            Text("还没有项目，点击下方「+」\n新建一个专属账本吧～")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .padding(.horizontal, 24)
                    } else {
                        // 横向可滑动卡片列表（onTapGesture 不会被 ScrollView 滑动误触发）
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(sortedActiveProjects) { project in
                                    ProjectCard(project: project)
                                        .frame(width: 160)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            AnalyticsManager.shared.trackEvent(eventId: "project_view_detail", eventName: "查看项目详情", params: ["project_status": "active", "source": "dashboard"])
                                            detailProject = project
                                        }
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 4)
                        }
                    }
                }
                .sheet(item: $detailProject) { project in
                    ProjectDetailView(project: project)
                        .environmentObject(store)
                }
                
                // MARK: 最近交易（真实数据）
                VStack(alignment: .leading, spacing: 16) {
                    Text("最近交易")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(Color.App.textBlack)
                        .padding(.horizontal, 24)
                    
                    if store.recentTransactions.isEmpty {
                        VStack(spacing: 12) {
                            Text("🦫")
                                .font(.system(size: 40))
                            Text("还没有任何记录")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Color.App.textBlack)
                            Text("点击底部「+」记录今天的\n第一笔收支吧")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .padding(.horizontal, 24)
                        .background(Color.App.cardBackground.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .padding(.horizontal, 24)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(store.recentTransactions.prefix(10)) { tx in
                                SwipeActionView(
                                    onEdit: { editingTransaction = tx },
                                    onDelete: { store.deleteTransaction(tx) }
                                ) {
                                    TransactionItem(transaction: tx)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            viewingTransaction = tx
                                        }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
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
                
                Spacer().frame(height: 16)
            }
        }
        .safeAreaInset(edge: .bottom) {
            // 为浮动 Tab 栏留出空间，防止内容被遮住
            Color.clear.frame(height: 110)
        }
        .background(Color.App.backgroundGray.ignoresSafeArea())
        .fullScreenCover(isPresented: $isAddRecordPresented) {
            AddRecordView()
                .environmentObject(store)
        }
        .sheet(isPresented: $showPeriodPicker) {
            PeriodPickerSheet(selectedPeriod: $selectedPeriod)
        }
    }
}

// MARK: - 时间维度选择器（莫兰迪绿风格）
struct PeriodPickerSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedPeriod: DashboardPeriod

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            HStack {
                Text("选择统计维度")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundColor(Color.App.textBlack)
                Spacer()
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.gray.opacity(0.4))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 20)

            // 选项列表
            VStack(spacing: 10) {
                ForEach(DashboardPeriod.allCases, id: \.self) { period in
                    Button(action: {
                        selectedPeriod = period
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Text(period.rawValue)
                                .font(.system(size: 16, weight: selectedPeriod == period ? .bold : .medium))
                                .foregroundColor(selectedPeriod == period ? Color.App.darkGreen : Color.App.textBlack.opacity(0.7))

                            Spacer()

                            if selectedPeriod == period {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color.App.darkGreen)
                            } else {
                                Circle()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1.5)
                                    .frame(width: 20, height: 20)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(selectedPeriod == period ? Color.App.darkGreen.opacity(0.08) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .presentationDetents([.height(300)])
        .presentationCornerRadius(24)
    }
}

// MARK: - 收入/储蓄小卡片
struct FinanceInfoCard: View {
    let title: String
    let value: Double
    @Environment(\.colorScheme) private var colorScheme
    
    private var isNegative: Bool { value < 0 }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color.App.textOnPrimary.opacity(0.8))
            HStack(spacing: 4) {
                if isNegative && colorScheme == .dark {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#FF6B6B"))
                }
                Text("¥ \(value.formatted(.number.precision(.fractionLength(0...2))))")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(isNegative && colorScheme == .dark ? Color(hex: "#FF6B6B") : Color.App.textOnPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            Group {
                if colorScheme == .dark {
                    Color.white.opacity(0.3)
                } else {
                    Color.white.opacity(0.4)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - 项目卡片（绑定真实 Project）
struct ProjectCard: View {
    let project: Project
    
    private var progressPair: ProgressColorPair {
        progressColorPair(for: project.colorHex)
    }
    private var progressPctColor: Color {
        let p = project.budgetProgress
        if p >= 1.0 { return Color.App.redExpense }
        if p >= 0.8 { return Color(hex: "#FFA500") }
        return Color(hex: progressPair.end)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Circle()
                    .fill(Color(hex: project.colorHex).opacity(0.4))
                    .frame(width: 40, height: 40)
                    .overlay(
                        AppIconView(name: project.icon, size: 18,
                                    color: Color.App.projectIconColor(for: project.colorHex))
                    )
                Spacer(minLength: 4)
                Text("进行中")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.App.darkGreen)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.App.primaryGreen.opacity(0.5))
                    .clipShape(Capsule())
            }
            
            Text(project.name)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color.App.textBlack)
                .lineLimit(1)
            
            if project.budget > 0 {
                HStack {
                    Text("¥\(project.totalSpent.formatted(.number.precision(.fractionLength(0))))")
                    Spacer()
                    Text("预算¥\(project.budget.formatted(.number.precision(.fractionLength(0))))")
                }
                .font(.system(size: 10))
                .foregroundColor(.gray)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.App.progressTrack).frame(height: 6)
                        Capsule()
                            .fill(LinearGradient(
                                colors: [Color(hex: progressPair.start), Color(hex: progressPair.end)],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: max(0, min(geo.size.width, geo.size.width * project.budgetProgress)), height: 6)
                    }
                }
                .frame(height: 6)
            } else {
                Text("已用 ¥\(project.totalSpent.formatted(.number.precision(.fractionLength(0))))")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                Spacer().frame(height: 6)
            }
        }
        .padding(16)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
    }
}

// MARK: - 交易记录行（绑定真实 Transaction）
struct TransactionItem: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color(hex: transaction.categoryColorHex).opacity(0.3))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: transaction.categoryIcon)
                        .foregroundColor(Color(hex: transaction.categoryColorHex))
                        .font(.system(size: 20))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.note.isEmpty ? transaction.categoryName : transaction.note)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.App.textBlack)
                Text("\(transaction.categoryName) · \(transaction.date.relativeDisplay)")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text("\(transaction.type == .expense ? "-" : "+") ¥\(transaction.amount.formatted(.number.precision(.fractionLength(2))))")
                .font(.system(size: 15, weight: .heavy))
                .foregroundColor(transaction.type == .expense ? Color.App.redExpense : Color.App.darkGreen)
        }
        .padding(16)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 5)
    }
}

// MARK: - 日期相对显示扩展
extension Date {
    var relativeDisplay: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        
        if calendar.isDateInToday(self) {
            formatter.dateFormat = "HH:mm"
            return "今天 \(formatter.string(from: self))"
        }
        if calendar.isDateInYesterday(self) {
            formatter.dateFormat = "HH:mm"
            return "昨天 \(formatter.string(from: self))"
        }
        
        // 今年的日期显示 月/日
        if calendar.component(.year, from: self) == calendar.component(.year, from: Date()) {
            formatter.dateFormat = "M/d"
        } else {
            // 非今年显示 年/月/日
            formatter.dateFormat = "yyyy/M/d"
        }
        return formatter.string(from: self)
    }
    
    var formattedChineseDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: self)
    }
}

#Preview {
    DashboardView(selectedTab: .constant(0))
        .environmentObject(AppStore(modelContext: try! ModelContainer(for: Project.self, Transaction.self, Category.self, ChatHistory.self, MemoryRule.self).mainContext))
}
