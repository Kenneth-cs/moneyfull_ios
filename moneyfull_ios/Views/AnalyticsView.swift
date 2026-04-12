import SwiftUI

struct AnalyticsView: View {
    @EnvironmentObject var store: AppStore
    @State private var trendTab = "month"
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Header
                HStack {
                    HStack(spacing: 8) {
                        AppLogo()
                        Text("财务统计")
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundColor(Color.App.textBlack)
                    }
                    Spacer()
                    Image(systemName: "bell")
                        .font(.system(size: 22))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                // Date Selector
                VStack(spacing: 8) {
                    Text("本月财务概览与分析报告")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Button(action: {}) {
                        HStack(spacing: 8) {
                            Text("2023年10月")
                                .font(.system(size: 14, weight: .bold))
                            Image(systemName: "calendar")
                        }
                        .foregroundColor(Color.App.textBlack.opacity(0.8))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.App.tabBackground)
                        .clipShape(Capsule())
                    }
                }
                
                // Donut Chart Mockup
                VStack(alignment: .leading, spacing: 24) {
                    Text("项目占比")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(Color.App.textBlack)
                    
                    ZStack {
                        Circle()
                            .stroke(Color.App.tabBackground, lineWidth: 40)
                            .frame(width: 200, height: 200)
                        
                        // Fake chart segments
                        Circle()
                            .trim(from: 0, to: 0.42)
                            .stroke(Color.App.primaryGreen, lineWidth: 40)
                            .frame(width: 200, height: 200)
                            .rotationEffect(.degrees(-90))
                        
                        Circle()
                            .trim(from: 0.42, to: 0.84)
                            .stroke(Color.App.lightOrange, lineWidth: 40)
                            .frame(width: 200, height: 200)
                            .rotationEffect(.degrees(-90))
                        
                        Circle()
                            .trim(from: 0.84, to: 0.92)
                            .stroke(Color.App.lightYellow, lineWidth: 40)
                            .frame(width: 200, height: 200)
                            .rotationEffect(.degrees(-90))
                        
                        VStack(spacing: 4) {
                            Text("¥12,840")
                                .font(.system(size: 28, weight: .heavy))
                                .foregroundColor(Color.App.textBlack)
                            Text("总支出")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack(spacing: 16) {
                        HStack {
                            LegendItem(color: Color.App.primaryGreen, title: "软件开发", percentage: "42%")
                            Spacer()
                            LegendItem(color: Color.App.lightOrange, title: "市场营销", percentage: "42%")
                        }
                        HStack {
                            LegendItem(color: Color.App.lightYellow, title: "办公租赁", percentage: "42%") // According to mockup text
                            Spacer()
                            LegendItem(color: Color.App.lightOrange.opacity(0.8), title: "其他杂项", percentage: "42%")
                        }
                    }
                }
                .padding(32)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 48))
                .padding(.horizontal, 24)
                
                // Line Chart Mockup
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Text("项目趋势")
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundColor(Color.App.textBlack)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            TabButton(title: "日", isSelected: trendTab == "day") { trendTab = "day" }
                            TabButton(title: "月", isSelected: trendTab == "month") { trendTab = "month" }
                            TabButton(title: "年", isSelected: trendTab == "year") { trendTab = "year" }
                        }
                        .padding(4)
                        .background(Color.App.primaryGreen.opacity(0.3))
                        .clipShape(Capsule())
                    }
                    
                    // Simple path representation for line chart
                    GeometryReader { geo in
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: geo.size.height * 0.8))
                            path.addQuadCurve(to: CGPoint(x: geo.size.width * 0.2, y: geo.size.height * 0.7),
                                              control: CGPoint(x: geo.size.width * 0.1, y: geo.size.height * 0.8))
                            path.addQuadCurve(to: CGPoint(x: geo.size.width * 0.5, y: geo.size.height * 0.4),
                                              control: CGPoint(x: geo.size.width * 0.35, y: geo.size.height * 0.6))
                            path.addQuadCurve(to: CGPoint(x: geo.size.width * 0.8, y: geo.size.height * 0.2),
                                              control: CGPoint(x: geo.size.width * 0.65, y: geo.size.height * 0.3))
                            path.addQuadCurve(to: CGPoint(x: geo.size.width, y: geo.size.height * 0.1),
                                              control: CGPoint(x: geo.size.width * 0.9, y: geo.size.height * 0.15))
                        }
                        .stroke(Color.App.primaryGreen, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                        
                        // Dots
                        Circle().fill(Color.App.darkGreen).frame(width: 8, height: 8).position(x: geo.size.width * 0.2, y: geo.size.height * 0.7)
                        Circle().fill(Color.App.darkGreen).frame(width: 8, height: 8).position(x: geo.size.width * 0.5, y: geo.size.height * 0.4)
                        Circle().fill(Color.App.darkGreen).frame(width: 8, height: 8).position(x: geo.size.width * 0.8, y: geo.size.height * 0.2)
                    }
                    .frame(height: 160)
                    
                    HStack {
                        Text("5月")
                        Spacer()
                        Text("6月")
                        Spacer()
                        Text("7月")
                        Spacer()
                        Text("8月")
                        Spacer()
                        Text("9月")
                        Spacer()
                        Text("10月")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                }
                .padding(32)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 48))
                .padding(.horizontal, 24)
                
                // Budget Health
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Text("预算健康度")
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundColor(Color.App.textBlack)
                        Spacer()
                        Text("总预算: ¥25,000")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.App.darkGreen)
                    }
                    
                    BudgetBar(title: "办公租赁", amount: "¥4,500 / ¥5,000 (90%)", progress: 0.9, color: Color.App.primaryGreen)
                    BudgetBar(title: "市场营销", amount: "¥6,200 / ¥5,500 (112%)", progress: 1.0, color: Color.App.redExpense, amountColor: Color.App.redExpense)
                    BudgetBar(title: "员工薪酬", amount: "¥8,000 / ¥10,000 (80%)", progress: 0.8, color: Color.App.lightYellow)
                }
                .padding(32)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 48))
                .padding(.horizontal, 24)
                
                Spacer().frame(height: 120)
            }
        }
        .background(Color.App.backgroundGray.ignoresSafeArea())
    }
}

struct LegendItem: View {
    let color: Color
    let title: String
    let percentage: String
    
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 14, height: 14)
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.App.textBlack.opacity(0.8))
            Text(percentage)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color.App.textBlack)
        }
        .frame(minWidth: 120, alignment: .leading)
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(isSelected ? Color.App.darkGreen : Color.App.textBlack.opacity(0.6))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(isSelected ? Color.white : Color.clear)
                .clipShape(Capsule())
                .shadow(color: isSelected ? Color.black.opacity(0.05) : Color.clear, radius: 2, x: 0, y: 1)
        }
    }
}

struct BudgetBar: View {
    let title: String
    let amount: String
    let progress: Double
    let color: Color
    var amountColor: Color = .gray
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.App.textBlack)
                Spacer()
                Text(amount)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(amountColor)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.App.tabBackground)
                        .frame(height: 16)
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * progress, height: 16)
                }
            }
            .frame(height: 16)
        }
    }
}

#Preview {
    AnalyticsView()
}
