# （未开发）账号体系 · 登录 · 数据云化迁移 PRD

**文档版本**：v3.3（新增多人协作记账的数据库预留设计：mf_project_members 表 + created_by_user_id 字段改名 + 协作者头像/昵称展示方案）
**创建日期**：2026-08-04
**最后更新**：2026-08-06
**功能归属**：基础设施迭代 · 全 App 生态通用
**目标**：完成从「iCloud 本地模式」到「服务端账号体系 + 用户画像生态」的第一步迁移

> **v3.0 架构说明**：v2.x 版本为了在"保留 iCloud"的前提下解决多账号串号问题，
> 引入了 `ownerAppUserId` + `syncedToServer` 双标记体系，逻辑较复杂。
> v3.0 改为更彻底的方案：**游客模式下 iCloud 照常工作（零改动、零风险）；
> 用户登录的那一刻，做一次性数据迁移，之后关闭 iCloud，完全交给服务端同步**。
> 这从根源上消除了 iCloud 与服务端的双写冲突，架构更简单、更不容易出错。

---

## 一、背景与目标

### 现状
- 钱小满目前以 **device_id（设备号）** 作为匿名用户标识
- 数据通过 **iCloud + SwiftData** 本地同步，无服务端账号概念
- 已有真实用户在使用，存量数据不能丢失

### 目标
- 建立**统一账号体系**，支撑钱小满及后续所有 App（人生教练等）
- 完成**数据从 iCloud 到 MySQL 服务端的平滑迁移**，不强迫用户，不丢数据
- 为后续**用户画像层 → 专属 Agent** 打好数据地基

### 整体三层架构（长期规划）

```
┌─────────────────────────────────────────────────────────────┐
│  第三层：Agent 智能层（跨 App 共享，推理出的洞察）              │
│  agent_memories / cross_app_insights                        │
├─────────────────────────────────────────────────────────────┤
│  第二层：用户画像层（派生数据，从原始数据定时计算得出）            │
│  portrait_profiles / portrait_change_logs                   │
│  ⚠️ 与原始数据同库，但独立表组，禁止原始数据层直接写入           │
├─────────────────────────────────────────────────────────────┤
│  第一层：原始数据层（各 App 独立表前缀，绝不混用）                │
│  mf_* (钱小满) / lc_* (人生教练) / 共用：users / apps        │
└─────────────────────────────────────────────────────────────┘
         ↑ 只有向上的数据流，原始数据绝不被其他 App 直接读写
```

**本次 PRD 范围（第一步）**：账号体系 + 手机号登录 + 数据迁移机制。  
微信登录、Apple 登录、用户画像层为后续迭代，但表结构设计时预留字段。

---

## 二、登录方式决策

### 第一步：手机号 + 密码体系（短信仅用于注册与找回密码）

| 方式 | 第一步 | 后续迭代 | 原因 |
|------|--------|---------|------|
| **手机号 + 密码**（注册/找回密码时用短信验证） | ✅ 做 | — | 无需第三方资质，实现简单，账号找回最稳定，日常登录无需短信，节省成本 |
| **微信登录** | ❌ 暂缓 | 第二步 | 需要企业主体微信开放平台资质 |
| **Apple 登录** | ❌ 暂缓 | 与微信同步 | App Store 规定：**只要提供任何第三方登录，必须同时提供 Apple 登录**。当微信登录上线时，Apple 登录必须同步上线 |

> **关键提醒**：第一步只做手机号，不涉及第三方登录，此时 App Store **不要求** Apple 登录。
> 一旦微信登录上线，必须同期上线 Apple 登录，否则面临下架风险。

### 2.1 三个核心流程

```
【注册】手机号 + 短信验证码（验证手机号真实性）+ 设置密码 → 完成注册
【登录】手机号 + 密码 → 直接登录，无需短信（日常高频操作，减少短信成本和步骤）
【忘记密码】手机号 + 短信验证码（验证身份）→ 设置新密码 → 完成重置
```

数据库层面需要在 `users` 表新增密码字段（见 3.1 节 schema 更新）。

### 短信服务方案（已简化，按现阶段体量调整）

- 推荐：**阿里云短信服务**（约 0.045 元/条，个人开发者可申请）
- 验证码有效期：5 分钟
- 防护措施：**同手机号 60 秒间隔、10 次/天上限**，作为唯一限流手段
- **不引入图形验证码/滑动验证**：现阶段用户体量小，图形验证码会增加注册门槛、影响转化率，暂不做
- **保留一个几乎零成本的兜底**：同一 IP 每分钟最多请求 5 次短信接口（防止脚本对单一来源疯狂调用），不引入额外交互，用户无感知
- **后续视情况升级**：如果上线后观察到短信发送量异常（如短时间内暴涨、大量验证码未被验证使用等），再考虑加图形验证码或滑动验证，现在不做提前优化

> 这个决策的取舍很清楚：现阶段体量小，被攻击的绝对损失有限（按量计费，即使被刷满一天上限，损失可控），
> 优先保证注册转化率；如果后续用户量上来后出现真实的滥刷问题，再补图形验证码也不迟，不是不可逆的决定。

---

## 三、数据库设计（v2.0 修订版）

### 策略：同一个 MySQL 实例，表前缀隔离

```
数据库：moneyfull_db（唯一 MySQL 实例）
├── [共用] users                  用户身份表
├── [共用] apps                   App 注册表
├── [共用] user_app_memberships   用户 × App 绑定关系
├── [共用] user_sync_states       数据同步状态追踪
├── [钱小满] mf_projects
├── [钱小满] mf_project_members      项目成员关系表（为多人协作预留）
├── [钱小满] mf_transactions
├── [钱小满] mf_categories
├── [人生教练-后续] lc_goals
├── [人生教练-后续] lc_journals
├── [画像层-第二步后] portrait_profiles
└── [画像层-第二步后] portrait_change_logs
```

### 3.1 核心表结构（v2.0 修订）

