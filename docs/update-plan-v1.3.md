# 《盲拍暗战》v1.3.0 开发计划

> 版本代号：**公会崛起 (Guild Rising)**
> 目标发布日期：2026-08-19
> 预计开发周期：4 周（2026-07-20 ~ 2026-08-19）

---

## 一、版本核心目标

### 1.1 社交深度提升（重点）
- 🏛️ **公会系统**：创建公会 / 公会等级 / 公会战 / 公会商店
- 🤝 **玩家互动**：私聊 / 表情 / 快捷消息
- 📊 **公会排行**：活跃排行 / 战力排行 / 财富排行

### 1.2 内容扩展
- 🏆 **跨服锦标赛**：多服务器玩家互通对战
- 🎖️ **成就系统扩展**：成就等级 / 隐藏成就 / 成就统计
- 💎 **装备系统**：角色装备 / 装备属性 / 装备强化

### 1.3 测试补全
- ✅ **补全缺失测试**：6 个核心系统的单元测试
- 🔗 **更多集成测试**：系统间协同验证
- 🐛 **回归测试**：确保 v1.0-v1.2 系统稳定性

---

## 二、现有系统缺口分析

### 2.1 系统清单与状态

| 模块 | 文件 | 状态 | 优先级 |
|------|------|------|--------|
| AI 玩家 | AIPlayer.lua | ✅ 完整 | 低 |
| 拍卖管理器 | AuctionManager.lua | ✅ 完整 | 低 |
| 出价系统 | BidSystem.lua | ✅ 完整 | 低 |
| 角色系统 | CharacterSystem.lua | ✅ 基本完整 | 中 |
| 揭秘系统 | RevealSystem.lua | ✅ 完整 | 低 |
| 回合管理 | RoundManager.lua | ✅ 完整 | 低 |
| 玩家数据 | PlayerDataManager.lua | ✅ 基本完整 | 中 |
| 藏品池 | ItemPool.lua | ✅ 完整 | 低 |
| 套装系统 | ItemSetSystem.lua | ✅ 完整 | 低 |
| 成就系统 | AchievementSystem.lua | ⚠️ 基础 | **高** |
| 每日任务 | DailyMissionSystem.lua | ⚠️ 基础 | **高** |
| 赛季系统 | SeasonSystem.lua | ✅ 完整 | 低 |
| 好友系统 | FriendSystem.lua | ✅ 完整 | 低 |
| 排行榜 | LeaderboardSystem.lua | ⚠️ 基础 | **高** |
| 个性化 | ProfileSystem.lua | ⚠️ 基础 | **高** |
| 限时活动 | EventModeSystem.lua | ⚠️ 基础 | **高** |
| 自定义房间 | RoomSystem.lua | ✅ 完整 | 低 |
| 锦标赛 | TournamentSystem.lua | ✅ v1.2 | 中 |
| 团队战 | TeamBattleSystem.lua | ✅ v1.2 | 中 |
| 交易市场 | TradeSystem.lua | ✅ v1.2 | 中 |
| 皮肤系统 | SkinSystem.lua | ✅ v1.2 | 低 |
| 系统管理器 | SystemManager.lua | ✅ v1.2 | 低 |
| **公会系统** | **GuildSystem.lua** | ❌ **缺失** | **极高** |
| **装备系统** | **EquipmentSystem.lua** | ❌ **缺失** | **高** |
| **跨服锦标赛** | **CrossServerTournament** | ❌ **缺失** | **中** |

### 2.2 测试文件覆盖缺口

| 系统 | 是否有测试 | 状态 |
|------|-----------|------|
| AchievementSystem | ❌ 无 | 需创建 |
| DailyMissionSystem | ❌ 无 | 需创建 |
| ProfileSystem | ❌ 无 | 需创建 |
| LeaderboardSystem | ❌ 无 | 需创建 |
| EventModeSystem | ❌ 无 | 需创建 |
| SystemManager | ❌ 无 | 需创建 |
| PlayerDataManager | ❌ 无 | 需创建 |

---

## 三、详细功能清单（按优先级）

### 🔴 第 1 周：高优先级功能（核心系统）

