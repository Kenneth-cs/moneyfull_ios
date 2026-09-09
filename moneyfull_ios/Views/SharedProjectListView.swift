import SwiftUI

struct SharedProjectListView: View {
    @State private var joinedProjects: [JoinedSharedProject] = []
    @State private var showCreateSheet = false
    @State private var showJoinSheet = false
    @State private var selectedProject: JoinedSharedProject?
    /// 加入成功后暂存，待 sheet 关闭后再触发导航
    @State private var pendingJoinNavigation: JoinedSharedProject? = nil
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            List {
                // 共享账本区域
                Section {
                    if joinedProjects.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("还没有共享账本")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("创建或加入一个共享账本，和家人朋友一起记账")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        ForEach(joinedProjects) { project in
                            Button {
                                selectedProject = project
                            } label: {
                                SharedProjectRow(project: project)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    HStack {
                        Image(systemName: "person.2.fill")
                        Text("共享账本")
                    }
                }

                // 操作按钮
                Section {
                    Button {
                        AnalyticsManager.shared.trackSharedProjectCreateClick()
                        showCreateSheet = true
                    } label: {
                        Label("创建共享账本", systemImage: "plus.circle.fill")
                    }

                    Button {
                        AnalyticsManager.shared.trackSharedProjectJoinClick()
                        showJoinSheet = true
                    } label: {
                        Label("输入邀请码加入", systemImage: "qrcode.viewfinder")
                    }
                }
            }
            .navigationTitle("共享记账")
            .sheet(isPresented: $showCreateSheet) {
                CreateSharedProjectView()
            }
            .sheet(isPresented: $showJoinSheet, onDismiss: {
                // sheet 关闭后才触发导航，避免 SwiftUI 双层 sheet/navigation 冲突
                if let project = pendingJoinNavigation {
                    loadProjects()
                    selectedProject = project
                    pendingJoinNavigation = nil
                }
            }) {
                JoinProjectView(onJoined: { project in
                    pendingJoinNavigation = project
                })
            }
            .navigationDestination(item: $selectedProject) { project in
                SharedProjectDetailView(project: project)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    loadProjects()
                    Task {
                        await SharedProjectService.shared.syncAll()
                    }
                }
            }
            .onAppear {
                loadProjects()
            }
            .onReceive(NotificationCenter.default.publisher(for: .sharedProjectDidSync)) { _ in
                loadProjects()
            }
            .onReceive(NotificationCenter.default.publisher(for: .sharedProjectJoinedFromDeepLink)) { notification in
                if let project = notification.userInfo?["project"] as? JoinedSharedProject {
                    loadProjects()
                    selectedProject = project
                }
            }
        }
    }

    private func loadProjects() {
        joinedProjects = SharedProjectService.shared.joinedProjects
    }
}

// MARK: - 项目行视图
struct SharedProjectRow: View {
    let project: JoinedSharedProject

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                HStack {
                    Image(systemName: "person.fill")
                        .font(.caption)
                    Text(project.participantName)
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text(project.inviteCode)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 创建共享项目视图
struct CreateSharedProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var projectName = ""
    @State private var creatorName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var createdProject: CreateProjectResponse?
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("账本名称", text: $projectName)
                    TextField("你的昵称", text: $creatorName)
                } header: {
                    Text("创建共享账本")
                } footer: {
                    Text("创建后会生成邀请码，分享给家人朋友即可加入")
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
                            await createProject()
                        }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("创建")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(projectName.isEmpty || creatorName.isEmpty || isLoading)
                }
            }
            .navigationTitle("创建共享账本")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let project = createdProject {
                    ShareInviteCodeView(project: project)
                }
            }
        }
    }

    private func createProject() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await SharedProjectService.shared.createProject(
                name: projectName,
                creatorName: creatorName
            )
            createdProject = response
            showShareSheet = true
            AnalyticsManager.shared.trackSharedProjectCreateSuccess(projectNameLength: projectName.count)
        } catch {
            errorMessage = "创建失败: \(error.localizedDescription)"
            AnalyticsManager.shared.trackSharedProjectCreateFail(errorType: "server")
        }

        isLoading = false
    }
}

// MARK: - 分享邀请码视图
struct ShareInviteCodeView: View {
    let project: CreateProjectResponse
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var qrImage: UIImage?
    @State private var showCopiedHint = false

