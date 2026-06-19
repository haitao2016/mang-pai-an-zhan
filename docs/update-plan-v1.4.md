# 《盲拍暗战》v1.3.0 Phase 2 + v1.4.0 开发计划

> 版本代号：**装备风暴 (Equipment Storm)**
> 目标发布：2026-09-15
> 开发周期：3 周（2026-08-20 ~ 2026-09-15）
> 当前版本：`v1.2.0` → 目标版本：`v1.4.0`

---

## 一、当前项目状态检查

### 1.1 系统清单（28 个系统）

| 模块 | 文件 | 状态 | 版本 |
|------|------|------|------|
| AI 玩家 | AIPlayer.lua | ✅ 完整 | v1.0 |
| 拍卖管理 | AuctionManager.lua | ✅ 完整 | v1.0 |
| 出价系统 | BidSystem.lua | ✅ 完整 | v1.0 |
| 角色系统 | CharacterSystem.lua | ✅ 完整 | v1.0 |
| 揭秘系统 | RevealSystem.lua | ✅ 完整 | v1.0 |
| 回合管理 | RoundManager.lua | ✅ 完整 | v1.0 |
| 玩家数据 | PlayerDataManager.lua | ✅ 完整 | v1.0 |
| 藏品池 | ItemPool.lua | ✅ 完整 | v1.0 |
| 套装系统 | ItemSetSystem.lua | ✅ 完整 | v1.0 |
| 赛季系统 | SeasonSystem.lua | ✅ 完整 | v1.1 |
| 好友系统 | FriendSystem.lua | ✅ 完整 | v1.1 |
| 自定义房间 | RoomSystem.lua | ✅ 完整 | v1.1 |
| 成就系统 | AchievementSystem.lua | ⚠️ **扩展中** | v1.3 |
| 每日任务 | DailyMissionSystem.lua | ✅ 完整 | v1.1 |
| 排行榜 | LeaderboardSystem.lua | ✅ 完整 | v1.1 |
| 个性化 | ProfileSystem.lua | ✅ 完整 | v1.1 |
| 限时活动 | EventModeSystem.lua | ✅ 完整 | v1.1 |
| 锦标赛 | TournamentSystem.lua | ✅ 完整 | v1.2 |
| 团队战 | TeamBattleSystem.lua | ✅ 完整 | v1.2 |
| 交易市场 | TradeSystem.lua | ✅ 完整 | v1.2 |
| 皮肤系统 | SkinSystem.lua | ✅ 完整 | v1.2 |
| 系统管理器 | SystemManager.lua | ✅ 完整 | v1.2 |
| **公会系统** | **GuildSystem.lua** | ⚠️ **需集成** | v1.3 |
| **装备系统** | **EquipmentSystem.lua** | ❌ **待创建** | v1.3 |

### 1.2 EventBus 事件缺口

**EventBus.Events 中已定义（40 个）**：`GAME_*, ROUND_*, PLAYER_*, ITEM_*, SKILL_*, ACHIEVEMENT_*, MISSION_*, SEASON_*, TOURNAMENT_*, TEAM_*, TRADE_*, SKIN_*, SYSTEM_*`

**⚠️ GuildSystem.lua 引用但未定义（会报错！）**：
- `GUILD_CREATE` ❌
- `GUILD_JOIN` ❌
- `GUILD_LEAVE` ❌
- `GUILD_CONTRIBUTION_UPDATE` ❌
- `GUILD_LEVEL_UP` ❌

**❌ 装备系统所需事件缺失**：
- `EQUIPMENT_UNLOCK` ❌
- `EQUIPMENT_EQUIP` ❌
- `EQUIPMENT_UNEQUIP` ❌
- `EQUIPMENT_ENHANCE` ❌
- `EQUIPMENT_SET_COMPLETE` ❌

### 1.3 SystemManager 注册缺口

**SystemRegistry 当前 12 个系统**：
- v1.0 核心: EventBus, Config (2)
- v1.1 游戏: SeasonSystem, FriendSystem, LeaderboardSystem, ProfileSystem, ItemSetSystem, EventModeSystem, RoomSystem (7)
- v1.2 新系统: TournamentSystem, TeamBattleSystem, TradeSystem, SkinSystem (4)

**⚠️ 未注册的系统**：
- ❌ `Game.GuildSystem` - priority 30
- ❌ `Game.EquipmentSystem` - priority 30
- ⚠️ `Game.AchievementSystem` - 应注册但未找到

### 1.4 Config.lua 配置缺口

当前缺少的配置节点：
- ❌ `Config.Guild` - 公会创建费用、成员上限、等级经验
- ❌ `Config.Equipment` - 装备稀有度、属性配置、强化消耗
- ⚠️ `Config.Achievements` 缺少 v1.3 扩展的等级/类别配置

### 1.5 测试文件状态

**已有 25 个测试文件（100% 覆盖现有系统）**：
- ✅ TestGuildSystem.lua
- ✅ TestAchievementSystem.lua (扩展后的)
- ✅ TestDailyMissionSystem.lua
- ✅ TestProfileSystem.lua
- ✅ TestLeaderboardSystem.lua
- ✅ TestEventModeSystem.lua
- ✅ TestSystemManager.lua
- ✅ TestPlayerDataManager.lua
- ✅ 其他原有系统测试

