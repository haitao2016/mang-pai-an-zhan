-- ============================================================================
-- Server.lua - 服务端网络逻辑（盲拍暗战）Phase 3
-- 管理连接、座位分配、角色选择、技能处理、竞拍流程驱动、开箱揭示
-- Phase 3: serverCloud 持久化、入场费、奖励、出售藏品、表情、收藏馆
-- ============================================================================

require "LuaScripts/Utilities/Sample"

local Config            = require("Config")
local Protocol          = require("Network.Protocol")
local AuctionManager    = require("Game.AuctionManager")
local ItemPool          = require("Game.ItemPool")
local RevealSystem      = require("Game.RevealSystem")
local AIPlayer          = require("Game.AIPlayer")
local CharacterSystem   = require("Game.CharacterSystem")
local CharacterData     = require("Data.CharacterData")
local PlayerDataManager = require("Game.PlayerDataManager")
local cjson             = require("cjson")

local Server = {}

-- ============================================================================
-- 模块变量
-- ============================================================================

---@type Scene
local scene_ = nil
---@type AuctionManager
local auction_ = nil
---@type ItemPool
local itemPool_ = nil
---@type RevealSystem
local reveal_ = nil
---@type CharacterSystem
local charSystem_ = nil

-- 座位管理 { [seatIdx] = { connection=userdata, node=Node, name=string, uid=number|nil } | nil }
local seats_ = {}
local MAX_SEATS = Config.Auction.MaxPlayers

-- AI 玩家 { [seatIdx] = AIPlayer }
local aiPlayers_ = {}

-- 游戏是否已启动
local gameStarted_ = false

-- 当前大厅配置
local currentHallConfig_ = Config.AuctionHalls[1]

-- 每个座位的初始竞拍预算 { [seatIdx] = number }（用于 SKILL_MARKET_SCAN 比例计算）
local seatInitialFunds_ = {}

-- 自动开始定时器（nil=未调度, >0=倒计时中）
local autoStartTimer_ = nil
local AUTO_START_DELAY = 2.0  -- 秒

-- 大厅选择门控：至少有一名真实玩家选择大厅后才允许自动开始
local hallSelected_ = false

-- 角色选择阶段
local charSelectActive_ = false   -- 是否处于角色选择阶段
local charSelectTimer_ = nil      -- 角色选择倒计时

-- 待处理的新加入玩家队列（延迟一帧发送分配消息）
local pendingSeats_ = {}

-- 本局赢家信息（用于 reveal 结束后发放奖励）
local roundWinnerSeat_ = nil
local roundWinnerSpeedWin_ = false

-- 本局开箱物品缓存（用于奖励持久化）
local revealItems_ = nil
local revealTotalValue_ = 0

-- ============================================================================
-- 初始化
-- ============================================================================

function Server.Start()
    SampleStart()
    Protocol.RegisterEvents()

    -- 创建场景
    scene_ = Scene()
    scene_:CreateComponent("Octree")
    scene_:CreateComponent("PhysicsWorld")

    -- 初始化游戏模块
    auction_ = AuctionManager.New()
    itemPool_ = ItemPool.New(currentHallConfig_)
    reveal_ = RevealSystem.New()
    charSystem_ = CharacterSystem.New(MAX_SEATS)

    -- 绑定通信回调
    auction_.sendToPlayer = function(seatIdx, eventName, data)
        Server.SendToSeat(seatIdx, eventName, data)
    end
    auction_.broadcastAll = function(eventName, data)
        Server.BroadcastAll(eventName, data)
    end

    -- 绑定揭示回调
    Server._BindRevealCallbacks()

    -- 绑定 AI 钩子
    Server._BindAIHooks()

    -- 绑定竞拍钩子（Phase 2：技能集成）
    Server._BindAuctionSkillHooks()

    -- 绑定游戏结束钩子（Phase 3：记录赢家以便后续奖励）
    auction_.onGameEndHook = function(winnerSeat, isSpeedWin)
        roundWinnerSeat_ = winnerSeat
        roundWinnerSpeedWin_ = isSpeedWin
        print(string.format("[Server] onGameEndHook: winner=%s, speedWin=%s",
            tostring(winnerSeat), tostring(isSpeedWin)))
    end

    -- 预创建座位节点 (REPLICATED)
    for i = 1, MAX_SEATS do
        local node = scene_:CreateChild("Seat_" .. i, REPLICATED)
        node:SetVar(StringHash(Protocol.VARS.IS_PLAYER), Variant(true))
        node:SetVar(StringHash(Protocol.VARS.SEAT_INDEX), Variant(i))
        node:SetVar(StringHash(Protocol.VARS.PLAYER_STATE), Variant("empty"))
        seats_[i] = { connection = nil, node = node, name = "", uid = nil }
    end

    -- 订阅网络事件
    SubscribeToEvent("ClientConnected", "Server_HandleClientConnected")
    SubscribeToEvent("ClientDisconnected", "Server_HandleClientDisconnected")
    SubscribeToEvent(Protocol.EVENTS.CLIENT_READY, "Server_HandleClientReady")
    SubscribeToEvent(Protocol.EVENTS.C2S_BID, "Server_HandleBid")
    SubscribeToEvent(Protocol.EVENTS.C2S_SELECT_CHAR, "Server_HandleSelectChar")
    SubscribeToEvent(Protocol.EVENTS.C2S_USE_SKILL, "Server_HandleUseSkill")

    -- Phase 3 事件
    SubscribeToEvent(Protocol.EVENTS.C2S_SELECT_HALL, "Server_HandleSelectHall")
    SubscribeToEvent(Protocol.EVENTS.C2S_SELL_ITEM, "Server_HandleSellItem")
    SubscribeToEvent(Protocol.EVENTS.C2S_EMOTE, "Server_HandleEmote")
    SubscribeToEvent(Protocol.EVENTS.C2S_GET_COLLECTION, "Server_HandleGetCollection")

    -- 订阅逻辑更新
    SubscribeToEvent("Update", "Server_HandleUpdate")

    -- 订阅服务器就绪事件（匹配成功后触发）
    SubscribeToEvent("ServerReady", "Server_HandleServerReady")

    print("[Server] Initialized (Phase 3), waiting for players...")
