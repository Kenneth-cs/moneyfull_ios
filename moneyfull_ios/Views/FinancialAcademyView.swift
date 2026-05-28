import SwiftUI

struct FinancialAcademyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            Color(hex: "#FAFBFA").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.backward")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(hex: "#276956"))
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.8))
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 2)
                    }
                    Spacer()
                    Text("✨ 财商学堂 ✨")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#226552"))
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.7).background(.ultraThinMaterial).ignoresSafeArea(edges: .top))
                .overlay(Rectangle().fill(Color(hex: "#E1E3E2").opacity(0.2)).frame(height: 1), alignment: .bottom)
                
                // Tab 切换
                HStack(spacing: 0) {
                    tabButton(title: "财务知识", index: 0)
                    tabButton(title: "经典书籍", index: 1)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(Color.white)
                
                if selectedTab == 0 {
                    articlesList
                } else {
                    booksList
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    @ViewBuilder
    private func tabButton(title: String, index: Int) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index }
        }) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: selectedTab == index ? .bold : .medium))
                    .foregroundColor(selectedTab == index ? Color(hex: "#276956") : Color.gray)
                
                Rectangle()
                    .fill(selectedTab == index ? Color(hex: "#9EE0C8") : Color.clear)
                    .frame(height: 3)
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - 财务知识文章
    private var articlesList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                ForEach(financialArticles) { article in
                    ArticleCard(article: article)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - 经典书籍摘要
    private var booksList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                ForEach(classicBooks) { book in
                    BookCard(book: book)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - 文章模型
struct Article: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let content: String
    let tag: String
}

// MARK: - 书籍模型
struct BookSummary: Identifiable {
    let id = UUID()
    let cover: String
    let title: String
    let author: String
    let summary: String
    let keyPoints: [String]
}

// MARK: - 文章卡片
struct ArticleCard: View {
    let article: Article
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Text(article.icon)
                    .font(.system(size: 28))
                    .frame(width: 44, height: 44)
                    .background(Color(hex: "#F0FBF6"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(article.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(hex: "#1A3C2E"))
                        Spacer()
                        Text(article.tag)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "#276956"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(hex: "#9EE0C8").opacity(0.3))
                            .clipShape(Capsule())
                    }
                    Text(article.subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(Color.gray)
                        .lineLimit(2)
                }
            }
            
            if isExpanded {
                Text(article.content)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#3A3A3A"))
                    .lineSpacing(6)
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) { isExpanded.toggle() }
            }) {
                HStack(spacing: 4) {
                    Text(isExpanded ? "收起" : "阅读全文")
                        .font(.system(size: 13, weight: .medium))
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(Color(hex: "#276956"))
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
    }
}

// MARK: - 书籍卡片
struct BookCard: View {
    let book: BookSummary
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                Text(book.cover)
                    .font(.system(size: 36))
                    .frame(width: 52, height: 68)
                    .background(Color(hex: "#FFF8E1"))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "#1A3C2E"))
                    Text(book.author)
                        .font(.system(size: 12))
                        .foregroundColor(Color.gray)
                    Text(book.summary)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#4A7A5E"))
                        .lineLimit(isExpanded ? nil : 2)
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text("💡 核心要点")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "#276956"))
                    
                    ForEach(book.keyPoints.indices, id: \.self) { i in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(i + 1).")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(hex: "#9EE0C8"))
                            Text(book.keyPoints[i])
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "#3A3A3A"))
                                .lineSpacing(4)
                        }
                    }
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) { isExpanded.toggle() }
            }) {
                HStack(spacing: 4) {
                    Text(isExpanded ? "收起" : "查看摘要")
                        .font(.system(size: 13, weight: .medium))
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(Color(hex: "#276956"))
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
    }
}

