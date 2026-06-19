-- ============================================================================
-- SeasonSystem.lua - 赛季系统
-- ----------------------------------------------------------------------------
-- 功能：
--   1. 赛季周期管理（每 14 天一个赛季）
--   2. 赛季经验值与等级系统（1-50 级）
--   3. 赛季奖励解锁（每级一个奖励）
--   4. 与 EventBus 集成：自动响应 game_end, item_collect 等事件
--   5. serverCloud 持久化保存进度
--
-- 使用：
--   local SeasonSystem = require("Game.SeasonSystem")
--   SeasonSystem.RegisterEvents()   -- 注册事件监听（由 SystemManager 调用）
--   SeasonSystem.AddExp(playerId, 50)  -- 手动添加经验
-- ============================================================================

local Config = require("Config")
local EventBus = require("Utils.EventBus")

local SeasonSystem = {}

-- ============================================================================
-- 内部状态
-- ============================================================================
local _eventsRegistered = false

-- ============================================================================
-- 获取玩家赛季数据（从 serverCloud 加载）
-- ============================================================================
local function _GetSeasonData(playerId)
    if not serverCloud or not serverCloud.game or not serverCloud.game.season then
        return nil
    end

    local uid = playerId or "default"
    local data = serverCloud.game.season:Get(uid, {
        seasonId    = SeasonSystem.GetCurrentSeasonId(),
        level       = 1,
        exp         = 0,
        totalExp    = 0,
        lastUpdate  = os and os.time() or 0,
        claimedRewards = {},  -- 已领取的奖励等级
        stats       = {
            gamesPlayed = 0,
            gamesWon   = 0,
            itemsCollected = 0,
            skillsUsed = 0
        }
    })

    return data
end

-- ============================================================================
-- 保存玩家赛季数据
-- ============================================================================
local function _SaveSeasonData(playerId, data)
    if not serverCloud or not serverCloud.game or not serverCloud.game.season then
        return false
    end

    local uid = playerId or "default"
    if os and os.time then
        data.lastUpdate = os.time()
    end

    serverCloud.game.season:Post(uid, data)
    return true
end

-- ============================================================================
-- 获取当前赛季 ID（基于日期计算）
-- ============================================================================
function SeasonSystem.GetCurrentSeasonId()
    if not Config.Seasons then
        return "S001"
    end

    -- 基于起始日期计算当前赛季
    local startDate = Config.Seasons.StartDate or "2026-06-19"
    local seasonDuration = Config.Seasons.DurationDays or 14

    -- 简单实现：根据时间戳差计算
    if os and os.time and os.date then
        -- 解析起始日期
        local year, month, day = string.match(startDate, "(%d+)-(%d+)-(%d+)")
        if year and month and day then
            local startTime = os.time({
                year = tonumber(year),
                month = tonumber(month),
                day = tonumber(day),
                hour = 0,
                min = 0,
                sec = 0
            })
            local currentTime = os.time()
            local daysPassed = math.floor((currentTime - startTime) / (24 * 60 * 60))
            local seasonNumber = math.floor(daysPassed / seasonDuration) + 1
            return string.format("S%03d", seasonNumber)
        end
    end

    return "S001"
end

-- ============================================================================
-- 获取升级所需经验
-- ============================================================================
function SeasonSystem.GetExpForLevel(level)
    if not Config.Seasons then
        return 100 * level
    end

    -- 基础经验 + 递增
    local baseExp = Config.Seasons.BaseExpPerLevel or 100
    local growth = Config.Seasons.ExpGrowthFactor or 1.2

    return math.floor(baseExp * math.pow(growth, level - 1))
end

-- ============================================================================
-- 获取当前赛季配置
-- ============================================================================
function SeasonSystem.GetSeasonConfig()
    if not Config.Seasons then
        return {
            Name = "第一赛季·初露锋芒",
            DurationDays = 14,
            MaxLevel = 50,
            BaseExpPerLevel = 100,
            ExpGrowthFactor = 1.2
        }
    end
    return Config.Seasons
end

