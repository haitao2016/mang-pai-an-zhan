-- ============================================================================
-- AchievementSystem.lua - 成就系统
-- 10 个成就，自动检测条件，发放金币奖励
-- 持久化存储：serverCloud
-- ============================================================================

local Config = require("Config")
local EventBus = require("Utils.EventBus")
local cjson  = require("cjson")

local AchievementSystem = {}

-- ============================================================================
-- v1.3 成就等级与类别定义
-- ============================================================================
AchievementSystem.Levels = {
    { id = "copper",   name = "铜",  color = "#CD7F32", icon = "🥉" },
    { id = "silver",   name = "银",  color = "#C0C0C0", icon = "🥈" },
    { id = "gold",     name = "金",  color = "#FFD700", icon = "🥇" },
    { id = "platinum", name = "铂金", color = "#E5E4E2", icon = "⭐" },
    { id = "diamond",  name = "钻石", color = "#B9F2FF", icon = "💎" },
}

AchievementSystem.Categories = {
    { id = "competition", name = "竞技", icon = "🏆" },
    { id = "social",      name = "社交", icon = "👥" },
    { id = "collection",  name = "收集", icon = "📦" },
    { id = "growth",      name = "成长", icon = "📈" },
    { id = "special",     name = "特殊", icon = "🎯", hidden = false },
}

-- ============================================================================
-- 成就定义
-- ============================================================================

-- 已完成的成就 ID 集合，每个玩家一份
-- 格式: { [uid] = { ["first_win"] = true, ... } }
local unlockedAchievements_ = {}

-- 玩家的成就统计数据
-- 格式: { [uid] = { win_count = 0, game_count = 0, speed_win_count = 0, ... } }
local stats_ = {}

-- 是否已加载的标记
local loaded_ = {}

-- ============================================================================
-- 辅助函数
-- ============================================================================

--- 获取玩家的统计数据
---@param uid number
---@return table
local function _GetStats(uid)
    if not stats_[uid] then
        stats_[uid] = {
            win_count = 0,           -- 胜场数
            game_count = 0,          -- 参与局数
            speed_win_count = 0,     -- 速胜次数
            collected_items = 0,     -- 累计藏品数
            legend_count = 0,        -- 传说级藏品数
            top2_rounds = 0,         -- 单局前2名回合数
            positive_gain = 0,       -- 正收益局数
            hall_victory = {},       -- 各厅获胜记录 { "hall_beginner" = true, ... }
            collection_value = 0,    -- 累计收藏价值
            skill_uses = 0,          -- 技能使用次数
            -- v1.3 扩展统计字段
            auction_count = 0,       -- 拍卖次数
            win_streak = 0,          -- 当前连胜
            max_win_streak = 0,      -- 历史最高连胜
            lose_streak = 0,         -- 当前连败
            tournament_wins = 0,     -- 锦标赛胜场
            team_battle_count = 0,   -- 团队战次数
            guild_contribution = 0,  -- 公会贡献值累计
            skin_unlocks = 0,        -- 皮肤解锁数
            total_gold = 0,          -- 累计获得金币
            login_days = 1,          -- 累计登录天数
            total_balance = 0,       -- 累计最终余额（正收益总和）
            perfect_rounds = 0,      -- 完美回合（排名第一的次数）
        }
    end
    return stats_[uid]
end

--- 获取玩家的成就集合
---@param uid number
---@return table
local function _GetUnlocked(uid)
    if not unlockedAchievements_[uid] then
        unlockedAchievements_[uid] = {}
    end
    return unlockedAchievements_[uid]
end

-- ============================================================================
-- 加载与保存
-- ============================================================================

