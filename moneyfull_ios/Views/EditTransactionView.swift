import SwiftUI
import SwiftData

struct EditTransactionView: View {
    let transaction: Transaction
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var store: AppStore
    
    @State private var type: TransactionType
    @State private var amount: String
    @State private var selectedCategory: Category?
    @State private var note: String
    @State private var date: Date
    @State private var showDatePicker = false
    @State private var showKeypad = true
    
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    private let successFeedback = UINotificationFeedbackGenerator()
    
    private var displayAmount: String { amount.isEmpty ? "0" : amount }
    
    init(transaction: Transaction) {
        self.transaction = transaction
        _type = State(initialValue: transaction.type)
        _amount = State(initialValue: String(transaction.amount))
        _note = State(initialValue: transaction.note)
        _date = State(initialValue: transaction.date)
        _selectedCategory = State(initialValue: nil)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color.App.textBlack)
                        .frame(width: 40, height: 40)
                }
                Spacer()
                Text("编辑记录")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(Color.App.textBlack)
                Spacer()
                Button(action: handleSave) {
                    Text("完成")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(amount.isEmpty ? Color.gray : Color(hex: "#546073"))
                        .clipShape(Capsule())
                }
                .disabled(amount.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Color.clear.frame(height: 1)
                        .contentShape(Rectangle())
                        .onTapGesture { showKeypad = false }
                    
                    HStack(spacing: 0) {
                        typeButton(label: "支出", t: .expense)
                        typeButton(label: "收入", t: .income)
                    }
                    .padding(4)
                    .frame(width: 200)
                    .background(Color.App.tabBackground)
                    .clipShape(Capsule())
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 40)
                            .fill(Color.App.amountBg)
                        
                        VStack(spacing: 8) {
                            Text("输入金额")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(hex: "#484A07").opacity(0.6))
                                .kerning(2)
                            
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("¥")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(Color(hex: "#1C1D00"))
                                Text(displayAmount)
                                    .font(.system(size: 56, weight: .black))
                                    .foregroundColor(Color(hex: "#1C1D00"))
                                    .minimumScaleFactor(0.5)
                                    .lineLimit(1)
                                if showKeypad { BlinkingCursor() }
                            }
                        }
                        .padding(.vertical, 28)
                    }
                    .padding(.horizontal, 24)
                    .onTapGesture { showKeypad = true }
                    
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("分类")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color.App.textBlack)
                            Spacer()
                        }
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 20) {
                            ForEach(store.categories.filter {
                                type == .expense ? ($0.transactionType == "expense" || $0.transactionType == "both")
                                                 : ($0.transactionType == "income" || $0.transactionType == "both")
                            }, id: \.id) { cat in
                                CategoryItem(name: cat.name, icon: cat.icon, colorHex: cat.colorHex, isSelected: selectedCategory?.id == cat.id) {
                                    impactFeedback.impactOccurred()
                                    selectedCategory = cat
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: "#E2E2E2"))
                            .frame(width: 40, height: 40)
                            .overlay(Image(systemName: "pencil").foregroundColor(.gray))
                        TextField("添加备注...", text: $note)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding(16)
                    .background(Color.App.tabBackground)
                    .clipShape(Capsule())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                }
            }
            
            VStack(spacing: 0) {
                Button(action: { showKeypad.toggle() }) {
                    HStack(spacing: 6) {
                        Image(systemName: showKeypad ? "chevron.down" : "keyboard")
                            .font(.system(size: 12, weight: .bold))
                        Text(showKeypad ? "收起键盘" : "展开键盘")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(Color.App.darkGreen.opacity(0.7))
                    .padding(.vertical, 10)
                }
                
                if showKeypad {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            KeyButton(label: "1") { handleKey("1") }
                            KeyButton(label: "2") { handleKey("2") }
                            KeyButton(label: "3") { handleKey("3") }
                            KeyButton(icon: "calendar") { showDatePicker = true }
                        }
                        HStack(spacing: 12) {
                            KeyButton(label: "4") { handleKey("4") }
                            KeyButton(label: "5") { handleKey("5") }
                            KeyButton(label: "6") { handleKey("6") }
                            KeyButton(label: "+") { handleKey("+") }
                        }
                        HStack(spacing: 12) {
                            KeyButton(label: "7") { handleKey("7") }
                            KeyButton(label: "8") { handleKey("8") }
                            KeyButton(label: "9") { handleKey("9") }
                            KeyButton(label: "-") { handleKey("-") }
                        }
                        HStack(spacing: 12) {
                            KeyButton(label: ".") { handleKey(".") }
                            KeyButton(label: "0") { handleKey("0") }
                            KeyButton(icon: "delete.left.fill") { handleKey("del") }
                            Button(action: { showKeypad = false }) {
                                Text("确认")
                                    .font(.system(size: 18, weight: .heavy))
                                    .foregroundColor(Color.App.darkGreen)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(Color.App.primaryGreen)
                                    .clipShape(RoundedRectangle(cornerRadius: 24))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showKeypad)
            .background(
                Color.App.cardBackground
                    .clipShape(RoundedRectangle(cornerRadius: 40))
                    .shadow(color: Color.black.opacity(0.05), radius: 20, x: 0, y: -10)
            )
        }
        .background(Color.App.backgroundGray.ignoresSafeArea())
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(date: $date)
        }
        .onAppear {
            if selectedCategory == nil {
                selectedCategory = store.categories.first { $0.name == transaction.categoryName } ?? store.categories.first
            }
        }
    }
    
    @ViewBuilder
    private func typeButton(label: String, t: TransactionType) -> some View {
        Button(action: {
            impactFeedback.impactOccurred()
            type = t
        }) {
            Text(label)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(type == t ? Color.App.textBlack : Color.gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(type == t ? Color.App.cardBackground : Color.clear)
                .clipShape(Capsule())
                .shadow(color: type == t ? Color.black.opacity(0.05) : Color.clear, radius: 2, x: 0, y: 1)
        }
    }
    
    private func handleKey(_ key: String) {
        impactFeedback.impactOccurred()
        switch key {
        case "del":
            if !amount.isEmpty { amount.removeLast() }
        case ".":
            if !amount.contains(".") { amount += key }
        default:
            if let dotIndex = amount.firstIndex(of: ".") {
                let decimals = amount.distance(from: amount.index(after: dotIndex), to: amount.endIndex)
                if decimals >= 2 { return }
            }
            if amount.count < 10 { amount += key }
        }
        if let val = Double(amount), val > 1000 {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
    
    private func handleSave() {
        guard let category = selectedCategory,
              let amountValue = Double(amount), amountValue > 0 else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        
        store.updateTransaction(
            transaction,
            amount: amountValue,
            type: type,
            categoryName: category.name,
            categoryIcon: category.icon,
            categoryColorHex: category.colorHex,
            note: note,
            date: date
        )
        
        successFeedback.notificationOccurred(.success)
        presentationMode.wrappedValue.dismiss()
    }
}

#Preview {
    let container = try! ModelContainer(for: Project.self, Transaction.self, Category.self)
    let tx = Transaction(amount: 100, type: .expense, categoryName: "餐饮", categoryIcon: "fork.knife", categoryColorHex: "#A8E6CF")
    return EditTransactionView(transaction: tx)
        .environmentObject(AppStore(modelContext: container.mainContext))
}
