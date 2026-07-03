import SwiftUI

struct FuelPackSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var storeManager: StoreManager
    @State private var selectedPack: Int = 200 // 200 or 500
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 温暖治愈的奶油米色背景
            Color(hex: "#FFFDF8").ignoresSafeArea()
            
            // 顶部装饰性背景光晕
            Circle()
                .fill(Color.App.primaryGreen.opacity(0.15))
                .frame(width: 200, height: 200)
                .offset(x: 100, y: -80)
                .blur(radius: 40)
            
            Circle()
                .fill(Color.App.lightYellow.opacity(0.2))
                .frame(width: 150, height: 150)
                .offset(x: -80, y: 20)
                .blur(radius: 30)
            
            VStack(spacing: 0) {
                // MARK: - 顶部插画区
                ZStack {
                    // 柔和的背景垫片
                    Circle()
                        .fill(Color.App.primaryGreen.opacity(0.15))
                        .frame(width: 130, height: 130)
                    
                    // 水豚组件
                    CapybaraView(size: 84)
                        .offset(y: 12)
                    
                    // 没电的思考气泡
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 42, height: 42)
                            .shadow(color: Color(hex: "#4A3022").opacity(0.08), radius: 8, x: 0, y: 4)
                        
                        Text("🪫")
                            .font(.system(size: 20))
                    }
                    .offset(x: 45, y: -35)
                    
                    // 汗滴
                    Text("💦")
                        .font(.system(size: 16))
                        .offset(x: -40, y: -20)
                }
                .padding(.top, 48)
                
                // MARK: - 情感化标题
                Text("小满今天算累啦")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(hex: "#4A3022"))
                    .padding(.top, 24)
                
                Text("给小满投喂一点能量，继续帮你理清账单吧～\n（能量永久有效，吃不完可以存着哦）")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#8C7366"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.top, 12)
                    .padding(.horizontal, 32)
                
                // MARK: - 零食包选项
                HStack(spacing: 16) {
                    FuelPackOptionCard(
                        title: "小份能量饼干",
                        count: 200,
                        price: "¥6",
                        isSelected: selectedPack == 200
                    )
                    .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedPack = 200 } }
                    
                    FuelPackOptionCard(
                        title: "大份能量套餐",
                        count: 500,
                        price: "¥12",
                        isSelected: selectedPack == 500,
                        badge: "小满最爱 💖"
                    )
                    .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedPack = 500 } }
                }
                .padding(.horizontal, 24)
                .padding(.top, 36)
                
                // MARK: - 购买按钮
                Button(action: { purchaseFuelPack() }) {
                    HStack(spacing: 6) {
                        if isPurchasing {
                            ProgressView()
                                .tint(Color(hex: "#0D2218"))
                        } else {
                            Text("投喂 \(selectedPack) 次能量")
                                .font(.system(size: 17, weight: .heavy, design: .rounded))
                            Text("(\(selectedPack == 200 ? "¥6" : "¥12"))")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .opacity(0.9)
                        }
                    }
                    .foregroundColor(Color(hex: "#0D2218"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [Color.App.primaryGreen, Color(hex: "#63C7A1")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Color.App.primaryGreen.opacity(0.4), radius: 12, x: 0, y: 6)
                }
                .disabled(isPurchasing)
                .padding(.horizontal, 24)
                .padding(.top, 32)
                
                // MARK: - 底部引导
                HStack(spacing: 4) {
                    Text("想要小满每天都元气满满？")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#8C7366"))
                    Button(action: {
                        dismiss()
                        // NotificationCenter.default.post(name: .showPaywall, object: nil)
                    }) {
                        Text("了解专业版订阅")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.App.darkGreen)
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            
            // 关闭按钮 (柔和配色)
            Button { dismiss() } label: {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#F5EFE9"))
                        .frame(width: 32, height: 32)
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(hex: "#8C7366"))
                }
            }
            .padding(.trailing, 20)
            .padding(.top, 20)
        }
        .alert("购买失败", isPresented: $showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func purchaseFuelPack() {
        let productID = selectedPack == 200 ? StoreManager.ProductID.fuelPack200.rawValue : StoreManager.ProductID.fuelPack500.rawValue
        
        guard let product = storeManager.getFuelPackProducts().first(where: { $0.id == productID }) else {
            errorMessage = "产品不存在，请稍后重试"
            showError = true
            return
        }
        
        isPurchasing = true
        
        Task {
            do {
                let success = try await storeManager.purchase(product)
                
                await MainActor.run {
                    isPurchasing = false
                    
                    if success {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isPurchasing = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

private struct FuelPackOptionCard: View {
    let title: String
    let count: Int
    let price: String
    let isSelected: Bool
    var badge: String? = nil
    
    var body: some View {
        ZStack(alignment: .top) {
            // 背景与描边
            RoundedRectangle(cornerRadius: 24)
                .fill(isSelected ? Color.App.primaryGreen.opacity(0.12) : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(
                            style: isSelected 
                                ? StrokeStyle(lineWidth: 2) 
                                : StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                        )
                        .foregroundColor(isSelected ? Color.App.darkGreen : Color(hex: "#E8E0D9"))
                )
                .shadow(color: isSelected ? Color.App.darkGreen.opacity(0.12) : Color.black.opacity(0.02),
                        radius: isSelected ? 12 : 8, x: 0, y: isSelected ? 6 : 4)
            
            VStack(spacing: 6) {
                // Badge 区域 (手写贴纸风)
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "#FF4D4D"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(hex: "#FFE5E5"))
                                .shadow(color: Color(hex: "#FF4D4D").opacity(0.15), radius: 4, x: 0, y: 2)
                        )
                        .rotationEffect(.degrees(3)) // 微微倾斜，更俏皮
                        .offset(y: -12)
                } else {
                    Spacer().frame(height: 16)
                }
                
                // 零食名称
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isSelected ? Color.App.darkGreen : Color(hex: "#8C7366"))
                    .padding(.top, badge != nil ? 0 : 8)
                
                // 次数
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(count)")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundColor(isSelected ? Color.App.darkGreen : Color(hex: "#4A3022"))
                    Text("次")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(isSelected ? Color.App.darkGreen.opacity(0.8) : Color(hex: "#8C7366"))
                }
                
                // 价格
                Text(price)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(isSelected ? Color.App.darkGreen : Color(hex: "#4A3022"))
                    .padding(.top, 2)
            }
            .padding(.bottom, 24)
        }
        .frame(height: 156)
        .scaleEffect(isSelected ? 1.03 : 1.0)
    }
}

#Preview {
    FuelPackSheet()
}