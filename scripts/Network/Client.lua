-- ============================================================================
-- Client.lua - 客户端网络逻辑（盲拍暗战）Phase 3
-- 管理与服务器的通信、游戏状态同步、UI 驱动
-- Phase 2: 角色选择、技能使用、被动通知
-- Phase 3: 持久化经济、大厅选择、社交表情、收藏馆、新手引导
-- ============================================================================

require "LuaScripts/Utilities/Sample"

local Config   = require("Config")
local Protocol = require("Network.Protocol")
local Helper   = require("Utils.Helper")
local cjson    = require("cjson")

local Client = {}

-- ============================================================================
-- 客户端游戏状态（供 UI 读取）
-- ============================================================================

Client.state = {
    -- 连接状态
    connected = false,
    mySeat = 0,
    myName = "",

    -- 游戏信息
    gameState = Config.GameState.WAITING,
    currentRound = 0,
    totalRounds = 0,
    hallName = "",
    playerCount = 0,

    -- 余额
    funds = 0,
    totalBid = 0,

    -- 出价阶段
    timeLeft = 0,
    speedWinMult = 0,
    bidSubmitted = false,
    lastBidAccepted = false,
    lastBidReason = "",

    -- 结果
    lastRank = 0,
    lastHint = "",

    -- 速胜/结束
    winnerSeat = 0,
    winnerName = "",
    isSpeedWin = false,
    allBidsJson = "",

    -- 拍卖物品（开局时服务端广播）
    auctionItems = {},      -- { {name, rarity, valueRange, category}, ... }
    auctionTotalValueMin = 0,  -- 拍卖物品总估值下限
    auctionTotalValueMax = 0,  -- 拍卖物品总估值上限

    -- 揭示
    revealItems = {},       -- { {name, rarity, value, category}, ... }
    revealTotalValue = 0,
    revealBidTotal = 0,
    revealProfit = 0,

    -- 其他玩家 { [seatIdx] = { name=string, charId=string, charName=string } }
    players = {},

    -- === Phase 2: 角色选择 ===
    charSelectActive = false,       -- 是否处于角色选择阶段
    charSelectTimeLeft = 0,         -- 角色选择剩余时间
    availableChars = {},            -- 可选角色列表（从 JSON 解析）
    selectedChars = {},             -- { [seatIdx] = { charId, charName } }
    myCharId = "",                  -- 自己选的角色 id
    myCharName = "",                -- 自己选的角色名
    myCharData = nil,               -- 自己角色的完整数据（从 availableChars 中查到）

    -- === Phase 2: 技能 ===
    skillInfo = nil,                -- 当前技能状态 { skillName, cd, usesLeft, maxUses, canUse }
    lastSkillResult = nil,          -- 最近一次技能结果 { success, skillName, resultData }
    skillNeedsTarget = false,       -- 当前角色技能是否需要选择目标

    -- === Phase 2: 被动 ===
    passiveMessages = {},           -- 被动触发消息列表 { {name, desc}, ... }

    -- === Phase 3: 经济 ===
    balance = 0,                    -- 持久化账户余额
    lastBalanceDelta = 0,           -- 最近一次余额变动
    lastBalanceReason = "",         -- 最近一次变动原因

    -- === Phase 3: 大厅 ===
    selectedHallId = "",            -- 当前选择的拍卖厅 id

    -- === Phase 3: 收藏馆 ===
    collection = {},                -- 藏品列表（从服务端获取）
    collectionCount = 0,            -- 藏品总数
    collectionTotalValue = 0,       -- 藏品总价值

    -- === Phase 3: 奖励 ===
    rewardItems = {},               -- 最近一次获胜奖励藏品
    rewardTotalValue = 0,           -- 奖励总价值

    -- === Phase 3: 出售 ===
    lastSellResult = nil,           -- 最近出售结果 { success, itemName, sellPrice, reason }

    -- === Phase 3: 社交 ===
    lastEmote = nil,                -- 最近收到的表情 { seatIdx, emoteId, emoteText }
}

-- UI 更新回调（由 UI 模块设置）
Client.onStateChanged = nil  -- function(key, value)

-- ============================================================================
-- 模块变量
-- ============================================================================

---@type Scene
local scene_ = nil

-- ============================================================================
-- 初始化
-- ============================================================================