```sql
-- =============================================
-- 统一用户表（修订：BIGINT主键 + 外部UUID + 预留微信UnionID）
-- =============================================
CREATE TABLE users (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,  -- 内部主键，不对外暴露
    user_uuid       VARCHAR(36) NOT NULL UNIQUE,        -- 对外唯一标识（API 中使用此字段）
    phone           VARCHAR(20) UNIQUE,                 -- 手机号（第一步主要登录方式）
    password_hash   VARCHAR(255),                       -- 密码哈希（bcrypt/argon2，绝不存明文）
    wechat_unionid  VARCHAR(100) UNIQUE,                -- 微信跨App唯一ID（后续微信登录时填入）
    wechat_openid   VARCHAR(100) UNIQUE,                -- 微信本App的OpenID（后续填入）
    apple_sub       VARCHAR(100) UNIQUE,                -- Apple Sign In 的 Subject ID（后续填入）
    display_name    VARCHAR(50),
    avatar_url      VARCHAR(300),
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    is_deleted      TINYINT(1) DEFAULT 0                -- 逻辑删除（满足Apple审核账号注销要求）
);
-- ⚠️ wechat_unionid vs wechat_openid 的关键区别：
--    openid  = 用户在「本App」的唯一ID，换一个App就变了
--    unionid = 用户在「同一微信开放平台主体下所有App」的唯一ID
--    跨App生态打通（钱小满↔人生教练）必须用 unionid，否则无法识别为同一个人

-- =============================================
-- App 注册表
-- =============================================
CREATE TABLE apps (
    id          VARCHAR(20) PRIMARY KEY,   -- 'moneyfull' / 'lifecoach'
    name        VARCHAR(50),
    bundle_id   VARCHAR(100)
);

-- =============================================
-- 用户 × App 绑定关系
-- =============================================
CREATE TABLE user_app_memberships (
    user_id               BIGINT NOT NULL,
    app_id                VARCHAR(20) NOT NULL,
    device_id             VARCHAR(100),                -- 绑定前的匿名设备号（用于迁移关联）
    joined_at             TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    icloud_migration_done TINYINT(1) DEFAULT 0,        -- iCloud历史数据是否已上传
    PRIMARY KEY (user_id, app_id)
);

-- =============================================
-- 用户同步状态表（解决新老用户判断、冲突检测）
-- =============================================
CREATE TABLE user_sync_states (
    user_id              BIGINT PRIMARY KEY,
    app_id               VARCHAR(20),
    server_record_count  INT DEFAULT 0,               -- 服务端存有多少条数据（判断是否首次登录）
    last_sync_at         TIMESTAMP,                   -- 最后一次成功同步时间
    icloud_upload_done   TINYINT(1) DEFAULT 0
);

-- =============================================
-- 交易流水表（修订：引入版本号、逻辑删除、服务端权威时间戳）
-- ⚠️ v3.3 修订：user_id 改名为 created_by_user_id，
--    明确语义为"记账人"而非"拥有者"，为多人协作预留（见 3.3 节）
-- =============================================
CREATE TABLE mf_transactions (
    id                VARCHAR(36) PRIMARY KEY,         -- 客户端生成的 UUID（保证离线也能创建）
    created_by_user_id BIGINT NOT NULL,                -- 记账人（谁记的这笔账），不代表"归属"
    project_id        VARCHAR(36),
    amount            DECIMAL(12, 2) NOT NULL,
    category          VARCHAR(50),
    note              TEXT,
    transaction_at    TIMESTAMP NOT NULL,              -- 用户填写的交易时间（可手动修改，不用于冲突判断）
    ai_parsed         TINYINT(1) DEFAULT 0,
    raw_input         TEXT,

    -- 并发控制与同步关键字段
    version           INT DEFAULT 1,                   -- 乐观锁版本号：每次修改 +1，服务端拒绝低版本的覆盖写
    is_deleted        TINYINT(1) DEFAULT 0,            -- 逻辑删除：删除操作同步给服务端，防止"死而复生"
    server_updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    -- server_updated_at 由服务端在写入时生成，客户端不可伪造，用于增量同步拉取

    INDEX idx_creator_sync (created_by_user_id, server_updated_at),  -- 增量同步核心索引
    INDEX idx_project_sync (project_id, server_updated_at)           -- 多人协作场景：按项目拉增量
);

-- =============================================
-- 项目表（钱小满专属）
-- ⚠️ v3.3 修订：user_id 改名为 created_by_user_id，
--    仅代表"创建者"这一历史事实，当前谁能访问该项目由下方 mf_project_members 决定
-- =============================================
CREATE TABLE mf_projects (
    id              VARCHAR(36) PRIMARY KEY,
    created_by_user_id BIGINT NOT NULL,             -- 创建者（不可变的历史记录，不代表当前访问权限）
    name            VARCHAR(100),
    budget          DECIMAL(12, 2),
    is_archived     TINYINT(1) DEFAULT 0,
    version         INT DEFAULT 1,
    is_deleted      TINYINT(1) DEFAULT 0,
    server_updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_creator_sync (created_by_user_id, server_updated_at)
);

-- =============================================
-- [预留] 项目成员关系表（为多人协作记账预留，第一步只有 owner 一条记录）
-- =============================================
CREATE TABLE mf_project_members (
    id                BIGINT AUTO_INCREMENT PRIMARY KEY,
    project_id        VARCHAR(36) NOT NULL,
    user_id           BIGINT NOT NULL,
    role              VARCHAR(20) NOT NULL,          -- 'owner' / 'member' / 'viewer'，⚠️ 不设默认值，
                                                       -- 强制业务代码显式指定，避免误插入高权限角色
    joined_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_deleted        TINYINT(1) DEFAULT 0,          -- 成员被移出项目时逻辑删除，而非物理删除
    server_updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uk_project_user (project_id, user_id),
    INDEX idx_user_projects (user_id, is_deleted),   -- 核心索引：查"我能访问的所有项目"
    INDEX idx_project_members (project_id, is_deleted) -- 核心索引：查"这个项目当前有哪些成员"
);
```

### 3.2 为什么不用物理外键（FOREIGN KEY）？

v1.0 版本中使用了物理外键，此处说明为何改为应用层保证：

- **现阶段暂时保留物理外键**：单库单应用，外键能防止脏数据，对早期产品利大于弊
- **计划在分库前移除**：一旦数据量大到需要拆库，外键是硬性障碍
- **应用层需同时做完整性校验**：不能单靠数据库，业务代码要自行检查引用关系

### 3.3 为多人协作记账预留的设计（现在做，成本极低；后续再做，成本很高）

