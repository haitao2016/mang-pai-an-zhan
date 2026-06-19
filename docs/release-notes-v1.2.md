# 盲拍暗战 v1.2.0 发布说明

> 版本代号：**竞技盛典 (Apex Tournament)**
> 发布日期：2026-07-19
> 代码库：`/workspace`

---

## 一、版本概述

**v1.2.0 是「盲拍暗战」的第三个主要版本更新**，聚焦于三大核心主题：

1. 🏆 **竞技深度**：锦标赛系统 + 团队战，提供丰富的多人对战体验
2. 💰 **经济闭环**：交易市场 + 皮肤系统，构建完整的藏品经济生态
3. 🔗 **系统集成**：统一的事件总线 + 系统管理器，保证各系统协同工作

---

## 二、核心特性一览

| 模块 | 功能 | 状态 |
|------|------|------|
| 🏆 锦标赛系统 | 单败淘汰制 / 8-16人参赛 / 奖励发放 | ✅ 已完成 |
| 👥 团队战系统 | 2v2组队 / 共享资金池 / 团队技能 | ✅ 已完成 |
| 🛒 交易市场 | 挂单/购买/取消 / 黑名单管理 / 市场统计 | ✅ 已完成 |
| 🎨 皮肤系统 | 5种稀有度 / 皮肤套装 / 装备管理 | ✅ 已完成 |
| 🔗 系统集成 | EventBus事件总线 / SystemManager统一管理 | ✅ 已完成 |
| 🧪 测试覆盖 | 12个测试文件 / 70+测试用例 | ✅ 已完成 |

---

## 三、新增核心系统详解

### 3.1 锦标赛系统（TournamentSystem）
**文件位置**：`scripts/Game/TournamentSystem.lua`

**核心机制：**
- 🏁 **赛制**：单败淘汰制，支持 8 人或 16 人参赛
- 📊 **对阵生成**：Fisher-Yates 洗牌算法，保证公平随机
- 🏆 **奖励机制**：冠军 / 亚军 / 四强阶梯奖励
- 📝 **历史记录**：追踪每个玩家的锦标赛参与轨迹

**关键 API：**
```lua
TournamentSystem.CreateTournament(options)    -- 创建锦标赛
TournamentSystem.Register(tournamentId, uid)   -- 报名
TournamentSystem.SubmitMatchResult(tournamentId, matchId, winner)  -- 提交结果
TournamentSystem.GetAvailableTournaments(uid)  -- 获取可参加锦标赛
TournamentSystem.GetPlayerHistory(uid)          -- 获取玩家历史
```

---

### 3.2 团队战系统（TeamBattleSystem）
**文件位置**：`scripts/Game/TeamBattleSystem.lua`

**核心机制：**
- 👥 **组队系统**：创建团队 / 邀请加入 / 离开团队
- 🎮 **团队对战**：红队 vs 蓝队，2v2 协作模式
- 💰 **共享资金池**：团队成员共同决策出价
- ⚡ **团队技能**：激励（全员出价+10%）/ 护盾（免疫无效出价）/ 洞察（预测对手总出价）
- 📈 **团队排行**：积分排名，团队荣誉系统

**关键 API：**
```lua
TeamBattleSystem.CreateTeam(captainUid, options)   -- 创建团队
TeamBattleSystem.JoinTeam(teamId, uid)               -- 加入团队
TeamBattleSystem.StartMatch(matchId)                  -- 开始团队战
TeamBattleSystem.SubmitTeamBid(matchId, uid, bid)     -- 提交团队出价
TeamBattleSystem.UseTeamSkill(matchId, uid, skillId)  -- 使用团队技能
TeamBattleSystem.GetTeamLeaderboard(limit)             -- 获取团队排行榜
```

---

### 3.3 交易市场系统（TradeSystem）
**文件位置**：`scripts/Game/TradeSystem.lua`

**核心机制：**
- 🏷️ **挂单出售**：设置价格，支持 10 - 1000000 金币范围
- 🛒 **直接购买**：一键购买，5% 交易手续费
- 🔒 **安全机制**：黑名单系统，屏蔽可疑卖家
- 📊 **市场统计**：在售数量 / 成交数量 / 平均价格
- ⏱️ **自动下架**：7 天未售出自动过期