**还需创建**：
- ❌ TestEquipmentSystem.lua - 装备系统测试
- ❌ TestIntegrationV1_3.lua - v1.3 跨系统集成测试
- ❌ TestIntegrationV1_4.lua - v1.4 跨系统集成测试

---

## 二、v1.3.0 Phase 2 - 系统集成与修复

### 2.1 目标

完成 v1.3.0 已创建系统的集成工作，确保公会系统和扩展后的成就系统能真正运行。

### 2.2 任务清单

#### Task 1：扩展 EventBus（高优先级）

**文件**: `scripts/Utils/EventBus.lua`

**修改内容**:
```
EventBus.Events = {
    -- ... 原有 40 个事件 ...

    -- ── v1.3 公会事件 ──
    GUILD_CREATE             = "guild_create",
    GUILD_JOIN               = "guild_join",
    GUILD_LEAVE              = "guild_leave",
    GUILD_KICK               = "guild_kick",
    GUILD_CONTRIBUTION_UPDATE = "guild_contribution_update",
    GUILD_LEVEL_UP           = "guild_level_up",
    GUILD_WAR_START          = "guild_war_start",
    GUILD_WAR_END            = "guild_war_end",
    GUILD_SHOP_PURCHASE      = "guild_shop_purchase",

    -- ── v1.3 装备事件 ──
    EQUIPMENT_UNLOCK         = "equipment_unlock",
    EQUIPMENT_EQUIP          = "equipment_equip",
    EQUIPMENT_UNEQUIP        = "equipment_unequip",
    EQUIPMENT_ENHANCE        = "equipment_enhance",
    EQUIPMENT_SET_COMPLETE   = "equipment_set_complete",
}
```

**新增事件数**: +15 → 总计 55 个事件

**预期代码量**: ~30 行

---

#### Task 2：修复 GuildSystem 事件引用（高优先级）

**文件**: `scripts/Game/GuildSystem.lua`

**问题**: 部分事件使用字符串而非 EventBus.Events 引用

**修复**:
```lua
-- 原代码 (错误):
EventBus.Publish("guild_war_started", { ... })
EventBus.Publish("guild_war_ended", { ... })
EventBus.Subscribe("mission_completed", function(data) ... end, "GuildSystem")
EventBus.Subscribe("season_progress_update", function(data) ... end, "GuildSystem")

-- 修复后:
EventBus.Publish(EventBus.Events.GUILD_WAR_START, { ... })
EventBus.Publish(EventBus.Events.GUILD_WAR_END, { ... })
EventBus.Subscribe(EventBus.Events.MISSION_COMPLETE, function(data) ... end, "GuildSystem")
EventBus.Subscribe(EventBus.Events.SEASON_PROGRESS, function(data) ... end, "GuildSystem")
```

**预期代码量**: ~10 行修改

---

#### Task 3：在 SystemManager 中注册新系统（高优先级）

**文件**: `scripts/Game/SystemManager.lua`

**修改内容**:
```lua
SystemManager.SystemRegistry = {
    -- ... 原有 12 个系统 ...

    -- ── v1.3 新系统 ──
    { name = "GuildSystem",     module = "Game.GuildSystem",         priority = 30 },
    { name = "EquipmentSystem", module = "Game.EquipmentSystem",     priority = 30 },
}
```

**同时需扩展统计函数**:
```lua
function SystemManager.GetSystemStats()
    -- ...
    elseif sys.priority == 30 then
        v1_3 = v1_3 + 1
    -- ...
    return {
        total = ...,
        v1_0 = v1_0,
        v1_1 = v1_1,
        v1_2 = v1_2,
        v1_3 = v1_3,  -- 新增
    }
end
```

**预期代码量**: ~30 行

---

#### Task 4：Config.lua 添加公会配置（高优先级）

**文件**: `scripts/Config.lua`

**新增节点**:
```lua
Config.Guild = {
    createCost = 5000,           -- 创建公会费用
    baseMaxMembers = 10,         -- 基础成员数
    membersPerLevel = 5,         -- 每级增加成员数
    maxLevel = 10,               -- 最高等级
    expPerLevel = 500,           -- 每级所需经验
    warVictoryExp = 100,         -- 公会战胜利经验奖励
    warVictoryMemberContribution = 20,  -- 成员个人贡献奖励
    dailySignInContribution = 5, -- 每日签到贡献值
    renameCost = 2000,           -- 改名费用
    minMemberNameLength = 2,     -- 公会名称最小长度
    maxMemberNameLength = 12,    -- 公会名称最大长度
}

-- 公会商店物品配置
Config.GuildShop = {
    { id = "gold_pack_1",       name = "小型金币包", cost = 50,  reward = { gold = 1000 } },
    { id = "gold_pack_2",       name = "中型金币包", cost = 100, reward = { gold = 2500 } },
    { id = "skill_boost",       name = "技能强化符", cost = 150, reward = { skillBoost = true } },
    { id = "avatar_frame",      name = "公会头像框", cost = 300, reward = { avatarFrame = "guild" } },
    { id = "legendary_pack",    name = "传说藏品包", cost = 800, reward = { legendaryItem = true } },
}
```

**预期代码量**: ~60 行

---

#### Task 5：更新版本号（低优先级，最后执行）

**文件**: `scripts/Config.lua`

**修改**:
```lua
Config.Version = "1.4.0"
Config.ReleaseDate = "2026-09-15"
```

