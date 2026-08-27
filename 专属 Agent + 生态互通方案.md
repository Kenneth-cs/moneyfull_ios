
## 你的方向对吗？

**总体方向是对的，但时机和优先级很关键。**

### 为什么是对的

你的核心目标是**"专属 Agent + 生态互通"**，这两件事本质上都需要服务端。原因是：

- iCloud 是设备绑定的本地同步，AI Agent 无法实时读取、分析用户数据
- 用户画像需要跨时间、跨行为累积计算，本地无法完成
- 多 App 生态数据互通，必须有一个中间层来聚合

### 你需要警惕的问题

**目前已有用户在用**，这意味着你有一个 iCloud 数据迁移的包袱。这个迁移如果做不好，会流失真实用户。

---

## 数据架构的核心设计理念

你说的"不弄脏数据"是最关键的点，我把这个问题的解法叫做**"三层隔离架构"**：

```
┌─────────────────────────────────────────────────────────┐
│  第三层：Agent 智能层（跨 App 共享，推理出的洞察）          │
│  user_agent_memory / cross_app_insights                 │
├─────────────────────────────────────────────────────────┤
│  第二层：用户画像层（派生数据，从原始数据计算得出）           │
│  user_portraits / portrait_dimensions                   │
├─────────────────────────────────────────────────────────┤
│  第一层：原始数据层（各 App 独立命名空间，绝不混用）          │
│  moneyfull_* / lifecoach_* / app_x_*                   │
└─────────────────────────────────────────────────────────┘
         ↑ 只有向上的数据流，原始数据绝不被其他 App 直接读写
```

**核心原则：原始数据属于各自的 App，画像和洞察属于用户本人，上层不能反向修改下层。**

---

## 数据库迭代规划（分4个阶段）

### 第一阶段：统一身份 + 数据迁移（最紧急，2-4周）

这是一切的地基，必须先做好。

```sql
-- 统一用户身份表（所有 App 共用）
CREATE TABLE users (
    id          VARCHAR(36) PRIMARY KEY,  -- UUID
    phone       VARCHAR(20) UNIQUE,       -- 可选，用于跨设备找回
    email       VARCHAR(100) UNIQUE,      -- 可选
    apple_id    VARCHAR(100) UNIQUE,      -- Sign in with Apple
    created_at  TIMESTAMP DEFAULT NOW(),
    last_active TIMESTAMP
);

-- App 注册表（你每新增一个 App 就插一条）
CREATE TABLE apps (
    id       VARCHAR(20) PRIMARY KEY,  -- 如 'moneyfull', 'lifecoach'
    name     VARCHAR(50),
    version  VARCHAR(10)
);

-- 用户与 App 的绑定关系（用户在哪些 App 有账号）
CREATE TABLE user_app_memberships (
    user_id    VARCHAR(36),
    app_id     VARCHAR(20),
    joined_at  TIMESTAMP,
    icloud_migration_done BOOLEAN DEFAULT FALSE,  -- 迁移标记
    PRIMARY KEY (user_id, app_id)
);
```

**迁移策略（不丢失现有 iCloud 用户）**：
1. App 升级时：用 `Sign in with Apple` 让用户登录，创建 server 账号
2. 首次登录后：把 iCloud 本地数据上传到 server 作为历史数据
3. 新数据：直接写 server，iCloud 保留为离线备份
4. 过渡期结束后：iCloud 降为只读缓存

---

### 第二阶段：各 App 原始数据上云（按需推进）

钱小满的核心表迁移到 MySQL，**严格用 `app_id` 做命名空间隔离**：

```sql
-- 项目表（钱小满专属）
CREATE TABLE mf_projects (
    id          VARCHAR(36) PRIMARY KEY,
    user_id     VARCHAR(36) NOT NULL,  -- 关联统一用户
    name        VARCHAR(100),
    budget      DECIMAL(12,2),
    created_at  TIMESTAMP,
    -- ... 其他字段
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- 交易流水（钱小满专属）
CREATE TABLE mf_transactions (
    id          VARCHAR(36) PRIMARY KEY,
    user_id     VARCHAR(36) NOT NULL,
    project_id  VARCHAR(36),
    amount      DECIMAL(12,2),
    category    VARCHAR(50),
    note        TEXT,
    created_at  TIMESTAMP,
    -- 保留 AI 相关字段
    ai_parsed   BOOLEAN DEFAULT FALSE,
    raw_input   TEXT  -- 用户的原始语音/文字，AI 训练用
);
```

**关键原则：人生教练 App 的服务端代码，物理上不能 JOIN 钱小满的表。靠业务层隔离，不靠数据库权限。**

---

### 第三阶段：用户画像层（核心竞争力，3-6个月后）