> 背景：后续要做"同一个项目可邀请其他账号一起记账"的功能。这个功能的业务逻辑
> （邀请码、权限管理、加入/退出）可以完全放到后续版本开发，但底层数据结构现在不预留，
> 以后要从"单人所有"模型迁移到"多人共享"模型，需要写数据回填脚本、且不能中断线上服务，
> 代价远高于现在顺手加一张表。现在做这几处改动，不增加第一步任何 UI/业务逻辑的开发量。

**现在做的三件事：**

1. **字段改名**：`mf_projects.user_id` / `mf_transactions.user_id` 改为 `created_by_user_id`，
   明确语义是"创建者/记账人"，而不是"当前访问权限的拥有者"（已体现在上面的建表语句中）
2. **新增 `mf_project_members` 表**：项目的访问权限完全由这张表决定，而不是看 `mf_projects.created_by_user_id`
3. **`GET /sync/pull` 查询逻辑现在就用 JOIN 写法**（见 5.5 节），而不是等以后再重写：

```sql
-- 现在（第一步）就用这个查询，虽然此时每个项目只有一条 owner 记录，
-- 查询结果和直接 WHERE created_by_user_id = ? 完全一样，但以后加了协作功能也不用改查询逻辑
SELECT p.* FROM mf_projects p
JOIN mf_project_members pm ON p.id = pm.project_id
WHERE pm.user_id = ? AND pm.is_deleted = 0
```

**第一步的极简业务逻辑**：用户创建一个 `mf_projects`，服务端顺手往 `mf_project_members`
插入一条 `(project_id, user_id, role='owner')`，仅此而已，不涉及邀请、二维码等任何多人协作的前端/接口开发。

### 3.4 多人协作时展示对方头像/昵称的设计

> 需求：多人共享项目里，看到别人记的账时，需要显示这个人的头像和昵称。

这个不需要额外新增字段冗余存储头像/昵称——`users` 表已经有 `display_name` 和 `avatar_url`，
只需要一个专门的"项目成员信息"接口，让 JOIN 在查询时发生，而不是把头像昵称重复存到每条流水记录里：

```
GET /projects/:project_id/members
→ 返回：
[
  { "user_uuid": "xxx", "display_name": "张三", "avatar_url": "https://...", "role": "owner" },
  { "user_uuid": "yyy", "display_name": "李四", "avatar_url": "https://...", "role": "member" }
]

实现：SELECT u.user_uuid, u.display_name, u.avatar_url, pm.role
      FROM mf_project_members pm
      JOIN users u ON pm.user_id = u.id
      WHERE pm.project_id = ? AND pm.is_deleted = 0
```

**客户端使用方式：**

```
打开一个共享项目详情页时，调用一次 GET /projects/:id/members，
在本地缓存一份"项目成员 user_uuid → {头像, 昵称}"的映射表
      ↓
渲染流水列表时，用每条 mf_transactions.created_by_user_id
去查这份本地缓存映射表，显示对应的头像和昵称
      ↓
不需要在每次同步流水数据时都带上头像/昵称信息，
避免头像/昵称冗余存储在大量流水记录里、以及用户改头像后到处都要更新的问题
```

**为什么不做数据冗余（比如在 mf_transactions 里也存一份头像/昵称快照）？**

- 用户头像/昵称是会变的，实时查 `users` 表能保证任何时候看到的都是最新的
- 唯一的例外场景：如果某成员后来注销了账号（4.5节），`users.display_name` 会被置为"已注销用户"，
  此时其历史记账记录会自然显示为"已注销用户"，这是合理的兜底效果，不需要额外设计
- 第一步不需要考虑这个优化，等真正做协作功能、且发现接口调用频率有性能问题时，再考虑要不要加缓存层

**第一步不需要做的（继续推迟到位）**：邀请码/邀请链接生成与核销、成员管理 UI、协作相关的推送通知——这些是纯增量功能，不涉及改造现有表结构。

---

## 四、账号体系设计

### 4.1 核心架构原则：登录状态决定数据管道

这是 v3.0 的核心设计，一张图说清楚：

```
┌──────────────┐   登录（一次性迁移+关闭CloudKit）   ┌──────────────────┐
│   游客模式    │ ─────────────────────────────────→ │     登录模式       │
│              │                                     │                  │
│ SwiftData +  │                                     │  SwiftData（纯本地）│
│ CloudKit同步  │ ←───────────────────────────────── │  ↕ 服务端 MySQL   │
│（原生行为，   │   退出登录（清空本地+重开CloudKit）  │  （CloudKit 已关闭）│
│  零改动）     │                                     │                  │
└──────────────┘                                     └──────────────────┘
```

**两种模式互斥，同一时间只处在其中一种：**

| | 游客模式 | 登录模式 |
|---|---------|---------|
| 数据管道 | SwiftData + CloudKit（系统原生） | SwiftData（纯本地）+ 服务端 API |
| iCloud 是否参与 | ✅ 是，和现在线上版本完全一样 | ❌ 否，彻底断开 |
| 跨设备同步方式 | 靠 iCloud 自动同步 | 靠服务端 push/pull |
| 换手机恢复数据 | 靠 iCloud 自动恢复 | 登录后从服务端拉取 |

> 这样设计的好处：游客模式没有任何变化，不会影响存量用户；只有主动选择登录的用户，才会进入新的服务端体系，复杂度被限制在"登录"这一个动作里，不会扩散到日常使用的方方面面。

### 4.2 游客模式（不强制登录，行为完全不变）

- 游客以 **device_id** 作为匿名身份正常使用，数据存本地 SwiftData + iCloud（原生行为）
- 游客模式无法享受：跨设备云同步（走服务端的那种）、AI Agent 个性化
- 登录引导为**软引导**，不阻断核心使用流程

### 4.3 登录：一次性迁移 + 关闭 iCloud（核心流程）