#### 功能 3.1 — 公会系统（Guild System）
**需求说明**：
- 玩家可以创建公会（需要 5000 金币）
- 公会等级系统（1-10 级，成员越多升级越快）
- 公会成员管理（邀请/踢出/权限管理）
- 公会贡献值系统（参与公会战获得）
- 公会商店（使用贡献值兑换专属道具）
- 公会聊天室（公会成员内部沟通）
- 公会战（公会 vs 公会的团队战）

**功能拆解**：

1. **公会核心管理**
   ```lua
   GuildSystem.CreateGuild(leaderUid, name, description)
   GuildSystem.JoinGuild(guildId, uid)
   GuildSystem.LeaveGuild(uid)
   GuildSystem.InviteMember(guildId, inviterUid, targetUid)
   GuildSystem.KickMember(guildId, kickerUid, targetUid)
   GuildSystem.GetGuildInfo(guildId)
   GuildSystem.GetPlayerGuild(uid)
   GuildSystem.GetGuildList(filter, limit)  -- 搜索/浏览公会
   ```

2. **公会等级与贡献**
   ```lua
   GuildSystem.AddContribution(guildId, uid, amount, reason)
   GuildSystem.GetContribution(guildId, uid)
   GuildSystem.GetGuildLevel(guildId)
   GuildSystem.UpgradeGuild(guildId)
   ```

3. **公会战系统**
   ```lua
   GuildSystem.StartGuildWar(guild1Id, guild2Id)
   GuildSystem.SubmitGuildWarResult(matchId, winnerGuildId)
   GuildSystem.GetGuildWarHistory(guildId, limit)
   ```

4. **公会商店**
   ```lua
   GuildSystem.GetGuildShopItems(guildId)
   GuildSystem.PurchaseShopItem(guildId, uid, itemId)
   ```

5. **EventBus 事件**
   ```
   GUILD_CREATE, GUILD_JOIN, GUILD_LEAVE,
   GUILD_WAR_START, GUILD_WAR_END,
   GUILD_CONTRIBUTION_UPDATE, GUILD_LEVEL_UP
   ```

**依赖项**：PlayerDataManager.lua, TeamBattleSystem.lua, EventBus.lua
**预计工作量**：**5 天**（250 行代码）

---

#### 功能 3.2 — 成就系统扩展（Achievement System Expansion）
**需求说明**：
- 当前只有简单的 achievement_unlock 事件
- 新增成就等级（铜/银/金/铂金/钻石 5 级）
- 新增成就类别（竞技/社交/收集/经济/特殊）
- 新增隐藏成就（达成后才显示）
- 成就统计（总完成度/稀有成就数）
- 成就奖励（解锁时发放金币/经验/专属徽章）

**功能拆解**：

1. **成就定义扩展**
   ```lua
   -- 成就等级：1=铜, 2=银, 3=金, 4=铂金, 5=钻石
   -- 成就类别：competition, social, collection, economy, special
   -- 隐藏属性：isHidden (bool)
   -- 奖励配置：goldReward, xpReward, badgeRewardId

   AchievementSystem.GetAchievementCategories()
   AchievementSystem.GetAchievementsByCategory(category, limit)
   AchievementSystem.GetPlayerProgressByCategory(uid, category)
   ```

2. **隐藏成就**
   ```lua
   AchievementSystem.GetVisibleAchievements(uid)  -- 不含未解锁的隐藏成就
   AchievementSystem.UnlockHiddenAchievement(uid, achievementId)
   ```

3. **成就统计**
   ```lua
   AchievementSystem.GetPlayerStats(uid)
   -- 返回：totalUnlocked, byLevel, byCategory, completionRate
   AchievementSystem.GetRareAchievementCount(uid)
   ```

4. **成就奖励**
   ```lua
   AchievementSystem.ClaimReward(uid, achievementId)
   AchievementSystem.GetUnclaimedRewards(uid)
   ```

**依赖项**：PlayerDataManager.lua, EventBus.lua
**预计工作量**：**3 天**（180 行代码）

---

#### 功能 3.3 — 补全核心测试文件
**需求说明**：为 7 个尚未有测试文件的系统创建单元测试

**测试文件清单**：