// MARK: - 数据
let financialArticles: [Article] = [
    // MARK: - 预算规划 (8篇)
    Article(icon: "💰", title: "50/30/20 预算法则", subtitle: "最简单的预算分配方法，适合理财新手入门",
            content: "50/30/20 法则是哈佛大学 Elizabeth Warren 提出的经典预算方法：\n\n• 50% 用于必要支出：房租、水电、交通、餐饮等生活必需品\n• 30% 用于个人消费：娱乐、购物、旅行等提升生活品质的开支\n• 20% 用于储蓄和还债：应急基金、投资理财、偿还贷款\n\n核心理念是「先储蓄后消费」。每月收入到账后，先自动转出 20% 到储蓄账户，再分配剩余部分。坚持 3 个月就能养成习惯。", tag: "入门"),
    Article(icon: "📋", title: "信封预算法：古老但有效", subtitle: "用实体或虚拟信封控制每类消费上限",
            content: "信封预算法是最古老的预算方法之一，至今仍然有效。\n\n操作方法：\n① 将每月收入分成若干「信封」：餐饮、交通、娱乐、购物等\n② 每个信封放入对应金额的预算\n③ 消费时从对应信封取钱\n④ 信封空了，该类消费就停止\n\n数字化版本可以用记账 App 的预算功能替代实体信封。关键在于：每类消费有明确上限，花完就停。", tag: "入门"),
    Article(icon: "🎯", title: "零基预算法：每一分钱都有去处", subtitle: "收入 - 支出 = 0，让每块钱都找到归属",
            content: "零基预算法的核心：收入减去所有支出（包括储蓄）等于零。\n\n不是说花光所有钱，而是给每块钱分配任务：\n• 收入 10000 元\n• 房租 3000 + 餐饮 2000 + 交通 500 + 储蓄 2000 + 投资 1500 + 娱乐 1000 = 10000\n\n这种方法的优势是避免「不知道钱花哪了」的情况。每月初花 15 分钟做一次零基预算，能显著减少无意识消费。", tag: "入门"),
    Article(icon: "📱", title: "记账三个月后该做什么", subtitle: "记账不是目的，分析和优化才是",
            content: "很多人记账几个月后就放弃了，因为「记了也不知道怎么改」。\n\n记账三个月后的行动指南：\n① 导出三个月数据，按类别汇总\n② 找出前 3 大支出类别\n③ 分析哪些是必要支出，哪些可以优化\n④ 设定下个月的预算目标\n⑤ 每月对比，持续优化\n\n记账的终极目标不是记录每一笔，而是发现消费模式并做出改变。", tag: "实用"),
    Article(icon: "🏠", title: "房租占收入多少才合理", subtitle: "30% 法则不是万能的，要因地制宜",
            content: "国际通行标准：房租不超过月收入的 30%。\n\n但在一线城市，这个比例可能很难达到。更灵活的思路：\n• 理想：房租 ≤ 25%（有充足余量投资和储蓄）\n• 可接受：房租 ≤ 35%（需要控制其他开支）\n• 警戒线：房租 > 40%（严重影响生活质量）\n\n降低房租占比的方法：合租、选择稍远但交通便利的区域、与房东谈长租优惠。", tag: "实用"),
    Article(icon: "🍽️", title: "餐饮开支如何合理控制", subtitle: "不亏待自己，也不浪费钱",
            content: "餐饮通常是仅次于房租的第二大开支。\n\n省钱但不亏待自己的方法：\n• 工作日午餐带饭，每周省 100-200 元\n• 减少外卖频次，自己做饭成本约为外卖的 1/3\n• 聚餐 AA 制，避免「面子消费」\n• 超市购物前列清单，避免冲动购买\n\n建议餐饮预算：月收入的 15-20%。如果超过 25%，就有优化空间。", tag: "实用"),
    Article(icon: "📊", title: "年度财务回顾怎么做", subtitle: "每年年底做一次全面的财务体检",
            content: "年度财务回顾清单：\n① 计算年度总收入和总支出\n② 计算储蓄率（储蓄/收入）\n③ 检查投资收益情况\n④ 盘点资产和负债\n⑤ 评估保险是否充足\n⑥ 设定新一年的财务目标\n\n好的储蓄率目标：20% 以上为良好，30% 以上为优秀，50% 以上为 FIRE 级别。", tag: "进阶"),
    Article(icon: "🧮", title: "如何制定年度储蓄目标", subtitle: "把大目标拆解成每月可执行的小步骤",
            content: "设定年度储蓄目标的步骤：\n① 回顾去年储蓄情况\n② 设定今年的目标金额（建议比去年多 10-20%）\n③ 除以 12 得到每月目标\n④ 发工资当天自动转账到储蓄账户\n⑤ 每季度检查一次进度\n\n如果每月目标有压力，先从 10% 开始，每月增加 1%，年底就能达到 20% 以上。", tag: "入门"),
    // MARK: - 储蓄技巧 (8篇)
    Article(icon: "🛡️", title: "应急基金：你的财务安全网", subtitle: "为什么需要 3-6 个月的应急储备金",
            content: "应急基金是理财的第一步，也是最重要的一步。\n\n目标金额：3-6 个月的基本生活费\n存放位置：货币基金或活期存款（随时可取）\n\n建立步骤：\n① 计算每月基本开销（房租+餐饮+交通+水电）\n② 乘以 3-6 倍作为目标金额\n③ 每月固定存入，直到达标\n④ 达标后只在真正紧急时使用，用后及时补充", tag: "基础"),
    Article(icon: "🏦", title: "定期存款 vs 货币基金", subtitle: "低风险理财的两种选择，各有优劣",
            content: "定期存款：\n• 优点：保本保息，利率固定\n• 缺点：流动性差，提前支取损失利息\n• 适合：1 年内确定不用的钱\n\n货币基金：\n• 优点：随时存取，收益每日到账\n• 缺点：收益浮动，通常低于定期\n• 适合：应急资金、短期闲置资金\n\n建议：应急基金放货币基金，确定不用的钱放定期。", tag: "入门"),
    Article(icon: "💡", title: "365 存钱法：小钱也能变大钱", subtitle: "每天存一点，一年下来超乎想象",
            content: "365 存钱法：每天存 1-365 元中任意金额，一年下来总额为 66795 元。\n\n操作方式：\n• 准备一张表格，写上 1-365\n• 每天选一个数字存对应金额\n• 存过的数字划掉\n• 一年结束，所有数字都划掉\n\n灵活变体：\n• 简化版：每天固定存 50 元，一年 18250 元\n• 递增版：第 1 天存 1 元，第 2 天存 2 元...第 365 天存 365 元", tag: "入门"),
    Article(icon: "🎁", title: "年终奖怎么花最划算", subtitle: "一笔钱的分配艺术",
            content: "年终奖到手后，建议这样分配：\n\n• 30% 储蓄/投资：直接转入理财账户\n• 20% 还债：如果有贷款，优先偿还高息债务\n• 20% 孝敬父母/人情往来\n• 20% 奖励自己：旅行、购物、学习\n• 10% 应急补充：充实应急基金\n\n关键原则：先储蓄后消费，不要先花再存。", tag: "实用"),
    Article(icon: "🔄", title: "自动化储蓄：让存钱变成无意识行为", subtitle: "设置自动转账，消灭「月底没余钱」的困境",
            content: "自动化储蓄是最有效的存钱方法：\n\n① 发工资当天，自动转出 20% 到储蓄账户\n② 设置自动定投基金（每月固定日期扣款）\n③ 设置零钱自动转入（如支付宝的笔笔攒）\n\n心理学原理：看不见的钱就不会花。工资到账前就转走，你不会觉得「少了什么」。", tag: "入门"),
    Article(icon: "🎯", title: "52 周阶梯存钱法", subtitle: "每周递增存钱，一年轻松存下 13780 元",
            content: "52 周存钱法：第 1 周存 10 元，第 2 周存 20 元...第 52 周存 520 元。\n\n一年总额：10+20+30+...+520 = 13780 元\n\n优点：\n• 起步金额小，容易坚持\n• 逐渐增加，养成习惯\n• 每周有成就感\n\n变体：从 520 元开始递减（年末压力小），或者随机抽取金额增加趣味性。", tag: "入门"),
    Article(icon: "💎", title: "如何存下第一桶金", subtitle: "从 0 到 10 万的实操路径",
            content: "第一桶金通常指 10 万元存款。\n\n以月薪 8000 为例的 3 年计划：\n• 第 1 年：月存 1500，年存 1.8 万\n• 第 2 年：加薪后月存 2500，年存 3 万，累计 4.8 万\n• 第 3 年：月存 3000，年存 3.6 万 + 理财收益，累计 8.5 万+\n\n加速方法：\n• 记账找出可削减的开支\n• 开发副业增加收入\n• 年终奖、加班费全部存入", tag: "进阶"),
    Article(icon: "📊", title: "高收益存款产品怎么选", subtitle: "在安全前提下，让你的存款收益最大化",
            content: "存款产品收益排行（从低到高）：\n\n① 活期存款：0.2%（应急资金用）\n② 货币基金：1.5-2.5%（短期闲置）\n③ 大额存单：2.5-3.0%（20 万起）\n④ 结构性存款：2.5-4.0%（有浮动）\n⑤ 国债：2.5-3.5%（安全性最高）\n\n建议：不要把所有钱放在一个产品里。分散配置，兼顾流动性和收益。", tag: "进阶"),
    // MARK: - 投资理财 (10篇)
    Article(icon: "📈", title: "基金定投入门指南", subtitle: "最适合普通人的投资方式",
            content: "基金定投 = 定期定额买入基金。\n\n优势：\n• 分散风险：不择时，平均成本\n• 门槛低：每月 100 元起\n• 强制储蓄：养成投资习惯\n\n选择标准：\n• 宽基指数基金（沪深 300、中证 500）\n• 成立 3 年以上\n• 规模 10 亿以上\n• 费率低\n\n定投纪律：坚持 3 年以上，不要因为短期下跌而停止。", tag: "入门"),
    Article(icon: "📊", title: "股票投资入门：你需要知道的基础知识", subtitle: "什么是股票？如何开始投资？",
            content: "股票 = 公司的一小部分所有权。\n\n入门知识：\n• 股票代码：6 位数字，如 600519（茅台）\n• 涨跌幅限制：A 股每日涨跌 10%（创业板 20%）\n• 交易时间：周一至周五 9:30-15:00\n• 最低买入：1 手 = 100 股\n\n新手建议：\n• 先学后做，至少了解基本财务指标\n• 用闲钱投资，不要借钱炒股\n• 从指数基金开始，不要直接买个股", tag: "入门"),
    Article(icon: "🏗️", title: "资产配置的核心原则", subtitle: "不要把鸡蛋放在一个篮子里",
            content: "资产配置是投资中最重要的决策，决定了 90% 以上的收益。\n\n经典配置模型：\n• 保守型：70% 债券 + 30% 股票\n• 平衡型：50% 债券 + 50% 股票\n• 进攻型：30% 债券 + 70% 股票\n\n年龄法则：股票占比 = 100 - 年龄\n• 25 岁：75% 股票 + 25% 债券\n• 40 岁：60% 股票 + 40% 债券\n• 60 岁：40% 股票 + 60% 债券", tag: "进阶"),
    Article(icon: "📉", title: "投资亏损了怎么办", subtitle: "亏损是投资的必修课，关键是如何应对",
            content: "面对亏损的正确心态：\n\n① 不要恐慌卖出：市场短期波动是正常的\n② 检查投资逻辑：当初买入的理由还成立吗？\n③ 如果逻辑没变，坚持甚至加仓\n④ 如果逻辑已变，果断止损\n\n巴菲特的名言：「别人恐惧时我贪婪，别人贪婪时我恐惧。」\n\n但前提是你买的是好资产，而不是垃圾股。", tag: "心理"),
    Article(icon: "🧮", title: "基金的 A 类和 C 类怎么选", subtitle: "持有时间决定选哪种更划算",
            content: "A 类基金：前端收费，买入时收取申购费（通常 0.1-1.5%）\nC 类基金：不收申购费，但每年收取销售服务费（约 0.4-0.8%）\n\n选择标准：\n• 持有 < 1 年：选 C 类（无申购费）\n• 持有 1-2 年：看具体费率比较\n• 持有 > 2 年：选 A 类（总费用更低）\n\n定投通常持有时间较长，建议选 A 类。", tag: "实用"),
    Article(icon: "🌍", title: "全球资产配置：不要只投 A 股", subtitle: "分散投资到不同市场，降低单一市场风险",
            content: "为什么要全球配置？\n• A 股、美股、港股走势不完全相关\n• 单一市场风险集中\n• 全球配置可以平滑收益\n\n简单方法：\n• 沪深 300 指数基金（A 股）\n• 标普 500 指数基金（美股）\n• 恒生指数基金（港股）\n• 各配 1/3，每年再平衡一次", tag: "进阶"),
    Article(icon: "💰", title: "分红型基金 vs 增长型基金", subtitle: "要现金流还是要资本增值？",
            content: "分红型基金：定期派发现金红利\n• 适合：需要稳定现金流的退休人士\n• 优点：有「落袋为安」的感觉\n• 缺点：分红后净值下降\n\n增长型基金：收益全部再投资\n• 适合：不需要现金流的年轻投资者\n• 优点：复利效应更强\n• 缺点：没有现金流入\n\n年轻人建议选增长型，让复利充分发挥作用。", tag: "进阶"),
    Article(icon: "⚖️", title: "主动基金 vs 被动基金", subtitle: "花大价钱请基金经理，还是跟踪指数？",
            content: "主动基金：基金经理选股，目标跑赢市场\n• 优点：可能获得超额收益\n• 缺点：费率高（1.5%），依赖基金经理能力\n\n被动基金（指数基金）：跟踪特定指数\n• 优点：费率低（0.1-0.5%），透明度高\n• 缺点：只能获得市场平均收益\n\n数据表明：长期来看，80% 的主动基金跑不赢指数。普通人建议选指数基金。", tag: "进阶"),
    Article(icon: "📅", title: "定投止盈策略：什么时候卖出", subtitle: "会买的是徒弟，会卖的才是师傅",
            content: "基金定投止盈方法：\n\n① 目标收益率法：设定 20-30% 的目标，达到就分批卖出\n② 估值止盈法：当指数 PE 高于历史 70% 分位时开始分批卖出\n③ 回撤止盈法：收益达到目标后，如果从最高点回撤 5-10% 就卖出\n\n关键原则：\n• 分批卖出，不要一次清仓\n• 卖出后继续定投，不要停止\n• 记录每次操作，复盘优化", tag: "进阶"),
    Article(icon: "🔍", title: "如何看懂基金的晨星评级", subtitle: "用专业工具筛选优质基金",
            content: "晨星评级是全球最权威的基金评级体系：\n\n• 5 星：同类基金中表现前 10%\n• 4 星：前 10-32.5%\n• 3 星：前 32.5-67.5%\n• 2 星：前 67.5-90%\n• 1 星：后 10%\n\n注意事项：\n• 评级基于历史业绩，不代表未来\n• 要看 3 年和 5 年评级，不要只看 1 年\n• 同类比较才有意义（股票基金和债券基金不能比）", tag: "进阶"),
    // MARK: - 负债管理 (6篇)
    Article(icon: "💳", title: "信用卡的正确使用姿势", subtitle: "合理使用信用卡，让它成为你的理财工具",
            content: "信用卡本身不是洪水猛兽，关键在于怎么用。\n\n✅ 正确用法：利用免息期、全额还款、积分兑换、自动还款\n❌ 错误用法：分期还款、取现、以卡养卡\n\n记住：信用卡是延迟支付工具，不是额外收入。", tag: "实用"),
    Article(icon: "🏠", title: "房贷要不要提前还", subtitle: "这取决于你的投资能力和贷款利率",
            content: "是否提前还房贷的判断标准：\n\n• 如果贷款利率 > 4%，且你没有稳定的投资渠道：建议提前还\n• 如果贷款利率 < 4%，且你能获得更高的投资收益：不急着还\n• 如果是公积金贷款（利率 3.1%）：不建议提前还\n\n提前还款策略：\n• 缩短年限比减少月供更省利息\n• 等额本息还款超过 1/2 时间后，提前还款意义不大\n• 等额本金还款超过 1/3 时间后，提前还款意义不大", tag: "进阶"),
    Article(icon: "🚫", title: "远离消费贷和现金贷", subtitle: "年化 20-36% 的利息会吞噬你的财富",
            content: "消费贷/现金贷的真实成本：\n\n• 花呗分期：实际年化约 13-15%\n• 信用卡分期：实际年化约 13-18%\n• 网贷平台：实际年化 20-36%\n\n为什么这么高？\n• 分期手续费是按初始本金计算，不是剩余本金\n• 提前还款通常不减免手续费\n\n底线：绝对不要碰年化超过 10% 的借贷。", tag: "警示"),
    Article(icon: "📊", title: "负债率多少算健康", subtitle: "合理的负债是杠杆，过度的负债是枷锁",
            content: "负债健康指标：\n\n• 月负债还款额 / 月收入 ≤ 40%（安全线）\n• 月负债还款额 / 月收入 ≤ 60%（警戒线）\n• 月负债还款额 / 月收入 > 60%（危险）\n\n好负债 vs 坏负债：\n• 好负债：房贷（利率低，资产增值）、教育贷款（提升收入能力）\n• 坏负债：消费贷、信用卡分期、赌博借贷\n\n如果负债率超过 60%，优先还债，暂停投资。", tag: "基础"),
    Article(icon: "🔄", title: "债务雪球法 vs 债务雪崩法", subtitle: "两种还债策略，哪种更适合你？",
            content: "债务雪球法（Dave Ramsey 推荐）：\n• 先还金额最小的债务\n• 心理激励强，快速看到成果\n• 适合需要动力的人\n\n债务雪崩法（数学最优）：\n• 先还利率最高的债务\n• 总利息支出最少\n• 适合理性且有耐心的人\n\n建议：如果你需要心理激励，选雪球法；如果你能坚持，选雪崩法。", tag: "实用"),
    Article(icon: "⚠️", title: "征信报告怎么看", subtitle: "你的信用档案决定了未来的借贷成本",
            content: "每年可免费查询 2 次个人征信报告（中国人民银行征信中心）。\n\n关注要点：\n① 信贷记录：贷款和信用卡的还款情况\n② 逾期记录：连续 3 次或累计 6 次逾期影响很大\n③ 查询记录：频繁被查会影响信用评分\n④ 负债总额：过高会影响新贷款审批\n\n维护征信：按时还款、不要频繁申请信用卡、不要为他人担保。", tag: "实用"),
    // MARK: - 保险规划 (5篇)
    Article(icon: "🛡️", title: "保险配置的优先顺序", subtitle: "先保障后理财，先大人后小孩",
            content: "保险配置顺序：\n\n① 医保（必须有）：国家福利，覆盖基础医疗\n② 百万医疗险（优先）：几百元保费，几百万保额\n③ 意外险（优先）：几十到几百元，覆盖意外伤害\n④ 重疾险（重要）：确诊即赔，弥补收入损失\n⑤ 定期寿险（有家庭后）：保障家人生活\n\n原则：先保障后理财，先大人后小孩，先经济支柱后其他成员。", tag: "入门"),
    Article(icon: "💊", title: "百万医疗险怎么选", subtitle: "几百元撬动几百万的医疗保障",
            content: "百万医疗险选购要点：\n\n• 保额：100-600 万（够用即可，不必追求最高）\n• 免赔额：通常 1 万元（社保报销后）\n• 续保条件：选保证续保 20 年的产品\n• 增值服务：质子重离子、外购药、就医绿通\n• 价格：30 岁约 300 元/年，50 岁约 1000 元/年\n\n注意：既往症通常不保，趁健康时尽早购买。", tag: "实用"),
    Article(icon: "🏥", title: "重疾险买多少保额合适", subtitle: "保额要覆盖治疗费 + 3-5 年收入",
            content: "重疾险保额计算：\n\n• 治疗费用：30-50 万（重大疾病平均治疗费）\n• 收入损失：年收入 × 3-5 年（康复期间无法工作）\n• 建议保额：50-100 万\n\n产品选择：\n• 消费型 vs 返还型：选消费型，性价比更高\n• 定期 vs 终身：预算有限选定期（保至 70 岁）\n• 单次 vs 多次赔付：预算充足选多次", tag: "实用"),
    Article(icon: "👶", title: "孩子的保险怎么买", subtitle: "花最少的钱给孩子最全面的保障",
            content: "孩子保险配置：\n\n① 少儿医保（必须）：国家福利，每年几百元\n② 少儿意外险（优先）：几十元/年，覆盖意外医疗\n③ 少儿重疾险（重要）：白血病等少儿高发疾病\n④ 百万医疗险（补充）：大病住院费用\n\n注意：\n• 不要给孩子买寿险（孩子不承担家庭经济责任）\n• 不要买教育金保险（收益低，不如自己投资）\n• 大人的保障比孩子更重要", tag: "实用"),
    Article(icon: "💼", title: "公司给的团险够用吗", subtitle: "团险是福利，但不能完全替代个人保险",
            content: "公司团险的优势：\n• 通常免费或低价\n• 无需健康告知\n• 可覆盖家属\n\n团险的局限：\n• 离职就失去保障\n• 保额通常较低\n• 保障范围有限\n\n建议：团险作为补充，个人保险作为基础。至少自己配置一份百万医疗险和意外险。", tag: "实用"),
    // MARK: - 税务知识 (4篇)
    Article(icon: "🧾", title: "个人所得税怎么算", subtitle: "了解你的工资是怎么被扣税的",
            content: "个人所得税计算（工资薪金）：\n\n应纳税所得额 = 工资 - 5000（起征点）- 五险一金 - 专项附加扣除\n\n税率表（按月）：\n• ≤ 3000：3%\n• 3001-12000：10%\n• 12001-25000：20%\n• 25001-35000：25%\n• 35001-55000：30%\n• 55001-80000：35%\n• > 80000：45%\n\n专项附加扣除：子女教育、房贷利息、租房、赡养老人、继续教育、大病医疗。", tag: "入门"),
    Article(icon: "📝", title: "专项附加扣除全攻略", subtitle: "合法节税，每年能省几千到几万元",
            content: "7 项专项附加扣除：\n\n① 子女教育：每个子女每月 1000 元\n② 继续教育：学历教育每月 400 元\n③ 大病医疗：超过 15000 元部分，最高 80000 元\n④ 房贷利息：每月 1000 元（首套房）\n⑤ 租房租金：每月 800-1500 元（看城市）\n⑥ 赡养老人：每月 2000 元\n⑦ 3 岁以下婴幼儿照护：每个婴幼儿每月 2000 元\n\n一定要在个税 App 中填报，否则白白多交税。", tag: "实用"),
    Article(icon: "💼", title: "年终奖的计税方式选择", subtitle: "单独计税 vs 并入综合所得，哪个更省税？",
            content: "年终奖两种计税方式：\n\n① 单独计税：年终奖单独按月度税率表计算\n② 并入综合所得：和工资一起计算\n\n选择建议：\n• 年收入 < 6 万：选并入综合所得（可能不用交税）\n• 年收入 6-20 万：通常选单独计税\n• 年收入 > 20 万：需要具体计算比较\n\n在个税 App 中可以两种方式都试算，选税额更低的。", tag: "进阶"),
    Article(icon: "📊", title: "投资收益如何报税", subtitle: "股票、基金、理财的税务处理",
            content: "各类投资的税务情况：\n\n• 股票买卖差价：暂免个人所得税\n• 股票分红：持股 > 1 年免税，≤ 1 年按 20% 缴税\n• 基金分红：暂免个人所得税\n• 基金买卖差价：暂免个人所得税\n• 银行存款利息：暂免个人所得税\n• 房产出售：满五唯一免个税，否则按差额 20%\n\n目前 A 股投资的税负较轻，是普通投资者的优势。", tag: "进阶"),
    // MARK: - 消费心理 (5篇)
    Article(icon: "🧠", title: "消费降级不等于降低生活质量", subtitle: "聪明消费，把钱花在真正重要的地方",
            content: "消费降级的核心不是「不花钱」，而是「把钱花对地方」。\n\n实用技巧：\n① 区分「想要」和「需要」\n② 记账发现消费漏洞\n③ 延迟满足：等 24 小时再决定\n④ 替代方案：自己做饭、图书馆、运动\n\n记住：真正的富足不是拥有更多，而是需要更少。", tag: "心理"),
    Article(icon: "⏰", title: "延迟满足的 24 小时法则", subtitle: "想买的东西等一天再决定",
            content: "24 小时法则是对抗冲动消费最简单有效的方法：\n\n操作方式：\n• 看到想买的东西，先加入购物车\n• 等待 24 小时\n• 24 小时后如果还想买，再下单\n\n效果：\n• 减少 50% 以上的冲动消费\n• 避免买了后悔的情况\n• 省下的钱可以用于更重要的事情\n\n升级版：大额消费等 72 小时甚至 1 周。", tag: "心理"),
    Article(icon: "🛒", title: "如何避免「消费升级」陷阱", subtitle: "收入增加不一定要升级消费",
            content: "消费升级陷阱：\n\n• 加薪了 → 换更大的房子\n• 发奖金了 → 买更贵的包\n• 升职了 → 换更好的车\n\n这就是「生活方式膨胀」：收入增加，支出也同步增加，永远存不下钱。\n\n破解方法：\n• 收入增加后，先提高储蓄率，再考虑升级消费\n• 设定「消费天花板」：某些类别的支出有上限\n• 区分「提升生活品质」和「虚荣消费」", tag: "心理"),
    Article(icon: "🎭", title: "社交消费的压力与应对", subtitle: "不被「面子」绑架，做自己财务的主人",
            content: "常见的社交消费压力：\n\n• 朋友聚餐抢着买单\n• 同事都用名牌，自己不好意思用平价\n• 朋友圈晒旅行，自己也要去\n\n应对策略：\n① 找志同道合的朋友（消费观相似）\n② 学会说「不」：超出预算的活动可以婉拒\n③ 记住：真正的朋友不会因为你省钱而看不起你\n④ 把注意力从「别人怎么看我」转移到「我的财务目标」", tag: "心理"),
    Article(icon: "📱", title: "如何戒掉「手机购物」习惯", subtitle: "减少屏幕时间 = 减少消费",
            content: "手机购物是现代人最大的消费黑洞。\n\n戒断方法：\n① 删除购物 App（需要用时再装）\n② 关闭所有购物推送通知\n③ 取消关注种草博主\n④ 卸载比价工具（减少浏览时间）\n⑤ 设置手机使用时间限制\n\n替代活动：\n• 想购物时去散步或运动\n• 把购物车里的东西截图，一周后再看\n• 计算每件商品需要工作多少小时才能买到", tag: "心理"),
    // MARK: - 财务自由 (4篇)
    Article(icon: "🔥", title: "FIRE 运动：财务自由提前退休", subtitle: "25 倍年支出 = 财务自由",
            content: "FIRE（Financial Independence, Retire Early）的核心公式：\n\n财务自由所需金额 = 年支出 × 25\n\n例如：年支出 10 万 → 需要 250 万\n\n实现路径：\n① 降低年支出（提高储蓄率）\n② 增加收入（工资 + 副业 + 投资）\n③ 投资增值（年化 7-8%）\n④ 达到目标后，每年取出 4% 生活\n\n4% 法则：历史数据表明，每年取出 4%，资金可以支撑 30 年以上。", tag: "进阶"),
    Article(icon: "💼", title: "被动收入的 7 种来源", subtitle: "让钱为你工作，而不是你为钱工作",
            content: "被动收入来源：\n\n① 投资分红：股票/基金的定期分红\n② 房租收入：出租房产的租金\n③ 版税收入：书籍、音乐、课程的版权费\n④ 利息收入：存款、债券的利息\n⑤ 股权收益：投资创业公司的回报\n⑥ 数字产品：App、模板、素材的销售\n⑦ 自动化生意：可以自动运行的业务\n\n关键是前期投入时间和精力，建立可持续的收入来源。", tag: "进阶"),
    Article(icon: "📊", title: "你的财务自由度是多少", subtitle: "用一个公式评估你的财务健康状况",
            content: "财务自由度 = 被动收入 / 月支出\n\n• < 25%：财务依赖期（完全依赖工资）\n• 25-50%：财务安全期（有一定缓冲）\n• 50-75%：财务活力期（选择更多）\n• 75-100%：财务独立期（接近自由）\n• ≥ 100%：财务自由期（可以不工作）\n\n提升方法：\n• 增加被动收入（投资、副业）\n• 降低月支出（减少不必要消费）\n• 双管齐下效果最好", tag: "进阶"),
    Article(icon: "🎯", title: "从月薪 5000 到财务自由的路径", subtitle: "普通人也可以实现的财务规划",
            content: "以月薪 5000、年支出 4 万为例：\n\n阶段一（1-3 年）：建立应急基金 3 万\n阶段二（3-5 年）：学习投资，开始定投\n阶段三（5-10 年）：积累第一桶金 20 万\n阶段四（10-15 年）：投资收益开始显著\n阶段五（15-20 年）：达到财务自由目标\n\n关键因素：\n• 储蓄率 > 30%\n• 投资年化收益 7-8%\n• 持续学习和提升收入\n• 保持耐心，享受过程", tag: "进阶"),
    // MARK: - 理财防骗 (4篇)
    Article(icon: "🚨", title: "理财骗局的 5 个特征", subtitle: "遇到这些信号，请立即远离",
            content: "理财骗局的共同特征：\n\n① 承诺高收益无风险：「保本保息 15%」→ 100% 是骗局\n② 拉人头返利：介绍朋友投资可以拿提成\n③ 催促你做决定：「今天不买就没了」\n④ 无法解释钱去了哪里：资金去向不透明\n⑤ 用名人背书：伪造与名人的合影或推荐\n\n记住：\n• 银行存款利率才 2%，任何承诺超过 10% 的都要警惕\n• 天上不会掉馅饼\n• 你不贪别人的利息，别人就骗不了你的本金", tag: "警示"),
    Article(icon: "⚠️", title: "P2P 教训：高收益的代价", subtitle: "曾经的「理财神器」如何变成「收割机」",
            content: "P2P 行业的教训：\n\n• 2015 年高峰期：6000+ 平台\n• 2020 年：基本全部清退\n• 投资者损失：数千亿元\n\n教训总结：\n① 高收益必然伴随高风险\n② 平台「爆雷」前往往看起来最安全\n③ 不要把所有钱放在一个平台\n④ 监管政策变化可能一夜之间改变局面\n\n对普通投资者的启示：远离任何承诺固定高收益的产品。", tag: "警示"),
    Article(icon: "🔍", title: "如何识别「杀猪盘」骗局", subtitle: "投资理财 + 感情诈骗的复合型骗局",
            content: "「杀猪盘」的典型流程：\n\n① 通过社交软件加好友\n② 建立感情信任（养猪）\n③ 展示投资收益截图\n④ 引导你到虚假平台投资\n⑤ 初期让你小赚，加大投入\n⑥ 大额投入后平台「维护」或跑路\n\n防范方法：\n• 网友推荐的投资平台一律不碰\n• 只在正规券商和银行投资\n• 任何要求转账到个人账户的都是骗局", tag: "警示"),
    Article(icon: "💡", title: "正规理财渠道有哪些", subtitle: "选择正规渠道，让投资更安心",
            content: "正规理财渠道：\n\n① 银行：存款、理财产品、代销基金\n② 证券公司：股票、基金、债券\n③ 基金公司官网/ App：直接购买基金\n④ 支付宝/微信：货币基金、指数基金\n⑤ 保险公司：保险产品\n\n验证方法：\n• 查看是否有金融牌照\n• 在证监会/银保监会官网查询\n• 不要相信「内部渠道」「特殊资源」", tag: "入门"),
]

