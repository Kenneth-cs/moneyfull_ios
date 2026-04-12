import SwiftUI

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
            
            // 7. Eyes (relaxed/closed arcs)
            // Left eye
            var leftEye = Path()
            leftEye.move(to: CGPoint(x: 33 * scale, y: 52 * scale))
            leftEye.addQuadCurve(
                to: CGPoint(x: 39 * scale, y: 52 * scale),
                control: CGPoint(x: 36 * scale, y: 50 * scale)
            )
            context.stroke(leftEye, with: .color(Color(hex: "#4A3022")),
                           style: StrokeStyle(lineWidth: 2.5 * scale, lineCap: .round))
            // Right eye
            var rightEye = Path()
            rightEye.move(to: CGPoint(x: 61 * scale, y: 52 * scale))
            rightEye.addQuadCurve(
                to: CGPoint(x: 67 * scale, y: 52 * scale),
                control: CGPoint(x: 64 * scale, y: 50 * scale)
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
        .frame(width: size, height: size)
    }
}

// MARK: - 卡皮气泡 + 浮动动效组合
struct GreetingMascotView: View {
    @State private var isBreathing = false
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            // 气泡
            Text("早安，今天也是\n平静的一天呢～")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.App.darkGreen)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white)
                        Triangle()
                            .fill(Color.white)
                            .frame(width: 14, height: 8)
                            .offset(x: 10, y: 7)
                    }
                )
            
            // 卡皮
            CapybaraView(size: 72)
                .padding(.trailing, 8)
        }
        .offset(y: isBreathing ? -6 : 4)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                isBreathing = true
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

#Preview {
    VStack(spacing: 40) {
        AppLogo()
        CapybaraView()
        GreetingMascotView()
    }
    .padding()
    .background(Color.App.primaryGreen)
}