1. **TestAchievementSystem.lua**（10 个用例）
   - 成就解锁/检查
   - 按类别获取成就
   - 成就进度统计
   - 成就奖励领取

2. **TestDailyMissionSystem.lua**（10 个用例）
   - 每日任务刷新
   - 任务进度更新
   - 任务奖励领取
   - 连续登录奖励

3. **TestProfileSystem.lua**（8 个用例）
   - 玩家资料获取/更新
   - 称号系统
   - 头像切换
   - 个性化设置

4. **TestLeaderboardSystem.lua**（10 个用例）
   - 排行榜更新
   - 多类型排行榜（胜场/藏品/财富）
   - 自己排名高亮
   - 周榜/月榜切换

5. **TestEventModeSystem.lua**（8 个用例）
   - 活动模式开关
   - 活动奖励发放
   - 限时模式规则验证

6. **TestSystemManager.lua**（8 个用例）
   - 系统初始化测试
   - 系统启动/关闭
   - 系统实例获取
   - 生命周期管理

7. **TestPlayerDataManager.lua**（10 个用例）
   - 玩家数据存储/读取
   - 数据持久化测试
   - 金币/余额更新

**预计工作量**：**3 天**（共 64 个测试用例）

---

### 🟡 第 2 周：中优先级功能（内容扩展）

#### 功能 3.4 — 装备系统（Equipment System）
**需求说明**：
- 角色装备栏（武器/防具/饰品/徽章 4 个槽位）
- 装备属性加成（攻击力/防御力/特殊效果）
- 装备稀有度（普通/稀有/史诗/传说/独占）
- 装备强化（消耗金币提升属性）
- 装备获取（开箱/活动/商店/公会贡献）

**功能拆解**：

1. **装备数据模型**
   ```lua
   Equipment = {
       id = "eq_001",
       name = "出价匕首",
       type = "weapon",        -- weapon, armor, accessory, badge
       rarity = 3,             -- 1-5 稀有度
       characterId = 1,        -- 适用角色 (nil=通用)
       stats = {
           attackBonus = 10,   -- 出价时金币+10%
           defenseBonus = 5,   -- 防守时减免5%
           specialEffect = "critical_hit"  -- 特殊效果ID
       },
       level = 1,              -- 强化等级
       maxLevel = 10
   }
   ```

2. **装备管理 API**
   ```lua
   EquipmentSystem.GetEquipmentsForCharacter(characterId)
   EquipmentSystem.GetPlayerEquipments(uid)
   EquipmentSystem.EquipItem(uid, characterId, slot, equipmentId)
   EquipmentSystem.UnequipItem(uid, characterId, slot)
   EquipmentSystem.GetEquippedItems(uid, characterId)
   ```

3. **装备强化系统**
   ```lua
   EquipmentSystem.UpgradeEquipment(uid, equipmentId)
   EquipmentSystem.GetUpgradeCost(equipmentId, currentLevel)
   ```

4. **属性计算**
   ```lua
   EquipmentSystem.CalculateTotalStats(uid, characterId)
   -- 返回：总攻击加成/总防御加成/总特殊效果
   ```

5. **EventBus 事件**
   ```
   EQUIPMENT_UNLOCK, EQUIPMENT_EQUIP, EQUIPMENT_UPGRADE
   ```

**依赖项**：PlayerDataManager.lua, CharacterSystem.lua, ItemPool.lua
**预计工作量**：**4 天**（220 行代码）

---

#### 功能 3.5 — 每日任务系统扩展 + 周任务
**需求说明**：
- 当前仅有每日任务，扩展为：每日任务 + 周任务 + 月任务
- 任务类型扩展：竞技/收集/社交/经济/特殊
- 任务重置机制（每日 0:00 / 每周一 0:00 / 每月 1 日）
- 活跃度系统：完成一定数量任务后获得额外奖励
- 连续登录奖励（3 天/7 天/15 天/30 天）

**功能拆解**：

1. **任务配置扩展**
   ```lua
   Config.Missions = {
       daily = { ... },
       weekly = { ... },
       monthly = { ... },
       continuous = {
           days3 = { reward = ... },
           days7 = { reward = ... },
           days15 = { reward = ... },
           days30 = { reward = ... }
       }
   }
   ```