--- 加载玩家的成就数据
---@param uid number
---@param callback fun(ok: boolean)|nil 完成回调
function AchievementSystem.LoadPlayerData(uid, callback)
    if loaded_[uid] then
        if callback then callback(true) end
        return
    end

    print(string.format("[AchievementSystem] Loading for uid=%s", tostring(uid)))

    serverCloud.game.achievement:Get(uid, {
        ok = function(data)
            local stats = _GetStats(uid)
            local unlocked = _GetUnlocked(uid)

            for _, entry in ipairs(data) do
                if entry.key == "stats_json" then
                    local ok2, parsed = pcall(cjson.decode, entry.value)
                    if ok2 and type(parsed) == "table" then
                        for k, v in pairs(parsed) do
                            stats[k] = v
                        end
                    end
                elseif entry.key == "unlocked_json" then
                    local ok2, parsed = pcall(cjson.decode, entry.value)
                    if ok2 and type(parsed) == "table" then
                        for id, _ in pairs(parsed) do
                            unlocked[id] = true
                        end
                    end
                end
            end

            loaded_[uid] = true
            print(string.format("[AchievementSystem] Loaded for uid=%s", tostring(uid)))
            if callback then callback(true) end
        end,
        err = function(msg)
            print(string.format("[AchievementSystem] Load failed: %s", tostring(msg)))
            loaded_[uid] = true  -- 标记已尝试，避免重复请求
            if callback then callback(false) end
        end,
    })
end

--- 保存玩家的成就数据
---@param uid number
function AchievementSystem.SavePlayerData(uid)
    if not loaded_[uid] then
        print(string.format("[AchievementSystem] Save skipped, not loaded for uid=%s", tostring(uid)))
        return
    end

    local stats = _GetStats(uid)
    local unlocked = _GetUnlocked(uid)

    print(string.format("[AchievementSystem] Saving for uid=%s", tostring(uid)))

    local ok1, statsJson = pcall(cjson.encode, stats)
    if ok1 then
        serverCloud.game.achievement:Post(uid, {
            key = "stats_json",
            value = statsJson,
        })
    end

    local ok2, unlockedJson = pcall(cjson.encode, unlocked)
    if ok2 then
        serverCloud.game.achievement:Post(uid, {
            key = "unlocked_json",
            value = unlockedJson,
        })
    end
end

-- ============================================================================
-- 事件记录接口
-- ============================================================================

--- 记录一次胜利
---@param uid number
---@param hallId string 拍卖厅 ID
---@param finalBalance number 最终余额
---@param initialFunds number 初始资金
---@return table newlyUnlocked 本次新解锁的成就列表
function AchievementSystem.RecordVictory(uid, hallId, finalBalance, initialFunds)
    local stats = _GetStats(uid)
    stats.win_count = stats.win_count + 1
    stats.game_count = stats.game_count + 1

    -- 连胜/连败
    stats.win_streak = stats.win_streak + 1
    stats.lose_streak = 0
    if stats.win_streak > stats.max_win_streak then
        stats.max_win_streak = stats.win_streak
    end

    if hallId then
        stats.hall_victory[hallId] = true
    end

    -- 计算正收益
    if finalBalance and initialFunds then
        if finalBalance > initialFunds then
            stats.positive_gain = stats.positive_gain + 1
            stats.total_balance = stats.total_balance + (finalBalance - initialFunds)
        end
        stats.total_gold = stats.total_gold + math.max(0, finalBalance - initialFunds)
    end

    return AchievementSystem._CheckAllAchievements(uid)
end

--- 记录一次游戏结束（失败）
---@param uid number
function AchievementSystem.RecordGameEnd(uid)
    local stats = _GetStats(uid)
    stats.game_count = stats.game_count + 1
    stats.lose_streak = stats.lose_streak + 1
    stats.win_streak = 0
    return AchievementSystem._CheckAllAchievements(uid)
end

--- 记录一次速胜
---@param uid number
function AchievementSystem.RecordSpeedWin(uid)
    local stats = _GetStats(uid)
    stats.speed_win_count = stats.speed_win_count + 1
    return AchievementSystem._CheckAllAchievements(uid)
