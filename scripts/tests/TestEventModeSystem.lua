-- ============================================================================
-- TestEventModeSystem.lua - 活动模式系统单元测试（v1.1）
-- ============================================================================

local TestRunner = require("Utils.TestRunner")
local EventModeSystem = require("Game.EventModeSystem")

local tests = TestRunner.NewSuite("EventModeSystem")

-- ============================================================================
-- 测试：获取可用活动模式
-- ============================================================================
function tests.TestGetAvailableModes()
    local modes = EventModeSystem.GetAvailableModes()
    TestRunner.Assert(type(modes) == "table", "应该能获取活动模式列表")
    TestRunner.Assert(#modes > 0, "活动模式列表不应为空")

    for _, mode in ipairs(modes) do
        TestRunner.Assert(mode.id ~= nil, "活动模式应有ID")
        TestRunner.Assert(mode.name ~= nil, "活动模式应有名称")
    end

    print("[EventModeSystem] 可用活动模式测试通过 (数量: " .. #modes .. ")")
end

-- ============================================================================
-- 测试：判断是否为活动时间
-- ============================================================================
function tests.TestIsEventTime()
    local isEvent = EventModeSystem.IsEventTime()
    TestRunner.Assert(type(isEvent) == "boolean", "活动时间判断应返回布尔值")

    print("[EventModeSystem] 活动时间测试通过 (活动中: " .. tostring(isEvent) .. ")")
end

-- ============================================================================
-- 测试：获取当前活动模式
-- ============================================================================
function tests.TestGetCurrentMode()
    local mode = EventModeSystem.GetCurrentMode()
    TestRunner.Assert(type(mode) == "table" or mode == nil, "当前活动应该是table或nil")

    if mode ~= nil then
        TestRunner.Assert(mode.id ~= nil, "当前活动应有ID")
    end

    print("[EventModeSystem] 当前活动测试通过")
end

-- ============================================================================
-- 测试：获取当前活动ID
-- ============================================================================
function tests.TestGetCurrentModeId()
    local modeId = EventModeSystem.GetCurrentModeId()
    TestRunner.Assert(type(modeId) == "string" or modeId == nil, "活动ID应该是字符串或nil")

    print("[EventModeSystem] 当前活动ID测试通过 (ID: " .. tostring(modeId) .. ")")
end

-- ============================================================================
-- 测试：获取活动剩余时间
-- ============================================================================
function tests.TestGetEventTimeRemaining()
    local remaining = EventModeSystem.GetEventTimeRemaining()
    TestRunner.Assert(type(remaining) == "number" or type(remaining) == "string",
        "剩余时间应该是数字或字符串")

    print("[EventModeSystem] 剩余时间测试通过 (剩余: " .. tostring(remaining) .. ")")
end

-- ============================================================================
-- 测试：获取回合数配置
-- ============================================================================
function tests.TestGetRounds()
    local rounds = EventModeSystem.GetRounds()
    TestRunner.Assert(type(rounds) == "number", "回合数应该是数字")
    TestRunner.Assert(rounds > 0, "回合数应该大于0")

    print("[EventModeSystem] 回合数测试通过 (回合: " .. rounds .. ")")
end

-- ============================================================================
-- 测试：获取出价时间限制
-- ============================================================================
function tests.TestGetBidTimeLimit()
    local limit = EventModeSystem.GetBidTimeLimit()
    TestRunner.Assert(type(limit) == "number", "出价时间限制应该是数字")
    TestRunner.Assert(limit > 0, "出价时间限制应该大于0")

    print("[EventModeSystem] 出价时间限制测试通过 (秒: " .. limit .. ")")
end

-- ============================================================================
-- 测试：获取初始资金
-- ============================================================================
function tests.TestGetInitialFunds()
    local funds = EventModeSystem.GetInitialFunds()
    TestRunner.Assert(type(funds) == "number", "初始资金应该是数字")
    TestRunner.Assert(funds > 0, "初始资金应该大于0")

    print("[EventModeSystem] 初始资金测试通过 (金币: " .. funds .. ")")
end

-- ============================================================================
-- 测试：获取奖励加成
-- ============================================================================
function tests.TestGetRewardBonus()
    local bonus = EventModeSystem.GetRewardBonus()
    TestRunner.Assert(type(bonus) == "number", "奖励加成应该是数字")
    TestRunner.Assert(bonus >= 1.0, "奖励加成应该大于等于1.0")

    print("[EventModeSystem] 奖励加成测试通过 (加成: " .. bonus .. "x)")
end

-- ============================================================================
-- 测试：获取经验加成
-- ============================================================================
function tests.TestGetBonusExp()
    local exp = EventModeSystem.GetBonusExp()
    TestRunner.Assert(type(exp) == "number", "经验加成应该是数字")
    TestRunner.Assert(exp >= 0, "经验加成应该非负")

    print("[EventModeSystem] 经验加成测试通过 (加成: " .. exp .. ")")
end

-- ============================================================================
-- 测试：判断能否参与活动
-- ============================================================================
function tests.TestCanJoinEvent()
    local canJoin = EventModeSystem.CanJoinEvent()
    TestRunner.Assert(type(canJoin) == "boolean", "加入判断应返回布尔值")

    print("[EventModeSystem] 能否参与活动测试通过 (可参与: " .. tostring(canJoin) .. ")")
end

-- ============================================================================
-- 测试：获取活动状态
-- ============================================================================
function tests.TestGetEventStatus()
    local status = EventModeSystem.GetEventStatus()
    TestRunner.Assert(type(status) == "table", "活动状态应该是table")
    TestRunner.Assert(status.isActive ~= nil, "活动状态应有isActive字段")

    print("[EventModeSystem] 活动状态测试通过")
end

-- ============================================================================
-- 测试：完整活动配置获取
-- ============================================================================
function tests.TestFullEventConfig()
    local status = EventModeSystem.GetEventStatus()

    local config = {
        rounds = EventModeSystem.GetRounds(),
        bidTime = EventModeSystem.GetBidTimeLimit(),
        initialFunds = EventModeSystem.GetInitialFunds(),
        rewardBonus = EventModeSystem.GetRewardBonus(),
        bonusExp = EventModeSystem.GetBonusExp(),
        canJoin = EventModeSystem.CanJoinEvent(),
    }

    TestRunner.Assert(config.rounds > 0, "回合数配置有效")
    TestRunner.Assert(config.initialFunds > 0, "初始资金配置有效")
    TestRunner.Assert(config.rewardBonus >= 1.0, "奖励加成配置有效")

    print("[EventModeSystem] 完整活动配置测试通过")
end

-- ============================================================================
-- 运行所有测试
-- ============================================================================
TestRunner.Run(tests)
return tests
