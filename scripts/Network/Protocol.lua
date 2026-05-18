-- ============================================================================
-- Protocol.lua - 《盲拍暗战》网络消息协议定义（共享模块）
-- 所有远程事件名称、节点变量名、控制按钮标志统一在此定义
-- ============================================================================

local Protocol = {}

-- ============================================================================
-- 远程事件名称
-- ============================================================================
Protocol.EVENTS = {
    -- 连接阶段
    CLIENT_READY     = "ClientReady",       -- 客户端就绪
    ASSIGN_SEAT      = "AssignSeat",        -- 服务端分配座位号

    -- 角色选择阶段 (Phase 2)
    S2C_CHAR_SELECT_START = "S2C_CharSelectStart", -- 进入角色选择阶段
    C2S_SELECT_CHAR       = "C2S_SelectChar",      -- 客户端选择角色
    S2C_CHAR_SELECTED     = "S2C_CharSelected",    -- 广播某座位选择了角色
    S2C_CHAR_SELECT_END   = "S2C_CharSelectEnd",   -- 角色选择结束

    -- 技能 (Phase 2)
    C2S_USE_SKILL    = "C2S_UseSkill",      -- 客户端使用主动技能
    S2C_SKILL_RESULT = "S2C_SkillResult",   -- 技能使用结果
    S2C_SKILL_INFO   = "S2C_SkillInfo",     -- 技能状态同步（CD/次数）
    S2C_PASSIVE_INFO = "S2C_PassiveInfo",   -- 被动技能触发通知

    -- 竞拍流程
    S2C_GAME_START     = "S2C_GameStart",     -- 比赛开始（含初始余额、轮数等）
    S2C_AUCTION_ITEMS  = "S2C_AuctionItems",  -- 本局拍卖物品列表（游戏开始时广播）
    S2C_ROUND_START    = "S2C_RoundStart",    -- 新回合开始（含倒计时等）
    C2S_BID            = "C2S_Bid",           -- 客户端提交出价
    S2C_BID_ACK        = "S2C_BidAck",        -- 服务端确认收到出价
    S2C_ROUND_RESULT   = "S2C_RoundResult",   -- 回合结果（模糊信息）
    S2C_SPEED_WIN      = "S2C_SpeedWin",      -- 速胜触发
    S2C_GAME_END       = "S2C_GameEnd",       -- 比赛结束（完整揭晓）

    -- 开箱揭示
    S2C_REVEAL_START   = "S2C_RevealStart",   -- 开始开箱
    S2C_REVEAL_ITEM    = "S2C_RevealItem",    -- 逐件揭示
    S2C_REVEAL_TOTAL   = "S2C_RevealTotal",   -- 总价值揭晓

    -- 玩家状态
    S2C_PLAYER_JOIN    = "S2C_PlayerJoin",    -- 玩家加入
    S2C_PLAYER_LEAVE   = "S2C_PlayerLeave",   -- 玩家离开
    S2C_TIMER_SYNC     = "S2C_TimerSync",     -- 倒计时同步

    -- ===================== Phase 3: 大厅选择 =====================
    C2S_SELECT_HALL    = "C2S_SelectHall",    -- 客户端选择拍卖厅
    S2C_PLAYER_DATA    = "S2C_PlayerData",    -- 下发持久化玩家数据（余额、藏品统计等）

    -- ===================== Phase 3: 经济循环 =====================
    S2C_BALANCE_UPDATE = "S2C_BalanceUpdate", -- 余额变动通知（入场费扣除/出售所得）
    S2C_REWARD         = "S2C_Reward",        -- 竞拍获胜奖励（藏品入库）
    C2S_SELL_ITEM      = "C2S_SellItem",      -- 客户端出售藏品
    S2C_SELL_RESULT    = "S2C_SellResult",    -- 出售结果

    -- ===================== Phase 3: 收藏馆 =====================
    C2S_GET_COLLECTION = "C2S_GetCollection", -- 请求藏品列表
    S2C_COLLECTION_DATA = "S2C_CollectionData", -- 藏品列表数据

    -- ===================== Phase 3: 社交 =====================
    C2S_EMOTE          = "C2S_Emote",         -- 发送表情/快捷语
    S2C_EMOTE          = "S2C_Emote",         -- 广播表情/快捷语

}

-- ============================================================================
-- 节点变量名（用于 SetVar/GetVar 同步）
-- ============================================================================
Protocol.VARS = {
    IS_PLAYER    = "IsPlayer",     -- bool: 是否是玩家节点
    SEAT_INDEX   = "SeatIdx",      -- int: 座位号 (1-4)
    PLAYER_NAME  = "PName",        -- string: 玩家昵称
    PLAYER_STATE = "PState",       -- string: 玩家状态
}