**关键 API：**
```lua
TradeSystem.CreateListing(sellerUid, itemId, itemData, price)  -- 创建挂单
TradeSystem.Purchase(buyerUid, listingId)                       -- 购买藏品
TradeSystem.CancelListing(uid, listingId)                       -- 取消挂单
TradeSystem.GetMarketList(filter)                                -- 获取市场列表
TradeSystem.GetTradeHistory(uid)                                 -- 获取交易历史
TradeSystem.BlockPlayer(uid, blockedUid)                        -- 拉黑玩家
```

---

### 3.4 皮肤系统（SkinSystem）
**文件位置**：`scripts/Game/SkinSystem.lua`

**核心机制：**
- 🎨 **5 种稀有度**：普通 / 稀有 / 史诗 / 传说 / 独占
- 👤 **角色独立**：每个角色拥有独立的皮肤池
- 🎁 **套装系统**：集齐特定套装解锁额外奖励
- 🔧 **装备管理**：一键装备 / 卸下 / 预览

**稀有度分布：**

| 稀有度 | 颜色 | 获取方式 | 示例 |
|--------|------|---------|------|
| 普通 | 白色 | 成就解锁 | 经典款式 |
| 稀有 | 蓝色 | 活动任务 | 节日限定 |
| 史诗 | 紫色 | 商城购买 | 精英战士 |
| 传说 | 金色 | 限定时间 | 传奇王者 |
| 独占 | 红色 | 赛季/充值 | 至尊典藏 |

**关键 API：**
```lua
SkinSystem.GetSkinsForCharacter(characterId)  -- 获取角色皮肤列表
SkinSystem.UnlockSkin(uid, skinId, reason)    -- 解锁皮肤
SkinSystem.EquipSkin(uid, characterId, skinId)  -- 装备皮肤
SkinSystem.ClaimSetReward(uid, setId)           -- 领取套装奖励
SkinSystem.GetPlayerStats(uid)                  -- 获取玩家皮肤统计
```

---

## 四、系统架构升级

### 4.1 EventBus 事件总线扩展
**文件位置**：`scripts/Utils/EventBus.lua`

**事件总数扩展**：
- v1.0: 10+ 个基础事件
- v1.1: 20+ 个游戏事件
- v1.2: **35 个标准事件**（新增 15 个）

**v1.2 新增事件：**

| 分类 | 事件名称 | 用途 |
|------|---------|------|
| 🏆 锦标赛 | `TOURNAMENT_START` | 锦标赛开始 |
| | `TOURNAMENT_END` | 锦标赛结束 |
| | `TOURNAMENT_WIN` | 玩家获得名次 |
| | `TOURNAMENT_REGISTER` | 玩家报名 |
| | `TOURNAMENT_MATCH_RESULT` | 比赛结果提交 |
| 👥 团队战 | `TEAM_CREATE` | 创建团队 |
| | `TEAM_JOIN` | 加入团队 |
| | `TEAM_LEAVE` | 离开团队 |
| | `TEAM_START` | 团队战开始 |
| | `TEAM_WIN` | 团队战胜利 |
| | `TEAM_SKILL_USE` | 使用团队技能 |
| 🛒 交易市场 | `TRADE_LISTING` | 挂单上架 |
| | `TRADE_PURCHASE` | 购买完成 |
| | `TRADE_CANCEL` | 取消挂单 |
| | `TRADE_BLOCK` | 拉黑玩家 |
| 🎨 皮肤系统 | `SKIN_UNLOCK` | 皮肤解锁 |
| | `SKIN_EQUIP` | 装备皮肤 |
| | `SKIN_SET_COMPLETE` | 套装完成 |

---

### 4.2 SystemManager 系统管理器
**文件位置**：`scripts/Game/SystemManager.lua`

**核心功能：**
- 🔄 **统一初始化**：按优先级顺序加载所有系统
- 🔗 **事件集成**：统一注册所有系统的事件监听器
- 🔍 **状态追踪**：实时监控各系统的初始化和运行状态
- 🔧 **控制接口**：提供 Init / Start / Reset / GetSystem 等接口

**系统优先级：**

