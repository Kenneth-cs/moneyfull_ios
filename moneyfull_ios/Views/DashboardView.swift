import SwiftUI
import SwiftData

struct DashboardView: View {
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // MARK: Header
                HStack {
                    HStack(spacing: 8) {
                        AppLogo()
                        Text("首页看板")
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundColor(Color.App.textBlack)
                    }
                    Spacer()
                    Image(systemName: "bell")
                        .font(.system(size: 22))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
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
                    
                    // 卡皮 + 气泡
                    GreetingMascotView()
                        .padding(.trailing, 24)
                        .padding(.top, 20)
                    
                    // 财务数据
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("当前支出")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color.App.darkGreen.opacity(0.8))
                            Text("¥ \(store.monthlyExpense.formatted(.number.precision(.fractionLength(2))))")
                                .font(.system(size: 34, weight: .heavy))
                                .foregroundColor(Color.App.darkGreen)
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
                
                // MARK: 进行中的项目（真实数据）
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
                    
                    if store.activeProjects.isEmpty {
                        Text("还没有进行中的项目，点击 + 新建一个吧！")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .padding(24)
                    } else {
                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
                            spacing: 16
                        ) {
                            ForEach(store.activeProjects.prefix(4)) { project in
                                ProjectCard(project: project)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
                
                // MARK: 最近交易（真实数据）
                VStack(alignment: .leading, spacing: 16) {
                    Text("最近交易")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(Color.App.textBlack)
                        .padding(.horizontal, 24)
                    
                    if store.recentTransactions.isEmpty {
                        Text("还没有交易记录")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
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
                
                Spacer().frame(height: 120)
            }
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
                .foregroundColor(Color.App.darkGreen.opacity(0.8))
            Text("¥ \(value.formatted(.number.precision(.fractionLength(0))))")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color.App.darkGreen)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - 项目卡片（绑定真实 Project）
struct ProjectCard: View {
    let project: Project
    
    private var progressColor: Color {
        let p = project.budgetProgress
        if p >= 1.0 { return Color.App.redExpense }
        if p >= 0.8 { return Color(hex: "#FFA500") }
        return Color.App.darkGreen
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Circle()
                    .fill(Color(hex: project.colorHex).opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: project.icon)
                            .foregroundColor(Color(hex: project.colorHex))
                            .font(.system(size: 16))
                    )
                Spacer(minLength: 4)
                Text("进行中")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.App.darkOrangeBrown)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.App.lightOrange)
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
                        Capsule().fill(Color.gray.opacity(0.1)).frame(height: 6)
                        Capsule()
                            .fill(progressColor)
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
        .background(Color.white)
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
        .background(Color.white)
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