**预期代码量**: 2 行

---

### 2.3 依赖关系图

```
GuildSystem.lua
    ├── 需要 EventBus.Events.GUILD_* 事件
    ├── 需要 Config.Guild / Config.GuildShop 配置
    └── 需要在 SystemManager 中注册
         └── 才能在 GameUI 中使用

EquipmentSystem.lua (待创建)
    ├── 需要 EventBus.Events.EQUIPMENT_* 事件
    ├── 需要 Config.Equipment 配置
    └── 需要在 SystemManager 中注册
```

---

## 三、v1.3.0 - 装备系统开发（核心）

### 3.1 设计概要

**装备槽位**（4 个主槽位 + 2 个饰品槽位）：
| 槽位 | 示例 | 属性类型 |
|------|------|---------|
| 武器 (Weapon) | 拍卖锤、金币剑 | +出价精准度 / +最终收益 |
| 防具 (Armor) | 神秘斗篷、富豪礼服 | +防御力 / +抗干扰 |
| 饰品 (Accessory) | 幸运硬币、收藏家徽章 | +稀有度加成 / +暴击 |
| 徽章 (Badge) | 拍卖大师徽章 | +全局属性加成 |

**稀有度等级**（与藏品稀有度对齐）：
1. 普通 (Common) - 灰色
2. 稀有 (Rare) - 绿色
3. 史诗 (Epic) - 紫色
4. 传说 (Legendary) - 金色
5. 神话 (Mythic) - 红色

### 3.2 核心功能

**文件**: `scripts/Game/EquipmentSystem.lua`

**主要 API**:
```lua
-- 装备管理
EquipmentSystem.GetPlayerEquipment(uid)              -- 获取玩家装备栏
EquipmentSystem.Equip(uid, equipmentId, slot)        -- 装备某物品
EquipmentSystem.Unequip(uid, slot)                   -- 卸下装备
EquipmentSystem.GetEquippedInSlot(uid, slot)         -- 获取已装备物品

-- 解锁与收藏
EquipmentSystem.UnlockEquipment(uid, equipmentId)    -- 解锁装备
EquipmentSystem.IsUnlocked(uid, equipmentId)         -- 是否已解锁
EquipmentSystem.GetEquipmentList(uid)                -- 获取所有装备及解锁状态
EquipmentSystem.GetEquipmentConfig(equipmentId)       -- 获取装备配置信息

-- 装备强化
EquipmentSystem.Enhance(uid, equipmentId)            -- 强化装备
EquipmentSystem.GetEnhanceLevel(uid, equipmentId)    -- 获取强化等级
EquipmentSystem.GetEnhanceCost(equipmentId, level)   -- 获取强化费用

-- 属性计算
EquipmentSystem.GetTotalStats(uid)                   -- 获取所有装备总属性
EquipmentSystem.GetBonusForHall(uid, hallId)         -- 获取特定厅加成
EquipmentSystem.GetPlayerPower(uid)                  -- 计算玩家战力值

-- 套装效果
EquipmentSystem.GetActiveSetBonus(uid)               -- 获取当前激活的套装效果
EquipmentSystem.GetAllSets()                         -- 获取所有套装配置

-- 系统管理
EquipmentSystem.Reset()                              -- 重置系统（测试用）
EquipmentSystem.RegisterEvents()                     -- 注册 EventBus 监听
```

### 3.3 装备系统配置

**文件**: `scripts/Config.lua`

**新增节点**:
```lua
Config.Equipment = {
    maxEnhanceLevel = 10,        -- 最高强化等级
    baseEnhanceCost = 500,       -- 基础强化费用
    costMultiplierPerLevel = 1.5, -- 每级费用倍率
    successRateBase = 0.9,        -- 基础成功率
    successRateDrop = 0.05,       -- 每级成功率下降
    statsPerEnhanceLevel = 0.1,   -- 每级强化属性加成

    slots = { "weapon", "armor", "accessory", "badge" },
}

-- 装备物品列表
Config.EquipmentItems = {
    -- 武器类
    { id = "weapon_basic_hammer",   name = "新手拍卖锤", slot = "weapon",  rarity = 1, stats = { bidAccuracy = 0.05 } },
    { id = "weapon_gold_sword",     name = "金币剑",     slot = "weapon",  rarity = 2, stats = { bidAccuracy = 0.10, finalBonus = 0.05 } },
    { id = "weapon_mystic_gavel",   name = "神秘法槌",   slot = "weapon",  rarity = 3, stats = { bidAccuracy = 0.15, finalBonus = 0.10 } },
    { id = "weapon_auction_master", name = "拍卖大师锤", slot = "weapon",  rarity = 4, stats = { bidAccuracy = 0.25, finalBonus = 0.15 } },
    { id = "weapon_mythic_scepter", name = "神话权杖",   slot = "weapon",  rarity = 5, stats = { bidAccuracy = 0.35, finalBonus = 0.25, allRarityBonus = 0.05 } },

    -- 防具类
    { id = "armor_basic_cloak",     name = "普通斗篷",    slot = "armor",   rarity = 1, stats = { defense = 0.1 } },
    { id = "armor_mystic_robe",     name = "神秘长袍",    slot = "armor",   rarity = 3, stats = { defense = 0.25, antiSkill = 0.10 } },
    { id = "armor_millionaire",     name = "富豪礼服",    slot = "armor",   rarity = 4, stats = { defense = 0.35, finalBonus = 0.10 } },

    -- 饰品类
    { id = "acc_lucky_coin",        name = "幸运硬币",    slot = "accessory", rarity = 2, stats = { critChance = 0.15 } },
    { id = "acc_collector_badge",   name = "收藏家徽章",  slot = "accessory", rarity = 3, stats = { itemValueBonus = 0.15, rarityBonus = 0.10 } },
    { id = "acc_rarity_ring",       name = "稀有度指环",  slot = "accessory", rarity = 4, stats = { rarityBonus = 0.25 } },

    -- 徽章类
    { id = "badge_auction_master",  name = "拍卖大师徽章", slot = "badge",   rarity = 4, stats = { globalBonus = 0.10 } },
    { id = "badge_champion",        name = "冠军徽章",    slot = "badge",   rarity = 5, stats = { globalBonus = 0.20, critChance = 0.20 } },
}

-- 装备套装配置
Config.EquipmentSets = {
    {
        id = "auction_master_set",
        name = "拍卖大师套装",
        pieces = { "weapon_auction_master", "armor_millionaire", "acc_collector_badge", "badge_auction_master" },
        bonus2 = { finalBonus = 0.10 },               -- 2件效果
        bonus3 = { rarityBonus = 0.15 },               -- 3件效果
        bonus4 = { globalBonus = 0.25, critChance = 0.30 },  -- 4件效果
    },
    {
        id = "mythic_legend_set",
        name = "神话传说套装",
        pieces = { "weapon_mythic_scepter", "badge_champion" },
        bonus2 = { globalBonus = 0.50, itemValueBonus = 0.30 },
    },
}
```

