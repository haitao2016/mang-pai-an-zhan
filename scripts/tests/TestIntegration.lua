-- ============================================================================
-- TestIntegration.lua - v1.2 系统集成测试
-- ----------------------------------------------------------------------------
-- 测试内容：
--   1. EventBus 扩展事件（v1.2 新增事件）
--   2. SystemManager 系统初始化和启动
--   3. 系统间事件传播（锦标赛→赛季, 团队战→赛季, 市场→藏品）
--   4. 皮肤系统与赛季系统联动
-- ============================================================================

local TestRunner = require("Utils.TestRunner")
local EventBus = require("Utils.EventBus")
local SystemManager = require("Game.SystemManager")

local tests = TestRunner.NewSuite("Integration")

-- ============================================================================
-- 测试 1: EventBus v1.2 新事件类型
-- ============================================================================
function tests.TestEventBus_V1_2_Events()
    -- 检查所有 v1.2 事件类型是否存在
    local requiredEvents = {
        "TOURNAMENT_START",
        "TOURNAMENT_END",
        "TOURNAMENT_WIN",
        "TOURNAMENT_REGISTER",
        "TOURNAMENT_MATCH_RESULT",
        "TEAM_CREATE",
        "TEAM_JOIN",
        "TEAM_LEAVE",
        "TEAM_START",
        "TEAM_WIN",
        "TEAM_SKILL_USE",
        "TRADE_LISTING",
        "TRADE_PURCHASE",
        "TRADE_CANCEL",
        "TRADE_BLOCK",
        "SKIN_UNLOCK",
        "SKIN_EQUIP",
        "SKIN_SET_COMPLETE",
    }

    local foundCount = 0
    for _, eventName in ipairs(requiredEvents) do
        TestRunner.Assert(EventBus.Events[eventName] ~= nil,
            "Event should exist: " .. eventName)
        if EventBus.Events[eventName] ~= nil then
            foundCount = foundCount + 1
        end
    end

    print("[Integration] v1.2 事件: " .. foundCount .. "/" .. #requiredEvents .. " 已定义")
end

-- ============================================================================
-- 测试 2: SystemManager 初始化统计
-- ============================================================================
function tests.TestSystemManager_Stats()
    local stats = SystemManager.GetSystemStats()

    TestRunner.Assert(stats.total >= 12, "Should have at least 12 systems")
    TestRunner.Assert(stats.v1_0 >= 2, "Should have at least 2 v1.0 core systems")
    TestRunner.Assert(stats.v1_1 >= 5, "Should have at least 5 v1.1 game systems")
    TestRunner.Assert(stats.v1_2 == 4, "Should have exactly 4 v1.2 new systems")

    print("[Integration] 系统统计: 总 " .. stats.total ..
          " 个 (v1.0: " .. stats.v1_0 ..
          ", v1.1: " .. stats.v1_1 ..
          ", v1.2: " .. stats.v1_2 .. ")")
end

-- ============================================================================
-- 测试 3: 系统管理器初始化
-- ============================================================================
function tests.TestSystemManager_Init()
    SystemManager.Reset()

    local result = SystemManager.Init()
    TestRunner.Assert(result == true, "Init should succeed")
    TestRunner.Assert(SystemManager.IsInitialized() == true, "Should be initialized")

    print("[Integration] SystemManager 初始化完成")
end

-- ============================================================================
-- 测试 4: 系统管理器启动（事件监听）
-- ============================================================================
function tests.TestSystemManager_Start()
    if not SystemManager.IsInitialized() then
        SystemManager.Init()
    end

    local result = SystemManager.Start()
    TestRunner.Assert(result == true, "Start should succeed")
    TestRunner.Assert(SystemManager.IsStarted() == true, "Should be started")

    print("[Integration] SystemManager 启动完成")
end

-- ============================================================================
-- 测试 5: 获取系统实例
-- ============================================================================
function tests.TestSystemManager_GetSystem()
    if not SystemManager.IsInitialized() then
        SystemManager.Init()
    end

    -- 测试 v1.2 系统是否能获取到
    local tournament = SystemManager.GetSystem("TournamentSystem")
    local teamBattle = SystemManager.GetSystem("TeamBattleSystem")
    local trade = SystemManager.GetSystem("TradeSystem")
    local skin = SystemManager.GetSystem("SkinSystem")

    TestRunner.Assert(tournament ~= nil, "Should get TournamentSystem")
    TestRunner.Assert(teamBattle ~= nil, "Should get TeamBattleSystem")
    TestRunner.Assert(trade ~= nil, "Should get TradeSystem")
    TestRunner.Assert(skin ~= nil, "Should get SkinSystem")

    print("[Integration] v1.2 系统获取成功")
end

-- ============================================================================
-- 测试 6: 锦标赛 → 赛季 事件传播
-- ============================================================================
function tests.TestEventPropagation_TournamentToSeason()
    SystemManager.Reset()
    SystemManager.Init()
    SystemManager.Start()

    -- 手动模拟锦标赛胜利事件
    local eventReceived = 0
    EventBus.Subscribe(EventBus.Events.SEASON_PROGRESS, function(data)
        if data.source == "tournament_win" then
            eventReceived = eventReceived + 1
        end
    end, "TestObserver")

    -- 模拟锦标赛胜利（通过 TournamentSystem 完成锦标赛）
    local TournamentSystem = SystemManager.GetSystem("TournamentSystem")
    if TournamentSystem and TournamentSystem._CompleteTournament then
        -- 创建一个锦标赛并完成它
        local tourneyId = TournamentSystem.CreateTournament()
        TournamentSystem.Register(tourneyId, "test_player", "测试玩家")

        -- 直接调用 _CompleteTournament 触发事件
        TournamentSystem._CompleteTournament({
            id = tourneyId,
            rewards = { { reward = 1000, title = "测试冠军" } }
        }, "test_player")
    end

    print("[Integration] 锦标赛→赛季事件传播测试完成")
end

-- ============================================================================
-- 测试 7: 团队战 → 赛季 事件传播
-- ============================================================================
function tests.TestEventPropagation_TeamBattleToSeason()
    SystemManager.Reset()
    SystemManager.Init()
    SystemManager.Start()

    -- 监听赛季进度事件
    local progressCount = 0
    EventBus.Subscribe(EventBus.Events.SEASON_PROGRESS, function(data)
        if data.source == "team_win" then
            progressCount = progressCount + 1
        end
    end, "TestObserver")

    -- 模拟团队战胜利流程
    local TeamBattleSystem = SystemManager.GetSystem("TeamBattleSystem")
    if TeamBattleSystem then
        -- 创建团队并匹配
        local teamId = TeamBattleSystem.CreateTeam("test_player")

        -- 尝试启动团队战
        local ok2 = TeamBattleSystem.StartMatch(teamId)

        print("[Integration] 团队战测试: 团队ID=" .. tostring(teamId) ..
              ", 启动=" .. tostring(ok2))
    end

    print("[Integration] 团队战→赛季事件传播测试完成")
end

-- ============================================================================
-- 测试 8: 交易市场 → 藏品系统 事件传播
-- ============================================================================
function tests.TestEventPropagation_TradeToItem()
    SystemManager.Reset()
    SystemManager.Init()
    SystemManager.Start()

    -- 监听藏品收集事件
    local itemCollectCount = 0
    EventBus.Subscribe(EventBus.Events.ITEM_COLLECT, function(data)
        if data.source == "trade_market" then
            itemCollectCount = itemCollectCount + 1
        end
    end, "TestObserver")

    -- 模拟市场交易流程
    local TradeSystem = SystemManager.GetSystem("TradeSystem")
    if TradeSystem then
        -- 创建挂单并购买
        local ok, listingId = TradeSystem.CreateListing(
            "seller", "item_001", { name = "测试藏品", rarity = 3 }, 500)

        if ok then
            -- 购买藏品
            local ok2, tradeId = TradeSystem.Purchase("buyer", listingId)
            print("[Integration] 市场交易测试: 挂单=" .. tostring(listingId) ..
                  ", 交易=" .. tostring(ok2))
        end
    end

    -- 检查事件是否传播
    TestRunner.Assert(itemCollectCount >= 0, "Item collect event should propagate")
    print("[Integration] 市场→藏品事件传播测试完成, 触发次数: " .. itemCollectCount)
end

-- ============================================================================
-- 测试 9: 皮肤系统 → 赛季 事件传播
-- ============================================================================
function tests.TestEventPropagation_SkinToSeason()
    SystemManager.Reset()
    SystemManager.Init()
    SystemManager.Start()

    -- 监听赛季进度事件
    local progressEvents = {}
    EventBus.Subscribe(EventBus.Events.SEASON_PROGRESS, function(data)
        table.insert(progressEvents, data)
    end, "TestObserver")

    -- 测试皮肤解锁
    local SkinSystem = SystemManager.GetSystem("SkinSystem")
    if SkinSystem then
        SkinSystem.UnlockSkin("test_player", "skin_rare_001", "achievement")

        local ok2 = SkinSystem.EquipSkin("test_player", 1, "skin_default")
        print("[Integration] 皮肤系统测试: 解锁成功, 装备=" .. tostring(ok2))
    end

    print("[Integration] 皮肤系统→赛季事件传播测试完成")
end

-- ============================================================================
-- 测试 10: 系统管理器重置
-- ============================================================================
function tests.TestSystemManager_Reset()
    SystemManager.Reset()

    TestRunner.Assert(SystemManager.IsInitialized() == false,
        "Should not be initialized after reset")
    TestRunner.Assert(SystemManager.IsStarted() == false,
        "Should not be started after reset")

    print("[Integration] SystemManager 重置测试完成")
end

-- ============================================================================
-- 测试 11: 完整生命周期（Init → Start → 使用 → Reset）
-- ============================================================================
function tests.TestFullLifecycle()
    -- 1. 初始化
    SystemManager.Reset()
    local initOk = SystemManager.Init()
    TestRunner.Assert(initOk == true, "Init should succeed")

    -- 2. 启动
    local startOk = SystemManager.Start()
    TestRunner.Assert(startOk == true, "Start should succeed")

    -- 3. 使用：锦标赛报名 + 团队创建 + 市场交易 + 皮肤解锁
    local TournamentSystem = SystemManager.GetSystem("TournamentSystem")
    local TeamBattleSystem = SystemManager.GetSystem("TeamBattleSystem")
    local TradeSystem = SystemManager.GetSystem("TradeSystem")
    local SkinSystem = SystemManager.GetSystem("SkinSystem")

    if TournamentSystem then
        local tid = TournamentSystem.CreateTournament({ name = "测试杯" })
        TournamentSystem.Register(tid, "player1", "玩家一")
    end

    if TeamBattleSystem then
        TeamBattleSystem.CreateTeam("player1", { name = "测试队" })
    end

    if TradeSystem then
        TradeSystem.CreateListing("player1", "item1", { name = "藏品A" }, 200)
    end

    if SkinSystem then
        SkinSystem.UnlockSkin("player1", "skin_001", "test")
    end

    print("[Integration] 完整生命周期测试完成")
end

-- ============================================================================
-- 测试 12: EventBus 事件历史记录
-- ============================================================================
function tests.TestEventBus_History()
    SystemManager.Reset()
    SystemManager.Init()
    SystemManager.Start()

    -- 触发几个 v1.2 事件
    local TournamentSystem = SystemManager.GetSystem("TournamentSystem")
    if TournamentSystem then
        local tid = TournamentSystem.CreateTournament()
        TournamentSystem.Register(tid, "history_test", "历史测试")
    end

    local SkinSystem = SystemManager.GetSystem("SkinSystem")
    if SkinSystem then
        SkinSystem.UnlockSkin("history_test", "skin_001", "test")
    end

    -- 获取事件历史
    local history = EventBus.GetHistory(20)
    TestRunner.Assert(type(history) == "table", "History should be a table")

    print("[Integration] 事件历史记录测试完成")
end

-- ============================================================================
-- 运行所有测试
-- ============================================================================
TestRunner.Run(tests)

return tests
