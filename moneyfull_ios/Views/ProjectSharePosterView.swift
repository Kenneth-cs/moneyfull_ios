import SwiftUI
import UIKit

/// 个人项目分享海报（专为 ImageRenderer 导出设计，宽度固定 390pt）
struct ProjectSharePosterView: View {
    let project: Project
    let categorySegments: [(name: String, amount: Double, colorHex: String, icon: String)]
    let projectMode: ProjectMode
    /// 按日期降序排列的账单，传入前已在调用方排好序
    let transactions: [Transaction]

    private var colorPair: ProgressColorPair { progressColorPair(for: project.colorHex) }
    private var accentColor: Color { Color(hex: colorPair.end) }
    private var accentLight: Color { Color(hex: colorPair.start) }

    private var totalSpent: Double { project.totalSpent }
    private var totalIncome: Double { project.totalIncome }
    private var netProfit: Double { totalIncome - totalSpent }

    private var topCategories: [(name: String, amount: Double, colorHex: String, icon: String)] {
        Array(categorySegments.prefix(5))
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection       // 渐变项目信息
            statsSection        // 核心数字
            categorySection     // 分类占比
            if !transactions.isEmpty {
                transactionSection  // 账单时间轴
            }
            qrFooterSection     // 二维码底部
        }
        .background(Color.white)
        .frame(width: 390)
    }

    // MARK: - 渐变项目信息 Header

    private var headerSection: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [accentColor, accentLight.opacity(0.6)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .frame(height: 140)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: project.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                    Text(project.name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    // 模式标签
                    Text(projectMode == .earning ? "搞钱模式" : "生活模式")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.9))
                        .clipShape(Capsule())
                }
                Text(dateRangeText)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.75))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }

    // MARK: - 核心数据

    private var statsSection: some View {
        HStack(spacing: 0) {
            if projectMode == .earning {
                statItem(title: "总收入", amount: totalIncome, color: Color(hex: "#2C6957"))
                Divider().frame(height: 40)
                statItem(title: "总支出", amount: totalSpent, color: Color(hex: "#E05C5C"))
                Divider().frame(height: 40)
                statItem(title: "净收益", amount: netProfit,
                         color: netProfit >= 0 ? Color(hex: "#2C6957") : Color(hex: "#E05C5C"))
            } else {
                statItem(title: "总支出", amount: totalSpent, color: Color(hex: "#E05C5C"))
                Divider().frame(height: 40)
                statItem(title: "预算", amount: project.budget, color: Color(hex: "#999999"))
                Divider().frame(height: 40)
                statItem(title: "剩余", amount: project.budget - totalSpent,
                         color: (project.budget - totalSpent) >= 0 ? Color(hex: "#2C6957") : Color(hex: "#E05C5C"))
            }
        }
        .padding(.vertical, 20)
        .background(Color(hex: "#F9FAFB"))
    }

    private func statItem(title: String, amount: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#999999"))
            Text("¥\(formatAmount(abs(amount)))")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 分类占比

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("支出分类")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(hex: "#1A1A1A"))
                Spacer()
                Text("Top \(topCategories.count)")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#999999"))
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)

            if topCategories.isEmpty {
                Text("暂无支出记录")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#BBBBBB"))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(topCategories.enumerated()), id: \.offset) { i, cat in
                        categoryRow(cat: cat, rank: i + 1)
                        if i < topCategories.count - 1 {
                            Divider().padding(.leading, 24)
                        }
                    }
                }
            }
        }
        .padding(.bottom, 4)
    }

    // 进度条宽度：视图固定 390pt，横向布局中给 bar 分配 160pt 宽度
    private static let barMaxWidth: CGFloat = 160

    private func categoryRow(cat: (name: String, amount: Double, colorHex: String, icon: String), rank: Int) -> some View {
        let pct = totalSpent > 0 ? CGFloat(cat.amount / totalSpent) : 0
        let barWidth = max(4, Self.barMaxWidth * pct)
        return HStack(spacing: 12) {
            // 色块 + 图标
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: cat.colorHex).opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: cat.icon)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: cat.colorHex))
            }
            // 分类名 + 固定宽度进度条（不用 GeometryReader，ImageRenderer 兼容）
            VStack(alignment: .leading, spacing: 4) {
                Text(cat.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "#1A1A1A"))
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "#F0F0F0"))
                        .frame(width: Self.barMaxWidth, height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: cat.colorHex))
                        .frame(width: barWidth, height: 4)
                }
            }
            Spacer()
            // 金额 + 百分比
            VStack(alignment: .trailing, spacing: 2) {
                Text("¥\(formatAmount(cat.amount))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#1A1A1A"))
                Text("\(Int(pct * 100))%")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#999999"))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    // MARK: - 账单时间轴（最近 20 笔，按日分组）

    private var transactionSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("账单明细")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(hex: "#1A1A1A"))
                Spacer()
                Text("最近 \(min(transactions.count, 20)) 笔")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#999999"))
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // 分隔线
            Rectangle()
                .fill(Color(hex: "#F5F5F5"))
                .frame(height: 1)

            ForEach(groupedTransactions, id: \.key) { group in
                // 日期分组 header
                Text(group.key)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#BBBBBB"))
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 4)

                ForEach(group.value) { tx in
                    txRow(tx)
                    Rectangle()
                        .fill(Color(hex: "#F8F8F8"))
                        .frame(height: 1)
                        .padding(.leading, 68)
                }
            }
        }
        .padding(.bottom, 8)
    }

    private func txRow(_ tx: Transaction) -> some View {
        HStack(spacing: 12) {
            // 分类图标圆
            ZStack {
                Circle()
                    .fill(Color(hex: tx.categoryColorHex).opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: tx.categoryIcon.isEmpty ? "questionmark" : tx.categoryIcon)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: tx.categoryColorHex))
            }
            // 名称 + 时间
            VStack(alignment: .leading, spacing: 2) {
                Text(tx.note.isEmpty ? tx.categoryName : tx.note)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "#1A1A1A"))
                    .lineLimit(1)
                Text(txTimeText(tx.date))
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#BBBBBB"))
            }
            Spacer()
            // 金额
            Text(String(format: "%@¥%.2f",
                        tx.type == .expense ? "-" : "+",
                        tx.amount))
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(tx.type == .expense ? Color(hex: "#E05C5C") : Color(hex: "#2C6957"))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
    }

    /// 按日期分组，最多取 20 笔
    private var groupedTransactions: [(key: String, value: [Transaction])] {
        let recent = Array(transactions.prefix(20))
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy年M月d日"
        var dict: [(key: String, value: [Transaction])] = []
        var keys: [String] = []
        for tx in recent {
            let k = fmt.string(from: tx.date)
            if let i = dict.firstIndex(where: { $0.key == k }) {
                dict[i].value.append(tx)
            } else {
                dict.append((key: k, value: [tx]))
                keys.append(k)
            }
        }
        return dict
    }

    private func txTimeText(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: date)
    }

    // MARK: - 二维码底部

    private var qrFooterSection: some View {
        // App Store 下载二维码（扫码下载 App）
        let qrContent = "https://apps.apple.com/cn/app/id6762140727"
        let qrImage = QRCodeHelper.generate(from: qrContent, size: 180) // 高分辨率再缩小显示

        return HStack(spacing: 16) {
            // 左侧文字
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(accentColor)
                    Text("钱小满")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "#1A1A1A"))
                }
                Text("向着财务自由前进！")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#555555"))
                Text("扫码下载 App")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#BBBBBB"))
                    .padding(.top, 2)
                Text(posterDateText)
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#CCCCCC"))
            }

            Spacer()

            // 右侧二维码
            if let qr = qrImage {
                VStack(spacing: 4) {
                    Image(uiImage: qr)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .padding(6)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(hex: "#E8E8E8"), lineWidth: 1)
                        )
                        .cornerRadius(8)
                    Text("扫码下载")
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: "#CCCCCC"))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(Color(hex: "#F9FAFB"))
    }

    // MARK: - 辅助

    private var dateRangeText: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy年M月d日"
        let start = fmt.string(from: project.createdAt)
        fmt.dateFormat = "M月d日"
        let end = fmt.string(from: Date())
        return "\(start) - \(end)"
    }

    private var posterDateText: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy.MM.dd"
        return fmt.string(from: Date())
    }

    private func formatAmount(_ v: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: v)) ?? "\(Int(v))"
    }
}