end

--- 记录获得藏品
---@param uid number
---@param rarity number 稀有度等级 1-4
---@param value number 藏品价值
function AchievementSystem.RecordItemObtained(uid, rarity, value)
    local stats = _GetStats(uid)
    stats.collected_items = stats.collected_items + 1
    stats.collection_value = stats.collection_value + (value or 0)

    if rarity == 4 then
        stats.legend_count = stats.legend_count + 1
    end

    return AchievementSystem._CheckAllAchievements(uid)
end

--- 记录本局每轮出价排名
---@param uid number
---@param rankList number[] 每轮排名（1=第一，2=第二...）
function AchievementSystem.RecordBidRanks(uid, rankList)
    local stats = _GetStats(uid)
    local top2Count = 0
    local perfectCount = 0
    for _, rank in ipairs(rankList) do
        if rank <= 2 then
            top2Count = top2Count + 1
        end
        if rank == 1 then
            perfectCount = perfectCount + 1
        end
    end

    if top2Count > stats.top2_rounds then
        stats.top2_rounds = top2Count
    end
    stats.perfect_rounds = stats.perfect_rounds + perfectCount

    return AchievementSystem._CheckAllAchievements(uid)
end

--- 记录技能使用
---@param uid number
function AchievementSystem.RecordSkillUse(uid)
    local stats = _GetStats(uid)
    stats.skill_uses = stats.skill_uses + 1
    return AchievementSystem._CheckAllAchievements(uid)
end

-- ============================================================================
-- v1.3 新增记录接口
-- ============================================================================

--- 记录一次拍卖
---@param uid number
function AchievementSystem.RecordAuction(uid)
    local stats = _GetStats(uid)
    stats.auction_count = stats.auction_count + 1
    return AchievementSystem._CheckAllAchievements(uid)
end

--- 记录锦标赛胜利
---@param uid number
---@param tournamentId string
function AchievementSystem.RecordTournamentWin(uid, tournamentId)
    local stats = _GetStats(uid)
    stats.tournament_wins = stats.tournament_wins + 1
    return AchievementSystem._CheckAllAchievements(uid)
end

--- 记录团队战
---@param uid number
---@param isWin boolean 是否胜利
function AchievementSystem.RecordTeamBattle(uid, isWin)
    local stats = _GetStats(uid)
    stats.team_battle_count = stats.team_battle_count + 1
    if isWin then
        return AchievementSystem._CheckAllAchievements(uid)
    end
    return {}
end

--- 记录公会贡献
---@param uid number
---@param amount number 贡献值
function AchievementSystem.RecordGuildContribution(uid, amount)
    local stats = _GetStats(uid)
    stats.guild_contribution = stats.guild_contribution + (amount or 0)
    return AchievementSystem._CheckAllAchievements(uid)
end

--- 记录皮肤解锁
---@param uid number
function AchievementSystem.RecordSkinUnlock(uid)
    local stats = _GetStats(uid)
    stats.skin_unlocks = stats.skin_unlocks + 1
    return AchievementSystem._CheckAllAchievements(uid)
end

--- 记录登录
---@param uid number
function AchievementSystem.RecordLogin(uid)
    local stats = _GetStats(uid)
    stats.login_days = stats.login_days + 1
    return AchievementSystem._CheckAllAchievements(uid)
end

--- 记录金币获得
---@param uid number
---@param amount number
function AchievementSystem.RecordGoldObtained(uid, amount)
    local stats = _GetStats(uid)
    stats.total_gold = stats.total_gold + (amount or 0)
    return AchievementSystem._CheckAllAchievements(uid)
end

-- ============================================================================
-- 成就检查
-- ============================================================================

