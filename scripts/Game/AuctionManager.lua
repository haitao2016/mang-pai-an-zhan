-- ============================================================================
-- AuctionManager.lua - 竞拍总管理器（服务端权威）
-- 编排 BidSystem + RoundManager，驱动完整竞拍流程
-- ============================================================================

local Config   = require("Config")
local BidSystem    = require("Game.BidSystem")
local RoundManager = require("Game.RoundManager")

local cjson = require("cjson")

---@class AuctionManager
local AuctionManager = {}
AuctionManager.__index = AuctionManager

--- 创建竞拍管理器
---@return AuctionManager
function AuctionManager.New()
    local self = setmetatable({}, AuctionManager)

    self.bidSystem = BidSystem.New()
    self.roundManager = RoundManager.New()
    self.gameState = Config.GameState.WAITING
    self.hallConfig = Config.AuctionHalls[1]  -- 默认，由 Server.lua 设置

    -- 每个座位的初始竞拍预算 { [seatIdx] = number }
    self.playerFunds = {}

    -- 玩家信息 { [seatIdx] = { name=string, connection=userdata, isAI=boolean } }
    self.players = {}
    -- AI 座位集合 { [seatIdx] = true }
    self.aiSeats = {}
    -- 当前轮排名结果（临时缓存）
    self.lastResults = nil
    -- 最终赢家
    self.winner = nil

    -- 外部回调（由 Server.lua 设置）
    --- 向指定玩家发送消息
    ---@type fun(seatIdx: number, eventName: string, data: VariantMap)
    self.sendToPlayer = nil
    --- 向所有玩家广播消息
    ---@type fun(eventName: string, data: VariantMap)
    self.broadcastAll = nil
    --- 回合开始回调（AI 用）
    ---@type fun(roundNum: number)|nil
    self.onRoundStartHook = nil
    --- 回合结算回调（AI 用）
    ---@type fun(roundNum: number, results: table)|nil
    self.onRoundSettledHook = nil
    --- 游戏结束回调（Server.lua 用于奖励持久化）
    ---@type fun(winnerSeat: number, isSpeedWin: boolean)|nil
    self.onGameEndHook = nil

    -- 绑定 RoundManager 回调
    self:_BindRoundCallbacks()

    return self
end

--- 绑定 RoundManager 的回调
function AuctionManager:_BindRoundCallbacks()
    local Protocol = require("Network.Protocol")

    -- 回合开始 → 通知客户端
    self.roundManager.onRoundStart = function(roundNum, speedWinMult)
        self.gameState = Config.GameState.BIDDING
        self.bidSystem:StartRound(roundNum)

        if self.broadcastAll then
            self.broadcastAll(
                Protocol.EVENTS.S2C_ROUND_START,
                Protocol.MakeRoundStartMessage(roundNum, Config.Auction.BidTimeLimit, speedWinMult)
            )
        end
        print(string.format("[AuctionManager] Round %d started, broadcast to clients", roundNum))

        -- 触发外部钩子（AI 回合开始通知）
        if self.onRoundStartHook then
            self.onRoundStartHook(roundNum)
        end
    end

    -- 出价超时 → 自动出 0
    self.roundManager.onBidTimeout = function(roundNum)
        self.bidSystem:AutoBidForTimeout()
        self:_DoSettle(roundNum)
    end

    -- 回合结算 → 计算排名并发送结果
    self.roundManager.onRoundSettle = function(roundNum)
        -- 结算已在 onBidTimeout 中完成
        -- 这里只处理阶段切换（结果展示时间）
        self.gameState = Config.GameState.SETTLING
    end

    -- 速胜触发 → 通知客户端
    self.roundManager.onSpeedWin = function(winnerSeat, roundNum)
        self.winner = winnerSeat
        if self.broadcastAll then
            local winnerName = self.players[winnerSeat] and self.players[winnerSeat].name or "???"
            self.broadcastAll(
                Protocol.EVENTS.S2C_SPEED_WIN,
                Protocol.MakeSpeedWinMessage(winnerSeat, winnerName, roundNum)
            )
        end
    end

    -- 游戏结束 → 发送最终结果
    self.roundManager.onGameOver = function(isSpeedWin)
        self:_DoGameEnd(isSpeedWin)
    end

    -- 倒计时同步
    self.roundManager.onTimerTick = function(timeLeft)
        if self.broadcastAll then
            self.broadcastAll(
                Protocol.EVENTS.S2C_TIMER_SYNC,
                Protocol.MakeTimerSyncMessage(timeLeft)
            )
        end
    end
