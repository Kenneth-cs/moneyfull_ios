import SwiftUI
import UIKit
import SwiftData

// MARK: - 页面顶部标题栏（标题绝对居中，logo 在左，铃铛在右）
struct PageHeader: View {
    let title: String
    
    var body: some View {
        ZStack {
            // 标题绝对居中
            Text(title)
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(Color.App.textBlack)
            
            // 左侧 Logo
            HStack {
                AppLogo()
                Spacer()
            }
            
            // 右侧铃铛
            HStack {
                Spacer()
                Image(systemName: "bell")
                    .font(.system(size: 22))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }
}

struct AppLogo: View {
    var body: some View {
        ZStack {
            // Top Right Large Empty Circle
            Circle()
                .stroke(Color.App.primaryGreen, lineWidth: 2.5)
                .frame(width: 12, height: 12)
                .offset(x: 4, y: -4)
            
            // Bottom Left Medium Empty Circle
            Circle()
                .stroke(Color.App.primaryGreen, lineWidth: 2)
                .frame(width: 8, height: 8)
                .offset(x: -4, y: 4)
            
            // Bottom Right Small Filled Circle
            Circle()
                .fill(Color.App.primaryGreen)
                .frame(width: 5, height: 5)
                .offset(x: 5, y: 6)
        }
        .frame(width: 24, height: 24)
    }
}

struct CapybaraView: View {
    let size: CGFloat
    
    init(size: CGFloat = 72) {
        self.size = size
    }
    
    @State private var isBlinking = false
    let blinkTimer = Timer.publish(every: 3.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Canvas { context, canvasSize in
            let s = min(canvasSize.width, canvasSize.height)
            let scale = s / 100.0
            
            // 1. Orange on top 🍊
            let orangeCenter = CGPoint(x: 50 * scale, y: 22 * scale)
            context.fill(Circle().path(in: CGRect(
                x: orangeCenter.x - 10 * scale, y: orangeCenter.y - 10 * scale,
                width: 20 * scale, height: 20 * scale
            )), with: .color(Color(hex: "#FF9F00")))
            
            // 2. Leaf on orange
            var leaf = Path()
            leaf.move(to: CGPoint(x: 50 * scale, y: 12 * scale))
            leaf.addQuadCurve(
                to: CGPoint(x: 60 * scale, y: 12 * scale),
                control: CGPoint(x: 55 * scale, y: 6 * scale)
            )
            context.stroke(leaf, with: .color(Color(hex: "#2C6956")),
                           style: StrokeStyle(lineWidth: 2.5 * scale, lineCap: .round))
            
            // 3. Body/Head (ellipse for rounder face)
            context.fill(Ellipse().path(in: CGRect(
                x: 20 * scale, y: 30 * scale,
                width: 60 * scale, height: 58 * scale
            )), with: .color(Color(hex: "#B08968")))
            
            // 4. Ears (small circles)
            let earR: CGFloat = 6 * scale
            // Left ear
            context.fill(Circle().path(in: CGRect(
                x: 20 * scale - earR, y: 42 * scale - earR,
                width: earR * 2, height: earR * 2
            )), with: .color(Color(hex: "#7F5539")))
            // Right ear
            context.fill(Circle().path(in: CGRect(
                x: 80 * scale - earR, y: 42 * scale - earR,
                width: earR * 2, height: earR * 2
            )), with: .color(Color(hex: "#7F5539")))
            
            // 5. Snout (ellipse)
            context.fill(Ellipse().path(in: CGRect(
                x: (50 - 16) * scale, y: (68 - 11) * scale,
                width: 32 * scale, height: 22 * scale
            )), with: .color(Color(hex: "#9C6644")))
            
            // 6. Nose (bezier curve)
            var nose = Path()
            nose.move(to: CGPoint(x: 46 * scale, y: 64 * scale))
            nose.addQuadCurve(
                to: CGPoint(x: 54 * scale, y: 64 * scale),
                control: CGPoint(x: 50 * scale, y: 68 * scale)
            )
            context.stroke(nose, with: .color(Color(hex: "#4A3022")),
                           style: StrokeStyle(lineWidth: 2 * scale, lineCap: .round))
            
            // 7. Eyes: open = arc bowing UP ∩ (like ^_^), blink = arc bowing DOWN ∪ (droopy/closed)
            let eyeControlY = isBlinking ? (56 * scale) : (48 * scale)
            // Left eye
            var leftEye = Path()
            leftEye.move(to: CGPoint(x: 33 * scale, y: 52 * scale))
            leftEye.addQuadCurve(
                to: CGPoint(x: 39 * scale, y: 52 * scale),
                control: CGPoint(x: 36 * scale, y: eyeControlY)
            )
            context.stroke(leftEye, with: .color(Color(hex: "#4A3022")),
                           style: StrokeStyle(lineWidth: 2.5 * scale, lineCap: .round))
            // Right eye
            var rightEye = Path()
            rightEye.move(to: CGPoint(x: 61 * scale, y: 52 * scale))
            rightEye.addQuadCurve(
                to: CGPoint(x: 67 * scale, y: 52 * scale),
                control: CGPoint(x: 64 * scale, y: eyeControlY)
            )
            context.stroke(rightEye, with: .color(Color(hex: "#4A3022")),
                           style: StrokeStyle(lineWidth: 2.5 * scale, lineCap: .round))
            
            // 8. Blush (semi-transparent coral ellipses)
            context.opacity = 0.6
            context.fill(Ellipse().path(in: CGRect(
                x: (32 - 4) * scale, y: (60 - 2.5) * scale,
                width: 8 * scale, height: 5 * scale
            )), with: .color(Color(hex: "#FF7F50")))
            context.fill(Ellipse().path(in: CGRect(
                x: (68 - 4) * scale, y: (60 - 2.5) * scale,
                width: 8 * scale, height: 5 * scale
            )), with: .color(Color(hex: "#FF7F50")))
        }
        .id(isBlinking) // Force Canvas to redraw when isBlinking changes
        .frame(width: size, height: size)
        .onReceive(blinkTimer) { _ in
            // Trigger blink every 3 seconds
            isBlinking = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isBlinking = false
            }
        }
    }
}

// MARK: - 卡皮气泡 + 浮动动效组合
struct GreetingMascotView: View {
    @EnvironmentObject var store: AppStore
    @State private var isBreathing = false
    @State private var bounceScale: CGFloat = 1.0
    @State private var currentQuote: String = ""
    @State private var resetTask: Task<Void, Never>?
    @State private var debounceTask: Task<Void, Never>?
    @State private var tapCount: Int = 0
    @State private var isInteracting: Bool = false
    
