import SwiftUI
import StoreKit

// MARK: - Feature Item
private struct PremiumFeature: Identifiable {
    let id = UUID()
    let icon: String
    let iconBg: Color
    let iconFg: Color
    let title: String
    let desc: String
}

private let premiumFeatures: [PremiumFeature] = [
    PremiumFeature(
        icon: "sparkles",
        iconBg: Color(hex: "#FFF0C0"),
        iconFg: Color(hex: "#C08A00"),
        title: "每日 100 次小满调用",
        desc: "语音 · 图片 · 对话全开放，告别次数焦虑"
    ),
    PremiumFeature(
        icon: "folder.fill.badge.plus",
        iconBg: Color.App.primaryGreen.opacity(0.3),
        iconFg: Color.App.darkGreen,
        title: "无限项目抽屉",
        desc: "旅行、装修、创业……想建多少建多少"
    ),
    PremiumFeature(
        icon: "chart.bar.xaxis.ascending",
        iconBg: Color(hex: "#DDE8FF"),
        iconFg: Color(hex: "#4C6EF5"),
        title: "经营看板 · 看清盈亏",
        desc: "现金流 · 成本 · 利润，搞钱项目必看"
    ),
    PremiumFeature(
        icon: "shield.lefthalf.filled",
        iconBg: Color(hex: "#FFE0E0"),
        iconFg: Color(hex: "#E74C3C"),
        title: "预算防线 · 拒绝超支",
        desc: "每日走势 · 超支预警，旅行装修必备"
    ),
    PremiumFeature(
        icon: "wand.and.stars",
        iconBg: Color.App.lightOrange.opacity(0.5),
        iconFg: Color.App.darkOrange,
        title: "小满一键规划预算",
        desc: "说出项目场景，小满自动生成分类预算明细"
    ),
    PremiumFeature(
        icon: "bell.badge.fill",
        iconBg: Color.App.lightYellow.opacity(0.5),
        iconFg: Color.App.darkYellow,
        title: "小满主动提醒",
        desc: "超预算时财务预警提醒，不再不知不觉花超"
    ),
]

// MARK: - Paywall Main View

struct PaywallView: View {
    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedProduct: Product?
    @State private var headerFloat = false
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var wasPremiumOnOpen = false
    @State private var showLegacyGiftLetter = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false

