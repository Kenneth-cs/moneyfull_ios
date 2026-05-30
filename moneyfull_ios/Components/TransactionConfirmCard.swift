import SwiftUI

struct TransactionConfirmCard: View {
    let cardData: TransactionCardData
    @EnvironmentObject var store: AppStore
    var onConfirm: ((TransactionCardData) -> Void)?
    var onCancel: (() -> Void)?
    var onSaveMemory: ((String, String, String?) -> Void)?
    @State private var timeRemaining = 8
    @State private var timer: Timer?
    @State private var isConfirmed = false
    @State private var isCancelled = false
    @State private var showCreateCategoryAlert = false
    @State private var editableData: TransactionCardData = TransactionCardData(amount: 0, type: "expense", categoryName: "", categoryIcon: "", categoryColorHex: "", note: "")
    @State private var isEditing = false
    @State private var hasEdited = false
    @State private var showAmountEditor = false
    @State private var showCategoryPicker = false
    @State private var showProjectPicker = false
    @State private var amountText = ""

    private var displayData: TransactionCardData {
        hasEdited ? editableData : cardData
    }

    private var amountDisplay: String {
        let prefix = displayData.type == "expense" ? "-" : "+"
        return "\(prefix)¥\(displayData.amount)"
    }

    private var amountColor: Color {
        displayData.type == "expense" ? Color.App.redExpense : Color.App.darkGreen
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Image(systemName: displayData.isNewCategory ? "sparkles" : "checkmark.circle.fill")
                    .foregroundColor(displayData.isNewCategory ? Color.yellow : Color.App.darkGreen)
                Text(displayData.isNewCategory ? "新分类建议" : "交易确认")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                if !displayData.isNewCategory {
                    if isEditing {
                        HStack(spacing: 4) {
                            Image(systemName: "pause.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color.orange)
                            Text("已暂停")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color.orange)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Capsule())
                    } else {
                        Text("\(timeRemaining)s")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
            }

            // 交易详情
            VStack(alignment: .leading, spacing: 12) {
                // 分类行（可点击）
                Button(action: {
                    guard !displayData.isNewCategory else { return }
                    pauseTimer()
                    showCategoryPicker = true
                }) {
                    HStack {
                        Image(systemName: displayData.categoryIcon)
                            .foregroundColor(Color(hex: displayData.categoryColorHex))
                        VStack(alignment: .leading, spacing: 2) {
                            if displayData.isNewCategory {
                                HStack {
                                    Text("✨ \(displayData.categoryName)")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(Color.orange)
                                    Text("(新分类)")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                            } else {
                                Text(displayData.categoryName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color.App.textBlack)
                            }
                            if !displayData.groupName.isEmpty {
                                Text("归属：\(displayData.groupName)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        }
                        Spacer()
                        if !displayData.isNewCategory {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color.App.darkGreen.opacity(0.5))
                        }
                    }
                }

                // 金额行（可点击）
                Button(action: {
                    guard !displayData.isNewCategory else { return }
                    pauseTimer()
                    amountText = String(format: "%.0f", displayData.amount)
                    showAmountEditor = true
                }) {
                    HStack {
                        Text("金额")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        Spacer()
                        Text(amountDisplay)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(amountColor)
                        if !displayData.isNewCategory {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color.App.darkGreen.opacity(0.5))
                        }
                    }
                }

                if !displayData.note.isEmpty {
                    Text(displayData.note)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }

                // 项目行（可点击）
                Button(action: {
                    guard !displayData.isNewCategory else { return }
                    pauseTimer()
                    showProjectPicker = true
                }) {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.gray)
                        Text(displayData.projectName ?? "未选择项目")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        Spacer()
                        if !displayData.isNewCategory {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color.App.darkGreen.opacity(0.5))
                        }
                    }
                }

                if displayData.isNewCategory {
                    Text("点击\"创建并入账\"将在「\(displayData.groupName)」下创建新分类「\(displayData.categoryName)」")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                        .padding(.top, 4)
                }
            }
            .padding(16)
            .background(Color.App.tabBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // 操作按钮
            HStack(spacing: 12) {
                Button(action: {
                    cancelTransaction()
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
                    if displayData.isNewCategory {
                        showCreateCategoryAlert = true
                    } else {
                        confirmTransaction()
                    }
                }) {
                    Text(displayData.isNewCategory ? "创建并入账" : "确认入账")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(displayData.isNewCategory ? Color.orange : Color.App.darkGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(16)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        .onAppear {
            editableData = cardData
            if !cardData.isNewCategory {
                startTimer()
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
        .opacity(isConfirmed ? 0.6 : 1.0)
        .overlay(
            Group {
                if isConfirmed {
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(Color.App.darkGreen)
                        Text(displayData.isNewCategory ? "已创建并入账" : "已入账")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color.App.darkGreen)
                    }
                }
            }
        )
        .sheet(isPresented: $showAmountEditor) {
            AmountEditSheet(amountText: $amountText, onSave: { newAmount in
                editableData.amount = newAmount
                hasEdited = true
                resumeTimer()
            }, onCancel: {
                resumeTimer()
            })
        }
        .sheet(isPresented: $showCategoryPicker) {
            ConfirmCardCategoryPicker(
                selectedCategoryName: Binding(
                    get: { editableData.categoryName },
                    set: { editableData.categoryName = $0 }
                ),
                selectedCategoryIcon: Binding(
                    get: { editableData.categoryIcon },
                    set: { editableData.categoryIcon = $0 }
                ),
                selectedCategoryColor: Binding(
                    get: { editableData.categoryColorHex },
                    set: { editableData.categoryColorHex = $0 }
                ),
                selectedGroupName: Binding(
                    get: { editableData.groupName },
                    set: { editableData.groupName = $0 }
                ),
                type: displayData.type == "expense" ? .expense : .income,
                categories: store.categories,
                onSave: { hasEdited = true; resumeTimer() },
                onCancel: { resumeTimer() }
            )
        }
        .sheet(isPresented: $showProjectPicker) {
            ConfirmCardProjectPicker(
                selectedProjectName: Binding(
                    get: { editableData.projectName },
                    set: { editableData.projectName = $0 }
                ),
                projects: store.activeProjects,
                onSave: { hasEdited = true; resumeTimer() },
                onCancel: { resumeTimer() }
            )
        }
        .alert("创建新分类", isPresented: $showCreateCategoryAlert) {
            Button("取消", role: .cancel) {}
            Button("确认创建") {
                confirmTransaction()
            }
        } message: {
            Text("将在「\(displayData.groupName)」下创建新分类「\(displayData.categoryName)」，并记录这笔交易。")
        }
    }

    // MARK: - 倒计时控制
    private func startTimer() {
        timer?.invalidate()
        isEditing = false
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                timer?.invalidate()
                confirmTransaction()
            }
        }
    }

    private func pauseTimer() {
        timer?.invalidate()
        isEditing = true
    }

    private func resumeTimer() {
        isEditing = false
        if timeRemaining > 0 {
            startTimer()
        }
    }

    private func confirmTransaction() {
        guard !isConfirmed && !isCancelled else { return }

        timer?.invalidate()
        isConfirmed = true

        let finalData = hasEdited ? editableData : cardData

        if finalData.isNewCategory {
            store.addCategory(
                name: finalData.categoryName,
                icon: finalData.categoryIcon,
                colorHex: finalData.categoryColorHex,
                groupName: finalData.groupName
            )
        }

        if !finalData.note.isEmpty {
            onSaveMemory?(finalData.note, finalData.categoryName, finalData.projectName)
        }

        onConfirm?(finalData)
    }

    private func cancelTransaction() {
        guard !isConfirmed && !isCancelled else { return }

        timer?.invalidate()
        isCancelled = true

        onCancel?()
    }
}

// MARK: - 金额编辑弹层
struct AmountEditSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var amountText: String
    var onSave: (Double) -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("修改金额")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                    TextField("输入金额", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color.App.textBlack)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 16)
                        .background(Color.App.tabBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("修改金额")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        onCancel()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        if let amount = Double(amountText), amount > 0 {
                            onSave(amount)
                        }
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(Color.App.darkGreen)
                    .font(.system(size: 16, weight: .bold))
                }
            }
        }
        .presentationDetents([.height(250)])
        .presentationCornerRadius(24)
    }
}

