-- ============================================================================
-- TestTournamentSystem.lua - 锦标赛系统单元测试
-- ============================================================================

local TestRunner = require("Utils.TestRunner")
local TournamentSystem = require("Game.TournamentSystem")

local tests = TestRunner.NewSuite("TournamentSystem")

-- ============================================================================
-- 测试：创建锦标赛
-- ============================================================================
function tests.TestCreateTournament()
    TournamentSystem.Reset()

    local tournamentId = TournamentSystem.CreateTournament({
        name = "测试锦标赛",
        maxPlayers = 8,
        entryFee = 100,
        prize = 5000
    })

    TestRunner.Assert(type(tournamentId) == "string", "Should return tournament ID")
    TestRunner.Assert(string.match(tournamentId, "^TRN_"), "Tournament ID should start with TRN_")

    local bracket = TournamentSystem.GetBracket(tournamentId)
    TestRunner.Assert(bracket ~= nil, "Should get bracket")
    TestRunner.Assert(bracket.name == "测试锦标赛", "Should have correct name")
    TestRunner.Assert(bracket.maxPlayers == 8, "Should have correct max players")

    print("[TournamentSystem] 创建锦标赛: " .. tournamentId)
end

-- ============================================================================
-- 测试：报名参加锦标赛
-- ============================================================================
function tests.TestRegister()
    TournamentSystem.Reset()

    local tournamentId = TournamentSystem.CreateTournament({
        maxPlayers = 8,
        entryFee = 0
    })

    local ok, err = TournamentSystem.Register(tournamentId, "player1", "玩家一")
    TestRunner.Assert(ok == true, "First registration should succeed")

    local ok2, err2 = TournamentSystem.Register(tournamentId, "player1", "玩家一")
    TestRunner.Assert(ok2 == false, "Duplicate registration should fail")
    TestRunner.Assert(err2 == "already_registered", "Should return already_registered error")

    local bracket = TournamentSystem.GetBracket(tournamentId)
    TestRunner.Assert(bracket.playerCount == 1, "Player count should be 1")

    print("[TournamentSystem] 报名测试完成")
end