    var body: some View {
        ZStack {
            Color.App.backgroundGray.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    PaywallHeaderSection(isFloating: $headerFloat)
                    PaywallFeaturesSection()
                        .padding(.top, 16)
                    
                    PaywallPlansSection(selectedProduct: $selectedProduct, products: storeManager.getPremiumProducts(), currentProductID: storeManager.currentProductID)
                        .padding(.top, 28)

                    Button(action: {
                        // V2.0 埋点：查看付费说明
                        AnalyticsManager.shared.trackEvent(
                            eventId: "paywall_letter_viewed",
                            eventName: "查看付费说明",
                            params: ["source": "paywall"]
                        )
                        showLegacyGiftLetter = true
                    }) {
                        Text("关于会员付费上线的说明 →")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.App.textSecondary)
                    }
                    .padding(.top, 10)
                    
                    PaywallCTASection(
                        selectedProduct: $selectedProduct,
                        isPurchasing: $isPurchasing,
                        currentProductID: storeManager.currentProductID,
                        onPurchase: purchaseSelectedProduct,
                        onRestore: restorePurchases,
                        onOfferCode: { storeManager.presentOfferCodeSheet() }
                    )
                    .padding(.top, 20)
                    
                    PaywallComparisonSection()
                        .padding(.top, 32)
                    
                    PaywallFinePrint(showTermsOfService: $showTermsOfService, showPrivacyPolicy: $showPrivacyPolicy)
                        .padding(.top, 20)
                        .padding(.bottom, 48)
                }
            }
            .ignoresSafeArea(edges: .top)

            // 透明返回按钮，无任何背景
            Button { dismiss() } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("返回")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.92))
            }
            .buttonStyle(.plain)
            .padding(.leading, 20)
            .padding(.top, 56)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .ignoresSafeArea(edges: .top)
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert("提示", isPresented: $showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            wasPremiumOnOpen = storeManager.isPremium
            if selectedProduct == nil {
                selectedProduct = storeManager.getPremiumProducts().first(where: { $0.id == StoreManager.ProductID.premiumAnnual.rawValue })
            }
        }
        .onChange(of: storeManager.isPremium) { _, isPremium in
            // 仅在从非会员变为会员时 dismiss（即新购买后），已订阅用户打开时不自动关闭
            if isPremium && !wasPremiumOnOpen {
                dismiss()
            }
        }
        .sheet(isPresented: $showLegacyGiftLetter) {
            LegacyGiftLetterView(onDismiss: { showLegacyGiftLetter = false })
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showTermsOfService) {
            TermsOfServiceView()
        }
    }
    
    private func purchaseSelectedProduct() {
        guard let product = selectedProduct else { return }
        isPurchasing = true
        Task {
            do {
                _ = try await storeManager.purchase(product)
                isPurchasing = false
            } catch {
                isPurchasing = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func restorePurchases() {
        isPurchasing = true
        Task {
            await storeManager.restorePurchases()
            isPurchasing = false
            if storeManager.isPremium {
                dismiss()
            } else {
                errorMessage = "未找到可恢复的订阅"
                showError = true
            }
        }
    }
}

// MARK: - Header

private struct PaywallHeaderSection: View {
    @Binding var isFloating: Bool
    @State private var sparkle = false

    private let gradient = LinearGradient(
        colors: [Color(hex: "#103F2B"), Color(hex: "#1A5C40"), Color(hex: "#26825B")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack {
            gradient
                .frame(maxWidth: .infinity)
                .frame(height: 290)

            // Decorative blobs
            Circle()
                .fill(Color.App.primaryGreen.opacity(0.18))
                .frame(width: 260, height: 260)
                .offset(x: -100, y: -60)
                .blur(radius: 40)
            Circle()
                .fill(Color(hex: "#F0C060").opacity(0.15))
                .frame(width: 200, height: 200)
                .offset(x: 120, y: 60)
                .blur(radius: 50)

            VStack(spacing: 12) {
                // Capybara with crown
                ZStack(alignment: .top) {
                    CapybaraView(size: 88)
                    Text("👑")
                        .font(.system(size: 24))
                        .offset(y: -18)
                        .scaleEffect(sparkle ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: sparkle)
                }
                .padding(.top, 78)

                // Badge
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "#F0C060"))
                    Text("小满专业版Pro")
                        .font(.system(size: 13, weight: .black))
                        .kerning(2)
                        .foregroundColor(Color(hex: "#F0C060"))
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "#F0C060"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color(hex: "#F0C060").opacity(0.15))
                        .overlay(Capsule().stroke(Color(hex: "#F0C060").opacity(0.35), lineWidth: 1))
                )

                Text("解锁 AI 财务管家的全部潜力")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("两杯奶茶的钱，换一整年的财务自由")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.bottom, 10)
        }
        .onAppear { sparkle = true }
    }
}

// MARK: - Features

private struct PaywallFeaturesSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 0) {
                ForEach(Array(premiumFeatures.enumerated()), id: \.element.id) { idx, feature in
                    PaywallFeatureRow(feature: feature)
                    if idx < premiumFeatures.count - 1 {
                        Divider()
                            .padding(.leading, 64)
                            .opacity(0.5)
                    }
                }
            }
            .padding(.vertical, 8)
            .background(Color.App.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
        }
        .padding(.horizontal, 20)
    }
}

private struct PaywallFeatureRow: View {
    let feature: PremiumFeature

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(feature.iconBg)
                    .frame(width: 42, height: 42)
                Image(systemName: feature.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(feature.iconFg)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.App.textBlack)
                Text(feature.desc)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(Color.App.darkGreen)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Plans

private struct PaywallPlansSection: View {
    @Binding var selectedProduct: Product?
    let products: [Product]
    var currentProductID: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("选择你的方案")
                .font(.system(size: 12, weight: .black))
                .foregroundColor(.gray.opacity(0.8))
                .kerning(2)
                .padding(.horizontal, 8)

            let monthly = products.first(where: { $0.id == StoreManager.ProductID.premiumMonthly.rawValue })
            let annual = products.first(where: { $0.id == StoreManager.ProductID.premiumAnnual.rawValue })
            let lifetime = products.first(where: { $0.id == StoreManager.ProductID.premiumLifetime.rawValue })
            let hasActivePlan = !currentProductID.isEmpty

