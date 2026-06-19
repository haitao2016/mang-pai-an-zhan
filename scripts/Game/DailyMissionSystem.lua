-- ============================================================================
-- DailyMissionSystem.lua - 每日任务系统
-- 4 个任务，每天 00:00 自动刷新
-- ============================================================================

local Config = require("Config")
local cjson  = require("cjson")

local DailyMissionSystem = {}

-- ============================================================================
-- 状态存储
-- ============================================================================

-- 玩家的每日任务进度
-- { [uid] = {
--     date = "2026-06-19",           -- 当前日期
--     missions = {
--         ["daily_first_win"] = { progress = 1, claimed = false },
--         ...
--     },
--     stats = { game_count=0, win_count=0, skill_uses=0, legend_count=0 }
-- } }
local playerMissions_ = {}

-- 是否已加载
local loaded_ = {}

-- ============================================================================
-- 辅助函数
-- ============================================================================

--- 获取今日日期字符串（YYYY-MM-DD）
---@return string
local function _GetTodayString()
    local now = os.time()
    local t = os.date("*t", now)
    return string.format("%04d-%02d-%02d", t.year, t.month, t.day)
end

--- 获取玩家的任务数据（初始化如需要）
---@param uid number
---@return table
local function _GetMissionData(uid)
    if not playerMissions_[uid] then
        playerMissions_[uid] = {
            date = _GetTodayString(),
            missions = {},
            stats = {
                game_count = 0,
                win_count = 0,
                skill_uses = 0,
                legend_count = 0,
            },
        }
        for _, mission in ipairs(Config.DailyMissions) do
            playerMissions_[uid].missions[mission.id] = {
                progress = 0,
                claimed = false,
            }
        end
    end

    -- 自动刷新跨日
    if playerMissions_[uid].date ~= _GetTodayString() then
        playerMissions_[uid] = {
            date = _GetTodayString(),
            missions = {},
            stats = {
                game_count = 0,
                win_count = 0,
                skill_uses = 0,
                legend_count = 0,
            },
        }
        for _, mission in ipairs(Config.DailyMissions) do
            playerMissions_[uid].missions[mission.id] = {
                progress = 0,
                claimed = false,
            }
        end
        print(string.format("[DailyMission] Day refreshed for uid=%s", tostring(uid)))
    end

    return playerMissions_[uid]
end

-- ============================================================================
-- 加载与保存
-- ============================================================================

--- 加载玩家的每日任务数据
---@param uid number
---@param callback fun(ok: boolean)|nil
function DailyMissionSystem.LoadPlayerData(uid, callback)
    if loaded_[uid] then
        -- 检查是否跨日
        _GetMissionData(uid)
        if callback then callback(true) end
        return
    end

    print(string.format("[DailyMissionSystem] Loading for uid=%s", tostring(uid)))

    serverCloud.game.daily_mission:Get(uid, {
        ok = function(data)
            local missionData = nil

            for _, entry in ipairs(data) do
                if entry.key == "data_json" then
                    local ok2, parsed = pcall(cjson.decode, entry.value)
                    if ok2 and type(parsed) == "table" then
                        missionData = parsed
                    end
                end
            end

            if missionData and missionData.date == _GetTodayString() then
                playerMissions_[uid] = missionData
            else
                -- 日期不同或加载失败，新建数据
                _GetMissionData(uid)
            end

            loaded_[uid] = true
            print(string.format("[DailyMissionSystem] Loaded for uid=%s", tostring(uid)))
            if callback then callback(true) end
        end,
        err = function(msg)
            print(string.format("[DailyMissionSystem] Load failed: %s", tostring(msg)))
            loaded_[uid] = true
            _GetMissionData(uid)
            if callback then callback(false) end
        end,
    })
end

--- 保存玩家的每日任务数据
---@param uid number
function DailyMissionSystem.SavePlayerData(uid)
    if not loaded_[uid] then return end

    local data = _GetMissionData(uid)
    local ok, jsonStr = pcall(cjson.encode, data)
    if ok then
        serverCloud.game.daily_mission:Post(uid, {
            key = "data_json",
            value = jsonStr,
        })
    end