2. **任务 API**
   ```lua
   DailyMissionSystem.GetDailyMissions(uid)
   DailyMissionSystem.GetWeeklyMissions(uid)
   DailyMissionSystem.GetMonthlyMissions(uid)
   DailyMissionSystem.UpdateMissionProgress(uid, missionId, progress)
   DailyMissionSystem.ClaimMissionReward(uid, missionId)
   DailyMissionSystem.CheckReset(uid)  -- 检查是否需要重置
   ```

3. **活跃度系统**
   ```lua
   DailyMissionSystem.GetActivityPoints(uid)
   DailyMissionSystem.ClaimActivityReward(uid, threshold)
   -- 活跃度阈值：20/40/60/80/100 点
   ```

4. **连续登录奖励**
   ```lua
   DailyMissionSystem.GetContinuousLoginDays(uid)
   DailyMissionSystem.ClaimContinuousReward(uid, days)
   ```

**依赖项**：PlayerDataManager.lua, EventBus.lua
**预计工作量**：**3 天**（180 行代码）

---

### 🟢 第 3 周：中低优先级功能（体验优化）

#### 功能 3.6 — 排行榜系统扩展（Leaderboard Expansion）
**需求说明**：
- 多类型排行榜：胜场榜 / 藏品价值榜 / 财富榜 / 公会战力榜
- 周榜 / 月榜切换
- 自己排名高亮显示
- 排行榜奖励（每周一发放）
- Top 10 玩家展示

**功能拆解**：

1. **多榜支持**
   ```lua
   LeaderboardSystem.GetLeaderboard(type, period, limit)
   -- type: "wins", "item_value", "wealth", "guild_power"
   -- period: "weekly", "monthly", "all_time"
   ```

2. **个人排名高亮**
   ```lua
   LeaderboardSystem.GetPlayerRank(uid, type, period)
   LeaderboardSystem.GetPlayerRankWithNeighbors(uid, type, period, neighborCount)
   ```

3. **排行榜奖励**
   ```lua
   LeaderboardSystem.GetRankRewards(type, period)
   LeaderboardSystem.ClaimRankReward(uid, type, period)
   ```

4. **Top 10 展示**
   ```lua
   LeaderboardSystem.GetTop10(type, period)
   ```

**依赖项**：PlayerDataManager.lua, EventBus.lua, GuildSystem.lua
**预计工作量**：**3 天**（150 行代码）

---

#### 功能 3.7 — 个性化系统扩展（Profile Expansion）
**需求说明**：
- 个人资料卡片完善（头像框 / 称号 / 徽章）
- 玩家签名 / 心情状态
- 对战记录统计（总场次/胜率/最佳战绩）
- 收藏展示（稀有藏品展示）
- 隐私设置（隐藏余额/隐藏对战记录）

**功能拆解**：

1. **资料卡 API**
   ```lua
   ProfileSystem.GetPlayerProfile(uid)
   ProfileSystem.UpdateProfile(uid, profileData)
   ProfileSystem.SetAvatarFrame(uid, frameId)
   ProfileSystem.SetTitle(uid, titleId)
   ProfileSystem.SetBadge(uid, badgeId, position)  -- badge1/badge2/badge3
   ProfileSystem.SetSignature(uid, text)
   ProfileSystem.SetMood(uid, mood)
   ```

2. **对战统计**
   ```lua
   ProfileSystem.GetBattleStats(uid)
   -- 返回：totalGames, wins, losses, winRate, bestRank, favoriteCharacter
   ```

3. **隐私设置**
   ```lua
   ProfileSystem.GetPrivacySettings(uid)
   ProfileSystem.UpdatePrivacySettings(uid, settings)
   -- settings: { hideBalance, hideBattleRecord, hideInventory }
   ```

4. **收藏展示**
   ```lua
   ProfileSystem.GetFeaturedItems(uid)
   ProfileSystem.SetFeaturedItem(uid, itemId, position)
   ```

**依赖项**：PlayerDataManager.lua, ItemPool.lua, AchievementSystem.lua
**预计工作量**：**3 天**（160 行代码）