            // Monthly + Annual side by side
            HStack(spacing: 12) {
                if let monthly = monthly {
                    PaywallPlanCard(
                        title: "月卡",
                        price: monthly.displayPrice,
                        periodLabel: "/ 月",
                        subLabel: "随时可取消",
                        originalPrice: nil,
                        badge: nil,
                        isRecommended: false,
                        isSelected: selectedProduct?.id == monthly.id,
                        isCurrentPlan: currentProductID == monthly.id,
                        isDimmed: hasActivePlan && currentProductID == monthly.id
                    )
                    .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedProduct = monthly } }
                }
                
                if let annual = annual {
                    PaywallPlanCard(
                        title: "年卡",
                        price: annual.displayPrice,
                        periodLabel: "/ 年",
                        subLabel: "省 43%，≈ ¥5.7/月",
                        originalPrice: "原价 ¥118",
                        badge: "推荐",
                        isRecommended: true,
                        isSelected: selectedProduct?.id == annual.id,
                        isCurrentPlan: currentProductID == annual.id,
                        isDimmed: hasActivePlan && currentProductID == annual.id
                    )
                    .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedProduct = annual } }
                }
            }

            // Lifetime full width
            if let lifetime = lifetime {
                PaywallPlanCardWide(
                    title: "终身",
                    price: lifetime.displayPrice,
                    periodLabel: "买断",
                    subLabel: "一次付清，永久有效",
                    originalPrice: "原价 ¥398",
                    badge: "限时首发",
                    isSelected: selectedProduct?.id == lifetime.id,
                    isCurrentPlan: currentProductID == lifetime.id,
                    isDimmed: hasActivePlan && currentProductID == lifetime.id
                )
                .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedProduct = lifetime } }
            }
        }
        .padding(.horizontal, 20)
    }
}

private struct PaywallPlanCard: View {
    let title: String
    let price: String
    let periodLabel: String
    let subLabel: String
    let originalPrice: String?
    let badge: String?
    let isRecommended: Bool
    let isSelected: Bool
    var isCurrentPlan: Bool = false
    var isDimmed: Bool = false

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 22)
                .fill(isSelected ? Color.App.primaryGreen.opacity(0.09) : Color.App.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(isSelected ? Color.App.darkGreen : Color.App.separator,
                                lineWidth: isSelected ? 2.5 : 1)
                )
                .shadow(color: isSelected ? Color.App.darkGreen.opacity(0.15) : Color.black.opacity(0.03),
                        radius: isSelected ? 14 : 8, x: 0, y: 4)

            VStack(spacing: 5) {
                if isCurrentPlan {
                    Text("当前方案")
                        .font(.system(size: 10, weight: .black))
                        .kerning(0.5)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.gray.opacity(0.15)))
                        .padding(.top, 14)
                } else if let badge = badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .black))
                        .kerning(0.5)
                        .foregroundColor(isSelected ? .white : Color.App.darkGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(isSelected ? Color.App.darkGreen : Color.App.primaryGreen.opacity(0.25)))
                        .padding(.top, 14)
                } else {
                    Spacer().frame(height: 34)
                }

                Text(title)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(Color.App.textBlack)

                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(price)
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundColor(isSelected ? Color.App.darkGreen : Color.App.textBlack)
                    Text(periodLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.App.textSecondary)
                }

                if let originalPrice = originalPrice {
                    Text(originalPrice)
                        .font(.system(size: 11, weight: .medium))
                        .strikethrough(true, color: Color.App.textSecondary.opacity(0.5))
                        .foregroundColor(Color.App.textSecondary.opacity(0.6))
                }

                Text(subLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.App.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 172)
        .scaleEffect(isSelected && isRecommended ? 1.02 : 1.0)
        .opacity(isDimmed ? 0.5 : 1.0)
    }
}