### 3.4 内部状态管理

```lua
-- 玩家装备数据结构
_equipmentData[uid] = {
    equipped = {
        weapon = "weapon_gold_sword",     -- 当前装备的物品ID
        armor = "armor_mystic_robe",
        accessory = "acc_lucky_coin",
        badge = nil,
    },
    unlocked = {                          -- 已解锁的装备
        weapon_basic_hammer = true,
        weapon_gold_sword = true,
        armor_basic_cloak = true,
        armor_mystic_robe = true,
        acc_lucky_coin = true,
    },
    enhanceLevels = {                     -- 装备强化等级
        weapon_gold_sword = 3,
        armor_mystic_robe = 5,
    },
}
```

### 3.5 EventBus 集成

**发布事件**:
```lua
EventBus.Publish(EventBus.Events.EQUIPMENT_UNLOCK, {
    uid = uid,
    equipmentId = equipmentId,
    slot = config.slot,
    rarity = config.rarity,
})

EventBus.Publish(EventBus.Events.EQUIPMENT_EQUIP, {
    uid = uid,
    equipmentId = equipmentId,
    slot = slot,
    previousEquipment = oldEquipmentId,
})

EventBus.Publish(EventBus.Events.EQUIPMENT_ENHANCE, {
    uid = uid,
    equipmentId = equipmentId,
    newLevel = newLevel,
    success = true,
})

EventBus.Publish(EventBus.Events.EQUIPMENT_SET_COMPLETE, {
    uid = uid,
    setId = setId,
    setName = setConfig.name,
    bonus = activeBonus,
})
```

**订阅事件**:
```lua
-- 监听成就解锁奖励装备
EventBus.Subscribe(EventBus.Events.ACHIEVEMENT_UNLOCK, function(data)
    if data.rewardEquipment then
        EquipmentSystem.UnlockEquipment(data.uid, data.rewardEquipment)
    end
end, "EquipmentSystem")

-- 监听赛季奖励装备
EventBus.Subscribe(EventBus.Events.SEASON_LEVELUP, function(data)
    if data.rewardEquipment then
        EquipmentSystem.UnlockEquipment(data.uid, data.rewardEquipment)
    end
end, "EquipmentSystem")

-- 监听公会商店购买
EventBus.Subscribe(EventBus.Events.GUILD_SHOP_PURCHASE, function(data)
    if data.reward and data.reward.equipment then
        EquipmentSystem.UnlockEquipment(data.uid, data.reward.equipment)
    end
end, "EquipmentSystem")
```

### 3.6 属性计算系统

**属性类型定义**:
```lua
bidAccuracy      -- 出价精准度 (影响出价接近最优的概率)
finalBonus       -- 最终收益加成 (百分比)
defense          -- 防御力 (减少被技能影响的概率)
antiSkill        -- 抗技能 (特定技能无效化概率)
critChance       -- 暴击几率 (双倍收益概率)
rarityBonus      -- 稀有度加成 (获得高稀有度物品的额外加成)
itemValueBonus   -- 物品价值加成 (藏品估值提升)
globalBonus      -- 全局加成 (所有属性的百分比加成)
allRarityBonus   -- 全稀有度加成
```

