-- ============================================================================
-- EventModeSystem.lua - 限时活动模式系统
-- ----------------------------------------------------------------------------
-- 支持 Blind Rush 极速竞拍模式
-- 每日 20:00-22:00 开放
-- ============================================================================

local Config = require("Config")
local EventBus = require("Utils.EventBus")

local EventModeSystem = {}

-- ============================================================================
-- 内部状态
-- ============================================================================
local _currentMode = nil  -- 当前活动模式 nil 表示标准模式

-- ============================================================================
-- 辅助：获取当前小时
-- ============================================================================
local function _GetCurrentHour()
    if os and os.date then
        local t = os.date("*t")
        return t.hour
    end
    return 12  -- 默认中午
end

-- ============================================================================
-- 获取所有可用模式
-- ============================================================================
function EventModeSystem.GetAvailableModes()
    if not Config.EventModes then return {} end

    local result = {}
    for modeId, mode in pairs(Config.EventModes) do
        table.insert(result, {
            id = modeId,
            name = mode.Name,
            description = mode.Description,
            rounds = mode.Rounds,
            bidTimeLimit = mode.BidTimeLimit,
            enabled = mode.Enabled ~= false
        })
    end
    return result
end

-- ============================================================================
-- 检查当前是否在活动时间内
-- ============================================================================
function EventModeSystem.IsEventTime()
    if not Config.EventModes then return false end

    local hour = _GetCurrentHour()

    for modeId, mode in pairs(Config.EventModes) do
        if mode.Enabled and mode.TimeWindow then
            local startHour = mode.TimeWindow[1]
            local endHour = mode.TimeWindow[2]

            if hour >= startHour and hour < endHour then
                return true, modeId
            end
        end
    end

    return false, nil
end

-- ============================================================================
-- 获取当前活动模式配置
-- ============================================================================
function EventModeSystem.GetCurrentMode()
    local inEvent, modeId = EventModeSystem.IsEventTime()

    if not inEvent or not modeId then
        return nil  -- 标准模式
    end

    return Config.EventModes[modeId]
end

-- ============================================================================
-- 获取当前模式 ID
-- ============================================================================
function EventModeSystem.GetCurrentModeId()
    local mode = EventModeSystem.GetCurrentMode()
    return mode and mode.Name or "standard"
end

-- ============================================================================
-- 获取活动剩余时间（秒）
-- ============================================================================
function EventModeSystem.GetEventTimeRemaining()
    local inEvent, modeId = EventModeSystem.IsEventTime()

    if not inEvent then
        return 0
    end

    local mode = Config.EventModes and Config.EventModes[modeId]
    if not mode or not mode.TimeWindow then
        return 0
    end

    local hour = _GetCurrentHour()
    local endHour = mode.TimeWindow[2]

    -- 计算到活动结束的秒数
    local now = os and os.time and os.time() or 0
    local endOfHour = os and os.date and os.time({
        year = os.date("*t").year,
        month = os.date("*t").month,
        day = os.date("*t").day,
        hour = endHour,
        min = 0,
        sec = 0
    }) or (3600 * endHour)

    return math.max(0, endOfHour - now)
end

-- ============================================================================
-- 获取模式的回合数
-- ============================================================================
function EventModeSystem.GetRounds()
    local mode = EventModeSystem.GetCurrentMode()
    if mode then
        return mode.Rounds or 5
    end
    return Config.Auction.TotalRounds or 5
end

-- ============================================================================
-- 获取模式的出价时限
-- ============================================================================
function EventModeSystem.GetBidTimeLimit()
    local mode = EventModeSystem.GetCurrentMode()
    if mode then
        return mode.BidTimeLimit or 15
    end
    return Config.Auction.BidTimeLimit or 15
end

-- ============================================================================
-- 获取模式的初始资金
-- ============================================================================
function EventModeSystem.GetInitialFunds()
    local mode = EventModeSystem.GetCurrentMode()
    if mode and mode.InitialFunds then
        return mode.InitialFunds
    end
    return Config.Auction.InitialFunds or 10000
end

-- ============================================================================
-- 获取奖励倍率
-- ============================================================================
function EventModeSystem.GetRewardBonus()
    local mode = EventModeSystem.GetCurrentMode()
    if mode then
        return mode.RewardBonus or 1.0
    end
    return 1.0
end

-- ============================================================================
-- 获取额外赛季经验
-- ============================================================================
function EventModeSystem.GetBonusExp()
    local mode = EventModeSystem.GetCurrentMode()
    if mode then
        return mode.BonusExp or 0
    end
    return 0
end

-- ============================================================================
-- 检查是否可以进入活动模式
-- ============================================================================
function EventModeSystem.CanJoinEvent()
    local inEvent, modeId = EventModeSystem.IsEventTime()
    if not inEvent then
        return false, "not_in_event_time"
    end

    local mode = Config.EventModes and Config.EventModes[modeId]
    if not mode or not mode.Enabled then
        return false, "mode_disabled"
    end

    return true, mode.Name
end

-- ============================================================================
-- 获取活动状态信息
-- ============================================================================
function EventModeSystem.GetEventStatus()
    local inEvent, modeId = EventModeSystem.IsEventTime()
    local status = {
        isActive = inEvent,
        modeName = "standard",
        modeDescription = "标准暗拍模式",
        rounds = Config.Auction.TotalRounds or 5,
        bidTimeLimit = Config.Auction.BidTimeLimit or 15,
        timeRemaining = 0,
        rewardBonus = 1.0,
        bonusExp = 0
    }

    if inEvent and modeId then
        local mode = Config.EventModes[modeId]
        if mode then
            status.modeName = mode.Name
            status.modeDescription = mode.Description
            status.rounds = mode.Rounds or status.rounds
            status.bidTimeLimit = mode.BidTimeLimit or status.bidTimeLimit
            status.timeRemaining = EventModeSystem.GetEventTimeRemaining()
            status.rewardBonus = mode.RewardBonus or 1.0
            status.bonusExp = mode.BonusExp or 0
        end
    end

    return status
end

-- ============================================================================
-- 发布事件
-- ============================================================================
function EventModeSystem.PublishEventStart(modeId)
    EventBus.Publish("event_mode_start", {
        modeId = modeId,
        modeName = Config.EventModes and Config.EventModes[modeId] and Config.EventModes[modeId].Name or "unknown"
    })
end

function EventModeSystem.PublishEventEnd(modeId)
    EventBus.Publish("event_mode_end", {
        modeId = modeId
    })
end

-- ============================================================================
-- 注册事件
-- ============================================================================
function EventModeSystem.RegisterEvents()
    print("[EventModeSystem] 系统已注册")
end

return EventModeSystem
