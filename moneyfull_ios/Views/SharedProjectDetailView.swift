import SwiftUI

struct SharedProjectDetailView: View {
    let project: JoinedSharedProject
    /// 实时成员列表，比 project.memberNames 快照更新
    @State private var liveMembers: [String]

    init(project: JoinedSharedProject) {
        self.project = project
        _liveMembers = State(initialValue: project.memberNames)
    }
    @State private var transactions: [SharedTransaction] = []
    @State private var isLoading = false
    @State private var showAddSheet = false
    @State private var errorMessage: String?
    @State private var showInviteCode = false
    @State private var showLeaveAlert = false
    @Environment(\.dismiss) private var dismiss

    // Q2：改名
    @State private var showRenameSheet = false
    @State private var renameText = ""
    @State private var isRenaming = false
    @State private var renameError: String?

    // 修改我的昵称（项目级别）
    @State private var showNicknameSheet = false
    @State private var nicknameText = ""

    // 统计帮助气泡
    @State private var showStatsTip = false

    // 分享账单报告
    @State private var showReportShareSheet = false
    private var reportShareURL: URL {
        URL(string: "https://originapex.cn/shared-api/\(project.inviteCode)/report")!
    }
    private var reportShareText: String {
        "查看「\(project.name)」共享账单明细 👉 https://originapex.cn/shared-api/\(project.inviteCode)/report"
    }

    // Q3：流水行详情
    @State private var selectedTransaction: SharedTransaction? = nil

    // Q4：Tab 切换 + 统计数据
    @State private var selectedTabIndex = 0   // 0=流水记录 1=统计
    @State private var statsData: ProjectStatsResponse? = nil
    @State private var isLoadingStats = false

    private var totalAmount: Double {
        transactions.filter { !$0.isDeleted }.reduce(0) { $0 + $1.amount }
    }

    private var memberPayments: [String: Double] {
        Dictionary(grouping: transactions.filter { !$0.isDeleted }) { $0.displayPayerName }
            .mapValues { $0.reduce(0) { $0 + abs($1.amount) } }
    }

