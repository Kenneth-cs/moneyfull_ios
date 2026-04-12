import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Header
                HStack {
                    HStack(spacing: 8) {
                        AppLogo()
                        Text("个人中心")
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
                
                // User Info
                VStack(spacing: 12) {
                    ZStack(alignment: .bottomTrailing) {
                        Circle()
                            .fill(LinearGradient(colors: [Color.App.primaryGreen, .white], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 128, height: 128)
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                            .overlay(
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundColor(Color.App.primaryGreen.opacity(0.8))
                                    .clipShape(Circle())
                                    .padding(8)
                            )
                        
                        Circle()
                            .fill(Color.App.primaryGreen)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "pencil")
                                    .foregroundColor(Color.App.darkGreen)
                                    .font(.system(size: 16, weight: .bold))
                            )
                            .overlay(Circle().stroke(Color.App.backgroundGray, lineWidth: 4))
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            .offset(x: -4, y: -4)
                    }
                    
                    Text("Julian Thorne")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundColor(Color.App.textBlack)
                    
                    Text("高级财务分析师")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 16)
                
                // Stats
                HStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Image(systemName: "folder.fill.badge.gearshape")
                            .font(.system(size: 24))
                            .foregroundColor(Color.App.darkGreen)
                        Text("12")
                            .font(.system(size: 32, weight: .black))
                            .foregroundColor(Color.App.darkGreen)
                        Text("活跃项目")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.App.darkGreen.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color.App.primaryGreen.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                    
                    VStack(spacing: 8) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color.App.darkYellow)
                        Text("48")
                            .font(.system(size: 32, weight: .black))
                            .foregroundColor(Color.App.darkYellow)
                        Text("总账目")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.App.darkYellow.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color.App.lightYellow.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                }
                .padding(.horizontal, 24)
                
                // Menu
                VStack(alignment: .leading, spacing: 16) {
                    Text("账户管理")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.gray.opacity(0.8))
                        .kerning(2)
                        .padding(.horizontal, 8)
                    
                    VStack(spacing: 0) {
                        MenuItem(icon: "arrow.down.doc", iconBg: Color.App.lightOrange.opacity(0.4), iconColor: Color.App.darkOrange, title: "导出数据")
                        MenuItem(icon: "paintpalette", iconBg: Color.App.primaryGreen.opacity(0.4), iconColor: Color.App.darkGreen, title: "主题设置")
                        MenuItem(icon: "bell", iconBg: Color.App.lightYellow.opacity(0.6), iconColor: Color.App.darkYellow, title: "通知偏好")
                        MenuItem(icon: "questionmark.circle", iconBg: Color.gray.opacity(0.1), iconColor: .gray, title: "帮助与反馈", hasBorder: false)
                    }
                    .padding(8)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                    .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 24)
                
                // Logout
                Button(action: {}) {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("退出登录")
                    }
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "#93000A"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color(hex: "#FFDAD6"))
                    .clipShape(Capsule())
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                Spacer().frame(height: 120) // padding for bottom nav
            }
        }
        .background(Color.App.backgroundGray.ignoresSafeArea())
    }
}

struct MenuItem: View {
    let icon: String
    let iconBg: Color
    let iconColor: Color
    let title: String
    var hasBorder: Bool = true
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(iconBg)
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: icon)
                        .foregroundColor(iconColor)
                        .font(.system(size: 20, weight: .semibold))
                )
            
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.App.textBlack)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(Color.gray.opacity(0.5))
                .font(.system(size: 16, weight: .semibold))
        }
        .padding(16)
        .overlay(
            Group {
                if hasBorder {
                    Divider()
                        .background(Color.gray.opacity(0.1))
                        .padding(.leading, 80)
                }
            },
            alignment: .bottom
        )
    }
}

#Preview {
    ProfileView()
}
