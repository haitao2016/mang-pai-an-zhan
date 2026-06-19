-- ============================================================================
-- TestTradeSystem.lua - 藏品交易市场系统单元测试
-- ============================================================================

local TestRunner = require("Utils.TestRunner")
local TradeSystem = require("Game.TradeSystem")

local tests = TestRunner.NewSuite("TradeSystem")

-- ============================================================================
-- 测试：创建挂单
-- ============================================================================
function tests.TestCreateListing()
    TradeSystem.Reset()

    local ok, listingId = TradeSystem.CreateListing("seller1", "item001", {
        name = "稀有道具",
        rarity = 3
    }, 500)

    TestRunner.Assert(ok == true, "Listing creation should succeed")
    TestRunner.Assert(type(listingId) == "string", "Should return listing ID")
    TestRunner.Assert(string.match(listingId, "^LIST_"), "Listing ID should start with LIST_")

    print("[TradeSystem] 创建挂单: " .. listingId)
end

-- ============================================================================
-- 测试：挂单价格验证
-- ============================================================================
function tests.TestPriceValidation()
    TradeSystem.Reset()

    -- 价格过低
    local ok1, err1 = TradeSystem.CreateListing("seller1", "item001", {}, 5)
    TestRunner.Assert(ok1 == false, "Should fail for price too low")
    TestRunner.Assert(err1 == "price_too_low", "Should return price_too_low error")

    -- 价格过高
    local ok2, err2 = TradeSystem.CreateListing("seller1", "item001", {}, 2000000)
    TestRunner.Assert(ok2 == false, "Should fail for price too high")
    TestRunner.Assert(err2 == "price_too_high", "Should return price_too_high error")

    print("[TradeSystem] 价格验证测试完成")
end

-- ============================================================================
-- 测试：购买藏品
-- ============================================================================
function tests.TestPurchase()
    TradeSystem.Reset()

    local _, listingId = TradeSystem.CreateListing("seller1", "item001", {
        name = "测试道具",
        rarity = 2
    }, 100)

    local ok, tradeId, result = TradeSystem.Purchase("buyer1", listingId)
    TestRunner.Assert(ok == true, "Purchase should succeed")
    TestRunner.Assert(type(tradeId) == "string", "Should return trade ID")
    TestRunner.Assert(result.itemName == "测试道具", "Should return correct item")
    TestRunner.Assert(result.fee == 5, "Fee should be 5%")

    print("[TradeSystem] 购买测试完成: " .. tradeId)
end

-- ============================================================================
-- 测试：不能购买自己的挂单
-- ============================================================================
function tests.TestCannotBuyOwnListing()
    TradeSystem.Reset()

    local _, listingId = TradeSystem.CreateListing("seller1", "item001", {}, 100)

    local ok, err = TradeSystem.Purchase("seller1", listingId)
    TestRunner.Assert(ok == false, "Should fail")
    TestRunner.Assert(err == "cannot_buy_own_listing", "Should return cannot_buy_own_listing")

    print("[TradeSystem] 自我购买测试完成")
end

