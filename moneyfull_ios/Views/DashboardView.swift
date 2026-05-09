import SwiftUI
import SwiftData

// 智能金额格式化：整数不显示小数，有小数才保留2位
private func smartFormat(_ value: Double) -> String {
    if value.truncatingRemainder(dividingBy: 1) == 0 {
        return value.formatted(.number.precision(.fractionLength(0)))
    }
    return value.formatted(.number.precision(.fractionLength(2)))
}

struct DashboardView: View {
    @EnvironmentObject var store: AppStore
    // 选中的项目，用于弹出详情页（sheet）
    @State private var detailProject: Project? = nil
    
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
                            Text("当前支出")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color.App.textOnPrimary.opacity(0.8))
                            Text("¥ \(smartFormat(store.monthlyExpense))")
                                .font(.system(size: 34, weight: .heavy))
                                .foregroundColor(Color.App.textOnPrimary)
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                        }
                        
                        HStack(spacing: 12) {
                            FinanceInfoCard(title: "收入", value: store.monthlyIncome)
                            FinanceInfoCard(title: "储蓄", value: store.monthlySaving)
                        }
                        .frame(maxWidth: 240)
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
                        Text("查看全部")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.App.darkGreen)
                    }
                    .padding(.horizontal, 24)
                    
                    if sortedActiveProjects.isEmpty {
                        // 空状态：卡皮巴拉引导新建项目
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
                                TransactionItem(transaction: tx)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
                
                Spacer().frame(height: 16)
            }
        }
        .safeAreaInset(edge: .bottom) {
            // 为浮动 Tab 栏留出空间，防止内容被遮住
            Color.clear.frame(height: 110)
        }
        .background(Color.App.backgroundGray.ignoresSafeArea())
    }
}

// MARK: - 收入/储蓄小卡片
struct FinanceInfoCard: View {
    let title: String
    let value: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color.App.textOnPrimary.opacity(0.8))
            Text("¥ \(value.formatted(.number.precision(.fractionLength(0))))")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color.App.textOnPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.4))
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
        if calendar.isDateInToday(self) { return "今天 " + formatted(date: .omitted, time: .shortened) }
        if calendar.isDateInYesterday(self) { return "昨天 " + formatted(date: .omitted, time: .shortened) }
        return formatted(date: .abbreviated, time: .omitted)
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppStore(modelContext: try! ModelContainer(for: Project.self, Transaction.self, Category.self).mainContext))
}