end

--- 添加玩家
---@param seatIdx number 座位号
---@param playerName string 玩家昵称
---@param connection userdata|nil 网络连接（AI 为 nil）
---@param isAI boolean|nil 是否为 AI 玩家
function AuctionManager:AddPlayer(seatIdx, playerName, connection, isAI)
    self.players[seatIdx] = {
        name = playerName,
        connection = connection,
        isAI = isAI or false,
    }
    if isAI then
        self.aiSeats[seatIdx] = true
    end
    -- 注：竞拍预算在 TryStartGame(playerFundsMap) 时才初始化
    print(string.format("[AuctionManager] %s '%s' joined at seat %d",
        isAI and "AI" or "Player", playerName, seatIdx))
end

--- 移除玩家
---@param seatIdx number
function AuctionManager:RemovePlayer(seatIdx)
    if self.players[seatIdx] then
        print(string.format("[AuctionManager] %s '%s' left from seat %d",
            self.players[seatIdx].isAI and "AI" or "Player",
            self.players[seatIdx].name, seatIdx))
        self.players[seatIdx] = nil
        self.aiSeats[seatIdx] = nil
        self.bidSystem:RemovePlayer(seatIdx)
    end
end

--- 获取当前玩家数
---@return number
function AuctionManager:GetPlayerCount()
    local count = 0
    for _ in pairs(self.players) do
        count = count + 1
    end
    return count
end

--- 尝试开始比赛
---@param playerFundsMap table<number, number> 每个座位的竞拍预算 { [seatIdx] = funds }
---@return boolean started
function AuctionManager:TryStartGame(playerFundsMap)
    local playerCount = self:GetPlayerCount()
    if playerCount < 2 then
        print("[AuctionManager] Not enough players to start")
        return false
    end

    -- 用每人不同的预算初始化 BidSystem
    self.playerFunds = playerFundsMap or {}
    for seatIdx in pairs(self.players) do
        local funds = self.playerFunds[seatIdx] or Config.Auction.InitialFunds
        self.bidSystem:InitPlayer(seatIdx, funds)
    end

    self.gameState = Config.GameState.PREPARING

    -- 逐人发送 GameStart（每人看到自己的预算）
    local Protocol = require("Network.Protocol")
    for seatIdx in pairs(self.players) do
        local funds = self.playerFunds[seatIdx] or Config.Auction.InitialFunds
        if self.sendToPlayer then
            self.sendToPlayer(seatIdx, Protocol.EVENTS.S2C_GAME_START,
                Protocol.MakeGameStartMessage(
                    funds,
                    Config.Auction.TotalRounds,
                    self.hallConfig.name,
                    playerCount
                )
            )
        end
    end

    -- 启动回合管理器
    self.roundManager:StartGame()
    print(string.format("[AuctionManager] Game started! Hall=%s, players=%d",
        self.hallConfig.name, playerCount))
    return true
end

--- 处理玩家出价
---@param seatIdx number
---@param amount number
---@return boolean accepted
---@return string reason
function AuctionManager:HandleBid(seatIdx, amount)
    -- 只在出价阶段接受
    if not self.roundManager:IsBidding() then
        return false, "当前不是出价阶段"
    end

    local accepted, reason = self.bidSystem:SubmitBid(seatIdx, amount)

    -- 发送确认
    if self.sendToPlayer then
        local Protocol = require("Network.Protocol")
        self.sendToPlayer(seatIdx, Protocol.EVENTS.S2C_BID_ACK,
            Protocol.MakeBidAckMessage(accepted, reason))
    end

    -- 如果所有人都出完了，提前结束出价阶段
    if accepted and self.bidSystem:AllBidsSubmitted() then
        print("[AuctionManager] All bids in, settling early")
        self.roundManager:NotifyAllBidsIn()
        self:_DoSettle(self.roundManager:GetCurrentRound())
    end

    return accepted, reason
end

