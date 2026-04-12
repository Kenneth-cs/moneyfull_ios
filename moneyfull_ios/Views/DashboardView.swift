import SwiftUI

struct DashboardView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Header
                HStack {
                    Spacer()
                    
                    VStack(spacing: 2) {
                        HStack(alignment: .bottom, spacing: 2) {
                            Circle().stroke(Color.App.primaryGreen, lineWidth: 2).frame(width: 8, height: 8)
                            Circle().stroke(Color.App.primaryGreen, lineWidth: 2).frame(width: 12, height: 12)
                            Circle().stroke(Color.App.primaryGreen, lineWidth: 2).frame(width: 6, height: 6)
                        }
                        
                        Text("首页看板")
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundColor(Color.App.textBlack)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .overlay(
                    HStack {
                        Spacer()
                        Image(systemName: "bell")
                            .font(.system(size: 22))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                )
                
                // Top Card
                ZStack(alignment: .topTrailing) {
                    // Card Background
                    RoundedRectangle(cornerRadius: 32)
                        .fill(LinearGradient(
                            colors: [Color.App.primaryGreen, Color.App.lightGreen],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .shadow(color: Color.App.primaryGreen.opacity(0.4), radius: 20, x: 0, y: 10)
                    
                    // Decorative blur circle
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 160, height: 160)
                        .blur(radius: 20)
                        .offset(x: 40, y: -40)
                    
                    // Mascot Speech
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("早安，今天也是平静的一天\n呢~")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.App.darkGreen)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.8).background(.ultraThinMaterial))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.trailing, 24)
                            .padding(.top, 24)
                        
                        // Capybara Mascot
                        ZStack {
                            Text("🍊")
                                .font(.system(size: 20))
                                .offset(y: -24)
                            Text("🦫")
                                .font(.system(size: 40))
                        }
                        .padding(.trailing, 48)
                        .padding(.top, 8)
                    }
                    
                    // Content
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("当前支出")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color.App.darkGreen.opacity(0.8))
                            
                            Text("¥ 678.00")
                                .font(.system(size: 44, weight: .heavy))
                                .foregroundColor(Color.App.darkGreen)
                        }
                        
                        HStack(spacing: 32) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("收入")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color.App.darkGreen.opacity(0.8))
                                Text("¥ 0")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color.App.darkGreen)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("储蓄")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color.App.darkGreen.opacity(0.8))
                                Text("¥ -678")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color.App.darkGreen)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                }
                .padding(.horizontal, 24)
                
                // Ongoing Projects
                VStack(spacing: 16) {
                    HStack {
                        Text("进行中的项目")
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundColor(Color.App.textBlack)
                        Spacer()
                        Text("查看全部")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.App.darkGreen)
                    }
                    .padding(.horizontal, 24)
                    
                    HStack(spacing: 16) {
                        ProjectCard(
                            icon: "paintpalette.fill", iconColor: Color.App.darkOrangeBrown, iconBg: Color.App.lightOrange.opacity(0.3),
                            title: "品牌重塑项目", spent: "3k", budget: "7k", progress: 0.42, progressColor: Color.App.darkGreen
                        )
                        
                        ProjectCard(
                            icon: "house.fill", iconColor: Color.App.darkGreen, iconBg: Color.App.primaryGreen.opacity(0.3),
                            title: "海景房装修", spent: "75k", budget: "100k", progress: 0.75, progressColor: Color.App.darkGreen
                        )
                    }
                    .padding(.horizontal, 24)
                }
                
                // Recent Transactions
                VStack(alignment: .leading, spacing: 16) {
                    Text("最近交易")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(Color.App.textBlack)
                        .padding(.horizontal, 24)
                    
                    VStack(spacing: 12) {
                        TransactionItem(
                            icon: "fork.knife", iconColor: Color.App.darkOrange, iconBg: Color.App.lightOrange.opacity(0.3),
                            title: "海鲜餐厅", desc: "餐饮 • 今天 12:45", amount: "- ¥ 458.00", isExpense: true
                        )
                        TransactionItem(
                            icon: "pencil.tip", iconColor: Color.App.darkGreen, iconBg: Color.App.primaryGreen.opacity(0.3),
                            title: "设计素材", desc: "工作 • 昨天 18:20", amount: "- ¥ 120.00", isExpense: true
                        )
                        TransactionItem(
                            icon: "tram.fill", iconColor: Color.App.darkYellow, iconBg: Color.App.lightYellow.opacity(0.3),
                            title: "交通充值", desc: "交通 • 昨天 08:30", amount: "- ¥ 100.00", isExpense: true
                        )
                        TransactionItem(
                            icon: "briefcase.fill", iconColor: Color.App.darkGreen, iconBg: Color.App.primaryGreen.opacity(0.3),
                            title: "项目结款", desc: "收入 • 10月24日", amount: "+ ¥ 5,000.00", isExpense: false
                        )
                    }
                    .padding(.horizontal, 24)
                }
                
                Spacer().frame(height: 120) // padding for bottom nav
            }
            .background(Color.App.backgroundGray.ignoresSafeArea())
        }
        .background(Color.App.backgroundGray.ignoresSafeArea())
    }
}

struct ProjectCard: View {
    let icon: String
    let iconColor: Color
    let iconBg: Color
    let title: String
    let spent: String
    let budget: String
    let progress: Double
    let progressColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Circle()
                    .fill(iconBg)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: icon)
                            .foregroundColor(iconColor)
                            .font(.system(size: 20))
                    )
                
                Spacer()
                
                Text("进行中")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.App.darkOrangeBrown)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.App.lightOrange)
                    .clipShape(Capsule())
            }
            
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.App.textBlack)
                .lineLimit(1)
            
            HStack {
                Text("已用 ¥\(spent)")
                Spacer()
                Text("预算 ¥\(budget)")
            }
            .font(.system(size: 12))
            .foregroundColor(.gray)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 8)
                    Capsule()
                        .fill(progressColor)
                        .frame(width: geo.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 5)
    }
}

struct TransactionItem: View {
    let icon: String
    let iconColor: Color
    let iconBg: Color
    let title: String
    let desc: String
    let amount: String
    let isExpense: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(iconBg)
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: icon)
                        .foregroundColor(iconColor)
                        .font(.system(size: 20))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.App.textBlack)
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text(amount)
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(isExpense ? Color.App.redExpense : Color.App.darkGreen)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 5)
    }
}

#Preview {
    DashboardView()
}