**总属性计算逻辑**:
```lua
function EquipmentSystem.GetTotalStats(uid)
    local stats = {
        bidAccuracy = 0,
        finalBonus = 0,
        defense = 0,
        antiSkill = 0,
        critChance = 0,
        rarityBonus = 0,
        itemValueBonus = 0,
        globalBonus = 0,
        allRarityBonus = 0,
    }

    local data = _equipmentData[uid]
    if not data then return stats end

    -- 遍历所有装备槽位
    for slot, equipmentId in pairs(data.equipped) do
        if equipmentId and data.unlocked[equipmentId] then
            local config = GetEquipmentConfig(equipmentId)
            if config and config.stats then
                -- 应用装备基础属性
                for stat, value in pairs(config.stats) do
                    stats[stat] = (stats[stat] or 0) + value
                end

                -- 应用强化加成
                local enhanceLevel = data.enhanceLevels[equipmentId] or 0
                if enhanceLevel > 0 then
                    local enhanceMultiplier = 1 + (enhanceLevel * Config.Equipment.statsPerEnhanceLevel)
                    for stat, value in pairs(config.stats) do
                        stats[stat] = stats[stat] + (value * enhanceLevel * Config.Equipment.statsPerEnhanceLevel)
                    end
                end
            end
        end
    end

    -- 应用套装效果
    local setBonus = EquipmentSystem.GetActiveSetBonus(uid)
    for stat, value in pairs(setBonus) do
        stats[stat] = (stats[stat] or 0) + value
    end

    -- 应用全局加成
    if stats.globalBonus > 0 then
        for stat, value in pairs(stats) do
            if stat ~= "globalBonus" then
                stats[stat] = value * (1 + stats.globalBonus)
            end
        end
    end

    return stats
end
```

**预期代码量**: ~400 行

---

## 四、v1.4.0 - 游戏内系统联动

### 4.1 成就系统与装备联动

在 `AchievementSystem.lua` 中添加：
```lua
-- 新成就条件类型: "equipment_unlock", "equipment_equip", "set_complete", "enhance_level"
Config.Achievements = {
    -- ... 原有成就 ...

    -- 装备相关成就 (v1.3 新增)
    { id = "first_equipment", name = "第一份装备", desc = "解锁第一件装备", checkType = "equipment_unlock", checkValue = 1, level = "gold", category = "special", reward = 500 },
    { id = "equipment_10",    name = "装备收藏家",  desc = "解锁10件装备",   checkType = "equipment_unlock", checkValue = 10, level = "platinum", category = "collection", reward = 2000 },
    { id = "equipment_full",  name = "全副武装",    desc = "装备4个槽位",    checkType = "equipment_equip", checkValue = 4, level = "gold", category = "competition", reward = 1500 },
    { id = "set_complete",    name = "套装大师",    desc = "完成一个装备套装", checkType = "set_complete", checkValue = 1, level = "platinum", category = "collection", reward = 3000 },
    { id = "max_enhance",     name = "强化达人",    desc = "将装备强化到满级", checkType = "enhance_level", checkValue = 10, level = "diamond", category = "special", reward = 5000 },

    -- 公会相关成就 (v1.3 新增)
    { id = "guild_create",    name = "公会创始人",  desc = "创建一个公会",     checkType = "guild_status", checkValue = "leader", level = "silver", category = "social", reward = 2000 },
    { id = "guild_join",      name = "公会成员",    desc = "加入任意公会",     checkType = "guild_status", checkValue = "member", level = "copper", category = "social", reward = 500 },
    { id = "guild_war_victory", name = "公会战士",  desc = "赢得10场公会战",   checkType = "guild_war_wins", checkValue = 10, level = "gold", category = "competition", reward = 3000 },
    { id = "guild_max_level", name = "公会之巅",    desc = "公会达到最高等级", checkType = "guild_level", checkValue = 10, level = "diamond", category = "special", reward = 8000 },
}
```

### 4.2 赛季系统与装备联动

在 `SeasonSystem.lua` 中（如存在）添加装备奖励逻辑：
```lua
-- 赛季等级奖励装备物品
Config.Seasons.levelRewards = {
    [5]  = { gold = 1000, equipment = "weapon_gold_sword" },
    [10] = { gold = 2000, equipment = "armor_mystic_robe" },
    [15] = { gold = 3000, equipment = "acc_rarity_ring" },
    [20] = { gold = 5000, equipment = "badge_auction_master" },
    [25] = { gold = 8000, equipment = "weapon_mythic_scepter" },
    [30] = { gold = 10000, equipment = "badge_champion" },
}
```

### 4.3 交易市场与装备联动

在 `TradeSystem.lua` 中支持装备物品交易：
```lua
-- 装备物品也可以挂单交易
Config.Trade.equipmentTradable = true
Config.Trade.equipmentFeeRate = 0.10  -- 装备交易手续费 10%
```

---

## 五、测试补全计划

### 5.1 TestEquipmentSystem.lua（高优先级）

**测试用例清单**（预计 15-20 个用例）：

| # | 测试名称 | 测试目标 |
|---|---------|---------|
| 1 | TestUnlockEquipment | 解锁装备功能 |
| 2 | TestIsUnlocked | 判断是否已解锁 |
| 3 | TestEquip | 装备物品到槽位 |
| 4 | TestUnequip | 卸下装备 |
| 5 | TestGetEquippedInSlot | 获取槽位中的装备 |
| 6 | TestGetPlayerEquipment | 获取玩家完整装备栏 |
| 7 | TestEnhance | 装备强化功能 |
| 8 | TestEnhanceCost | 强化费用计算 |
| 9 | TestGetEnhanceLevel | 获取强化等级 |
| 10 | TestGetTotalStats | 计算总属性 |
| 11 | TestGetBonusForHall | 特定厅属性加成 |
| 12 | TestGetPlayerPower | 计算玩家战力 |
| 13 | TestSetBonusDetection | 套装效果检测 |
| 14 | TestFullSetBonus | 完整套装效果激活 |
| 15 | TestEquipMultipleSlots | 多槽位装备管理 |
| 16 | TestStatsAccumulation | 属性累加正确性 |
| 17 | TestEventPublishing | 事件发布验证 |
| 18 | TestReset | 重置功能 |