| 优先级 | 系统组 | 包含模块 |
|--------|--------|---------|
| 1 | 核心系统 | EventBus, Config |
| 10 | v1.1 游戏系统 | SeasonSystem, FriendSystem, LeaderboardSystem, ProfileSystem, ItemSetSystem, EventModeSystem, RoomSystem |
| 20 | v1.2 新系统 | TournamentSystem, TeamBattleSystem, TradeSystem, SkinSystem |

---

## 五、系统间集成与联动

### 5.1 锦标赛 → 赛季系统
- 🏆 锦标赛胜利 → `SEASON_PROGRESS`（+50 XP）
- 🥈 锦标赛亚军 → `SEASON_PROGRESS`（+20 XP）
- 📋 参赛成就 → `ACHIEVEMENT_UNLOCK`（特定成就）

### 5.2 团队战 → 赛季系统
- 👥 团队战胜利 → `SEASON_PROGRESS`（+30 XP，每位成员）
- ⚡ 团队技能使用 → 成就进度更新
- 📈 团队积分排名 → 每月赛季奖励

### 5.3 交易市场 → 藏品系统
- 🛒 购买藏品 → `ITEM_COLLECT`（触发收藏统计）
- 📊 市场交易 → 更新玩家藏品收藏率
- 🏆 稀有藏品交易 → `ACHIEVEMENT_UNLOCK`（成就解锁）

### 5.4 皮肤系统 → 赛季系统
- 🎨 皮肤套装完成 → `SEASON_PROGRESS`（+80 XP）
- 🏅 稀有皮肤解锁 → `ACHIEVEMENT_UNLOCK`（皮肤收藏家）

---

## 六、UI/UX 面板入口

### 6.1 大厅导航更新
**文件位置**：`scripts/UI/GameUI.lua`

| 导航项 | 功能 | 面板函数 |
|--------|------|---------|
| 🏛️ 收藏馆 | 查看/管理藏品 | `_ShowCollection()` |
| 🏆 锦标赛 | 报名/参赛/查看结果 | `_ShowTournament()` |
| 👥 团队战 | 创建/加入团队 | `_ShowTeamBattle()` |
| 🛒 市场 | 浏览/交易藏品 | `_ShowTradeMarket()` |
| 🎨 皮肤 | 购买/装备角色皮肤 | `_ShowSkinShop()` |

### 6.2 底部快捷栏
- 一键访问所有 v1.2 新功能
- 实时显示各系统通知（如：锦标赛即将开始）
- 与 v1.1 的赛季/好友面板无缝切换

---

## 七、测试覆盖报告

### 7.1 测试文件清单

| 测试文件 | 用例数 | 覆盖系统 | 版本 |
|---------|--------|---------|------|
| `TestTournamentSystem.lua` | 10 | 锦标赛创建/报名/对阵/奖励 | v1.2 |
| `TestTeamBattleSystem.lua` | 10 | 团队创建/匹配/出价/技能 | v1.2 |
| `TestTradeSystem.lua` | 12 | 挂单/购买/取消/黑名单/统计 | v1.2 |
| `TestSkinSystem.lua` | 11 | 解锁/购买/装备/套装/统计 | v1.2 |
| `TestIntegration.lua` | 12 | 系统集成/事件传播/生命周期 | v1.2 |
| `TestSeasonSystem.lua` | 9 | 赛季进度/等级/奖励 | v1.1 |
| `TestFriendSystem.lua` | 12 | 好友系统完整功能 | v1.1 |
| `TestEventBus.lua` | 11 | 事件发布/订阅/历史 | v1.1 |
| `TestRoomSystem.lua` | 10 | 自定义房间功能 | v1.1 |
| `TestItemSetSystem.lua` | 10 | 套装收集机制 | v1.1 |

**总测试用例数：107+**

---

## 八、配置文件更新

### 8.1 Config.lua v1.2.0
**新增配置节点：**

| 配置节点 | 用途 |
|---------|------|
| `Config.Tournament` | 锦标赛参数（人数/奖励/规则） |
| `Config.TeamBattle` | 团队战参数（技能/匹配/排行） |
| `Config.Trade` | 市场参数（手续费/价格范围/过期） |
| `Config.Skins` | 皮肤参数（皮肤列表/稀有度/套装） |
| `Config.SkinSets` | 皮肤套装定义（套装成员/奖励） |