```
用户点击登录 → 验证码校验成功 → 获得 user_uuid
      ↓
第一步：读取本地 SwiftData（CloudKit 模式）当前所有数据
      ↓
第二步：批量 POST 上传到服务端（走 /sync/migrate 接口）
      ↓
第三步：短暂缓冲监听（30~60秒）
      → 监听 NSPersistentStoreRemoteChange，
        防止 iCloud 还有历史数据在路上没同步完就断开了
      → 期间如果又来新数据，一并追加上传
      → ⚠️ 注意防止「通知回环」：给这批新增记录标记 syncedToServer=true 的
        写入操作本身也会触发一次新的 RemoteChange 通知。简单规避方式：
        维护一个本次会话内"已处理记录 ID"的集合，通知触发时跳过已在集合里的 ID，
        不需要引入完整的持久化历史 Token 机制（这个缓冲窗口只有 30-60 秒，够用）
      ↓
第四步：技术上关闭 CloudKit 同步
      → 重新创建一个 ModelContainer，
        指向同一份本地数据文件，但配置为 cloudKitDatabase: .none
      → ⚠️ 关键点：这必须是真实的配置切换，
        不能只是用 isLoggedIn 这种 if 判断"假装"关闭
        （否则系统仍可能在后台继续接收 iCloud 推送）
      ↓
第五步：从服务端拉取全量/增量数据，补全本地缓存
      ↓
迁移完成，之后所有同步只走服务端 API
```

**技术实现方式（二选一）：**

| 方式 | 说明 | 适用场景 |
|------|------|---------|
| A. 原地切换配置 | 用同一个 SQLite 文件重新创建 `ModelContainer(cloudKitDatabase: .none)` | 实现简单，推荐优先尝试 |
| B. 迁移到新的本地库 | 读取旧 Store 全部数据，写入一个全新的纯本地 `ModelContainer` | 若方式A有兼容问题时的备选方案 |

> 建议开发阶段先验证方式A是否可行（SwiftData 对这种配置切换的支持情况需要实测），有问题再退回方式B。

### ⚠️ 4.3.1 方式A 的潜在风险：SQLite 文件锁（P1，实现时需注意）

方式A 是"销毁旧 Container，用同一个 SQLite 文件路径创建新 Container"，存在一个真实的时序风险：
CloudKit 的后台同步线程可能还没完全释放对该 SQLite 文件的句柄，此时立刻用同一路径创建新 Container，
可能报 `SQLite Error 5: database is locked`，或新 Container 创建失败。

**规避措施：**

```
销毁旧 Container 时的正确顺序：
  1. 显式将旧 ModelContext 置为 nil，释放引用
  2. 显式调用旧 Container 的清理/reset 方法，确保 CloudKit 同步线程收到停止信号
  3. 短暂等待（如 0.5 秒）再创建新 Container，给系统释放文件句柄的时间
  4. 创建新 Container 时做好失败捕获（try/catch），一旦捕获到文件锁错误：
     → 不要重试硬刚，直接降级走「方式B」（迁移到全新本地库文件）
```

**决策原则**：方式A 的预研放在开发最早期做，如果实测发现 SQLite 锁问题频繁出现，
不要花时间硬解决时序问题，直接切换到方式B——方式B 虽然多写几行"读旧库写新库"的代码，
但没有任何文件锁的不确定性，稳定性上限更高，是更值得托底的方案。

### 4.4 退出登录（切换账号）

> ✅ **v3.0 改进**：因为登录期间 iCloud 已经被关闭，退出登录时**可以安全地物理清空本地数据**，
> 不会有任何 CloudKit 级联删除的风险（这是 v2.x 版本最头疼的问题，v3.0 架构下自然消失）。

```
用户点击「退出登录」
      ↓
检查本地是否有 syncedToServer = false 的记录（未上传成功的数据）= N 条
│
├─ N = 0（所有数据已同步）
│    → 直接退出：清除 Keychain token
│    → 重置本地 Store（删除 SQLite 文件或清空数据库）
│    → 重新创建 Guest 模式的 ModelContainer（cloudKitDatabase 重新开启）
│    → 回到游客状态（此时 iCloud 会自动把"从未被任何账号带走"的旧数据同步回来，
│       这些数据是真正意义上的"游客数据"，不属于刚退出的这个账号）
│
└─ N > 0（有数据尚未上传成功，比如网络问题）
     → 弹出 Sheet：
        ┌────────────────────────────────────────────────┐
        │  发现 N 条历史数据正在保存，是否继续？            │
        │                                                │
        │  退出前系统将自动完成同步，                      │
        │  确保数据已保存到云端服务器                      │
        │                                                │
        │  [继续保存并退出]    [直接退出（数据可能丢失）]   │
        └────────────────────────────────────────────────┘
     → 「继续保存并退出」：后台上传完成后，再执行上面 N=0 的清空流程
     → 「直接退出」：用户明确知情后，直接清空，未上传的数据丢弃
```

**为什么 A/B 换账号不会串数据？**

```
A 登录期间：iCloud 已关闭，A 的所有数据只去服务端，从未写入 iCloud
A 退出：本地清空，重新开启 iCloud（游客模式）
      → 这时候 iCloud 同步回来的，只可能是"设备上从来没被任何账号认领过的旧游客数据"
      → 不可能是 A 的数据，因为 A 的数据压根没经过 iCloud
B 登录：只会合并这部分游客数据，与 A 完全无关
```

### 4.5 账号注销（⚠️ App Store 硬性要求）

> Apple 审核指南规定：**只要 App 支持账号创建，必须提供账号注销功能**。
> 这与登录方式无关，手机号登录也需要做。

```
用户点击「注销账号」
→ 弹出确认 Sheet（告知后果：数据将被删除，不可恢复）
→ 用户二次确认
→ 服务端执行：
    users.is_deleted = 1
    users.phone = NULL（隐匿敏感信息）
    users.display_name = "已注销用户"
    mf_transactions.is_deleted = 1（批量逻辑删除）
    mf_projects.is_deleted = 1
→ 返回客户端，清除本地 Keychain token
→ 走与「退出登录」相同的本地清空 + 重开 iCloud 流程
→ 退出到登录页
```

注意：**服务端数据不做物理删除**，保留逻辑删除记录，满足数据审计要求，同时避免误操作无法追回。

### 4.6 登录后的多设备同步说明

一旦用户登录，iCloud 不再参与任何设备间同步，跨设备数据一致性完全依赖服务端：

```
iPhone（已登录A）        服务端           iPad（已登录A）
  记一笔账
    ↓ 上传
                      收到并落盘
                                          ↓ App进前台/下拉刷新
                                       拉取增量数据，显示新记录
```

