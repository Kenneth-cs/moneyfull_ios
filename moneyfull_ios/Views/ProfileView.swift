import SwiftUI
import SwiftData

struct ProfileView: View {
    @EnvironmentObject var store: AppStore
    @State private var showBudgetSetting = false
    @State private var showExportAlert = false
    @State private var userName: String = UserDefaults.standard.string(forKey: "userName") ?? "钱小满用户"
    @State private var showEditName = false
    @State private var tempName: String = ""
    
    // 从 AppStore 拿真实统计
    private var activeCount: Int { store.activeProjects.count }
    private var totalTxCount: Int { store.recentTransactions.count }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // MARK: Header
                HStack {
                    HStack(spacing: 8) {
                        AppLogo()
                        Text("个人中心")
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
                
                // MARK: 用户信息
                VStack(spacing: 12) {
                    ZStack(alignment: .bottomTrailing) {
                        Circle()
                            .fill(LinearGradient(colors: [Color.App.primaryGreen, .white],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 128, height: 128)
                            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 5)
                            .overlay(
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundColor(Color.App.primaryGreen.opacity(0.8))
                                    .clipShape(Circle())
                                    .padding(8)
                            )
                        
                        // 编辑按钮
                        Button(action: {
                            tempName = userName
                            showEditName = true
                        }) {
                            Circle()
                                .fill(Color.App.primaryGreen)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "pencil")
                                        .foregroundColor(Color.App.darkGreen)
                                        .font(.system(size: 16, weight: .bold))
                                )
                                .overlay(Circle().stroke(Color.App.backgroundGray, lineWidth: 4))
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        }
                        .offset(x: -4, y: -4)
                    }
                    
                    Text(userName)
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundColor(Color.App.textBlack)
                    
                    Text("记录每一笔，掌控每一天")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 8)
                
                // MARK: 真实数据统计卡片
                HStack(spacing: 16) {
                    ProfileStatCard(
                        icon: "folder.fill.badge.gearshape",
                        value: "\(activeCount)",
                        label: "活跃项目",
                        bgColor: Color.App.primaryGreen.opacity(0.2),
                        fgColor: Color.App.darkGreen
                    )
                    ProfileStatCard(
                        icon: "book.closed.fill",
                        value: "\(totalTxCount)",
                        label: "总账目",
                        bgColor: Color.App.lightYellow.opacity(0.3),
                        fgColor: Color.App.darkYellow
                    )
                }
                .padding(.horizontal, 24)
                
                // MARK: 本月财务小结
                MonthSummaryCard(store: store)
                    .padding(.horizontal, 24)
                
                // MARK: 功能菜单
                VStack(alignment: .leading, spacing: 16) {
                    Text("账户管理")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.gray.opacity(0.8))
                        .kerning(2)
                        .padding(.horizontal, 8)
                    
                    VStack(spacing: 0) {
                        MenuItem(icon: "chart.bar.doc.horizontal",
                                 iconBg: Color.App.primaryGreen.opacity(0.3),
                                 iconColor: Color.App.darkGreen,
                                 title: "月度预算设置") {
                            showBudgetSetting = true
                        }
                        MenuItem(icon: "arrow.down.doc",
                                 iconBg: Color.App.lightOrange.opacity(0.4),
                                 iconColor: Color.App.darkOrange,
                                 title: "导出数据") {
                            showExportAlert = true
                        }
                        MenuItem(icon: "paintpalette",
                                 iconBg: Color.App.lightYellow.opacity(0.6),
                                 iconColor: Color.App.darkYellow,
                                 title: "主题设置") {}
                        MenuItem(icon: "questionmark.circle",
                                 iconBg: Color.gray.opacity(0.1),
                                 iconColor: .gray,
                                 title: "帮助与反馈",
                                 hasBorder: false) {}
                    }
                    .padding(8)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                    .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 24)
                
                // MARK: 版本信息
                Text("钱小满 v1.0  ·  每笔都算数 🦫")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray.opacity(0.6))
                    .padding(.top, 8)
                
                Spacer().frame(height: 120)
            }
        }
        .background(Color.App.backgroundGray.ignoresSafeArea())
        // 改名弹窗
        .alert("修改昵称", isPresented: $showEditName) {
            TextField("请输入昵称", text: $tempName)
            Button("确定") {
                if !tempName.trimmingCharacters(in: .whitespaces).isEmpty {
                    userName = tempName
                    UserDefaults.standard.set(userName, forKey: "userName")
                }
            }
            Button("取消", role: .cancel) {}
        }
        // 导出提示
        .alert("导出数据", isPresented: $showExportAlert) {
            Button("好的", role: .cancel) {}
        } message: {
            Text("数据导出功能正在开发中，敬请期待～")
        }
        // 预算设置页面
        .sheet(isPresented: $showBudgetSetting) {
            BudgetSettingView()
        }
    }
}