    private let randomQuotes = [
        "钱不是攒出来的，是赚出来的...但我还是劝你记账🦫",
        "今天没乱花钱吧？",
        "佛系记账，富贵在天✨",
        "深呼吸，世界如此美好，不要为钱暴躁~",
        "别担心，账记着呢，钱也会回来的💪",
        "今天的支出，明天的回忆～",
        "记账使我快乐（假装）😊",
        "小满陪你，一起精打细算🧮",
        "每笔账都是生活的小记号📝",
        "你是最棒的理财小能手！",
        "钱财如水，记账如堤🌊",
        "管好钱包，才能管好人生🔑",
        "坚持记账，已经超越99%的人啦🎉",
        "日拱一卒，功不唐捐💫",
        "今天也要努力不剁手哦🛍️"
    ]
    
    private let level1Quotes = [
        "别戳我，橘子会掉的🍊",
        "戳一戳，财运多～",
        "哎呀，被发现了🦫",
        "你戳到我痒痒肉啦～",
        "诶嘿！还没到记账时间呢～",
        "Hello！今天心情如何？",
        "嘻嘻，又来啦～",
        "轻轻戳一下，满满正能量✨",
        "今天也是元气满满的一天！",
        "欢迎来找小满玩🦫"
    ]
    
    private let level2Quotes = [
        "还在戳？看来今天真的很闲呢～",
        "深呼吸...我是佛系小满",
        "橘子有点晕了哦🍊",
        "我已经在转圈了，别再戳了💫",
        "你戳的每一下，我都在用心感受❤️",
        "再戳我就要去找橘子告状了🍊",
        "哎呦，停下停下～",
        "你是不是没事情做呀？去记个账吧📖",
        "我的耐戳能力有限哦⚠️",
        "小满：请对我温柔一点🥺"
    ]
    
    private let level3Quotes = [
        "打坐中，勿扰 🧘‍♂️",
        "我闭上眼睛，假装没看见你在戳我",
        "溜了溜了，去梦里数钱啦～",
        "你赢了，我已经没词了🏆",
        "我决定退休了，让橘子来接班🍊",
        "此刻我已到达禅境，万物皆空～",
        "疯狂戳戳戳，我已无感🏳️",
        "小满已下线，橘子值班中🍊",
        "恭喜你解锁成就：连击大师🎯",
        "我飞走了，下次再聊🕊️"
    ]
    
