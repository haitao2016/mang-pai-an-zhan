-- ============================================================================
-- AntiCheat.lua - 反作弊系统
-- 服务端检测异常行为：出价篡改、超快操作、异常模式
-- ============================================================================

local AntiCheat = {}

-- ============================================================================
-- 配置
-- ============================================================================

AntiCheat.Config = {
    -- 出价异常检测
    bid = {
        maxBidRatio = 1.5,       -- 出价与可用余额的最大比例（防止一掷千金全押）
        minBidInterval = 0.5,   -- 两次出价的最小间隔（秒）
        suspiciousBidCount = 5, -- 超过此数量的可疑出价触发警告
    },

    -- 操作速度检测
    operation = {
        minBidTime = 1.0,       -- 最短出价思考时间（秒）
        minCharSelectTime = 2.0, -- 最短角色选择时间（秒）
        maxActionsPerSecond = 5, -- 每秒最大操作次数
    },

    -- 网络异常检测
    network = {
        maxReconnectPerMinute = 10, -- 每分钟最大重连次数
        pingThreshold = 500,        -- 延迟警告阈值（毫秒）
    },

    -- 惩罚配置
    penalty = {
        warnThreshold = 3,    -- 警告次数达到此值时采取行动
        kickThreshold = 5,    -- 踢出阈值
        banDuration = 3600,  -- 封禁时长（秒），默认1小时
    },
}

-- ============================================================================
-- 玩家作弊状态追踪
-- ============================================================================

---@class PlayerCheatState
---@field seatIdx number 座位号
---@field uid number 用户ID
---@field warnings number 警告次数
---@field lastBidTime number 上次出价时间戳
---@field lastBidAmount number 上次出价金额
---@field consecutiveMaxBids number 连续最大出价次数
---@field actionsThisSecond number 最近一秒内的操作数
---@field actionTimestamps table 时间戳数组
---@field reconnectCount number 重连次数
---@field reconnectStartTime number 本次重连统计开始时间
---@field banned boolean 是否被封禁
---@field banExpiryTime number 封禁到期时间
---@field作弊历史 table
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
    print(string.format("[AntiCheat] Banned uid=%s for %d seconds", tostring(self.uid), duration))
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

local server_ = nil  -- Server 模块引用（用于踢人等操作）

-- ============================================================================
-- 初始化
-- ============================================================================

--- 设置 Server 模块引用
---@param server table
function AntiCheat.SetServer(server)
    server_ = server
end

--- 获取或创建玩家作弊状态
---@param seatIdx number
---@param uid number|nil
---@return PlayerCheatState
function AntiCheat.GetOrCreateState(seatIdx, uid)
    if not playerStates_[seatIdx] then
        playerStates_[seatIdx] = PlayerCheatState.New(seatIdx, uid)
    end
    return playerStates_[seatIdx]
end

--- 清除玩家状态
---@param seatIdx number
function AntiCheat.ClearState(seatIdx)
    playerStates_[seatIdx] = nil
end

-- ============================================================================
-- 出价检测
-- ============================================================================

--- 检测出价合法性
---@param seatIdx number
---@param uid number|nil
---@param amount number 出价金额
---@param availableFunds number 可用余额
---@param timestamp number 出价时间戳
---@return boolean allowed
---@return string|nil reason
function AntiCheat.CheckBid(seatIdx, uid, amount, availableFunds, timestamp)
    local state = AntiCheat.GetOrCreateState(seatIdx, uid)

    -- 检查是否被封禁
    if state:IsBanned() then
        return false, "账户已被封禁"
    end

    -- 检测1：出价间隔过短（机器人/脚本检测）
    local cfg = AntiCheat.Config.bid
    local timeSinceLastBid = timestamp - state.lastBidTime
    if state.lastBidTime > 0 and timeSinceLastBid < cfg.minBidInterval then
        state:AddWarning("出价间隔异常短: " .. string.format("%.2fs", timeSinceLastBid))
        -- 不直接拒绝，只警告
    end

    -- 检测2：出价金额超出可用余额
    if amount > availableFunds then
        state:AddWarning("出价超出余额: " .. amount .. " > " .. availableFunds)
        return false, "出价超出可用余额"
    end

    -- 检测3：出价比例异常（全押检测）
    if availableFunds > 0 then
        local ratio = amount / availableFunds
        if ratio > cfg.maxBidRatio then
            state:AddWarning("出价比例异常: " .. string.format("%.2f%%", ratio * 100))
        end
    end

    -- 检测4：连续最大出价
    if amount == availableFunds and availableFunds > 0 then
        state.consecutiveMaxBids = state.consecutiveMaxBids + 1
        if state.consecutiveMaxBids >= 3 then
            state:AddWarning("连续全押3次以上")
        end
    else
        state.consecutiveMaxBids = 0
    end

    -- 检测5：出价金额异常（与历史差异过大）
    if state.lastBidAmount > 0 then
        local diff = math.abs(amount - state.lastBidAmount) / state.lastBidAmount
        if diff > 5.0 and amount > 1000 then  -- 差异超过500%且金额较大
            state:AddWarning(string.format("出价跳跃异常: %d -> %d", state.lastBidAmount, amount))
        end
    end

    -- 更新状态
    state.lastBidTime = timestamp
    state.lastBidAmount = amount
    state:RecordAction()

    -- 检查惩罚阈值
    if state.warnings >= AntiCheat.Config.penalty.kickThreshold then
        return false, "检测到异常行为，已被临时封禁"
    end

    return true, nil