-- ============================================================================
-- 测试：拉黑玩家
-- ============================================================================
function tests.TestBlockPlayer()
    TradeSystem.Reset()

    local ok = TradeSystem.BlockPlayer("player1", "player2")
    TestRunner.Assert(ok == true, "Block should succeed")

    local ok2, err2 = TradeSystem.BlockPlayer("player1", "player2")
    TestRunner.Assert(ok2 == false, "Duplicate block should fail")

    local blacklist = TradeSystem.GetBlacklist("player1")
    TestRunner.Assert(#blacklist == 1, "Should have 1 blocked player")
    TestRunner.Assert(blacklist[1] == "player2", "Should be player2")

    print("[TradeSystem] 拉黑测试完成")
end

-- ============================================================================
-- 测试：解除拉黑
-- ============================================================================
function tests.TestUnblockPlayer()
    TradeSystem.Reset()

    TradeSystem.BlockPlayer("player1", "player2")

    local ok = TradeSystem.UnblockPlayer("player1", "player2")
    TestRunner.Assert(ok == true, "Unblock should succeed")

    local blacklist = TradeSystem.GetBlacklist("player1")
    TestRunner.Assert(#blacklist == 0, "Should have no blocked players")

    print("[TradeSystem] 解除拉黑测试完成")
end

-- ============================================================================
-- 测试：不能与拉黑的卖家交易
-- ============================================================================
function tests.TestBlockedSeller()
    TradeSystem.Reset()

    local _, listingId = TradeSystem.CreateListing("seller1", "item001", {}, 100)

    TradeSystem.BlockPlayer("buyer1", "seller1")

    local ok, err = TradeSystem.Purchase("buyer1", listingId)
    TestRunner.Assert(ok == false, "Should fail")
    TestRunner.Assert(err == "seller_blocked", "Should return seller_blocked")

    print("[TradeSystem] 拉黑交易测试完成")
end

-- ============================================================================
-- 测试：获取市场列表
-- ============================================================================
function tests.TestGetMarketList()
    TradeSystem.Reset()

    -- 创建多个挂单
    TradeSystem.CreateListing("seller1", "item1", { name = "道具A", rarity = 1 }, 100)
    TradeSystem.CreateListing("seller2", "item2", { name = "道具B", rarity = 3 }, 300)
    TradeSystem.CreateListing("seller3", "item3", { name = "道具C", rarity = 5 }, 500)

    local allListings = TradeSystem.GetMarketList({})
    TestRunner.Assert(#allListings >= 3, "Should have at least 3 listings")

    -- 按稀有度筛选
    local rareListings = TradeSystem.GetMarketList({ rarity = 3 })
    for _, listing in ipairs(rareListings) do
        TestRunner.Assert(listing.itemRarity == 3, "All should be rarity 3")
    end

    -- 按价格筛选
    local cheapListings = TradeSystem.GetMarketList({ maxPrice = 200 })
    for _, listing in ipairs(cheapListings) do
        TestRunner.Assert(listing.price <= 200, "All should be <= 200")
    end

    print("[TradeSystem] 市场列表测试完成")
end

-- ============================================================================
-- 测试：获取我的挂单
-- ============================================================================
function tests.TestGetMyListings()
    TradeSystem.Reset()

    TradeSystem.CreateListing("player1", "item1", { name = "我的道具1" }, 100)
    TradeSystem.CreateListing("player1", "item2", { name = "我的道具2" }, 200)

    local myListings = TradeSystem.GetMyListings("player1")
    TestRunner.Assert(#myListings == 2, "Should have 2 listings")

    local otherListings = TradeSystem.GetMyListings("player2")
    TestRunner.Assert(#otherListings == 0, "Should have 0 listings")

    print("[TradeSystem] 我的挂单测试完成")
end

-- ============================================================================
-- 测试：取消挂单
-- ============================================================================
function tests.TestCancelListing()
    TradeSystem.Reset()

    local _, listingId = TradeSystem.CreateListing("seller1", "item001", {}, 100)

    local ok = TradeSystem.CancelListing("seller1", listingId)
    TestRunner.Assert(ok == true, "Cancel should succeed")

    local myListings = TradeSystem.GetMyListings("seller1")
    TestRunner.Assert(#myListings == 0, "Should have 0 listings")

    print("[TradeSystem] 取消挂单测试完成")
end

-- ============================================================================
-- 测试：获取交易历史
-- ============================================================================
function tests.TestGetTradeHistory()
    TradeSystem.Reset()

    local _, listingId = TradeSystem.CreateListing("seller1", "item001", {}, 100)
    TradeSystem.Purchase("buyer1", listingId)

    -- 卖家的交易历史
    local sellerHistory = TradeSystem.GetTradeHistory("seller1")
    TestRunner.Assert(#sellerHistory >= 1, "Should have seller history")
    TestRunner.Assert(sellerHistory[1].type == "sold", "Should be sold type")

    -- 买家的交易历史
    local buyerHistory = TradeSystem.GetTradeHistory("buyer1")
    TestRunner.Assert(#buyerHistory >= 1, "Should have buyer history")
    TestRunner.Assert(buyerHistory[1].type == "purchased", "Should be purchased type")

    print("[TradeSystem] 交易历史测试完成")
end

-- ============================================================================
-- 测试：市场统计
-- ============================================================================
function tests.TestGetMarketStats()
    TradeSystem.Reset()

    TradeSystem.CreateListing("seller1", "item1", { name = "A", rarity = 1 }, 100)
    TradeSystem.CreateListing("seller2", "item2", { name = "B", rarity = 3 }, 300)

    local _, listingId = TradeSystem.CreateListing("seller3", "item3", { name = "C", rarity = 5 }, 500)
    TradeSystem.Purchase("buyer1", listingId)

    local stats = TradeSystem.GetMarketStats()
    TestRunner.Assert(stats.totalListings >= 3, "Should have total listings")
    TestRunner.Assert(stats.totalTrades >= 1, "Should have at least 1 trade")

    print("[TradeSystem] 市场统计测试完成")
end

-- ============================================================================
-- 运行所有测试
-- ============================================================================
TestRunner.Run(tests)

return tests