--- 执行回合结算
---@param roundNum number
function AuctionManager:_DoSettle(roundNum)
    local results = self.bidSystem:SettleRound(roundNum)
    self.lastResults = results

    -- 向每个玩家发送其个人排名（模糊信息）
    local Protocol = require("Network.Protocol")
    for _, entry in ipairs(results) do
        local hint = Config.HintMessages[entry.rank] or "未知"
        local totalBid = self.bidSystem:GetTotalBid(entry.seatIdx)
        local fundsLeft = self.bidSystem:GetAvailableFunds(entry.seatIdx)

        if self.sendToPlayer then
            self.sendToPlayer(entry.seatIdx, Protocol.EVENTS.S2C_ROUND_RESULT,
                Protocol.MakeRoundResultMessage(roundNum, entry.rank, hint, totalBid, fundsLeft))
        end
    end

    -- 触发外部钩子（AI 排名记录）
    if self.onRoundSettledHook then
        self.onRoundSettledHook(roundNum, results)
    end

    -- 检查速胜
    local isSpeedWin, winnerSeat = self.roundManager:CheckSpeedWin(results)
    if isSpeedWin then
        self.roundManager:TriggerSpeedWin(winnerSeat)
    end
end

--- 处理游戏结束
---@param isSpeedWin boolean
function AuctionManager:_DoGameEnd(isSpeedWin)
    self.gameState = Config.GameState.GAME_OVER

    -- 确定最终赢家
    if not isSpeedWin then
        -- 普通结束：累计出价最高的获胜
        local maxBid = -1
        local winSeat = nil
        for seatIdx in pairs(self.players) do
            local total = self.bidSystem:GetTotalBid(seatIdx)
            if total > maxBid then
                maxBid = total
                winSeat = seatIdx
            end
        end
        self.winner = winSeat
    end

    -- 构建完整出价历史 JSON
    local history = self.bidSystem:GetBidHistory()
    local historyForJson = {}
    for round, bids in pairs(history) do
        historyForJson[tostring(round)] = {}
        for seat, amount in pairs(bids) do
            historyForJson[tostring(round)][tostring(seat)] = amount
        end
    end
    local allBidsJson = cjson.encode(historyForJson)

    -- 广播结束
    local Protocol = require("Network.Protocol")
    local winnerName = "???"
    if self.winner and self.players[self.winner] then
        winnerName = self.players[self.winner].name
    end

    if self.broadcastAll then
        self.broadcastAll(
            Protocol.EVENTS.S2C_GAME_END,
            Protocol.MakeGameEndMessage(self.winner or 0, winnerName, isSpeedWin, allBidsJson)
        )
    end

    print(string.format("[AuctionManager] Game ended! Winner: Seat %d (%s), SpeedWin: %s",
        self.winner or 0, winnerName, tostring(isSpeedWin)))

    -- 触发游戏结束钩子（Server.lua 用于奖励持久化）
    if self.onGameEndHook then
        self.onGameEndHook(self.winner, isSpeedWin)
    end
end

--- 每帧更新
---@param dt number
function AuctionManager:Update(dt)
    if self.gameState == Config.GameState.WAITING then
        return
    end
    self.roundManager:Update(dt)
end

--- 获取当前游戏状态
---@return string
function AuctionManager:GetGameState()
    return self.gameState
end

--- 获取当前轮次
---@return number
function AuctionManager:GetCurrentRound()
    return self.roundManager:GetCurrentRound()
end

--- 获取当前阶段剩余时间
---@return number
function AuctionManager:GetTimeLeft()
    return self.roundManager:GetTimeLeft()
end

--- 获取赢家座位号
---@return number|nil
function AuctionManager:GetWinner()
    return self.winner
end

--- 获取出价系统（用于外部查询余额等）
---@return BidSystem
function AuctionManager:GetBidSystem()
    return self.bidSystem
end

--- 检查座位是否为 AI
---@param seatIdx number
---@return boolean
function AuctionManager:IsAI(seatIdx)
    return self.aiSeats[seatIdx] == true
end

--- 获取所有 AI 座位列表
---@return number[]
function AuctionManager:GetAISeats()
    local seats = {}
    for seatIdx in pairs(self.aiSeats) do
        table.insert(seats, seatIdx)
    end
    table.sort(seats)
    return seats
end

return AuctionManager
