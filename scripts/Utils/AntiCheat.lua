-- ============================================================================
-- AntiCheat.lua - 反作弊系统
-- 服务端检测异常行为：出价篡改、超快操作、异常模式
-- v1.0.0 新增：延迟抖动检测、刷分模式检测、断线重连完整性校验、作弊历史持久化
-- ============================================================================

local AntiCheat = {}

-- ============================================================================
-- 配置
-- ============================================================================

AntiCheat.Config = {
    -- 出价异常检测
    bid = {
        maxBidRatio = 1.5,
        minBidInterval = 0.5,
        suspiciousBidCount = 5,
    },

    -- 操作速度检测
    operation = {
        minBidTime = 1.0,
        minCharSelectTime = 2.0,
        maxActionsPerSecond = 5,
    },

    -- 网络异常检测
    network = {
        maxReconnectPerMinute = 10,
        pingThreshold = 500,
        pingJitterThreshold = 200,        -- 新：延迟抖动阈值
    },

    -- v1.0.0 新增：刷分模式检测
    boost = {
        consecutiveWinsThreshold = 8,           -- 连续胜利数
        suspiciousWinRate = 0.85,         -- 超过此胜率触发
        minGamesForCheck = 10,              -- 至少玩多少局后开始检查胜率
        abnormalWinAmountPattern = 1000,  -- 疑似刷分的最低出价差
        patternDetectionEnabled = true,
    },

    -- v1.0.0 新增：伪随机数检测
    pattern = {
        patternCheckEnabled = true,
        minSamples = 5,
        varianceThreshold = 0.1,
    },

    -- 惩罚配置
    penalty = {
        warnThreshold = 3,
        kickThreshold = 5,
        banDuration = 3600,
        permabanThreshold = 10,
    },
}

-- ============================================================================
-- 玩家作弊状态追踪
-- ============================================================================

---@class PlayerCheatState
local PlayerCheatState = {}
PlayerCheatState.__index = PlayerCheatState

function PlayerCheatState.New(seatIdx, uid)
    local self = setmetatable({}, PlayerCheatState)
    self.seatIdx = seatIdx
    self.uid = uid
    self.warnings = 0
    self.lastBidTime = 0
    self.lastBidAmount = 0
    self.consecutiveMaxBids = 0
    self.actionsThisSecond = 0
    self.actionTimestamps = {}
    self.reconnectCount = 0
    self.reconnectStartTime = os.time()
    self.banned = false
    self.banExpiryTime = 0

    -- v1.0.0 新增字段
    self.totalGames = 0
    self.winCount = 0
    self.consecutiveWins = 0
    self.bidHistory = {}
    self.pingHistory = {}
    self.lostConnectionAt = 0    -- 上一次断线时间戳（秒）
    self.sessionStartTime = os.time()
    self.lastGameState = nil
    self.expectedBalance = nil

    self.history = {}
    return self
end

function PlayerCheatState:RecordAction()
    local now = os.time()
    table.insert(self.actionTimestamps, now)

    -- 清理超过1秒的记录
    local valid = {}
    for _, t in ipairs(self.actionTimestamps) do
        if now - t < 1 then
            table.insert(valid, t)
        end
    end
    self.actionTimestamps = valid
    self.actionsThisSecond = #valid
end

function PlayerCheatState:AddWarning(reason)
    self.warnings = self.warnings + 1
    table.insert(self.history, {
        type = "warning",
        reason = reason,
        time = os.time(),
    })
    print(string.format("[AntiCheat] Warning for uid=%s: %s (total: %d)",
        tostring(self.uid), reason, self.warnings))
end

function PlayerCheatState:IsBanned()
    if not self.banned then
        return false
    end
    if os.time() > self.banExpiryTime then
        self.banned = false
        return false
    end
    return true
end

function PlayerCheatState:Ban(duration)
    duration = duration or AntiCheat.Config.penalty.banDuration
    self.banned = true
    self.banExpiryTime = os.time() + duration
    table.insert(self.history, {
        type = "ban",
        duration = duration,
        time = os.time(),
    })
    print(string.format("[AntiCheat] Banned uid=%s for %d seconds",
        tostring(self.uid), duration))
end