private struct PaywallPlanCardWide: View {
    let title: String
    let price: String
    let periodLabel: String
    let subLabel: String
    let originalPrice: String?
    let badge: String?
    let isSelected: Bool
    var isCurrentPlan: Bool = false
    var isDimmed: Bool = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(Color.App.textBlack)
                    if isCurrentPlan {
                        Text("当前方案")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.gray.opacity(0.15)))
                    } else if let badge = badge {
                        Text(badge)
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(isSelected ? .white : Color(hex: "#C08A00"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(isSelected ? Color(hex: "#C08A00") : Color(hex: "#FFF0C0")))
                    }
                }
                Text(subLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.App.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(price)
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundColor(isSelected ? Color.App.darkGreen : Color.App.textBlack)
                    Text(periodLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.App.textSecondary)
                }
                if let originalPrice = originalPrice {
                    Text(originalPrice)
                        .font(.system(size: 11, weight: .medium))
                        .strikethrough(true, color: Color.App.textSecondary.opacity(0.5))
                        .foregroundColor(Color.App.textSecondary.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(isSelected ? Color.App.primaryGreen.opacity(0.09) : Color.App.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(isSelected ? Color.App.darkGreen : Color.App.separator,
                        lineWidth: isSelected ? 2.5 : 1)
        )
        .shadow(color: isSelected ? Color.App.darkGreen.opacity(0.1) : Color.black.opacity(0.03),
                radius: isSelected ? 12 : 6, x: 0, y: 3)
        .opacity(isDimmed ? 0.5 : 1.0)
    }
}

// MARK: - Comparison Section