-- ============================================================================
-- 注册所有远程事件（服务端和客户端都必须调用）
-- ============================================================================
function Protocol.RegisterEvents()
    for _, eventName in pairs(Protocol.EVENTS) do
        network:RegisterRemoteEvent(eventName)
    end
    print("[Protocol] All remote events registered")
end

-- ============================================================================
-- 工具函数：构建 VariantMap
-- ============================================================================

--- 创建出价消息 (C2S)
---@param amount number 出价金额
---@return VariantMap
function Protocol.MakeBidMessage(amount)
    local data = VariantMap()
    data["Amount"] = Variant(math.floor(amount))
    return data
end

--- 创建角色选择开始消息 (S2C)
---@param timeLimit number 选择时限（秒）
---@param availableJson string 可选角色列表 JSON
---@return VariantMap
function Protocol.MakeCharSelectStartMessage(timeLimit, availableJson)
    local data = VariantMap()
    data["TimeLimit"] = Variant(timeLimit)
    data["Available"] = Variant(availableJson)
    return data
end

--- 创建客户端选角消息 (C2S)
---@param characterId string 角色 id
---@return VariantMap
function Protocol.MakeSelectCharMessage(characterId)
    local data = VariantMap()
    data["CharId"] = Variant(characterId)
    return data
end

--- 创建角色已选通知 (S2C 广播)
---@param seatIdx number 座位号
---@param characterId string 角色 id
---@param characterName string 角色名称
---@return VariantMap
function Protocol.MakeCharSelectedMessage(seatIdx, characterId, characterName)
    local data = VariantMap()
    data["SeatIdx"] = Variant(seatIdx)
    data["CharId"] = Variant(characterId)
    data["CharName"] = Variant(characterName)
    return data
end

--- 创建角色选择结束消息 (S2C)
---@param allSelectionsJson string 所有座位的角色选择 JSON
---@return VariantMap
function Protocol.MakeCharSelectEndMessage(allSelectionsJson)
    local data = VariantMap()
    data["Selections"] = Variant(allSelectionsJson)
    return data
end

--- 创建技能使用消息 (C2S)
---@param targetSeat number|nil 目标座位（部分技能需要）
---@return VariantMap
function Protocol.MakeUseSkillMessage(targetSeat)
    local data = VariantMap()
    data["TargetSeat"] = Variant(targetSeat or 0)
    return data
end

--- 创建技能结果消息 (S2C)
---@param success boolean 是否成功
---@param skillName string 技能名称
---@param resultJson string 技能结果详情 JSON
---@return VariantMap
function Protocol.MakeSkillResultMessage(success, skillName, resultJson)
    local data = VariantMap()
    data["Success"] = Variant(success)
    data["SkillName"] = Variant(skillName)
    data["Result"] = Variant(resultJson or "")
    return data
end

--- 创建技能状态同步消息 (S2C)
---@param skillInfoJson string 技能状态 JSON { skillId, skillName, cd, usesLeft, maxUses }
---@return VariantMap
function Protocol.MakeSkillInfoMessage(skillInfoJson)
    local data = VariantMap()
    data["SkillInfo"] = Variant(skillInfoJson)
    return data
end

--- 创建被动技能触发通知 (S2C)
---@param passiveName string 被动技能名称
---@param desc string 触发描述
---@return VariantMap
function Protocol.MakePassiveInfoMessage(passiveName, desc)
    local data = VariantMap()
    data["PassiveName"] = Variant(passiveName)
    data["Desc"] = Variant(desc)
    return data
end

--- 创建回合开始消息 (S2C)
---@param roundNum number 当前轮次
---@param timeLimit number 出价时限
---@param speedWinMult number 速胜倍率（0表示无速胜）
---@return VariantMap
function Protocol.MakeRoundStartMessage(roundNum, timeLimit, speedWinMult)
    local data = VariantMap()
    data["Round"] = Variant(roundNum)
    data["TimeLimit"] = Variant(timeLimit)
    data["SpeedWinMult"] = Variant(speedWinMult)
    return data
end

--- 创建回合结果消息 (S2C)
---@param roundNum number 当前轮次
---@param rank number 该玩家排名 (1-4)
---@param hint string 模糊提示（"领先"/"接近"/"落后"/"垫底"）
---@param totalBid number 该玩家累计出价
---@param fundsLeft number 该玩家剩余余额
---@return VariantMap
function Protocol.MakeRoundResultMessage(roundNum, rank, hint, totalBid, fundsLeft)
    local data = VariantMap()
    data["Round"] = Variant(roundNum)
    data["Rank"] = Variant(rank)
    data["Hint"] = Variant(hint)
    data["TotalBid"] = Variant(math.floor(totalBid))
    data["FundsLeft"] = Variant(math.floor(fundsLeft))
    return data