end

--- 绑定揭示系统回调
function Server._BindRevealCallbacks()
    reveal_.onRevealItem = function(index, item)
        Server.BroadcastAll(
            Protocol.EVENTS.S2C_REVEAL_ITEM,
            Protocol.MakeRevealItemMessage(index, item.name, item.rarity, item.value, item.category or "")
        )
    end

    reveal_.onRevealTotal = function(totalValue, bidTotal, profit)
        Server.BroadcastAll(
            Protocol.EVENTS.S2C_REVEAL_TOTAL,
            Protocol.MakeRevealTotalMessage(totalValue, bidTotal, profit)
        )
    end

    reveal_.onRevealDone = function()
        print("[Server] Reveal done — saving rewards")
        Server._SaveWinnerReward()
    end
end

--- Phase 3: 发放赢家奖励（异步 serverCloud）
function Server._SaveWinnerReward()
    local winnerSeat = roundWinnerSeat_
    if not winnerSeat then
        print("[Server] No winner, skipping reward")
        return
    end

    local seat = seats_[winnerSeat]
    if not seat then return end

    -- AI 不需要持久化
    if auction_:IsAI(winnerSeat) then
        print("[Server] Winner is AI, skipping reward persistence")
        return
    end

    local uid = seat.uid
    if not uid then
        print("[Server] Winner has no uid, skipping reward")
        return
    end

    -- 计算奖金：出价总额 × WinnerBonusRatio
    local bidTotal = auction_:GetBidSystem():GetTotalBid(winnerSeat)
    local bonusAmount = math.floor(bidTotal * Config.Economy.WinnerBonusRatio)

    local items = revealItems_ or {}

    PlayerDataManager.SaveReward(uid, items, bonusAmount, bidTotal, function(ok)
        if ok then
            -- 通知赢家奖励
            local rewardJson = cjson.encode(items)
            Server.SendToSeat(winnerSeat, Protocol.EVENTS.S2C_REWARD,
                Protocol.MakeRewardMessage(rewardJson, revealTotalValue_))

            -- 更新余额通知（净变动 = -bidTotal + bonusAmount）
            local newBalance = PlayerDataManager.GetCachedBalance(uid)
            local netChange = -bidTotal + bonusAmount
            Server.SendToSeat(winnerSeat, Protocol.EVENTS.S2C_BALANCE_UPDATE,
                Protocol.MakeBalanceUpdateMessage(newBalance, netChange, "reward"))

            print(string.format("[Server] Reward saved for seat %d: %d items, bidTotal=%d, bonus=%d",
                winnerSeat, #items, bidTotal, bonusAmount))
        else
            print(string.format("[Server] Failed to save reward for seat %d", winnerSeat))
        end
    end)
end

--- 绑定 AI 回合钩子
function Server._BindAIHooks()
    auction_.onRoundStartHook = function(roundNum)
        for seatIdx, ai in pairs(aiPlayers_) do
            ai:OnRoundStart(roundNum)
        end
    end

    auction_.onRoundSettledHook = function(roundNum, results)
        for _, entry in ipairs(results) do
            local ai = aiPlayers_[entry.seatIdx]
            if ai then
                ai:RecordRank(roundNum, entry.rank)
            end
        end

        -- Phase 2：回合结束后更新角色技能 CD
        charSystem_:OnRoundEnd()

        -- 向真人玩家同步技能状态
        Server._SyncSkillInfo()

        -- 触发回合结束被动
        Server._TriggerPassives("round_end", roundNum)
    end
end

--- 绑定竞拍技能钩子（Phase 2）
function Server._BindAuctionSkillHooks()
    -- 回合开始前触发被动
    local origOnRoundStart = auction_.onRoundStartHook
    auction_.onRoundStartHook = function(roundNum)
        -- 先触发回合开始被动
        Server._TriggerPassives("round_start", roundNum)

        -- 再通知 AI
        if origOnRoundStart then origOnRoundStart(roundNum) end

        -- 发送技能状态
        Server._SyncSkillInfo()
    end
end

-- ============================================================================
-- 网络事件处理
-- ============================================================================

function Server_HandleServerReady(eventType, eventData)
    print("[Server] Server ready, match started!")
end

function Server_HandleClientConnected(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    print(string.format("[Server] Client connected: %s", tostring(connection)))
end

function Server_HandleClientReady(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    connection.scene = scene_

    local seatIdx = Server._FindFreeSeat()
    if not seatIdx then
        print("[Server] No free seats!")
        return
    end

    -- Phase 3: 获取 userId
    local uid = nil
    if connection.identity then
        local uidVariant = connection.identity["user_id"]
        if uidVariant then
            uid = uidVariant:GetInt64()
        end
    end

    local playerName = "玩家" .. seatIdx

    seats_[seatIdx].connection = connection
    seats_[seatIdx].name = playerName
    seats_[seatIdx].uid = uid
    seats_[seatIdx].node:SetVar(StringHash(Protocol.VARS.PLAYER_NAME), Variant(playerName))
    seats_[seatIdx].node:SetVar(StringHash(Protocol.VARS.PLAYER_STATE), Variant("ready"))
    seats_[seatIdx].node:SetOwner(connection)

    auction_:AddPlayer(seatIdx, playerName, connection)

    table.insert(pendingSeats_, { seatIdx = seatIdx, playerName = playerName })

    -- Phase 3: 异步加载玩家持久化数据
    if uid then
        PlayerDataManager.LoadPlayerData(uid, function(ok, data)
            if ok then
                ---@diagnostic disable: missing-parameter
                Server.SendToSeat(seatIdx, Protocol.EVENTS.S2C_PLAYER_DATA,
                    Protocol.MakePlayerDataMessage(data.balance, 0, 0))
                ---@diagnostic enable: missing-parameter
                print(string.format("[Server] Player data loaded for seat %d: balance=%d",
                    seatIdx, data.balance))
            else
                -- 加载失败时兜底：使用默认余额，确保客户端能进入大厅选择
                local fallbackBalance = Config.Economy.InitialBalance
                ---@diagnostic disable: missing-parameter
                Server.SendToSeat(seatIdx, Protocol.EVENTS.S2C_PLAYER_DATA,
                    Protocol.MakePlayerDataMessage(fallbackBalance, 0, 0))
                ---@diagnostic enable: missing-parameter
                print(string.format("[Server] Player data load failed for seat %d, using fallback balance=%d",
                    seatIdx, fallbackBalance))
            end
        end)
    else
        -- uid 为 nil（本地测试或 identity 不可用）：使用默认数据
        local fallbackBalance = Config.Economy.InitialBalance
        Server.SendToSeat(seatIdx, Protocol.EVENTS.S2C_PLAYER_DATA,
            Protocol.MakePlayerDataMessage(fallbackBalance, 0, 0, false))
        print(string.format("[Server] No uid for seat %d, using fallback balance=%d",
            seatIdx, fallbackBalance))
    end
end

function Server_HandleClientDisconnected(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")

    for i = 1, MAX_SEATS do
        if seats_[i].connection == connection then
            print(string.format("[Server] Player '%s' (seat %d) disconnected",
                seats_[i].name, i))

            -- Phase 3: 清除玩家数据缓存
            if seats_[i].uid then
                PlayerDataManager.ClearCache(seats_[i].uid)
            end

            Server.BroadcastAll(Protocol.EVENTS.S2C_PLAYER_LEAVE,
                Protocol.MakePlayerLeaveMessage(i))

            auction_:RemovePlayer(i)
            seats_[i].connection = nil
            seats_[i].name = ""
            seats_[i].uid = nil
            seats_[i].node:SetVar(StringHash(Protocol.VARS.PLAYER_STATE), Variant("empty"))
            seats_[i].node:SetOwner(nil)
            break
        end
    end
end

--- 处理出价消息
function Server_HandleBid(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local amount = eventData["Amount"]:GetInt()

    local seatIdx = Server._GetSeatByConnection(connection)
    if not seatIdx then
        print("[Server] Bid from unknown connection")
        return
    end

    -- Phase 2：应用技能修正
    local finalAmount = Server._ApplyBidSkills(seatIdx, amount)

    local accepted, reason = auction_:HandleBid(seatIdx, finalAmount)
    print(string.format("[Server] Bid from seat %d: %d (orig %d) -> %s %s",
        seatIdx, finalAmount, amount, accepted and "accepted" or "rejected", reason))
end

--- 处理角色选择 (Phase 2)
function Server_HandleSelectChar(eventType, eventData)
    if not charSelectActive_ then
        print("[Server] Char select not active, ignoring")
        return
    end

    local connection = eventData["Connection"]:GetPtr("Connection")
    local charId = eventData["CharId"]:GetString()

    local seatIdx = Server._GetSeatByConnection(connection)
    if not seatIdx then
        print("[Server] SelectChar from unknown connection")
        return
    end

    local ok, errMsg = charSystem_:SelectCharacter(seatIdx, charId)
    if ok then
        local charData = CharacterData.GetCharacter(charId)
        local charName = charData and charData.name or charId
        -- 广播选角结果
        Server.BroadcastAll(Protocol.EVENTS.S2C_CHAR_SELECTED,
            Protocol.MakeCharSelectedMessage(seatIdx, charId, charName))
        print(string.format("[Server] Seat %d selected character: %s", seatIdx, charName))
    else
        -- 选择失败，发给该玩家错误消息
        Server.SendToSeat(seatIdx, Protocol.EVENTS.S2C_SKILL_RESULT,
            Protocol.MakeSkillResultMessage(false, "选角失败", cjson.encode({ error = errMsg })))
        print(string.format("[Server] Seat %d char select failed: %s", seatIdx, errMsg))
    end
end

--- 处理主动技能使用 (Phase 2)
function Server_HandleUseSkill(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local targetSeat = eventData["TargetSeat"]:GetInt()
    if targetSeat == 0 then targetSeat = nil end

    local seatIdx = Server._GetSeatByConnection(connection)
    if not seatIdx then
        print("[Server] UseSkill from unknown connection")
        return
    end

    local ok, errMsg, serverLogic = charSystem_:UseActiveSkill(seatIdx, targetSeat)
    if ok then
        local resultData = Server._ExecuteActiveSkill(seatIdx, serverLogic, targetSeat)
        Server.SendToSeat(seatIdx, Protocol.EVENTS.S2C_SKILL_RESULT,
            Protocol.MakeSkillResultMessage(true, serverLogic, cjson.encode(resultData)))

        -- 同步技能状态
        Server._SyncSkillInfoToSeat(seatIdx)
    else
        Server.SendToSeat(seatIdx, Protocol.EVENTS.S2C_SKILL_RESULT,
            Protocol.MakeSkillResultMessage(false, errMsg or "", ""))
    end
end

-- ============================================================================
-- Phase 3: 新事件处理器
-- ============================================================================

--- 处理大厅选择 (Phase 3)
function Server_HandleSelectHall(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local hallId = eventData["HallId"]:GetString()

    local seatIdx = Server._GetSeatByConnection(connection)
    if not seatIdx then
        print("[Server] SelectHall from unknown connection")
        return
    end

    -- 游戏已开始时禁止更换大厅
    if gameStarted_ then
        print(string.format("[Server] Seat %d tried to switch hall during game, rejected", seatIdx))
        return
    end

    -- 验证 hallId 是否有效
    local targetHall = nil
    for _, hall in ipairs(Config.AuctionHalls) do
        if hall.id == hallId then
            targetHall = hall
            break
        end
    end

    if not targetHall then
        print(string.format("[Server] Invalid hallId: %s", hallId))
        return
    end

    -- 更新当前大厅配置
    currentHallConfig_ = targetHall

    -- 用新配置重建物品池
    itemPool_ = ItemPool.New(currentHallConfig_)

    print(string.format("[Server] Hall changed to '%s' (entryFee=%d) by seat %d",
        targetHall.name, targetHall.entryFee, seatIdx))

    -- 大厅已选择，解除自动开始门控
    if not hallSelected_ then
        hallSelected_ = true
        print("[Server] Hall selected, auto-start gate unlocked")
        Server._CheckAutoStart()
    end
end

--- 处理出售藏品 (Phase 3)
function Server_HandleSellItem(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local itemId = eventData["ItemId"]:GetString()

    local seatIdx = Server._GetSeatByConnection(connection)
    if not seatIdx then return end

    local uid = seats_[seatIdx].uid
    if not uid then
        Server.SendToSeat(seatIdx, Protocol.EVENTS.S2C_SELL_RESULT,
            Protocol.MakeSellResultMessage(false, "", 0, "未登录"))
        return
    end

    -- 先从 serverCloud 获取该物品信息（需要 value 计算售价）
    PlayerDataManager.GetCollection(uid, function(ok, items, _, _)
        if not ok then
            Server.SendToSeat(seatIdx, Protocol.EVENTS.S2C_SELL_RESULT,
                Protocol.MakeSellResultMessage(false, "", 0, "获取藏品失败"))
            return
        end

        -- 在藏品列表中查找目标 item
        local targetItem = nil
        for _, item in ipairs(items) do
            if item.id == itemId then
                targetItem = item
                break
            end
        end

        if not targetItem then
            Server.SendToSeat(seatIdx, Protocol.EVENTS.S2C_SELL_RESULT,
                Protocol.MakeSellResultMessage(false, "", 0, "藏品不存在"))
            return
        end

        PlayerDataManager.SellItem(uid, itemId, targetItem.value, function(sellOk, sellPrice, newBalance)
            Server.SendToSeat(seatIdx, Protocol.EVENTS.S2C_SELL_RESULT,
                Protocol.MakeSellResultMessage(sellOk, targetItem.name, sellPrice,
                    sellOk and "" or "出售失败"))

            if sellOk then
                Server.SendToSeat(seatIdx, Protocol.EVENTS.S2C_BALANCE_UPDATE,
                    Protocol.MakeBalanceUpdateMessage(newBalance, sellPrice, "sell_item"))
            end
        end)
    end)
end

--- 处理表情/快捷语 (Phase 3)
function Server_HandleEmote(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local emoteId = eventData["EmoteId"]:GetString()

    local seatIdx = Server._GetSeatByConnection(connection)
    if not seatIdx then return end

    -- 查找表情文本
    local emoteText = ""
    for _, e in ipairs(Config.Emotes) do
        if e.id == emoteId then
            emoteText = e.text
            break
        end
    end

    if emoteText == "" then
        print(string.format("[Server] Unknown emote: %s", emoteId))
        return
    end

    -- 广播给所有玩家
    Server.BroadcastAll(Protocol.EVENTS.S2C_EMOTE,
        Protocol.MakeBroadcastEmoteMessage(seatIdx, emoteId, emoteText))

    print(string.format("[Server] Seat %d sent emote: %s", seatIdx, emoteText))
end

--- 处理获取藏品列表 (Phase 3)
function Server_HandleGetCollection(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")

    local seatIdx = Server._GetSeatByConnection(connection)
    if not seatIdx then return end

    local uid = seats_[seatIdx].uid
    if not uid then return end

    PlayerDataManager.GetCollection(uid, function(ok, items, totalCount, totalValue)
        if ok then
            local collectionJson = cjson.encode(items)
            Server.SendToSeat(seatIdx, Protocol.EVENTS.S2C_COLLECTION_DATA,
                Protocol.MakeCollectionDataMessage(collectionJson, totalCount, totalValue))
        end
    end)
end

-- ============================================================================
-- 主循环
-- ============================================================================

function Server_HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    -- 处理待加入的玩家（延迟一帧，等 scene 同步完成）
    if #pendingSeats_ > 0 then
        local batch = pendingSeats_
        pendingSeats_ = {}
        for _, info in ipairs(batch) do
            Server.SendToSeat(info.seatIdx, Protocol.EVENTS.ASSIGN_SEAT,
                Protocol.MakeAssignSeatMessage(info.seatIdx, info.playerName))

            Server.BroadcastAll(Protocol.EVENTS.S2C_PLAYER_JOIN,
                Protocol.MakePlayerJoinMessage(info.seatIdx, info.playerName))

            print(string.format("[Server] Seat %d assigned to '%s'", info.seatIdx, info.playerName))
        end
        Server._CheckAutoStart()
    end

    -- 驱动自动开始倒计时
    if autoStartTimer_ and not gameStarted_ then
        autoStartTimer_ = autoStartTimer_ - dt
        if autoStartTimer_ <= 0 then
            autoStartTimer_ = nil
            print("[Server] Auto-start triggered, entering char select")
            Server._EnterCharSelect()
        end
    end

    -- 驱动角色选择倒计时
    if charSelectTimer_ then
        charSelectTimer_ = charSelectTimer_ - dt
        if charSelectTimer_ <= 0 then
            charSelectTimer_ = nil
            Server._EndCharSelect()
        else
            -- 每秒同步一次倒计时给客户端
            Server.BroadcastAll(
                Protocol.EVENTS.S2C_TIMER_SYNC,
                Protocol.MakeTimerSyncMessage(charSelectTimer_))
        end
    end

    -- 更新竞拍逻辑
    auction_:Update(dt)

    -- 驱动 AI 出价（仅在出价阶段）
    if auction_:GetGameState() == Config.GameState.BIDDING then
        Server._UpdateAIPlayers(dt)
    end

    -- 更新揭示系统
    reveal_:Update(dt)

    -- 游戏结束后启动开箱流程
    if auction_:GetGameState() == Config.GameState.GAME_OVER and not reveal_:IsActive() and not reveal_:IsDone() then
        Server._StartReveal()
    end
end

-- ============================================================================
-- 角色选择流程 (Phase 2)
-- ============================================================================

--- 进入角色选择阶段
function Server._EnterCharSelect()
    if gameStarted_ then return end

    -- 先用 AI 填充空座位
    Server._FillAIPlayers()

    charSelectActive_ = true
    charSystem_:Reset()

    -- 构建可选角色列表
    local allIds = CharacterData.GetAllIds()
    local available = {}
    for _, id in ipairs(allIds) do
        local c = CharacterData.GetCharacter(id)
        if c then
            table.insert(available, {
                id = c.id,
                name = c.name,
                title = c.title,
                desc = c.desc,
                activeSkill = {
                    name = c.activeSkill.name,
                    desc = c.activeSkill.desc,
                    cooldown = c.activeSkill.cooldown,
                    maxUses = c.activeSkill.maxUses,
                    needsTarget = (c.activeSkill.serverLogic == "SKILL_SPY"
                        or c.activeSkill.serverLogic == "SKILL_MISINFORM"
                        or c.activeSkill.serverLogic == "SKILL_PRESSURE"),
                },
                passiveSkill = {
                    name = c.passiveSkill.name,
                    desc = c.passiveSkill.desc,
                },
            })
        end
    end
    local availJson = cjson.encode(available)

    -- 广播角色选择开始
    Server.BroadcastAll(Protocol.EVENTS.S2C_CHAR_SELECT_START,
        Protocol.MakeCharSelectStartMessage(Config.Skill.SelectTimeLimit, availJson))

    -- AI 自动选角
    for seatIdx in pairs(aiPlayers_) do
        local charId = charSystem_:AutoSelectForAI(seatIdx)
        if charId then
            local charData = CharacterData.GetCharacter(charId)
            local charName = charData and charData.name or charId
            Server.BroadcastAll(Protocol.EVENTS.S2C_CHAR_SELECTED,
                Protocol.MakeCharSelectedMessage(seatIdx, charId, charName))
        end
    end

    -- 启动角色选择倒计时
    charSelectTimer_ = Config.Skill.SelectTimeLimit

    print("[Server] Char select started, " .. #allIds .. " characters available")
end

--- 结束角色选择阶段
function Server._EndCharSelect()
    charSelectActive_ = false
    charSelectTimer_ = nil

    -- 为未选角的真人玩家自动分配
    for i = 1, MAX_SEATS do
        if seats_[i].connection and not charSystem_:GetSeatInfo(i) then
            local charId = charSystem_:AutoSelectForAI(i)  -- 使用相同的随机选角逻辑
            if charId then
                local charData = CharacterData.GetCharacter(charId)
                local charName = charData and charData.name or charId
                Server.BroadcastAll(Protocol.EVENTS.S2C_CHAR_SELECTED,
                    Protocol.MakeCharSelectedMessage(i, charId, charName))
                print(string.format("[Server] Auto-assigned char %s to seat %d", charName, i))
            end
        end
    end

    -- 构建选角结果
    local selections = {}
    for i = 1, MAX_SEATS do
        local info = charSystem_:GetSeatInfo(i)
        if info then
            selections[tostring(i)] = {
                characterId = info.characterId,
                characterName = info.characterData.name,
            }
        end
    end
    local selectionsJson = cjson.encode(selections)

    -- 广播选角结束
    Server.BroadcastAll(Protocol.EVENTS.S2C_CHAR_SELECT_END,
        Protocol.MakeCharSelectEndMessage(selectionsJson))

    print("[Server] Char select ended, starting game")

    -- Phase 3: 扣除入场费后开始游戏
    Server._DeductEntryFeesAndStart()
end

-- ============================================================================
-- Phase 3: 入场费扣除 + 游戏启动
-- ============================================================================

--- 扣除所有真人玩家的入场费，然后启动游戏
function Server._DeductEntryFeesAndStart()
    local entryFee = currentHallConfig_.entryFee

    if entryFee <= 0 then
        -- 免费厅，直接开始
        Server._StartGame()
        return
    end

    -- 统计需要扣费的真人玩家
    local pendingCount = 0
    local doneCount = 0

    for i = 1, MAX_SEATS do
        if seats_[i].connection and seats_[i].uid then
            pendingCount = pendingCount + 1
        end
    end

    if pendingCount == 0 then
        -- 全是 AI
        Server._StartGame()
        return
    end

    -- 逐个扣费（异步，全部完成后启动）
    for i = 1, MAX_SEATS do
        if seats_[i].connection and seats_[i].uid then
            local uid = seats_[i].uid
            local seatIdx = i
            PlayerDataManager.DeductEntryFee(uid, entryFee, function(ok, newBalance)
                doneCount = doneCount + 1

                if ok then
                    Server.SendToSeat(seatIdx, Protocol.EVENTS.S2C_BALANCE_UPDATE,
                        Protocol.MakeBalanceUpdateMessage(newBalance, -entryFee, "entry_fee"))
                    print(string.format("[Server] Entry fee -%d for seat %d, balance=%d",
                        entryFee, seatIdx, newBalance))
                else
                    print(string.format("[Server] Entry fee deduction failed for seat %d (insufficient funds?)", seatIdx))
                    -- 即使扣费失败也允许参加（免费体验），不踢人
                end

                -- 所有扣费完成后启动
                if doneCount >= pendingCount then
                    Server._StartGame()
                end
            end)
        end
    end
end

-- ============================================================================
-- 主动技能执行 (Phase 2)
-- ============================================================================

--- 执行主动技能的服务端逻辑
---@param seatIdx number
---@param serverLogic string
---@param targetSeat number|nil
---@return table resultData
function Server._ExecuteActiveSkill(seatIdx, serverLogic, targetSeat)
    local result = {}

    if serverLogic == "SKILL_APPRAISE" then
        -- 鉴宝慧眼：透视本轮藏品箱的最高稀有度类别
        local topCategory = itemPool_:GetTopRarityCategory()
        result.topCategory = topCategory or "未知"
        result.desc = "本轮最高稀有度藏品类别: " .. result.topCategory

    elseif serverLogic == "SKILL_SPY" then
        -- 暗探：查看目标上轮出价
        if targetSeat then
            local bidSystem = auction_:GetBidSystem()
            local lastRound = auction_:GetCurrentRound() - 1
            local lastBid = 0
            if lastRound >= 1 then
                local history = bidSystem:GetBidHistory()
                if history[lastRound] and history[lastRound][targetSeat] then
                    lastBid = history[lastRound][targetSeat]
                end
            end
            -- 检查目标是否有信息屏障
            if charSystem_:IsShielded(targetSeat) then
                result.blocked = true
                result.desc = "目标启用了信息屏障，探查失败！"
            else
                result.targetBid = lastBid
                result.desc = string.format("座位%d上轮出价: %d", targetSeat, lastBid)
            end
        end

    elseif serverLogic == "SKILL_MISINFORM" then
        -- 虚假情报：下轮目标看到的排名偏移
        result.desc = string.format("已向座位%d发送虚假情报", targetSeat or 0)

    elseif serverLogic == "SKILL_BUDGET_BOOST" then
        -- 追加预算：临时增加 15% 余额
        local bidSystem = auction_:GetBidSystem()
        local currentFunds = bidSystem:GetAvailableFunds(seatIdx)
        local boost = math.floor(currentFunds * Config.Skill.BudgetBoost)
        bidSystem:AddFunds(seatIdx, boost)
        result.boost = boost
        result.desc = string.format("追加预算 +%d 金币", boost)

    elseif serverLogic == "SKILL_FORTUNE" then
        -- 天命一掷：本轮出价随机修正
        result.desc = "天命一掷已启动，本轮出价将获得随机修正"

    elseif serverLogic == "SKILL_SHIELD" then
        -- 信息屏障：本轮免疫情报类技能
        result.desc = "信息屏障已启动，本轮免疫情报类技能"

    elseif serverLogic == "SKILL_MARKET_SCAN" then
        -- 全场扫描：查看所有人剩余余额的高/中/低档位
        local bidSystem = auction_:GetBidSystem()
        local scans = {}
        for i = 1, MAX_SEATS do
            if i ~= seatIdx and auction_:GetPlayerCount() > 0 then
                local funds = bidSystem:GetAvailableFunds(i)
                local initFunds = seatInitialFunds_[i] or 1
                local ratio = funds / initFunds
                local tier
                if ratio > 0.66 then
                    tier = "充裕"
                elseif ratio > 0.33 then
                    tier = "中等"
                else
                    tier = "紧张"
                end
                table.insert(scans, { seat = i, tier = tier })
            end
        end
        result.scans = scans
        result.desc = "全场余额扫描完成"

    elseif serverLogic == "SKILL_PRESSURE" then
        -- 心理施压：下轮目标看到"你的出价被监视"
        result.desc = string.format("已对座位%d施加心理压力", targetSeat or 0)
    end

    print(string.format("[Server] Skill %s by seat %d: %s",
        serverLogic, seatIdx, result.desc or ""))
    return result
end

-- ============================================================================
-- 被动技能触发 (Phase 2)
-- ============================================================================

--- 触发指定时机的所有被动技能
---@param trigger string "round_start"|"round_end"|"bid_phase"|"reveal"
---@param roundNum number|nil
function Server._TriggerPassives(trigger, roundNum)
    local passives = charSystem_:GetPassivesByTrigger(trigger)
    for _, p in ipairs(passives) do
        local desc = Server._DescribePassive(p.serverLogic, p.seatIdx)
        if desc then
            -- 通知该玩家被动触发
            Server.SendToSeat(p.seatIdx, Protocol.EVENTS.S2C_PASSIVE_INFO,
                Protocol.MakePassiveInfoMessage(p.characterData.passiveSkill.name, desc))
        end
    end
end

--- 获取被动技能描述
---@param serverLogic string
---@param seatIdx number
---@return string|nil
function Server._DescribePassive(serverLogic, seatIdx)
    if serverLogic == "PASSIVE_APPRAISE_FREE" then
        return "慧眼识珠：每轮自动获得最高稀有度类别提示"
    elseif serverLogic == "PASSIVE_FOG_OF_WAR" then
        return "战争迷雾：对手查看你的信息可能被干扰"
    elseif serverLogic == "PASSIVE_FRUGAL" then
        return string.format("精打细算：出价后返还 %.0f%% 金额", Config.Skill.FrugalRefund * 100)
    elseif serverLogic == "PASSIVE_LUCKY_BOX" then
        return "锦鲤体质：开箱稀有度提升"
    elseif serverLogic == "PASSIVE_POKER_FACE" then
        return "扑克脸：你的排名对对手隐藏真实位置"
    elseif serverLogic == "PASSIVE_TREND_SENSE" then
        return "趋势嗅觉：每轮可看到藏品总价值档位"
    elseif serverLogic == "PASSIVE_DISTORT_VALUE" then
        return "暗中搅局：其他玩家看到的物品价值可能偏差"
    elseif serverLogic == "PASSIVE_GAP_SENSE" then
        return "市井嗅觉：每轮可感知与第一名的差距"
    end
    return nil
end

-- ============================================================================
-- 出价技能修正 (Phase 2)
-- ============================================================================

--- 应用技能对出价金额的修正
---@param seatIdx number
---@param amount number 原始出价
---@return number 修正后出价
function Server._ApplyBidSkills(seatIdx, amount)
    local finalAmount = amount

    -- 天命一掷：随机修正
    if charSystem_:HasFortune(seatIdx) then
        local mult = charSystem_:RollFortune()
        finalAmount = math.floor(finalAmount * mult)
        print(string.format("[Server] Fortune applied to seat %d: x%.2f (%d -> %d)",
            seatIdx, mult, amount, finalAmount))
    end

    -- 确保不为负
    if finalAmount < 0 then finalAmount = 0 end

    return finalAmount
end

-- ============================================================================
-- 技能状态同步 (Phase 2)
-- ============================================================================

--- 向所有真人玩家同步技能状态
function Server._SyncSkillInfo()
    for i = 1, MAX_SEATS do
        if seats_[i].connection then
            Server._SyncSkillInfoToSeat(i)
        end
    end
end

--- 向指定座位同步技能状态
---@param seatIdx number
function Server._SyncSkillInfoToSeat(seatIdx)
    local status = charSystem_:GetActiveSkillStatus(seatIdx)
    local json = cjson.encode(status)
    Server.SendToSeat(seatIdx, Protocol.EVENTS.S2C_SKILL_INFO,
        Protocol.MakeSkillInfoMessage(json))
end

-- ============================================================================
-- 内部辅助
-- ============================================================================

function Server._FindFreeSeat()
    for i = 1, MAX_SEATS do
        if seats_[i].connection == nil and not aiPlayers_[i] then
            return i
        end
    end
    return nil
end

function Server._GetSeatByConnection(connection)
    for i = 1, MAX_SEATS do
        if seats_[i].connection == connection then
            return i
        end
    end
    return nil
end

function Server._CheckAutoStart()
    if gameStarted_ then return end

    -- 门控：必须等待真实玩家选择大厅后才能自动开始
    if not hallSelected_ then
        print("[Server] Waiting for hall selection before auto-start...")
        return
    end

    local count = auction_:GetPlayerCount()

    if count >= MAX_SEATS then
        Server._EnterCharSelect()
        return
    end

    if count >= 1 and autoStartTimer_ == nil then
        autoStartTimer_ = AUTO_START_DELAY
        print(string.format("[Server] %d/%d players, auto-start in %.0f seconds...",
            count, MAX_SEATS, AUTO_START_DELAY))
    end
end

function Server._FillAIPlayers()
    for i = 1, MAX_SEATS do
        if seats_[i].connection == nil and not aiPlayers_[i] then
            local ai = AIPlayer.New(i)
            aiPlayers_[i] = ai

            seats_[i].name = ai:GetName()
            seats_[i].node:SetVar(StringHash(Protocol.VARS.PLAYER_NAME), Variant(ai:GetName()))
            seats_[i].node:SetVar(StringHash(Protocol.VARS.PLAYER_STATE), Variant("ready"))

            auction_:AddPlayer(i, ai:GetName(), nil, true)

            Server.BroadcastAll(Protocol.EVENTS.S2C_PLAYER_JOIN,
                Protocol.MakePlayerJoinMessage(i, ai:GetName()))

            print(string.format("[Server] AI player '%s' (%s) filled seat %d",
                ai:GetName(), ai:GetStrategy(), i))
        end
    end
end

function Server._UpdateAIPlayers(dt)
    local roundNum = auction_:GetCurrentRound()
    local totalRounds = Config.Auction.TotalRounds
    local bidSystem = auction_:GetBidSystem()

    for seatIdx, ai in pairs(aiPlayers_) do
        local availableFunds = bidSystem:GetAvailableFunds(seatIdx)
        local shouldBid, amount = ai:Update(dt, availableFunds, roundNum, totalRounds)

        if shouldBid then
            -- AI 也应用技能修正
            local finalAmount = Server._ApplyBidSkills(seatIdx, amount)
            local accepted, reason = auction_:HandleBid(seatIdx, finalAmount)
            print(string.format("[Server] AI seat %d bid %d -> %s %s",
                seatIdx, finalAmount, accepted and "accepted" or "rejected", reason))
        end
    end
end

function Server._StartGame()
    if gameStarted_ then return end
    gameStarted_ = true

    auction_.hallConfig = currentHallConfig_

    -- 构建每个座位的竞拍预算：真人用持久化余额，AI 用大厅 fundRange 均值
    local hallFundRange = currentHallConfig_.fundRange
    local aiFunds = math.floor((hallFundRange[1] + hallFundRange[2]) / 2)
    local playerFundsMap = {}
    seatInitialFunds_ = {}

    for i = 1, MAX_SEATS do
        if seats_[i].connection and seats_[i].uid then
            -- 真人玩家：用其持久化余额作为竞拍预算
            local balance = PlayerDataManager.GetCachedBalance(seats_[i].uid)
            playerFundsMap[i] = balance
            seatInitialFunds_[i] = balance
        elseif seats_[i].name then
            -- AI 玩家：用大厅 fundRange 均值
            playerFundsMap[i] = aiFunds
            seatInitialFunds_[i] = aiFunds
        end
    end

    -- 生成本局拍卖物品（开局即确定，所有玩家可见）
    local itemCount = currentHallConfig_.itemCountPerBox
    local items, totalValue = itemPool_:GenerateBox(itemCount, nil, nil, nil)
    revealItems_ = items
    revealTotalValue_ = totalValue

    -- 构建物品 JSON 广播给所有客户端
    local itemsList = {}
    for i, item in ipairs(items) do
        itemsList[i] = {
            name = item.name,
            rarity = item.rarity,
            valueRange = item.valueRange,
            category = item.category or "",
        }
    end
    local itemsJson = cjson.encode(itemsList)

    print(string.format("[Server] Starting game in %s! items=%d, totalValue=%d",
        currentHallConfig_.name, itemCount, totalValue))
    for seatIdx, funds in pairs(playerFundsMap) do
        print(string.format("[Server]   Seat %d funds=%d", seatIdx, funds))
    end

    -- 传递每人不同的竞拍预算
    auction_:TryStartGame(playerFundsMap)

    -- 广播拍卖物品列表
    Server.BroadcastAll(Protocol.EVENTS.S2C_AUCTION_ITEMS,
        Protocol.MakeAuctionItemsMessage(itemsJson))
end

function Server._StartReveal()
    local winnerSeat = auction_:GetWinner()
    if not winnerSeat then
        print("[Server] No winner, skipping reveal")
        return
    end

    -- 使用开局时已生成的物品（revealItems_ / revealTotalValue_ 在 _StartGame 中缓存）
    local items = revealItems_
    local totalValue = revealTotalValue_
    local bidTotal = auction_:GetBidSystem():GetTotalBid(winnerSeat)

    Server.BroadcastAll(Protocol.EVENTS.S2C_REVEAL_START, VariantMap())

    reveal_:Start(items, totalValue, bidTotal)
end

-- ============================================================================
-- 通信工具
-- ============================================================================

function Server.SendToSeat(seatIdx, eventName, data)
    local seat = seats_[seatIdx]
    if seat and seat.connection then
        ---@diagnostic disable-next-line: missing-parameter
        seat.connection:SendRemoteEvent(eventName, true, data)
    end
end

function Server.BroadcastAll(eventName, data)
    for i = 1, MAX_SEATS do
        if seats_[i].connection then
            seats_[i].connection:SendRemoteEvent(eventName, true, data)
        end
    end
end

function Server.OnAllPlayersReady()
    Server._EnterCharSelect()
end

return Server