    private func generateInteractiveQuote() -> String {
        // 15% 概率触发个性化彩蛋
        if Int.random(in: 1...100) <= 15 {
            let now = Date()
            let hour = Calendar.current.component(.hour, from: now)
            let expense = store.monthlyExpense
            let income = store.monthlyIncome

            var eggs: [String] = []
            if expense > 0 {
                eggs.append("本月已花 ¥\(expense.formatted(.number.precision(.fractionLength(0))))，佛系一点哦～")
            }
            if income > 0 {
                eggs.append("本月入账 ¥\(income.formatted(.number.precision(.fractionLength(0))))，继续努力💪")
            }
            if let firstTx = store.recentTransactions.first {
                eggs.append("刚才的「\(firstTx.categoryName)」记得很棒！继续保持🦫")
            }
            if expense > 0 && income > 0 && expense > income * 0.9 {
                eggs.append("快收支平衡啦，这个月省着点花～")
            }
            if hour >= 22 || hour < 4 {
                eggs.append("这么晚还不睡，是在数钱吗？💤")
            }
            if hour >= 6 && hour < 9 {
                eggs.append("早起的鸟儿有虫吃，早起的你能省几块钱？🐦")
            }
            if !eggs.isEmpty {
                return eggs.randomElement()!
            }
        }
        
        if tapCount <= 1 {
            return level1Quotes.randomElement() ?? "别戳我，橘子会掉的🍊"
        } else if tapCount == 2 {
            return level2Quotes.randomElement() ?? "还在戳？看来今天真的很闲呢～"
        } else {
            return level3Quotes.randomElement() ?? "打坐中，勿扰 🧘‍♂️"
        }
    }
    
    private func generateSmartQuote() -> String {
        if let lastTx = store.recentTransactions.first {
            let diff = Date().timeIntervalSince(lastTx.date)
            if diff < 120 { // < 2 minutes
                return lastTx.type == .expense ? "账本+1，离财务自由又近了一步✨" : "哇塞！发财啦，今晚可以加个鸡腿🍗"
            }
        }
        
        let expense = store.monthlyExpense
        let income = store.monthlyIncome
        if expense == 0 && income > 0 {
            return "今天竟然没花钱！不愧是勤俭持家的你👍"
        } else if expense > 0 && expense > income * 0.9 {
            return "哎呀，最近花得有点多啦，接下来要吃土了吗？💸"
        }
        
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 5 && hour < 10 {
            return "早安，新的一天也要佛系理财哦～"
        } else if hour >= 11 && hour < 14 {
            return "午饭时间到！吃点好的，记得记一笔呀🍱"
        } else if hour >= 22 || hour < 4 {
            return "夜深啦，橘子要掉了，快睡吧💤"
        }
        
        return randomQuotes.randomElement() ?? "早安，今天也是平静的一天呢～"
    }
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            // 气泡：横向拉宽，贴近卡片顶部（黄色框位置）
            Text(currentQuote.isEmpty || isInteracting ? " " : currentQuote)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.App.darkGreen)
                .multilineTextAlignment(.leading)
                .lineSpacing(3)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(width: 172, alignment: .leading)
                .background(
                    ZStack(alignment: .bottomTrailing) {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                        // 尾巴在底部偏右，指向下方卡皮
                        Triangle()
                            .fill(Color.white)
                            .frame(width: 14, height: 10)
                            .offset(x: -28, y: 8)
                    }
                )
                .opacity(currentQuote.isEmpty || isInteracting ? 0 : 1)
                .animation(.easeInOut, value: currentQuote)
            
            // 卡皮：右对齐，位于气泡正下方（红色框位置）
            CapybaraView(size: 80)
                .scaleEffect(bounceScale)
        }
        .offset(y: isBreathing ? -5 : 3)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
            if currentQuote.isEmpty {
                currentQuote = generateSmartQuote()
            }
        }
        .onChange(of: store.recentTransactions) {
            currentQuote = generateSmartQuote()
        }
        .onTapGesture {
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.impactOccurred()

            tapCount += 1
            withAnimation(.easeInOut(duration: 0.15)) {
                isInteracting = true
            }

            let response = tapCount >= 3 ? 0.15 : 0.2
            withAnimation(.spring(response: response, dampingFraction: 0.5, blendDuration: 0)) {
                bounceScale = 0.9
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: response + 0.1, dampingFraction: 0.3, blendDuration: 0)) {
                    bounceScale = 1.0
                }
            }

            debounceTask?.cancel()
            debounceTask = Task {
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard !Task.isCancelled else { return }

                let finalTapCount = tapCount
                let quote = generateInteractiveQuote()
                withAnimation(.easeInOut) {
                    isInteracting = false
                    currentQuote = quote
                }

                let delaySeconds: UInt64
                if finalTapCount <= 2 {
                    delaySeconds = 5
                } else if finalTapCount == 3 {
                    delaySeconds = 10
                } else {
                    delaySeconds = 15
                }

                resetTask?.cancel()
                resetTask = Task {
                    try? await Task.sleep(nanoseconds: delaySeconds * 1_000_000_000)
                    if !Task.isCancelled {
                        withAnimation(.easeInOut) {
                            tapCount = 0
                            currentQuote = generateSmartQuote()
                        }
                    }
                }
            }
        }
    }
}