    private var dateRangeText: String {
        let activeTxs = transactions.filter { !$0.isDeleted }
        guard let first = activeTxs.min(by: { $0.transactionAt < $1.transactionAt }),
              let last = activeTxs.max(by: { $0.transactionAt < $1.transactionAt }) else {
            return "\(liveMembers.count)位成员"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.M.d"
        let firstStr = formatter.string(from: first.transactionAt)
        let lastStr = formatter.string(from: last.transactionAt)
        if firstStr == lastStr {
            return "\(firstStr) · \(liveMembers.count)位成员"
        }
        return "\(firstStr) - \(lastStr) · \(liveMembers.count)位成员"
    }

    private var groupedTransactions: [(String, [SharedTransaction])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        let groups = Dictionary(grouping: transactions.filter { !$0.isDeleted }) { tx -> String in
            let date = tx.transactionAt
            if Calendar.current.isDateInToday(date) { return "今天" }
            if Calendar.current.isDateInYesterday(date) { return "昨天" }
            let monthDayFormatter = DateFormatter()
            monthDayFormatter.dateFormat = "M月d日"
            return monthDayFormatter.string(from: date)
        }
        
        // 简单按组中第一条记录的时间排序
        return groups.sorted { (group1, group2) -> Bool in
            let date1 = group1.value.first?.transactionAt ?? Date.distantPast
            let date2 = group2.value.first?.transactionAt ?? Date.distantPast
            return date1 > date2
        }.map { ($0.key, $0.value.sorted { $0.transactionAt > $1.transactionAt }) }
    }

    private var displayTransactions: [(String, [SharedTransaction])] {
        return groupedTransactions
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                headerSection
                statsCard
                transactionListSection
            }
            .padding(.top, 12)
        }
        .background(Color(hex: "#F2F2F7").ignoresSafeArea())
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        renameText = project.name
                        renameError = nil
                        showRenameSheet = true
                    } label: { Label("修改账本名称", systemImage: "pencil") }
                    Button {
                        nicknameText = project.participantName
                        showNicknameSheet = true
                    } label: { Label("修改我的昵称", systemImage: "person.crop.circle") }
                    Button {
                        AnalyticsManager.shared.trackSharedInviteViewPanel(source: "menu")
                        showInviteCode = true
                    } label: { Label("邀请成员", systemImage: "person.badge.plus") }
                    Button {
                        Task { await refreshTransactions() }
                    } label: { Label("刷新同步", systemImage: "arrow.clockwise") }
                    Button(role: .destructive) { showLeaveAlert = true } label: {
                        Label("退出共享账本", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        // Q2：改名 sheet
        .sheet(isPresented: $showRenameSheet) {
            NavigationStack {
                Form {
                    Section {
                        TextField("账本名称", text: $renameText)
                    }
                    if let err = renameError {
                        Section { Text(err).foregroundColor(.red) }
                    }
                }
                .navigationTitle("修改名称")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showRenameSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            guard !renameText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            isRenaming = true
                            Task {
                                do {
                                    try await SharedProjectService.shared.renameProject(
                                        inviteCode: project.inviteCode,
                                        newName: renameText.trimmingCharacters(in: .whitespaces)
                                    )
                                    await MainActor.run { showRenameSheet = false }
                                } catch {
                                    await MainActor.run {
                                        renameError = error.localizedDescription
                                        isRenaming = false
                                    }
                                }
                            }
                        }
                        .disabled(renameText.trimmingCharacters(in: .whitespaces).isEmpty || isRenaming)
                    }
                }
            }
            .presentationDetents([.height(200)])
        }
        .sheet(isPresented: $showAddSheet, onDismiss: {
            Task { await refreshTransactions() }
        }) {
            AddRecordView(sharedProject: project)
        }
        // Q3：流水详情 sheet
        .sheet(item: $selectedTransaction) { tx in
            SharedTransactionDetailSheet(
                transaction: tx,
                inviteCode: project.inviteCode,
                onDeleted: { deletedId in
                    transactions.removeAll { $0.id == deletedId }
                    selectedTransaction = nil
                },
                onUpdated: { updatedTx in
                    if let idx = transactions.firstIndex(where: { $0.id == updatedTx.id }) {
                        transactions[idx] = updatedTx
                    }
                    selectedTransaction = nil
                }
            )
        }
        .sheet(isPresented: $showInviteCode) {
            ShareInviteCodeView(project: CreateProjectResponse(
                projectId: project.projectId,
                inviteCode: project.inviteCode,
                name: project.name
            ))
        }
        // 分享账单报告
        .sheet(isPresented: $showReportShareSheet) {
            ShareSheet(activityItems: [reportShareURL, reportShareText])
                .onDisappear {
                    AnalyticsManager.shared.trackShareSharedProjectShared(shareMethod: "system_sheet")
                }
        }
        // 修改我的昵称 sheet（项目级别，不影响其他项目）
        .sheet(isPresented: $showNicknameSheet) {
            NavigationStack {
                Form {
                    Section {
                        TextField("我的昵称", text: $nicknameText)
                            .autocorrectionDisabled()
                    } footer: {
                        Text("昵称只在「\(project.name)」中生效，不影响其他共享账本")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .navigationTitle("修改我的昵称")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showNicknameSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            let trimmed = nicknameText.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty else { return }
                            SharedProjectService.shared.updateMyNickname(
                                inviteCode: project.inviteCode,
                                nickname: trimmed
                            )
                            // 同步更新全局昵称（作为下次建新项目的默认值）
                            SharedProjectService.shared.myNickname = trimmed
                            showNicknameSheet = false
                        }
                        .disabled(nicknameText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .presentationDetents([.height(240)])
        }
        .alert("退出确认", isPresented: $showLeaveAlert) {
            Button("取消", role: .cancel) {}
            Button("退出", role: .destructive) {
                Task {
                    await leaveProject()
                }
            }
        } message: {
            Text("确定要退出「\(project.name)」吗？退出后将无法查看此账本的流水。")
        }
        .task {
            await refreshTransactions()
        }
        .onAppear {
            AnalyticsManager.shared.trackSharedProjectViewDetail(memberCount: liveMembers.count)
        }
        .refreshable {
            await refreshTransactions()
        }
        // 写入成功通知：服务器确认保存后立即刷新，比 onDismiss 更精准
        .onReceive(NotificationCenter.default.publisher(for: .sharedTransactionDidWrite)) { notification in
            guard let projectId = notification.userInfo?["projectId"] as? String,
                  projectId == project.projectId else { return }
            Task {
                await refreshTransactions()
                await loadStats()   // 流水变了，统计也要同步刷新
            }
        }
    }

    // 卡片 1：顶部项目信息（背景图 + 成员头像）
    private var headerSection: some View {
        ZStack(alignment: .topLeading) {
            // Banner 背景图
            Image("shared_banner")
                .resizable()
                .scaledToFill()
                .frame(height: 160)
                .clipped()
                .cornerRadius(20)

            // 左侧信息区 (重新设计的纯净排版)
            VStack(alignment: .leading, spacing: 20) {
                // 标题与日期
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundColor(Color(hex: "#123524"))
                    Text(dateRangeText)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#2C5A43").opacity(0.85))
                }

                // 成员头像与添加按钮
                HStack(spacing: 14) {
                    let displayMembers = Array(liveMembers.prefix(4))
                    ForEach(displayMembers.indices, id: \.self) { index in
                        let name = displayMembers[index]
                        VStack(spacing: 6) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 40, height: 40)
                                .shadow(color: Color(hex: "#2E8B57").opacity(0.15), radius: 5, x: 0, y: 2)
                                .overlay(
                                    Text(String(name.prefix(1)))
                                        .font(.system(size: 15, weight: .heavy))
                                        .foregroundColor(Color(hex: "#2E8B57"))
                                )
                            Text(name)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(hex: "#2C5A43"))
                                .lineLimit(1)
                                .frame(width: 44)
                        }
                    }
                    // 邀请按钮 (显眼的白底绿标)
                    Button(action: {
                        AnalyticsManager.shared.trackSharedInviteViewPanel(source: "header")
                        showInviteCode = true
                    }) {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 40, height: 40)
                                .shadow(color: Color(hex: "#2E8B57").opacity(0.15), radius: 5, x: 0, y: 2)
                                .overlay(
                                    Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(Color(hex: "#2E8B57"))
                                )
                            Text("邀请")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(hex: "#2C5A43"))
                        }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)

            // 右上角分享 icon（轻量化白底绿标）
            Button {
                AnalyticsManager.shared.trackShareSharedProjectClick()
                showReportShareSheet = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "#2E8B57"))
                    .frame(width: 32, height: 32)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(14)
        }
        .padding(.horizontal, 16)
    }

    private var memberStatsSection: some View { EmptyView() }

    // 卡片 2：总支出 + 成员分摊 + 记一笔按钮
    private var statsCard: some View {
        VStack(spacing: 20) {
            // 总支出行
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("总支出")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)
                    Text("¥ \(totalAmount, specifier: "%.0f")")
                        .font(.system(size: 36, weight: .heavy))
                        .foregroundColor(Color.App.textBlack)
                }
                Spacer()
            }

            // 成员支付概览（3 列均分）
            HStack(spacing: 0) {
                let membersToDisplay = Array(liveMembers.prefix(3)).map { ($0, memberPayments[$0] ?? 0) }
                ForEach(membersToDisplay.indices, id: \.self) { index in
                    let item = membersToDisplay[index]
                    VStack(spacing: 6) {
                        Text("\(item.0)支付")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        Text("¥ \(item.1, specifier: "%.0f")")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color.App.textBlack)
                    }
                    .frame(maxWidth: .infinity)
                    if index < membersToDisplay.count - 1 {
                        Divider().frame(height: 28)
                    }
                }
            }

            // 记一笔按钮
            Button(action: {
                AnalyticsManager.shared.trackSharedRecordClickAdd()
                showAddSheet = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 20))
                    Text("记一笔").font(.system(size: 18, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color(hex: "#2E8B57"))
                .clipShape(RoundedRectangle(cornerRadius: 27))
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .padding(.horizontal, 16)
    }

    private var transactionListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tab 切换区
            HStack(spacing: 20) {
                // 流水记录 tab
                Button(action: { selectedTabIndex = 0 }) {
                    VStack(spacing: 6) {
                        Text("流水记录")
                            .font(.system(size: 16, weight: selectedTabIndex == 0 ? .bold : .medium))
                            .foregroundColor(selectedTabIndex == 0 ? Color.App.textBlack : .gray)
                        Capsule()
                            .fill(selectedTabIndex == 0 ? Color(hex: "#2E8B57") : Color.clear)
                            .frame(width: 24, height: 3)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                // 统计 tab + 问号（紧邻，4pt 间距）
                HStack(alignment: .top, spacing: 4) {
                    Button(action: {
                        selectedTabIndex = 1
                        if statsData == nil { Task { await loadStats() } }
                        Task { await loadStats() }  // 每次切入统计 tab 都刷新，保证数据最新
                    }) {
                        VStack(spacing: 6) {
                            Text("统计")
                                .font(.system(size: 16, weight: selectedTabIndex == 1 ? .bold : .medium))
                                .foregroundColor(selectedTabIndex == 1 ? Color.App.textBlack : .gray)
                            Capsule()
                                .fill(selectedTabIndex == 1 ? Color(hex: "#2E8B57") : Color.clear)
                                .frame(width: 24, height: 3)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button { showStatsTip = true } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 13))
                            .foregroundColor(.gray.opacity(0.5))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 2)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .sheet(isPresented: $showStatsTip) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("💡 统计计算说明")
                            .font(.system(size: 16, weight: .bold))
                        Spacer()
                        Button { showStatsTip = false } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.gray.opacity(0.5))
                        }
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 8) {
                            Text("付了").font(.system(size: 13, weight: .semibold)).foregroundColor(Color(hex: "#2E8B57")).frame(width: 36, alignment: .leading)
                            Text("该成员作为付款方的累计金额（实际掏钱的部分）")
                                .font(.system(size: 13)).foregroundColor(.secondary)
                        }
                        HStack(alignment: .top, spacing: 8) {
                            Text("消费").font(.system(size: 13, weight: .semibold)).foregroundColor(Color(hex: "#E05C5C")).frame(width: 36, alignment: .leading)
                            Text("该成员参与的账单按参与人数平摊后的累计金额")
                                .font(.system(size: 13)).foregroundColor(.secondary)
                        }
                        HStack(alignment: .top, spacing: 8) {
                            Text("应收").font(.system(size: 13, weight: .semibold)).foregroundColor(Color(hex: "#2E8B57")).frame(width: 36, alignment: .leading)
                            Text("付了 > 消费 → 其他成员欠 TA 的金额")
                                .font(.system(size: 13)).foregroundColor(.secondary)
                        }
                        HStack(alignment: .top, spacing: 8) {
                            Text("应补").font(.system(size: 13, weight: .semibold)).foregroundColor(Color(hex: "#E05C5C")).frame(width: 36, alignment: .leading)
                            Text("付了 < 消费 → TA 需要补给其他成员的金额")
                                .font(.system(size: 13)).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(24)
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            if selectedTabIndex == 0 {
                // ── 流水记录 ──
                if isLoading && transactions.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding()
                } else if transactions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 36))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("还没有任何记录")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.gray)
                        Text("点击下方「记一笔」开始记账")
                            .font(.system(size: 13))
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(displayTransactions, id: \.0) { group in
                            VStack(alignment: .leading, spacing: 0) {
                                Text(group.0)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                VStack(spacing: 0) {
                                    ForEach(group.1) { transaction in
                                        SharedTransactionRow(transaction: transaction, memberCount: liveMembers.count)
                                            .contentShape(Rectangle())
                                            .onTapGesture { selectedTransaction = transaction }
                                            .swipeActions(edge: .trailing) {
                                                if transaction.deviceId == SharedProjectService.shared.deviceId {
                                                    Button(role: .destructive) {
                                                        Task { await deleteTransaction(transaction) }
                                                    } label: { Label("删除", systemImage: "trash") }
                                                }
                                            }
                                        if transaction.id != group.1.last?.id {
                                            Divider().padding(.leading, 76)
                                        }
                                    }
                                }
                                .background(Color.white)
                            }
                        }
                    }
                }
            } else {
                // ── 统计 ──
                statsTabView
            }
        }
        .background(Color.white)
        .cornerRadius(20)
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    // Q4：统计 Tab 内容
    private var statsTabView: some View {
        VStack(spacing: 0) {
            if isLoadingStats {
                ProgressView().frame(maxWidth: .infinity).padding(40)
            } else if let stats = statsData {
                VStack(spacing: 0) {
                    // 列标题
                    HStack(spacing: 0) {
                        Color.clear.frame(width: 80)
                        Text("付了").font(.system(size: 11)).foregroundColor(.gray).frame(maxWidth: .infinity)
                        Text("消费").font(.system(size: 11)).foregroundColor(.gray).frame(maxWidth: .infinity)
                        Text("结算").font(.system(size: 11)).foregroundColor(.gray).frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                    Divider()

                    ForEach(stats.memberStats, id: \.participantName) { member in
                        let balance = member.totalPaid - member.totalConsumed
                        HStack(spacing: 0) {
                            // 头像 + 名字
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color(hex: "#F0F7F4"))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Text(String(member.participantName.prefix(1)))
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color(hex: "#2E8B57"))
                                    )
                                Text(member.participantName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color.App.textBlack)
                                    .lineLimit(1)
                            }
                            .frame(width: 80, alignment: .leading)

                            // 付了
                            Text("¥\(String(format: "%.2f", member.totalPaid))")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.App.textBlack)
                                .frame(maxWidth: .infinity)

                            // 消费
                            Text("¥\(String(format: "%.2f", member.totalConsumed))")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.App.textBlack)
                                .frame(maxWidth: .infinity)

                            // 结算（应收/应补）
                            VStack(spacing: 2) {
                                Text(balance >= 0 ? "+¥\(String(format: "%.2f", balance))" : "-¥\(String(format: "%.2f", abs(balance)))")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(balance >= 0 ? Color(hex: "#2E8B57") : Color(hex: "#E05C5C"))
                                Text(balance >= 0 ? "应收" : "应补")
                                    .font(.system(size: 10))
                                    .foregroundColor(balance >= 0 ? Color(hex: "#2E8B57") : Color(hex: "#E05C5C"))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        if member.participantName != stats.memberStats.last?.participantName {
                            Divider().padding(.leading, 104)
                        }
                    }
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 32))
                        .foregroundColor(.gray.opacity(0.4))
                    Text("暂无统计数据")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    Button("重新加载") { Task { await loadStats() } }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "#2E8B57"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
    }

    private func refreshTransactions() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await SharedProjectService.shared.fetchTransactions(
                inviteCode: project.inviteCode,
                since: project.lastSyncTime
            )
            transactions = response.transactions
                .filter { !$0.isDeleted }
                .sorted { $0.transactionAt > $1.transactionAt }

            // 更新同步时间
            if let serverTime = ISO8601DateFormatter().date(from: response.serverTime) {
                var projects = SharedProjectService.shared.joinedProjects
                if let index = projects.firstIndex(where: { $0.projectId == project.projectId }) {
                    projects[index].lastSyncTime = serverTime
                    SharedProjectService.shared.joinedProjects = projects
                }
            }
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
        }

        // 顺带刷新成员列表（忽略失败，不影响主流程）
        if let info = try? await SharedProjectService.shared.fetchProjectInfo(inviteCode: project.inviteCode) {
            let members = info.members.map { $0.participantName }
            liveMembers = members
            // 同步写回本地缓存，下次打开时成员数量正确
            var projects = SharedProjectService.shared.joinedProjects
            if let index = projects.firstIndex(where: { $0.projectId == project.projectId }) {
                projects[index].memberNames = members
                SharedProjectService.shared.joinedProjects = projects
            }
        }

        isLoading = false
    }

    private func loadStats() async {
        isLoadingStats = true
        defer { isLoadingStats = false }
        do {
            statsData = try await SharedProjectService.shared.fetchStats(inviteCode: project.inviteCode)
        } catch {
            print("加载统计失败: \(error)")
        }
    }

    private func deleteTransaction(_ transaction: SharedTransaction) async {
        do {
            try await SharedProjectService.shared.deleteTransaction(
                inviteCode: project.inviteCode,
                transactionId: transaction.id
            )
            transactions.removeAll { $0.id == transaction.id }
        } catch {
            errorMessage = "删除失败: \(error.localizedDescription)"
        }
    }

    private func leaveProject() async {
        do {
            try await SharedProjectService.shared.leaveProject(inviteCode: project.inviteCode)
            // 退出成功后上报埋点
            AnalyticsManager.shared.trackSharedProjectLeave(isCreator: false)
            dismiss()
        } catch {
            errorMessage = "退出失败: \(error.localizedDescription)"
        }
    }
}