end

-- ============================================================================
-- 事件记录接口
-- ============================================================================

--- 记录一次胜利
---@param uid number
---@return table 本次完成的任务列表（未领取的）
function DailyMissionSystem.RecordVictory(uid)
    local data = _GetMissionData(uid)
    data.stats.win_count = data.stats.win_count + 1
    data.stats.game_count = data.stats.game_count + 1
    return DailyMissionSystem._UpdateProgress(uid)
end

--- 记录一次游戏结束（失败也算）
---@param uid number
---@return table 本次完成的任务列表
function DailyMissionSystem.RecordGameEnd(uid)
    local data = _GetMissionData(uid)
    data.stats.game_count = data.stats.game_count + 1
    return DailyMissionSystem._UpdateProgress(uid)
end

--- 记录一次技能使用
---@param uid number
---@return table 本次完成的任务列表
function DailyMissionSystem.RecordSkillUse(uid)
    local data = _GetMissionData(uid)
    data.stats.skill_uses = data.stats.skill_uses + 1
    return DailyMissionSystem._UpdateProgress(uid)
end

--- 记录获得传说级藏品
---@param uid number
---@return table 本次完成的任务列表
function DailyMissionSystem.RecordLegendItem(uid)
    local data = _GetMissionData(uid)
    data.stats.legend_count = data.stats.legend_count + 1
    return DailyMissionSystem._UpdateProgress(uid)
end

-- ============================================================================
-- 进度更新
-- ============================================================================

--- 更新所有任务的进度
---@param uid number
---@return table 本次新完成的任务列表（未领取的）
function DailyMissionSystem._UpdateProgress(uid)
    local data = _GetMissionData(uid)
    local newCompleted = {}

    for _, mission in ipairs(Config.DailyMissions) do
        local missionState = data.missions[mission.id]
        if missionState and not missionState.claimed then
            local statKey = mission.checkType
            local current = data.stats[statKey] or 0

            local oldProgress = missionState.progress
            missionState.progress = math.min(current, mission.checkValue)

            -- 检测是否新完成
            if oldProgress < mission.checkValue and missionState.progress >= mission.checkValue then
                table.insert(newCompleted, {
                    id = mission.id,
                    name = mission.name,
                    desc = mission.desc,
                    reward = mission.reward,
                })
                print(string.format("[DailyMissionSystem] Completed: %s (uid=%s)", mission.name, tostring(uid)))
            end
        end
    end

    return newCompleted
end

-- ============================================================================
-- 奖励领取
-- ============================================================================

--- 领取任务奖励
---@param uid number
---@param missionId string
---@return boolean ok
---@return table|nil reward { name, reward }
function DailyMissionSystem.ClaimReward(uid, missionId)
    local data = _GetMissionData(uid)
    local missionState = data.missions[missionId]

    if not missionState then
        return false, nil
    end

    if missionState.claimed then
        return false, nil
    end

    -- 查找任务定义
    local missionDef = nil
    for _, m in ipairs(Config.DailyMissions) do
        if m.id == missionId then
            missionDef = m
            break
        end
    end

    if not missionDef then
        return false, nil
    end

    if missionState.progress < missionDef.checkValue then
        return false, nil
    end

    -- 领取奖励
    missionState.claimed = true

    print(string.format("[DailyMissionSystem] Claimed: %s, reward=%d (uid=%s)",
        missionDef.name, missionDef.reward, tostring(uid)))

    return true, {
        name = missionDef.name,
        reward = missionDef.reward,
    }
end

--- 一键领取所有可领取的任务奖励
---@param uid number
---@return table rewards { totalReward, count, items }
function DailyMissionSystem.ClaimAllAvailable(uid)
    local data = _GetMissionData(uid)
    local total = 0
    local count = 0
    local items = {}

    for _, mission in ipairs(Config.DailyMissions) do
        local state = data.missions[mission.id]
        if state and not state.claimed and state.progress >= mission.checkValue then
            state.claimed = true
            total = total + mission.reward
            count = count + 1
            table.insert(items, {
                id = mission.id,
                name = mission.name,
                reward = mission.reward,
            })
        end
    end

    return {
        totalReward = total,
        count = count,
        items = items,
    }