end

-- ============================================================================
-- 操作速度检测
-- ============================================================================

--- 检测操作是否过快
---@param seatIdx number
---@param uid number|nil
---@param actionType string "bid" | "char_select" | "skill"
---@param timestamp number
---@return boolean allowed
---@return string|nil reason
function AntiCheat.CheckOperationSpeed(seatIdx, uid, actionType, timestamp)
    local state = AntiCheat.GetOrCreateState(seatIdx, uid)

    -- 检查是否被封禁
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

    -- 检测操作频率
    if state.actionsThisSecond >= cfg.maxActionsPerSecond then
        state:AddWarning("操作频率过高: " .. state.actionsThisSecond .. "/s")
        return false, "操作过于频繁，请稍后再试"
    end

    -- 检测思考时间不足
    -- 注意：这里需要传入上次操作时间来检测
    -- 简化版本：直接记录操作
    state:RecordAction()

    return true, nil
end

-- ============================================================================
-- 网络异常检测
-- ============================================================================

--- 检测重连频率
---@param seatIdx number
---@param uid number|nil
---@return boolean allowed
---@return string|nil reason
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

--- 检测延迟
---@param seatIdx number
---@param ping number 延迟（毫秒）
---@return boolean allowed
---@return string|nil reason
function AntiCheat.CheckPing(seatIdx, ping)
    local state = AntiCheat.GetOrCreateState(seatIdx, nil)
    local cfg = AntiCheat.Config.network

    if ping > cfg.pingThreshold then
        state:AddWarning("高延迟: " .. ping .. "ms")
        -- 高延迟不阻止游戏，但记录
    end

    return true, nil
end

-- ============================================================================
-- 惩罚管理
-- ============================================================================

--- 警告玩家
---@param seatIdx number
---@param reason string
function AntiCheat.Warn(seatIdx, reason)
    local state = playerStates_[seatIdx]
    if not state then return end

    state:AddWarning(reason)

    if state.warnings >= AntiCheat.Config.penalty.warnThreshold then
        AntiCheat.Kick(seatIdx, "多次违规行为")
    end
end

--- 踢出玩家
---@param seatIdx number
---@param reason string
function AntiCheat.Kick(seatIdx, reason)
    if server_ and server_.KickPlayer then
        server_:KickPlayer(seatIdx, reason)
    end
    print(string.format("[AntiCheat] Kicked seat %d: %s", seatIdx, reason))
end

--- 封禁玩家
---@param seatIdx number
---@param duration number 秒
---@param reason string
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

--- 获取玩家作弊历史
---@param seatIdx number
---@return table
function AntiCheat.GetHistory(seatIdx)
    local state = playerStates_[seatIdx]
    if not state then return {} end
    return state.history
end

--- 获取玩家警告次数
---@param seatIdx number
---@return number
function AntiCheat.GetWarningCount(seatIdx)
    local state = playerStates_[seatIdx]
    if not state then return 0 end
    return state.warnings
end

-- ============================================================================
-- 服务端集成钩子
-- ============================================================================

--- 创建反作弊集成模块
---@param Server table Server 模块
---@return table 集成函数
function AntiCheat.Integrate(Server)
    local Integrator = {}

    --- 在处理出价前调用
    ---@param seatIdx number
    ---@param uid number|nil
    ---@param amount number
    ---@param availableFunds number
    ---@return boolean, string|nil
    function Integrator.OnBeforeBid(seatIdx, uid, amount, availableFunds)
        return AntiCheat.CheckBid(seatIdx, uid, amount, availableFunds, os.time())
    end

    --- 在处理技能使用前调用
    ---@param seatIdx number
    ---@param uid number|nil
    ---@return boolean, string|nil
    function Integrator.OnBeforeSkill(seatIdx, uid)
        return AntiCheat.CheckOperationSpeed(seatIdx, uid, "skill", os.time())
    end

    --- 在玩家断线重连时调用
    ---@param seatIdx number
    ---@param uid number|nil
    ---@return boolean, string|nil
    function Integrator.OnReconnect(seatIdx, uid)
        return AntiCheat.CheckReconnect(seatIdx, uid)
    end

    --- 更新延迟
    ---@param seatIdx number
    ---@param ping number
    function Integrator.OnPingUpdate(seatIdx, ping)
        AntiCheat.CheckPing(seatIdx, ping)
    end

    --- 玩家加入时初始化
    ---@param seatIdx number
    ---@param uid number|nil
    function Integrator.OnPlayerJoin(seatIdx, uid)
        AntiCheat.GetOrCreateState(seatIdx, uid)
    end

    --- 玩家离开时清理
    ---@param seatIdx number
    function Integrator.OnPlayerLeave(seatIdx)
        AntiCheat.ClearState(seatIdx)
    end

    return Integrator
end

return AntiCheat