-- ============================================================================
-- 添加经验值（核心方法）
-- ============================================================================
function SeasonSystem.AddExp(playerId, amount, reason)
    if not amount or amount <= 0 then return 0 end

    local data = _GetSeasonData(playerId)
    if not data then
        print("[SeasonSystem] 无法获取赛季数据")
        return 0
    end

    -- 检查赛季 ID 是否匹配，不匹配则重置
    local currentSeason = SeasonSystem.GetCurrentSeasonId()
    if data.seasonId ~= currentSeason then
        print("[SeasonSystem] 赛季已变化，从 " .. tostring(data.seasonId) .. " 到 " .. currentSeason .. "，重置进度")
        data.seasonId = currentSeason
        data.level = 1
        data.exp = 0
        data.claimedRewards = {}
    end

    local seasonConfig = SeasonSystem.GetSeasonConfig()
    local oldLevel = data.level
    data.exp = data.exp + amount
    data.totalExp = (data.totalExp or 0) + amount

    -- 检查升级
    local levelsGained = 0
    while data.level < (seasonConfig.MaxLevel or 50) do
        local expNeeded = SeasonSystem.GetExpForLevel(data.level)
        if data.exp >= expNeeded then
            data.exp = data.exp - expNeeded
            data.level = data.level + 1
            levelsGained = levelsGained + 1
        else
            break
        end
    end

    -- 保存
    _SaveSeasonData(playerId, data)

    -- 发布事件
    EventBus.Publish(EventBus.Events.SEASON_PROGRESS, {
        playerId = playerId,
        level = data.level,
        exp = data.exp,
        expGained = amount,
        reason = reason or "unknown",
        levelsGained = levelsGained
    })

    if levelsGained > 0 then
        EventBus.Publish(EventBus.Events.SEASON_LEVELUP, {
            playerId = playerId,
            oldLevel = oldLevel,
            newLevel = data.level,
            levelsGained = levelsGained
        })
        print("[SeasonSystem] 🎉 " .. (playerId or "玩家") .. " 升级到 " .. data.level .. " 级！")
    end

    return levelsGained
end

-- ============================================================================
-- 获取玩家赛季状态
-- ============================================================================
function SeasonSystem.GetPlayerStatus(playerId)
    local data = _GetSeasonData(playerId)
    if not data then return nil end

    local seasonConfig = SeasonSystem.GetSeasonConfig()
    local expForCurrent = SeasonSystem.GetExpForLevel(data.level)
    local expForNext = SeasonSystem.GetExpForLevel(data.level + 1)

    return {
        seasonId = data.seasonId,
        seasonName = seasonConfig.Name or "未知赛季",
        level = data.level,
        maxLevel = seasonConfig.MaxLevel or 50,
        currentExp = data.exp,
        nextLevelExp = expForNext,
        progressPercent = math.min(100, math.floor(data.exp / expForNext * 100)),
        totalExp = data.totalExp or 0,
        claimedRewards = data.claimedRewards or {},
        stats = data.stats or {}
    }
end

-- ============================================================================
-- 获取指定等级的奖励配置
-- ============================================================================
function SeasonSystem.GetReward(level)
    if not Config.Seasons or not Config.Seasons.Rewards then
        -- 默认奖励配置
        local rewards = {
            [1]  = { type = "gold", amount = 100,  name = "新手礼包" },
            [5]  = { type = "gold", amount = 300,  name = "成长奖励" },
            [10] = { type = "gold", amount = 500,  name = "小有所成" },
            [15] = { type = "item", rarity = 2,    name = "稀有藏品" },
            [20] = { type = "gold", amount = 1000, name = "经验丰富" },
            [25] = { type = "title", id = "T001", name = "竞拍达人" },
            [27] = { type = "equipment", equipmentId = "weapon_gold_sword", name = "金币剑" },
            [30] = { type = "gold", amount = 2000, name = "精英收藏家" },
            [35] = { type = "item", rarity = 3, name = "史诗藏品" },
            [37] = { type = "equipment", equipmentId = "acc_lucky_coin", name = "幸运硬币" },
            [40] = { type = "gold", amount = 5000, name = "大师级别" },
            [42] = { type = "equipment", equipmentId = "armor_leather_vest", name = "皮甲背心" },
            [45] = { type = "title", id = "T002", name = "传奇收藏家" },
            [47] = { type = "equipment", equipmentId = "badge_silver_star", name = "银星徽章" },
            [50] = { type = "item", rarity = 4,    name = "传说藏品" }
        }
        return rewards[level]
    end

    return Config.Seasons.Rewards[level]
