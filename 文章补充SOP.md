现在我完全了解了数据结构。这是一套完整的方案：你需要生成一个 `FinancialAcademyData.swift` 文件，包含 `financialArticles` 和 `classicBooks` 两个数组。

---

## 整体思路

**脚本做三件事：**
1. 维护一份 100 条目的「内容大纲」（标题、分类、图标等）
2. 循环调用 AI API，逐条生成 `paragraphs` 等详细内容
3. 将所有结果拼装成合法的 `.swift` 文件，直接复制到项目里用

---

## 完整 Python 脚本

新建文件 `generate_articles.py`，放到项目根目录：

```python
#!/usr/bin/env python3
"""
生成 FinancialAcademyData.swift
用法：
  pip install openai
  export OPENAI_API_KEY="sk-..."
  python generate_articles.py
"""

import os, json, time, re
from openai import OpenAI

client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])
MODEL  = "gpt-4o"          # 换成 gpt-4-turbo / claude-3-5-sonnet 均可

# ─────────────────────────────────────────────
# 1. 内容大纲 ── 50 篇文章
# ─────────────────────────────────────────────
ARTICLES_PLAN = [
    # 预算规划 8篇
    {"icon":"💰","title":"零基础预算入门","subtitle":"第一次做预算？从这里开始","tag":"必读","category":"预算规划","readTime":5,"level":"入门"},
    {"icon":"📊","title":"50/30/20法则完全指南","subtitle":"三步法则让钱花得明明白白","tag":"热门","category":"预算规划","readTime":6,"level":"入门"},
    {"icon":"📅","title":"月度预算制作实战","subtitle":"手把手制作你的第一份月度预算","tag":"实操","category":"预算规划","readTime":7,"level":"入门"},
    {"icon":"🛡️","title":"应急基金：你的财务护盾","subtitle":"为什么3-6个月支出是最低标准","tag":"重要","category":"预算规划","readTime":5,"level":"入门"},
    {"icon":"🔁","title":"固定支出 vs 可变支出","subtitle":"学会分类，才能精准控制","tag":"基础","category":"预算规划","readTime":4,"level":"入门"},
    {"icon":"📆","title":"年度预算规划全攻略","subtitle":"从12个月的视角统筹财务","tag":"进阶","category":"预算规划","readTime":8,"level":"进阶"},
    {"icon":"👨‍👩‍👧","title":"家庭预算管理技巧","subtitle":"两个人的钱如何一起管好","tag":"家庭","category":"预算规划","readTime":6,"level":"进阶"},
    {"icon":"🆘","title":"预算超支了怎么办","subtitle":"别慌，这5步帮你快速恢复","tag":"急救","category":"预算规划","readTime":5,"level":"入门"},
    # 储蓄技巧 8篇
    {"icon":"🐷","title":"储蓄习惯养成的科学","subtitle":"让大脑爱上存钱的心理机制","tag":"心理","category":"储蓄技巧","readTime":5,"level":"入门"},
    {"icon":"⚡","title":"自动储蓄：懒人也能存到钱","subtitle":"设置一次，终身受益","tag":"实操","category":"储蓄技巧","readTime":4,"level":"入门"},
    {"icon":"🏦","title":"高息储蓄账户选择指南","subtitle":"让你的存款多跑一步","tag":"工具","category":"储蓄技巧","readTime":6,"level":"入门"},
    {"icon":"🎯","title":"目标储蓄法：为梦想存钱","subtitle":"把大目标拆成每日小存款","tag":"方法","category":"储蓄技巧","readTime":5,"level":"入门"},
    {"icon":"💡","title":"节流25招：省钱不省质量","subtitle":"日常开销里藏着的省钱机会","tag":"实用","category":"储蓄技巧","readTime":7,"level":"入门"},
    {"icon":"📈","title":"储蓄率越高，自由越近","subtitle":"每提高1%储蓄率意味着什么","tag":"数据","category":"储蓄技巧","readTime":6,"level":"进阶"},
    {"icon":"🔒","title":"定期存款 vs 活期存款","subtitle":"不同时期资金应该放哪里","tag":"对比","category":"储蓄技巧","readTime":5,"level":"入门"},
    {"icon":"🌊","title":"收入波动时如何储蓄","subtitle":"自由职业、兼职者的储蓄策略","tag":"特殊","category":"储蓄技巧","readTime":6,"level":"进阶"},
    # 投资理财 10篇
    {"icon":"📈","title":"投资入门：钱生钱的逻辑","subtitle":"复利究竟有多强大","tag":"必读","category":"投资理财","readTime":6,"level":"入门"},
    {"icon":"🥚","title":"资产配置：不要把鸡蛋放一个篮子","subtitle":"分散投资降低风险的原理","tag":"核心","category":"投资理财","readTime":7,"level":"入门"},
    {"icon":"📊","title":"指数基金入门完全指南","subtitle":"普通人最好的投资工具","tag":"热门","category":"投资理财","readTime":8,"level":"入门"},
    {"icon":"🏠","title":"房产投资：利与弊全分析","subtitle":"买房到底算不算好投资","tag":"热议","category":"投资理财","readTime":9,"level":"进阶"},
    {"icon":"🪙","title":"黄金投资：避险资产的作用","subtitle":"什么时候该配置黄金","tag":"工具","category":"投资理财","readTime":6,"level":"进阶"},
    {"icon":"📉","title":"市场下跌时该怎么办","subtitle":"熊市生存与抄底的正确姿势","tag":"策略","category":"投资理财","readTime":7,"level":"进阶"},
    {"icon":"💼","title":"定投策略：时间是最好的朋友","subtitle":"每月定投如何平滑成本","tag":"方法","category":"投资理财","readTime":6,"level":"入门"},
    {"icon":"🔍","title":"看懂基金收益率","subtitle":"年化、累计、净值涨幅怎么看","tag":"基础","category":"投资理财","readTime":5,"level":"入门"},
    {"icon":"🌐","title":"境外投资入门","subtitle":"港股、美股、全球基金怎么配","tag":"进阶","category":"投资理财","readTime":8,"level":"进阶"},
    {"icon":"⚖️","title":"风险与收益的平衡之道","subtitle":"找到适合自己的投资风格","tag":"核心","category":"投资理财","readTime":7,"level":"入门"},
    # 负债管理 6篇
    {"icon":"🏧","title":"好债 vs 坏债：你分得清吗","subtitle":"并非所有债务都是麻烦","tag":"认知","category":"负债管理","readTime":5,"level":"入门"},
    {"icon":"❄️","title":"债务雪球法 vs 雪崩法","subtitle":"两种还款策略谁更适合你","tag":"方法","category":"负债管理","readTime":6,"level":"入门"},
    {"icon":"💳","title":"信用卡债务解套指南","subtitle":"高利率信用卡怎么快速还清","tag":"急救","category":"负债管理","readTime":7,"level":"进阶"},
    {"icon":"🎓","title":"助学贷款的聪明还法","subtitle":"不同收入阶段的最优策略","tag":"实操","category":"负债管理","readTime":6,"level":"入门"},
    {"icon":"🏡","title":"房贷提前还款的利弊","subtitle":"手里有闲钱，要不要提前还房贷","tag":"热议","category":"负债管理","readTime":7,"level":"进阶"},
    {"icon":"📋","title":"债务整合：简化还款的方法","subtitle":"多笔债务如何合并管理","tag":"工具","category":"负债管理","readTime":5,"level":"进阶"},
    # 保险规划 5篇
    {"icon":"🛡️","title":"保险到底买什么","subtitle":"普通人必配的四类保险","tag":"必读","category":"保险规划","readTime":6,"level":"入门"},
    {"icon":"❤️","title":"重疾险完全解读","subtitle":"什么年龄买，买多少才够","tag":"核心","category":"保险规划","readTime":7,"level":"进阶"},
    {"icon":"👪","title":"家庭保险规划顺序","subtitle":"保障谁是第一位的","tag":"家庭","category":"保险规划","readTime":5,"level":"入门"},
    {"icon":"🏥","title":"医疗险：百万医疗怎么选","subtitle":"门诊险和住院险的区别","tag":"对比","category":"保险规划","readTime":6,"level":"入门"},
    {"icon":"📜","title":"看懂保险条款中的陷阱","subtitle":"这些细节不注意，理赔时会后悔","tag":"警示","category":"保险规划","readTime":7,"level":"进阶"},
    # 税务知识 4篇
    {"icon":"🧾","title":"个人所得税全解析","subtitle":"工资条里的税是怎么算的","tag":"必知","category":"税务知识","readTime":6,"level":"入门"},
    {"icon":"💼","title":"专项附加扣除怎么用","subtitle":"子女教育、租房、继续教育全攻略","tag":"实操","category":"税务知识","readTime":7,"level":"入门"},
    {"icon":"📊","title":"投资收益如何纳税","subtitle":"股票、基金、房产的税务处理","tag":"进阶","category":"税务知识","readTime":6,"level":"进阶"},
    {"icon":"🌍","title":"境外收入的税务合规","subtitle":"全球征税时代的应对之道","tag":"特殊","category":"税务知识","readTime":7,"level":"进阶"},
    # 消费心理 5篇
    {"icon":"🛒","title":"消费主义陷阱识别指南","subtitle":"广告和促销背后的心理操控","tag":"警示","category":"消费心理","readTime":5,"level":"入门"},
    {"icon":"😌","title":"情绪消费：压力下的钱包失控","subtitle":"如何识别并控制冲动消费","tag":"心理","category":"消费心理","readTime":6,"level":"入门"},
    {"icon":"🎁","title":"极简主义消费：少买，好好买","subtitle":"质量优先的消费哲学","tag":"理念","category":"消费心理","readTime":5,"level":"入门"},
    {"icon":"💰","title":"价格锚定效应与聪明购物","subtitle":"为什么你总觉得"很划算"","tag":"认知","category":"消费心理","readTime":5,"level":"入门"},
    {"icon":"🔄","title":"延迟满足：购物清单的力量","subtitle":"30天等待法如何省下大笔钱","tag":"方法","category":"消费心理","readTime":4,"level":"入门"},
    # 财务自由 4篇
    {"icon":"🏝️","title":"财务自由的真实定义","subtitle":"FIRE运动并非只是提前退休","tag":"理念","category":"财务自由","readTime":6,"level":"入门"},
    {"icon":"🧮","title":"你需要多少钱才能财务自由","subtitle":"25倍法则和4%提取率","tag":"计算","category":"财务自由","readTime":7,"level":"进阶"},
    {"icon":"🚀","title":"加速实现财务自由的路径","subtitle":"开源、节流、投资三管齐下","tag":"策略","category":"财务自由","readTime":8,"level":"进阶"},
    {"icon":"🌱","title":"财务自由之后：钱的意义","subtitle":"富足之后如何找到生活意义","tag":"人生","category":"财务自由","readTime":5,"level":"进阶"},
    # 理财防骗 4篇
    {"icon":"🚨","title":"理财诈骗五大套路","subtitle":"识别庞氏骗局和非法集资","tag":"必读","category":"理财防骗","readTime":5,"level":"入门"},
    {"icon":"📱","title":"网络投资平台如何辨真假","subtitle":"查证一个平台合规性的5步骤","tag":"实操","category":"理财防骗","readTime":6,"level":"入门"},
    {"icon":"👴","title":"老年人理财骗局防范","subtitle":"家人需要知道的常见骗术","tag":"警示","category":"理财防骗","readTime":5,"level":"入门"},
    {"icon":"🔐","title":"被骗了怎么追回损失","subtitle":"紧急处理步骤和维权渠道","tag":"急救","category":"理财防骗","readTime":6,"level":"入门"},
]

# ─────────────────────────────────────────────
# 2. 内容大纲 ── 50 本书
# ─────────────────────────────────────────────
BOOKS_PLAN = [
    # 理财入门 10本
    {"cover":"📗","title":"小狗钱钱","author":"博多·舍费尔","summary":"一只神奇的小狗教你掌握财务自由的秘密","category":"理财入门","readTime":8,"level":"入门"},
    {"cover":"📘","title":"穷爸爸富爸爸","author":"罗伯特·清崎","summary":"颠覆传统财富观的理财圣经","category":"理财入门","readTime":10,"level":"入门"},
    {"cover":"📙","title":"富人思维","author":"史蒂夫·西伯尔德","summary":"穷人和富人在思维方式上的100个不同","category":"理财入门","readTime":8,"level":"入门"},
    {"cover":"📕","title":"你的钱，你的人生","author":"乔·多明格斯","summary":"重新定义财富与时间的关系","category":"理财入门","readTime":9,"level":"入门"},
    {"cover":"📗","title":"财务自由之路","author":"博多·舍费尔","summary":"7年内实现财务自由的系统方法","category":"理财入门","readTime":10,"level":"入门"},
    {"cover":"📘","title":"30岁前的每一天","author":"博多·舍费尔","summary":"年轻人必读的财富养成指南","category":"理财入门","readTime":7,"level":"入门"},
    {"cover":"📙","title":"工薪族的理财课","author":"车仁表","summary":"月薪3000也能实现的理财计划","category":"理财入门","readTime":6,"level":"入门"},
    {"cover":"📕","title":"钱从哪里来","author":"香帅","summary":"理解货币与财富的底层逻辑","category":"理财入门","readTime":9,"level":"入门"},
    {"cover":"📗","title":"把时间当作朋友","author":"李笑来","summary":"用认知升级推动财富积累","category":"理财入门","readTime":8,"level":"入门"},
    {"cover":"📘","title":"好好赚钱","author":"简七","summary":"中国语境下的个人理财实操指南","category":"理财入门","readTime":7,"level":"入门"},
    # 投资经典 10本
    {"cover":"📈","title":"聪明的投资者","author":"本杰明·格雷厄姆","summary":"价值投资圣经，巴菲特的必读书","category":"投资经典","readTime":12,"level":"进阶"},
    {"cover":"📉","title":"股票作手回忆录","author":"爱德温·李费佛","summary":"华尔街传奇交易员的传记与智慧","category":"投资经典","readTime":10,"level":"进阶"},
    {"cover":"💹","title":"彼得·林奇的成功投资","author":"彼得·林奇","summary":"普通投资者如何战胜专业机构","category":"投资经典","readTime":11,"level":"进阶"},
    {"cover":"🏦","title":"漫步华尔街","author":"伯顿·马尔基尔","summary":"指数投资的学术级辩护","category":"投资经典","readTime":10,"level":"进阶"},
    {"cover":"📊","title":"巴菲特致股东的信","author":"沃伦·巴菲特","summary":"50年投资智慧的第一手资料","category":"投资经典","readTime":12,"level":"进阶"},
    {"cover":"💰","title":"投资最重要的事","author":"霍华德·马克斯","summary":"周期、风险与第二层次思维","category":"投资经典","readTime":9,"level":"进阶"},
    {"cover":"🌊","title":"随机漫步的傻瓜","author":"纳西姆·塔勒布","summary":"运气与技能的区分，反脆弱的前身","category":"投资经典","readTime":9,"level":"进阶"},
    {"cover":"🔍","title":"证券分析","author":"格雷厄姆 & 多德","summary":"价值投资的奠基之作","category":"投资经典","readTime":14,"level":"进阶"},
    {"cover":"🎯","title":"巴菲特之道","author":"罗伯特·哈格斯特朗","summary":"系统解读巴菲特的投资哲学","category":"投资经典","readTime":10,"level":"进阶"},
    {"cover":"🧭","title":"与天为敌：风险探索传奇","author":"彼得·伯恩斯坦","summary":"人类如何学会管理和驾驭风险","category":"投资经典","readTime":11,"level":"进阶"},
    # 财务思维 8本
    {"cover":"🧠","title":"思考，快与慢","author":"丹尼尔·卡尼曼","summary":"影响财务决策的认知偏见","category":"财务思维","readTime":13,"level":"进阶"},
    {"cover":"💡","title":"纳瓦尔宝典","author":"纳瓦尔·拉维坎特","summary":"致富、健康与幸福的第一性原理","category":"财务思维","readTime":7,"level":"进阶"},
    {"cover":"🔑","title":"原则","author":"瑞·达利欧","summary":"全球最大对冲基金创始人的决策系统","category":"财务思维","readTime":14,"level":"进阶"},
    {"cover":"🌟","title":"零到一","author":"彼得·蒂尔","summary":"从垄断思维看财富创造","category":"财务思维","readTime":8,"level":"进阶"},
    {"cover":"📖","title":"反脆弱","author":"纳西姆·塔勒布","summary":"从混乱中获益的财务思维","category":"财务思维","readTime":12,"level":"进阶"},
    {"cover":"🎓","title":"穷查理宝典","author":"查理·芒格","summary":"多元思维模型与人生智慧","category":"财务思维","readTime":11,"level":"进阶"},
    {"cover":"🌈","title":"不平等的代价","author":"约瑟夫·斯蒂格利茨","summary":"理解贫富差距背后的制度逻辑","category":"财务思维","readTime":10,"level":"进阶"},
    {"cover":"⚖️","title":"稀缺","author":"塞德希尔·穆来纳桑","summary":"贫穷与忙碌的相同本质","category":"财务思维","readTime":9,"level":"进阶"},
    # 创业与收入 7本
    {"cover":"🚀","title":"精益创业","author":"埃里克·莱斯","summary":"用最小成本验证商业模式","category":"创业与收入","readTime":9,"level":"进阶"},
    {"cover":"💼","title":"The $100 Startup","author":"克里斯·吉列博","summary":"用100美元起步的小型创业故事","category":"创业与收入","readTime":8,"level":"进阶"},
    {"cover":"🎯","title":"4小时工作制","author":"蒂姆·费里斯","summary":"解放时间与地点的新工作方式","category":"创业与收入","readTime":9,"level":"进阶"},
    {"cover":"📣","title":"你凭什么做好互联网","author":"曹政","summary":"互联网时代的个人竞争力","category":"创业与收入","readTime":7,"level":"进阶"},
    {"cover":"🏗️","title":"重来","author":"贾森·弗里德","summary":"小团队高效创业的反常识指南","category":"创业与收入","readTime":6,"level":"进阶"},
    {"cover":"🌐","title":"平台革命","author":"帕克 & 范·埃尔斯泰恩","summary":"理解平台经济与商业模式创新","category":"创业与收入","readTime":10,"level":"进阶"},
    {"cover":"💡","title":"斯坦福大学创业成长课","author":"彼得·蒂尔","summary":"科技创业的底层逻辑","category":"创业与收入","readTime":8,"level":"进阶"},
    # 金钱心理 7本
    {"cover":"🧬","title":"金钱心理学","author":"摩根·豪塞尔","summary":"关于贪婪、恐惧与财富的永恒道理","category":"金钱心理","readTime":9,"level":"入门"},
    {"cover":"😊","title":"幸福的金钱","author":"伊丽莎白·邓恩","summary":"科学研究：怎么花钱才能买到幸福","category":"金钱心理","readTime":8,"level":"入门"},
    {"cover":"🎭","title":"影响力","author":"罗伯特·西奥迪尼","summary":"说服与消费决策背后的心理规律","category":"金钱心理","readTime":9,"level":"进阶"},
    {"cover":"🔮","title":"预测非理性","author":"丹·艾瑞里","summary":"我们的决策为何系统性地偏离理性","category":"金钱心理","readTime":9,"level":"进阶"},
    {"cover":"💲","title":"当下的幸福","author":"丹·吉尔伯特","summary":"人们为什么总是误判财富带来的幸福","category":"金钱心理","readTime":8,"level":"进阶"},
    {"cover":"🏆","title":"成功人士的七个习惯","author":"史蒂芬·柯维","summary":"从个人效能到财务规律","category":"金钱心理","readTime":10,"level":"入门"},
    {"cover":"🌊","title":"心流","author":"米哈里·契克森米哈","summary":"不靠金钱也能获得最优体验","category":"金钱心理","readTime":9,"level":"进阶"},
    # 财务规划 8本
    {"cover":"🗺️","title":"财务规划实战手册","author":"卡尔·理查兹","summary":"用素描图解释个人财务规划","category":"财务规划","readTime":7,"level":"入门"},
    {"cover":"🏡","title":"富裕的退休生活","author":"威廉·伯恩斯坦","summary":"为退休科学配置资产","category":"财务规划","readTime":9,"level":"进阶"},
    {"cover":"📋","title":"一页纸理财计划","author":"卡尔·理查兹","summary":"用最简单的方式规划人生财务","category":"财务规划","readTime":6,"level":"入门"},
    {"cover":"🌙","title":"结婚前必读的理财书","author":"大卫·바哈","summary":"伴侣共同财务规划的实用指南","category":"财务规划","readTime":7,"level":"入门"},
    {"cover":"💰","title":"自动化百万富翁","author":"大卫·巴哈","summary":"设置系统，让财富自动增长","category":"财务规划","readTime":7,"level":"入门"},
    {"cover":"🎓","title":"父母的钱·孩子的未来","author":"玛利亚·布鲁诺","summary":"为子女教育进行财务规划","category":"财务规划","readTime":8,"level":"进阶"},
    {"cover":"📊","title":"生命周期投资法","author":"艾尔斯 & 纳扎里","summary":"不同人生阶段的最优资产配置","category":"财务规划","readTime":10,"level":"进阶"},
    {"cover":"🏛️","title":"遗产规划完全指南","author":"丹尼斯·克利福德","summary":"如何合法有效地传承财富","category":"财务规划","readTime":9,"level":"进阶"},
]

# ─────────────────────────────────────────────
# 3. AI 生成函数
# ─────────────────────────────────────────────

def generate_article_paragraphs(article: dict) -> list[str]:
    prompt = f"""你是一位中文个人理财作家。请为以下文章生成 paragraphs 内容（约600-800字）。

文章信息：
- 标题：{article['title']}
- 副标题：{article['subtitle']}
- 分类：{article['category']}
- 难度：{article['level']}

格式规则（必须严格遵守）：
- 用 "## " 开头表示小标题（2-3个）
- 用 "• " 开头表示要点列表
- 用 "💡 " 开头表示提示/建议（绿色高亮框）
- 用 "⚠️ " 开头表示警告（黄色高亮框）
- 普通正文直接写

输出格式：每个段落单独一行，用 JSON 数组包裹，例如：
["## 第一节标题", "正文内容...", "• 要点一", "💡 提示内容"]

只输出 JSON 数组，不要其他文字。"""

    resp = client.chat.completions.create(
        model=MODEL,
        messages=[{"role": "user", "content": prompt}],
        temperature=0.7,
    )
    raw = resp.choices[0].message.content.strip()
    # 提取 JSON 数组
    match = re.search(r'\[.*\]', raw, re.DOTALL)
    if match:
        return json.loads(match.group())
    return [raw]


def generate_book_paragraphs(book: dict) -> tuple[list[str], list[str]]:
    prompt = f"""你是一位中文书评作家。请为以下书籍生成书籍精读内容。

书籍信息：
- 书名：{book['title']}
- 作者：{book['author']}
- 简介：{book['summary']}
- 分类：{book['category']}

请输出以下 JSON 格式：
{{
  "paragraphs": ["## 核心论点", "正文...", "• 要点", "💡 启示"],
  "keyPoints": ["第一个核心要点（20字内）", "第二个核心要点", "第三个核心要点", "第四个核心要点", "第五个核心要点"]
}}

paragraphs 约 500-700 字，keyPoints 恰好 5 条。只输出 JSON，不要其他文字。"""

    resp = client.chat.completions.create(
        model=MODEL,
        messages=[{"role": "user", "content": prompt}],
        temperature=0.7,
    )
    raw = resp.choices[0].message.content.strip()
    match = re.search(r'\{.*\}', raw, re.DOTALL)
    if match:
        data = json.loads(match.group())
        return data.get("paragraphs", []), data.get("keyPoints", [])
    return [], []


# ─────────────────────────────────────────────
# 4. Swift 代码生成辅助函数
# ─────────────────────────────────────────────

def swift_string(s: str) -> str:
    """转义 Swift 字符串中的特殊字符"""
    return s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n')

def swift_string_array(lst: list) -> str:
    items = ",\n            ".join(f'"{swift_string(s)}"' for s in lst)
    return f'[\n            {items}\n        ]'


# ─────────────────────────────────────────────
# 5. 主流程
# ─────────────────────────────────────────────

def main():
    lines = [
        "import Foundation",
        "",
        "// Auto-generated by generate_articles.py",
        "// DO NOT EDIT MANUALLY",
        "",
        "let financialArticles: [Article] = ["
    ]

    for i, article in enumerate(ARTICLES_PLAN):
        print(f"[{i+1}/50] 生成文章：{article['title']}")
        try:
            paragraphs = generate_article_paragraphs(article)
        except Exception as e:
            print(f"  ⚠️ 失败，使用占位内容: {e}")
            paragraphs = [f"## {article['title']}", article['subtitle']]

        lines.append("    Article(")
        lines.append(f'        icon: "{swift_string(article["icon"])}",')
        lines.append(f'        title: "{swift_string(article["title"])}",')
        lines.append(f'        subtitle: "{swift_string(article["subtitle"])}",')
        lines.append(f'        content: "{swift_string(article["subtitle"])}",')
        lines.append(f'        tag: "{swift_string(article["tag"])}",')
        lines.append(f'        category: "{swift_string(article["category"])}",')
        lines.append(f'        readTime: {article["readTime"]},')
        lines.append(f'        level: "{swift_string(article["level"])}",')
        lines.append(f'        paragraphs: {swift_string_array(paragraphs)}')
        lines.append("    )" + ("," if i < len(ARTICLES_PLAN) - 1 else ""))

        time.sleep(0.5)  # 避免触发限流

    lines.append("]")
    lines.append("")
    lines.append("let classicBooks: [BookSummary] = [")

    for i, book in enumerate(BOOKS_PLAN):
        print(f"[{i+1}/50] 生成书籍：{book['title']}")
        try:
            paragraphs, key_points = generate_book_paragraphs(book)
        except Exception as e:
            print(f"  ⚠️ 失败，使用占位内容: {e}")
            paragraphs = [f"## {book['title']}", book['summary']]
            key_points = ["核心要点1", "核心要点2", "核心要点3", "核心要点4", "核心要点5"]

        lines.append("    BookSummary(")
        lines.append(f'        cover: "{swift_string(book["cover"])}",')
        lines.append(f'        title: "{swift_string(book["title"])}",')
        lines.append(f'        author: "{swift_string(book["author"])}",')
        lines.append(f'        summary: "{swift_string(book["summary"])}",')
        lines.append(f'        keyPoints: {swift_string_array(key_points)},')
        lines.append(f'        category: "{swift_string(book["category"])}",')
        lines.append(f'        readTime: {book["readTime"]},')
        lines.append(f'        level: "{swift_string(book["level"])}",')
        lines.append(f'        paragraphs: {swift_string_array(paragraphs)}')
        lines.append("    )" + ("," if i < len(BOOKS_PLAN) - 1 else ""))

        time.sleep(0.5)

    lines.append("]")

    output_path = "moneyfull_ios/Views/FinancialAcademyData.swift"
    with open(output_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    print(f"\n✅ 完成！输出文件：{output_path}")
    print(f"   文章：{len(ARTICLES_PLAN)} 篇  书籍：{len(BOOKS_PLAN)} 本")


if __name__ == "__main__":
    main()
```

