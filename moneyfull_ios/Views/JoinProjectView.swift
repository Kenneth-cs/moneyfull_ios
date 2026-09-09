import SwiftUI

struct JoinProjectView: View {
    @Environment(\.dismiss) private var dismiss
    var prefilledCode: String = ""
    /// 成功加入后回调，外部可据此跳转到项目详情
    var onJoined: ((JoinedSharedProject) -> Void)? = nil
    @State private var inviteCode = ""
    @State private var participantName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var joinedProject: JoinProjectResponse?
    @State private var projectPreview: ProjectInfoResponse?
    @State private var isFetchingPreview = false
    @State private var previewError: String?

    private var isPreviewMode: Bool {
        projectPreview != nil && joinedProject == nil
    }

    var body: some View {
        NavigationStack {
            Form {
                if joinedProject == nil {
                    Section {
                        TextField("6位邀请码", text: $inviteCode)
                            .textInputAutocapitalization(.characters)
                            .onChange(of: inviteCode) { _, newValue in
                                inviteCode = String(newValue.prefix(6)).uppercased()
                                projectPreview = nil
                                previewError = nil
                            }
                    } header: {
                        Text("加入共享账本")
                    } footer: {
                        Text("输入创建者分享的6位邀请码")
                    }
                }

                if let error = previewError {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }

                if let preview = projectPreview, joinedProject == nil {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(preview.name)
                                .font(.title3)
                                .fontWeight(.bold)

                            Text("\(preview.memberCount) 位成员")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            ForEach(preview.members.prefix(5)) { member in
                                HStack {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            Text(String(member.participantName.prefix(1)))
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                        )
                                    Text(member.participantName)
                                        .font(.system(size: 14))
                                    Spacer()
                                }
                            }
                            if preview.members.count > 5 {
                                Text("还有 \(preview.members.count - 5) 位成员...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Text("项目信息")
                    }
                }

                if isPreviewMode {
                    Section {
                        TextField("你的昵称", text: $participantName)
                    } header: {
                        Text("设置昵称")
                    } footer: {
                        Text("你在账本中显示的名称")
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }

                if let project = joinedProject {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.green)

                            Text("加入成功！")
                                .font(.headline)

                            Text(project.name)
                                .font(.title3)
                                .fontWeight(.bold)

                            Text("成员: \(project.members.map { $0.participantName }.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical)
                    }
                }

                Section {
                    Button {
                        Task {
                            if isPreviewMode {
                                await joinProject()
                            } else {
                                await fetchPreview()
                            }
                        }
                    } label: {
                        if isLoading || isFetchingPreview {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(joinedProject != nil ? "完成" : (isPreviewMode ? "加入账本" : "查询"))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(joinedProject != nil ? false : (inviteCode.count != 6 || (isPreviewMode && participantName.isEmpty) || isLoading || isFetchingPreview))
                }
            }
            .navigationTitle("加入共享账本")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if !prefilledCode.isEmpty {
                    inviteCode = prefilledCode
                }
                let nickname = SharedProjectService.shared.myNickname
                if !nickname.isEmpty {
                    participantName = nickname
                }
            }
        }
    }

    private func fetchPreview() async {
        isFetchingPreview = true
        previewError = nil
        errorMessage = nil

        let trimmedCode = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let info = try await SharedProjectService.shared.fetchProjectInfo(inviteCode: trimmedCode)
            projectPreview = info
        } catch {
            previewError = "查询失败: \(error.localizedDescription)"
        }

        isFetchingPreview = false
    }

    private func joinProject() async {
        if let response = joinedProject {
            // 从本地已存数据取出完整项目，回调给外部以便导航
            if let saved = SharedProjectService.shared.joinedProjects
                .first(where: { $0.projectId == response.projectId }) {
                onJoined?(saved)
            }
            dismiss()
            return
        }

        isLoading = true
        errorMessage = nil

        let trimmedCode = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let response = try await SharedProjectService.shared.joinProject(
                inviteCode: trimmedCode,
                participantName: participantName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            SharedProjectService.shared.myNickname = participantName
            joinedProject = response
            AnalyticsManager.shared.trackSharedProjectJoinSuccess(memberCount: response.members.count)
        } catch {
            errorMessage = "加入失败: \(error.localizedDescription)"
            AnalyticsManager.shared.trackSharedProjectJoinFail(errorType: "server")
        }

        isLoading = false
    }
}

#Preview {
    JoinProjectView()
}