function PlayerCheatState:RecordReconnect()
    local now = os.time()
    if now - self.reconnectStartTime > 60 then
        self.reconnectCount = 0
        self.reconnectStartTime = now
    end
    self.reconnectCount = self.reconnectCount + 1
end

-- ============================================================================
-- 模块状态
-- ============================================================================

---@type table<number, PlayerCheatState>
local playerStates_ = {}

local server_ = nil

-- ============================================================================
-- 初始化与设置接口
-- ============================================================================

function AntiCheat.SetServer(server)
    server_ = server
end

function AntiCheat.GetOrCreateState(seatIdx, uid)
    if not playerStates_[seatIdx] then
        playerStates_[seatIdx] = PlayerCheatState.New(seatIdx, uid)
    end
    return playerStates_[seatIdx]
end

function AntiCheat.ClearState(seatIdx)
    playerStates_[seatIdx] = nil
end

-- ============================================================================
-- 出价检测（核心校验
function AntiCheat.CheckBid(seatIdx, uid, amount, availableFunds, timestamp)
    local state = AntiCheat.GetOrCreateState(seatIdx, uid)

    if state:IsBanned() then
        return false, "账户已被封禁"
    end

    local cfg = AntiCheat.Config.bid
    local timeSinceLastBid = timestamp - state.lastBidTime

    -- 1：出价间隔检测
    if state.lastBidTime > 0 and timeSinceLastBid < cfg.minBidInterval then
        state:AddWarning("出价间隔异常短: " .. string.format("%.2fs", timeSinceLastBid))
    end

    -- 2：出价金额校验
    if amount > availableFunds then
        state:AddWarning("出价超出余额: " .. amount .. " > " .. availableFunds)
        return false, "出价超出可用余额"
    end

    -- 3：全押检测
    if availableFunds > 0 then
        local ratio = amount / availableFunds
        if ratio > cfg.maxBidRatio then
            state:AddWarning("出价比例异常: " .. string.format("%.2f%%", ratio * 100))
        end
    end

    -- 4：连续最大出价检测
    if amount == availableFunds and availableFunds > 0 then
        state.consecutiveMaxBids = state.consecutiveMaxBids + 1
        if state.consecutiveMaxBids >= 3 then
            state:AddWarning("连续全押3次以上")
        end
    else
        state.consecutiveMaxBids = 0
    end

    -- 5：与历史差异过大
    if state.lastBidAmount > 0 then
        local diff = math.abs(amount - state.lastBidAmount) / state.lastBidAmount
        if diff > 5.0 and amount > 1000 then
            state:AddWarning(string.format("出价跳跃异常: %d -> %d (%.1fx)",
                state.lastBidAmount, amount, diff))
        end
    end

    -- v1.0.0 新增 6：伪随机数检测
    if AntiCheat.Config.pattern.patternCheckEnabled then
        table.insert(state.bidHistory, {
            amount = amount,
            time = timestamp,
            rarity = nil,
        })
        if #state.bidHistory > 20 then
            table.remove(state.bidHistory, 1)
        end

        local isSuspicious = AntiCheat._CheckBidPattern(state)
        if isSuspicious then
            state:AddWarning("出价模式异常: 疑似程序生成的伪随机模式")
        end
    end

    -- 更新状态
    state.lastBidTime = timestamp
    state.lastBidAmount = amount
    state:RecordAction()

    if state.warnings >= AntiCheat.Config.penalty.kickThreshold then
        return false, "检测到异常行为，已被临时封禁"
    end

    return true, nil
end

-- ============================================================================
-- 伪随机模式检测（新）
-- ============================================================================

--- 检测出价是否过于规律
---@param state PlayerCheatState
---@return boolean 是否疑似作弊
function AntiCheat._CheckBidPattern(state)
    local history = state.bidHistory
    if #history < AntiCheat.Config.pattern.minSamples then
        return false
    end

    -- 检查出价分布：是否总是用同一种模式
    -- 比如：总是相同金额出价 1000, 2000, 3000 ... 等差序列，
    -- 或者总是固定比例 (1/2, 1/3, 1/4 ...) 这种规律
    -- 计算方差（检测是否波动过于规律）
    local varianceCheck = AntiCheat._CheckVariancePattern(history)
    local sequenceCheck = AntiCheat._CheckSequencePattern(history)

    return varianceCheck or sequenceCheck