end

-- ============================================================================
-- 查询接口
-- ============================================================================

--- 获取玩家的每日任务列表
---@param uid number
---@return table
function DailyMissionSystem.GetMissionList(uid)
    local data = _GetMissionData(uid)
    local list = {}

    for _, mission in ipairs(Config.DailyMissions) do
        local state = data.missions[mission.id] or { progress = 0, claimed = false }
        local progress = math.min(1.0, state.progress / mission.checkValue)

        table.insert(list, {
            id = mission.id,
            name = mission.name,
            desc = mission.desc,
            reward = mission.reward,
            progress = progress,
            current = state.progress,
            target = mission.checkValue,
            claimed = state.claimed,
            completed = state.progress >= mission.checkValue,
        })
    end

    return list
end

--- 获取可领取奖励的任务数量
---@param uid number
---@return number
function DailyMissionSystem.GetAvailableCount(uid)
    local list = DailyMissionSystem.GetMissionList(uid)
    local count = 0
    for _, m in ipairs(list) do
        if m.completed and not m.claimed then
            count = count + 1
        end
    end
    return count
end

--- 获取今日日期
---@return string
function DailyMissionSystem.GetCurrentDate()
    return _GetTodayString()
end

--- 重置玩家的每日任务（测试用）
---@param uid number
function DailyMissionSystem.ResetForTesting(uid)
    playerMissions_[uid] = nil
    loaded_[uid] = false
end

-- ============================================================================
-- v1.1.0 新增：周任务系统
-- ============================================================================

local weeklyMissions_ = {}  -- 周任务数据

--- 获取本周标识（基于周一刷新机制）
local function _GetWeekString()
    if not os or not os.time then
        return "2026-W25"
    end
    local now = os.time()
    local t = os.date("*t", now)
    -- 计算是今年的第几周
    local yearStart = os.time({ year = t.year, month = 1, day = 1, hour = 0 })
    local daysPassed = math.floor((now - yearStart) / (24 * 60 * 60))
    local weekNum = math.floor(daysPassed / 7) + 1
    return string.format("%04d-W%02d", t.year, weekNum)
end

--- 获取玩家周任务数据
local function _GetWeeklyData(uid)
    if not Config.WeeklyMissions then
        return nil
    end

    if not weeklyMissions_[uid] then
        weeklyMissions_[uid] = {
            week = _GetWeekString(),
            missions = {},
            stats = {
                game_wins = 0,
                items_collected = 0,
                skills_used = 0
            }
        }
        for _, m in ipairs(Config.WeeklyMissions.Missions) do
            weeklyMissions_[uid].missions[m.id] = {
                progress = 0,
                claimed = false
            }
        end
    end

    -- 自动周刷新
    if weeklyMissions_[uid].week ~= _GetWeekString() then
        weeklyMissions_[uid] = {
            week = _GetWeekString(),
            missions = {},
            stats = {
                game_wins = 0,
                items_collected = 0,
                skills_used = 0
            }
        }
        for _, m in ipairs(Config.WeeklyMissions.Missions) do
            weeklyMissions_[uid].missions[m.id] = {
                progress = 0,
                claimed = false
            }
        end
        print("[WeeklyMission] Week refreshed for uid=" .. tostring(uid))
    end

    return weeklyMissions_[uid]
end