// MARK: - 圆角扩展
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - 流水行视图
struct SharedTransactionRow: View {
    let transaction: SharedTransaction
    let memberCount: Int

    var body: some View {
        HStack(spacing: 16) {
            // 左侧圆形分类图标
            Circle()
                .fill(Color(hex: "#F5E6D3")) // 假数据颜色
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: getIcon(for: transaction.category))
                        .foregroundColor(Color(hex: "#D4A373"))
                )

            // 中间标题 + 日期 + 参与人
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.note?.isEmpty == false ? transaction.note! : (transaction.category ?? "未分类"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.App.textBlack)
                
                Text("\(transaction.displayPayerName)支付 · \(transaction.displayParticipantsText)")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }

            Spacer()

            // 右侧金额
            Text(String(format: "%@¥%.2f", transaction.amount > 0 ? "+" : "", abs(transaction.amount)))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(transaction.amount > 0 ? Color.App.primaryGreen : Color.App.textBlack)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
    
    private func getIcon(for category: String?) -> String {
        switch category {
        case "餐饮", "吃喝": return "fork.knife"
        case "交通", "出行": return "car.fill"
        case "购物", "居家": return "bag.fill"
        case "娱乐": return "film.fill"
        case "医疗": return "cross.case.fill"
        case "教育", "成长": return "book.fill"
        case "人情": return "gift.fill"
        case "工资": return "banknote.fill"
        default: return "tag.fill"
        }
    }
}