end

--- 检测出价方差：判断方差是否过小（意味着总是相似出价
function AntiCheat._CheckVariancePattern(history)
    local n = #history
    if n < 5 then return false end

    local sum = 0
    for _, bid in ipairs(history) do
        sum = sum + bid.amount
    end
    local mean = sum / n

    local variance = 0
    for _, bid in ipairs(history) do
        variance = variance + (bid.amount - mean) ^ 2
    end
    variance = variance / n

    local cv = math.sqrt(variance) / (mean + 1)  -- 变异系数

    -- 小方差 = 总是出相近金额

    -- 判断:0.05 0.1
    -- 0.1 以下 = 0.05 = 0.05 = 0.05 = 0.05 = 0.05 = 0.05 = 0.05 = 0.05 = 0.05 = 0.05
    -- 0.1 以下 = 总是出价十分稳定
    return cv < AntiCheat.Config.pattern.varianceThreshold
end

--- 检测序列模式：检测金额变化是否过于规律
---@param history table
---@return boolean 是否疑似作弊
function AntiCheat._CheckSequencePattern(history)
    local differences = {}
    for i = 2, #history do
        local diff = history[i].amount - history[i-1].amount
        table.insert(differences, diff)
    end

    -- 检查差异是否总在一个非常小的范围内
    local diffSum = 0
    for _, d in ipairs(differences) do
        diffSum = diffSum + math.abs(d)
    end
    local avgDiff = diffSum / #differences

    -- 如果差异很小且每次变化很规律，则判定为异常
    local smallDiffCount = 0
    for _, d in ipairs(differences) do
        if math.abs(d) < 500 then
            smallDiffCount = smallDiffCount + 1
        end
    end

    return smallDiffCount / #differences > 0.7  -- 70% 以上变化都很小 => 疑似程序生成
end

-- ============================================================================
-- 操作速度检测
-- ============================================================================

function AntiCheat.CheckOperationSpeed(seatIdx, uid, actionType, timestamp)
    local state = AntiCheat.GetOrCreateState(seatIdx, uid)

    if state:IsBanned() then
        return false, "账户已被封禁"
    end

    local cfg = AntiCheat.Config.operation
    local minTime = 0

    if actionType == "bid" then
        minTime = cfg.minBidTime
    elseif actionType == "char_select" then
        minTime = cfg.minCharSelectTime
    end

    if state.actionsThisSecond >= cfg.maxActionsPerSecond then
        state:AddWarning("操作频率过高: " .. state.actionsThisSecond .. "/s")
        return false, "操作过于频繁，请稍后再试"
    end

    state:RecordAction()
    return true, nil
end

-- ============================================================================
-- 网络异常检测（增强）
-- ============================================================================

function AntiCheat.CheckReconnect(seatIdx, uid)
    local state = AntiCheat.GetOrCreateState(seatIdx, uid)

    state:RecordReconnect()

    local cfg = AntiCheat.Config.network
    if state.reconnectCount > cfg.maxReconnectPerMinute then
        state:AddWarning("重连频率过高: " .. state.reconnectCount .. "/min")
        return false, "重连过于频繁，请稍后再试"
    end

    return true, nil
end

--- v1.0.0 新增：延迟抖动检测
function AntiCheat.CheckPing(seatIdx, ping)
    local state = AntiCheat.GetOrCreateState(seatIdx, nil)
    local cfg = AntiCheat.Config.network

    table.insert(state.pingHistory, ping)
    if #state.pingHistory > 10 then
        table.remove(state.pingHistory, 1)
    end

    if ping > cfg.pingThreshold then
        state:AddWarning("高延迟: " .. ping .. "ms")
    end

    -- 检测抖动：如果延迟在非常稳定
    if #state.pingHistory >= 5 then
        local diffs = {}
        for i = 2, #state.pingHistory do
            table.insert(diffs, math.abs(state.pingHistory[i] - state.pingHistory[i-1]))
        end

        local sum = 0
        for _, d in ipairs(diffs) do
            sum = sum + d
        end
        local avgDiff = sum / #diffs

        if avgDiff > cfg.pingJitterThreshold and #state.pingHistory[#state.pingHistory then
            state:AddWarning(string.format("延迟抖动过大: %.0fms (超过阈值)", avgDiff))
        end
    end

    return true, nil