--- 检查所有成就条件
---@param uid number
---@return table 本次新解锁的成就列表
function AchievementSystem._CheckAllAchievements(uid)
    local unlocked = _GetUnlocked(uid)
    local stats = _GetStats(uid)
    local newlyUnlocked = {}
    local events = Config.Achievements

    if not events or #events == 0 then
        return newlyUnlocked
    end

    for _, achievement in ipairs(events) do
        if not unlocked[achievement.id] then
            local ok = AchievementSystem._CheckCondition(achievement, stats)
            if ok then
                unlocked[achievement.id] = true

                -- v1.3: 发布成就解锁事件
                if EventBus and EventBus.Publish and EventBus.Events then
                    EventBus.Publish(EventBus.Events.ACHIEVEMENT_UNLOCK, {
                        uid = uid,
                        achievementId = achievement.id,
                        name = achievement.name,
                        level = achievement.level or "gold",
                        category = achievement.category or "growth",
                        reward = achievement.reward or 100,
                    })
                end

                table.insert(newlyUnlocked, {
                    id = achievement.id,
                    name = achievement.name,
                    desc = achievement.desc,
                    reward = achievement.reward,
                    level = achievement.level or "gold",
                    category = achievement.category or "growth",
                })
                print(string.format("[AchievementSystem] 成就解锁: %s (uid=%s, level=%s)",
                    achievement.name, tostring(uid), achievement.level or "gold"))
            end
        end
    end

    return newlyUnlocked
end

--- 检查单个成就条件
---@param achievement table
---@param stats table
---@return boolean
function AchievementSystem._CheckCondition(achievement, stats)
    local t = achievement.checkType
    local v = achievement.checkValue

    if t == "win_count" then
        return stats.win_count >= v

    elseif t == "game_count" then
        return stats.game_count >= v

    elseif t == "speed_win_count" then
        return stats.speed_win_count >= v

    elseif t == "collected_items" then
        return stats.collected_items >= v

    elseif t == "legend_count" then
        return stats.legend_count >= v

    elseif t == "top2_rounds" then
        return stats.top2_rounds >= v

    elseif t == "positive_gain" then
        return stats.positive_gain >= v

    elseif t == "hall_victory" then
        local winCount = 0
        for _, _ in pairs(stats.hall_victory) do
            winCount = winCount + 1
        end
        return winCount >= v

    elseif t == "collection_value" then
        return stats.collection_value >= v

    elseif t == "skill_uses" then
        return stats.skill_uses >= v

    -- v1.3 新增检查类型
    elseif t == "auction_count" then
        return stats.auction_count >= v

    elseif t == "max_win_streak" then
        return stats.max_win_streak >= v

    elseif t == "tournament_wins" then
        return stats.tournament_wins >= v

    elseif t == "team_battle_count" then
        return stats.team_battle_count >= v

    elseif t == "guild_contribution" then
        return stats.guild_contribution >= v

    elseif t == "skin_unlocks" then
        return stats.skin_unlocks >= v

    elseif t == "total_gold" then
        return stats.total_gold >= v

    elseif t == "login_days" then
        return stats.login_days >= v

    elseif t == "total_balance" then
        return stats.total_balance >= v

    elseif t == "perfect_rounds" then
        return stats.perfect_rounds >= v
    end

    return false
end

-- ============================================================================
-- 查询接口
-- ============================================================================

--- 获取玩家已解锁的成就数量
---@param uid number
---@return number
function AchievementSystem.GetUnlockedCount(uid)
    local unlocked = _GetUnlocked(uid)
    local count = 0
    for _, _ in pairs(unlocked) do
        count = count + 1
    end
    return count
end

--- 获取总成就数
---@return number
function AchievementSystem.GetTotalCount()
    return #Config.Achievements
end

--- 获取玩家某个统计项的值
---@param uid number
---@param statKey string
---@return number
function AchievementSystem.GetStat(uid, statKey)
    local stats = _GetStats(uid)
    local val = stats[statKey]
    if type(val) == "table" then
        local count = 0
        for _, _ in pairs(val) do count = count + 1 end
        return count
    end
    return val or 0