**预期代码量**: ~300 行

---

### 5.2 TestIntegrationV1_3.lua（中优先级）

**集成测试场景**：

| # | 测试名称 | 涉及系统 | 验证内容 |
|---|---------|---------|---------|
| 1 | GuildIntegration | GuildSystem + SeasonSystem + AchievementSystem | 公会贡献触发赛季经验 |
| 2 | GuildWarEventChain | GuildSystem + EventBus + LeaderboardSystem | 公会战胜利更新排行榜 |
| 3 | GuildShopPurchaseChain | GuildSystem + PlayerDataManager + EventBus | 购买公会商店物品 |
| 4 | AchievementEventPropagation | AchievementSystem + EventBus + ProfileSystem | 成就解锁更新玩家资料 |
| 5 | GuildMemberCountAndRank | GuildSystem + LeaderboardSystem | 公会成员变化影响排行榜 |
| 6 | EquipmentUnlocksAchievement | EquipmentSystem + AchievementSystem | 装备解锁触发成就 |
| 7 | EquipmentEnhanceChain | EquipmentSystem + PlayerDataManager + EventBus | 强化消耗金币并发布事件 |
| 8 | SetBonusAndStats | EquipmentSystem + CharacterSystem | 套装效果与角色协同 |
| 9 | SeasonRewardEquipment | SeasonSystem + EquipmentSystem | 赛季奖励装备物品 |
| 10 | FullPlayerProfile | GuildSystem + AchievementSystem + EquipmentSystem + ProfileSystem | 综合玩家画像 |

**预期代码量**: ~250 行

---

## 六、完整任务时间线

### Week 1 (2026-08-20 ~ 2026-08-26) - 系统集成周

| 日期 | 任务 | 责任人 | 代码量估算 | 优先级 |
|------|------|--------|-----------|--------|
| Day 1 (08-20) | **Task 1**: 扩展 EventBus 添加 GUILD 和 EQUIPMENT 事件 | Dev A | ~30 行 | 🔴 极高 |
| Day 1 (08-20) | **Task 2**: 修复 GuildSystem 事件引用 | Dev A | ~10 行修改 | 🔴 极高 |
| Day 2 (08-21) | **Task 3**: 在 SystemManager 注册 GuildSystem + EquipmentSystem | Dev A | ~30 行 | 🔴 极高 |
| Day 2 (08-21) | **Task 4**: Config.lua 添加公会配置 | Dev B | ~60 行 | 🔴 极高 |
| Day 3 (08-22) | **Task 5.1**: 装备系统核心 - 解锁/装备/卸下 | Dev B | ~100 行 | 🔴 极高 |
| Day 4 (08-23) | **Task 5.2**: 装备系统核心 - 强化系统 | Dev B | ~80 行 | 🔴 极高 |
| Day 5 (08-24) | **Task 5.3**: 装备系统核心 - 属性计算 | Dev A | ~80 行 | 🔴 极高 |
| Day 5 (08-24) | **Task 5.4**: 装备系统核心 - 套装效果 | Dev A | ~80 行 | 🟡 高 |
| Day 6 (08-25) | **Task 6**: Config.lua 添加装备配置 | Dev B | ~80 行 | 🔴 极高 |
| Day 7 (08-26) | **Week 1 代码审查 & 修复** | All | - | - |

**Week 1 总计**: ~550 行新增代码

---

### Week 2 (2026-08-27 ~ 2026-09-02) - 测试与联动周

| 日期 | 任务 | 责任人 | 代码量估算 | 优先级 |
|------|------|--------|-----------|--------|
| Day 8 (08-27) | **Task 7**: TestEquipmentSystem 前 10 个用例 | Dev A | ~180 行 | 🔴 极高 |
| Day 9 (08-28) | **Task 7**: TestEquipmentSystem 剩余用例 | Dev A | ~120 行 | 🟡 高 |
| Day 10 (08-29) | **Task 8**: AchievementSystem 添加装备/公会成就 | Dev B | ~150 行 | 🟡 高 |
| Day 11 (08-30) | **Task 9**: SeasonSystem 装备奖励联动 | Dev B | ~80 行 | 🟡 高 |
| Day 12 (08-31) | **Task 10**: TestIntegrationV1_3 前 5 个测试 | Dev A | ~120 行 | 🟡 高 |
| Day 13 (09-01) | **Task 10**: TestIntegrationV1_3 剩余 5 个测试 | Dev A | ~130 行 | 🟡 高 |
| Day 14 (09-02) | **Week 2 代码审查 & 修复** | All | - | - |

**Week 2 总计**: ~780 行新增代码

---

### Week 3 (2026-09-03 ~ 2026-09-15) - 验证与发布周