end

--- 创建速胜消息 (S2C)
---@param winnerSeat number 胜者座位号
---@param winnerName string 胜者昵称
---@param roundNum number 在第几轮速胜
---@return VariantMap
function Protocol.MakeSpeedWinMessage(winnerSeat, winnerName, roundNum)
    local data = VariantMap()
    data["WinnerSeat"] = Variant(winnerSeat)
    data["WinnerName"] = Variant(winnerName)
    data["Round"] = Variant(roundNum)
    return data
end

--- 创建比赛结束消息 (S2C)
---@param winnerSeat number 胜者座位号
---@param winnerName string 胜者昵称
---@param isSpeedWin boolean 是否速胜
---@param allBidsJson string 所有人所有轮出价的JSON（完整揭晓）
---@return VariantMap
function Protocol.MakeGameEndMessage(winnerSeat, winnerName, isSpeedWin, allBidsJson)
    local data = VariantMap()
    data["WinnerSeat"] = Variant(winnerSeat)
    data["WinnerName"] = Variant(winnerName)
    data["IsSpeedWin"] = Variant(isSpeedWin)
    data["AllBids"] = Variant(allBidsJson)
    return data
end

--- 创建比赛开始消息 (S2C)
---@param funds number 初始余额
---@param totalRounds number 总轮数
---@param hallName string 拍卖厅名称
---@param playerCount number 玩家数量
---@return VariantMap
function Protocol.MakeGameStartMessage(funds, totalRounds, hallName, playerCount)
    local data = VariantMap()
    data["Funds"] = Variant(math.floor(funds))
    data["TotalRounds"] = Variant(totalRounds)
    data["HallName"] = Variant(hallName)
    data["PlayerCount"] = Variant(playerCount)
    return data
end

--- 创建拍卖物品列表消息 (S2C)
---@param itemsJson string 物品列表 JSON（包含 name, rarity, value, category）
---@return VariantMap
function Protocol.MakeAuctionItemsMessage(itemsJson)
    local data = VariantMap()
    data["Items"] = Variant(itemsJson)
    return data
end

--- 创建座位分配消息 (S2C)
---@param seatIndex number 座位号 (1-4)
---@param playerName string 玩家昵称
---@return VariantMap
function Protocol.MakeAssignSeatMessage(seatIndex, playerName)
    local data = VariantMap()
    data["SeatIdx"] = Variant(seatIndex)
    data["PlayerName"] = Variant(playerName)
    return data
end

--- 创建出价确认消息 (S2C)
---@param accepted boolean 是否接受
---@param reason string 拒绝原因（接受时为空）
---@return VariantMap
function Protocol.MakeBidAckMessage(accepted, reason)
    local data = VariantMap()
    data["Accepted"] = Variant(accepted)
    data["Reason"] = Variant(reason or "")
    return data
end

--- 创建倒计时同步消息 (S2C)
---@param timeLeft number 剩余秒数
---@return VariantMap
function Protocol.MakeTimerSyncMessage(timeLeft)
    local data = VariantMap()
    data["TimeLeft"] = Variant(timeLeft)
    return data
end

--- 创建开箱物品揭示消息 (S2C)
---@param itemIndex number 第几件物品
---@param itemName string 物品名称
---@param itemRarity number 稀有度等级 (1-4)
---@param itemValue number 物品价值
---@param itemCategory string 物品分类
---@return VariantMap
function Protocol.MakeRevealItemMessage(itemIndex, itemName, itemRarity, itemValue, itemCategory)
    local data = VariantMap()
    data["ItemIdx"] = Variant(itemIndex)
    data["ItemName"] = Variant(itemName)
    data["ItemRarity"] = Variant(itemRarity)
    data["ItemValue"] = Variant(math.floor(itemValue))
    data["ItemCategory"] = Variant(itemCategory or "")
    return data
end

--- 创建总价值揭晓消息 (S2C)
---@param totalValue number 藏品总价值
---@param bidTotal number 竞拍总出价
---@param profit number 盈亏
---@return VariantMap
function Protocol.MakeRevealTotalMessage(totalValue, bidTotal, profit)
    local data = VariantMap()
    data["TotalValue"] = Variant(math.floor(totalValue))
    data["BidTotal"] = Variant(math.floor(bidTotal))
    data["Profit"] = Variant(math.floor(profit))
    return data
end