end

--- 检查某个成就是否解锁
---@param uid number
---@param achievementId string
---@return boolean
function AchievementSystem.IsUnlocked(uid, achievementId)
    local unlocked = _GetUnlocked(uid)
    return unlocked[achievementId] == true
end

--- 获取玩家的完整成就列表（含进度）
---@param uid number
---@return table
function AchievementSystem.GetAchievementList(uid)
    local unlocked = _GetUnlocked(uid)
    local stats = _GetStats(uid)
    local list = {}

    local achievements = Config.Achievements or {}

    for _, achievement in ipairs(achievements) do
        local progress = 0
        local current = 0

        if achievement.checkType == "hall_victory" then
            current = 0
            for _, _ in pairs(stats.hall_victory) do
                current = current + 1
            end
        elseif achievement.checkType == "positive_gain" then
            current = stats.positive_gain or 0
        else
            current = stats[achievement.checkType] or 0
        end

        progress = math.min(1.0, current / achievement.checkValue)

        table.insert(list, {
            id = achievement.id,
            name = achievement.name,
            desc = achievement.desc,
            reward = achievement.reward,
            level = achievement.level or "gold",
            category = achievement.category or "growth",
            unlocked = unlocked[achievement.id] == true,
            progress = progress,
            current = current,
            target = achievement.checkValue,
        })
    end

    return list
end

-- ============================================================================
-- v1.3 新增查询接口
-- ============================================================================

--- 按等级获取成就列表
---@param uid number
---@param levelId string copper/silver/gold/platinum/diamond
---@return table
function AchievementSystem.GetAchievementsByLevel(uid, levelId)
    local list = AchievementSystem.GetAchievementList(uid)
    local filtered = {}
    for _, a in ipairs(list) do
        if a.level == levelId then
            table.insert(filtered, a)
        end
    end
    return filtered
end

--- 按类别获取成就列表
---@param uid number
---@param categoryId string competition/social/collection/growth/special
---@return table
function AchievementSystem.GetAchievementsByCategory(uid, categoryId)
    local list = AchievementSystem.GetAchievementList(uid)
    local filtered = {}
    for _, a in ipairs(list) do
        if a.category == categoryId then
            table.insert(filtered, a)
        end
    end
    return filtered
end

--- 获取玩家的成就统计汇总
---@param uid number
---@return table
function AchievementSystem.GetAchievementSummary(uid)
    local list = AchievementSystem.GetAchievementList(uid)
    local unlocked = _GetUnlocked(uid)
    local stats = _GetStats(uid)

    local summary = {
        totalCount = #list,
        unlockedCount = 0,
        totalReward = 0,
        byLevel = { copper = 0, silver = 0, gold = 0, platinum = 0, diamond = 0 },
        byCategory = { competition = 0, social = 0, collection = 0, growth = 0, special = 0 },
        unlockedByLevel = { copper = 0, silver = 0, gold = 0, platinum = 0, diamond = 0 },
        unlockedByCategory = { competition = 0, social = 0, collection = 0, growth = 0, special = 0 },
        recentUnlocks = {},
        stats = stats,
    }

    for _, a in ipairs(list) do
        if summary.byLevel[a.level] then
            summary.byLevel[a.level] = summary.byLevel[a.level] + 1
        end
        if summary.byCategory[a.category] then
            summary.byCategory[a.category] = summary.byCategory[a.category] + 1
        end

        if a.unlocked then
            summary.unlockedCount = summary.unlockedCount + 1
            summary.totalReward = summary.totalReward + (a.reward or 0)
            if summary.unlockedByLevel[a.level] then
                summary.unlockedByLevel[a.level] = summary.unlockedByLevel[a.level] + 1
            end
            if summary.unlockedByCategory[a.category] then
                summary.unlockedByCategory[a.category] = summary.unlockedByCategory[a.category] + 1
            end
        end
    end

    -- 完成度百分比
    summary.completionRate = summary.totalCount > 0 and (summary.unlockedCount / summary.totalCount) or 0

    return summary
