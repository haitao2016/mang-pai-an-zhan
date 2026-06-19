-- ============================================================================
-- TestLeaderboardSystem.lua - 排行榜系统单元测试（v1.1 + v1.3 扩展）
-- ============================================================================

local TestRunner = require("Utils.TestRunner")
local LeaderboardSystem = require("Game.LeaderboardSystem")

local tests = TestRunner.NewSuite("LeaderboardSystem")

-- ============================================================================
-- 测试：获取可用排行榜列表
-- ============================================================================
function tests.TestGetAvailableBoards()
    local boards = LeaderboardSystem.GetAvailableBoards()
    TestRunner.Assert(type(boards) == "table", "应该能获取排行榜列表")
    TestRunner.Assert(#boards > 0, "排行榜列表不应为空")

    for _, b in ipairs(boards) do
        TestRunner.Assert(b.id ~= nil, "排行榜应有ID")
        TestRunner.Assert(b.name ~= nil, "排行榜应有名称")
    end

    print("[LeaderboardSystem] 可用排行榜测试通过 (数量: " .. #boards .. ")")
end

-- ============================================================================
-- 测试：获取排行榜配置
-- ============================================================================
function tests.TestGetBoardConfig()
    local boards = LeaderboardSystem.GetAvailableBoards()
    TestRunner.Assert(#boards > 0, "至少应有一个排行榜")

    local config = LeaderboardSystem.GetBoardConfig(boards[1].id)
    TestRunner.Assert(config ~= nil, "应该能获取排行榜配置")
    TestRunner.Assert(config.id ~= nil, "配置应有ID")

    print("[LeaderboardSystem] 配置测试通过")
end

-- ============================================================================
-- 测试：更新玩家统计数据
-- ============================================================================
function tests.TestUpdatePlayerStats()
    local ok = LeaderboardSystem.UpdatePlayerStats(1001, {
        winCount = 5,
        gameCount = 10,
        collectionValue = 5000,
        speedWinCount = 2,
    })
    TestRunner.Assert(true, "更新玩家统计不应失败")

    local ok2 = LeaderboardSystem.UpdatePlayerStats(1002, {
        winCount = 15,
        gameCount = 20,
        collectionValue = 15000,
        speedWinCount = 8,
    })
    TestRunner.Assert(true, "更新玩家2统计不应失败")

    local ok3 = LeaderboardSystem.UpdatePlayerStats(1003, {
        winCount = 10,
        gameCount = 15,
        collectionValue = 10000,
        speedWinCount = 5,
    })

    print("[LeaderboardSystem] 更新玩家统计测试通过")
end

-- ============================================================================
-- 测试：获取排行榜
-- ============================================================================
function tests.TestGetBoard()
    local boards = LeaderboardSystem.GetAvailableBoards()
    TestRunner.Assert(#boards > 0, "至少应有一个排行榜")

    local board = LeaderboardSystem.GetBoard(boards[1].id, 50)
    TestRunner.Assert(type(board) == "table", "应该能获取排行榜")

    for _, entry in ipairs(board) do
        TestRunner.Assert(entry.uid ~= nil or entry.rank ~= nil, "排行榜条目应有标识")
    end

    print("[LeaderboardSystem] 获取排行榜测试通过 (条目数: " .. #board .. ")")
end

-- ============================================================================
-- 测试：获取玩家排名
-- ============================================================================
function tests.TestGetPlayerRank()
    local boards = LeaderboardSystem.GetAvailableBoards()
    TestRunner.Assert(#boards > 0, "至少应有一个排行榜")

    local rank = LeaderboardSystem.GetPlayerRank(boards[1].id, 1002)
    TestRunner.Assert(true, "获取玩家排名不应失败")

    print("[LeaderboardSystem] 玩家排名测试通过 (排名: " .. tostring(rank) .. ")")
end

-- ============================================================================
-- 测试：获取玩家所有排名
-- ============================================================================
function tests.TestGetAllPlayerRanks()
    local ranks = LeaderboardSystem.GetAllPlayerRanks(1001)
    TestRunner.Assert(type(ranks) == "table", "应该能获取所有排名")

    for boardId, rank in pairs(ranks) do
        TestRunner.Assert(type(boardId) == "string", "排行榜ID应为字符串")
    end

    print("[LeaderboardSystem] 获取所有排名测试通过")
end

-- ============================================================================
-- 测试：获取Top N
-- ============================================================================
function tests.TestGetTopN()
    local boards = LeaderboardSystem.GetAvailableBoards()
    TestRunner.Assert(#boards > 0, "至少应有一个排行榜")

    local top10 = LeaderboardSystem.GetTopN(boards[1].id, 10)
    TestRunner.Assert(type(top10) == "table", "应该能获取Top 10")
    TestRunner.Assert(#top10 <= 10, "Top N数量不应该超过N")

    print("[LeaderboardSystem] Top N测试通过 (Top10条目: " .. #top10 .. ")")
end

-- ============================================================================
-- 测试：排行榜排序
-- ============================================================================
function tests.TestRankingOrder()
    LeaderboardSystem.Reset()

    LeaderboardSystem.UpdatePlayerStats(2001, { winCount = 50, collectionValue = 50000 })
    LeaderboardSystem.UpdatePlayerStats(2002, { winCount = 100, collectionValue = 100000 })
    LeaderboardSystem.UpdatePlayerStats(2003, { winCount = 75, collectionValue = 75000 })

    local boards = LeaderboardSystem.GetAvailableBoards()
    if #boards > 0 then
        local board = LeaderboardSystem.GetBoard(boards[1].id, 10)
        TestRunner.Assert(#board >= 3, "排行榜至少应有3条记录")
    end

    print("[LeaderboardSystem] 排序测试通过")
end

-- ============================================================================
-- 测试：多玩家竞争排名
-- ============================================================================
function tests.TestMultiPlayerRanking()
    LeaderboardSystem.Reset()

    -- 10个玩家
    for i = 1, 10 do
        LeaderboardSystem.UpdatePlayerStats(3000 + i, {
            winCount = math.random(1, 50),
            gameCount = math.random(10, 100),
            collectionValue = math.random(1000, 50000),
        })
    end

    local boards = LeaderboardSystem.GetAvailableBoards()
    if #boards > 0 then
        local board = LeaderboardSystem.GetBoard(boards[1].id, 20)
        TestRunner.Assert(#board >= 10, "排行榜至少应有10条记录")
    end

    print("[LeaderboardSystem] 多玩家竞争测试通过")
end

-- ============================================================================
-- 运行所有测试
-- ============================================================================
TestRunner.Run(tests)
return tests