> 这意味着 iPad 上看到 iPhone 新记录的时机，取决于 iPad 什么时候主动同步（进入前台/下拉刷新），
> 而不再是 iCloud 的准实时推送。第一步可以先用"进入前台自动拉取增量"覆盖大部分场景，
> 后续如果需要更实时的多端同步体验，可以引入服务端推送通知（如 APNs）触发主动同步，
> 但这不是第一步的必需项。

---

## 五、同步机制设计

### 5.1 核心原则

| 原则 | 说明 |
|------|------|
| **登录态决定数据管道** | 游客模式=SwiftData+CloudKit（原生不变）；登录模式=SwiftData（纯本地）+服务端，两者互斥，登录时一次性切换 |
| **本地优先，零阻塞** | App 打开立即展示本地 SwiftData 缓存，绝不等待任何网络操作 |
| **服务端时间戳权威** | 冲突判断只用 `server_updated_at`（服务端生成），禁止用客户端时钟 |
| **版本号乐观锁** | 每条记录有 `version` 字段，服务端只接受版本号 ≥ 当前版本的更新 |
| **逻辑删除同步** | 删除操作用 `is_deleted=1` 同步，防止数据"死而复生" |
| **增量同步** | 每次只同步"上次同步时间点之后变化的数据"，不做全量传输 |

### 5.2 App 启动流程

```
App 启动
│
└─ 立即展示本地 SwiftData 已有的数据（0ms 白屏，用户立刻看到内容）
     │
     ├─ 用户已登录（Keychain 有有效 token，本地是纯本地 Store）
     │    └─ 后台静默拉取服务端增量数据
     │         → 拉到新数据后，局部刷新 UI（不打断用户操作）
     │
     └─ 用户未登录（游客模式，本地是 CloudKit Store）
          └─ 监听 NSPersistentStoreRemoteChange（CloudKit 后台同步通知）
               → iCloud 有数据推送时，SwiftData 自动刷新 UI
               → 不需要任何硬等待，完全事件驱动
```

> **说明**：`NSPersistentStoreRemoteChange` 是 Apple 官方的 CloudKit 变更通知，SwiftData 内建支持。
> 游客模式下用它来做无感知的后台刷新；登录模式下由于 CloudKit 已关闭，不会再收到此通知，
> 增量数据的刷新完全由服务端轮询/拉取驱动。

### ⚠️ 5.2.1 iOS 技术实现约束：线程安全（必须遵守，否则会崩溃）

`NSPersistentStoreRemoteChange` 通知**不保证在主线程触发**，直接在回调里操作主线程的
`ModelContext` 或更新 UI 会导致崩溃或数据竞争，实现时必须遵守：

```swift
// ❌ 错误示例：回调线程不确定，直接操作可能崩溃
NotificationCenter.default.addObserver(forName: .NSPersistentStoreRemoteChange, ...) { _ in
    mainModelContext.insert(...)   // 危险：可能不在主线程
    self.refreshUI()               // 危险：UI 状态可能不在主线程更新
}

// ✅ 正确做法：显式分流
NotificationCenter.default.addObserver(forName: .NSPersistentStoreRemoteChange, ...) { _ in
    // 1. 重活（扫描、批量处理）用后台 Context 处理
    Task {
        let bgContext = ModelContext(container)  // 派生的后台上下文
        // ... 在此处理数据变化 ...

        // 2. 涉及 UI 更新的部分，显式切回主线程
        await MainActor.run {
            self.refreshUI()
        }
    }
}
```

**核心约束**：
- 数据扫描/批量处理等重活 → 后台 `ModelContext`，不占用主线程
- 弹窗、状态刷新等 UI 操作 → 必须显式 `@MainActor` / `MainActor.run` 切回主线程
- 不允许同一个 `ModelContext` 实例被多线程同时访问（SwiftData Context 非线程安全）

> **⚠️ 补充：通知回环风险**。如果回调里除了刷新 UI，还会对本地数据做写入（比如打标记、
> save），这次写入本身也会被记入持久化历史，从而再次触发 `NSPersistentStoreRemoteChange`。
> 游客模式下的"纯刷新 UI"场景没有这个问题；但 4.3 节登录迁移流程中的"缓冲监听 + 追加上传"
> 场景涉及写回操作，需要按 4.3 节的说明用"已处理 ID 去重"规避回环，避免重复处理和多余的性能开销。

### 5.3 客户端本地记录的同步标记

客户端 SwiftData 的每条记录（Transaction / Project）需增加一个本地字段，用于登录模式下追踪增量推送：

```swift
// iOS 客户端 SwiftData 模型（不存入 MySQL，纯客户端字段）
@Model class Transaction {
    // ... 正常业务字段 ...
    var syncedToServer: Bool = false  // false = 未上传到服务端，true = 已成功上传
}
```

**用途**：
- 登录期间新建/修改的记录，先本地写入（`syncedToServer = false`），后台上传成功后置为 `true`
- 判断"退出登录时是否有未同步完的数据"，也是靠扫描这个字段
- 由于登录模式下本地库是纯本地、单账号专属的（不会混入其他账号或游客数据），
  **不再需要 `ownerAppUserId` 这类账号归属标记**——本地库本身就是"干净"的，天然不会串号

### 5.4 数据同步的冲突场景及处理方案

#### 场景 A：多设备离线修改同一条记录（已决策：自动取最新 server 版本，不弹窗打扰用户）

```
iPad 离线：把账单 X 从 ¥100 改成 ¥200，version = 2
iPhone 在线：把账单 X 从 ¥100 改成 ¥300，version = 2，成功上传服务端（服务端 version 变为 2）

iPad 联网后，尝试上传 version=2 的修改：

服务端判断：
  收到 version=2 的写请求，但服务端当前 version 已经是 2（被 iPhone 写过了）
  → 判定为冲突，拒绝覆盖
  → 直接返回服务端当前版本数据（¥300），iPad 静默用它覆盖本地缓存
  → 不弹窗、不打断用户，UI 局部刷新为 ¥300 即可
```

> **说明**：不做用户选择弹窗，简化交互。财务数据的多设备并发冲突频率极低（同一账单几乎不会被两台设备同时改），
> 用"服务端最后写入为准"的简单规则即可覆盖绝大多数场景，避免为小概率场景增加交互复杂度。