--- 创建玩家加入通知消息 (S2C)
---@param seatIndex number 座位号
---@param playerName string 玩家昵称
---@return VariantMap
function Protocol.MakePlayerJoinMessage(seatIndex, playerName)
    local data = VariantMap()
    data["SeatIdx"] = Variant(seatIndex)
    data["PlayerName"] = Variant(playerName)
    return data
end

--- 创建玩家离开通知消息 (S2C)
---@param seatIndex number 座位号
---@return VariantMap
function Protocol.MakePlayerLeaveMessage(seatIndex)
    local data = VariantMap()
    data["SeatIdx"] = Variant(seatIndex)
    return data
end

-- ============================================================================
-- Phase 3: 大厅选择消息
-- ============================================================================

--- 创建选择拍卖厅消息 (C2S)
---@param hallId string 拍卖厅 id（如 "hall_beginner"）
---@return VariantMap
function Protocol.MakeSelectHallMessage(hallId)
    local data = VariantMap()
    data["HallId"] = Variant(hallId)
    return data
end

--- 创建玩家持久化数据消息 (S2C)
---@param balance number 账户余额
---@param collectionCount number 藏品数量
---@param totalValue number 藏品总价值
---@return VariantMap
function Protocol.MakePlayerDataMessage(balance, collectionCount, totalValue)
    local data = VariantMap()
    data["Balance"] = Variant(math.floor(balance))
    data["CollectionCount"] = Variant(collectionCount)
    data["TotalValue"] = Variant(math.floor(totalValue))
    return data
end

-- ============================================================================
-- Phase 3: 经济循环消息
-- ============================================================================

--- 创建余额变动通知 (S2C)
---@param newBalance number 更新后余额
---@param delta number 变动金额（正=收入，负=支出）
---@param reason string 变动原因（如 "entry_fee"、"sell_item"、"reward"）
---@return VariantMap
function Protocol.MakeBalanceUpdateMessage(newBalance, delta, reason)
    local data = VariantMap()
    data["Balance"] = Variant(math.floor(newBalance))
    data["Delta"] = Variant(math.floor(delta))
    data["Reason"] = Variant(reason)
    return data
end

--- 创建竞拍奖励消息 (S2C) — 获胜后藏品入库
---@param rewardJson string 奖励藏品列表 JSON
---@param totalValue number 藏品总价值
---@return VariantMap
function Protocol.MakeRewardMessage(rewardJson, totalValue)
    local data = VariantMap()
    data["Reward"] = Variant(rewardJson)
    data["TotalValue"] = Variant(math.floor(totalValue))
    return data
end

--- 创建出售藏品消息 (C2S)
---@param itemId string 藏品唯一标识
---@return VariantMap
function Protocol.MakeSellItemMessage(itemId)
    local data = VariantMap()
    data["ItemId"] = Variant(itemId)
    return data
end

--- 创建出售结果消息 (S2C)
---@param success boolean 是否成功
---@param itemName string 藏品名称
---@param sellPrice number 出售价格
---@param reason string 失败原因（成功时为空）
---@return VariantMap
function Protocol.MakeSellResultMessage(success, itemName, sellPrice, reason)
    local data = VariantMap()
    data["Success"] = Variant(success)
    data["ItemName"] = Variant(itemName or "")
    data["SellPrice"] = Variant(math.floor(sellPrice or 0))
    data["Reason"] = Variant(reason or "")
    return data
end

-- ============================================================================
-- Phase 3: 收藏馆消息
-- ============================================================================

--- 创建藏品列表数据消息 (S2C)
---@param collectionJson string 完整藏品列表 JSON
---@param totalCount number 总数
---@param totalValue number 总价值
---@return VariantMap
function Protocol.MakeCollectionDataMessage(collectionJson, totalCount, totalValue)
    local data = VariantMap()
    data["Collection"] = Variant(collectionJson)
    data["TotalCount"] = Variant(totalCount)
    data["TotalValue"] = Variant(math.floor(totalValue))
    return data
end

-- ============================================================================
-- Phase 3: 社交消息
-- ============================================================================

--- 创建发送表情消息 (C2S)
---@param emoteId string 表情 id
---@return VariantMap
function Protocol.MakeEmoteMessage(emoteId)
    local data = VariantMap()
    data["EmoteId"] = Variant(emoteId)
    return data
end

--- 创建广播表情消息 (S2C)
---@param seatIdx number 发送者座位号
---@param emoteId string 表情 id
---@param emoteText string 表情显示文本
---@return VariantMap
function Protocol.MakeBroadcastEmoteMessage(seatIdx, emoteId, emoteText)
    local data = VariantMap()
    data["SeatIdx"] = Variant(seatIdx)
    data["EmoteId"] = Variant(emoteId)
    data["EmoteText"] = Variant(emoteText)
    return data
end

return Protocol
