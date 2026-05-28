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
    
    private var amountText: String {
        let prefix = cardData.type == "expense" ? "-" : "+"
        return "\(prefix)¥\(cardData.amount)"
    }
    
    private var amountColor: Color {
        cardData.type == "expense" ? Color.App.redExpense : Color.App.darkGreen
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Image(systemName: cardData.isNewCategory ? "sparkles" : "checkmark.circle.fill")
                    .foregroundColor(cardData.isNewCategory ? Color.yellow : Color.App.darkGreen)
                Text(cardData.isNewCategory ? "新分类建议" : "交易确认")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                if !cardData.isNewCategory {
                    Text("\(timeRemaining)s")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
            
            // 交易详情
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: cardData.categoryIcon)
                        .foregroundColor(Color(hex: cardData.categoryColorHex))
                    VStack(alignment: .leading, spacing: 2) {
                        if cardData.isNewCategory {
                            HStack {
                                Text("✨ \(cardData.categoryName)")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color.orange)
                                Text("(新分类)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        } else {
                            Text(cardData.categoryName)
                                .font(.system(size: 16, weight: .medium))
                        }
                        if !cardData.groupName.isEmpty {
                            Text("归属：\(cardData.groupName)")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                    Spacer()
                    Text(amountText)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(amountColor)
                }
                
                if !cardData.note.isEmpty {
                    Text(cardData.note)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                if let projectName = cardData.projectName {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.gray)
                        Text(projectName)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
                
                if cardData.isNewCategory {
                    Text("点击\"创建并入账\"将在「\(cardData.groupName)」下创建新分类「\(cardData.categoryName)」")
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
                    Text(cardData.isNewCategory ? "取消" : "取消")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.App.tabBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Button(action: {
                    if cardData.isNewCategory {
                        showCreateCategoryAlert = true
                    } else {
                        confirmTransaction()
                    }
                }) {
                    Text(cardData.isNewCategory ? "创建并入账" : "确认入账")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(cardData.isNewCategory ? Color.orange : Color.App.darkGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(16)
        .background(Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        .onAppear {
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
                        Text(cardData.isNewCategory ? "已创建并入账" : "已入账")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color.App.darkGreen)
                    }
                }
            }
        )
        .alert("创建新分类", isPresented: $showCreateCategoryAlert) {
            Button("取消", role: .cancel) {}
            Button("确认创建") {
                confirmTransaction()
            }
        } message: {
            Text("将在「\(cardData.groupName)」下创建新分类「\(cardData.categoryName)」，并记录这笔交易。")
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                timer?.invalidate()
                confirmTransaction()
            }
        }
    }
    
    private func confirmTransaction() {
        guard !isConfirmed && !isCancelled else { return }
        
        timer?.invalidate()
        isConfirmed = true
        
        if cardData.isNewCategory {
            store.addCategory(
                name: cardData.categoryName,
                icon: cardData.categoryIcon,
                colorHex: cardData.categoryColorHex,
                groupName: cardData.groupName
            )
        }
        
        if !cardData.note.isEmpty {
            onSaveMemory?(cardData.note, cardData.categoryName, cardData.projectName)
        }
        
        onConfirm?(cardData)
    }
    
    private func cancelTransaction() {
        guard !isConfirmed && !isCancelled else { return }
        
        timer?.invalidate()
        isCancelled = true
        
        // 调用回调
        onCancel?()
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