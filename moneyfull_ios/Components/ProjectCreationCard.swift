import SwiftUI

struct ProjectCreationCard: View {
    let projectData: ProjectCreationData
    var onCreateProject: ((ProjectCreationData) -> Void)?
    @State private var isCreated = false
    @State private var showConfirmAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "folder.badge.plus")
                    .foregroundColor(Color.App.darkGreen)
                Text("创建项目")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
            }
            
            // 项目详情
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: projectData.projectIcon)
                        .foregroundColor(Color(hex: projectData.projectColor))
                    Text(projectData.projectName)
                        .font(.system(size: 18, weight: .medium))
                }
                
                Text("点击\"创建项目\"将为您创建此项目")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .padding(16)
            .background(Color.App.tabBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            // 操作按钮
            HStack(spacing: 12) {
                Button(action: {
                    // 取消
                }) {
                    Text("取消")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.App.tabBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Button(action: {
                    showConfirmAlert = true
                }) {
                    Text("创建项目")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.App.darkGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isCreated)
            }
        }
        .padding(16)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        .opacity(isCreated ? 0.6 : 1.0)
        .overlay(
            Group {
                if isCreated {
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(Color.App.darkGreen)
                        Text("项目已创建")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color.App.darkGreen)
                    }
                }
            }
        )
        .alert("确认创建项目", isPresented: $showConfirmAlert) {
            Button("取消", role: .cancel) {}
            Button("确认") {
                isCreated = true
                onCreateProject?(projectData)
            }
        } message: {
            Text("将为您创建项目「\(projectData.projectName)」")
        }
    }
}

#Preview {
    ProjectCreationCard(projectData: ProjectCreationData(projectName: "约会"))
        .padding()
        .background(Color.gray.opacity(0.1))
}