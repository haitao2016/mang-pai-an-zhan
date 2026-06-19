-- ============================================================================
-- tests/TestBidSystem.lua - BidSystem 单元测试
-- ============================================================================

local TestRunner = require("Utils.TestRunner")
local Config = require("Config")
local BidSystem = require("Game.BidSystem")

-- 创建独立的 BidSystem 用于测试
local function CreateTestBidSystem()
    local bs = BidSystem.New()
    bs:InitPlayer(1, 10000)
    bs:InitPlayer(2, 12000)
    bs:InitPlayer(3, 8000)
    bs:InitPlayer(4, 15000)
    return bs
end

-- 测试套件
local tests = {
    -- 基础初始化测试
    test_init = function()
        local bs = BidSystem.New()
        TestRunner.Assert(bs ~= nil, "BidSystem should be created")
        TestRunner.AssertEqual(0, bs:GetActivePlayerCount(), "Should start with 0 players")
    end,

    test_init_players = function()
        local bs = CreateTestBidSystem()
        TestRunner.AssertEqual(4, bs:GetActivePlayerCount(), "Should have 4 players")
        TestRunner.AssertEqual(10000, bs:GetAvailableFunds(1), "Player 1 funds")
        TestRunner.AssertEqual(12000, bs:GetAvailableFunds(2), "Player 2 funds")
    end,

    -- 出价测试
    test_valid_bid = function()
        local bs = CreateTestBidSystem()
        local accepted, reason = bs:SubmitBid(1, 1000)
        TestRunner.Assert(accepted, "Valid bid should be accepted")
        TestRunner.AssertEqual("", reason, "Should have no error message")
        TestRunner.AssertEqual(9000, bs:GetAvailableFunds(1), "Funds should be deducted")
    end,

    test_bid_exceed_funds = function()
        local bs = CreateTestBidSystem()
        local accepted, reason = bs:SubmitBid(1, 15000)
        TestRunner.Assert(not accepted, "Bid exceeding funds should be rejected")
        TestRunner.Assert(reason ~= "", "Should have error message")
    end,

    test_duplicate_bid = function()
        local bs = CreateTestBidSystem()
        bs:SubmitBid(1, 1000)
        local accepted, reason = bs:SubmitBid(1, 2000)
        TestRunner.Assert(not accepted, "Duplicate bid should be rejected")
    end,

    test_bid_zero = function()
        local bs = CreateTestBidSystem()
        local accepted, reason = bs:SubmitBid(1, 0)
        TestRunner.Assert(accepted, "Zero bid should be allowed")
        TestRunner.AssertEqual(10000, bs:GetAvailableFunds(1), "Funds unchanged for zero bid")
    end,

    test_bid_history = function()
        local bs = CreateTestBidSystem()
        bs:StartRound(1)
        bs:SubmitBid(1, 1000)
        bs:SubmitBid(2, 2000)
        bs:SubmitBid(3, 500)
        bs:SubmitBid(4, 1500)

        local history = bs:GetBidHistory()
        TestRunner.Assert(history ~= nil, "History should exist")
        TestRunner.AssertEqual(1000, history[1][1], "Player 1 bid recorded")
        TestRunner.AssertEqual(2000, history[1][2], "Player 2 bid recorded")
    end,

    -- 结算测试
    test_settle_ranking = function()
        local bs = CreateTestBidSystem()
        bs:StartRound(1)
        bs:SubmitBid(1, 1000)
        bs:SubmitBid(2, 2000)
        bs:SubmitBid(3, 500)
        bs:SubmitBid(4, 1500)

        local results = bs:SettleRound(1)
        TestRunner.AssertEqual(4, #results, "Should have 4 results")

        -- 检查排名顺序
        TestRunner.AssertEqual(2, results[1].seatIdx, "Player 2 should be 1st")
        TestRunner.AssertEqual(4, results[2].seatIdx, "Player 4 should be 2nd")
        TestRunner.AssertEqual(1, results[3].seatIdx, "Player 1 should be 3rd")
        TestRunner.AssertEqual(3, results[4].seatIdx, "Player 3 should be 4th")

        TestRunner.AssertEqual(1, results[1].rank, "Player 2 rank 1")
        TestRunner.AssertEqual(2, results[2].rank, "Player 4 rank 2")
    end,

    test_all_bids_submitted = function()
        local bs = CreateTestBidSystem()
        TestRunner.Assert(not bs:AllBidsSubmitted(), "Should not be complete initially")

        bs:StartRound(1)
        TestRunner.Assert(not bs:AllBidsSubmitted(), "Should not be complete after StartRound")

        bs:SubmitBid(1, 1000)
        TestRunner.Assert(not bs:AllBidsSubmitted(), "Should not be complete with 1 bid")

        bs:SubmitBid(2, 1000)
        bs:SubmitBid(3, 1000)
        bs:SubmitBid(4, 1000)
        TestRunner.Assert(bs:AllBidsSubmitted(), "Should be complete after all bids")
    end,

    test_auto_bid_timeout = function()
        local bs = CreateTestBidSystem()
        bs:StartRound(1)
        bs:SubmitBid(1, 1000)
        bs:SubmitBid(2, 2000)
        -- Players 3 and 4 timeout
        bs:AutoBidForTimeout()

        TestRunner.AssertEqual(0, bs.currentBids[3], "Player 3 auto-bid 0")
        TestRunner.AssertEqual(0, bs.currentBids[4], "Player 4 auto-bid 0")
        TestRunner.Assert(bs:AllBidsSubmitted(), "All bids should be submitted after auto-bid")
    end,

    test_remove_player = function()
        local bs = CreateTestBidSystem()
        bs:RemovePlayer(1)
        TestRunner.AssertEqual(3, bs:GetActivePlayerCount(), "Should have 3 players after removal")
        TestRunner.AssertEqual(nil, bs.funds[1], "Player 1 funds should be removed")
    end,

    test_add_funds = function()
        local bs = CreateTestBidSystem()
        local initial = bs:GetAvailableFunds(1)
        bs:AddFunds(1, 1000)
        TestRunner.AssertEqual(initial + 1000, bs:GetAvailableFunds(1), "Funds should be added")
    end,

    test_total_bid_accumulation = function()
        local bs = CreateTestBidSystem()

        -- Round 1
        bs:StartRound(1)
        bs:SubmitBid(1, 1000)
        bs:SubmitBid(2, 2000)
        bs:SubmitBid(3, 500)
        bs:SubmitBid(4, 1500)
        bs:SettleRound(1)

        -- Round 2
        bs:StartRound(2)
        bs:SubmitBid(1, 500)
        bs:SubmitBid(2, 1000)
        bs:SubmitBid(3, 300)
        bs:SubmitBid(4, 800)
        bs:SettleRound(2)

        -- Check accumulated totals
        TestRunner.AssertEqual(1500, bs:GetTotalBid(1), "Player 1 total bid")
        TestRunner.AssertEqual(3000, bs:GetTotalBid(2), "Player 2 total bid")
        TestRunner.AssertEqual(800, bs:GetTotalBid(3), "Player 3 total bid")
        TestRunner.AssertEqual(2300, bs:GetTotalBid(4), "Player 4 total bid")
    end,
}

-- 运行测试
TestRunner.RunSuite("BidSystem", tests)
TestRunner.PrintSummary()

return TestRunner.results