| 日期 | 任务 | 责任人 | 代码量估算 | 优先级 |
|------|------|--------|-----------|--------|
| Day 15 (09-03) | **Task 11**: 运行所有单元测试并修复错误 | QA | - | 🔴 极高 |
| Day 16 (09-04) | **Task 12**: 运行集成测试并修复 | QA | - | 🔴 极高 |
| Day 17 (09-05) | **Task 13**: GameUI 公会面板 | Dev C | ~200 行 | 🟡 高 |
| Day 18 (09-06) | **Task 14**: GameUI 装备面板 | Dev C | ~200 行 | 🟡 高 |
| Day 19 (09-07) | **Task 15**: 手动测试 - 公会创建流程 | QA | - | 🟡 高 |
| Day 20 (09-08) | **Task 16**: 手动测试 - 装备/强化流程 | QA | - | 🟡 高 |
| Day 21 (09-09) | **Task 17**: 手动测试 - 赛季/成就/装备联动 | QA | - | 🟡 高 |
| Day 22 (09-10) | **Bug Fix Day** - 集中修复测试发现的问题 | All | - | 🔴 极高 |
| Day 23 (09-11) | **Task 18**: 性能测试与优化 | Dev A | ~30 行 | 🟢 中 |
| Day 24 (09-12) | **Task 19**: 更新 Config.Version 到 "1.4.0" | Dev A | 2 行 | 🔴 极高 |
| Day 25 (09-13) | **Task 20**: Release Notes 编写 | PM | ~50 行 | 🟡 高 |
| Day 26 (09-14) | **最终回归测试** | QA | - | 🔴 极高 |
| Day 27 (09-15) | **Release v1.4.0** | All | - | - |

**Week 3 总计**: ~430 行新增代码

---

## 七、总代码量估算

| 类别 | 代码量 |
|------|-------|
| EventBus 扩展 | ~30 行 |
| GuildSystem 修复 | ~10 行 |
| SystemManager 扩展 | ~30 行 |
| Config.lua 扩展 | ~140 行 |
| **EquipmentSystem.lua** | **~400 行** |
| AchievementSystem 成就扩展 | ~150 行 |
| SeasonSystem 装备奖励 | ~80 行 |
| **TestEquipmentSystem.lua** | **~300 行** |
| **TestIntegrationV1_3.lua** | **~250 行** |
| GameUI 公会面板 | ~200 行 |
| GameUI 装备面板 | ~200 行 |
| **总计** | **~1790 行** |

---

## 八、优先级矩阵

| 优先级 | 紧急度 | 影响度 | 任务 | 说明 |
|--------|--------|--------|------|------|
| 🔴 极高 | 10/10 | 10/10 | EventBus 扩展 + 系统注册 | 没有这个系统根本无法初始化 |
| 🔴 极高 | 10/10 | 9/10 | Config 公会/装备配置 + 装备系统核心 | 游戏的核心玩法依赖 |
| 🔴 极高 | 9/10 | 10/10 | 装备系统测试 | 保证核心功能正确 |
| 🟡 高 | 7/10 | 8/10 | 成就/赛季/交易联动 | 让系统有意义的联动功能 |
| 🟡 高 | 6/10 | 8/10 | GameUI 面板 | 玩家可见的界面 |
| 🟡 高 | 6/10 | 7/10 | 集成测试 | 验证跨系统协同 |
| 🟢 中 | 4/10 | 6/10 | 性能优化 | 非阻塞但重要 |
| ⚪ 低 | 2/10 | 3/10 | Release Notes | 最后编写 |

---

## 九、风险与应对策略

| # | 风险 | 概率 | 影响 | 应对策略 |
|---|------|------|------|---------|
| 1 | EventBus 事件名错误导致运行时报错 | 中 | 高 | 所有事件引用统一使用 EventBus.Events 常量，禁止手写字符串 |
| 2 | 装备属性计算影响平衡性 | 中 | 中 | 初期属性值设置保守，后续根据数据分析调整 |
| 3 | 公会+装备同时上线导致数据量过大 | 低 | 中 | 每个玩家装备数据仅 ~2KB，10万玩家也仅 200MB |
| 4 | 强化系统 RNG 导致玩家不满 | 低 | 高 | 保底机制：强化失败不降级，仅消耗金币 |
| 5 | 系统间事件循环触发 | 低 | 高 | 事件订阅使用命名空间避免循环，每个系统有唯一标识 |
| 6 | 配置热更新导致数据不一致 | 低 | 中 | 所有系统有 Reset() 函数，配置变更后统一重新加载 |

---

## 十、验收标准

### 10.1 功能验收

- [ ] **GuildSystem** 可以创建、加入、离开公会
- [ ] **GuildSystem** 可以添加贡献值、升级公会
- [ ] **GuildSystem** 可以发起公会战并获得奖励
- [ ] **GuildSystem** 可以在公会商店购买物品
- [ ] **EquipmentSystem** 可以解锁、装备、卸下物品
- [ ] **EquipmentSystem** 可以强化装备
- [ ] **EquipmentSystem** 属性计算正确
- [ ] **EquipmentSystem** 套装效果正确激活
- [ ] **AchievementSystem** 可以检测公会/装备相关成就
- [ ] **SeasonSystem** 可以奖励装备物品
- [ ] **EventBus** 所有 GUILD_* 和 EQUIPMENT_* 事件正常发布和订阅

### 10.2 测试验收