/// 三角形（气泡小尾巴）
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX - rect.width / 2, y: 0))
        path.addLine(to: CGPoint(x: rect.midX + rect.width / 2, y: 0))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.height))
        path.closeSubpath()
        return path
    }
}

struct SwipeActionView<Content: View>: View {
    let content: Content
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var showDeleteConfirm = false

    private let actionWidth: CGFloat = 72
    private let totalActionWidth: CGFloat = 144

    init(onEdit: @escaping () -> Void, onDelete: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 0) {
                Button(action: onEdit) {
                    VStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .semibold))
                        Text("修改")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(width: actionWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.App.darkGreen)
                }
                Button(action: { showDeleteConfirm = true }) {
                    VStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .semibold))
                        Text("删除")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(width: actionWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.App.redExpense)
                }
            }
            .frame(maxHeight: .infinity)
            // 右侧增加与卡片匹配的圆角
            .mask(
                HStack(spacing: 0) {
                    Rectangle()
                    // 右侧圆角20
                    Rectangle()
                        .cornerRadius(20)
                        .padding(.leading, -20)
                }
            )
            .opacity(offset < 0 ? 1 : 0)

            content
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            let newOffset = value.translation.width
                            if newOffset < 0 {
                                offset = max(newOffset, -totalActionWidth)
                            } else if offset < 0 {
                                offset = min(0, newOffset + offset)
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if offset < -totalActionWidth / 2 {
                                    offset = -totalActionWidth
                                } else {
                                    offset = 0
                                }
                            }
                        }
                )
        }
        .clipped()
        .confirmationDialog("确认删除该账单？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                withAnimation { offset = 0 }
                onDelete()
            }
            Button("取消", role: .cancel) {
                withAnimation { offset = 0 }
            }
        } message: {
            Text("删除后无法恢复。")
        }
    }
}

// MARK: - 账单详情弹层
struct TransactionDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var store: AppStore
    
    let transaction: Transaction
    
    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Circle()
                        .fill(Color(hex: transaction.categoryColorHex).opacity(0.2))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: transaction.categoryIcon)
                                .font(.system(size: 36))
                                .foregroundColor(Color(hex: transaction.categoryColorHex))
                        )
                    
                    Text(transaction.categoryName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text("\(transaction.type == .expense ? "-" : "+") ¥\(transaction.amount.formatted(.number.precision(.fractionLength(2))))")
                        .font(.system(size: 40, weight: .heavy))
                        .foregroundColor(Color.App.textBlack)
                }
                .padding(.top, 40)
                
                VStack(spacing: 0) {
                    DetailRow(title: "交易类型", value: transaction.type == .expense ? "支出" : "收入")
                    Divider().padding(.leading, 16)
                    DetailRow(title: "日期", value: {
                        let f = DateFormatter()
                        f.dateFormat = "yyyy年M月d日 HH:mm"
                        return f.string(from: transaction.date)
                    }())
                    
                    if let projectName = transaction.project?.name {
                        Divider().padding(.leading, 16)
                        DetailRow(title: "归属项目", value: projectName)
                    }
                    
                    if !transaction.note.isEmpty {
                        Divider().padding(.leading, 16)
                        DetailRow(title: "备注", value: transaction.note)
                    }
                }
                .background(Color.App.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)
                
                Spacer()
            }
            .background(Color.App.backgroundGray.edgesIgnoringSafeArea(.all))
            .navigationTitle("账单详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color.App.textBlack)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: { showEditSheet = true }) {
                            Text("修改")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color.App.darkGreen)
                        }
                        Button(action: { showDeleteConfirm = true }) {
                            Text("删除")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color.App.redExpense)
                        }
                    }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                EditTransactionView(transaction: transaction)
                    .environmentObject(store)
            }
            .confirmationDialog("确认删除该账单？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    store.deleteTransaction(transaction)
                    presentationMode.wrappedValue.dismiss()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("删除后无法恢复。")
            }
        }
    }
}

fileprivate struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.gray)
                .frame(width: 70, alignment: .leading)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color.App.textBlack)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
}

#Preview {
    let container = try! ModelContainer(for: Project.self, Transaction.self, Category.self)
    let store = AppStore(modelContext: container.mainContext)
    return VStack(spacing: 40) {
        AppLogo()
        CapybaraView()
        GreetingMascotView()
            .environmentObject(store)
    }
    .padding()
    .background(Color.App.primaryGreen)
}
