-- ============================================================================
-- BidSystem.lua - 出价系统（服务端权威）
-- 管理每轮出价的收集、校验、排序和结算
-- ============================================================================

local Config = require("Config")

---@class BidSystem
local BidSystem = {}
BidSystem.__index = BidSystem

--- 创建出价系统实例
---@return BidSystem
function BidSystem.New()
    local self = setmetatable({}, BidSystem)
    -- 玩家余额 { [seatIdx] = number }
    self.funds = {}
    -- 玩家累计出价 { [seatIdx] = number }
    self.totalBids = {}
    -- 当前轮出价 { [seatIdx] = number }
    self.currentBids = {}
    -- 历史每轮出价 { [round] = { [seatIdx] = number } }
    self.bidHistory = {}
    -- 已锁定（已提交出价）的座位 { [seatIdx] = true }
    self.lockedSeats = {}
    -- 活跃座位列表
    self.activeSeats = {}
    return self
end

--- 初始化玩家余额
---@param seatIdx number 座位号
---@param funds number 初始余额（可选，默认用 Config）
function BidSystem:InitPlayer(seatIdx, funds)
    local initFunds = funds or Config.Auction.InitialFunds
    self.funds[seatIdx] = initFunds
    self.totalBids[seatIdx] = 0
    self.activeSeats[seatIdx] = true
    print(string.format("[BidSystem] Seat %d init with funds: %d", seatIdx, initFunds))
end

--- 移除玩家
---@param seatIdx number
function BidSystem:RemovePlayer(seatIdx)
    self.activeSeats[seatIdx] = nil
    print(string.format("[BidSystem] Seat %d removed", seatIdx))
end

--- 开始新一轮出价
---@param roundNum number
function BidSystem:StartRound(roundNum)
    self.currentBids = {}
    self.lockedSeats = {}
    print(string.format("[BidSystem] Round %d bidding started", roundNum))
end

--- 提交出价
---@param seatIdx number 座位号
---@param amount number 出价金额
---@return boolean accepted 是否接受
---@return string reason 拒绝原因
function BidSystem:SubmitBid(seatIdx, amount)
    -- 校验玩家是否活跃
    if not self.activeSeats[seatIdx] then
        return false, "玩家不在游戏中"
    end

    -- 校验是否已锁定（每轮只能出一次价）
    if self.lockedSeats[seatIdx] then
        return false, "本轮已出价"
    end

    -- 校验金额合法性
    amount = math.floor(amount)
    if amount < Config.Auction.MinBid then
        return false, string.format("出价不能低于 %d", Config.Auction.MinBid)
    end

    -- 校验余额
    local availableFunds = self.funds[seatIdx] - self.totalBids[seatIdx]
    if amount > availableFunds then
        return false, string.format("余额不足（可用: %d）", availableFunds)
    end

    -- 记录出价并锁定
    self.currentBids[seatIdx] = amount
    self.lockedSeats[seatIdx] = true
    print(string.format("[BidSystem] Seat %d bid %d (remaining: %d)",
        seatIdx, amount, availableFunds - amount))

    return true, ""
end

--- 获取活跃玩家数
---@return number
function BidSystem:GetActivePlayerCount()
    local count = 0
    for _ in pairs(self.activeSeats) do
        count = count + 1
    end
    return count
end

--- 检查是否所有活跃玩家都已出价
---@return boolean
function BidSystem:AllBidsSubmitted()
    for seatIdx in pairs(self.activeSeats) do
        if not self.lockedSeats[seatIdx] then
            return false
        end
    end
    return true
end

--- 给超时未出价的玩家自动出价 0
function BidSystem:AutoBidForTimeout()
    for seatIdx in pairs(self.activeSeats) do
        if not self.lockedSeats[seatIdx] then
            self.currentBids[seatIdx] = 0
            self.lockedSeats[seatIdx] = true
            print(string.format("[BidSystem] Seat %d auto-bid 0 (timeout)", seatIdx))
        end
    end
end

--- 结算当前轮：排序出价，返回排名结果
---@param roundNum number
---@return table results 排名结果 { {seatIdx, amount, rank}, ... }
function BidSystem:SettleRound(roundNum)
    -- 保存到历史
    self.bidHistory[roundNum] = {}
    for seatIdx, amount in pairs(self.currentBids) do
        self.bidHistory[roundNum][seatIdx] = amount
        -- 累计出价
        self.totalBids[seatIdx] = self.totalBids[seatIdx] + amount
    end

    -- 构建排序列表
    local sortList = {}
    for seatIdx in pairs(self.activeSeats) do
        local amount = self.currentBids[seatIdx] or 0
        table.insert(sortList, { seatIdx = seatIdx, amount = amount })
    end

    -- 按出价降序排列
    table.sort(sortList, function(a, b)
        return a.amount > b.amount
    end)

    -- 分配排名
    local results = {}
    for rank, entry in ipairs(sortList) do
        entry.rank = rank
        table.insert(results, entry)
    end

    print(string.format("[BidSystem] Round %d settled: %d bids", roundNum, #results))
    for _, r in ipairs(results) do
        print(string.format("  Rank %d: Seat %d bid %d", r.rank, r.seatIdx, r.amount))
    end

    return results
end

--- 获取玩家剩余可用余额
---@param seatIdx number
---@return number
function BidSystem:GetAvailableFunds(seatIdx)
    local f = self.funds[seatIdx] or 0
    local t = self.totalBids[seatIdx] or 0
    return f - t
end

--- 获取玩家累计出价
---@param seatIdx number
---@return number
function BidSystem:GetTotalBid(seatIdx)
    return self.totalBids[seatIdx] or 0
end

--- 获取完整出价历史（用于游戏结束时揭晓）
---@return table { [round] = { [seatIdx] = amount } }
function BidSystem:GetBidHistory()
    return self.bidHistory
end

--- 追加余额（技能 SKILL_BUDGET_BOOST 使用）
---@param seatIdx number 座位号
---@param amount number 追加金额
function BidSystem:AddFunds(seatIdx, amount)
    if self.funds[seatIdx] then
        self.funds[seatIdx] = self.funds[seatIdx] + amount
        print(string.format("[BidSystem] Seat %d funds +%d (now: %d)", seatIdx, amount, self.funds[seatIdx]))
    end
end

--- 获取所有活跃座位
---@return table
function BidSystem:GetActiveSeats()
    local seats = {}
    for seatIdx in pairs(self.activeSeats) do
        table.insert(seats, seatIdx)
    end
    table.sort(seats)
    return seats
end

return BidSystem