function Client.Start()
    SampleStart()
    Protocol.RegisterEvents()

    -- 创建本地场景
    scene_ = Scene()
    scene_:CreateComponent("Octree")

    -- 设置服务端场景（background_match 模式下，首次 Start 时可能尚无连接）
    local serverConn = network.serverConnection
    if serverConn then
        serverConn.scene = scene_
        print("[Client] serverConnection available at Start")
    else
        print("[Client] serverConnection not yet available (background_match mode)")
    end

    -- 订阅 ServerReady —— background_match 模式下匹配成功的通知
    SubscribeToEvent("ServerReady", "Client_HandleServerReady")

    -- 订阅网络消息 —— Phase 1
    SubscribeToEvent(Protocol.EVENTS.ASSIGN_SEAT, "Client_HandleAssignSeat")
    SubscribeToEvent(Protocol.EVENTS.S2C_GAME_START, "Client_HandleGameStart")
    SubscribeToEvent(Protocol.EVENTS.S2C_AUCTION_ITEMS, "Client_HandleAuctionItems")
    SubscribeToEvent(Protocol.EVENTS.S2C_ROUND_START, "Client_HandleRoundStart")
    SubscribeToEvent(Protocol.EVENTS.S2C_BID_ACK, "Client_HandleBidAck")
    SubscribeToEvent(Protocol.EVENTS.S2C_ROUND_RESULT, "Client_HandleRoundResult")
    SubscribeToEvent(Protocol.EVENTS.S2C_SPEED_WIN, "Client_HandleSpeedWin")
    SubscribeToEvent(Protocol.EVENTS.S2C_GAME_END, "Client_HandleGameEnd")
    SubscribeToEvent(Protocol.EVENTS.S2C_TIMER_SYNC, "Client_HandleTimerSync")
    SubscribeToEvent(Protocol.EVENTS.S2C_REVEAL_START, "Client_HandleRevealStart")
    SubscribeToEvent(Protocol.EVENTS.S2C_REVEAL_ITEM, "Client_HandleRevealItem")
    SubscribeToEvent(Protocol.EVENTS.S2C_REVEAL_TOTAL, "Client_HandleRevealTotal")
    SubscribeToEvent(Protocol.EVENTS.S2C_PLAYER_JOIN, "Client_HandlePlayerJoin")
    SubscribeToEvent(Protocol.EVENTS.S2C_PLAYER_LEAVE, "Client_HandlePlayerLeave")

    -- 订阅网络消息 —— Phase 2: 角色选择 + 技能
    SubscribeToEvent(Protocol.EVENTS.S2C_CHAR_SELECT_START, "Client_HandleCharSelectStart")
    SubscribeToEvent(Protocol.EVENTS.S2C_CHAR_SELECTED, "Client_HandleCharSelected")
    SubscribeToEvent(Protocol.EVENTS.S2C_CHAR_SELECT_END, "Client_HandleCharSelectEnd")
    SubscribeToEvent(Protocol.EVENTS.S2C_SKILL_RESULT, "Client_HandleSkillResult")
    SubscribeToEvent(Protocol.EVENTS.S2C_SKILL_INFO, "Client_HandleSkillInfo")
    SubscribeToEvent(Protocol.EVENTS.S2C_PASSIVE_INFO, "Client_HandlePassiveInfo")

    -- 订阅网络消息 —— Phase 3: 经济 + 收藏 + 社交 + 引导
    SubscribeToEvent(Protocol.EVENTS.S2C_PLAYER_DATA, "Client_HandlePlayerData")
    SubscribeToEvent(Protocol.EVENTS.S2C_BALANCE_UPDATE, "Client_HandleBalanceUpdate")
    SubscribeToEvent(Protocol.EVENTS.S2C_REWARD, "Client_HandleReward")
    SubscribeToEvent(Protocol.EVENTS.S2C_SELL_RESULT, "Client_HandleSellResult")
    SubscribeToEvent(Protocol.EVENTS.S2C_COLLECTION_DATA, "Client_HandleCollectionData")
    SubscribeToEvent(Protocol.EVENTS.S2C_EMOTE, "Client_HandleEmote")

    -- 延迟一帧尝试发送 ClientReady（非 background_match 模式下连接已存在）
    Helper.DelayOneFrame(function()
        Client._TrySendClientReady()
    end)

    print("[Client] Initialized (Phase 3)")
end