// MARK: - 确认卡片分类选择器
struct ConfirmCardCategoryPicker: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedCategoryName: String
    @Binding var selectedCategoryIcon: String
    @Binding var selectedCategoryColor: String
    @Binding var selectedGroupName: String
    var type: TransactionType
    var categories: [Category]
    var onSave: () -> Void
    var onCancel: () -> Void

    private var filteredCategories: [Category] {
        let typeStr = type == .expense ? "expense" : "income"
        return categories.filter { $0.transactionType == typeStr || $0.transactionType == "both" }
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(filteredCategories) { category in
                    Button(action: {
                        selectedCategoryName = category.name
                        selectedCategoryIcon = category.icon
                        selectedCategoryColor = category.colorHex
                        selectedGroupName = category.groupName
                        onSave()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: category.icon)
                                .font(.system(size: 18))
                                .foregroundColor(Color(hex: category.colorHex))
                                .frame(width: 36, height: 36)
                                .background(Color(hex: category.colorHex).opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Text(category.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color.App.textBlack)
                            Spacer()
                            if selectedCategoryName == category.name {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color.App.darkGreen)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("选择分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        onCancel()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 确认卡片项目选择器
struct ConfirmCardProjectPicker: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedProjectName: String?
    var projects: [Project]
    var onSave: () -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationView {
            List {
                Button(action: {
                    selectedProjectName = nil
                    onSave()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.gray)
                        Text("不选择项目")
                            .foregroundColor(.gray)
                        Spacer()
                        if selectedProjectName == nil {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color.App.darkGreen)
                        }
                    }
                }
                ForEach(projects) { project in
                    Button(action: {
                        selectedProjectName = project.name
                        onSave()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(hex: project.colorHex).opacity(0.3))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    AppIconView(name: project.icon, size: 16,
                                                color: Color(hex: project.colorHex))
                                )
                            Text(project.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color.App.textBlack)
                            Spacer()
                            if selectedProjectName == project.name {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color.App.darkGreen)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("选择项目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        onCancel()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    TransactionConfirmCard(cardData: TransactionCardData(
        amount: 25.0,
        type: "expense",
        categoryName: "餐饮",
        categoryIcon: "fork.knife",
        categoryColorHex: "#A8E6CF",
        note: "午餐",
        projectName: "日常开销"
    ))
    .padding()
    .background(Color.gray.opacity(0.1))
}