---

## 九、数据迁移与兼容

### 9.1 v1.1 → v1.2 迁移策略
- ✅ **玩家数据保留**：藏品、金币、成就全部保留
- ✅ **赛季数据保留**：赛季进度/等级无缝延续
- ✅ **好友列表保留**：社交关系完整迁移
- ✅ **v1.2 新系统从零开始**：锦标赛/团队战/市场/皮肤不依赖历史数据

### 9.2 兼容性保证
- 所有 v1.1 API 保持不变（向后兼容）
- 新增系统仅提供新增 API，不修改现有接口
- 事件系统完全兼容，旧事件监听器继续生效

---

## 十、与 v1.1 对比总结

| 维度 | v1.1.0 | v1.2.0 | 变化 |
|------|--------|--------|------|
| 核心系统 | 7 个 | **11 个** | +4 |
| 系统代码 | ~6000 行 | **~10000 行** | +67% |
| EventBus 事件 | 20 | **35** | +15 |
| 游戏模式 | 2 种 | **4 种** | +2 |
| 测试文件 | 7 | **12** | +5 |
| 测试用例 | ~60 | **107+** | +78% |
| 大厅导航项 | 5 | **9** | +4 |

---

## 十一、v1.3 前瞻规划

以下功能正在规划中，预计 v1.3 版本发布：

| 功能 | 描述 | 状态 |
|------|------|------|
| 公会系统 | 创建公会 / 公会战 / 公会商店 | 规划中 |
| 跨服锦标赛 | 多服务器玩家互通对战 | 规划中 |
| 语音聊天 | 房间内语音沟通 | 规划中 |
| 自定义外观 | 更丰富的角色个性化 | 规划中 |
| 故事模式 | 单人剧情体验 | 规划中 |

---

## 十二、技术栈与开发工具

### 12.1 核心技术
- **引擎**：UrhoX
- **脚本语言**：Lua 5.4
- **网络模型**：match_info 房间制
- **事件系统**：发布-订阅模式（EventBus）
- **持久化**：serverCloud 云端存储

### 12.2 项目结构
```
/workspace/
├── scripts/
│   ├── Game/                 # 18 个游戏系统
│   │   ├── TournamentSystem.lua     # v1.2 新增
│   │   ├── TeamBattleSystem.lua     # v1.2 新增
│   │   ├── TradeSystem.lua          # v1.2 新增
│   │   ├── SkinSystem.lua           # v1.2 新增
│   │   ├── SystemManager.lua        # v1.2 新增
│   │   └── ...
│   ├── Utils/                # 7 个工具模块
│   │   ├── EventBus.lua              # v1.2 扩展
│   │   └── ...
│   ├── UI/                   # 界面相关
│   │   └── GameUI.lua                # v1.2 更新
│   └── tests/               # 16 个测试文件
│       ├── TestTournamentSystem.lua  # v1.2 新增
│       ├── TestTeamBattleSystem.lua  # v1.2 新增
│       ├── TestTradeSystem.lua       # v1.2 新增
│       ├── TestSkinSystem.lua        # v1.2 新增
│       ├── TestIntegration.lua        # v1.2 新增
│       └── ...
├── docs/                    # 文档
│   ├── dev-plan.md                 # 开发计划
│   ├── update-plan-v1.1.md         # v1.1 更新计划
│   ├── update-plan-v1.2.md         # v1.2 更新计划
│   └── release-notes-v1.2.md       # v1.2 发布说明
└── .project/
    └── project.json                # TapTap 发布配置 v1.2.0
```

---

## 十三、已知问题与未来改进

### 13.1 当前限制
- 团队战目前仅支持 2v2，4v4 模式规划中
- 锦标赛目前仅支持单败淘汰，双败淘汰规划中
- 市场拍卖模式（竞价）规划中，当前仅支持一口价
- 皮肤系统美术资源需要后续补充

### 13.2 性能优化方向
- 市场列表大数据量滚动优化（虚拟列表）
- 多人房间连接稳定性优化
- 皮肤预览动画性能调优

---

> **文档版本**：v1.2.0-release
> **最后更新**：2026-07-19
> **维护者**：盲拍暗战开发团队
