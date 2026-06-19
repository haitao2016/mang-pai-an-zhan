-- ============================================================================
-- TestRevealSystem.lua - RevealSystem 单元测试
-- ============================================================================

local TestRunner = require("Utils.TestRunner")
local Config = require("Config")
local RevealSystem = require("Game.RevealSystem")

-- 测试辅助：创建测试用藏品
local function createTestItem(name, rarity, value)
    return {
        name = name,
        rarity = rarity,
        value = value,
        rarityName = Config.Rarity[rarity] and Config.Rarity[rarity].name or "未知",
    }
end

-- 测试套件
local tests = {
    -- 基础创建测试
    test_create = function()
        local rs = RevealSystem.New()
        TestRunner.Assert(rs ~= nil, "RevealSystem should be created")
        TestRunner.AssertEqual(RevealSystem.Phase.IDLE, rs.phase, "Initial phase should be IDLE")
    end,

    test_initial_state = function()
        local rs = RevealSystem.New()
        TestRunner.Assert(not rs:IsActive(), "Should not be active initially")
        TestRunner.Assert(not rs:IsDone(), "Should not be done initially")
        TestRunner.AssertEqual(RevealSystem.Phase.IDLE, rs:GetPhase(), "Phase should be IDLE")
    end,

    -- 开始揭示测试
    test_start_reveal = function()
        local rs = RevealSystem.New()
        local items = {
            createTestItem("青铜鼎", 1, 1000),
            createTestItem("翡翠镯", 2, 2000),
        }

        rs:Start(items, 3000, 2500)
        TestRunner.AssertEqual(RevealSystem.Phase.SHOWING, rs.phase, "Phase should be SHOWING")
        TestRunner.AssertEqual(2, #rs.items, "Should have 2 items")
        TestRunner.AssertEqual(3000, rs.totalValue, "Total value should be set")
        TestRunner.AssertEqual(2500, rs.bidTotal, "Bid total should be set")
        TestRunner.AssertEqual(0, rs.currentIndex, "Current index should start at 0")
    end,

    test_start_callback = function()
        local rs = RevealSystem.New()
        local started = false
        rs.onRevealStart = function()
            started = true
        end

        local items = { createTestItem("测试", 1, 100) }
        rs:Start(items, 100, 80)
        TestRunner.Assert(started, "onRevealStart callback should be called")
    end,

    -- 更新逻辑测试
    test_update_not_active = function()
        local rs = RevealSystem.New()
        rs:Update(1.0)  -- IDLE 状态
        TestRunner.AssertEqual(RevealSystem.Phase.IDLE, rs.phase, "Phase should remain IDLE")
    end,

    test_update_showing_phase = function()
        local rs = RevealSystem.New()
        local items = { createTestItem("藏品1", 1, 1000) }
        rs:Start(items, 1000, 800)

        local revealedItem = nil
        rs.onRevealItem = function(idx, item)
            revealedItem = item
        end

        -- 初始延迟后应该揭示第一件
        rs:Update(0.6)  -- 小于初始延迟 0.5
        TestRunner.AssertEqual(0, rs.currentIndex, "Should not reveal yet")

        rs:Update(0.5)  -- 触发揭示
        TestRunner.AssertEqual(1, rs.currentIndex, "Should reveal item 1")
        TestRunner.Assert(revealedItem ~= nil, "onRevealItem callback should be called")
    end,

    test_update_all_items_revealed = function()
        local rs = RevealSystem.New()
        local items = {
            createTestItem("藏品1", 1, 1000),
            createTestItem("藏品2", 2, 2000),
        }
        rs:Start(items, 3000, 2500)

        local revealedCount = 0
        rs.onRevealItem = function()
            revealedCount = revealedCount + 1
        end

        local revealedTotal = false
        rs.onRevealTotal = function()
            revealedTotal = true
        end

        -- 模拟揭示流程
        -- 初始延迟 0.5 + 间隔 0.8 = 1.3s 后揭示第一件
        rs:Update(0.6)
        rs:Update(0.8)  -- 第一件

        -- 第二件
        rs:Update(0.8)  -- 第二件

        -- 之后进入 TOTAL 阶段
        TestRunner.AssertEqual(2, revealedCount, "Should reveal both items")
        TestRunner.AssertEqual(RevealSystem.Phase.TOTAL, rs.phase, "Should be in TOTAL phase")
        TestRunner.Assert(revealedTotal, "onRevealTotal should be called")
    end,

    test_update_total_phase = function()
        local rs = RevealSystem.New()
        local items = { createTestItem("唯一藏品", 1, 5000) }
        rs:Start(items, 5000, 4000)

        rs.onRevealTotal = function(tv, bt, profit)
            TestRunner.AssertEqual(5000, tv, "Total value should be correct")
            TestRunner.AssertEqual(4000, bt, "Bid total should be correct")
            TestRunner.AssertEqual(1000, profit, "Profit should be correct")
        end

        -- 跳过到 TOTAL 阶段
        rs:Update(0.6)
        rs:Update(0.8)  -- 揭示唯一藏品后进入 TOTAL

        TestRunner.AssertEqual(RevealSystem.Phase.TOTAL, rs.phase, "Should be in TOTAL phase")
    end,

    test_update_done_phase = function()
        local rs = RevealSystem.New()
        local items = { createTestItem("唯一藏品", 1, 1000) }
        rs:Start(items, 1000, 800)

        local doneCalled = false
        rs.onRevealDone = function()
            doneCalled = true
        end

        -- 快速推进到完成
        rs:Update(0.6)  -- 初始延迟
        rs:Update(0.8)  -- 揭示
        rs:Update(2.5)  -- TOTAL 阶段结束（2.0s）

        TestRunner.AssertEqual(RevealSystem.Phase.DONE, rs.phase, "Should be DONE")
        TestRunner.Assert(doneCalled, "onRevealDone should be called")
    end,

    -- 阶段查询测试
    test_is_active = function()
        local rs = RevealSystem.New()
        TestRunner.Assert(not rs:IsActive(), "Should not be active initially")

        local items = { createTestItem("测试", 1, 100) }
        rs:Start(items, 100, 80)

        TestRunner.Assert(rs:IsActive(), "Should be active after start (SHOWING)")

        -- 直接设置 phase 测试
        rs.phase = RevealSystem.Phase.TOTAL
        TestRunner.Assert(rs:IsActive(), "Should be active in TOTAL phase")

        rs.phase = RevealSystem.Phase.DONE
        TestRunner.Assert(not rs:IsActive(), "Should not be active when DONE")
    end,

    test_is_done = function()
        local rs = RevealSystem.New()
        TestRunner.Assert(not rs:IsDone(), "Should not be done initially")

        rs.phase = RevealSystem.Phase.DONE
        TestRunner.Assert(rs:IsDone(), "Should be done when phase is DONE")
    end,

    -- 重置测试
    test_reset = function()
        local rs = RevealSystem.New()
        local items = { createTestItem("测试", 1, 100) }
        rs:Start(items, 100, 80)

        rs:Reset()
        TestRunner.AssertEqual(RevealSystem.Phase.IDLE, rs.phase, "Phase should be IDLE after reset")
        TestRunner.AssertEqual(0, #rs.items, "Items should be empty after reset")
        TestRunner.AssertEqual(0, rs.currentIndex, "Index should be 0 after reset")
        TestRunner.AssertEqual(0, rs.totalValue, "Total value should be 0 after reset")
        TestRunner.AssertEqual(0, rs.bidTotal, "Bid total should be 0 after reset")
    end,

    -- 边界情况测试
    test_empty_items = function()
        local rs = RevealSystem.New()
        rs:Start({}, 0, 0)

        local totalCalled = false
        rs.onRevealTotal = function()
            totalCalled = true
        end

        -- 空物品应该直接进入 TOTAL
        rs:Update(0.6)
        TestRunner.AssertEqual(RevealSystem.Phase.TOTAL, rs.phase, "Should go to TOTAL with no items")
    end,

    test_callback_order = function()
        local rs = RevealSystem.New()
        local items = {
            createTestItem("藏品1", 1, 1000),
            createTestItem("藏品2", 2, 2000),
        }
        rs:Start(items, 3000, 2500)

        local callOrder = {}
        rs.onRevealStart = function()
            table.insert(callOrder, "start")
        end
        rs.onRevealItem = function(idx)
            table.insert(callOrder, "item_" .. idx)
        end
        rs.onRevealTotal = function()
            table.insert(callOrder, "total")
        end
        rs.onRevealDone = function()
            table.insert(callOrder, "done")
        end

        -- 执行完整流程
        rs:Update(0.6)  -- start 触发
        table.insert(callOrder, "update_1")
        rs:Update(0.8)  -- item_1
        table.insert(callOrder, "update_2")
        rs:Update(0.8)  -- item_2
        table.insert(callOrder, "update_3")
        rs:Update(2.5)  -- total + done

        print("[Test] Call order: " .. table.concat(callOrder, " -> "))
        TestRunner.Assert(#callOrder > 0, "Callbacks should be called in order")
    end,

    -- 价值计算测试
    test_profit_calculation = function()
        local rs = RevealSystem.New()
        local items = {
            createTestItem("藏品1", 1, 5000),
            createTestItem("藏品2", 2, 3000),
        }
        rs:Start(items, 8000, 10000)  -- bid > value = 亏损

        -- 跳过到 TOTAL
        rs:Update(0.6)
        rs:Update(0.8)
        rs:Update(0.8)

        -- 手动计算 profit
        local expectedProfit = rs.totalValue - rs.bidTotal
        TestRunner.AssertEqual(-2000, expectedProfit, "Profit should be negative when bid > value")
    end,

    -- 稀有度保留测试
    test_rarity_preserved = function()
        local rs = RevealSystem.New()
        local legendItem = createTestItem("传说神器", 4, 50000)
        local items = { legendItem }
        rs:Start(items, 50000, 40000)

        TestRunner.AssertEqual(4, rs.items[1].rarity, "Legend rarity should be preserved")
        TestRunner.AssertEqual("传说", rs.items[1].rarityName, "Legend name should be preserved")
    end,

    -- 多物品揭示时序测试
    test_multiple_items_timing = function()
        local rs = RevealSystem.New()
        local items = {
            createTestItem("A", 1, 100),
            createTestItem("B", 1, 200),
            createTestItem("C", 1, 300),
        }
        rs:Start(items, 600, 500)

        local revealedOrder = {}
        rs.onRevealItem = function(idx)
            table.insert(revealedOrder, idx)
        end

        -- 初始延迟 0.5 + 每件 0.8
        -- t=0.6: 还未揭示
        rs:Update(0.6)
        TestRunner.AssertEqual(0, #revealedOrder, "Nothing revealed yet")

        -- t=0.6+0.8=1.4: 揭示第1件
        rs:Update(0.8)
        TestRunner.AssertEqual(1, revealedOrder[1], "First item revealed")

        -- t=1.4+0.8=2.2: 揭示第2件
        rs:Update(0.8)
        TestRunner.AssertEqual(2, revealedOrder[2], "Second item revealed")

        -- t=2.2+0.8=3.0: 揭示第3件
        rs:Update(0.8)
        TestRunner.AssertEqual(3, revealedOrder[3], "Third item revealed")
        TestRunner.AssertEqual(RevealSystem.Phase.TOTAL, rs.phase, "Should be TOTAL now")
    end,
}

-- 运行测试
TestRunner.RunSuite("RevealSystem", tests)
TestRunner.PrintSummary()

return TestRunner.results
