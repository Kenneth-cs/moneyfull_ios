import SwiftUI

struct AddRecordView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var type: RecordType = .expense
    @State private var amount: String = "128.50"
    
    enum RecordType {
        case expense, income
    }
    
    let categories: [(icon: String, bg: Color, label: String)] = [
        ("fork.knife", Color.App.primaryGreen, "餐饮"),
        ("bag.fill", Color.App.lightOrange, "购物"),
        ("car.fill", Color.App.lightYellow, "交通"),
        ("house.fill", Color(hex: "#DBEAFE"), "居家"),
        ("gamecontroller.fill", Color(hex: "#F3E8FF"), "娱乐"),
        ("heart.text.square.fill", Color(hex: "#FCE7F3"), "医疗"),
        ("graduationcap.fill", Color(hex: "#FFEDD5"), "教育"),
        ("gearshape.fill", Color(hex: "#EEEEEE"), "设置")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color.App.textBlack)
                }
                Spacer()
                Text("记一笔")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(Color.App.textBlack)
                Spacer()
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Text("完成")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(hex: "#546073"))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Toggle
                    HStack(spacing: 0) {
                        Button(action: { type = .expense }) {
                            Text("支出")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(type == .expense ? Color.App.textBlack : Color.gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(type == .expense ? Color.white : Color.clear)
                                .clipShape(Capsule())
                                .shadow(color: type == .expense ? Color.black.opacity(0.05) : Color.clear, radius: 2, x: 0, y: 1)
                        }
                        
                        Button(action: { type = .income }) {
                            Text("收入")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(type == .income ? Color.App.textBlack : Color.gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(type == .income ? Color.white : Color.clear)
                                .clipShape(Capsule())
                                .shadow(color: type == .income ? Color.black.opacity(0.05) : Color.clear, radius: 2, x: 0, y: 1)
                        }
                    }
                    .padding(4)
                    .frame(width: 200)
                    .background(Color.App.tabBackground)
                    .clipShape(Capsule())
                    
                    // Amount Input
                    ZStack(alignment: .topTrailing) {
                        RoundedRectangle(cornerRadius: 48)
                            .fill(Color.App.amountBg)
                        
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 120, height: 120)
                            .blur(radius: 20)
                            .offset(x: 40, y: -40)
                        
                        VStack(spacing: 8) {
                            Text("输入金额")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color(hex: "#484A07").opacity(0.6))
                                .kerning(2)
                            
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("¥")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(Color(hex: "#1C1D00"))
                                Text(amount)
                                    .font(.system(size: 64, weight: .black))
                                    .foregroundColor(Color(hex: "#1C1D00"))
                                Capsule()
                                    .fill(Color(hex: "#1C1D00"))
                                    .frame(width: 4, height: 48)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 48))
                    
                    // Categories
                    VStack(spacing: 16) {
                        HStack {
                            Text("分类")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color.App.textBlack)
                            Spacer()
                            Text("更多")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 24) {
                            ForEach(0..<categories.count, id: \.self) { i in
                                VStack(spacing: 8) {
                                    Circle()
                                        .fill(categories[i].bg)
                                        .frame(width: 64, height: 64)
                                        .overlay(
                                            Image(systemName: categories[i].icon)
                                                .font(.system(size: 24))
                                                .foregroundColor(Color.black.opacity(0.8))
                                        )
                                        .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)
                                    
                                    Text(categories[i].label)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Color.App.textBlack.opacity(0.8))
                                }
                            }
                        }
                    }
                    
                    // Project Selector
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: "#E2E2E2"))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "house.fill")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 16))
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("归属项目")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.gray)
                                .kerning(1)
                            Text("日常收支 (Daily Living)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color.App.textBlack)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .foregroundColor(.gray)
                    }
                    .padding(16)
                    .background(Color.App.tabBackground)
                    .clipShape(Capsule())
                    
                    // Note Input
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: "#E2E2E2"))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "pencil")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 16))
                            )
                        
                        TextField("添加备注...", text: .constant(""))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.App.textBlack)
                    }
                    .padding(16)
                    .background(Color.App.tabBackground)
                    .clipShape(Capsule())
                    
                }
                .padding(.horizontal, 24)
            }
            
            // Custom Keyboard
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    KeyButton(label: "1") { handleKey("1") }
                    KeyButton(label: "2") { handleKey("2") }
                    KeyButton(label: "3") { handleKey("3") }
                    KeyButton(icon: "calendar") { }
                }
                HStack(spacing: 16) {
                    KeyButton(label: "4") { handleKey("4") }
                    KeyButton(label: "5") { handleKey("5") }
                    KeyButton(label: "6") { handleKey("6") }
                    KeyButton(label: "+") { }
                }
                HStack(spacing: 16) {
                    KeyButton(label: "7") { handleKey("7") }
                    KeyButton(label: "8") { handleKey("8") }
                    KeyButton(label: "9") { handleKey("9") }
                    KeyButton(label: "-") { }
                }
                HStack(spacing: 16) {
                    KeyButton(label: ".") { handleKey(".") }
                    KeyButton(label: "0") { handleKey("0") }
                    KeyButton(icon: "delete.left.fill") { handleKey("del") }
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Text("完成")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundColor(Color.App.darkGreen)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.App.primaryGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 32))
                    }
                }
            }
            .padding(24)
            .padding(.bottom, 20) // Extra for home indicator
            .background(
                Color.white
                    .clipShape(RoundedRectangle(cornerRadius: 48))
                    .shadow(color: Color.black.opacity(0.05), radius: 20, x: 0, y: -10)
                    .ignoresSafeArea()
            )
        }
        .background(Color.App.backgroundGray.ignoresSafeArea())
    }
    
    private func handleKey(_ key: String) {
        if key == "del" {
            if amount.count > 1 {
                amount.removeLast()
            } else {
                amount = "0"
            }
        } else {
            if amount == "0" && key != "." {
                amount = key
            } else {
                amount += key
            }
        }
    }
}

struct KeyButton: View {
    var label: String? = nil
    var icon: String? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if let label = label {
                    Text(label)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color.App.textBlack)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(Color.App.textBlack)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(height: 64)
            .background(Color.App.tabBackground)
            .clipShape(RoundedRectangle(cornerRadius: 32))
        }
    }
}

#Preview {
    AddRecordView()
}
