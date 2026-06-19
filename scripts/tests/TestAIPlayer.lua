-- ============================================================================
-- TestAIPlayer.lua - AIPlayer 单元测试
-- ============================================================================

local TestRunner = require("Utils.TestRunner")
local Config = require("Config")
local AIPlayer = require("Game.AIPlayer")

-- 测试套件
local tests = {
    -- 基础创建测试
    test_create_ai = function()
        local ai = AIPlayer.New(1)
        TestRunner.Assert(ai ~= nil, "AIPlayer should be created")
        TestRunner.Assert(ai.seatIdx == 1, "Seat index should be 1")
        TestRunner.Assert(ai.name ~= nil, "AI should have a name")
    end,

    test_create_with_strategy = function()
        local ai = AIPlayer.New(1, AIPlayer.Strategy.AGGRESSIVE)
        TestRunner.AssertEqual(AIPlayer.Strategy.AGGRESSIVE, ai.strategy, "Strategy should be aggressive")
        TestRunner.AssertEqual("aggressive", ai:GetStrategy(), "GetStrategy should return aggressive")
    end,

    test_random_strategy = function()
        -- 创建多个 AI，应该有不同的策略
        local strategies = {}
        for i = 1, 20 do
            local ai = AIPlayer.New(i)
            strategies[ai.strategy] = true
        end
        -- 至少应该有超过一种策略被选中（概率上）
        local count = 0
        for _ in pairs(strategies) do count = count + 1 end
        TestRunner.Assert(count >= 2, "Should have multiple strategy types selected")
    end,

    -- 回合开始测试
    test_round_start_reset = function()
        local ai = AIPlayer.New(1)
        ai.hasBidThisRound = true  -- 模拟上轮已出价
        ai:OnRoundStart(2)
        TestRunner.Assert(not ai.hasBidThisRound, "hasBidThisRound should be reset")
        TestRunner.AssertEqual(2, ai.lastRound, "lastRound should be updated")
        TestRunner.Assert(ai.bidDelay > 0, "bidDelay should be set")
    end,

    test_bid_delay_range = function()
        local ai = AIPlayer.New(1, AIPlayer.Strategy.CONSERVATIVE)
        ai:OnRoundStart(1)
        local params = ai.params
        TestRunner.Assert(ai.bidDelay >= params.delayMin, "bidDelay should be >= delayMin")
        TestRunner.Assert(ai.bidDelay <= params.delayMax, "bidDelay should be <= delayMax")
    end,

    -- 排名记录测试
    test_record_rank = function()
        local ai = AIPlayer.New(1)
        ai:RecordRank(1, 2)
        TestRunner.AssertEqual(2, ai.rankHistory[1], "Rank should be recorded")
        ai:RecordRank(2, 1)
        TestRunner.AssertEqual(1, ai.rankHistory[2], "Second rank should be recorded")
    end,

    -- 出价计算测试
    test_no_bid_when_already_bid = function()
        local ai = AIPlayer.New(1)
        ai.hasBidThisRound = true
        local shouldBid, amount = ai:Update(0.1, 10000, 1, 5)
        TestRunner.Assert(not shouldBid, "Should not bid when already bid this round")
        TestRunner.AssertEqual(0, amount, "Amount should be 0")
    end,

    test_no_bid_when_delay_remaining = function()
        local ai = AIPlayer.New(1)
        ai.bidDelay = 5.0
        local shouldBid, amount = ai:Update(1.0, 10000, 1, 5)
        TestRunner.Assert(not shouldBid, "Should not bid when delay remaining")
        TestRunner.AssertEqual(0, amount, "Amount should be 0")
    end,

    test_bid_when_delay_expired = function()
        local ai = AIPlayer.New(1, AIPlayer.Strategy.BALANCED)
        ai.bidDelay = 0
        local shouldBid, amount = ai:Update(0.1, 10000, 1, 5)
        TestRunner.Assert(shouldBid, "Should bid when delay expired")
        TestRunner.Assert(amount > 0, "Amount should be positive")
        TestRunner.Assert(amount <= 10000, "Amount should not exceed funds")
    end,

    test_no_bid_when_no_funds = function()
        local ai = AIPlayer.New(1)
        ai.bidDelay = 0
        local shouldBid, amount = ai:Update(0.1, 0, 1, 5)
        TestRunner.Assert(shouldBid, "Should bid (auto 0) when no funds")
        TestRunner.AssertEqual(0, amount, "Amount should be 0 when no funds")
    end,

    test_bid_amount_based_on_strategy = function()
        -- 激进策略应该出价更高
        local aggressive = AIPlayer.New(1, AIPlayer.Strategy.AGGRESSIVE)
        local conservative = AIPlayer.New(2, AIPlayer.Strategy.CONSERVATIVE)

        aggressive.bidDelay = 0
        conservative.bidDelay = 0

        local aggTotal = 0
        local consTotal = 0
        local trials = 50

        for i = 1, trials do
            local _, aggAmt = aggressive:Update(0.1, 10000, 3, 5)
            local _, consAmt = conservative:Update(0.1, 10000, 3, 5)
            aggTotal = aggTotal + aggAmt
            consTotal = consTotal + consAmt
            -- 重置
            aggressive.hasBidThisRound = false
            conservative.hasBidThisRound = false
            aggressive.bidDelay = 0
            conservative.bidDelay = 0
        end

        local aggAvg = aggTotal / trials
        local consAvg = consTotal / trials

        print(string.format("[Test] Aggressive avg bid: %.0f, Conservative avg bid: %.0f",
            aggAvg, consAvg))

        -- 激进策略平均出价应该更高
        TestRunner.Assert(aggAvg > consAvg, "Aggressive should bid more than conservative")
    end,

    test_last_round_aggressive_goes_all_in = function()
        local ai = AIPlayer.New(1, AIPlayer.Strategy.AGGRESSIVE)
        ai.bidDelay = 0

        -- 模拟最后一轮
        local shouldBid, amount = ai:Update(0.1, 10000, 5, 5)
        TestRunner.Assert(shouldBid, "Should bid on last round")

        -- 激进策略最后一轮应该出价较高
        local ratio = amount / 10000
        TestRunner.Assert(ratio > 0.5, "Aggressive should bet big on last round, ratio: " .. string.format("%.2f", ratio))
    end,

    test_pressure_when_behind = function()
        local ai = AIPlayer.New(1, AIPlayer.Strategy.BALANCED)
        ai.bidDelay = 0

        -- 记录上一轮落后排名
        ai:RecordRank(1, 3)

        local _, amountBehind = ai:Update(0.1, 10000, 2, 5)

        -- 重置
        ai.hasBidThisRound = false
        ai.bidDelay = 0

        -- 领先时出价更低
        ai:RecordRank(1, 1)
        local _, amountAhead = ai:Update(0.1, 10000, 2, 5)

        print(string.format("[Test] Behind rank bid: %d, Ahead rank bid: %d",
            amountBehind, amountAhead))

        TestRunner.Assert(amountBehind > amountAhead,
            "Should bid more when behind, got behind=" .. amountBehind .. " ahead=" .. amountAhead)
    end,

    test_name_generation = function()
        local names = {}
        for i = 1, 30 do
            local ai = AIPlayer.New(i)
            names[ai.name] = true
        end
        -- 名字应该有变化
        local uniqueCount = 0
        for _ in pairs(names) do uniqueCount = uniqueCount + 1 end
        TestRunner.Assert(uniqueCount > 10, "Should have some name variety, got " .. uniqueCount)
    end,

    test_cannot_bid_twice_same_round = function()
        local ai = AIPlayer.New(1)
        ai.bidDelay = 0

        local shouldBid1, _ = ai:Update(0.1, 10000, 1, 5)
        TestRunner.Assert(shouldBid1, "First call should bid")

        local shouldBid2, _ = ai:Update(0.1, 10000, 1, 5)
        TestRunner.Assert(not shouldBid2, "Second call same round should not bid")
    end,
}

-- 运行测试
TestRunner.RunSuite("AIPlayer", tests)
TestRunner.PrintSummary()

return TestRunner.results
