import Foundation

// MARK: - 项目类型

enum ProjectType: String, CaseIterable, Identifiable {
    case travel = "travel"
    case businessTrip = "businessTrip"
    case roadTrip = "roadTrip"
    case camping = "camping"
    case skiing = "skiing"
    case renovation = "renovation"
    case remodeling = "remodeling"
    case moving = "moving"
    case furniture = "furniture"
    case appliance = "appliance"
    case wedding = "wedding"
    case babyShower = "babyShower"
    case birthday = "birthday"
    case graduation = "graduation"
    case studyAbroad = "studyAbroad"
    case examPrep = "examPrep"
    case training = "training"
    case drivingSchool = "drivingSchool"
    case medical = "medical"
    case dental = "dental"
    case cosmetic = "cosmetic"
    case fitness = "fitness"
    case pet = "pet"
    case carPurchase = "carPurchase"
    case carMaintenance = "carMaintenance"
    case computerBuild = "computerBuild"
    case investment = "investment"
    case newYearShopping = "newYearShopping"
    case shoppingFestival = "shoppingFestival"
    case social = "social"
    case daily = "daily"
    
    var id: String { rawValue }
}

// MARK: - 项目类型配置结构

struct ProjectTypeConfig {
    let type: ProjectType
    let displayName: String
    let icon: String
    let keywords: [String]
    let bigItemKeywords: [String]
    let bigItemLabel: String
    let dailyLabel: String
    let description: String
    let referenceStandard: ReferenceStandard
}

// MARK: - 对照标准

struct ReferenceStandard {
    let lowLabel: String
    let highLabel: String
    let unit: String
    let threshold: Double
    let format: (Double) -> String
}

// MARK: - 项目类型配置管理器

class ProjectTypeConfigManager {
    static let shared = ProjectTypeConfigManager()
    