---

#### 功能 3.8 — UI/UX 大版本优化
**需求说明**：
- 公会面板（创建/搜索/管理/公会战）
- 装备面板（装备管理/强化/属性查看）
- 成就面板扩展（分类/隐藏成就/统计）
- 任务面板（每日/每周/每月/活跃度）
- 排行榜新 UI（多榜切换/高亮自己）
- 个人资料卡片

**功能拆解**：

1. **新面板函数（GameUI.lua 扩展）**
   ```lua
   GameUI._ShowGuild()          -- 公会主面板
   GameUI._ShowEquipment()       -- 装备管理面板
   GameUI._ShowAchievements()    -- 成就面板
   GameUI._ShowMissions()        -- 任务面板
   GameUI._ShowLeaderboards()    -- 排行榜面板
   GameUI._ShowProfileCard()     -- 资料卡片
   ```

2. **大厅导航更新**
   - 新增公会入口 🏛️
   - 新增装备入口 ⚔️
   - 重新排列菜单顺序

3. **动画优化**
   - 公会创建动画
   - 装备强化成功特效
   - 成就解锁全屏弹窗
   - 排行榜切换动画

**预计工作量**：**3 天**

---

### 🟢 第 4 周：系统集成 + 测试 + 发布准备

#### 功能 3.9 — EventBus + SystemManager 扩展
**需求说明**：
- 为所有 v1.3 新系统添加标准事件
- 扩展系统管理器的系统注册表
- 事件链测试和调试工具

**新增 EventBus 事件**：
```lua
EventBus.Events = {
    -- ... 保留 v1.2 全部 35 个事件 ...

    -- 公会系统（v1.3, +7）
    GUILD_CREATE,           -- 公会创建
    GUILD_JOIN,             -- 加入公会
    GUILD_LEAVE,            -- 离开公会
    GUILD_WAR_START,        -- 公会战开始
    GUILD_WAR_END,          -- 公会战结束
    GUILD_CONTRIBUTION,     -- 贡献值更新
    GUILD_LEVEL_UP,         -- 公会升级

    -- 装备系统（v1.3, +4）
    EQUIPMENT_UNLOCK,       -- 解锁装备
    EQUIPMENT_EQUIP,        -- 装备穿戴
    EQUIPMENT_UPGRADE,      -- 装备强化
    EQUIPMENT_SET_COMPLETE, -- 装备套装完成

    -- 任务扩展（v1.3, +3）
    WEEKLY_MISSION_COMPLETE,  -- 周任务完成
    ACTIVITY_POINT_UPDATE,    -- 活跃度更新
    CONTINUOUS_LOGIN_REWARD,  -- 连续登录奖励

    -- 总计：35 + 14 = 49 个标准事件
}
```

**依赖项**：EventBus.lua, SystemManager.lua
**预计工作量**：**2 天**

---

#### 功能 3.10 — 集成测试 + 回归测试
**需求说明**：
- 创建完整的系统间集成测试
- 验证 v1.0-v1.2 系统在 v1.3 扩展下的兼容性
- 性能测试（大数据量/高频操作）

**测试内容**：

1. **公会系统集成**
   - 公会创建 → 成员加入 → 贡献值 → 商店购买 → 公会战
   - 确保玩家数据正确更新

2. **装备系统集成**
   - 获取装备 → 穿戴 → 强化 → 属性计算 → 实际对战应用
   - 与角色系统/藏品系统的联动

3. **跨系统事件链验证**
   - 任务完成 → 活跃度 → 奖励 → 赛季经验 → 成就
   - 公会战 → 贡献值 → 公会等级 → 解锁商店 → 购买装备

4. **性能压力测试**
   - 100 人公会操作
   - 1000 件装备的背包管理
   - 10000 条成就记录

**预计工作量**：**2 天**

---

#### 功能 3.11 — 发布准备
**需求说明**：
- v1.3.0 发布说明文档
- project.json 版本号更新
- TapTap 描述更新
- 数据迁移策略

**预计工作量**：**1 天**

---

## 四、v1.2 → v1.3 功能对比