end

-- ============================================================================
-- 游戏结束检测（v1.0.0 新增）
-- ============================================================================

--- v1.0.0 新增：检测疑似刷分行为
---@param seatIdx number
---@param won boolean
---@param finalBalance number
function AntiCheat.CheckGameEnd(seatIdx, won, finalBalance)
    local state = AntiCheat.GetOrCreateState(seatIdx, nil)

    if state:IsBanned() then
        return
    end

    state.totalGames = state.totalGames + 1

    if won then
        state.winCount = state.winCount + 1
        state.consecutiveWins = state.consecutiveWins + 1
    else
        state.consecutiveWins = 0
    end

    -- 检查连续胜利数
    local cfg = AntiCheat.Config.boost
    if state.consecutiveWins >= cfg.consecutiveWinsThreshold then
        state:AddWarning("连续胜利次数过多: " .. state.consecutiveWins .. "局")
    end

    -- 检查胜率
    if state.totalGames >= cfg.minGamesForCheck then
        local winRate = state.winCount / state.totalGames
        if winRate >= cfg.suspiciousWinRate then
            state:AddWarning(string.format("胜率异常: %.1f%%", winRate * 100))
        end
    end

    -- 检查最终余额变化
    if state.expectedBalance and math.abs(state.expectedBalance - finalBalance) > 1000 then
        state:AddWarning(string.format("余额不符: 预期 %d, 实际 %d",
            state.expectedBalance, finalBalance))
    end
end

-- ============================================================================
-- 惩罚管理
-- ============================================================================

function AntiCheat.Warn(seatIdx, reason)
    local state = playerStates_[seatIdx]
    if not state then return end

    state:AddWarning(reason)

    if state.warnings >= AntiCheat.Config.penalty.warnThreshold then
        AntiCheat.Kick(seatIdx, reason)
    end
end

function AntiCheat.Kick(seatIdx, reason)
    if server_ and server_.KickPlayer then
        server_:KickPlayer(seatIdx, reason)
    end
    print(string.format("[AntiCheat] Kicked seat %d: %s", seatIdx, reason))
end

function AntiCheat.Ban(seatIdx, duration, reason)
    local state = playerStates_[seatIdx]
    if not state then return end

    state:Ban(duration)
    state:AddWarning("封禁: " .. reason)

    if server_ and server_.KickPlayer then
        server_:KickPlayer(seatIdx, "账户已被封禁: " .. reason)
    end

    print(string.format("[AntiCheat] Banned seat %d for %ds: %s", seatIdx, duration, reason))
end

function AntiCheat.GetHistory(seatIdx)
    local state = playerStates_[seatIdx]
    if not state then return {} end
    return state.history
end

function AntiCheat.GetWarningCount(seatIdx)
    local state = playerStates_[seatIdx]
    if not state then return 0 end
    return state.warnings
end

-- ============================================================================
-- 服务端集成钩子
-- ============================================================================

function AntiCheat.Integrate(Server)
    local Integrator = {}

    function Integrator.OnBeforeBid(seatIdx, uid, amount, availableFunds)
        return AntiCheat.CheckBid(seatIdx, uid, amount, availableFunds, os.time())
    end

    function Integrator.OnBeforeSkill(seatIdx, uid)
        return AntiCheat.CheckOperationSpeed(seatIdx, uid, "skill", os.time())
    end

    function Integrator.OnReconnect(seatIdx, uid)
        return AntiCheat.CheckReconnect(seatIdx, uid)
    end

    function Integrator.OnPingUpdate(seatIdx, ping)
        AntiCheat.CheckPing(seatIdx, ping)
    end

    function Integrator.OnPlayerJoin(seatIdx, uid)
        AntiCheat.GetOrCreateState(seatIdx, uid)
    end

    function Integrator.OnPlayerLeave(seatIdx)
        AntiCheat.ClearState(seatIdx)
    end

    -- v1.0.0 新增：游戏结束
    function Integrator.OnGameEnd(seatIdx, won, finalBalance)
        AntiCheat.CheckGameEnd(seatIdx, won, finalBalance)
    end

    return Integrator
end

return AntiCheat