#### 场景 B：删除操作同步

```
手机删除账单 X → 本地标记 is_deleted = 1 → 上传服务端
服务端记录 is_deleted = 1，同时 server_updated_at 必须一并更新为当前时间

其他设备增量同步时：
  拉到 is_deleted = 1 的记录 → 本地也标记删除，不再显示
  → 彻底防止"死而复生"
```

> **⚠️ 实现细节，容易被忽略但很关键**：`GET /sync/pull?since=xxx` 是按 `server_updated_at > since`
> 筛选变化记录的。如果执行逻辑删除时只改了 `is_deleted=1` 而 `server_updated_at` 没跟着更新，
> 这条删除记录的时间戳还停留在很久以前，会被增量拉取的 `since` 条件过滤掉，导致其他设备永远收不到
> 这条删除指令、本地账单删不掉。好在 3.1 节表结构里 `server_updated_at` 已经设置了
> `ON UPDATE CURRENT_TIMESTAMP`，只要删除操作是通过标准的 `UPDATE ... SET is_deleted=1` 语句执行，
> MySQL 会自动帮忙更新这个时间戳，不需要在业务代码里额外手写——但开发时要注意不要用绕过
> 常规 UPDATE 语句的方式做删除（比如某些 ORM 的部分字段更新可能不触发），需要专项测试验证一下。

#### 场景 C：登录时的一次性数据迁移

> 见 4.3 节完整流程。核心是：不管服务端有没有数据，本地当前 SwiftData（CloudKit 模式）
> 里的全部数据都作为"待迁移数据"一次性上传，上传完成后才切换到纯本地 Store。

```
用户点击登录 → 登录成功
      ↓
读取本地 SwiftData 当前全部记录（此时还是 CloudKit 模式，包含了 iCloud 已同步的所有历史数据）
      ↓
批量上传服务端（/sync/migrate 接口）：
  → 服务端用 id + version 做去重合并（同 id 比 version，不同 id 直接追加）
  → 这样即使账号之前在别的设备登录过、服务端已有数据，也不会覆盖丢失，而是合并
      ↓
上传完成 → 拉取服务端最终数据 → 切换到纯本地 Store（关闭 CloudKit）
```

> **⚠️ 幂等性设计（必须做）**：迁移过程中如果网络波动，客户端可能因为超时重试，把同一批数据
> 重复提交两次。因为客户端生成的 `id`（UUID）就是主键，服务端接口必须实现幂等：
> 用 `INSERT ... ON DUPLICATE KEY UPDATE` 语义处理，同一个 `id` 重复提交时，只在新提交的
> `version` 更大时才更新，否则直接忽略，不会因为重复请求产生两条重复账单。
> 具体 SQL 写法见 5.5 节。

#### 场景 D：登录瞬间 iCloud 还没同步完（残留边界情况，轻量应对）

```
用户重装 App → 游客模式，iCloud 正在后台拉取历史数据（通常几秒到几十秒完成）
      ↓
用户此时立刻点击登录（极少数情况下 iCloud 还没同步完）
      ↓
登录触发迁移：上传"此刻"本地已有的数据
      ↓
迁移完成后，不立即关闭 CloudKit，而是再监听 30~60 秒的 NSPersistentStoreRemoteChange
      ↓
├─ 期间又同步到新数据 → 追加上传，然后再关闭 CloudKit
└─ 期间没有新数据 → 直接关闭 CloudKit，流程结束
```

> **兜底方案**：即使这个极小概率的场景真的漏掉了个别数据，可以在「设置」页提供一个
> 「重新检查本机历史数据」的手动入口，用户可随时触发一次本地→服务端的补充扫描上传，
> 作为最后一道保险，不需要为此设计更复杂的自动化机制。

### 5.5 增量同步接口设计

客户端每次同步，只拉取"上次同步时间后的变化"，不做全量传输：

```
GET /sync/pull?since=2026-08-01T10:00:00Z（携带登录 token 识别当前用户，无需显式传 user_id）
→ 项目列表：走 3.3 节的 JOIN 查询（通过 mf_project_members 判断可访问哪些项目）
   SELECT p.* FROM mf_projects p
   JOIN mf_project_members pm ON p.id = pm.project_id
   WHERE pm.user_id = :current_user AND pm.is_deleted = 0
     AND p.server_updated_at > :since
→ 流水列表：拉取"我参与的项目下的所有流水" + "我自己没归属项目的个人流水"
   SELECT t.* FROM mf_transactions t
   WHERE t.server_updated_at > :since
     AND (
       t.project_id IN (SELECT project_id FROM mf_project_members WHERE user_id = :current_user AND is_deleted = 0)
       OR (t.project_id IS NULL AND t.created_by_user_id = :current_user)
     )
→ 返回记录含 is_deleted=1 的逻辑删除记录

POST /sync/push
Body: { records: [...], client_version_map: { "tx_id_1": 2, "tx_id_2": 1 } }
→ 服务端逐条比对 version，接受或拒绝，返回冲突列表

POST /sync/migrate（登录时一次性迁移专用，见 4.3/5.4场景C）
Body: { records: [...] }
→ 服务端对每条记录执行幂等 UPSERT，语义如下：

  INSERT INTO mf_transactions
    (id, created_by_user_id, amount, category, transaction_at, version, is_deleted, ...)
  VALUES
    (:id, :created_by_user_id, :amount, :category, :transaction_at, :version, :is_deleted, ...)
  ON DUPLICATE KEY UPDATE
    version        = IF(VALUES(version) > version, VALUES(version), version),
    amount         = IF(VALUES(version) > version, VALUES(amount), amount),
    category       = IF(VALUES(version) > version, VALUES(category), category),
    is_deleted     = IF(VALUES(version) > version, VALUES(is_deleted), is_deleted),
    server_updated_at = IF(VALUES(version) > version, CURRENT_TIMESTAMP, server_updated_at);

GET /projects/:project_id/members（见 3.4 节，供客户端展示协作者头像/昵称）

  → 同一个 id 重复提交（比如客户端超时重试），只有 version 更大的那次才会真正生效，
    version 相同或更小的重复请求会被静默忽略，不会产生重复账单，天然满足幂等性
```

---

## 六、登录页面与入口设计

### 6.1 登录入口（非强制，软引导）