// MARK: - 流水详情/编辑 Sheet（Q3）
struct SharedTransactionDetailSheet: View {
    let transaction: SharedTransaction
    let inviteCode: String
    var onDeleted: (String) -> Void
    var onUpdated: (SharedTransaction) -> Void

    @Environment(\.dismiss) private var dismiss
    private var isOwn: Bool { transaction.deviceId == SharedProjectService.shared.deviceId }

    // 编辑状态
    @State private var editAmount: String = ""
    @State private var editNote: String = ""
    @State private var editCategory: String = ""
    @State private var editDate: Date = Date()
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var showDeleteAlert = false
    @State private var errorMessage: String?

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy年M月d日 HH:mm"; return f
    }()
    private let categories = ["餐饮","购物","交通","娱乐","医疗","教育","居住","人情","收入","其他"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // ── 金额卡（渐变背景 + 分类图标）──
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(LinearGradient(
                                colors: transaction.amount > 0
                                    ? [Color(hex: "#2E8B57"), Color(hex: "#4CAF50")]
                                    : [Color(hex: "#23303D"), Color(hex: "#2C3E50")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))

                        VStack(spacing: 12) {
                            // 分类图标
                            Circle()
                                .fill(Color.white.opacity(0.18))
                                .frame(width: 52, height: 52)
                                .overlay(
                                    Image(systemName: txCategoryIcon)
                                        .font(.system(size: 22, weight: .medium))
                                        .foregroundColor(.white)
                                )

                            // 金额（编辑时变 TextField）
                            if isEditing {
                                TextField("金额", text: $editAmount)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 40, weight: .heavy))
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.white)
                            } else {
                                Text(String(format: "%@¥%.2f",
                                            transaction.amount > 0 ? "+" : "",
                                            abs(transaction.amount)))
                                    .font(.system(size: 40, weight: .heavy))
                                    .foregroundColor(.white)
                            }

                            // 分类标签
                            Text(isEditing ? editCategory : (transaction.category ?? "未分类"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 12).padding(.vertical, 4)
                                .background(Color.white.opacity(0.18))
                                .clipShape(Capsule())
                        }
                        .padding(.vertical, 28)
                    }
                    .frame(maxWidth: .infinity)

                    // ── 字段卡 ──
                    VStack(spacing: 0) {
                        // 分类（编辑时显示 Picker）
                        if isEditing {
                            HStack {
                                Text("分类")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .frame(width: 52, alignment: .leading)
                                Picker("", selection: $editCategory) {
                                    ForEach(categories, id: \.self) { Text($0).tag($0) }
                                }
                                .pickerStyle(.menu)
                                .foregroundColor(Color.App.textBlack)
                                Spacer()
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            Divider().padding(.leading, 16)
                        }

                        // 备注
                        DetailRow(label: "备注",
                                  value: isEditing ? nil : (transaction.note?.isEmpty == false ? transaction.note! : "—")) {
                            if isEditing {
                                TextField("备注", text: $editNote)
                                    .foregroundColor(Color.App.textBlack)
                            }
                        }
                        Divider().padding(.leading, 16)

                        // 付款人
                        DetailRow(label: "付款人", value: transaction.displayPayerName)
                        Divider().padding(.leading, 16)

                        // 参与人（显示所有成员昵称）
                        DetailRow(label: "参与人", value: txParticipantsText)
                        Divider().padding(.leading, 16)

                        // 时间
                        DetailRow(label: "时间",
                                  value: isEditing ? nil : dateFormatter.string(from: transaction.transactionAt)) {
                            if isEditing {
                                DatePicker("", selection: $editDate, displayedComponents: [.date, .hourAndMinute])
                                    .labelsHidden()
                            }
                        }
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // 错误信息
                    if let err = errorMessage {
                        Text(err).font(.system(size: 13)).foregroundColor(.red)
                    }

                    // 删除按钮（仅自己的记录）
                    if isOwn && !isEditing {
                        Button(role: .destructive) { showDeleteAlert = true } label: {
                            Label("删除这条记录", systemImage: "trash")
                                .font(.system(size: 15, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.red.opacity(0.08))
                                .foregroundColor(.red)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .background(Color(hex: "#F2F2F7").ignoresSafeArea())
            .navigationTitle("流水详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if isEditing {
                        Button("取消") { isEditing = false }
                    } else {
                        Button("关闭") { dismiss() }
                    }
                }
                if isOwn {
                    ToolbarItem(placement: .confirmationAction) {
                        if isEditing {
                            Button(isSaving ? "保存中…" : "保存") {
                                Task { await saveEdit() }
                            }
                            .disabled(isSaving || editAmount.isEmpty)
                        } else {
                            Button("编辑") {
                                editAmount = String(format: "%.2f", abs(transaction.amount))
                                editNote = transaction.note ?? ""
                                editCategory = transaction.category ?? "其他"
                                editDate = transaction.transactionAt
                                isEditing = true
                            }
                        }
                    }
                }
            }
            .alert("确认删除", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) { Task { await performDelete() } }
            } message: { Text("删除后无法恢复。") }
        }
        .presentationDetents([.large])
    }

    // 分类图标
    private var txCategoryIcon: String {
        switch transaction.category {
        case "餐饮", "吃喝": return "fork.knife"
        case "交通", "出行": return "car.fill"
        case "购物", "居家": return "bag.fill"
        case "娱乐": return "film.fill"
        case "医疗": return "cross.case.fill"
        case "教育", "成长": return "book.fill"
        case "人情": return "gift.fill"
        case "工资": return "banknote.fill"
        default: return "tag.fill"
        }
    }

    // 参与人：显示所有成员昵称，而非"N人参与"
    private var txParticipantsText: String {
        if let names = transaction.participants, !names.isEmpty {
            return names.joined(separator: "、")
        }
        return "全体成员"
    }

    private func saveEdit() async {
        guard let amountValue = Double(editAmount) else {
            errorMessage = "请输入有效金额"; return
        }
        isSaving = true
        errorMessage = nil
        let sign: Double = transaction.amount < 0 ? -1 : 1
        let txDict: [String: Any] = [
            "id": transaction.id,
            "amount": sign * amountValue,
            "category": editCategory,
            "note": editNote,
            "transactionAt": ISO8601DateFormatter().string(from: editDate),
            "payerName": transaction.payerName ?? transaction.participantName ?? "我",
            "participants": transaction.participants ?? [],
            "splitMethod": transaction.splitMethod ?? "equal"
        ]
        do {
            _ = try await SharedProjectService.shared.writeTransactions(inviteCode: inviteCode, transactions: [txDict])
            // 构造更新后的本地对象（服务端会通过 sharedTransactionDidWrite 通知刷新）
            NotificationCenter.default.post(name: .sharedTransactionDidWrite, object: nil,
                                            userInfo: ["projectId": transaction.deviceId])
            let updated = SharedTransaction(
                id: transaction.id, deviceId: transaction.deviceId,
                participantName: transaction.participantName,
                payerName: transaction.payerName, participants: transaction.participants,
                splitMethod: transaction.splitMethod,
                amount: sign * amountValue, category: editCategory,
                note: editNote, transactionAt: editDate,
                isDeleted: transaction.isDeleted, serverUpdatedAt: transaction.serverUpdatedAt
            )
            onUpdated(updated)
        } catch {
            errorMessage = "保存失败: \(error.localizedDescription)"
        }
        isSaving = false
    }

    private func performDelete() async {
        do {
            try await SharedProjectService.shared.deleteTransaction(inviteCode: inviteCode, transactionId: transaction.id)
            onDeleted(transaction.id)
        } catch {
            errorMessage = "删除失败: \(error.localizedDescription)"
        }
    }
}

