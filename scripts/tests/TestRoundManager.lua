-- ============================================================================
-- tests/TestRoundManager.lua - RoundManager 单元测试
-- ============================================================================

local TestRunner = require("Utils.TestRunner")
local Config = require("Config")
local RoundManager = require("Game.RoundManager")

-- 创建测试用 RoundManager
local function CreateTestRoundManager()
    local rm = RoundManager.New()
    -- 重置回调以避免 nil 引用
    rm.onRoundStart = function() end
    rm.onBidTimeout = function() end
    rm.onRoundSettle = function() end
    rm.onSpeedWin = function() end
    rm.onGameOver = function() end
    rm.onTimerTick = function() end
    return rm
end

-- 测试套件
local tests = {
    -- 基础测试
    test_initial_state = function()
        local rm = CreateTestRoundManager()
        TestRunner.AssertEqual(0, rm:GetCurrentRound(), "Should start at round 0")
        TestRunner.AssertEqual(RoundManager.Phase.IDLE, rm:GetPhase(), "Should be in IDLE phase")
        TestRunner.Assert(not rm:IsGameOver(), "Should not be game over initially")
        TestRunner.Assert(not rm:IsBidding(), "Should not be bidding initially")
    end,

    test_start_game = function()
        local rm = CreateTestRoundManager()
        rm:StartGame()
        TestRunner.AssertEqual(1, rm:GetCurrentRound(), "Should start at round 1")
        TestRunner.AssertEqual(RoundManager.Phase.PREPARE, rm:GetPhase(), "Should be in PREPARE phase")
    end,

    -- 回合状态转换
    test_prepare_to_bidding = function()
        local rm = CreateTestRoundManager()
        rm:StartGame()

        -- 跳过准备时间
        rm:Update(Config.Auction.PrepareTime + 0.1)

        TestRunner.AssertEqual(RoundManager.Phase.BIDDING, rm:GetPhase(), "Should transition to BIDDING")
    end,

    test_bidding_timeout = function()
        local rm = CreateTestRoundManager()
        rm:StartGame()

        -- 准备 → 出价
        rm:Update(Config.Auction.PrepareTime + 0.1)
        TestRunner.AssertEqual(RoundManager.Phase.BIDDING, rm:GetPhase(), "Should be in BIDDING")

        -- 出价 → 结算
        rm:Update(Config.Auction.BidTimeLimit + 0.1)
        TestRunner.AssertEqual(RoundManager.Phase.SETTLING, rm:GetPhase(), "Should be in SETTLING")
    end,

    test_full_round_cycle = function()
        local rm = CreateTestRoundManager()
        rm:StartGame()

        local totalTime = Config.Auction.PrepareTime + Config.Auction.BidTimeLimit + Config.Auction.ResultShowTime
        rm:Update(totalTime + 0.1)

        TestRunner.AssertEqual(2, rm:GetCurrentRound(), "Should advance to round 2")
    end,

    test_all_rounds_complete = function()
        local rm = CreateTestRoundManager()
        rm:StartGame()

        -- 模拟所有5轮
        local rounds = Config.Auction.TotalRounds
        for i = 1, rounds do
            local totalTime = Config.Auction.PrepareTime + Config.Auction.BidTimeLimit + Config.Auction.ResultShowTime
            rm:Update(totalTime + 0.1)
        end

        TestRunner.Assert(rm:IsGameOver(), "Should be game over after all rounds")
        TestRunner.AssertEqual(RoundManager.Phase.DONE, rm:GetPhase(), "Should be in DONE phase")
    end,

    -- 速胜检测
    test_speed_win_multiplier = function()
        local rm = CreateTestRoundManager()
        rm:StartGame()
        rm:Update(Config.Auction.PrepareTime + 0.1)

        -- 第1轮速胜倍率应该是2.0
        TestRunner.AssertApprox(2.0, rm:GetSpeedWinMultiplier(), 0.01, "Round 1 speed win mult")
    end,

    test_speed_win_detection = function()
        local rm = CreateTestRoundManager()

        -- 第一名2000，第二名500 → 应该触发速胜
        local results = {
            { seatIdx = 1, amount = 2000, rank = 1 },
            { seatIdx = 2, amount = 500, rank = 2 },
        }

        local isSpeedWin, winner = rm:CheckSpeedWin(results)
        TestRunner.Assert(isSpeedWin, "Should detect speed win")
        TestRunner.AssertEqual(1, winner, "Winner should be seat 1")
    end,

    test_no_speed_win = function()
        local rm = CreateTestRoundManager()

        -- 第一名1000，第二名500 → 1000 < 500 * 2.0，不触发速胜
        local results = {
            { seatIdx = 1, amount = 1000, rank = 1 },
            { seatIdx = 2, amount = 500, rank = 2 },
        }

        local isSpeedWin, winner = rm:CheckSpeedWin(results)
        TestRunner.Assert(not isSpeedWin, "Should not detect speed win")
    end,

    test_no_speed_win_last_round = function()
        local rm = CreateTestRoundManager()
        rm.currentRound = 5  -- 最后一轮

        -- 第5轮速胜倍率应该为0
        TestRunner.AssertApprox(0, rm:GetSpeedWinMultiplier(), 0.01, "Last round no speed win")
    end,

    -- 提前结算（所有人出价完毕）
    test_early_settle = function()
        local rm = CreateTestRoundManager()
        rm:StartGame()
        rm:Update(Config.Auction.PrepareTime + 0.1)

        TestRunner.AssertEqual(RoundManager.Phase.BIDDING, rm:GetPhase(), "Should be bidding")

        -- 通知所有人出价完毕
        rm:NotifyAllBidsIn()
        TestRunner.AssertEqual(0, rm:GetTimeLeft(), "Timer should be 0")
    end,

    -- 速胜触发
    test_trigger_speed_win = function()
        local rm = CreateTestRoundManager()
        local triggered = false
        local winnerSeat = nil

        rm.onSpeedWin = function(seat, round)
            triggered = true
            winnerSeat = seat
        end

        rm:TriggerSpeedWin(3)
        TestRunner.Assert(triggered, "Speed win should be triggered")
        TestRunner.AssertEqual(3, winnerSeat, "Winner should be seat 3")
        TestRunner.Assert(rm:IsGameOver(), "Should be game over after speed win")
    end,

    -- 计时器测试
    test_time_left = function()
        local rm = CreateTestRoundManager()
        rm:StartGame()
        rm:Update(Config.Auction.PrepareTime + 0.1)

        local timeLeft = rm:GetTimeLeft()
        TestRunner.Assert(timeLeft > 0, "Should have time left")
        TestRunner.Assert(timeLeft <= Config.Auction.BidTimeLimit, "Should be within bid time limit")
    end,
}

-- 运行测试
TestRunner.RunSuite("RoundManager", tests)
TestRunner.PrintSummary()

return TestRunner.results