**① 首页顶部引导条**（游客状态常驻）
```
┌────────────────────────────────────────────────────────┐
│  🔒 登录后数据更安全，换手机也不怕丢失    [立即登录 →]   │
└────────────────────────────────────────────────────────┘
```

**② 个人中心顶部**（替代头像区域）
```
┌────────────────────────────────────────────────────────┐
│  👤 游客模式                                            │
│  登录后开启云同步 & AI 个性化服务      [立即登录 →]      │
└────────────────────────────────────────────────────────┘
```

**③ 点击「创建项目」时触发**（功能门控）
```
弹出底部 Sheet：
┌────────────────────────────────────────────────────────┐
│  🦫 登录后创建的项目                                    │
│     才能跨设备同步哦~                                   │
│                                                        │
│  [用手机号登录/注册]                                    │
│                                                        │
│              [先不了，继续游客模式]                      │
└────────────────────────────────────────────────────────┘
```

### 6.2 登录页面（独立完整页面，v3.1：改为手机号+密码体系）

**登录页（默认展示）**
```
┌────────────────────────────────────────────────────────┐
│                                                        │
│              🦫  欢迎回来钱小满                         │
│           让卡皮陪你记好每一笔                           │
│                                                        │
│  手机号                                                 │
│  ┌──────────────────────────────────────────────────┐  │
│  │  +86  │  13800138000                             │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  密码                                                   │
│  ┌──────────────────────────────────────────────────┐  │
│  │  ••••••••                                        │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │  登录                                            │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│              [忘记密码？]      [还没有账号？去注册]       │
│                                                        │
│  登录即代表同意《用户协议》和《隐私政策》                  │
│                                                        │
│              [暂不登录，继续游客使用]                    │
└────────────────────────────────────────────────────────┘
```

**注册页（点击"去注册"进入）**
```
┌────────────────────────────────────────────────────────┐
│              🦫  欢迎来到钱小满                         │
│                                                        │
│  手机号                                                 │
│  ┌──────────────────────────────────────────────────┐  │
│  │  +86  │  13800138000                             │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  验证码                              [发送验证码]       │
│  ┌──────────────────────────────────────────────────┐  │
│  │  ______                                          │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  设置密码                                               │
│  ┌──────────────────────────────────────────────────┐  │
│  │  ••••••••（至少8位，含字母+数字）                  │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │  注册                                            │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

**忘记密码页（点击"忘记密码"进入）**
```
┌────────────────────────────────────────────────────────┐
│              🦫  找回密码                               │
│                                                        │
│  手机号                                                 │
│  ┌──────────────────────────────────────────────────┐  │
│  │  +86  │  13800138000                             │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  验证码                              [发送验证码]       │
│  ┌──────────────────────────────────────────────────┐  │
│  │  ______                                          │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  设置新密码                                             │
│  ┌──────────────────────────────────────────────────┐  │
│  │  ••••••••                                        │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │  重置密码并登录                                    │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

> 三个独立流程：登录（手机号+密码，日常高频，无短信成本）、注册（手机号+验证码+设密码，验证手机真实性）、
> 忘记密码（手机号+验证码+设新密码，验证身份后允许重置）。只有注册和找回密码会用到短信。

### 6.3 登录后的数据迁移引导（v3.0：自动进行，无需用户选择）

> 因为迁移是登录流程里必须完成的一步（不迁移就无法安全切换到服务端模式），
> 不再设计成"是否同步"的二选一弹窗，而是登录后自动执行、展示进度即可。

```
登录成功
│
└─ 若本地有历史数据，展示进度提示（非阻断，可在后台完成，不允许中途取消）：
   ┌──────────────────────────────────────────────────┐
   │  🦫 正在关联 47 条历史数据...                     │
   │  ▓▓▓▓▓▓▓▓░░░░░░░░  60%                          │
   └──────────────────────────────────────────────────┘
   → 迁移完成后自动消失，用户可直接继续使用 App，无需等待
   → 若本地无历史数据（全新用户），跳过此步骤，直接进入 App
```

---

## 七、用户画像层说明（第二步规划）

### 存放位置
**同一个 MySQL 数据库，独立 `portrait_*` 表前缀，不新建数据库。**

理由：新建数据库会带来跨库 JOIN 的运维麻烦，且画像数据量不大，不需要独立扩容。

### 启动时机
当 server 端积累了至少 1000 个已登录用户、每人平均 30+ 条记录后，画像计算才有实际意义。

### 表结构（核心字段独立列，避免 JSON 查询性能陷阱）

```sql
-- 用户画像主表（定时批量计算写入，不实时写）
CREATE TABLE portrait_profiles (
    user_id              BIGINT PRIMARY KEY,
    updated_at           TIMESTAMP,

    -- 财务维度（频繁查询/筛选的指标独立为列，不放 JSON）
    avg_monthly_expense  DECIMAL(12, 2),    -- 月均支出
    saving_rate          DECIMAL(5, 4),     -- 储蓄率（0.00~1.00）
    budget_discipline    TINYINT,           -- 预算执行力评分 0-100
    record_active_days   INT,               -- 最近 90 天记账活跃天数

    -- 行为维度（核心指标）
    preferred_input      VARCHAR(20),       -- 'ai_voice' / 'manual' / 'photo'
    typical_record_hour  TINYINT,           -- 常见记账时间（小时，0-23）

    -- 扩展维度（不确定结构的未来字段放 JSON）
    extra_tags           JSON               -- 如 {"life_goals": [...], "personality": "节俭型"}
);

-- 画像变更日志（只追加，永不删除，可追溯历史）
CREATE TABLE portrait_change_logs (
    id           BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id      BIGINT,
    dimension    VARCHAR(50),    -- 如 'saving_rate'
    old_value    JSON,
    new_value    JSON,
    source_app   VARCHAR(20),    -- 'moneyfull' / 'lifecoach'
    computed_at  TIMESTAMP
);
```

### 计算方式
每天凌晨 2:00 运行服务端定时任务：

```
读取 mf_transactions（最近 90 天）
→ 计算各维度数值
→ UPSERT portrait_profiles（有则更新，无则插入）
→ APPEND portrait_change_logs（记录每次变化，永不删）

原则：
  原始数据表（mf_transactions）→ 只读，不改
  画像表（portrait_profiles）  → 覆盖写最新值
  变更日志                     → 只追加，永不删
```