// 通用行组件
private struct DetailRow<Content: View>: View {
    let label: String
    var value: String?
    @ViewBuilder var trailing: () -> Content

    init(label: String, value: String? = nil, @ViewBuilder trailing: @escaping () -> Content = { EmptyView() }) {
        self.label = label; self.value = value; self.trailing = trailing
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14)).foregroundColor(.gray)
                .frame(width: 60, alignment: .leading)
            if let v = value {
                Text(v).font(.system(size: 14, weight: .medium)).foregroundColor(Color.App.textBlack)
            }
            trailing()
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - 添加流水视图
struct AddSharedTransactionView: View {
    let inviteCode: String
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var category = ""
    @State private var note = ""
    @State private var transactionDate = Date()
    @State private var isLoading = false
    @State private var errorMessage: String?

    let categories = ["餐饮", "购物", "交通", "娱乐", "医疗", "教育", "居住", "其他"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("¥")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        TextField("金额", text: $amount)
                            .keyboardType(.decimalPad)
                            .font(.title2)
                    }

                    Picker("分类", selection: $category) {
                        Text("选择分类").tag("")
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }

                    TextField("备注（可选）", text: $note)

                    DatePicker("时间", selection: $transactionDate, displayedComponents: [.date, .hourAndMinute])
                } header: {
                    Text("添加流水")
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button {
                        Task {
                            await addTransaction()
                        }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("添加")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(amount.isEmpty || isLoading)
                }
            }
            .navigationTitle("记一笔")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func addTransaction() async {
        guard let amountValue = Double(amount) else {
            errorMessage = "请输入有效金额"
            return
        }

        isLoading = true
        errorMessage = nil

        let transaction: [String: Any] = [
            "id": UUID().uuidString,
            "amount": amountValue,
            "category": category.isEmpty ? "其他" : category,
            "note": note,
            "transactionAt": ISO8601DateFormatter().string(from: transactionDate)
        ]

        do {
            _ = try await SharedProjectService.shared.writeTransactions(
                inviteCode: inviteCode,
                transactions: [transaction]
            )
            dismiss()
        } catch {
            errorMessage = "添加失败: \(error.localizedDescription)"
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        SharedProjectDetailView(project: JoinedSharedProject(
            projectId: "test",
            inviteCode: "ABC123",
            name: "测试账本",
            participantName: "阿杰",
            memberNames: ["阿杰", "小美", "Tim"],
            lastSyncTime: nil
        ))
    }
}