--- 触发周任务进度更新（在游戏/技能/收集时调用）
function DailyMissionSystem.UpdateWeeklyProgress(uid, trigger)
    if not Config.WeeklyMissions then return {} end
    local data = _GetWeeklyData(uid)
    if not data then return {} end

    local statMap = {
        ["game_win"]     = "game_wins",
        ["item_collect"] = "items_collected",
        ["skill_use"]    = "skills_used"
    }
    local statKey = statMap[trigger]
    if not statKey then return {} end

    data.stats[statKey] = (data.stats[statKey] or 0) + 1

    -- 更新对应任务进度
    local newCompleted = {}
    for _, mission in ipairs(Config.WeeklyMissions.Missions) do
        if mission.trigger == trigger then
            local missionState = data.missions[mission.id]
            if missionState and not missionState.claimed then
                local old = missionState.progress
                missionState.progress = math.min(
                    data.stats[statKey] or 0,
                    mission.target
                )
                if old < mission.target and missionState.progress >= mission.target then
                    table.insert(newCompleted, {
                        id = mission.id,
                        name = mission.name,
                        reward = mission.reward
                    })
                    print("[WeeklyMission] Completed: " .. mission.name .. " (uid=" .. tostring(uid) .. ")")
                end
            end
        end
    end
    return newCompleted
end

--- 获取周任务列表
function DailyMissionSystem.GetWeeklyMissionList(uid)
    if not Config.WeeklyMissions then return {} end
    local data = _GetWeeklyData(uid)
    if not data then return {} end

    local list = {}
    for _, mission in ipairs(Config.WeeklyMissions.Missions) do
        local state = data.missions[mission.id] or {}
        table.insert(list, {
            id = mission.id,
            name = mission.name,
            desc = mission.desc,
            target = mission.target,
            progress = state.progress or 0,
            completed = (state.progress or 0) >= mission.target,
            claimed = state.claimed or false,
            reward = mission.reward
        })
    end
    return list
end

--- 领取周任务奖励
function DailyMissionSystem.ClaimWeeklyReward(uid, missionId)
    if not Config.WeeklyMissions then return false, nil end
    local data = _GetWeeklyData(uid)
    if not data then return false, nil end

    local missionState = data.missions[missionId]
    if not missionState or missionState.claimed then
        return false, nil
    end

    -- 查找任务配置
    local missionConfig = nil
    for _, m in ipairs(Config.WeeklyMissions.Missions) do
        if m.id == missionId then
            missionConfig = m
            break
        end
    end

    if not missionConfig or (missionState.progress or 0) < missionConfig.target then
        return false, nil
    end

    missionState.claimed = true
    print("[WeeklyMission] Reward claimed: " .. missionConfig.name .. " (" .. tostring(missionConfig.reward) .. " gold) (uid=" .. tostring(uid) .. ")")

    return true, {
        name = missionConfig.name,
        reward = missionConfig.reward
    }
end

--- 一键领取所有周任务奖励
function DailyMissionSystem.ClaimAllWeeklyRewards(uid)
    if not Config.WeeklyMissions then return {} end
    local claimed = {}
    for _, m in ipairs(Config.WeeklyMissions.Missions) do
        local ok, reward = DailyMissionSystem.ClaimWeeklyReward(uid, m.id)
        if ok and reward then
            table.insert(claimed, reward)
        end
    end
    return claimed
end

--- 注册事件监听（与 EventBus 集成）
function DailyMissionSystem.RegisterEvents()
    local ok, EventBus = pcall(require, "Utils.EventBus")
    if not ok or not EventBus then return end

    EventBus.Subscribe(EventBus.Events.GAME_END, function(data)
        if not data then return end
        local uid = data.playerId or data.uid or data.seat
        if data.isWinner or data.winner then
            DailyMissionSystem.UpdateWeeklyProgress(uid, "game_win")
        end
    end, "DailyMissionSystem")

    EventBus.Subscribe(EventBus.Events.ITEM_COLLECT, function(data)
        if not data then return end
        local uid = data.playerId or data.uid or data.seat
        DailyMissionSystem.UpdateWeeklyProgress(uid, "item_collect")
    end, "DailyMissionSystem")

    EventBus.Subscribe(EventBus.Events.SKILL_USE, function(data)
        if not data then return end
        local uid = data.playerId or data.uid or data.seat
        DailyMissionSystem.UpdateWeeklyProgress(uid, "skill_use")
    end, "DailyMissionSystem")

    print("[DailyMissionSystem] EventBus listeners registered (weekly + daily)")
end

return DailyMissionSystem