--- ServerReady 事件处理（background_match 模式下匹配成功时触发）
function Client_HandleServerReady(eventType, eventData)
    print("[Client] ServerReady event received — match succeeded!")
    -- 绑定场景到新建立的连接
    local conn = network.serverConnection
    if conn then
        conn.scene = scene_
        print("[Client] Bound scene to serverConnection")
    end
    -- 延迟一帧确保连接稳定后发送 ClientReady
    Helper.DelayOneFrame(function()
        Client._TrySendClientReady()
    end)
end

--- 尝试发送 ClientReady（兼容两种匹配模式）
function Client._TrySendClientReady()
    local conn = network.serverConnection
    if conn then
        conn:SendRemoteEvent(Protocol.EVENTS.CLIENT_READY, true)
        print("[Client] Sent ClientReady")
    else
        print("[Client] serverConnection still nil, waiting for ServerReady...")
    end
end

-- ============================================================================
-- Phase 1 网络消息处理
-- ============================================================================

function Client_HandleAssignSeat(eventType, eventData)
    Client.state.mySeat = eventData["SeatIdx"]:GetInt()
    Client.state.myName = eventData["PlayerName"]:GetString()
    Client.state.connected = true

    print(string.format("[Client] Assigned seat %d as '%s'",
        Client.state.mySeat, Client.state.myName))
    Client._NotifyUI("seat")

    -- 自动发送匹配前暂存的大厅选择
    if Client.state.pendingHallId then
        local hallId = Client.state.pendingHallId
        Client.state.pendingHallId = nil
        print(string.format("[Client] Auto-sending pending hall select: %s", hallId))
        Client._SendHallSelect(hallId)
    end
end

function Client_HandleGameStart(eventType, eventData)
    Client.state.funds = eventData["Funds"]:GetInt()
    Client.state.totalRounds = eventData["TotalRounds"]:GetInt()
    Client.state.hallName = eventData["HallName"]:GetString()
    Client.state.playerCount = eventData["PlayerCount"]:GetInt()
    Client.state.gameState = Config.GameState.PREPARING
    Client.state.totalBid = 0

    print(string.format("[Client] Game started! Funds: %d, Rounds: %d, Hall: %s",
        Client.state.funds, Client.state.totalRounds, Client.state.hallName))
    Client._NotifyUI("gameStart")
end

