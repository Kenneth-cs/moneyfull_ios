import SwiftUI
import SwiftData

struct ProfileView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var storeManager: StoreManager
    @EnvironmentObject var theme: ThemeManager
    @State private var showBudgetSetting = false
    @State private var showExportSheet = false
    @State private var showImportSheet = false
    @State private var showThemePicker = false
    @State private var showCategoryManagement = false
    @State private var showProjectSorting = false
    @State private var showBackTapTutorial = false
    @State private var showMemoryManagement = false
    @State private var showFeedback = false
    @State private var showReminderSetting = false
    @State private var userName: String = UserDefaults.standard.string(forKey: "userName") ?? "钱小满用户"
    @State private var showEditName = false
    @State private var tempName: String = ""
    @State private var showPaywall = false
    @State private var showFuelPackSheet = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false
    
    // 从 AppStore 拿真实统计
    private var activeCount: Int { store.activeProjects.count }
    private var totalTxCount: Int { store.fetchTotalTransactionCount() }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // MARK: Header
                PageHeader(title: "个人中心")
                
                // MARK: 用户信息
                VStack(spacing: 12) {
                    ZStack(alignment: .bottomTrailing) {
                        Circle()
                            .fill(LinearGradient(colors: [Color.App.primaryGreen, Color.App.backgroundGray],
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

                // MARK: Premium 入口
                if storeManager.isPremium {
                    // 已订阅：状态展示
                    VStack(alignment: .leading, spacing: 12) {
                        Text("我的订阅")
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(.gray.opacity(0.8))
                            .kerning(2)
                            .padding(.horizontal, 8)

                        VStack(spacing: 0) {
                            PremiumStatusRow(
                                planTitle: storeManager.currentPlanTitle,
                                expiryText: storeManager.currentPlanExpiry.isEmpty ? "已激活" : storeManager.currentPlanExpiry,
                                onTap: { showPaywall = true }
                            )
                            
                            Divider().padding(.leading, 72).opacity(0.5)
                            
                            RedeemCodeRow(onTap: { storeManager.presentOfferCodeSheet() })
                            
                            Divider().padding(.leading, 72).opacity(0.5)
                            
                            Button { showFuelPackSheet = true } label: {
                                HStack(spacing: 16) {
                                    Circle()
                                        .fill(Color.App.lightOrange.opacity(0.3))
                                        .frame(width: 42, height: 42)
                                        .overlay(
                                            Image(systemName: "bolt.fill")
                                                .foregroundColor(Color.App.darkOrange)
                                                .font(.system(size: 18, weight: .semibold))
                                        )
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("能量饼干")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(Color.App.textBlack)
                                        if storeManager.fuelCredits > 0 {
                                            Text("\(storeManager.fuelCredits) 次 AI 调用额度")
                                                .font(.system(size: 12))
                                                .foregroundColor(.gray)
                                        } else {
                                            Text("购买后获得额外和小满对话次数")
                                                .font(.system(size: 12))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.gray.opacity(0.5))
                                }
                                .contentShape(Rectangle())
                                .padding(16)
                            }
                            .buttonStyle(.plain)
                        }
                        .background(Color.App.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 5)
                    }
                    .padding(.horizontal, 24)
                } else {
                    // 未订阅：升级横幅 + 兑换码入口
                    VStack(spacing: 12) {
                        PremiumUpgradeBanner(onTap: { showPaywall = true })
                        
                        VStack(spacing: 0) {
                            RedeemCodeRow(onTap: { storeManager.presentOfferCodeSheet() })
                            
                            Divider().padding(.leading, 72).opacity(0.5)
                            
                            Button { showFuelPackSheet = true } label: {
                                HStack(spacing: 16) {
                                    Circle()
                                        .fill(Color.App.lightOrange.opacity(0.3))
                                        .frame(width: 42, height: 42)
                                        .overlay(
                                            Image(systemName: "bolt.fill")
                                                .foregroundColor(Color.App.darkOrange)
                                                .font(.system(size: 18, weight: .semibold))
                                        )
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("能量饼干")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(Color.App.textBlack)
                                        Text("购买后获得额外和小满对话次数")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.gray.opacity(0.5))
                                }
                                .contentShape(Rectangle())
                                .padding(16)
                            }
                            .buttonStyle(.plain)
                        }
                        .background(Color.App.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 5)
                    }
                    .padding(.horizontal, 24)
                }

                // MARK: 功能菜单
                VStack(spacing: 16) {

                    // 常用操作（网格）
                    VStack(alignment: .leading, spacing: 4) {
                        Text("常用操作")
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(.gray.opacity(0.8))
                            .kerning(2)
                            .padding(.horizontal, 8)

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 4),
                            spacing: 4
                        ) {
                            MenuGridItem(icon: "hand.tap",
                                         iconBg: Color.App.lightGreen.opacity(0.5),
                                         iconColor: Color.App.darkGreen,
                                         title: "无痛记账") { showBackTapTutorial = true }
                            MenuGridItem(icon: "chart.bar.doc.horizontal",
                                         iconBg: Color.App.primaryGreen.opacity(0.3),
                                         iconColor: Color.App.darkGreen,
                                         title: "月度预算") { showBudgetSetting = true }
                            MenuGridItem(icon: "tag.fill",
                                         iconBg: Color.App.lightGreen.opacity(0.5),
                                         iconColor: Color.App.darkGreen,
                                         title: "分类管理") { showCategoryManagement = true }
                            MenuGridItem(icon: "arrow.up.arrow.down",
                                         iconBg: Color.App.lightYellow.opacity(0.4),
                                         iconColor: Color.App.darkYellow,
                                         title: "项目排序") { showProjectSorting = true }
                            MenuGridItem(icon: "brain",
                                         iconBg: Color.purple.opacity(0.2),
                                         iconColor: .purple,
                                         title: "小满记忆") { showMemoryManagement = true }
                            MenuGridItem(icon: "paintpalette",
                                         iconBg: Color.App.lightYellow.opacity(0.6),
                                         iconColor: Color.App.darkYellow,
                                         title: "主题设置") { showThemePicker = true }
                            MenuGridItem(icon: "bell.fill",
                                         iconBg: Color.App.lightGreen.opacity(0.5),
                                         iconColor: Color.App.darkGreen,
                                         title: "记账提醒") { showReminderSetting = true }
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(12)
                    .background(Color.App.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 5)

                    // 数据管理 + 其他（四格平铺）
                    VStack(alignment: .leading, spacing: 4) {
                        Text("数据管理 · 其他")
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(.gray.opacity(0.8))
                            .kerning(2)
                            .padding(.horizontal, 8)

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 4),
                            spacing: 4
                        ) {
                            MenuGridItem(icon: "arrow.down.doc",
                                         iconBg: Color.App.lightOrange.opacity(0.4),
                                         iconColor: Color.App.darkOrange,
                                         title: "导出数据") { showExportSheet = true }
                            MenuGridItem(icon: "square.and.arrow.down",
                                         iconBg: Color.App.lightGreen.opacity(0.5),
                                         iconColor: Color.App.darkGreen,
                                         title: "导入账单") { showImportSheet = true }
                            MenuGridItem(icon: "questionmark.circle",
                                         iconBg: Color.gray.opacity(0.1),
                                         iconColor: .gray,
                                         title: "帮助反馈") { showFeedback = true }
                            MenuGridItem(icon: "star.fill",
                                         iconBg: Color.App.lightYellow.opacity(0.6),
                                         iconColor: Color.App.darkYellow,
                                         title: "好评支持") { AppRatingManager.shared.openAppStore() }
                            MenuGridItem(icon: "doc.text",
                                         iconBg: Color.App.lightGreen.opacity(0.4),
                                         iconColor: Color.App.darkGreen,
                                         title: "隐私政策") { showPrivacyPolicy = true }
                            MenuGridItem(icon: "doc.plaintext",
                                         iconBg: Color.App.lightOrange.opacity(0.4),
                                         iconColor: Color.App.darkOrange,
                                         title: "用户协议") { showTermsOfService = true }
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(12)
                    .background(Color.App.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 5)

                    // iCloud 同步状态（全宽行）
                    ICloudStatusRow(store: store)
                        .environmentObject(store)
                        .background(Color.App.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 24)
                
                // MARK: 版本信息
                Text("钱小满   ·  每笔都算数 🦫")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray.opacity(0.6))
                    .padding(.top, 8)
                
                Spacer().frame(height: 16)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 110)
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
        // 导出账单
        .sheet(isPresented: $showExportSheet) {
            ExportConfigSheet()
                .environmentObject(store)
        }
        // 导入账单
        .sheet(isPresented: $showImportSheet) {
            ImportConfigSheet()
                .environmentObject(store)
        }
        // 预算设置页面
        .sheet(isPresented: $showBudgetSetting) {
            BudgetSettingView()
        }
        // 分类管理页面
        .sheet(isPresented: $showCategoryManagement) {
            CategoryManagementView()
        }
        // 主题选择弹窗
        .sheet(isPresented: $showThemePicker) {
            ThemePickerView()
        }
        // 项目排序页面
        .sheet(isPresented: $showProjectSorting) {
            ProjectSortingView()
                .environmentObject(store)
        }
        // 无疼记账设置页面
        .sheet(isPresented: $showBackTapTutorial) {
            BackTapTutorialView()
        }
        // AI记忆管理页面
        .sheet(isPresented: $showMemoryManagement) {
            MemoryManagementView()
        }
        // 问题反馈页面
        .sheet(isPresented: $showFeedback) {
            FeedbackSheetView()
        }
        // 记账提醒设置页面
        .sheet(isPresented: $showReminderSetting) {
            ReminderSettingView()
        }
        // Premium 订阅页
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView()
        }
        // 能量饼干页
        .fullScreenCover(isPresented: $showFuelPackSheet) {
            FuelPackSheet()
        }
        // 隐私政策
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        // 用户协议
        .sheet(isPresented: $showTermsOfService) {
            TermsOfServiceView()
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

// MARK: - iCloud 同步状态行
import CloudKit

struct ICloudStatusRow: View {
    @ObservedObject var store: AppStore
    @State private var cloudStatus: CKAccountStatus = .couldNotDetermine
    @State private var isChecking = true

    private var stats: (projectCount: Int, transactionCount: Int, categoryCount: Int) {
        store.dataStats()
    }

    // 根据 iCloud 账号状态返回图标、颜色、标题、风险说明、操作提示
    private var statusConfig: (icon: String, color: Color, title: String, risk: String?, tip: String?) {
        switch cloudStatus {
        case .available:
            return (
                "checkmark.circle.fill",
                Color.App.darkGreen,
                "iCloud 同步已启用",
                nil,
                nil
            )
        case .noAccount:
            return (
                "exclamationmark.triangle.fill",
                .red,
                "未登录 iCloud 账号",
                "⚠️ 数据仅存本机，换机或删除 App 后将无法恢复",
                "前往 设置 > Apple ID 登录，或开启 iCloud"
            )
        case .restricted:
            return (
                "lock.icloud.fill",
                .orange,
                "iCloud 访问受限",
                "⚠️ 家长控制或企业管理限制了 iCloud，数据无法同步",
                "联系设备管理员，或前往 设置 解除限制"
            )
        case .couldNotDetermine, .temporarilyUnavailable:
            return (
                "icloud.slash.fill",
                .gray,
                "iCloud 状态未知",
                "暂时无法确认同步状态，可能是网络问题",
                "请检查网络后点击重试"
            )
        @unknown default:
            return ("questionmark.circle.fill", .gray, "同步状态未知", nil, nil)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                // 状态图标
                Circle()
                    .fill(statusConfig.color.opacity(0.12))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Group {
                            if isChecking {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Image(systemName: "icloud.fill")
                                    .foregroundColor(statusConfig.color)
                                    .font(.system(size: 20, weight: .semibold))
                            }
                        }
                    )

                // 标题 + 数据统计
                VStack(alignment: .leading, spacing: 3) {
                    Text(statusConfig.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.App.textBlack)
                    if cloudStatus == .available {
                        Text("\(stats.projectCount) 个项目 · \(stats.transactionCount) 笔账单已同步")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                // 状态图标（右侧）
                Image(systemName: statusConfig.icon)
                    .foregroundColor(statusConfig.color)
                    .font(.system(size: 20))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, statusConfig.risk != nil ? 8 : 16)

            // 非正常状态：展开说明 + 操作按钮
            if cloudStatus != .available && !isChecking {
                VStack(alignment: .leading, spacing: 8) {
                    if let risk = statusConfig.risk {
                        Text(risk)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(statusConfig.color)
                            .padding(.horizontal, 16)
                    }
                    if let tip = statusConfig.tip {
                        Text(tip)
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 16)
                    }
                    // 操作按钮行
                    HStack(spacing: 10) {
                        if cloudStatus == .noAccount || cloudStatus == .restricted {
                            Button(action: openSettings) {
                                Label("去设置", systemImage: "gear")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(statusConfig.color)
                                    .clipShape(Capsule())
                            }
                        }
                        if cloudStatus == .couldNotDetermine || cloudStatus == .temporarilyUnavailable {
                            Button(action: checkICloudStatus) {
                                Label("重试", systemImage: "arrow.clockwise")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(statusConfig.color)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                }
            }
        }
        .onAppear { checkICloudStatus() }
    }

    private func checkICloudStatus() {
        isChecking = true
        CKContainer.default().accountStatus { status, _ in
            DispatchQueue.main.async {
                self.cloudStatus = status
                self.isChecking = false
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - 本月财务小结
struct MonthSummaryCard: View {
    @ObservedObject var store: AppStore
    
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
        .background(Color.App.cardBackground)
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

// MARK: - 网格菜单项
struct MenuGridItem: View {
    let icon: String
    let iconBg: Color
    let iconColor: Color
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(iconBg)
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.App.textBlack)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                                    AppIconView(name: project.icon, size: 18,
                                                color: Color(hex: project.colorHex))
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
                                    AppIconView(name: project.icon, size: 18,
                                                color: Color(hex: project.colorHex))
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

// MARK: - 主题选择面板
struct ThemePickerView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var theme: ThemeManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 卡皮形象预告
                VStack(spacing: 8) {
                    Text("🦫")
                        .font(.system(size: 60))
                    Text("选一个让眼睛舒适的模式")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(.top, 16)
                
                // 三个选项
                VStack(spacing: 12) {
                    ForEach(ThemeMode.allCases, id: \.rawValue) { mode in
                        Button(action: {
                            theme.mode = mode
                            AnalyticsManager.shared.trackEvent(eventId: "profile_change_theme", eventName: "切换外观主题", params: ["theme_selected": mode.rawValue])
                        }) {
                            HStack(spacing: 16) {
                                Circle()
                                    .fill(themeIconBg(mode))
                                    .frame(width: 52, height: 52)
                                    .overlay(
                                        Image(systemName: mode.icon)
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundColor(themeIconColor(mode))
                                    )
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(mode.displayName)
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(Color.App.textBlack)
                                    Text(themeDesc(mode))
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                if theme.mode == mode {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(Color.App.darkGreen)
                                }
                            }
                            .padding(18)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color.App.cardBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24)
                                            .stroke(theme.mode == mode ? Color.App.primaryGreen : Color.clear, lineWidth: 2.5)
                                    )
                            )
                            .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
            }
            .background(Color.App.backgroundGray.ignoresSafeArea())
            .navigationTitle("主题设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { presentationMode.wrappedValue.dismiss() }
                        .font(.system(size: 16, weight: .bold))
                }
            }
        }
    }
    
    private func themeIconBg(_ mode: ThemeMode) -> Color {
        switch mode {
        case .system: return Color.App.primaryGreen.opacity(0.2)
        case .light:  return Color.App.lightYellow.opacity(0.4)
        case .dark:   return Color.App.darkGreen.opacity(0.15)
        }
    }
    
    private func themeIconColor(_ mode: ThemeMode) -> Color {
        switch mode {
        case .system: return Color.App.darkGreen
        case .light:  return Color.App.darkYellow
        case .dark:   return Color.App.darkGreen
        }
    }
    
    private func themeDesc(_ mode: ThemeMode) -> String {
        switch mode {
        case .system: return "随系统自动切换，省心省事"
        case .light:  return "清爽明亮，白天使用更舒适"
        case .dark:   return "护眼深色，夜间使用很友好"
        }
    }
}

struct ProjectSortingView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var store: AppStore
    @State private var projects: [Project] = []

    var body: some View {
        NavigationView {
            List {
                ForEach(projects) { project in
                    HStack(spacing: 14) {
                        Circle()
                            .fill(Color(hex: project.colorHex).opacity(0.3))
                            .frame(width: 40, height: 40)
                            .overlay(
                                AppIconView(name: project.icon, size: 18,
                                            color: Color(hex: project.colorHex))
                            )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(project.name)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Color.App.textBlack)
                            if project.isPinned {
                                Text("已置顶")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color.App.darkGreen)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .onMove { source, destination in
                    projects.move(fromOffsets: source, toOffset: destination)
                    store.updateProjectSortOrder(projects)
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("项目排序")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        store.updateProjectSortOrder(projects)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 16, weight: .bold))
                }
            }
        }
        .onAppear {
            projects = store.activeProjects
        }
    }
}

// MARK: - 问题反馈页面
struct FeedbackSheetView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var showSaveAlert = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 顶部图标
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 40))
                            .foregroundColor(Color.App.darkGreen)
                        
                        Text("遇到问题？联系小助手")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.App.textBlack)
                        
                        Text("添加微信时请备注：钱小满")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 16)

                    // 二维码图片（长按可保存）
                    Image("contact_qr")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
                        .contextMenu {
                            Button {
                                saveImageToAlbum()
                            } label: {
                                Label("保存图片", systemImage: "square.and.arrow.down")
                            }
                        }
                    
                    Text("长按图片可保存到相册")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray.opacity(0.6))

                    // 温馨提示
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color.App.darkYellow)
                            Text("反馈小贴士")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color.App.textBlack)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            tipRow(text: "描述遇到的问题或建议")
                            tipRow(text: "如有截图可一并发送，方便定位")
                            tipRow(text: "小助手通常 24 小时内回复")
                        }
                    }
                    .padding(16)
                    .background(Color.App.lightYellow.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 4)

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .background(Color.App.backgroundGray.ignoresSafeArea())
            .navigationTitle("问题反馈")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
        .alert("已保存", isPresented: $showSaveAlert) {
            Button("好的", role: .cancel) {}
        } message: {
            Text("图片已保存到相册")
        }
    }

    private func tipRow(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.App.darkGreen.opacity(0.3))
                .frame(width: 6, height: 6)
                .padding(.top, 5)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.App.textBlack.opacity(0.7))
        }
    }

    private func saveImageToAlbum() {
        guard let image = UIImage(named: "contact_qr") else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        showSaveAlert = true
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppStore(modelContext: try! ModelContainer(for: Project.self, Transaction.self, Category.self, ChatHistory.self, MemoryRule.self).mainContext))
        .environmentObject(StoreManager.shared)
        .environmentObject(ThemeManager())
}