- [ ] **单元测试** 全部通过
  - TestEquipmentSystem: ≥18/18 通过
  - TestGuildSystem: 11/11 通过
  - TestAchievementSystem: 14/14 通过
  - 其他系统: 保持 100% 通过率
- [ ] **集成测试** 全部通过
  - TestIntegrationV1_3: ≥10/10 通过
  - TestIntegration (原有): 保持原有通过
- [ ] **代码覆盖率** ≥80%（核心系统）

### 10.3 性能验收

- [ ] 装备属性计算耗时 < 1ms（单次）
- [ ] 公会操作耗时 < 5ms（不含存储）
- [ ] 系统初始化耗时 < 100ms（含所有 12+系统）
- [ ] 事件发布/订阅耗时 < 1ms（单次事件）

---

## 十一、发布清单

发布前必须完成以下所有项：

- [ ] ✅ EventBus 添加 GUILD_* 和 EQUIPMENT_* 事件
- [ ] ✅ GuildSystem 使用正确的事件引用
- [ ] ✅ SystemManager 注册 GuildSystem 和 EquipmentSystem
- [ ] ✅ Config.lua 添加 Config.Guild 和 Config.GuildShop
- [ ] ✅ Config.lua 添加 Config.Equipment / EquipmentItems / EquipmentSets
- [ ] ✅ EquipmentSystem.lua 完成（400+行）
- [ ] ✅ AchievementSystem 添加公会/装备相关成就
- [ ] ✅ 所有单元测试通过（≥95%）
- [ ] ✅ 所有集成测试通过（100%）
- [ ] ✅ GameUI 公会面板
- [ ] ✅ GameUI 装备面板
- [ ] ✅ Config.Version 更新为 "1.4.0"
- [ ] ✅ Release Notes 编写完成
- [ ] ✅ 最终回归测试通过

---

## 十二、v1.5 前瞻（未来计划）

以下功能不在本计划内，但在后续版本中考虑：

| 功能 | 预期版本 | 说明 |
|------|---------|------|
| 跨服锦标赛 | v1.5 | 多服务器玩家互通对战 |
| 赛季战令 | v1.5 | 付费通行证系统 |
| 语音聊天 | v2.0 | 公会/团队战实时语音 |
| 自定义角色外观 | v1.5 | 角色自定义建模系统 |
| 故事模式 | v2.0 | 单人剧情模式 |
| 成就等级系统 | v1.4 | 已在此版本部分实现 |

---

## 十三、关键决策记录

| # | 决策 | 理由 | 影响范围 |
|---|------|------|---------|
| 1 | 装备系统不单独做存储层 | 玩家数据已有 PlayerDataManager，装备数据可以嵌入其中 | 简化架构 |
| 2 | 强化失败不降级 | 提升玩家体验，避免强烈挫败感 | 装备系统 |
| 3 | 公会系统直接内嵌商店 | 避免创建额外系统 | GuildSystem + 配置 |
| 4 | EventBus 事件名全大写+下划线 | 与现有系统保持一致（如 TOURNAMENT_WIN） | 所有代码 |
| 5 | 装备属性使用 additive 累加 | 简单直观，玩家易理解 | EquipmentSystem |

---

## 十四、参考文件清单

开发时参考的现有系统文件：

| 参考源文件 | 目的 |
|-----------|------|
| `TournamentSystem.lua` | 参考系统结构、事件发布模式 |
| `SkinSystem.lua` | 参考解锁/装备系统的实现模式 |
| `TeamBattleSystem.lua` | 参考团队战的实现（类似公会战） |
| `ItemSetSystem.lua` | 参考套装效果的检测逻辑 |
| `SeasonSystem.lua` | 参考等级奖励的实现 |
| `TestIntegration.lua` | 参考集成测试的写法 |
| `Config.lua` | 参考现有配置节点的写法 |
| `EventBus.lua` | 参考事件命名规范 |

---

## 十五、FAQ

### Q1: 为什么不直接在 v1.3.0 包含所有功能，还要分 Phase？
**A**: 因为之前已创建的 GuildSystem 和 AchievementSystem 扩展需要先完成集成才能运行。先解决这些问题，再开发 EquipmentSystem，避免同时处理过多未完成的工作。

### Q2: 装备系统为什么需要这么多行代码？
**A**: 装备系统包含：装备槽位管理（4个槽位）、解锁状态追踪、强化系统（10级）、属性计算（9种属性类型）、套装检测（多件组合效果）、事件发布/订阅（6+事件）。参考 TournamentSystem.lua 约 300 行，装备系统略复杂。

### Q3: 为什么属性计算不用更复杂的公式系统？
**A**: 初期采用简单加法 + 全局乘数（globalBonus）。这样：
- 代码易读易维护
- 性能高（O(n) n=槽位数）
- 玩家容易理解和计算
- 后续如有需求，可升级为 modifier 系统

### Q4: EventBus 事件从 40 个增加到 55 个，会不会太多？
**A**: 不会。每个系统通常有 3-8 个事件（初始化/状态变化/完成/错误等）。14 个游戏系统 × 平均 4 个事件 = 56 个事件是合理的。

### Q5: 装备系统的物品来源是什么？
**A**: 主要来源：
1. 赛季等级奖励（Config.Seasons.levelRewards）
2. 公会商店购买
3. 成就解锁奖励
4. 交易市场购买（如启用）
5. 限时活动奖励（EventModeSystem）

---

**文档结束**