| 维度 | v1.2.0 | v1.3.0（目标） | 变化 |
|------|--------|----------------|------|
| 游戏系统 | 25 | **27+** | +2（公会/装备） |
| EventBus 事件 | 35 | **49** | +14 |
| 成就数量 | 基础 | **10+ 类别/5 等级** | 大幅扩展 |
| 任务系统 | 每日任务 | 每日+每周+每月+活跃度+连续登录 | **5x 内容** |
| 排行榜 | 简单 | **4 类型 × 3 周期 = 12 榜** | +11 |
| 社交系统 | 好友/团队 | 好友+团队+**公会/公会战** | **+公会生态** |
| 装备系统 | 无 | **4 槽位 × 5 稀有度 × 强化** | 从零开始 |
| 个性化 | 头像/称号 | **头像框/称号/徽章/签名/心情** | +5 功能 |
| 测试文件 | 16 | **23** | +7 |
| 测试用例 | 107 | **200+** | +100 |
| 总代码行数 | ~10000 | **~15000** | +50% |

---

## 五、里程碑与时间线

| 周次 | 日期范围 | 主要任务 | 预计完成度 |
|------|----------|---------|-----------|
| **第 1 周** | 07-20 ~ 07-26 | 公会系统 + 成就扩展 + 测试补全 | 30% |
| **第 2 周** | 07-27 ~ 08-02 | 装备系统 + 任务扩展 | 60% |
| **第 3 周** | 08-03 ~ 08-09 | 排行榜扩展 + 个性化 + UI/UX | 85% |
| **第 4 周** | 08-10 ~ 08-19 | EventBus 扩展 + 集成测试 + 发布准备 | 100% |

---

## 六、详细开发排期（按天）

### 第 1 周：核心系统周

| 日期 | 上午任务 | 下午任务 | 晚上验证 |
|------|---------|---------|---------|
| **07-20 周一** | GuildSystem 核心框架 + 公会创建/加入 | 公会等级/贡献系统 | 公会基础功能测试 |
| **07-21 周二** | 公会战系统 | 公会商店系统 | 公会战 + 商店测试 |
| **07-22 周三** | AchievementSystem 扩展 | 成就类别/等级/隐藏 | 成就系统测试 |
| **07-23 周四** | 成就奖励 + 成就统计 | TestAchievementSystem.lua | 成就系统完整测试 |
| **07-24 周五** | 测试补全 Day1 | TestDailyMission + TestProfile | 测试通过验证 |
| **07-25 周六** | 测试补全 Day2 | TestLeaderboard + TestEventMode | 测试通过验证 |
| **07-26 周日** | 测试补全 Day3 | TestSystemManager + TestPlayerDataManager | 第 1 周验收 |

### 第 2 周：内容扩展周

| 日期 | 上午任务 | 下午任务 | 晚上验证 |
|------|---------|---------|---------|
| **07-27 周一** | EquipmentSystem 数据模型 | 装备管理 API（装备/卸下） | 基础装备测试 |
| **07-28 周二** | 装备强化系统 | 属性计算系统 | 强化 + 属性测试 |
| **07-29 周三** | 装备 EventBus 事件 | 装备套装机制 | 装备系统集成测试 |
| **07-30 周四** | DailyMission 扩展（周/月任务） | 任务重置机制 | 任务扩展测试 |
| **07-31 周五** | 活跃度系统 | 活跃度奖励 | 活跃度测试 |
| **08-01 周六** | 连续登录奖励系统 | 任务奖励发放 | 连续登录测试 |
| **08-02 周日** | 装备/任务系统集成 | 创建 TestEquipmentSystem.lua | 第 2 周验收 |

### 第 3 周：体验优化周

| 日期 | 上午任务 | 下午任务 | 晚上验证 |
|------|---------|---------|---------|
| **08-03 周一** | LeaderboardSystem 扩展（多榜） | 周榜/月榜机制 | 排行榜扩展测试 |
| **08-04 周二** | 个人排名高亮 | 排行榜奖励发放 | 排行榜完整测试 |
| **08-05 周三** | ProfileSystem 扩展 | 头像框/徽章/签名/心情 | 个性化测试 |
| **08-06 周四** | 对战统计 | 隐私设置 | 个性化系统测试 |
| **08-07 周五** | GameUI 新面板（公会/装备） | 公会 UI + 装备 UI | UI 功能测试 |
| **08-08 周六** | GameUI 新面板（成就/任务/排行榜） | 动画优化 | UI 完整测试 |
| **08-09 周日** | UI 整体联调 | 响应式布局优化 | 第 3 周验收 |

