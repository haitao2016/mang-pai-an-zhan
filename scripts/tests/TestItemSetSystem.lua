-- ============================================================================
-- TestItemSetSystem.lua - 藏品套装系统单元测试
-- ============================================================================

local TestRunner = require("Utils.TestRunner")
local ItemSetSystem = require("Game.ItemSetSystem")

local tests = TestRunner.NewSuite("ItemSetSystem")

-- ============================================================================
-- 测试：获取所有套装配置
-- ============================================================================
function tests.TestGetAllSets()
    local sets = ItemSetSystem.GetAllSets()
    TestRunner.Assert(type(sets) == "table", "Should return table")
    TestRunner.Assert(#sets >= 3, "Should have at least 3 sets")

    print("[ItemSetSystem] 获取套装列表测试通过，共 " .. #sets .. " 个套装")
end

-- ============================================================================
-- 测试：获取玩家套装进度
-- ============================================================================
function tests.TestGetPlayerProgress()
    ItemSetSystem.Reset("test_player_001")

    local progress = ItemSetSystem.GetPlayerProgress("test_player_001")
    TestRunner.Assert(type(progress) == "table", "Should return table")
    TestRunner.Assert(#progress >= 3, "Should have progress for all sets")

    print("[ItemSetSystem] 获取进度测试通过")
end

-- ============================================================================
-- 测试：添加藏品到套装
-- ============================================================================
function tests.TestCollectItem()
    ItemSetSystem.Reset("test_player_001")

    local changed = ItemSetSystem.CollectItem("test_player_001", "eastern_001", "eastern", 1)
    TestRunner.Assert(changed == true, "Should add item to set")

    local progress = ItemSetSystem.GetPlayerProgress("test_player_001")
    local easternProgress = nil
    for _, p in ipairs(progress) do
        if p.id == "set_eastern" then
            easternProgress = p
            break
        end
    end

    TestRunner.Assert(easternProgress ~= nil, "Should have eastern set progress")
    TestRunner.Assert(easternProgress.collected >= 1, "Should have collected 1 item")

    print("[ItemSetSystem] 收集藏品测试通过")
end

-- ============================================================================
-- 测试：重复收集不计入
-- ============================================================================
function tests.TestDuplicateCollect()
    ItemSetSystem.Reset("test_player_002")

    ItemSetSystem.CollectItem("test_player_002", "eastern_001", "eastern", 1)
    local changed = ItemSetSystem.CollectItem("test_player_002", "eastern_001", "eastern", 1)

    local progress = ItemSetSystem.GetPlayerProgress("test_player_002")
    for _, p in ipairs(progress) do
        if p.id == "set_eastern" then
            TestRunner.Assert(p.collected == 1, "Should not count duplicate items")
            break
        end
    end

    print("[ItemSetSystem] 重复收集测试通过")
end

-- ============================================================================
-- 测试：套装完成检测
-- ============================================================================
function tests.TestSetCompletion()
    ItemSetSystem.Reset("test_player_003")

    -- 东方艺术系列需要 10 件
    for i = 1, 10 do
        ItemSetSystem.CollectItem("test_player_003", "eastern_" .. string.format("%03d", i), "eastern", 1)
    end

    local isComplete = ItemSetSystem.IsSetComplete("test_player_003", "set_eastern")
    TestRunner.Assert(isComplete == true, "Set should be complete after 10 items")

    print("[ItemSetSystem] 套装完成检测测试通过")
end

-- ============================================================================
-- 测试：获取套装详情
-- ============================================================================
function tests.TestGetSetDetails()
    ItemSetSystem.Reset("test_player_004")

    ItemSetSystem.CollectItem("test_player_004", "eastern_001", "eastern", 1)

    local details = ItemSetSystem.GetSetDetails("test_player_004", "set_eastern")
    TestRunner.Assert(details ~= nil, "Should return details")
    TestRunner.Assert(details.collected >= 1, "Should show collected items")
    TestRunner.Assert(details.required == 10, "Should show required count")

    print("[ItemSetSystem] 套装详情测试通过")
end

-- ============================================================================
-- 测试：领取套装奖励
-- ============================================================================
function tests.TestClaimReward()
    ItemSetSystem.Reset("test_player_005")

    -- 收集完成套装
    for i = 1, 10 do
        ItemSetSystem.CollectItem("test_player_005", "eastern_" .. string.format("%03d", i), "eastern", 1)
    end

    -- 领取奖励
    local ok, reward = ItemSetSystem.ClaimReward("test_player_005", "set_eastern")
    TestRunner.Assert(ok == true, "Should claim reward successfully")
    TestRunner.Assert(reward ~= nil, "Should return reward")

    -- 重复领取应失败
    ok = ItemSetSystem.ClaimReward("test_player_005", "set_eastern")
    TestRunner.Assert(ok == false, "Should not allow duplicate claim")

    print("[ItemSetSystem] 领取奖励测试通过")
end

-- ============================================================================
-- 测试：未完成无法领取
-- ============================================================================
function tests.TestCannotClaimIncomplete()
    ItemSetSystem.Reset("test_player_006")

    -- 只收集 1 件
    ItemSetSystem.CollectItem("test_player_006", "eastern_001", "eastern", 1)

    local ok = ItemSetSystem.ClaimReward("test_player_006", "set_eastern")
    TestRunner.Assert(ok == false, "Should not allow claim for incomplete set")

    print("[ItemSetSystem] 未完成无法领取测试通过")
end

-- ============================================================================
-- 测试：获取可领取奖励的套装
-- ============================================================================
function tests.TestGetClaimableSets()
    ItemSetSystem.Reset("test_player_007")

    -- 完成一个套装
    for i = 1, 10 do
        ItemSetSystem.CollectItem("test_player_007", "eastern_" .. string.format("%03d", i), "eastern", 1)
    end

    local claimable = ItemSetSystem.GetClaimableSets("test_player_007")
    TestRunner.Assert(#claimable >= 1, "Should have at least 1 claimable set")

    print("[ItemSetSystem] 可领取套装测试通过，共 " .. #claimable .. " 个可领取")
end

-- ============================================================================
-- 测试：稀有度收集套装
-- ============================================================================
function tests.TestRaritySetCollection()
    ItemSetSystem.Reset("test_player_008")

    -- 收集 50 件稀有以上藏品（稀有度 >= 2）
    for i = 1, 50 do
        ItemSetSystem.CollectItem("test_player_008", "item_r" .. i, "set_rare", 2)
    end

    local isComplete = ItemSetSystem.IsSetComplete("test_player_008", "set_rare")
    TestRunner.Assert(isComplete == true, "Rarity set should be complete")

    print("[ItemSetSystem] 稀有度套装测试通过")
end

-- ============================================================================
-- 测试：重置功能
-- ============================================================================
function tests.TestReset()
    ItemSetSystem.CollectItem("test_player_009", "eastern_001", "eastern", 1)

    ItemSetSystem.Reset("test_player_009")

    local progress = ItemSetSystem.GetPlayerProgress("test_player_009")
    for _, p in ipairs(progress) do
        TestRunner.Assert(p.collected == 0, "Progress should be reset")
    end

    print("[ItemSetSystem] 重置功能测试通过")
end

-- ============================================================================
-- 运行所有测试
-- ============================================================================
TestRunner.Run(tests)

return tests