-- ============================================================================
-- 测试：8人锦标赛对阵生成
-- ============================================================================
function tests.TestBracketGeneration()
    TournamentSystem.Reset()

    local tournamentId = TournamentSystem.CreateTournament({
        name = "8人锦标赛",
        maxPlayers = 8
    })

    -- 模拟8人报名
    for i = 1, 8 do
        TournamentSystem.Register(tournamentId, "player" .. i, "玩家" .. i)
    end

    local bracket = TournamentSystem.GetBracket(tournamentId)
    TestRunner.Assert(bracket.status == "in_progress", "Tournament should be in progress")
    TestRunner.Assert(bracket.currentRound == 1, "Should start at round 1")
    TestRunner.Assert(#bracket.rounds[1].matches == 4, "Round 1 should have 4 matches")

    print("[TournamentSystem] 对阵生成: 4场比赛/轮")
end

-- ============================================================================
-- 测试：提交比赛结果
-- ============================================================================
function tests.TestSubmitMatchResult()
    TournamentSystem.Reset()

    local tournamentId = TournamentSystem.CreateTournament({
        maxPlayers = 8
    })

    for i = 1, 8 do
        TournamentSystem.Register(tournamentId, "player" .. i, "玩家" .. i)
    end

    local bracket = TournamentSystem.GetBracket(tournamentId)
    local round1Matches = bracket.rounds[1].matches

    -- 第一轮第1场
    local match1 = round1Matches[1]
    local winner1 = match1.player1.uid
    local ok, err = TournamentSystem.SubmitMatchResult(tournamentId, match1.id, winner1)
    TestRunner.Assert(ok == true, "Should submit result successfully")

    -- 获取更新后的对阵
    local updatedBracket = TournamentSystem.GetBracket(tournamentId)
    local completedCount = 0
    for _, m in ipairs(updatedBracket.rounds[1].matches) do
        if m.status == "completed" then
            completedCount = completedCount + 1
        end
    end
    TestRunner.Assert(completedCount == 1, "One match should be completed")

    print("[TournamentSystem] 比赛结果提交测试完成")
end

-- ============================================================================
-- 测试：获取可参加的锦标赛
-- ============================================================================
function tests.TestGetAvailableTournaments()
    TournamentSystem.Reset()

    -- 创建两个锦标赛
    local id1 = TournamentSystem.CreateTournament({ name = "锦标赛A" })
    local id2 = TournamentSystem.CreateTournament({ name = "锦标赛B" })

    -- 第一个报名满8人后自动开始
    for i = 1, 8 do
        TournamentSystem.Register(id1, "p1_" .. i, "玩家" .. i)
    end

    local available = TournamentSystem.GetAvailableTournaments("new_player")
    TestRunner.Assert(#available >= 1, "Should have available tournaments")

    local found = false
    for _, t in ipairs(available) do
        if t.name == "锦标赛A" then
            found = true
            TestRunner.Assert(t.alreadyRegistered == false, "Should not be registered")
        end
    end

    print("[TournamentSystem] 可参加锦标赛数: " .. #available)
end

-- ============================================================================
-- 测试：玩家历史记录
-- ============================================================================
function tests.TestGetPlayerHistory()
    TournamentSystem.Reset()

    local tournamentId = TournamentSystem.CreateTournament({
        maxPlayers = 8,
        prize = 10000
    })

    -- 玩家1报名并完成比赛
    TournamentSystem.Register(tournamentId, "player_history", "历史玩家")
    for i = 2, 8 do
        TournamentSystem.Register(tournamentId, "player" .. i, "玩家" .. i)
    end

    local history = TournamentSystem.GetPlayerHistory("player_history")
    TestRunner.Assert(#history >= 1, "Should have history record")

    local latest = history[#history]
    TestRunner.Assert(latest.tournamentId == tournamentId, "Should have correct tournament ID")

    print("[TournamentSystem] 历史记录测试完成")
end

-- ============================================================================
-- 测试：锦标赛奖励信息
-- ============================================================================
function tests.TestGetRewards()
    TournamentSystem.Reset()

    local tournamentId = TournamentSystem.CreateTournament({
        prize = 10000
    })

    local rewards = TournamentSystem.GetRewards(tournamentId)
    TestRunner.Assert(rewards ~= nil, "Should return rewards")
    TestRunner.Assert(#rewards == 3, "Should have 3 reward tiers")

    TestRunner.Assert(rewards[1].place == 1, "First place should be 1")
    TestRunner.Assert(rewards[1].reward == 10000, "Champion reward should be 10000")
    TestRunner.Assert(rewards[2].reward == 5000, "Runner-up reward should be 5000")

    print("[TournamentSystem] 奖励配置: 冠军=" .. rewards[1].reward .. ", 亚军=" .. rewards[2].reward)
end

-- ============================================================================
-- 测试：获取玩家当前比赛
-- ============================================================================
function tests.TestGetPlayerMatch()
    TournamentSystem.Reset()

    local tournamentId = TournamentSystem.CreateTournament({
        maxPlayers = 8
    })

    for i = 1, 8 do
        TournamentSystem.Register(tournamentId, "player" .. i, "玩家" .. i)
    end

    local match = TournamentSystem.GetPlayerMatch(tournamentId, "player1")
    TestRunner.Assert(match ~= nil, "Should return player's match")
    TestRunner.Assert(match.round == 1, "Should be round 1")

    print("[TournamentSystem] 玩家比赛查询测试完成")
end

-- ============================================================================
-- 测试：取消锦标赛
-- ============================================================================
function tests.TestCancelTournament()
    TournamentSystem.Reset()

    local tournamentId = TournamentSystem.CreateTournament({
        entryFee = 100
    })

    local ok, err = TournamentSystem.CancelTournament(tournamentId)
    TestRunner.Assert(ok == true, "Should cancel successfully")

    local bracket = TournamentSystem.GetBracket(tournamentId)
    TestRunner.Assert(bracket.status == "cancelled", "Status should be cancelled")

    print("[TournamentSystem] 锦标赛取消测试完成")
end

-- ============================================================================
-- 运行所有测试
-- ============================================================================
TestRunner.Run(tests)

return tests
