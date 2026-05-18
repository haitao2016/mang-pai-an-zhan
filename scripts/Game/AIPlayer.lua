-- ============================================================================
-- AIPlayer.lua - AI 玩家决策模块（服务端）
-- 提供三种策略（保守/激进/平衡），模拟真人出价节奏
-- ============================================================================

local Config = require("Config")

---@class AIPlayer
local AIPlayer = {}
AIPlayer.__index = AIPlayer

-- AI 策略类型
AIPlayer.Strategy = {
    CONSERVATIVE = "conservative",  -- 保守：低价试探，留余额到后期
    AGGRESSIVE   = "aggressive",    -- 激进：前期高价抢速胜
    BALANCED     = "balanced",      -- 平衡：根据局势动态调整
}

-- 策略参数表
local STRATEGY_PARAMS = {
    [AIPlayer.Strategy.CONSERVATIVE] = {
        -- 出价占可用余额的比例范围
        bidRatioMin = 0.03,
        bidRatioMax = 0.12,
        -- 后期加注倾向（越大越保守到后期才发力）
        lateGameBias = 0.6,
        -- 出价延迟范围（秒）
        delayMin = 3.0,
        delayMax = 10.0,
        -- 被超越时的加注幅度
        pressureMultiplier = 1.1,
    },
    [AIPlayer.Strategy.AGGRESSIVE] = {
        bidRatioMin = 0.15,
        bidRatioMax = 0.35,
        lateGameBias = -0.3,
        delayMin = 1.0,
        delayMax = 5.0,
        pressureMultiplier = 1.4,
    },
    [AIPlayer.Strategy.BALANCED] = {
        bidRatioMin = 0.08,
        bidRatioMax = 0.22,
        lateGameBias = 0.1,
        delayMin = 2.0,
        delayMax = 8.0,
        pressureMultiplier = 1.2,
    },
}

--- 所有可用策略列表（用于随机分配）
local ALL_STRATEGIES = {
    AIPlayer.Strategy.CONSERVATIVE,
    AIPlayer.Strategy.AGGRESSIVE,
    AIPlayer.Strategy.BALANCED,
}

--- 创建 AI 玩家
---@param seatIdx number 座位号
---@param strategy string|nil 策略类型（nil 则随机分配）
---@return AIPlayer
function AIPlayer.New(seatIdx, strategy)
    local self = setmetatable({}, AIPlayer)
    self.seatIdx = seatIdx
    self.strategy = strategy or ALL_STRATEGIES[math.random(1, #ALL_STRATEGIES)]
    self.params = STRATEGY_PARAMS[self.strategy]
    self.name = AIPlayer._GenerateName(seatIdx)

    -- 出价延迟控制
    self.bidDelay = 0       -- 本轮距出价还剩多少秒
    self.hasBidThisRound = false
    self.lastRound = 0

    -- 历史记录（用于动态调整策略）
    self.rankHistory = {}   -- { [round] = rank }

    print(string.format("[AIPlayer] Seat %d created: '%s' (%s)",
        seatIdx, self.name, self.strategy))
    return self
end

--- 生成 AI 名字
---@param seatIdx number
---@return string
function AIPlayer._GenerateName(seatIdx)
    local prefixes = { "小", "大", "老", "阿", "金", "银", "火", "冰" }
    local suffixes = { "鹰", "狼", "虎", "龙", "凤", "鲤", "鹤", "豹" }
    local p = prefixes[math.random(1, #prefixes)]
    local s = suffixes[math.random(1, #suffixes)]
    return p .. s
end

--- 新一轮开始时重置状态
---@param roundNum number
function AIPlayer:OnRoundStart(roundNum)
    self.hasBidThisRound = false
    self.lastRound = roundNum
    -- 随机延迟
    self.bidDelay = self.params.delayMin
        + math.random() * (self.params.delayMax - self.params.delayMin)
    print(string.format("[AIPlayer] Seat %d round %d, will bid in %.1fs",
        self.seatIdx, roundNum, self.bidDelay))
end

--- 记录回合结算排名
---@param roundNum number
---@param rank number
function AIPlayer:RecordRank(roundNum, rank)
    self.rankHistory[roundNum] = rank
end

--- 每帧更新，返回是否应该出价以及出价金额
---@param dt number
---@param availableFunds number 剩余可用余额
---@param roundNum number 当前轮次
---@param totalRounds number 总轮次
---@return boolean shouldBid
---@return number bidAmount
function AIPlayer:Update(dt, availableFunds, roundNum, totalRounds)
    if self.hasBidThisRound then
        return false, 0
    end

    -- 递减延迟
    self.bidDelay = self.bidDelay - dt
    if self.bidDelay > 0 then
        return false, 0
    end

    -- 计算出价
    local amount = self:_CalculateBid(availableFunds, roundNum, totalRounds)
    self.hasBidThisRound = true
    return true, amount
end

--- 核心：计算出价金额
---@param availableFunds number
---@param roundNum number
---@param totalRounds number
---@return number
function AIPlayer:_CalculateBid(availableFunds, roundNum, totalRounds)
    if availableFunds <= 0 then
        return 0
    end

    local params = self.params

    -- 基础出价比例（在 min~max 之间随机）
    local baseRatio = params.bidRatioMin
        + math.random() * (params.bidRatioMax - params.bidRatioMin)

    -- 轮次因子：后期加注倾向
    -- roundProgress: 0.0(第1轮) → 1.0(最后一轮)
    local roundProgress = (roundNum - 1) / math.max(1, totalRounds - 1)
    local roundFactor = 1.0 + params.lateGameBias * roundProgress

    -- 排名压力因子：落后时加注
    local pressureFactor = 1.0
    local lastRank = self.rankHistory[roundNum - 1]
    if lastRank then
        if lastRank >= 3 then
            -- 排名靠后，增加压力
            pressureFactor = params.pressureMultiplier
        elseif lastRank == 1 then
            -- 领先时略保守
            pressureFactor = 0.85
        end
    end

    -- 最后一轮特殊处理：梭哈或保留
    local lastRoundFactor = 1.0
    if roundNum == totalRounds then
        if self.strategy == AIPlayer.Strategy.AGGRESSIVE then
            lastRoundFactor = 1.8  -- 激进型最后一轮梭哈
        elseif self.strategy == AIPlayer.Strategy.CONSERVATIVE then
            lastRoundFactor = 1.3  -- 保守型也适当加注
        else
            lastRoundFactor = 1.5
        end
    end

    -- 计算最终出价
    local ratio = baseRatio * roundFactor * pressureFactor * lastRoundFactor
    local rawAmount = availableFunds * ratio

    -- 加入随机扰动 ±15%
    local jitter = 0.85 + math.random() * 0.30
    rawAmount = rawAmount * jitter

    -- 限制范围
    local amount = math.floor(math.max(0, math.min(rawAmount, availableFunds)))

    -- 确保不会出价为 0（除非真没钱）
    if amount == 0 and availableFunds > 0 then
        amount = math.min(math.floor(availableFunds * 0.05), availableFunds)
        amount = math.max(1, amount)
    end

    print(string.format(
        "[AIPlayer] Seat %d bid calc: funds=%d ratio=%.3f round=%d/%d rank=%s → %d",
        self.seatIdx, availableFunds, ratio, roundNum, totalRounds,
        lastRank and tostring(lastRank) or "?", amount
    ))

    return amount
end

--- 获取 AI 名字
---@return string
function AIPlayer:GetName()
    return self.name
end

--- 获取策略类型
---@return string
function AIPlayer:GetStrategy()
    return self.strategy
end

return AIPlayer