end

--- 获取成就等级的元数据
---@return table
function AchievementSystem.GetAllLevels()
    return AchievementSystem.Levels
end

--- 获取成就类别的元数据
---@return table
function AchievementSystem.GetAllCategories()
    return AchievementSystem.Categories
end

--- 获取玩家的最高连胜/连败记录
---@param uid number
---@return table
function AchievementSystem.GetStreakInfo(uid)
    local stats = _GetStats(uid)
    return {
        maxWinStreak = stats.max_win_streak or 0,
        currentWinStreak = stats.win_streak or 0,
        currentLoseStreak = stats.lose_streak or 0,
    }
end

--- 获取玩家的主要统计数据（用于UI展示）
---@param uid number
---@return table
function AchievementSystem.GetPlayerStats(uid)
    local stats = _GetStats(uid)
    return {
        winCount = stats.win_count,
        gameCount = stats.game_count,
        speedWinCount = stats.speed_win_count,
        collectedItems = stats.collected_items,
        legendCount = stats.legend_count,
        positiveGain = stats.positive_gain,
        hallVictoryCount = (function()
            local c = 0
            for _ in pairs(stats.hall_victory) do c = c + 1 end
            return c
        end)(),
        collectionValue = stats.collection_value,
        skillUses = stats.skill_uses,
        -- v1.3
        auctionCount = stats.auction_count,
        maxWinStreak = stats.max_win_streak,
        tournamentWins = stats.tournament_wins,
        teamBattleCount = stats.team_battle_count,
        guildContribution = stats.guild_contribution,
        skinUnlocks = stats.skin_unlocks,
        totalGold = stats.total_gold,
        loginDays = stats.login_days,
        totalBalance = stats.total_balance,
        perfectRounds = stats.perfect_rounds,
    }
end

--- EventBus 事件注册（v1.2/v1.3 系统集成）
function AchievementSystem.RegisterEvents()
    -- 监听锦标赛胜利（v1.2 TournamentSystem）
    EventBus.Subscribe(EventBus.Events.TOURNAMENT_WIN, function(data)
        if data and data.uid then
            AchievementSystem.RecordTournamentWin(data.uid, data.tournamentId)
        end
    end, "AchievementSystem")

    -- 监听团队战结果（v1.2 TeamBattleSystem）
    EventBus.Subscribe(EventBus.Events.TEAM_BATTLE_RESULT, function(data)
        if data and data.uid then
            AchievementSystem.RecordTeamBattle(data.uid, data.isWin or false)
        end
    end, "AchievementSystem")

    -- 监听公会贡献更新（v1.3 GuildSystem）
    EventBus.Subscribe("guild_contribution_update", function(data)
        if data and data.uid and data.amount then
            AchievementSystem.RecordGuildContribution(data.uid, data.amount)
        end
    end, "AchievementSystem")

    -- 监听皮肤解锁（v1.2 SkinSystem）
    EventBus.Subscribe("skin_unlock", function(data)
        if data and data.uid then
            AchievementSystem.RecordSkinUnlock(data.uid)
        end
    end, "AchievementSystem")

    -- 监听交易完成（v1.2 TradeSystem）
    EventBus.Subscribe("trade_purchase", function(data)
        if data and data.uid and data.price then
            AchievementSystem.RecordGoldObtained(data.uid, -math.abs(data.price))
        end
    end, "AchievementSystem")

    print("[AchievementSystem] 事件监听已注册")
end

--- 重置玩家成就数据（测试用）
---@param uid number
function AchievementSystem.ResetForTesting(uid)
    unlockedAchievements_[uid] = {}
    stats_[uid] = nil
    _GetStats(uid)
end

return AchievementSystem
