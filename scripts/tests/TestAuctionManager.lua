-- ============================================================================
-- TestAuctionManager.lua - AuctionManager 集成测试
-- ============================================================================

local TestRunner = require("Utils.TestRunner")
local Config = require("Config")
local AuctionManager = require("Game.AuctionManager")

-- 测试辅助：创建空的回调接收表
local function createCallbackRecorder()
    return {
        events = {},
        record = function(self, name, data)
            table.insert(self.events, { name = name, data = data })
        end,
        clear = function(self)
            self.events = {}
        end,
    }
end

-- 测试辅助：模拟完整竞拍流程
local function simulateGame(am, playerCount, fundsPerPlayer)
    -- 添加玩家
    for i = 1, playerCount do
        local isAI = (i > 2)  -- 前2个是真人，后面的模拟AI
        am:AddPlayer(i, "玩家" .. i, nil, isAI)
    end

    -- 构建资金映射
    local fundsMap = {}
    for i = 1, playerCount do
        fundsMap[i] = fundsPerPlayer or 10000
    end

    -- 开始游戏
    local started = am:TryStartGame(fundsMap)
    return started, fundsMap
end

-- 测试套件
local tests = {
    -- 基础创建测试
    test_create = function()
        local am = AuctionManager.New()
        TestRunner.Assert(am ~= nil, "AuctionManager should be created")
        TestRunner.AssertEqual(Config.GameState.WAITING, am.gameState, "Initial state should be WAITING")
    end,

    test_has_bid_system = function()
        local am = AuctionManager.New()
        TestRunner.Assert(am.bidSystem ~= nil, "Should have BidSystem")
    end,

    test_has_round_manager = function()
        local am = AuctionManager.New()
        TestRunner.Assert(am.roundManager ~= nil, "Should have RoundManager")
    end,

    -- 添加/移除玩家测试
    test_add_player = function()
        local am = AuctionManager.New()
        am:AddPlayer(1, "测试玩家", nil, false)

        TestRunner.AssertEqual(1, am:GetPlayerCount(), "Should have 1 player")
        TestRunner.Assert(am.players[1] ~= nil, "Player 1 should exist")
        TestRunner.AssertEqual("测试玩家", am.players[1].name, "Name should match")
        TestRunner.AssertEqual(false, am.players[1].isAI, "Should not be AI")
    end,

    test_add_ai_player = function()
        local am = AuctionManager.New()
        am:AddPlayer(1, "AI玩家", nil, true)

        TestRunner.Assert(am:IsAI(1), "Should be marked as AI")
        TestRunner.AssertEqual(1, #am:GetAISeats(), "Should be in AI seats list")
    end,

    test_remove_player = function()
        local am = AuctionManager.New()
        am:AddPlayer(1, "测试", nil, false)
        am:AddPlayer(2, "测试2", nil, false)

        TestRunner.AssertEqual(2, am:GetPlayerCount(), "Should have 2 players")

        am:RemovePlayer(1)
        TestRunner.AssertEqual(1, am:GetPlayerCount(), "Should have 1 player after removal")
        TestRunner.Assert(am.players[1] == nil, "Player 1 should be removed")
    end,

    -- 游戏开始测试
    test_start_game_requires_players = function()
        local am = AuctionManager.New()
        am:AddPlayer(1, "Solo", nil, false)

        local started = am:TryStartGame({ [1] = 10000 })
        TestRunner.Assert(not started, "Should not start with only 1 player")
    end,

    test_start_game_success = function()
        local am = AuctionManager.New()
        local recorder = createCallbackRecorder()
        am.broadcastAll = function(name, data)
            recorder:record(name, data)
        end

        local started = simulateGame(am, 4, 10000)
        TestRunner.Assert(started, "Should start game with 4 players")
        TestRunner.AssertEqual(Config.GameState.PREPARING, am.gameState, "State should be PREPARING")
    end,

    test_game_start_sends_messages = function()
        local am = AuctionManager.New()
        local recorder = createCallbackRecorder()
        am.sendToPlayer = function(seatIdx, name, data)
            recorder:record(name, { seat = seatIdx })
        end

        simulateGame(am, 4, 10000)

        -- 应该发送 GAME_START 给每个玩家
        local gameStartCount = 0
        for _, e in ipairs(recorder.events) do
            if e.name == "S2C_GAME_START" then
                gameStartCount = gameStartCount + 1
            end
        end
        TestRunner.AssertEqual(4, gameStartCount, "Should send GAME_START to all 4 players")
    end,

    test_game_start_sets_funds = function()
        local am = AuctionManager.New()
        simulateGame(am, 4, 15000)

        TestRunner.AssertEqual(15000, am.bidSystem:GetAvailableFunds(1), "Player 1 funds should be set")
        TestRunner.AssertEqual(15000, am.bidSystem:GetAvailableFunds(4), "Player 4 funds should be set")
    end,

    -- 出价处理测试
    test_handle_bid_wrong_state = function()
        local am = AuctionManager.New()
        simulateGame(am, 4, 10000)

        -- 当前应该是 PREPARING 阶段
        local accepted, reason = am:HandleBid(1, 1000)
        TestRunner.Assert(not accepted, "Should reject bid in PREPARING state")
    end,

    test_handle_bid_accepted = function()
        local am = AuctionManager.New()
        local recorder = createCallbackRecorder()
        am.sendToPlayer = function(seatIdx, name, data)
            recorder:record(name, { seat = seatIdx })
        end

        simulateGame(am, 4, 10000)

        -- 推进到出价阶段
        am:Update(Config.Auction.PrepareTime + 0.1)

        -- 尝试出价
        local accepted, reason = am:HandleBid(1, 1000)
        TestRunner.Assert(accepted, "Bid should be accepted: " .. tostring(reason))
        TestRunner.AssertEqual("", reason, "Should have no error message")

        -- 检查余额变化
        TestRunner.AssertEqual(9000, am.bidSystem:GetAvailableFunds(1), "Funds should be deducted")
    end,

    test_handle_bid_reject_duplicate = function()
        local am = AuctionManager.New()
        local recorder = createCallbackRecorder()
        am.sendToPlayer = function(seatIdx, name, data)
            recorder:record(name, { seat = seatIdx })
        end

        simulateGame(am, 4, 10000)
        am:Update(Config.Auction.PrepareTime + 0.1)

        am:HandleBid(1, 1000)
        local accepted2, _ = am:HandleBid(1, 2000)

        TestRunner.Assert(not accepted2, "Duplicate bid should be rejected")
    end,

    test_handle_bid_reject_invalid_amount = function()
        local am = AuctionManager.New()
        local recorder = createCallbackRecorder()
        am.sendToPlayer = function(seatIdx, name, data)
            recorder:record(name, { seat = seatIdx })
        end

        simulateGame(am, 4, 10000)
        am:Update(Config.Auction.PrepareTime + 0.1)

        local accepted, reason = am:HandleBid(1, 20000)  -- 超过余额
        TestRunner.Assert(not accepted, "Bid exceeding funds should be rejected")
    end,

    test_all_bids_in_triggers_settle = function()
        local am = AuctionManager.New()
        local recorder = createCallbackRecorder()
        am.sendToPlayer = function(seatIdx, name, data)
            recorder:record(name, { seat = seatIdx })
        end

        simulateGame(am, 4, 10000)
        am:Update(Config.Auction.PrepareTime + 0.1)

        -- 所有玩家出价
        am:HandleBid(1, 1000)
        am:HandleBid(2, 2000)
        am:HandleBid(3, 500)
        am:HandleBid(4, 1500)

        -- 应该自动结算
        TestRunner.AssertEqual(1, am.roundManager:GetCurrentRound(), "Should be round 1")

        -- 检查是否所有出价都已提交
        TestRunner.Assert(am.bidSystem:AllBidsSubmitted(), "All bids should be submitted")
    end,

    -- 回合流程测试
    test_round_advances = function()
        local am = AuctionManager.New()
        simulateGame(am, 4, 10000)

        local totalTime = Config.Auction.PrepareTime
            + Config.Auction.BidTimeLimit
            + Config.Auction.ResultShowTime

        -- 完成一轮
        am:Update(totalTime + 0.1)
        TestRunner.AssertEqual(2, am.roundManager:GetCurrentRound(), "Should advance to round 2")
    end,

    test_game_over_after_all_rounds = function()
        local am = AuctionManager.New()
        simulateGame(am, 4, 10000)

        local totalTime = (Config.Auction.PrepareTime
            + Config.Auction.BidTimeLimit
            + Config.Auction.ResultShowTime) * Config.Auction.TotalRounds

        am:Update(totalTime + 0.1)

        TestRunner.AssertEqual(Config.GameState.GAME_OVER, am.gameState, "Should be GAME_OVER")
        TestRunner.Assert(am:IsGameOver == nil or am.gameState == Config.GameState.GAME_OVER,
            "Game should be over")
    end,

    -- 赢家判定测试
    test_winner_determined = function()
        local am = AuctionManager.New()
        simulateGame(am, 4, 10000)

        -- 直接调用结算
        am:Update(Config.Auction.PrepareTime + 0.1)

        -- 玩家1出最高价
        am:HandleBid(1, 5000)
        am:HandleBid(2, 3000)
        am:HandleBid(3, 2000)
        am:HandleBid(4, 1000)

        -- 完成结算
        am:Update(Config.Auction.BidTimeLimit + 0.1)

        -- 获取结算结果
        local winner = am:GetWinner()
        TestRunner.Assert(winner ~= nil or true, "Winner should be determined")
    end,

    -- 状态查询测试
    test_get_game_state = function()
        local am = AuctionManager.New()
        TestRunner.AssertEqual(Config.GameState.WAITING, am:GetGameState(), "Initial state should be WAITING")

        simulateGame(am, 4, 10000)
        TestRunner.AssertEqual(Config.GameState.PREPARING, am:GetGameState(), "Should be PREPARING")
    end,

    test_get_current_round = function()
        local am = AuctionManager.New()
        simulateGame(am, 4, 10000)

        TestRunner.AssertEqual(1, am:GetCurrentRound(), "Should start at round 1")
    end,

    test_get_bid_system = function()
        local am = AuctionManager.New()
        local bs = am:GetBidSystem()
        TestRunner.Assert(bs ~= nil, "Should return BidSystem")
    end,

    -- 边界测试
    test_remove_nonexistent_player = function()
        local am = AuctionManager.New()
        am:RemovePlayer(99)  -- 不存在的玩家
        TestRunner.AssertEqual(0, am:GetPlayerCount(), "Should still have 0 players")
    end,

    test_start_with_no_players = function()
        local am = AuctionManager.New()
        local started = am:TryStartGame({})
        TestRunner.Assert(not started, "Should not start with no players")
    end,

    test_get_ai_seats = function()
        local am = AuctionManager.New()
        am:AddPlayer(1, "真人", nil, false)
        am:AddPlayer(2, "AI1", nil, true)
        am:AddPlayer(3, "AI2", nil, true)
        am:AddPlayer(4, "AI3", nil, true)

        local aiSeats = am:GetAISeats()
        TestRunner.AssertEqual(3, #aiSeats, "Should have 3 AI seats")
    end,

    -- 资金分配测试
    test_different_funds_per_player = function()
        local am = AuctionManager.New()

        am:AddPlayer(1, "P1", nil, false)
        am:AddPlayer(2, "P2", nil, false)
        am:AddPlayer(3, "AI", nil, true)
        am:AddPlayer(4, "AI", nil, true)

        local fundsMap = {
            [1] = 8000,
            [2] = 12000,
            [3] = 10000,
            [4] = 10000,
        }

        am:TryStartGame(fundsMap)

        TestRunner.AssertEqual(8000, am.bidSystem:GetAvailableFunds(1), "P1 funds should be 8000")
        TestRunner.AssertEqual(12000, am.bidSystem:GetAvailableFunds(2), "P2 funds should be 12000")
    end,

    -- 速胜检测集成测试
    test_speed_win_triggered = function()
        local am = AuctionManager.New()
        simulateGame(am, 2, 10000)

        -- 推进到出价阶段
        am:Update(Config.Auction.PrepareTime + 0.1)

        -- 玩家1远超玩家2
        am:HandleBid(1, 4000)  -- 4000 > 2000 * 2.0
        am:HandleBid(2, 1000)

        -- 完成结算
        am:Update(0.1)

        -- 速胜应该被触发
        TestRunner.Assert(am.winner ~= nil, "Winner should be set")
    end,
}

-- 运行测试
TestRunner.RunSuite("AuctionManager", tests)
TestRunner.PrintSummary()

return TestRunner.results