---

## 八、数据安全边界

```
权限规则：

✅ moneyfull 服务端   →  读写 mf_* 表
✅ moneyfull 服务端   →  只读 portrait_profiles
✅ lifecoach 服务端   →  读写 lc_* 表
✅ lifecoach 服务端   →  只读 portrait_profiles

❌ moneyfull 服务端   →  禁止访问 lc_* 表
❌ lifecoach 服务端   →  禁止访问 mf_* 表
❌ 任何 App 服务端    →  禁止直接写 portrait_profiles（只有定时任务可写）
```

技术落地：MySQL 创建不同权限的 DB 连接账号，moneyfull 服务的账号物理上没有 `lc_*` 表的读权限。

---

## 九、迭代路线图

### 第一步（本次迭代，P0）
账号体系 + 手机号登录 + 数据上云

- [ ] 搭建服务端（推荐：阿里云 ECS + MySQL 8.0 + Node.js）
- [ ] 创建 `users` / `apps` / `user_app_memberships` / `user_sync_states` 表（含 `password_hash` 字段）
- [ ] 创建 `mf_projects` / `mf_transactions`（字段名为 `created_by_user_id`，含 version、is_deleted、server_updated_at）
- [ ] 【多人协作预留，见3.3/3.4节】创建 `mf_project_members` 表，`role` 字段不设默认值
- [ ] 【多人协作预留】`/sync/pull` 项目与流水查询现在就用 JOIN 写法实现（行为与单人模式一致，为后续铺路）
- [ ] 【多人协作预留】实现 `GET /projects/:id/members` 接口（供后续展示协作者头像/昵称，第一步可选先不接入客户端UI）
- [ ] 客户端 SwiftData 模型新增 `syncedToServer` 本地字段
- [ ] 【关键技术预研，优先级最高】验证 SwiftData 能否原地切换 `cloudKitDatabase: .none`（4.3/4.3.1节方式A），
      注意 SQLite 文件锁时序问题，若不可行需改用方式B（数据迁移到全新本地库）
- [ ] 实现登录迁移流程：读取本地数据 → 上传服务端（/sync/migrate，幂等 UPSERT）→ 缓冲监听30-60秒（注意规避通知回环）→ 关闭 CloudKit
- [ ] 实现「设置-重新检查本机历史数据」手动补救入口
- [ ] 实现退出登录流程（未同步检测 + 弹窗 + 清空本地 + 重新开启 CloudKit 回到游客模式）
- [ ] `NSPersistentStoreRemoteChange` 回调线程安全处理（后台 Context 处理数据，MainActor 处理 UI）
- [ ] 接入阿里云短信服务：注册 + 忘记密码流程用短信验证码（60秒间隔 + IP限流，不做图形验证码）
- [ ] 实现手机号+密码注册/登录/忘记密码三个流程（密码用 bcrypt 哈希存储）
- [ ] 实现「账号注销」功能（App Store 合规硬要求）
- [ ] 客户端：登录/注册/忘记密码页面 UI 开发
- [ ] 客户端：首页 & 个人中心登录引导条
- [ ] 客户端：「创建项目」触发登录 Sheet
- [ ] 实现增量同步接口（push/pull，含 version 冲突检测，删除操作确认 server_updated_at 同步更新）
- [ ] 更新隐私政策（明确告知用户数据上传服务器）

### 第二步（第一步稳定后，1-3 个月）
微信登录 + Apple 登录 + 画像启动

- [ ] 微信开放平台企业资质申请
- [ ] 接入微信 SDK（使用 unionid 作为跨 App 识别字段）
- [ ] 同步上线 Apple Sign In（与微信登录必须同期，否则违反 App Store 规定）
- [ ] AI 聊天记录上云（Agent 训练原料）
- [ ] 启动 portrait_profiles 定时计算任务

### 第三步（3-6 个月后）
人生教练 App 接入 + 生态打通

- [ ] 人生教练 App 接入统一账号（复用 users 表，通过 wechat_unionid 识别同一用户）
- [ ] portrait_profiles 新增 life_goals 维度
- [ ] 跨 App 洞察计算上线

### 第四步（远期）
专属 Agent

- [ ] agent_memories 表（AI 记住用户偏好）
- [ ] cross_app_insights 表（跨 App 统一洞察）
- [ ] Agent 主动调取画像，做个性化建议

### 独立功能（数据库已就绪，可插入到任意阶段之间开发）
多人协作记账 —— 由于 3.3/3.4 节已在第一步预留好表结构，这个功能不依赖上面几个阶段的顺序，
可以根据业务优先级随时插入开发，纯粹是新增业务逻辑，不涉及数据迁移：

- [ ] 邀请码/邀请链接生成与核销接口
- [ ] 客户端：项目详情页展示协作者头像列表（调用 `GET /projects/:id/members`）
- [ ] 客户端：流水列表按 `created_by_user_id` 匹配显示对应记账人头像/昵称
- [ ] 服务端：写入流水/项目时校验 `mf_project_members` 权限（是否有权限记账/编辑）
- [ ] 协作相关的推送通知（如"张三记了一笔账"）

---

## 十、待决策问题（已确认）

| 编号 | 问题 | 最终决策 |
|------|------|---------|
| Q1 | 服务端技术栈选型？ | 与现有技术栈保持一致，或选简单易维护的方案即可，定为 **Node.js + Express + MySQL 8.0** |
| Q2 | 登录时的一次性迁移，是否允许用户中途取消？ | **不允许中途取消**，迁移过程静默完成 |
| Q3 | 登录迁移期间是否展示进度 UI？ | **展示**，文案为"正在关联 N 条历史数据"进度条（已更新至 6.3 节） |
| Q4 | 多设备修改冲突时，是否弹窗让用户选择？ | **不弹窗，自动取最新 server 版本**（已更新至 5.4 场景A，简化为静默覆盖） |
| Q5 | 4.3节技术方式A（原地切换 cloudKitDatabase 配置）是否可行？ | **确认可行**，按方式A实现，开发时仍需实测验证细节 |
| Q6 | 第一步是否接入微信登录？ | **不接入**，第一步只做手机号登录，微信登录推迟到第二步（与文档二、三节的既定安排一致） |