// MARK: - 统计数字卡片
struct ProfileStatCard: View {
    let icon: String
    let value: String
    let label: String
    let bgColor: Color
    let fgColor: Color
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(fgColor)
            Text(value)
                .font(.system(size: 36, weight: .black))
                .foregroundColor(fgColor)
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(fgColor.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 32))
    }
}

// MARK: - 本月财务小结
struct MonthSummaryCard: View {
    let store: AppStore
    
    private var saving: Double { store.monthlyIncome - store.monthlyExpense }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("本月财务小结")
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(Color.App.textBlack)
            
            HStack(spacing: 16) {
                summaryItem(title: "支出", value: store.monthlyExpense, color: Color.App.redExpense)
                Divider().frame(height: 40)
                summaryItem(title: "收入", value: store.monthlyIncome, color: Color.App.darkGreen)
                Divider().frame(height: 40)
                summaryItem(title: "储蓄", value: saving, color: saving >= 0 ? Color.App.darkGreen : Color.App.redExpense)
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 5)
    }
    
    @ViewBuilder
    private func summaryItem(title: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
            Text("¥\(Int(abs(value)))")
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 菜单行（带点击回调）
struct MenuItem: View {
    let icon: String
    let iconBg: Color
    let iconColor: Color
    let title: String
    var hasBorder: Bool = true
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Circle()
                    .fill(iconBg)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: icon)
                            .foregroundColor(iconColor)
                            .font(.system(size: 20, weight: .semibold))
                    )
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.App.textBlack)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(Color.gray.opacity(0.5))
                    .font(.system(size: 16, weight: .semibold))
            }
            .padding(16)
            .overlay(
                Group {
                    if hasBorder {
                        Divider()
                            .background(Color.gray.opacity(0.08))
                            .padding(.leading, 80)
                    }
                },
                alignment: .bottom
            )
        }
    }
}

// MARK: - 月度预算设置页
struct BudgetSettingView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(store.activeProjects.filter { $0.budget > 0 }) { project in
                        HStack(spacing: 14) {
                            Circle()
                                .fill(Color(hex: project.colorHex).opacity(0.3))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: project.icon)
                                        .foregroundColor(Color(hex: project.colorHex))
                                        .font(.system(size: 16))
                                )
                            VStack(alignment: .leading, spacing: 4) {
                                Text(project.name)
                                    .font(.system(size: 15, weight: .bold))
                                HStack {
                                    Text("已用 ¥\(project.totalSpent.formatted(.number.precision(.fractionLength(0))))")
                                    Text("/")
                                    Text("预算 ¥\(project.budget.formatted(.number.precision(.fractionLength(0))))")
                                }
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            }
                            Spacer()
                            Text("\(Int(project.budgetProgress * 100))%")
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundColor(project.budgetProgress >= 1 ? Color.App.redExpense : Color.App.darkGreen)
                        }
                        .padding(.vertical, 6)
                    }
                } header: {
                    Text("设有预算的项目")
                }
                
                Section {
                    ForEach(store.activeProjects.filter { $0.budget == 0 }) { project in
                        HStack(spacing: 14) {
                            Circle()
                                .fill(Color(hex: project.colorHex).opacity(0.3))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: project.icon)
                                        .foregroundColor(Color(hex: project.colorHex))
                                        .font(.system(size: 16))
                                )
                            Text(project.name)
                                .font(.system(size: 15, weight: .bold))
                            Spacer()
                            Text("无预算")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 6)
                    }
                } header: {
                    Text("未设预算的项目（可在项目详情中设置）")
                }
            }
            .navigationTitle("预算管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppStore(modelContext: try! ModelContainer(for: Project.self, Transaction.self, Category.self).mainContext))
}