    private let configs: [ProjectTypeConfig] = [
        ProjectTypeConfig(
            type: .travel,
            displayName: "旅行",
            icon: "airplane",
            keywords: ["旅行", "旅游", "度假", "出游", "自由行", "跟团"],
            bigItemKeywords: ["交通", "机票", "火车", "高铁", "飞机", "住宿", "酒店", "民宿"],
            bigItemLabel: "大件（交通+住宿）",
            dailyLabel: "日常均摊/天",
            description: "剔除大交通和住宿，看日常吃喝玩乐实际花了多少",
            referenceStandard: ReferenceStandard(
                lowLabel: "💤 极致穷游",
                highLabel: "👸 优质贵妇",
                unit: "天",
                threshold: 800,
                format: { "¥\(Int($0))/天 = 贵妇级别" }
            )
        ),
        ProjectTypeConfig(
            type: .businessTrip,
            displayName: "出差",
            icon: "briefcase",
            keywords: ["出差", "公务", "商务", "差旅"],
            bigItemKeywords: ["交通", "机票", "火车", "高铁", "飞机", "住宿", "酒店"],
            bigItemLabel: "大件（交通+住宿）",
            dailyLabel: "日常均摊/天",
            description: "剔除交通和住宿，看日常餐饮和市内交通花了多少",
            referenceStandard: ReferenceStandard(
                lowLabel: "💼 经济实惠",
                highLabel: "🌟 高端商务",
                unit: "天",
                threshold: 500,
                format: { "¥\(Int($0))/天 = 商务标准" }
            )
        ),
        ProjectTypeConfig(
            type: .roadTrip,
            displayName: "自驾游",
            icon: "car.fill",
            keywords: ["自驾", "自驾游", "公路旅行"],
            bigItemKeywords: ["油费", "过路费", "高速", "停车", "住宿", "酒店"],
            bigItemLabel: "大件（油费+住宿）",
            dailyLabel: "日常均摊/天",
            description: "剔除油费和住宿，看日常餐饮和门票花了多少",
            referenceStandard: ReferenceStandard(
                lowLabel: "🚗 省钱达人",
                highLabel: "🏎️ 豪华自驾",
                unit: "天",
                threshold: 600,
                format: { "¥\(Int($0))/天 = 豪华自驾" }
            )
        ),
        ProjectTypeConfig(
            type: .camping,
            displayName: "露营",
            icon: "tent.fill",
            keywords: ["露营", "野营", "户外"],
            bigItemKeywords: ["帐篷", "睡袋", "炉具", "灯具", "装备"],
            bigItemLabel: "大件（装备采购）",
            dailyLabel: "日常均摊/次",
            description: "剔除装备采购，看食材和消耗品花了多少",
            referenceStandard: ReferenceStandard(
                lowLabel: "⛺ 轻装上阵",
                highLabel: "🏕️ 豪华露营",
                unit: "次",
                threshold: 500,
                format: { "¥\(Int($0))/次 = 豪华露营" }
            )
        ),
        ProjectTypeConfig(
            type: .skiing,
            displayName: "滑雪",
            icon: "figure.skiing.downhill",
            keywords: ["滑雪", "冬运", "雪场"],
            bigItemKeywords: ["雪票", "缆车", "装备", "雪具", "教练", "住宿"],
            bigItemLabel: "大件（雪票+装备）",
            dailyLabel: "日常均摊/天",
            description: "剔除雪票和装备租赁，看餐饮和交通花了多少",
            referenceStandard: ReferenceStandard(
                lowLabel: "❄️ 新手体验",
                highLabel: "🎿 高端滑雪",
                unit: "天",
                threshold: 1000,
                format: { "¥\(Int($0))/天 = 高端滑雪" }
            )
        ),
        ProjectTypeConfig(
            type: .renovation,
            displayName: "新房装修",
            icon: "house.fill",
            keywords: ["装修", "新房", "毛坯", "硬装", "软装"],
            bigItemKeywords: ["家具", "家电", "建材", "卫浴", "地板", "瓷砖", "橱柜", "沙发", "床", "空调", "冰箱"],
            bigItemLabel: "大件（家具+家电）",
            dailyLabel: "辅材均摊/㎡",
            description: "剔除家具家电，看建材辅材和人工费花了多少",
            referenceStandard: ReferenceStandard(
                lowLabel: "🏠 经济简装",
                highLabel: "🏰 豪华装修",
                unit: "㎡",
                threshold: 2000,
                format: { "¥\(Int($0))/㎡ = 豪装标准" }
            )
        ),
        ProjectTypeConfig(
            type: .remodeling,
            displayName: "旧房翻新",
            icon: "hammer.fill",
            keywords: ["翻新", "改造", "老房", "旧房"],
            bigItemKeywords: ["家具", "家电", "建材", "卫浴", "地板", "瓷砖"],
            bigItemLabel: "大件（家具+建材）",
            dailyLabel: "辅材均摊/项",
            description: "剔除家具建材，看人工费和辅材花了多少",
            referenceStandard: ReferenceStandard(
                lowLabel: "🔧 局部翻新",
                highLabel: "✨ 全面翻新",
                unit: "项",
                threshold: 5000,
                format: { "¥\(Int($0))/项 = 全面翻新" }
            )
        ),
        ProjectTypeConfig(
            type: .moving,
            displayName: "搬家",
            icon: "box.truck.fill",
            keywords: ["搬家", "乔迁"],
            bigItemKeywords: ["搬家费", "搬运", "物流", "打包", "新家具", "新家电"],
            bigItemLabel: "大件（搬家费+新家具）",
            dailyLabel: "日常均摊/项",
            description: "剔除搬家费和新家具，看日常消耗品花了多少",
            referenceStandard: ReferenceStandard(
                lowLabel: "📦 精简搬家",
                highLabel: "🏡 品质搬家",
                unit: "次",
                threshold: 3000,
                format: { "¥\(Int($0))/次 = 品质搬家" }
            )
        ),
        ProjectTypeConfig(
            type: .furniture,
            displayName: "家具采购",
            icon: "sofa.fill",
            keywords: ["家具", "沙发", "床", "衣柜", "书桌", "餐桌"],
            bigItemKeywords: ["沙发", "床", "衣柜", "书桌", "餐桌", "橱柜"],
            bigItemLabel: "大件（主要家具）",
            dailyLabel: "小件均摊/件",
            description: "剔除主要家具，看小件家居用品花了多少",
            referenceStandard: ReferenceStandard(
                lowLabel: "🛋️ 经济实用",
                highLabel: "🪑 品质家居",
                unit: "件",
                threshold: 2000,
                format: { "¥\(Int($0))/件 = 品质家居" }
            )
        ),
        ProjectTypeConfig(
            type: .appliance,
            displayName: "家电采购",
            icon: "tv.fill",
            keywords: ["家电", "电器", "空调", "冰箱", "洗衣机", "电视"],
            bigItemKeywords: ["空调", "冰箱", "洗衣机", "电视", "热水器", "油烟机"],
            bigItemLabel: "大件（主要家电）",
            dailyLabel: "小件均摊/件",
            description: "剔除主要家电，看小家电和配件花了多少",
            referenceStandard: ReferenceStandard(
                lowLabel: "📺 经济实用",
                highLabel: "🏠 智能家电",
                unit: "件",
                threshold: 3000,
                format: { "¥\(Int($0))/件 = 智能家电" }
            )
        ),
        ProjectTypeConfig(
            type: .wedding,
            displayName: "婚礼",
            icon: "heart.fill",
            keywords: ["婚礼", "结婚", "婚庆", "喜宴"],
            bigItemKeywords: ["婚庆", "酒店", "婚纱", "摄影", "摄像", "司仪", "化妆"],
            bigItemLabel: "大件（婚庆+酒店）",
            dailyLabel: "小件均摊/项",
            description: "剔除婚庆酒店，看喜糖喜帖和小件花了多少",
            referenceStandard: ReferenceStandard(
                lowLabel: "💍 简约婚礼",
                highLabel: "👑 豪华婚礼",
                unit: "场",
                threshold: 100000,
                format: { "¥\(Int($0))/场 = 豪华婚礼" }
            )
        ),
        ProjectTypeConfig(
            type: .babyShower,
            displayName: "满月酒",
            icon: "figure.and.child.holdhands",
            keywords: ["满月", "百日", "周岁", "宝宝宴"],
            bigItemKeywords: ["酒店", "酒席", "蛋糕", "布置", "摄影"],
            bigItemLabel: "大件（酒席+布置）",
            dailyLabel: "小件均摊/项",
            description: "剔除酒席和布置，看伴手礼和小件花了多少",
            referenceStandard: ReferenceStandard(
                lowLabel: "🍼 温馨简约",
                highLabel: "🎉 隆重举办",
                unit: "场",
                threshold: 20000,
                format: { "¥\(Int($0))/场 = 隆重举办" }
            )
        ),
        ProjectTypeConfig(
            type: .birthday,
            displayName: "生日派对",
            icon: "birthday.cake.fill",
            keywords: ["生日", "派对", "party"],
            bigItemKeywords: ["场地", "蛋糕", "布置", "餐饮", "酒水"],
            bigItemLabel: "大件（场地+蛋糕）",
            dailyLabel: "小件均摊/项",
            description: "剔除场地和蛋糕，看装饰和礼物花了多少",
            referenceStandard: ReferenceStandard(
                lowLabel: "🎂 小型聚会",
                highLabel: "🎊 盛大派对",
                unit: "场",
                threshold: 5000,
                format: { "¥\(Int($0))/场 = 盛大派对" }
            )
        ),
        ProjectTypeConfig(
            type: .graduation,
            displayName: "毕业典礼",
            icon: "graduationcap.fill",
            keywords: ["毕业", "毕业典礼", "毕业季"],
            bigItemKeywords: ["学士服", "摄影", "聚餐", "旅行"],
            bigItemLabel: "大件（学士服+摄影）",
            dailyLabel: "小件均摊/项",
            description: "剔除学士服和摄影，看聚餐和纪念品花了多少",
            referenceStandard: ReferenceStandard(
                lowLabel: "🎓 简单纪念",
                highLabel: "📸 精彩记录",
                unit: "人",
                threshold: 1000,
                format: { "¥\(Int($0))/人 = 精彩记录" }
            )
        ),
        ProjectTypeConfig(
            type: .studyAbroad,
            displayName: "留学",
            icon: "globe.europe.africa.fill",
            keywords: ["留学", "出国", "海外"],
            bigItemKeywords: ["学费", "签证", "机票", "保险", "住宿", "房租"],
            bigItemLabel: "大件（学费+住宿）",
            dailyLabel: "生活费均摊/月",
            description: "剔除学费和住宿，看日常生活费花了多少",
            referenceStandard: ReferenceStandard(
                lowLabel: "📚 节俭留学",
                highLabel: "🌍 品质留学",
                unit: "月",
                threshold: 10000,
                format: { "¥\(Int($0))/月 = 品质留学" }
            )
        ),
        ProjectTypeConfig(
            type: .examPrep,
            displayName: "考试备考",
            icon: "book.fill",
            keywords: ["考研", "考公", "考编", "备考", "专升本"],
            bigItemKeywords: ["课程", "网课", "教材", "真题", "辅导班"],
            bigItemLabel: "大件（课程+教材）",
            dailyLabel: "日常均摊/月",
            description: "剔除课程和教材，看文具和生活费花了多少",
            referenceStandard: ReferenceStandard(
                lowLabel: "📖 自学备考",
                highLabel: "🎯 高端辅导",
                unit: "月",
                threshold: 3000,
                format: { "¥\(Int($0))/月 = 高端辅导" }
            )
        ),
        ProjectTypeConfig(
            type: .training,
            displayName: "培训学习",
            icon: "person.fill.checkmark",
            keywords: ["培训", "课程", "学习", "技能"],
            bigItemKeywords: ["学费", "课程费", "教材", "设备"],
            bigItemLabel: "大件（学费+教材）",
            dailyLabel: "日常均摊/期",
            description: "剔除学费和教材，看交通和餐饮花了多少",
            referenceStandard: ReferenceStandard(
                lowLabel: "📝 基础培训",
                highLabel: "🏆 高端培训",
                unit: "期",
                threshold: 5000,
                format: { "¥\(Int($0))/期 = 高端培训" }
            )
        ),
        ProjectTypeConfig(
            type: .drivingSchool,
            displayName: "驾照学习",
            icon: "car.side.fill",
            keywords: ["驾照", "驾校", "学车"],
            bigItemKeywords: ["学费", "报名费", "考试费"],
            bigItemLabel: "大件（学费+考试费）",
            dailyLabel: "日常均摊/次",
            description: "剔除学费和考试费，看交通和餐饮花了多少",
            referenceStandard: ReferenceStandard(
                lowLabel: "🚗 普通驾校",
                highLabel: "🏎️ VIP班",
                unit: "次",
                threshold: 8000,
                format: { "¥\(Int($0))/次 = VIP班" }
            )
        ),
        ProjectTypeConfig(
            type: .medical,
            displayName: "体检医疗",
            icon: "cross.case.fill",
            keywords: ["体检", "医疗", "看病", "住院", "手术"],
            bigItemKeywords: ["检查费", "手术费", "住院费", "药费", "治疗费"],
            bigItemLabel: "大件（检查+治疗）",
            dailyLabel: "日常均摊/项",
            description: "剔除检查和治疗费，看交通和营养品花了多少",
            referenceStandard: ReferenceStandard(
                lowLabel: "🏥 基础检查",
                highLabel: "💊 高端医疗",
                unit: "次",
                threshold: 5000,
                format: { "¥\(Int($0))/次 = 高端医疗" }
            )
        ),
        ProjectTypeConfig(
            type: .dental,
            displayName: "牙齿矫正",
            icon: "mouth.fill",
            keywords: ["牙齿", "矫正", "正畸", "牙套", "种植"],
            bigItemKeywords: ["矫正费", "牙套", "种植", "拔牙", "补牙"],
            bigItemLabel: "大件（矫正+种植）",
            dailyLabel: "日常均摊/次",
            description: "剔除矫正和种植费，看交通和复诊费花了多少",
            referenceStandard: ReferenceStandard(
                lowLabel: "🦷 基础矫正",
                highLabel: "😁 隐形矫正",
                unit: "次",
                threshold: 30000,
                format: { "¥\(Int($0))/次 = 隐形矫正" }
            )
        ),
        ProjectTypeConfig(
            type: .cosmetic,
            displayName: "医美",
            icon: "sparkles",
            keywords: ["医美", "美容", "整形", "护肤"],
            bigItemKeywords: ["手术", "注射", "激光", "热玛吉", "光子"],
            bigItemLabel: "大件（手术+注射）",
            dailyLabel: "日常均摊/次",
            description: "剔除手术和注射，看护肤品和交通花了多少",
            referenceStandard: ReferenceStandard(
                lowLabel: "💆 基础护肤",
                highLabel: "✨ 高端医美",
                unit: "次",
                threshold: 10000,
                format: { "¥\(Int($0))/次 = 高端医美" }
            )
        ),
        ProjectTypeConfig(
            type: .fitness,
            displayName: "健身",
            icon: "figure.run",
            keywords: ["健身", "运动", "减肥", "塑形"],
            bigItemKeywords: ["年卡", "私教", "课程", "装备"],
            bigItemLabel: "大件（年卡+私教）",
            dailyLabel: "日常均摊/月",
            description: "剔除年卡和私教，看运动装备和营养品花了多少",
            referenceStandard: ReferenceStandard(
                lowLabel: "💪 自主训练",
                highLabel: "🏋️ 私教健身",
                unit: "月",
                threshold: 2000,
                format: { "¥\(Int($0))/月 = 私教健身" }
            )
        ),
        ProjectTypeConfig(
            type: .pet,
            displayName: "宠物",
            icon: "pawprint.fill",
            keywords: ["宠物", "猫", "狗", "宠物医院"],
            bigItemKeywords: ["疫苗", "绝育", "手术", "体检", "宠物粮", "猫砂"],
            bigItemLabel: "大件（医疗+粮食）",
            dailyLabel: "日常均摊/月",
            description: "剔除医疗和粮食，看玩具和零食花了多少",
            referenceStandard: ReferenceStandard(
                lowLabel: "🐾 经济养宠",
                highLabel: "🐕 品质养宠",
                unit: "月",
                threshold: 1000,
                format: { "¥\(Int($0))/月 = 品质养宠" }
            )
        ),
        ProjectTypeConfig(
            type: .carPurchase,
            displayName: "买车",
            icon: "car.2.fill",
            keywords: ["买车", "购车", "提车"],
            bigItemKeywords: ["车款", "购置税", "保险", "上牌", "装潢"],
            bigItemLabel: "大件（车款+税费）",
            dailyLabel: "小件均摊/项",
            description: "剔除车款和税费，看装潢和配件花了多少",
            referenceStandard: ReferenceStandard(
                lowLabel: "🚗 经济代步",
                highLabel: "🏎️ 豪华座驾",
                unit: "辆",
                threshold: 200000,
                format: { "¥\(Int($0))/辆 = 豪华座驾" }
            )
        ),
        ProjectTypeConfig(
            type: .carMaintenance,
            displayName: "汽车保养",
            icon: "wrench.and.screwdriver.fill",
            keywords: ["保养", "维修", "修车", "汽车"],
            bigItemKeywords: ["机油", "轮胎", "刹车片", "电瓶", "大修"],
            bigItemLabel: "大件（机油+轮胎）",
            dailyLabel: "小件均摊/次",
            description: "剔除机油和轮胎，看小保养和配件花了多少",
            referenceStandard: ReferenceStandard(
                lowLabel: "🔧 基础保养",
                highLabel: "🚘 深度保养",
                unit: "次",
                threshold: 2000,
                format: { "¥\(Int($0))/次 = 深度保养" }
            )
        ),
        ProjectTypeConfig(
            type: .computerBuild,
            displayName: "电脑组装",
            icon: "desktopcomputer",
            keywords: ["电脑", "组装", "装机", "台式机"],
            bigItemKeywords: ["CPU", "显卡", "主板", "内存", "硬盘", "电源", "显示器"],
            bigItemLabel: "大件（核心硬件）",
            dailyLabel: "外设均摊/件",
            description: "剔除核心硬件，看外设和配件花了多少",
            referenceStandard: ReferenceStandard(
                lowLabel: "💻 办公主机",
                highLabel: "🎮 旗舰配置",
                unit: "台",
                threshold: 10000,
                format: { "¥\(Int($0))/台 = 旗舰配置" }
            )
        ),
        ProjectTypeConfig(
            type: .investment,
            displayName: "投资理财",
            icon: "chart.line.uptrend.xyaxis",
            keywords: ["投资", "理财", "股票", "基金", "房产"],
            bigItemKeywords: ["本金", "房款", "首付", "大额"],
            bigItemLabel: "大件（本金+大额）",
            dailyLabel: "手续费均摊/笔",
            description: "剔除本金和大额支出，看手续费和杂费花了多少",
            referenceStandard: ReferenceStandard(
                lowLabel: "📈 稳健投资",
                highLabel: "💎 高端投资",
                unit: "笔",
                threshold: 10000,
                format: { "¥\(Int($0))/笔 = 高端投资" }
            )
        ),
        ProjectTypeConfig(
            type: .newYearShopping,
            displayName: "年货采购",
            icon: "gift.fill",
            keywords: ["年货", "春节", "过年", "新年"],
            bigItemKeywords: ["礼品", "礼盒", "烟酒", "干货", "海鲜"],
            bigItemLabel: "大件（礼品+食材）",
            dailyLabel: "小件均摊/件",
            description: "剔除礼品和食材，看春联红包和小件花了多少",
            referenceStandard: ReferenceStandard(
                lowLabel: "🧧 简单年货",
                highLabel: "🎊 丰盛年货",
                unit: "户",
                threshold: 5000,
                format: { "¥\(Int($0))/户 = 丰盛年货" }
            )
        ),
        ProjectTypeConfig(
            type: .shoppingFestival,
            displayName: "购物节",
            icon: "cart.fill",
            keywords: ["双十一", "618", "购物节", "大促"],
            bigItemKeywords: ["数码", "家电", "家具", "大件"],
            bigItemLabel: "大件（数码+家电）",
            dailyLabel: "小件均摊/件",
            description: "剔除数码家电，看日用百货和服饰花了多少",
            referenceStandard: ReferenceStandard(
                lowLabel: "🛒 理性消费",
                highLabel: "🛍️ 疯狂购物",
                unit: "件",
                threshold: 500,
                format: { "¥\(Int($0))/件 = 疯狂购物" }
            )
        ),
        ProjectTypeConfig(
            type: .social,
            displayName: "社交聚会",
            icon: "person.3.fill",
            keywords: ["聚会", "聚餐", "团建", "社交", "约会"],
            bigItemKeywords: ["场地", "餐饮", "酒水", "活动"],
            bigItemLabel: "大件（场地+餐饮）",
            dailyLabel: "小件均摊/次",
            description: "剔除场地和餐饮，看交通和礼物花了多少",
            referenceStandard: ReferenceStandard(
                lowLabel: "🍻 简单聚餐",
                highLabel: "🎉 精致聚会",
                unit: "次",
                threshold: 500,
                format: { "¥\(Int($0))/次 = 精致聚会" }
            )
        ),
        ProjectTypeConfig(
            type: .daily,
            displayName: "日常开销",
            icon: "house.fill",
            keywords: ["日常", "生活", "开销", "消费"],
            bigItemKeywords: ["交通", "住宿", "机票", "酒店", "火车", "高铁", "飞机"],
            bigItemLabel: "大件（交通+住宿）",
            dailyLabel: "日常均摊/天",
            description: "剔除大交通和住宿，看日常吃喝玩乐实际花了多少",
            referenceStandard: ReferenceStandard(
                lowLabel: "💤 极致省钱",
                highLabel: "👸 品质生活",
                unit: "天",
                threshold: 300,
                format: { "¥\(Int($0))/天 = 品质生活" }
            )
        )
    ]
    