    private var shareURL: URL {
        URL(string: "https://originapex.cn/join/\(project.inviteCode)")!
    }
    private var shareText: String {
        "邀请你加入「\(project.name)」共享账本，点击链接或输入邀请码 \(project.inviteCode) 加入 👉 https://originapex.cn/join/\(project.inviteCode)"
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // 全局背景色
                Color(hex: "#F0F7F3").ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        headerSection
                        cardSection
                            .padding(.horizontal, 20)
                            .padding(.top, -36) // 卡片上移覆盖插画底部
                        buttonSection
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("邀请码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                AnalyticsManager.shared.trackSharedInviteViewPanel(source: "create_success")
                // 二维码编码 H5 落地页 URL，任何扫码 App 都能打开；
                // H5 页面内再通过按钮触发 moneyfull:// deep link
                qrImage = QRCodeHelper.generate(
                    from: "https://originapex.cn/join/\(project.inviteCode)",
                    size: 300
                )
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: [shareURL, shareText])
            }
        }
    }

    // MARK: - 顶部插画区

    private var headerSection: some View {
        ZStack(alignment: .bottomTrailing) {
            // 渐变背景
            LinearGradient(
                colors: [Color(hex: "#C8E8D4"), Color(hex: "#E8F5EE")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            // 左下叶子装饰
            Image("invite_leaf")
                .resizable()
                .scaledToFit()
                .frame(width: 80)
                .opacity(0.55)
                .rotationEffect(.degrees(-15))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 4)
                .padding(.bottom, 24)

            // 右上叶子（翻转）
            Image("invite_leaf")
                .resizable()
                .scaledToFit()
                .frame(width: 55)
                .opacity(0.3)
                .rotationEffect(.degrees(160))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, 16)
                .padding(.top, 6)

            // 人物插画：底部对齐，padding(.bottom, X) 控制往上偏移量
            Image("invite_illustration")
                .resizable()
                .scaledToFit()
                .frame(width: 200)
                .padding(.bottom, 23)  // ← 调这个数字：越大人物越靠上

            // 左侧文字内容
            VStack(alignment: .leading, spacing: 10) {
                Text("一起记账 让生活更美好")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#3D8A62"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.75))
                    .clipShape(Capsule())

                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "#4CAF50"))
                    Text("创建成功！")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color(hex: "#1A1A1A"))
                }

                Text("快邀请家人朋友\n一起来记账吧～")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#555555"))
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.leading, 24)
            .padding(.bottom, 44)
        }
        .frame(height: 190)
    }

    // MARK: - 邀请码卡片

    private var cardSection: some View {
        VStack(spacing: 0) {
            VStack(spacing: 18) {
                // 账本名称行
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(hex: "#E6F5EC"))
                            .frame(width: 40, height: 40)
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: "#4CAF50"))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("账本名称")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#AAAAAA"))
                        Text(project.name)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(Color(hex: "#1A1A1A"))
                    }
                    Spacer()
                }
                .padding(.top, 8)

                // 分割线
                Rectangle()
                    .fill(Color(hex: "#F0F0F0"))
                    .frame(height: 1)

                // 邀请码
                VStack(spacing: 8) {
                    Text("邀请码")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#AAAAAA"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(project.inviteCode)
                        .font(.system(size: 34, weight: .black, design: .monospaced))
                        .foregroundColor(Color(hex: "#2C7A54"))
                        .kerning(5)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: "#EAF7EF"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                // 二维码
                if let qr = qrImage {
                    Image(uiImage: qr)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 156, height: 156)
                        .padding(10)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "#DCF0E4"), lineWidth: 1.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // 底部说明 + 装饰语
                VStack(spacing: 6) {
                    Text("分享给家人朋友，输入邀请码即可加入")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#CCCCCC"))
                        .multilineTextAlignment(.center)

                    HStack {
                        Spacer()
                        Text("小小账本 连接大大的幸福 ❤️")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#D0D0D0"))
                    }
                }
                .padding(.bottom, 4)
            }
            .padding(24)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.07), radius: 20, x: 0, y: 6)
    }

    // MARK: - 按钮区

    private var buttonSection: some View {
        HStack(spacing: 12) {
            // 复制邀请码
            Button {
                UIPasteboard.general.string = project.inviteCode
                AnalyticsManager.shared.trackSharedInviteCopyCode()
                withAnimation(.spring()) { showCopiedHint = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    withAnimation { showCopiedHint = false }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showCopiedHint ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 14, weight: .semibold))
                    Text(showCopiedHint ? "已复制" : "复制邀请码")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(Color(hex: "#2C7A54"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(hex: "#2C7A54"), lineWidth: 1.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            // 分享
            Button {
                AnalyticsManager.shared.trackSharedInviteShare(shareMethod: "system_sheet")
                showShareSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                    Text("分享")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#5BAF8A"), Color(hex: "#2C7A54")],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color(hex: "#2C7A54").opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
    }
}

#Preview {
    SharedProjectListView()
}