function Client_HandleAuctionItems(eventType, eventData)
    local itemsJson = eventData["Items"]:GetString()
    local ok, items = pcall(cjson.decode, itemsJson)
    if ok and items then
        Client.state.auctionItems = items
        local totalMin, totalMax = 0, 0
        for _, item in ipairs(items) do
            local vr = item.valueRange
            if vr then
                totalMin = totalMin + (vr[1] or 0)
                totalMax = totalMax + (vr[2] or 0)
            end
        end
        Client.state.auctionTotalValueMin = totalMin
        Client.state.auctionTotalValueMax = totalMax
        print(string.format("[Client] Received %d auction items, estimate=%d~%d", #items, totalMin, totalMax))
    else
        print("[Client] Failed to parse auction items JSON")
        Client.state.auctionItems = {}
        Client.state.auctionTotalValueMin = 0
        Client.state.auctionTotalValueMax = 0
    end
    Client._NotifyUI("auctionItems")
end

function Client_HandleRoundStart(eventType, eventData)
    Client.state.currentRound = eventData["Round"]:GetInt()
    Client.state.timeLeft = eventData["TimeLimit"]:GetFloat()
    Client.state.speedWinMult = eventData["SpeedWinMult"]:GetFloat()
    Client.state.gameState = Config.GameState.BIDDING
    Client.state.bidSubmitted = false
    -- 清除上次技能结果
    Client.state.lastSkillResult = nil

    print(string.format("[Client] Round %d started (time: %.0f, speedWin: %.2f)",
        Client.state.currentRound, Client.state.timeLeft, Client.state.speedWinMult))
    Client._NotifyUI("roundStart")
end

function Client_HandleBidAck(eventType, eventData)
    Client.state.lastBidAccepted = eventData["Accepted"]:GetBool()
    Client.state.lastBidReason = eventData["Reason"]:GetString()

    if Client.state.lastBidAccepted then
        Client.state.bidSubmitted = true
        print("[Client] Bid accepted")
    else
        print("[Client] Bid rejected: " .. Client.state.lastBidReason)
    end
    Client._NotifyUI("bidAck")
end

function Client_HandleRoundResult(eventType, eventData)
    Client.state.lastRank = eventData["Rank"]:GetInt()
    Client.state.lastHint = eventData["Hint"]:GetString()
    Client.state.totalBid = eventData["TotalBid"]:GetInt()
    Client.state.funds = eventData["FundsLeft"]:GetInt()
    Client.state.gameState = Config.GameState.SETTLING

    print(string.format("[Client] Round result: Rank %d (%s), TotalBid: %d, Funds: %d",
        Client.state.lastRank, Client.state.lastHint,
        Client.state.totalBid, Client.state.funds))
    Client._NotifyUI("roundResult")
end

function Client_HandleSpeedWin(eventType, eventData)
    Client.state.winnerSeat = eventData["WinnerSeat"]:GetInt()
    Client.state.winnerName = eventData["WinnerName"]:GetString()
    Client.state.isSpeedWin = true

    print(string.format("[Client] Speed Win! Seat %d (%s) at round %d",
        Client.state.winnerSeat, Client.state.winnerName,
        eventData["Round"]:GetInt()))
    Client._NotifyUI("speedWin")
end

function Client_HandleGameEnd(eventType, eventData)
    Client.state.winnerSeat = eventData["WinnerSeat"]:GetInt()
    Client.state.winnerName = eventData["WinnerName"]:GetString()
    Client.state.isSpeedWin = eventData["IsSpeedWin"]:GetBool()
    Client.state.allBidsJson = eventData["AllBids"]:GetString()
    Client.state.gameState = Config.GameState.GAME_OVER

    print(string.format("[Client] Game over! Winner: %s (seat %d), SpeedWin: %s",
        Client.state.winnerName, Client.state.winnerSeat,
        tostring(Client.state.isSpeedWin)))
    Client._NotifyUI("gameEnd")
end

function Client_HandleTimerSync(eventType, eventData)
    Client.state.timeLeft = eventData["TimeLeft"]:GetFloat()
    Client._NotifyUI("timer")
end

function Client_HandleRevealStart(eventType, eventData)
    Client.state.gameState = Config.GameState.REVEALING
    Client.state.revealItems = {}
    print("[Client] Reveal started")
    Client._NotifyUI("revealStart")
end

function Client_HandleRevealItem(eventType, eventData)
    local item = {
        index = eventData["ItemIdx"]:GetInt(),
        name = eventData["ItemName"]:GetString(),
        rarity = eventData["ItemRarity"]:GetInt(),
        value = eventData["ItemValue"]:GetInt(),
        category = eventData["ItemCategory"]:GetString(),
    }
    table.insert(Client.state.revealItems, item)
    print(string.format("[Client] Reveal item %d: %s [%s] (%d)",
        item.index, item.name, item.category, item.value))
    Client._NotifyUI("revealItem")
end

function Client_HandleRevealTotal(eventType, eventData)
    Client.state.revealTotalValue = eventData["TotalValue"]:GetInt()
    Client.state.revealBidTotal = eventData["BidTotal"]:GetInt()
    Client.state.revealProfit = eventData["Profit"]:GetInt()

    print(string.format("[Client] Reveal total: Value %d, Bid %d, Profit %d",
        Client.state.revealTotalValue, Client.state.revealBidTotal,
        Client.state.revealProfit))
    Client._NotifyUI("revealTotal")
end

function Client_HandlePlayerJoin(eventType, eventData)
    local seatIdx = eventData["SeatIdx"]:GetInt()
    local name = eventData["PlayerName"]:GetString()
    Client.state.players[seatIdx] = Client.state.players[seatIdx] or {}
    Client.state.players[seatIdx].name = name
    print(string.format("[Client] Player joined: seat %d '%s'", seatIdx, name))
    Client._NotifyUI("playerJoin")
end

function Client_HandlePlayerLeave(eventType, eventData)
    local seatIdx = eventData["SeatIdx"]:GetInt()
    Client.state.players[seatIdx] = nil
    print(string.format("[Client] Player left: seat %d", seatIdx))
    Client._NotifyUI("playerLeave")
end

-- ============================================================================
-- Phase 2 网络消息处理：角色选择
-- ============================================================================

function Client_HandleCharSelectStart(eventType, eventData)
    local timeLimit = eventData["TimeLimit"]:GetFloat()
    local availableJson = eventData["Available"]:GetString()

    -- 解析可选角色
    local ok, available = pcall(cjson.decode, availableJson)
    if not ok then
        print("[Client] ERROR: failed to parse available chars JSON")
        available = {}
    end

    Client.state.charSelectActive = true
    Client.state.charSelectTimeLeft = timeLimit
    Client.state.timeLeft = timeLimit  -- 同步给 UI 倒计时
    Client.state.availableChars = available
    Client.state.selectedChars = {}
    Client.state.gameState = Config.GameState.CHAR_SELECT

    -- 检查角色技能是否需要目标（用于 UI 显示目标选择按钮）
    -- 此信息会在选角后从 availableChars 中提取

    print(string.format("[Client] Char select started, %d chars available, time: %.0f",
        #available, timeLimit))
    Client._NotifyUI("charSelectStart")
end

function Client_HandleCharSelected(eventType, eventData)
    local seatIdx = eventData["SeatIdx"]:GetInt()
    local charId = eventData["CharId"]:GetString()
    local charName = eventData["CharName"]:GetString()

    Client.state.selectedChars[seatIdx] = {
        charId = charId,
        charName = charName,
    }

    -- 更新玩家列表中的角色信息
    if Client.state.players[seatIdx] then
        Client.state.players[seatIdx].charId = charId
        Client.state.players[seatIdx].charName = charName
    end

    -- 是否是自己
    if seatIdx == Client.state.mySeat then
        Client.state.myCharId = charId
        Client.state.myCharName = charName
        -- 从 availableChars 中找到完整数据
        for _, c in ipairs(Client.state.availableChars) do
            if c.id == charId then
                Client.state.myCharData = c
                Client.state.skillNeedsTarget = c.activeSkill and c.activeSkill.needsTarget or false
                break
            end
        end
    end

    print(string.format("[Client] Seat %d selected char: %s (%s)",
        seatIdx, charName, charId))
    Client._NotifyUI("charSelected")
end

function Client_HandleCharSelectEnd(eventType, eventData)
    local selectionsJson = eventData["Selections"]:GetString()

    local ok, selections = pcall(cjson.decode, selectionsJson)
    if ok and selections then
        -- 更新所有座位的角色信息
        for seatStr, info in pairs(selections) do
            local seatIdx = tonumber(seatStr)
            if seatIdx then
                Client.state.selectedChars[seatIdx] = {
                    charId = info.characterId,
                    charName = info.characterName,
                }
                if Client.state.players[seatIdx] then
                    Client.state.players[seatIdx].charId = info.characterId
                    Client.state.players[seatIdx].charName = info.characterName
                end
                -- 自己的角色
                if seatIdx == Client.state.mySeat then
                    Client.state.myCharId = info.characterId
                    Client.state.myCharName = info.characterName
                end
            end
        end
    end

    Client.state.charSelectActive = false
    print("[Client] Char select ended")
    Client._NotifyUI("charSelectEnd")
end

-- ============================================================================
-- Phase 2 网络消息处理：技能
-- ============================================================================

function Client_HandleSkillResult(eventType, eventData)
    local success = eventData["Success"]:GetBool()
    local skillName = eventData["SkillName"]:GetString()
    local resultJson = eventData["Result"]:GetString()

    local resultData = {}
    if resultJson and resultJson ~= "" then
        local ok, parsed = pcall(cjson.decode, resultJson)
        if ok then resultData = parsed end
    end

    Client.state.lastSkillResult = {
        success = success,
        skillName = skillName,
        resultData = resultData,
    }

    print(string.format("[Client] Skill result: %s %s - %s",
        skillName, success and "SUCCESS" or "FAIL",
        resultData.desc or resultData.error or ""))
    Client._NotifyUI("skillResult")
end

function Client_HandleSkillInfo(eventType, eventData)
    local skillInfoJson = eventData["SkillInfo"]:GetString()

    local ok, info = pcall(cjson.decode, skillInfoJson)
    if ok then
        Client.state.skillInfo = info
    end

    print(string.format("[Client] Skill info updated: cd=%s, uses=%s",
        tostring(info and info.currentCD or "?"),
        tostring(info and info.usesLeft or "?")))
    Client._NotifyUI("skillInfo")
end

function Client_HandlePassiveInfo(eventType, eventData)
    local passiveName = eventData["PassiveName"]:GetString()
    local desc = eventData["Desc"]:GetString()

    table.insert(Client.state.passiveMessages, {
        name = passiveName,
        desc = desc,
    })

    print(string.format("[Client] Passive triggered: %s - %s", passiveName, desc))
    Client._NotifyUI("passiveInfo")
end

-- ============================================================================
-- Phase 3 网络消息处理：经济 + 收藏 + 社交 + 引导
-- ============================================================================

function Client_HandlePlayerData(eventType, eventData)
    Client.state.balance = eventData["Balance"]:GetInt()
    Client.state.collectionCount = eventData["CollectionCount"]:GetInt()
    Client.state.collectionTotalValue = eventData["TotalValue"]:GetInt()

    print(string.format("[Client] Player data: balance=%d, collection=%d",
        Client.state.balance, Client.state.collectionCount))
    Client._NotifyUI("playerData")
end

function Client_HandleBalanceUpdate(eventType, eventData)
    Client.state.balance = eventData["Balance"]:GetInt()
    Client.state.lastBalanceDelta = eventData["Delta"]:GetInt()
    Client.state.lastBalanceReason = eventData["Reason"]:GetString()

    print(string.format("[Client] Balance update: %d (%+d, %s)",
        Client.state.balance, Client.state.lastBalanceDelta,
        Client.state.lastBalanceReason))
    Client._NotifyUI("balanceUpdate")
end

function Client_HandleReward(eventType, eventData)
    local rewardJson = eventData["Reward"]:GetString()
    Client.state.rewardTotalValue = eventData["TotalValue"]:GetInt()

    local ok, items = pcall(cjson.decode, rewardJson)
    if ok and items then
        Client.state.rewardItems = items
    else
        Client.state.rewardItems = {}
        print("[Client] WARNING: failed to parse reward JSON")
    end

    print(string.format("[Client] Reward received: %d items, total value %d",
        #Client.state.rewardItems, Client.state.rewardTotalValue))
    Client._NotifyUI("reward")
end

function Client_HandleSellResult(eventType, eventData)
    Client.state.lastSellResult = {
        success = eventData["Success"]:GetBool(),
        itemName = eventData["ItemName"]:GetString(),
        sellPrice = eventData["SellPrice"]:GetInt(),
        reason = eventData["Reason"]:GetString(),
    }

    if Client.state.lastSellResult.success then
        print(string.format("[Client] Sold '%s' for %d",
            Client.state.lastSellResult.itemName,
            Client.state.lastSellResult.sellPrice))
    else
        print(string.format("[Client] Sell failed: %s",
            Client.state.lastSellResult.reason))
    end
    Client._NotifyUI("sellResult")
end

function Client_HandleCollectionData(eventType, eventData)
    local collectionJson = eventData["Collection"]:GetString()
    Client.state.collectionCount = eventData["TotalCount"]:GetInt()
    Client.state.collectionTotalValue = eventData["TotalValue"]:GetInt()

    local ok, items = pcall(cjson.decode, collectionJson)
    if ok and items then
        Client.state.collection = items
    else
        Client.state.collection = {}
        print("[Client] WARNING: failed to parse collection JSON")
    end

    print(string.format("[Client] Collection: %d items, total value %d",
        Client.state.collectionCount, Client.state.collectionTotalValue))
    Client._NotifyUI("collectionData")
end

function Client_HandleEmote(eventType, eventData)
    Client.state.lastEmote = {
        seatIdx = eventData["SeatIdx"]:GetInt(),
        emoteId = eventData["EmoteId"]:GetString(),
        emoteText = eventData["EmoteText"]:GetString(),
    }

    print(string.format("[Client] Emote from seat %d: %s",
        Client.state.lastEmote.seatIdx,
        Client.state.lastEmote.emoteText))
    Client._NotifyUI("emote")
end

-- ============================================================================
-- 客户端操作
-- ============================================================================

--- 发送出价
---@param amount number
function Client.SendBid(amount)
    if Client.state.bidSubmitted then
        print("[Client] Already bid this round")
        return
    end
    if Client.state.gameState ~= Config.GameState.BIDDING then
        print("[Client] Not in bidding phase")
        return
    end

    local serverConn = network.serverConnection
    if not serverConn then
        print("[Client] ERROR: no serverConnection when sending bid")
        return
    end
    local data = Protocol.MakeBidMessage(amount)
    serverConn:SendRemoteEvent(Protocol.EVENTS.C2S_BID, true, data)
    print(string.format("[Client] Sent bid: %d", math.floor(amount)))
end

--- 发送角色选择 (Phase 2)
---@param charId string
function Client.SelectCharacter(charId)
    if not Client.state.charSelectActive then
        print("[Client] Not in char select phase")
        return
    end

    -- 检查是否已被其他玩家选择
    for seatIdx, sel in pairs(Client.state.selectedChars) do
        if sel.charId == charId and seatIdx ~= Client.state.mySeat then
            print(string.format("[Client] Character %s already taken by seat %d", charId, seatIdx))
            return
        end
    end

    local serverConn = network.serverConnection
    if not serverConn then
        print("[Client] ERROR: no serverConnection when selecting char")
        return
    end
    local data = Protocol.MakeSelectCharMessage(charId)
    serverConn:SendRemoteEvent(Protocol.EVENTS.C2S_SELECT_CHAR, true, data)
    print(string.format("[Client] Sent char select: %s", charId))
end

--- 使用主动技能 (Phase 2)
---@param targetSeat number|nil 目标座位（部分技能需要）
function Client.UseSkill(targetSeat)
    if Client.state.gameState ~= Config.GameState.BIDDING then
        print("[Client] Can only use skill during bidding phase")
        return
    end

    local serverConn = network.serverConnection
    if not serverConn then
        print("[Client] ERROR: no serverConnection when using skill")
        return
    end
    local data = Protocol.MakeUseSkillMessage(targetSeat)
    serverConn:SendRemoteEvent(Protocol.EVENTS.C2S_USE_SKILL, true, data)
    print(string.format("[Client] Sent use skill, target: %s", tostring(targetSeat or "none")))
end

-- ============================================================================
-- Phase 3 客户端操作
-- ============================================================================

--- 选择拍卖厅
---@param hallId string 拍卖厅 id（如 "hall_beginner"）
function Client.SelectHall(hallId)
    Client.state.selectedHallId = hallId
    local serverConn = network.serverConnection
    if not serverConn then
        -- 匹配尚未完成，暂存 hallId，等 AssignSeat 后自动发送
        Client.state.pendingHallId = hallId
        print(string.format("[Client] No connection yet, pending hall select: %s", hallId))
        return
    end
    Client._SendHallSelect(hallId)
end

--- 实际发送大厅选择消息
function Client._SendHallSelect(hallId)
    local serverConn = network.serverConnection
    if not serverConn then return end
    local data = Protocol.MakeSelectHallMessage(hallId)
    serverConn:SendRemoteEvent(Protocol.EVENTS.C2S_SELECT_HALL, true, data)
    print(string.format("[Client] Sent hall select: %s", hallId))
end

--- 出售藏品
---@param itemId string 藏品唯一标识
function Client.SellItem(itemId)
    local serverConn = network.serverConnection
    if not serverConn then
        print("[Client] ERROR: no serverConnection when selling item")
        return
    end
    local data = Protocol.MakeSellItemMessage(itemId)
    serverConn:SendRemoteEvent(Protocol.EVENTS.C2S_SELL_ITEM, true, data)
    print(string.format("[Client] Sent sell item: %s", itemId))
end

--- 发送表情/快捷语
---@param emoteId string 表情 id
function Client.SendEmote(emoteId)
    local serverConn = network.serverConnection
    if not serverConn then
        print("[Client] ERROR: no serverConnection when sending emote")
        return
    end
    local data = Protocol.MakeEmoteMessage(emoteId)
    serverConn:SendRemoteEvent(Protocol.EVENTS.C2S_EMOTE, true, data)
    print(string.format("[Client] Sent emote: %s", emoteId))
end

--- 请求藏品列表
function Client.GetCollection()
    local serverConn = network.serverConnection
    if not serverConn then
        print("[Client] ERROR: no serverConnection when requesting collection")
        return
    end
    serverConn:SendRemoteEvent(Protocol.EVENTS.C2S_GET_COLLECTION, true)
    print("[Client] Sent get collection request")
end

--- 获取可用余额（游戏内）
---@return number
function Client.GetAvailableFunds()
    return Client.state.funds
end

--- 获取账户余额（持久化）
---@return number
function Client.GetBalance()
    return Client.state.balance
end

-- ============================================================================
-- 内部辅助
-- ============================================================================

--- 通知 UI 状态变化
---@param key string
function Client._NotifyUI(key)
    if Client.onStateChanged then
        Client.onStateChanged(key, Client.state)
    end
end

return Client
