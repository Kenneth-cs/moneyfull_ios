// MARK: - 项目选择弹窗 (仅本地项目)
struct LocalProjectPickerView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selected: Project?
    let projects: [Project]
    
    var body: some View {
        NavigationView {
            List(projects) { project in
                Button(action: {
                    selected = project
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(Color(hex: project.colorHex).opacity(0.3))
                            .frame(width: 44, height: 44)
                            .overlay(
                                AppIconView(name: project.icon, size: 20,
                                            color: Color(hex: project.colorHex))
                            )
                        Text(project.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color.App.textBlack)
                        Spacer()
                        if selected?.id == project.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color.App.darkGreen)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("选择归属项目")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
