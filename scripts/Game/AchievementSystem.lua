-- ============================================================================
-- AchievementSystem.lua - 成就系统
-- 10 个成就，自动检测条件，发放金币奖励
-- 持久化存储：serverCloud
-- ============================================================================

local Config = require("Config")
local cjson  = require("cjson")

local AchievementSystem = {}

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

    if hallId then
        stats.hall_victory[hallId] = true
    end

    -- 计算正收益
    if finalBalance and initialFunds and finalBalance > initialFunds then
        stats.positive_gain = stats.positive_gain + 1
    end

    return AchievementSystem._CheckAllAchievements(uid)
end

--- 记录一次游戏结束（失败）
---@param uid number
function AchievementSystem.RecordGameEnd(uid)
    local stats = _GetStats(uid)
    stats.game_count = stats.game_count + 1
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
    for _, rank in ipairs(rankList) do
        if rank <= 2 then
            top2Count = top2Count + 1
        end
    end

    -- 只记录最高的一次（单局成就），如果已有更高则不覆盖
    if top2Count > stats.top2_rounds then
        stats.top2_rounds = top2Count
    end

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
-- 成就检查
-- ============================================================================

--- 检查所有成就条件
---@param uid number
---@return table 本次新解锁的成就列表
function AchievementSystem._CheckAllAchievements(uid)
    local unlocked = _GetUnlocked(uid)
    local stats = _GetStats(uid)
    local newlyUnlocked = {}

    for _, achievement in ipairs(Config.Achievements) do
        if not unlocked[achievement.id] then
            local ok = AchievementSystem._CheckCondition(achievement, stats)
            if ok then
                unlocked[achievement.id] = true
                table.insert(newlyUnlocked, {
                    id = achievement.id,
                    name = achievement.name,
                    desc = achievement.desc,
                    reward = achievement.reward,
                })
                print(string.format("[AchievementSystem] Unlocked: %s (uid=%s)", achievement.name, tostring(uid)))
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

    for _, achievement in ipairs(Config.Achievements) do
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
            unlocked = unlocked[achievement.id] == true,
            progress = progress,
            current = current,
            target = achievement.checkValue,
        })
    end

    return list
end

--- 重置玩家成就数据（测试用）
---@param uid number
function AchievementSystem.ResetForTesting(uid)
    unlockedAchievements_[uid] = {}
    stats_[uid] = nil
    _GetStats(uid)
end

return AchievementSystem