    // MARK: - 智能识别项目类型
    
    func identifyProjectType(name: String, description: String = "") -> ProjectType {
        let text = (name + " " + description).lowercased()
        
        let priorityOrder: [ProjectType] = [
            .wedding, .babyShower, .graduation, .studyAbroad,
            .renovation, .remodeling, .skiing, .camping,
            .roadTrip, .businessTrip, .travel,
            .furniture, .appliance, .carPurchase, .computerBuild,
            .dental, .cosmetic, .medical,
            .fitness, .pet, .drivingSchool,
            .examPrep, .training, .investment,
            .newYearShopping, .shoppingFestival,
            .moving, .carMaintenance, .birthday,
            .social, .daily
        ]
        
        for type in priorityOrder {
            if let config = configs.first(where: { $0.type == type }) {
                let matched = config.keywords.filter { text.contains($0) }
                if !matched.isEmpty {
                    return type
                }
            }
        }
        
        return .daily
    }
    
    // MARK: - 获取配置
    
    func getConfig(for type: ProjectType) -> ProjectTypeConfig {
        configs.first(where: { $0.type == type }) ?? configs.first(where: { $0.type == .daily })!
    }
    
    func getConfig(name: String, description: String = "") -> ProjectTypeConfig {
        let type = identifyProjectType(name: name, description: description)
        return getConfig(for: type)
    }
}