end

-- ============================================================================
-- 检查是否可以领取某等级奖励
-- ============================================================================
function SeasonSystem.CanClaimReward(playerId, level)
    local data = _GetSeasonData(playerId)
    if not data then return false end

    -- 必须达到该等级
    if data.level < level then return false end

    -- 该等级必须有奖励
    if not SeasonSystem.GetReward(level) then return false end

    -- 必须未领取
    for _, claimed in ipairs(data.claimedRewards or {}) do
        if claimed == level then return false end
    end

    return true
end

-- ============================================================================
-- 领取等级奖励
-- ============================================================================
function SeasonSystem.ClaimReward(playerId, level)
    if not SeasonSystem.CanClaimReward(playerId, level) then
        print("[SeasonSystem] 无法领取奖励：等级 " .. tostring(level))
        return nil
    end

    local reward = SeasonSystem.GetReward(level)
    if not reward then return nil end

    local data = _GetSeasonData(playerId)

    -- 标记为已领取
    data.claimedRewards = data.claimedRewards or {}
    table.insert(data.claimedRewards, level)

    _SaveSeasonData(playerId, data)

    -- 如果是装备类型，自动解锁
    if reward.type == "equipment" and reward.equipmentId then
        -- 检查是否有 EquipmentSystem
        local ok, err = pcall(function()
            if EquipmentSystem then
                local unlockOk, err2 = EquipmentSystem.Unlock(playerId, reward.equipmentId)
                print("[SeasonSystem] 🔧 装备解锁: " .. reward.equipmentId .. " (uid=" .. tostring(playerId) .. ")")
            end
        end)
    end

    -- 发布奖励领取事件
    EventBus.Publish(EventBus.Events.SEASON_LEVELUP, {
        uid = playerId,
        level = level,
        rewardType = reward.type,
        rewardAmount = reward.amount,
        rewardEquipment = reward.equipmentId,
        rewardName = reward.name,
        rewardRarity = reward.rarity,
    })

    print("[SeasonSystem] 🏆 " .. (playerId or "玩家") .. " 领取 " .. level .. " 级奖励：" .. reward.name)

    return reward
end

-- ============================================================================
-- 获取可领取但未领取的奖励列表
-- ============================================================================
function SeasonSystem.GetUnclaimedRewards(playerId)
    local data = _GetSeasonData(playerId)
    if not data then return {} end

    local unclaimed = {}
    local seasonConfig = SeasonSystem.GetSeasonConfig()
    local maxLevel = math.min(data.level, seasonConfig.MaxLevel or 50)

    for level = 1, maxLevel do
        if SeasonSystem.GetReward(level) then
            local claimed = false
            for _, c in ipairs(data.claimedRewards or {}) do
                if c == level then
                    claimed = true
                    break
                end
            end
            if not claimed then
                table.insert(unclaimed, {
                    level = level,
                    reward = SeasonSystem.GetReward(level)
                })
            end
        end
    end

    return unclaimed
end

-- ============================================================================
-- 更新游戏统计（局数、胜场等）
-- ============================================================================
function SeasonSystem.UpdateStats(playerId, statName, increment)
    local data = _GetSeasonData(playerId)
    if not data then return false end

    data.stats = data.stats or {}
    data.stats[statName] = (data.stats[statName] or 0) + (increment or 1)

    _SaveSeasonData(playerId, data)
    return true
end