### 第 4 周：集成 + 发布周

| 日期 | 上午任务 | 下午任务 | 晚上验证 |
|------|---------|---------|---------|
| **08-10 周一** | EventBus 扩展（14 个新事件） | 系统间事件联动 | 事件系统测试 |
| **08-11 周二** | SystemManager 扩展（+2 系统） | 统一初始化测试 | 系统管理测试 |
| **08-12 周三** | 创建 TestIntegration-v1.3.lua | 公会+装备系统集成测试 | 集成测试通过 |
| **08-13 周四** | 跨系统事件链验证 | 回归测试（v1.0-v1.2） | 完整回归测试 |
| **08-14 周五** | 性能压力测试 | 性能优化 | 性能指标达标 |
| **08-15 周六** | v1.3.0 发布说明 | project.json 更新 | 发布文档完成 |
| **08-16 周日** | 数据迁移策略 | 最终验证 | 代码冻结 |
| **08-17 周一** | **最终回归测试** | Bug 修复 | 稳定性验证 |
| **08-18 周二** | **最终部署准备** | 最终检查 | 预发布验证 |
| **08-19 周三** | **v1.3.0 正式发布** | 发布监控 | 上线成功！ |

---

## 七、风险与应对

| 风险 | 影响 | 概率 | 应对方案 |
|------|------|------|---------|
| 公会系统复杂度超预期 | 延期 1 周 | ⚠️ **高** | MVP 方案：先实现公会基础功能，公会战延后到 v1.3.1 |
| 装备系统属性平衡困难 | 影响游戏体验 | ⚠️ **中** | 首月装备属性可动态调整，通过数据监控微调 |
| 测试补全工作量大 | 延期 3 天 | ⚠️ **中** | 优先保证核心系统测试，非核心系统简化 |
| UI 面板过多导致布局混乱 | 用户体验下降 | ⚠️ **中** | 统一导航栏，分组管理功能面板 |
| 跨系统事件链复杂 | Bug 难追踪 | ⚠️ **中** | 增加 EventBus 调试工具，事件日志可搜索 |
| 性能问题（大规模数据） | 卡顿/延迟 | ✅ **低** | 虚拟列表 + 分页查询 + 缓存机制 |

---

## 八、开发优先级矩阵

```
🔴 极高优先级（必须在 v1.3 完成）：
  ├── 公会系统（社交系统的核心）
  ├── 成就系统扩展（留存的关键）
  └── 装备系统（角色深度的核心）

🟡 高优先级（应该在 v1.3 完成）：
  ├── 任务系统扩展（每日+周+月+活跃度）
  ├── 排行榜系统扩展（12 榜）
  ├── 个性化系统扩展
  └── UI/UX 大版本优化

🟢 中优先级（建议在 v1.3 完成）：
  ├── 测试补全（7 个文件）
  ├── EventBus + SystemManager 扩展
  └── 集成测试 + 回归测试

⚪ 低优先级（可延后到 v1.4）：
  ├── 跨服锦标赛（依赖更多服务器架构）
  ├── 语音聊天（技术复杂度高）
  ├── 故事模式（需要大量内容创作）
  └── 自定义外观编辑器（美术资源依赖）
```

---

## 九、v1.4 前瞻规划

以下功能计划在 v1.4 版本中实现：

| 功能 | 描述 | 前置依赖 |
|------|------|---------|
| 跨服锦标赛 | 多服务器玩家互通对战 | 服务器架构扩展 |
| 语音聊天 | 房间内/团队内/公会内语音沟通 | 语音 SDK 集成 |
| 故事模式 | 单人剧情体验，背景故事展开 | 剧情脚本编写 |
| 自定义外观编辑器 | 玩家自由搭配角色外观 | 美术资源系统 |
| 赛季战令 | Battle Pass 系统，多轨道奖励 | 赛季系统进一步扩展 |
| 经济系统平衡 | 金币回收机制 / 经济监控 | 大数据分析 |
| 跨平台联机 | PC/移动平台互通 | 平台适配测试 |

