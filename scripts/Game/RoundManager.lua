-- ============================================================================
-- RoundManager.lua - 回合管理器（服务端权威）
-- 管理 5 轮制竞拍流程、速胜检测、回合状态机
-- ============================================================================

local Config = require("Config")

---@class RoundManager
local RoundManager = {}
RoundManager.__index = RoundManager

-- 回合阶段
RoundManager.Phase = {
    IDLE     = "idle",       -- 未开始
    PREPARE  = "prepare",    -- 回合准备（倒计时）
    BIDDING  = "bidding",    -- 出价中
    SETTLING = "settling",   -- 结算中
    DONE     = "done",       -- 回合结束
}

--- 创建回合管理器
---@return RoundManager
function RoundManager.New()
    local self = setmetatable({}, RoundManager)
    self.currentRound = 0
    self.totalRounds = Config.Auction.TotalRounds
    self.phase = RoundManager.Phase.IDLE
    self.phaseTimer = 0
    self.gameOver = false
    self.speedWin = false
    self.speedWinSeat = nil

    -- 回调函数
    self.onRoundStart = nil     -- function(roundNum, speedWinMult)
    self.onBidTimeout = nil     -- function(roundNum)
    self.onRoundSettle = nil    -- function(roundNum)
    self.onSpeedWin = nil       -- function(winnerSeat, roundNum)
    self.onGameOver = nil       -- function(isSpeedWin)
    self.onTimerTick = nil      -- function(timeLeft)

    self._lastTickSecond = -1
    return self
end

--- 开始第一轮
function RoundManager:StartGame()
    self.currentRound = 0
    self.gameOver = false
    self.speedWin = false
    self.speedWinSeat = nil
    print("[RoundManager] Game started")
    self:_NextRound()
end

--- 进入下一轮
function RoundManager:_NextRound()
    self.currentRound = self.currentRound + 1

    if self.currentRound > self.totalRounds then
        -- 所有轮次结束
        self:_EndGame(false)
        return
    end

    -- 进入准备阶段
    self.phase = RoundManager.Phase.PREPARE
    self.phaseTimer = Config.Auction.PrepareTime
    self._lastTickSecond = -1
    print(string.format("[RoundManager] Round %d/%d preparing...",
        self.currentRound, self.totalRounds))
end

--- 进入出价阶段
function RoundManager:_StartBidding()
    self.phase = RoundManager.Phase.BIDDING
    self.phaseTimer = Config.Auction.BidTimeLimit
    self._lastTickSecond = -1

    local mult = self:GetSpeedWinMultiplier()
    print(string.format("[RoundManager] Round %d bidding started (speedWin mult: %.2f)",
        self.currentRound, mult))

    if self.onRoundStart then
        self.onRoundStart(self.currentRound, mult)
    end
end

--- 进入结算阶段
function RoundManager:_StartSettling()
    self.phase = RoundManager.Phase.SETTLING
    self.phaseTimer = Config.Auction.ResultShowTime

    print(string.format("[RoundManager] Round %d settling...", self.currentRound))

    if self.onRoundSettle then
        self.onRoundSettle(self.currentRound)
    end
end

--- 结束游戏
---@param isSpeedWin boolean
function RoundManager:_EndGame(isSpeedWin)
    self.gameOver = true
    self.speedWin = isSpeedWin
    self.phase = RoundManager.Phase.DONE
    print(string.format("[RoundManager] Game over! SpeedWin: %s", tostring(isSpeedWin)))

    if self.onGameOver then
        self.onGameOver(isSpeedWin)
    end
end

--- 获取当前轮的速胜倍率
---@return number 倍率（0 表示不可速胜，即第5轮）
function RoundManager:GetSpeedWinMultiplier()
    return Config.Auction.SpeedWinMultipliers[self.currentRound] or 0
end

--- 检查速胜条件
---@param results table 排名结果 { {seatIdx, amount, rank}, ... }
---@return boolean isSpeedWin
---@return number|nil winnerSeat
function RoundManager:CheckSpeedWin(results)
    local mult = self:GetSpeedWinMultiplier()
    if mult <= 0 then
        return false, nil
    end

    if #results < 2 then
        return false, nil
    end

    local first = results[1]
    local second = results[2]

    -- 第一名出价 >= 第二名出价 * 倍率 → 速胜
    if first.amount > 0 and first.amount >= second.amount * mult then
        print(string.format("[RoundManager] Speed Win! Seat %d (%d >= %d * %.2f)",
            first.seatIdx, first.amount, second.amount, mult))
        self.speedWinSeat = first.seatIdx
        return true, first.seatIdx
    end

    return false, nil
end

--- 通知所有出价已收集完毕（由 AuctionManager 调用）
function RoundManager:NotifyAllBidsIn()
    if self.phase == RoundManager.Phase.BIDDING then
        -- 直接跳过剩余倒计时，进入结算
        self.phaseTimer = 0
        print("[RoundManager] All bids received, skipping to settle")
    end
end

--- 强制触发速胜结束
---@param winnerSeat number
function RoundManager:TriggerSpeedWin(winnerSeat)
    self.speedWinSeat = winnerSeat
    if self.onSpeedWin then
        self.onSpeedWin(winnerSeat, self.currentRound)
    end
    self:_EndGame(true)
end

--- 每帧更新
---@param dt number 时间步长（秒）
function RoundManager:Update(dt)
    if self.gameOver then return end

    if self.phase == RoundManager.Phase.PREPARE then
        self.phaseTimer = self.phaseTimer - dt
        if self.phaseTimer <= 0 then
            self:_StartBidding()
        end

    elseif self.phase == RoundManager.Phase.BIDDING then
        self.phaseTimer = self.phaseTimer - dt

        -- 每秒触发一次倒计时回调
        local sec = math.ceil(self.phaseTimer)
        if sec ~= self._lastTickSecond and sec >= 0 then
            self._lastTickSecond = sec
            if self.onTimerTick then
                self.onTimerTick(sec)
            end
        end

        if self.phaseTimer <= 0 then
            -- 超时
            print(string.format("[RoundManager] Round %d bid timeout!", self.currentRound))
            if self.onBidTimeout then
                self.onBidTimeout(self.currentRound)
            end
            self:_StartSettling()
        end

    elseif self.phase == RoundManager.Phase.SETTLING then
        self.phaseTimer = self.phaseTimer - dt
        if self.phaseTimer <= 0 then
            self:_NextRound()
        end
    end
end

--- 获取当前阶段
---@return string
function RoundManager:GetPhase()
    return self.phase
end

--- 获取当前轮次
---@return number
function RoundManager:GetCurrentRound()
    return self.currentRound
end

--- 获取当前阶段剩余时间
---@return number
function RoundManager:GetTimeLeft()
    return math.max(0, self.phaseTimer)
end

--- 游戏是否结束
---@return boolean
function RoundManager:IsGameOver()
    return self.gameOver
end

--- 是否正在出价阶段
---@return boolean
function RoundManager:IsBidding()
    return self.phase == RoundManager.Phase.BIDDING
end

return RoundManager