画像是**从原始数据计算出来的**，不是手写进去的。这层是你构建 Agent 的关键。

```sql
-- 用户画像主表
CREATE TABLE user_portraits (
    user_id     VARCHAR(36) PRIMARY KEY,
    updated_at  TIMESTAMP,
    -- 画像是一个 JSON 大字段，随时扩展，不用频繁改表结构
    portrait    JSON   
    -- portrait 结构示例：
    -- {
    --   "financial": {
    --     "avg_monthly_expense": 4200,
    --     "top_categories": ["餐饮", "交通"],
    --     "saving_rate": 0.18,
    --     "budget_discipline_score": 72  -- 0-100分
    --   },
    --   "behavior": {
    --     "active_days_per_week": 3.2,
    --     "preferred_input_method": "ai_voice",
    --     "typical_record_time": "21:00-22:00"
    --   },
    --   "life_goals": [...]  -- 来自人生教练 App
    -- }
);

-- 画像更新日志（可追溯，不弄脏历史）
CREATE TABLE portrait_change_logs (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id     VARCHAR(36),
    dimension   VARCHAR(50),  -- 如 'financial.saving_rate'
    old_value   JSON,
    new_value   JSON,
    source_app  VARCHAR(20),  -- 是哪个 App 贡献的这次更新
    computed_at TIMESTAMP
);
```

**画像计算方式**：不是实时的，而是**定时批量计算**（比如每天凌晨跑一次），把原始流水汇总成画像数值。这样原始数据永远干净，画像只是视图层的体现。

---

### 第四阶段：Agent 记忆层（长期目标）

这层让你的 AI 真正理解用户，是护城河所在。

```sql
-- Agent 对话记忆（每个 App 的 AI 助手都有独立记忆）
CREATE TABLE agent_memories (
    id          VARCHAR(36) PRIMARY KEY,
    user_id     VARCHAR(36),
    app_id      VARCHAR(20),
    memory_type VARCHAR(30),  -- 'preference' / 'fact' / 'goal' / 'habit'
    content     TEXT,         -- "用户不喜欢被催记账"
    importance  INT,          -- 重要度 1-10
    created_at  TIMESTAMP,
    expires_at  TIMESTAMP     -- 有些记忆会过期
);

-- 跨 App 的共享洞察（由平台层计算，不是单个 App 写的）
CREATE TABLE cross_app_insights (
    user_id     VARCHAR(36),
    insight_key VARCHAR(50),  -- 如 'life_financial_alignment'
    insight     JSON,
    -- 示例：{"financial_stress": 0.4, "goal_alignment_score": 68,
    --         "recommendation": "你的财务目标和人生规划有些不一致"}
    computed_at TIMESTAMP
);
```

---

## 数据安全设计（你最担心的点）

```
用户数据权限模型：

✅ moneyfull 服务  →  可读写 mf_* 表
✅ moneyfull 服务  →  可读写自己贡献的 portrait 维度
✅ lifecoach 服务  →  可读写 lc_* 表
✅ lifecoach 服务  →  可读写自己贡献的 portrait 维度

✅ moneyfull 服务  →  可读 user_portraits（画像层，但只读）
✅ lifecoach 服务  →  可读 user_portraits（画像层，但只读）

❌ moneyfull 服务  →  禁止读写 lc_* 表（人生教练原始数据）
❌ lifecoach 服务  →  禁止读写 mf_* 表（钱小满原始数据）
❌ 任何服务        →  禁止直接写 cross_app_insights（只有平台层可写）
```

**技术实现**：在后端用不同的数据库连接账号（MySQL 用户权限），服务 A 的账号物理上没有服务 B 表的读权限。

---

## 我的建议：分步执行，不要一步到位

```
现在（0-1个月）：
  先做「统一账号体系」+ iCloud 数据迁移方案
  不急着做用户画像，先把账号做稳

1-3个月：
  钱小满原始数据上 server
  AI 聊天记录上 server（这是训练专属 Agent 的关键原料）

3-6个月：
  跑通第一版用户画像计算（从钱小满数据开始）
  上线第二个 App 并接入统一账号

6个月后：
  开放画像层给各 App 读取
  开始构建跨 App 洞察
```

**一个最重要的建议**：在开始之前，先明确向用户说明数据会上传到服务器（更新隐私政策），并给用户一个"不同意就不用"的选择。这不只是法律要求，更是用户信任的基础，也是你未来用画像做 Agent 的合法性前提。

---

总结一下：你的方向完全正确，核心是**先做干净的"三层隔离架构"，画像和原始数据物理分离，上层靠计算不靠手写，权限在服务层而不是应用层做控制**。这样既能打通生态，又能保证各 App 的数据不会互相污染。