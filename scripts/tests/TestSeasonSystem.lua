-- ============================================================================
-- TestSeasonSystem.lua - 赛季系统单元测试
-- ============================================================================

local TestRunner = require("Utils.TestRunner")
local SeasonSystem = require("Game.SeasonSystem")

local tests = TestRunner.NewSuite("SeasonSystem")

-- ============================================================================
-- 测试：赛季 ID 生成
-- ============================================================================
function tests.TestSeasonIdGeneration()
    local seasonId = SeasonSystem.GetCurrentSeasonId()
    TestRunner.Assert(type(seasonId) == "string", "Season ID should be string")
    TestRunner.Assert(string.match(seasonId, "^S%d+$"), "Season ID format: S###")
    print("[SeasonSystem] 当前赛季: " .. seasonId)
end

-- ============================================================================
-- 测试：升级所需经验计算
-- ============================================================================
function tests.TestExpForLevel()
    local exp1 = SeasonSystem.GetExpForLevel(1)
    local exp2 = SeasonSystem.GetExpForLevel(2)
    local exp5 = SeasonSystem.GetExpForLevel(5)

    TestRunner.Assert(exp1 > 0, "Level 1 exp should be positive")
    TestRunner.Assert(exp2 > exp1, "Higher level should need more exp")
    TestRunner.Assert(exp5 > exp2, "Level 5 should need more exp than level 2")

    print("[SeasonSystem] 1级需 " .. exp1 .. " exp, 2级需 " .. exp2 .. " exp, 5级需 " .. exp5 .. " exp")
end

-- ============================================================================
-- 测试：奖励配置
-- ============================================================================
function tests.TestRewardConfiguration()
    local reward1 = SeasonSystem.GetReward(1)
    local reward10 = SeasonSystem.GetReward(10)
    local reward50 = SeasonSystem.GetReward(50)

    TestRunner.Assert(reward1 ~= nil, "Level 1 should have reward")
    TestRunner.Assert(reward10 ~= nil, "Level 10 should have reward")
    TestRunner.Assert(reward50 ~= nil, "Level 50 should have reward")

    TestRunner.Assert(reward1.type == "gold", "Level 1 reward should be gold")
    TestRunner.Assert(reward50.rarity == 4, "Level 50 reward should be legendary")

    print("[SeasonSystem] 奖励: Lv1=" .. reward1.name .. ", Lv50=" .. reward50.name)
end

-- ============================================================================
-- 测试：经验添加（模拟）
-- ============================================================================
function tests.TestAddExp()
    -- 模拟添加经验
    local levelsGained = SeasonSystem.AddExp("test_player_001", 100, "test")
    TestRunner.Assert(type(levelsGained) == "number", "Should return levels gained")

    print("[SeasonSystem] 添加 100 经验，获得 " .. levelsGained .. " 级")
end

-- ============================================================================
-- 测试：赛季状态获取
-- ============================================================================
function tests.TestGetPlayerStatus()
    local status = SeasonSystem.GetPlayerStatus("test_player_001")

    TestRunner.Assert(status ~= nil, "Should return status")
    TestRunner.Assert(status.level >= 1, "Level should be at least 1")
    TestRunner.Assert(status.maxLevel > 0, "Max level should be positive")

    print("[SeasonSystem] 玩家状态: Lv" .. status.level .. "/" .. status.maxLevel .. ", 进度" .. status.progressPercent .. "%")
end

-- ============================================================================
-- 测试：奖励领取检查
-- ============================================================================
function tests.TestCanClaimReward()
    -- 给予足够经验到 5 级
    SeasonSystem.AddExp("test_player_001", 5000, "test")

    local canClaim1 = SeasonSystem.CanClaimReward("test_player_001", 1)
    local canClaim50 = SeasonSystem.CanClaimReward("test_player_001", 50)

    TestRunner.Assert(canClaim1 == true, "Should be able to claim level 1 reward")
    TestRunner.Assert(canClaim50 == false, "Should NOT be able to claim level 50 reward yet")

    print("[SeasonSystem] 可领取: Lv1=" .. tostring(canClaim1) .. ", Lv50=" .. tostring(canClaim50))
end

-- ============================================================================
-- 测试：奖励领取
-- ============================================================================
function tests.TestClaimReward()
    local reward = SeasonSystem.ClaimReward("test_player_001", 1)

    TestRunner.Assert(reward ~= nil, "Should return reward")
    TestRunner.Assert(reward.name ~= nil, "Reward should have name")

    print("[SeasonSystem] 领取奖励: " .. reward.name)
end

-- ============================================================================
-- 测试：时间格式化
-- ============================================================================
function tests.TestFormatTimeRemaining()
    local remaining = SeasonSystem.GetSeasonTimeRemaining()
    TestRunner.Assert(remaining >= 0, "Remaining time should be non-negative")

    local formatted = SeasonSystem.FormatTimeRemaining(86400 * 3 + 3600 * 5)  -- 3天5小时
    TestRunner.Assert(string.find(formatted, "天"), "Should contain 'days'")
    TestRunner.Assert(string.find(formatted, "小时"), "Should contain 'hours'")

    print("[SeasonSystem] 赛季剩余: " .. formatted)
end

-- ============================================================================
-- 测试：未领取奖励列表
-- ============================================================================
function tests.TestGetUnclaimedRewards()
    local unclaimed = SeasonSystem.GetUnclaimedRewards("test_player_001")

    TestRunner.Assert(type(unclaimed) == "table", "Should return table")
    TestRunner.Assert(#unclaimed >= 0, "Should return array")

    print("[SeasonSystem] 待领取奖励数: " .. #unclaimed)
end

-- ============================================================================
-- 运行所有测试
-- ============================================================================
TestRunner.Run(tests)

return tests
