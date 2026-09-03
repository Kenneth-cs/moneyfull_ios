import SwiftUI

/// 预算设置/修改 Bottom Sheet
struct BudgetSetSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var currentBudget: Double? = nil
    @State private var isEditing: Bool = false
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool

    private let cal = Calendar.current
    private var year: Int { cal.component(.year, from: Date()) }
    private var month: Int { cal.component(.month, from: Date()) }
    private var monthDisplay: String { "\(month)月" }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            HStack {
                Text("本月预算")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundColor(Color.App.textBlack)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.gray.opacity(0.4))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 20)

            if isEditing {
                editingView
            } else if let budget = currentBudget {
                budgetInfoView(budget: budget)
            } else {
                noBudgetView
            }

            Spacer()
        }
        .presentationDetents([currentBudget != nil && !isEditing ? .height(320) : .height(340)])
        .presentationCornerRadius(24)
        .onAppear {
            currentBudget = HomeBudgetService.budget(year: year, month: month)
            if currentBudget == nil {
                isEditing = true
            }
        }
        .onChange(of: isInputFocused) {
            // 键盘消失时自动格式化
            if !isInputFocused, !inputText.isEmpty {
                if let value = Double(inputText), value > 0 {
                    inputText = formatAmount(value)
                }
            }
        }
    }

    // MARK: - 已设置预算：信息展示
    private func budgetInfoView(budget: Double) -> some View {
        let monthlyExpense = store.monthlyExpense(year: year, month: month)
        let remaining = budget - monthlyExpense
        let progress = budget > 0 ? monthlyExpense / budget : 0

        return VStack(spacing: 20) {
            // 月份 + 金额
            VStack(spacing: 8) {
                Text("\(monthDisplay)预算")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
                Text("¥\(formatAmount(budget))")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(Color.App.textBlack)
            }

            // 统计信息
            VStack(spacing: 12) {
                infoRow(label: "本月已支出", value: "¥\(formatAmount(monthlyExpense))")
                infoRow(label: "剩余预算",
                        value: remaining >= 0 ? "¥\(formatAmount(remaining))" : "超预算 ¥\(formatAmount(abs(remaining)))",
                        valueColor: remaining >= 0 ? Color.App.darkGreen : Color(hex: "#D94B4B"))
                infoRow(label: "预算已用", value: "\(Int(progress * 100))%")
            }
            .padding(.horizontal, 24)

            // 修改按钮
            Button {
                inputText = formatAmount(budget)
                isEditing = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isInputFocused = true
                }
            } label: {
                Text("修改预算")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.App.darkGreen)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.App.darkGreen.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - 未设置预算：引导
    private var noBudgetView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("设置本月预算")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Color.App.textBlack)
                Text("给自己定一个本月消费上限，\n钱小满会帮你判断花钱节奏。")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 24)

            amountInputField

            confirmButton
        }
    }

    // MARK: - 编辑状态
    private var editingView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("设置\(monthDisplay)预算")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Color.App.textBlack)
            }

            amountInputField

            // 参考上月支出（如果有）
            let lastMonthExpense = lastMonthExpenseValue()
            if lastMonthExpense > 0 {
                Text("参考：上月支出 ¥\(formatAmount(lastMonthExpense))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }

            HStack(spacing: 12) {
                if currentBudget != nil {
                    Button {
                        isEditing = false
                        isInputFocused = false
                    } label: {
                        Text("取消")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }

                confirmButton
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - 金额输入框
    private var amountInputField: some View {
        HStack(spacing: 8) {
            Text("¥")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color.App.darkGreen)
            TextField("0", text: $inputText)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Color.App.textBlack)
                .keyboardType(.decimalPad)
                .focused($isInputFocused)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.App.darkGreen.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 24)
    }

    // MARK: - 确认按钮
    private var confirmButton: some View {
        Button {
            saveBudget()
        } label: {
            Text("保存")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canSave ? Color(hex: "#20AE73") : Color.gray.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!canSave)
        .padding(.horizontal, 24)
    }

    private var canSave: Bool {
        guard let value = Double(inputText) else { return false }
        return value > 0
    }

    // MARK: - 信息行
    private func infoRow(label: String, value: String, valueColor: Color = Color.App.textBlack) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(valueColor)
        }
    }

    // MARK: - 保存
    private func saveBudget() {
        guard let value = Double(inputText), value > 0 else { return }
        HomeBudgetService.setBudget(value, year: year, month: month)
        currentBudget = value
        isEditing = false
        isInputFocused = false
        // 触发 store 刷新（dataVersion 变化会带动 DashboardView 和 BudgetCalendarView 更新）
        store.refresh()
        dismiss()
    }

    // MARK: - 工具
    private func formatAmount(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }

    private func lastMonthExpenseValue() -> Double {
        let lastMonth = cal.date(byAdding: .month, value: -1, to: Date())!
        let y = cal.component(.year, from: lastMonth)
        let m = cal.component(.month, from: lastMonth)
        return store.monthlyExpense(year: y, month: m)
    }
}