-- ============================================================================
-- 注册事件监听（通过 EventBus）
-- ============================================================================
function SeasonSystem.RegisterEvents()
    if _eventsRegistered then return end
    _eventsRegistered = true

    if not EventBus then return end

    -- 游戏结束：根据胜负给予经验
    EventBus.Subscribe(EventBus.Events.GAME_END, function(data)
        if not data then return end

        local playerId = data.playerId or data.uid or data.seat
        local isWinner = data.isWinner or data.winner or false

        local expAmount = isWinner and 50 or 20
        SeasonSystem.AddExp(playerId, expAmount, isWinner and "game_win" or "game_play")

        -- 更新统计
        SeasonSystem.UpdateStats(playerId, "gamesPlayed", 1)
        if isWinner then
            SeasonSystem.UpdateStats(playerId, "gamesWon", 1)
        end
    end, "SeasonSystem")

    -- 获得藏品：每件藏品给予少量经验
    EventBus.Subscribe(EventBus.Events.ITEM_COLLECT, function(data)
        if not data then return end

        local playerId = data.playerId or data.uid or data.seat
        local rarity = data.rarity or 1

        -- 根据稀有度给予经验：普通=10, 稀有=20, 史诗=40, 传说=100
        local expTable = { 10, 20, 40, 100 }
        local expAmount = expTable[rarity] or 10
        SeasonSystem.AddExp(playerId, expAmount, "item_collect_rarity_" .. rarity)

        SeasonSystem.UpdateStats(playerId, "itemsCollected", 1)
    end, "SeasonSystem")

    -- 技能使用：每次使用给予少量经验
    EventBus.Subscribe(EventBus.Events.SKILL_USE, function(data)
        if not data then return end

        local playerId = data.playerId or data.uid or data.seat
        SeasonSystem.AddExp(playerId, 5, "skill_use")
        SeasonSystem.UpdateStats(playerId, "skillsUsed", 1)
    end, "SeasonSystem")

    print("[SeasonSystem] 事件监听已注册")
end

-- ============================================================================
-- 获取赛季剩余时间（秒）
-- ============================================================================
function SeasonSystem.GetSeasonTimeRemaining()
    if not os or not os.time then
        return 14 * 24 * 60 * 60  -- 默认 14 天
    end

    local seasonConfig = SeasonSystem.GetSeasonConfig()
    local startDate = seasonConfig.StartDate or "2026-06-19"
    local duration = seasonConfig.DurationDays or 14

    local year, month, day = string.match(startDate, "(%d+)-(%d+)-(%d+)")
    if not year then return 0 end

    local startTime = os.time({
        year = tonumber(year), month = tonumber(month),
        day = tonumber(day), hour = 0, min = 0, sec = 0
    })
    local currentTime = os.time()
    local seasonNumber = math.floor((currentTime - startTime) / (duration * 24 * 60 * 60))
    local seasonEnd = startTime + (seasonNumber + 1) * duration * 24 * 60 * 60

    return seasonEnd - currentTime
end

-- ============================================================================
-- 格式化剩余时间为 "X 天 X 小时"
-- ============================================================================
function SeasonSystem.FormatTimeRemaining(seconds)
    seconds = seconds or SeasonSystem.GetSeasonTimeRemaining()
    local days = math.floor(seconds / (24 * 60 * 60))
    local hours = math.floor((seconds % (24 * 60 * 60)) / (60 * 60))
    return days .. " 天 " .. hours .. " 小时"
end

-- ============================================================================
-- 重置玩家赛季数据（调试用或赛季重置）
-- ============================================================================
function SeasonSystem.Reset(playerId)
    local data = {
        seasonId = SeasonSystem.GetCurrentSeasonId(),
        level = 1,
        exp = 0,
        totalExp = 0,
        lastUpdate = os and os.time() or 0,
        claimedRewards = {},
        stats = {
            gamesPlayed = 0,
            gamesWon = 0,
            itemsCollected = 0,
            skillsUsed = 0
        }
    }
    _SaveSeasonData(playerId, data)
    print("[SeasonSystem] " .. (playerId or "玩家") .. " 的赛季数据已重置")
    return data
end

return SeasonSystem