private struct PaywallComparisonSection: View {
    let rows: [(title: String, free: String, pro: String)] = [
        ("小满记账次数", "10 次 / 天", "100 次 / 天"),
        ("项目创建数量", "3 个", "无限"),
        ("预算分类数量", "最多 3 个", "不限"),
        ("小满预算规划", "—", "帮你规划"),
        ("经营看板", "—", "四维分析"),
        ("预算防线", "基础版", "完整版"),
        ("预算预警提醒", "—", "财务实时监控"),
        ("项目复盘总结", "—", "专业洞察建议"),
        ("账单导入导出", "支持", "支持"),
        ("CloudKit 同步", "支持", "支持"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("权益对比")
                .font(.system(size: 12, weight: .black))
                .foregroundColor(.gray.opacity(0.8))
                .kerning(2)
                .padding(.horizontal, 8)

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("功能")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.gray)
                        .frame(width: 100, alignment: .leading)
                    Spacer()
                    Text("免费版")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.gray)
                        .frame(width: 70, alignment: .center)
                    Spacer()
                    Text("专业版")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(hex: "#C08A00"))
                        .frame(width: 80, alignment: .center)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.App.cardBackground)

                Divider().opacity(0.5)

                // Rows
                ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                    HStack {
                        Text(row.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.App.textBlack)
                            .frame(width: 100, alignment: .leading)
                        Spacer()
                        Text(row.free)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.gray)
                            .frame(width: 70, alignment: .center)
                        Spacer()
                        Text(row.pro)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(row.pro == "—" ? .gray : Color.App.darkGreen)
                            .frame(width: 80, alignment: .center)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(idx % 2 == 0 ? Color.App.cardBackground.opacity(0.4) : Color.App.cardBackground)

                    if idx < rows.count - 1 {
                        Divider().opacity(0.3)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.App.separator, lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - CTA Section

private struct PaywallCTASection: View {
    @Binding var selectedProduct: Product?
    @Binding var isPurchasing: Bool
    let currentProductID: String
    let onPurchase: () -> Void
    let onRestore: () -> Void
    let onOfferCode: () -> Void

    private func planLevel(_ id: String) -> Int {
        switch id {
        case StoreManager.ProductID.premiumLifetime.rawValue: return 3
        case StoreManager.ProductID.premiumAnnual.rawValue:   return 2
        case StoreManager.ProductID.premiumMonthly.rawValue:  return 1
        default: return 0
        }
    }

    private var isCurrentPlan: Bool {
        guard !currentProductID.isEmpty, let selected = selectedProduct else { return false }
        return selected.id == currentProductID
    }

    private var isDowngrade: Bool {
        guard let sel = selectedProduct else { return false }
        return planLevel(sel.id) < planLevel(currentProductID)
    }

    private var planName: String {
        guard let product = selectedProduct else { return "" }
        if product.id == StoreManager.ProductID.premiumAnnual.rawValue { return "年卡" }
        if product.id == StoreManager.ProductID.premiumLifetime.rawValue { return "终身" }
        return "月卡"
    }

    private var ctaTitle: String {
        guard let product = selectedProduct else { return "请选择方案" }
        if isCurrentPlan { return "已是当前方案" }
        if isDowngrade { return "如需降级请前往订阅管理" }
        switch product.id {
        case StoreManager.ProductID.premiumAnnual.rawValue:
            return "升级到年卡 \(product.displayPrice)"
        case StoreManager.ProductID.premiumLifetime.rawValue:
            return "买断终身 \(product.displayPrice)"
        default:
            return "开通月卡 \(product.displayPrice)"
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            // Main CTA
            Button(action: onPurchase) {
                HStack(spacing: 8) {
                    if isPurchasing {
                        ProgressView()
                            .tint(Color(hex: "#103F2B"))
                    } else {
                        Text(ctaTitle)
                            .font(.system(size: 17, weight: .heavy))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .foregroundColor(isDowngrade ? .white : Color(hex: "#103F2B"))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    isDowngrade
                        ? AnyShapeStyle(Color.gray.opacity(0.3))
                        : AnyShapeStyle(LinearGradient(
                            colors: [Color.App.primaryGreen, Color(hex: "#63C7A1")],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                )
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: isDowngrade ? .clear : Color.App.primaryGreen.opacity(0.4), radius: 12, x: 0, y: 6)
            }
            .disabled(isPurchasing || selectedProduct == nil || isCurrentPlan || isDowngrade)
            .padding(.horizontal, 20)

            // 提示文案
            if !isCurrentPlan && !isDowngrade && selectedProduct != nil {
                Text("· 立即生效，按比例计算差价 ·")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray.opacity(0.5))
            }

            // Secondary actions
            HStack(spacing: 0) {
                Button(action: onRestore) {
                    Text("恢复购买")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)
                }
                Text("  ·  ")
                    .font(.system(size: 13))
                    .foregroundColor(.gray.opacity(0.5))
                Button(action: onOfferCode) {
                    Text("兑换会员码")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

// MARK: - Fine Print

private struct PaywallFinePrint: View {
    @Binding var showTermsOfService: Bool
    @Binding var showPrivacyPolicy: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            Text("订阅将自动续费，可随时在 App Store 设置中取消")
                .font(.system(size: 11))
                .foregroundColor(.gray.opacity(0.6))
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Button(action: { showTermsOfService = true }) {
                    Text("服务条款")
                        .font(.system(size: 11))
                        .foregroundColor(.gray.opacity(0.6))
                        .underline()
                }
                Button(action: { showPrivacyPolicy = true }) {
                    Text("隐私政策")
                        .font(.system(size: 11))
                        .foregroundColor(.gray.opacity(0.6))
                        .underline()
                }
            }
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Profile Entry Components

/// 未订阅时展示的 Premium 横幅（嵌入 ProfileView）
struct PremiumUpgradeBanner: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#103F2B"), Color(hex: "#26825B")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                    Text("👑")
                        .font(.system(size: 22))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("升级小满专业版Pro")
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundColor(Color(hex: "#103F2B"))
                            .lineLimit(1)
                        Text("NEW")
                            .font(.system(size: 9, weight: .black))
                            .kerning(0.5)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color(hex: "#26825B")))
                    }
                    Text("100 次小满 · 无限项目 · 经营看板 · AI 复盘")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#1A5C40").opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(hex: "#1A5C40").opacity(0.6))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#F2F9E8"), Color(hex: "#FFF8E7")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color(hex: "#E5F0D8"), lineWidth: 1)
            )
            .shadow(color: Color(hex: "#D4E6C3").opacity(0.4), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

/// 已订阅时展示的状态行（嵌入 ProfileView 菜单区）
struct PremiumStatusRow: View {
    let planTitle: String
    let expiryText: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#103F2B"), Color(hex: "#26825B")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 42, height: 42)
                    Text("👑")
                        .font(.system(size: 18))
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(planTitle.isEmpty ? "专业版" : "专业版 \(planTitle)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color.App.textBlack)
                        Text("已激活")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(Color.App.darkGreen)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.App.primaryGreen.opacity(0.3)))
                    }
                    Text(expiryText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

/// 兑换会员码行（嵌入 ProfileView 菜单区底部）
struct RedeemCodeRow: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.App.lightYellow.opacity(0.5))
                        .frame(width: 42, height: 42)
                    Image(systemName: "gift.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color.App.darkYellow)
                }
                Text("兑换会员码")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.App.textBlack)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}