---

## 使用步骤

**第一步：安装依赖**
```bash
pip install openai
```

**第二步：设置 API Key**
```bash
export OPENAI_API_KEY="sk-你的key"
```
如果用 Claude，改用：
```bash
pip install anthropic
export ANTHROPIC_API_KEY="sk-ant-你的key"
```
然后把脚本里的 `client` 初始化和 `generate_*` 函数改成 Anthropic 调用。

**第三步：运行脚本**
```bash
cd /Users/cs/Desktop/CS/AI/moneyfull_ios
python generate_articles.py
```
运行时间约 **10-15 分钟**（100 次 API 调用，含限流延迟）。

**第四步：添加到 Xcode**

脚本会生成 `moneyfull_ios/Views/FinancialAcademyData.swift`，内容是：
```swift
let financialArticles: [Article] = [ ... ]
let classicBooks: [BookSummary] = [ ... ]
```
在 Xcode 里把这个文件加入工程，`FinancialAcademyView.swift` 里的 `financialArticles` 和 `classicBooks` 就自动找到数据了。

---

## 关键设计说明

| 设计点 | 说明 |
|---|---|
| `time.sleep(0.5)` | 每次请求间隔，避免 Rate Limit |
| `try/except` 容错 | 某条生成失败时用占位内容，不中断整个脚本 |
| `## ` / `• ` / `💡 ` / `⚠️ ` | 与 `ArticleDetailView` 的渲染逻辑完全对应 |
| `swift_string()` | 转义双引号和反斜杠，保证输出是合法 Swift |
| JSON 数组解析 | AI 有时会在 JSON 前后加说明文字，用正则提取确保稳定 |

如果你想切换到 **免费的 Cursor 内置 AI** 来生成（不消耗自己的 API Key），告诉我，我可以把思路改成 Cursor Composer 的批量 prompt 方式。image.png