let classicBooks: [BookSummary] = [
    // MARK: - 理财入门 (10本)
    BookSummary(cover: "📗", title: "富爸爸穷爸爸", author: "罗伯特·清崎",
                summary: "通过两个爸爸的对比，揭示穷人和富人思维的根本差异。",
                keyPoints: ["资产是把钱放进你口袋的东西，负债是把钱从你口袋拿走的东西", "富人买入资产，穷人只有支出", "财务自由 = 被动收入 > 生活支出", "学会让钱为你工作，而不是你为钱工作"]),
    BookSummary(cover: "📕", title: "小狗钱钱", author: "博多·舍费尔",
                summary: "用故事的形式讲述理财入门知识，适合零基础读者。",
                keyPoints: ["列出愿望清单，选出最重要的 3 个", "50% 养鹅（储蓄投资），40% 梦想，10% 日常", "写成功日记，记录每天的小成就", "72 小时法则：决定做一件事，72 小时内必须行动"]),
    BookSummary(cover: "📘", title: "巴比伦最富有的人", author: "乔治·克拉森",
                summary: "用古巴比伦的寓言故事，讲述永恒不变的理财智慧。",
                keyPoints: ["至少将收入的 10% 存起来", "让金子为你工作：储蓄要用于投资", "守护财富：不要投资你不了解的东西", "寻求专业人士的建议，但要独立判断"]),
    BookSummary(cover: "📙", title: "财务自由之路", author: "博多·舍费尔",
                summary: "系统讲解如何从负债走向财务自由的实操指南。",
                keyPoints: ["财务安全→财务活力→财务独立→财务自由", "增加收入：提升能力、做副业、投资", "债务管理：还款额控制在收入 50% 以内", "建立多渠道收入来源"]),
    BookSummary(cover: "📒", title: "断舍离", author: "山下英子",
                summary: "减少不必要消费的理念与理财高度契合。",
                keyPoints: ["断 = 不买不需要的东西", "舍 = 扔掉没用的东西", "离 = 脱离对物品的执念", "通过减少消费欲望，自然实现储蓄增长"]),
    BookSummary(cover: "📓", title: "钱：7 步创造终身收入", author: "托尼·罗宾斯",
                summary: "全球顶级励志大师写的理财实操指南，涵盖从储蓄到投资的完整路径。",
                keyPoints: ["存钱是第一步，也是最重要的一步", "利用复利效应，越早开始越好", "配置低成本指数基金", "建立安全、成长、梦想三个财务桶"]),
    BookSummary(cover: "📔", title: "邻家的百万富翁", author: "托马斯·斯坦利",
                summary: "研究美国百万富翁的真实生活，发现他们大多是节俭的普通人。",
                keyPoints: ["真正的富翁生活远比你想象的节俭", "高收入不等于高财富，关键看储蓄率", "富翁的共同特质：节俭、有计划、自律", "不要用消费来证明自己的成功"]),
    BookSummary(cover: "📕", title: "财务自由——实用指南", author: "格兰特·萨巴蒂尔",
                summary: "作者从 25 岁存款 2 美元到 30 岁财务自由的真实经历。",
                keyPoints: ["5 年内实现财务自由是可能的", "提高收入比削减开支更重要", "建立多种收入来源", "投资指数基金，长期持有"]),
    BookSummary(cover: "📗", title: "好好赚钱", author: "简七",
                summary: "国内理财达人写的适合中国读者的理财入门书。",
                keyPoints: ["理财的第一步是记账", "先保障后投资：保险优先", "基金定投是最适合新手的投资方式", "设定明确的财务目标"]),
    BookSummary(cover: "📘", title: "工作前 5 年，决定你一生的财富", author: "三公子",
                summary: "适合年轻人的理财实操手册，从零开始建立财务体系。",
                keyPoints: ["刚工作就要开始理财", "先存下 3-6 个月的应急基金", "学会基金定投", "不要忽视保险的重要性"]),
    // MARK: - 投资经典 (10本)
    BookSummary(cover: "📕", title: "聪明的投资者", author: "本杰明·格雷厄姆",
                summary: "巴菲特的老师写的投资圣经，价值投资的奠基之作。",
                keyPoints: ["投资的核心是安全边际", "区分投资和投机", "市场先生理论：市场情绪波动不代表真实价值", "防御型投资者应选择分散的优质股票"]),
    BookSummary(cover: "📗", title: "漫步华尔街", author: "伯顿·马尔基尔",
                summary: "投资领域的经典之作，论证了指数投资的有效性。",
                keyPoints: ["短期市场走势不可预测", "低成本指数基金是最佳投资工具", "不要试图择时，长期持有才是王道", "分散投资降低风险"]),
    BookSummary(cover: "📘", title: "巴菲特致股东的信", author: "沃伦·巴菲特",
                summary: "巴菲特历年投资智慧的精华，价值投资的核心理念。",
                keyPoints: ["能力圈：只投资你理解的企业", "护城河：寻找有持久竞争优势的公司", "长期持有：不要频繁交易", "安全边际：以低于内在价值的价格买入"]),
    BookSummary(cover: "📙", title: "彼得·林奇的成功投资", author: "彼得·林奇",
                summary: "传奇基金经理的投资方法，教你如何从生活中发现投资机会。",
                keyPoints: ["从日常生活中发现投资机会", "了解你买的公司做什么", "6 种股票分类，不同策略对待", "不要被市场恐慌影响判断"]),
    BookSummary(cover: "📒", title: "投资最重要的事", author: "霍华德·马克斯",
                summary: "橡树资本创始人的投资备忘录，深度思考风险和收益。",
                keyPoints: ["第二层思维：比市场共识想得更深", "风险控制比追求收益更重要", "市场周期不可避免，学会利用它", "逆向投资：在别人恐惧时贪婪"]),
    BookSummary(cover: "📓", title: "指数基金投资指南", author: "银行螺丝钉",
                summary: "国内最实用的指数基金投资实操书。",
                keyPoints: ["指数基金是最适合普通人的投资工具", "定投策略：低估买入，高估卖出", "常见指数：沪深300、中证500、恒生指数", "长期持有，不要频繁操作"]),
    BookSummary(cover: "📔", title: "周期", author: "霍华德·马克斯",
                summary: "深入理解经济周期和市场周期，在周期中找到投资机会。",
                keyPoints: ["周期是不可避免的", "在周期底部买入，在顶部卖出", "情绪驱动的过度波动创造机会", "了解你现在处于周期的什么位置"]),
    BookSummary(cover: "📕", title: "股票作手回忆录", author: "埃德温·勒菲弗",
                summary: "传奇交易者杰西·利弗莫尔的故事，投机市场的经典。",
                keyPoints: ["市场趋势一旦形成，会持续一段时间", "止损是生存的关键", "不要过度交易", "耐心等待最佳时机"]),
    BookSummary(cover: "📗", title: "价值", author: "张磊",
                summary: "高瓴资本创始人的投资哲学，中国版的投资智慧。",
                keyPoints: ["长期主义：做时间的朋友", "选择有护城河的企业", "研究驱动，深入理解行业", "在变化中寻找不变的本质"]),
    BookSummary(cover: "📘", title: "投资中最简单的事", author: "邱国鹭",
                summary: "国内价值投资的实践者，用简单的方法做投资。",
                keyPoints: ["便宜是硬道理", "定价权是核心竞争力", "行业格局决定盈利能力", "逆向投资需要勇气和耐心"]),
    // MARK: - 财务思维 (8本)
    BookSummary(cover: "📙", title: "思考，快与慢", author: "丹尼尔·卡尼曼",
                summary: "诺贝尔经济学奖得主揭示人类思维的两种模式及决策偏见。",
                keyPoints: ["系统1（快思考）：直觉、自动、易出错", "系统2（慢思考）：理性、费力、更准确", "损失厌恶：失去100元的痛苦大于得到100元的快乐", "过度自信：我们对自己的判断过于自信"]),
    BookSummary(cover: "📒", title: "行为经济学讲义", author: "薛兆丰",
                summary: "用经济学思维理解人们的消费和投资行为。",
                keyPoints: ["人是理性的，但理性是有限的", "沉没成本不应影响未来决策", "机会成本才是真正的成本", "激励机制决定人的行为"]),
    BookSummary(cover: "📓", title: "稀缺", author: "塞德希尔·穆来纳森",
                summary: "为什么穷人越来越穷？稀缺心态如何影响我们的决策。",
                keyPoints: ["稀缺心态会降低认知能力", "时间稀缺和金钱稀缺的恶性循环", "留有余闲是打破稀缺的关键", "建立系统，减少对意志力的依赖"]),
    BookSummary(cover: "📔", title: "助推", author: "理查德·塞勒",
                summary: "诺贝尔经济学奖得主教你如何通过「助推」做出更好的财务决策。",
                keyPoints: ["默认选项的力量：自动加入比自动退出更有效", "简化选择：选项越多，越难做出好决定", "及时反馈：让结果可见才能改善行为", "自由主义的温和专制主义"]),
    BookSummary(cover: "📕", title: "穷查理宝典", author: "查理·芒格",
                summary: "巴菲特搭档的投资智慧，跨学科思维模型的集大成者。",
                keyPoints: ["多元思维模型：用多学科视角看问题", "反过来想，总是反过来想", "避免愚蠢比追求聪明更重要", "终身学习是最大的投资"]),
    BookSummary(cover: "📗", title: "原则", author: "瑞·达利欧",
                summary: "全球最大对冲基金创始人的人生和投资原则。",
                keyPoints: ["极度透明和极度真实", "拥抱失败，从错误中学习", "系统化决策，减少情绪干扰", "分散投资：圣杯策略"]),
    BookSummary(cover: "📘", title: "反脆弱", author: "纳西姆·塔勒布",
                summary: "如何从不确定性中获益，建立反脆弱的财务体系。",
                keyPoints: ["反脆弱 = 从波动和压力中获益", "杠铃策略：90%极度保守 + 10%极度激进", "避免中间风险：中庸策略最脆弱", "小的失败是成功的前提"]),
    BookSummary(cover: "📙", title: "随机漫步的傻瓜", author: "纳西姆·塔勒布",
                summary: "揭示投资中的运气成分，教你如何区分运气和能力。",
                keyPoints: ["成功者中很多是运气好的傻瓜", "幸存者偏差让我们高估能力的作用", "小概率事件的影响被严重低估", "保持谦逊，做好最坏的准备"]),
    // MARK: - 创业与收入 (7本)
    BookSummary(cover: "📒", title: "穷爸爸富爸爸（实践篇）", author: "罗伯特·清崎",
                summary: "富爸爸系列的实操版本，教你如何建立自己的商业系统。",
                keyPoints: ["B-I 三角形：使命、团队、领导力、现金流、系统", "从 E/S 象限转向 B/I 象限", "建立系统，让系统为你工作", "失败是成功的一部分"]),
    BookSummary(cover: "📓", title: "副业赚钱之道", author: "安晓辉",
                summary: "适合上班族的副业指南，教你如何利用业余时间增加收入。",
                keyPoints: ["盘点你的技能和资源", "选择与主业互补的副业", "利用互联网放大个人价值", "副业收入超过主业时再考虑全职"]),
    BookSummary(cover: "📔", title: "纳瓦尔宝典", author: "埃里克·乔根森",
                summary: "硅谷天使投资人纳瓦尔的财富和幸福智慧。",
                keyPoints: ["财富是在你睡觉时还能为你赚钱的资产", "杠杆：劳动力、资本、代码、媒体", "专属知识：无法通过培训获得的知识", "幸福是一种技能，可以学习和练习"]),
    BookSummary(cover: "📕", title: "从 0 到 1", author: "彼得·蒂尔",
                summary: "PayPal 创始人的创业哲学，如何创造全新的价值。",
                keyPoints: ["创新是从 0 到 1，复制是从 1 到 N", "垄断比竞争更赚钱", "幂律法则：少数公司获得大部分回报", "明确的愿景比计划更重要"]),
    BookSummary(cover: "📗", title: "精益创业", author: "埃里克·莱斯",
                summary: "用最小成本验证商业想法，减少创业风险。",
                keyPoints: ["MVP（最小可行产品）：快速验证想法", "构建-测量-学习循环", "转型还是坚持：用数据说话", "不要追求完美，先推出再迭代"]),
    BookSummary(cover: "📘", title: "刻意练习", author: "安德斯·艾利克森",
                summary: "如何通过科学的练习方法提升技能，从而增加收入。",
                keyPoints: ["天才不是天生的，是练出来的", "刻意练习的核心：走出舒适区", "即时反馈是进步的关键", "1 万小时法则需要正确的练习方式"]),
    BookSummary(cover: "📙", title: "能力变现", author: "帅健翔",
                summary: "教你如何把个人能力转化为收入。",
                keyPoints: ["找到你的能力优势", "定位细分市场", "用内容建立个人品牌", "知识付费是能力变现的高效方式"]),
    // MARK: - 金钱心理 (7本)
    BookSummary(cover: "📒", title: "金钱心理学", author: "摩根·豪塞尔",
                summary: "用心理学视角理解人与金钱的关系，投资行为的深层原因。",
                keyPoints: ["每个人对金钱的认知都受经历影响", "复利最大的特点是需要时间", "尾部事件驱动收益：少数决策决定大部分回报", "真正的财富是你看不见的"]),
    BookSummary(cover: "📓", title: "上瘾", author: "尼尔·埃亚尔",
                summary: "理解消费上瘾的机制，帮助你摆脱非理性消费。",
                keyPoints: ["触发→行动→奖赏→投入的上瘾循环", "商家如何利用上瘾模型让你花钱", "识别触发你消费的情绪", "用好习惯替代坏习惯"]),
    BookSummary(cover: "📔", title: "自控力", author: "凯利·麦格尼格尔",
                summary: "斯坦福大学心理学课程，教你如何提升自控力来管理消费。",
                keyPoints: ["自控力像肌肉，可以锻炼也会疲劳", "意志力是有限的资源", "冥想可以提升自控力", "承诺和监督机制帮助坚持"]),
    BookSummary(cover: "📕", title: "影响力", author: "罗伯特·西奥迪尼",
                summary: "理解商家如何影响你的购买决策，成为更理性的消费者。",
                keyPoints: ["互惠原理：免费试用让你觉得应该购买", "稀缺原理：限时促销制造紧迫感", "社会认同：销量高=好产品的心智捷径", "权威效应：专家推荐更容易被信任"]),
    BookSummary(cover: "📗", title: "怪诞行为学", author: "丹·艾瑞里",
                summary: "用实验揭示人类消费决策中的非理性行为。",
                keyPoints: ["锚定效应：第一个价格影响后续判断", "免费的力量：0 元的吸引力远超折扣", "所有权效应：拥有的东西在我们眼中更有价值", "预期效应：期望影响实际体验"]),
    BookSummary(cover: "📘", title: "清醒思考的艺术", author: "罗尔夫·多贝里",
                summary: "识别常见的思维错误，做出更理性的财务决策。",
                keyPoints: ["幸存者偏差：只看到成功案例", "沉没成本谬误：已经投入的不应影响未来决策", "确认偏误：只看支持自己观点的信息", "从众心理：别人买我也买"]),
    BookSummary(cover: "📙", title: "心流", author: "米哈里·契克森米哈赖",
                summary: "理解心流状态，找到工作与生活的平衡，减少用消费填补空虚。",
                keyPoints: ["心流 = 完全沉浸于当下活动的状态", "挑战与技能的平衡是进入心流的关键", "心流带来的满足感远超消费", "找到让你进入心流的工作，是最好的投资"]),
    // MARK: - 财务规划 (8本)
    BookSummary(cover: "📒", title: "30 岁前的每一天", author: "水湄物语",
                summary: "适合年轻人的理财和人生规划指南。",
                keyPoints: ["理财越早开始越好", "记账是理财的第一步", "投资自己是回报率最高的投资", "设定 3-5 年的财务目标"]),
    BookSummary(cover: "📓", title: "你的第一本保险书", author: "李元霸",
                summary: "国内最实用的保险购买指南，帮你避开保险陷阱。",
                keyPoints: ["先保障后理财", "消费型保险比返还型更划算", "重疾险、医疗险、意外险、寿险四大基础", "不要被销售话术迷惑"]),
    BookSummary(cover: "📔", title: "买房还是不买房", author: "谢博德·内拉",
                summary: "用经济学视角分析买房决策，打破「一定要买房」的迷思。",
                keyPoints: ["买房不一定是最好的投资", "租房的机会成本被严重低估", "房价收入比是衡量合理性的重要指标", "根据自身情况做决定，不要被社会压力左右"]),
    BookSummary(cover: "📕", title: "养老，从 20 岁开始", author: "赵博睿",
                summary: "年轻人的养老规划指南，越早准备越轻松。",
                keyPoints: ["养老不能只靠社保", "复利效应让年轻人有巨大优势", "养老三大支柱：社保、企业年金、个人养老", "每月多存 500 元，30 年后差距巨大"]),
    BookSummary(cover: "📗", title: "孩子的第一本理财书", author: "朴铁军",
                summary: "如何从小培养孩子的财商。",
                keyPoints: ["3 岁开始认识金钱", "6 岁开始给零花钱并学习管理", "12 岁开始了解投资概念", "用实践而非说教培养财商"]),
    BookSummary(cover: "📘", title: "家庭资产配置", author: "李璞",
                summary: "适合中国家庭的资产配置实操指南。",
                keyPoints: ["标准普尔家庭资产配置：10%消费、20%保障、30%增值、40%稳健", "根据家庭生命周期调整配置", "定期再平衡，保持目标比例", "不要把所有资产放在同一类别"]),
    BookSummary(cover: "📙", title: "婚姻与理财", author: "张晨",
                summary: "如何在婚姻中处理好金钱关系。",
                keyPoints: ["婚前坦诚讨论财务状况", "共同账户 vs 独立账户：找到适合你们的方式", "大额消费需要双方同意", "定期进行家庭财务会议"]),
    BookSummary(cover: "📒", title: "退休后的 30 年", author: "三浦展",
                summary: "如何为退休后 30 年的生活做好财务准备。",
                keyPoints: ["退休后的生活费约为退休前的 70-80%", "医疗费用是退休后最大的不确定支出", "4% 法则：每年取出 4%，资金可支撑 30 年", "保持适度的社交和活动，减少医疗支出"]),
]

#Preview {
    FinancialAcademyView()
}