---

## 十、项目资源清单

### 10.1 新增文件清单（v1.3）

| 文件 | 预计行数 | 类型 |
|------|---------|------|
| `scripts/Game/GuildSystem.lua` | ~250 | 核心系统 |
| `scripts/Game/EquipmentSystem.lua` | ~220 | 核心系统 |
| `scripts/tests/TestAchievementSystem.lua` | ~150 | 测试 |
| `scripts/tests/TestDailyMissionSystem.lua` | ~150 | 测试 |
| `scripts/tests/TestProfileSystem.lua` | ~120 | 测试 |
| `scripts/tests/TestLeaderboardSystem.lua` | ~150 | 测试 |
| `scripts/tests/TestEventModeSystem.lua` | ~120 | 测试 |
| `scripts/tests/TestSystemManager.lua` | ~120 | 测试 |
| `scripts/tests/TestPlayerDataManager.lua` | ~150 | 测试 |
| `scripts/tests/TestEquipmentSystem.lua` | ~150 | 测试 |
| `scripts/tests/TestGuildSystem.lua` | ~150 | 测试 |
| `scripts/tests/TestIntegration-v1.3.lua` | ~200 | 集成测试 |
| **新增小计** | **~2080 行** | **12 个文件** |

### 10.2 修改文件清单（v1.3）

| 文件 | 修改内容 | 预计改动 |
|------|---------|----------|
| `scripts/Utils/EventBus.lua` | +14 个新事件 | +50 行 |
| `scripts/Game/SystemManager.lua` | +2 个新系统注册 | +20 行 |
| `scripts/Game/AchievementSystem.lua` | 成就等级/类别/奖励系统 | +180 行 |
| `scripts/Game/DailyMissionSystem.lua` | 周任务/活跃度/连续登录 | +180 行 |
| `scripts/Game/LeaderboardSystem.lua` | 多榜/周期/奖励 | +150 行 |
| `scripts/Game/ProfileSystem.lua` | 头像框/徽章/签名/心情/隐私 | +160 行 |
| `scripts/UI/GameUI.lua` | 6 个新面板 + 导航更新 | +300 行 |
| `scripts/Config.lua` | 公会/装备/任务/成就配置节点 | +100 行 |
| `.project/project.json` | 版本号 1.2→1.3 | +10 行 |
| **修改小计** | **9 个文件** | **~1150 行** |

### 10.3 代码量汇总

| 类型 | 文件数 | 预计代码行数 |
|------|--------|-------------|
| 新增文件 | 12 | ~2080 |
| 修改文件 | 9 | +~1150 |
| **v1.3 总计** | **21 个文件** | **~3230 行** |
| **项目总计（v1.0+v1.1+v1.2）** | **~47** | **~10000** |
| **v1.3 后项目总计** | **~68 个文件** | **~13230 行** |

---

## 十一、质量保证计划

### 11.1 测试策略

| 测试类型 | 覆盖率目标 | 工具/方法 |
|---------|-----------|-----------|
| 单元测试 | 每个核心系统 10+ 用例 | Lua 测试框架 |
| 集成测试 | 主要系统间事件链 | EventBus 事件追踪 |
| 回归测试 | v1.0-v1.2 功能全部通过 | 自动化测试脚本 |
| 性能测试 | 1000 数据量无卡顿 | 手动压力测试 |

### 11.2 代码质量要求

- ✅ 所有新系统必须包含单元测试
- ✅ 所有公共 API 必须有事件通知
- ✅ 配置集中在 Config.lua，不硬编码
- ✅ 依赖项通过 SystemManager 管理
- ✅ 系统间通过 EventBus 解耦，不直接调用
- ✅ 玩家数据通过 PlayerDataManager 统一管理

---

> **文档版本**：v1.3.0-plan-draft
> **创建日期**：2026-06-19
> **最后更新**：2026-06-19
> **维护者**：盲拍暗战开发团队
