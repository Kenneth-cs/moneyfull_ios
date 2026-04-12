import SwiftUI
import SwiftData
struct ProjectDetailView: View {
    let project: Project
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) var presentationMode
    
    // 按日期分组的交易记录
    private var groupedTransactions: [(key: String, value: [Transaction])] {
        let sorted = project.transactions.sorted { $0.date > $1.date }
        var groups: [String: [Transaction]] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        for tx in sorted {
            let key = formatter.string(from: tx.date)
            groups[key, default: []].append(tx)
        }
        return groups.sorted { $0.key > $1.key }
    }
    
    // 进度条同色系色对
    private var colorPair: ProgressColorPair {
        progressColorPair(for: project.colorHex)
    }
    private var accentColor: Color { Color(hex: colorPair.end) }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: 自定义顶部导航栏
            ZStack {
                // 标题居中（两侧对称留出返回按钮宽度）
                Text(project.name)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundColor(Color.App.textBlack)
                    .lineLimit(1)
                    .padding(.horizontal, 80) // 两侧各留80pt给返回按钮
                
                // 左侧返回按钮
                HStack {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .bold))
                            Text("返回")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(accentColor)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 44)
            .padding(.top, 8)
            .background(Color.App.backgroundGray)
            
            // MARK: 主内容滚动区
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // 项目概览卡片
                    VStack(alignment: .leading, spacing: 20) {
                        // 项目图标 + 描述（不再重复项目名，导航栏已显示）
                        HStack(spacing: 14) {
                            Circle()
                                .fill(Color(hex: project.colorHex).opacity(0.3))
                                .frame(width: 56, height: 56)
                                .overlay(
                                    Image(systemName: project.icon)
                                        .foregroundColor(accentColor)
                                        .font(.system(size: 24))
                                )
                            VStack(alignment: .leading, spacing: 6) {
                                Text(project.name)
                                    .font(.system(size: 20, weight: .heavy))
                                    .foregroundColor(Color.App.textBlack)
                                if !project.desc.isEmpty {
                                    Text(project.desc)
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
                                        .lineSpacing(3)
                                }
                            }
                        }
                        
                        // 收支汇总
                        HStack(spacing: 12) {
                            StatCard(title: "总支出", value: project.totalSpent, color: Color.App.redExpense)
                            StatCard(title: "总收入", value: project.totalIncome, color: Color.App.darkGreen)
                            StatCard(title: "净收益", value: project.totalIncome - project.totalSpent, color: Color.App.darkGreen)
                        }
                        
                        // 预算进度条（同色系渐变）
                        if project.budget > 0 {
                            let progress = min(project.budgetProgress, 1.0)
                            let pctColor: Color = project.budgetProgress >= 1.0 ? Color.App.redExpense :
                                project.budgetProgress >= 0.8 ? Color(hex: "#FFA500") : accentColor
                            
                            VStack(spacing: 8) {
                                HStack {
                                    Text("预算进度")
                                        .font(.system(size: 13, weight: .bold)).foregroundColor(.gray)
                                    Spacer()
                                    Text("\(Int(project.budgetProgress * 100))%")
                                        .font(.system(size: 13, weight: .bold)).foregroundColor(pctColor)
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color(hex: "#F0F0F0")).frame(height: 10)
                                        Capsule()
                                            .fill(LinearGradient(
                                                colors: [Color(hex: colorPair.start), Color(hex: colorPair.end)],
                                                startPoint: .leading, endPoint: .trailing
                                            ))
                                            .frame(width: geo.size.width * progress, height: 10)
                                    }
                                }
                                .frame(height: 10)
                                HStack {
                                    Text("已用 ¥\(project.totalSpent.formatted(.number.precision(.fractionLength(0))))")
                                    Spacer()
                                    Text("预算 ¥\(project.budget.formatted(.number.precision(.fractionLength(0))))")
                                }
                                .font(.system(size: 11, weight: .semibold)).foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(24)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                    .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
                    .padding(.horizontal, 24)
                    
                    // MARK: 账单时间轴
                    VStack(alignment: .leading, spacing: 0) {
                        Text("账单时间轴")
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundColor(Color.App.textBlack)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 16)
                        
                        if groupedTransactions.isEmpty {
                            Text("还没有任何记录，点击 + 记一笔吧！")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 24)
                        } else {
                            ForEach(groupedTransactions, id: \.key) { group in
                                VStack(alignment: .leading, spacing: 0) {
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(Color(hex: project.colorHex))
                                            .frame(width: 10, height: 10)
                                        Text(group.key)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.leading, 24)
                                    .padding(.bottom, 10)
                                    
                                    VStack(spacing: 10) {
                                        ForEach(group.value) { tx in
                                            TimelineTxRow(transaction: tx, accentColor: Color(hex: project.colorHex))
                                                .padding(.horizontal, 24)
                                        }
                                    }
                                    .padding(.bottom, 20)
                                }
                            }
                        }
                    }
                    
                    Spacer().frame(height: 120)
                }
                .padding(.top, 16)
            }
        }
        .background(Color.App.backgroundGray.ignoresSafeArea())
        .navigationBarHidden(true) // 隐藏系统导航栏，使用自定义样式
    }
}

// MARK: - 统计小卡片
struct StatCard: View {
    let title: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
            Text("¥\(abs(value).formatted(.number.precision(.fractionLength(0))))")
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(value < 0 ? Color.App.redExpense : color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Timeline 账单行
struct TimelineTxRow: View {
    let transaction: Transaction
    let accentColor: Color
    
    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color(hex: transaction.categoryColorHex).opacity(0.3))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: transaction.categoryIcon)
                        .foregroundColor(Color(hex: transaction.categoryColorHex))
                        .font(.system(size: 18))
                )
            
            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.note.isEmpty ? transaction.categoryName : transaction.note)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.App.textBlack)
                Text("\(transaction.categoryName) · \(transaction.date.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text("\(transaction.type == .expense ? "-" : "+") ¥\(transaction.amount.formatted(.number.precision(.fractionLength(2))))")
                .font(.system(size: 15, weight: .heavy))
                .foregroundColor(transaction.type == .expense ? Color.App.redExpense : Color.App.darkGreen)
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 3)
    }
}

#Preview {
    NavigationView {
        ProjectDetailView(project: Project(name: "示例项目", icon: "house.fill", colorHex: "#A8E6CF", desc: "这是一个测试项目", budget: 10000))
            .environmentObject(AppStore(modelContext: try! ModelContainer(for: Project.self, Transaction.self, Category.self).mainContext))
    }
}
