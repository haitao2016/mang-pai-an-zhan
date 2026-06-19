-- ============================================================================
-- TestTeamBattleSystem.lua - 2v2 团队战系统单元测试
-- ============================================================================

local TestRunner = require("Utils.TestRunner")
local TeamBattleSystem = require("Game.TeamBattleSystem")

local tests = TestRunner.NewSuite("TeamBattleSystem")

-- ============================================================================
-- 测试：创建团队
-- ============================================================================
function tests.TestCreateTeam()
    TeamBattleSystem.Reset()

    local teamId = TeamBattleSystem.CreateTeam("player1", {
        name = "测试团队",
        tag = "TEST"
    })

    TestRunner.Assert(type(teamId) == "string", "Should return team ID")
    TestRunner.Assert(string.match(teamId, "^TEAM_"), "Team ID should start with TEAM_")

    local info = TeamBattleSystem.GetTeamInfo(teamId)
    TestRunner.Assert(info.name == "测试团队", "Should have correct name")
    TestRunner.Assert(info.tag == "TEST", "Should have correct tag")
    TestRunner.Assert(info.memberCount == 1, "Should have 1 member")

    print("[TeamBattleSystem] 创建团队: " .. teamId)
end

-- ============================================================================
-- 测试：邀请玩家
-- ============================================================================
function tests.TestInviteToTeam()
    TeamBattleSystem.Reset()

    local teamId = TeamBattleSystem.CreateTeam("player1")

    local ok, err = TeamBattleSystem.InviteToTeam(teamId, "player1", "player2")
    TestRunner.Assert(ok == true, "Invite should succeed")

    -- 重复邀请应失败
    local ok2, err2 = TeamBattleSystem.InviteToTeam(teamId, "player1", "player2")
    TestRunner.Assert(ok2 == false, "Duplicate invite should fail")

    print("[TeamBattleSystem] 邀请测试完成")
end

-- ============================================================================
-- 测试：加入团队
-- ============================================================================
function tests.TestJoinTeam()
    TeamBattleSystem.Reset()

    local teamId = TeamBattleSystem.CreateTeam("player1")

    local ok, err = TeamBattleSystem.JoinTeam(teamId, "player2")
    TestRunner.Assert(ok == true, "Join should succeed")

    local info = TeamBattleSystem.GetTeamInfo(teamId)
    TestRunner.Assert(info.memberCount == 2, "Should have 2 members")

    print("[TeamBattleSystem] 加入团队测试完成")
end

-- ============================================================================
-- 测试：离开团队
-- ============================================================================
function tests.TestLeaveTeam()
    TeamBattleSystem.Reset()

    local teamId = TeamBattleSystem.CreateTeam("player1")
    TeamBattleSystem.JoinTeam(teamId, "player2")

    local ok = TeamBattleSystem.LeaveTeam("player2")
    TestRunner.Assert(ok == true, "Leave should succeed")

    local info = TeamBattleSystem.GetTeamInfo(teamId)
    TestRunner.Assert(info.memberCount == 1, "Should have 1 member")

    print("[TeamBattleSystem] 离开团队测试完成")
end

-- ============================================================================
-- 测试：获取玩家团队
-- ============================================================================
function tests.TestGetPlayerTeam()
    TeamBattleSystem.Reset()

    local teamId = TeamBattleSystem.CreateTeam("player1")
    TeamBattleSystem.JoinTeam(teamId, "player2")

    local team = TeamBattleSystem.GetPlayerTeam("player1")
    TestRunner.Assert(team ~= nil, "Should return team")
    TestRunner.Assert(team.id == teamId, "Should have correct team ID")

    local noTeam = TeamBattleSystem.GetPlayerTeam("player999")
    TestRunner.Assert(noTeam == nil, "Should return nil for non-member")

    print("[TeamBattleSystem] 获取团队测试完成")
end

-- ============================================================================
-- 测试：创建团队战匹配
-- ============================================================================
function tests.TestCreateMatch()
    TeamBattleSystem.Reset()

    -- 创建两支完整团队
    local team1Id = TeamBattleSystem.CreateTeam("red1")
    TeamBattleSystem.JoinTeam(team1Id, "red2")

    local team2Id = TeamBattleSystem.CreateTeam("blue1")
    TeamBattleSystem.JoinTeam(team2Id, "blue2")

    local ok, matchId = TeamBattleSystem.CreateMatch(team1Id, team2Id)
    TestRunner.Assert(ok == true, "Match creation should succeed")
    TestRunner.Assert(type(matchId) == "string", "Should return match ID")

    print("[TeamBattleSystem] 创建匹配: " .. matchId)
end

-- ============================================================================
-- 测试：开始团队战
-- ============================================================================
function tests.TestStartMatch()
    TeamBattleSystem.Reset()

    local team1Id = TeamBattleSystem.CreateTeam("red1")
    TeamBattleSystem.JoinTeam(team1Id, "red2")

    local team2Id = TeamBattleSystem.CreateTeam("blue1")
    TeamBattleSystem.JoinTeam(team2Id, "blue2")

    local _, matchId = TeamBattleSystem.CreateMatch(team1Id, team2Id)

    local ok = TeamBattleSystem.StartMatch(matchId)
    TestRunner.Assert(ok == true, "Start should succeed")

    print("[TeamBattleSystem] 开始匹配测试完成")
end

-- ============================================================================
-- 测试：提交出价
-- ============================================================================
function tests.TestSubmitTeamBid()
    TeamBattleSystem.Reset()

    local team1Id = TeamBattleSystem.CreateTeam("red1")
    TeamBattleSystem.JoinTeam(team1Id, "red2")

    local team2Id = TeamBattleSystem.CreateTeam("blue1")
    TeamBattleSystem.JoinTeam(team2Id, "blue2")

    local _, matchId = TeamBattleSystem.CreateMatch(team1Id, team2Id)
    TeamBattleSystem.StartMatch(matchId)

    local ok = TeamBattleSystem.SubmitTeamBid(matchId, "red1", 100)
    TestRunner.Assert(ok == true, "Bid should succeed")

    local ok2 = TeamBattleSystem.SubmitTeamBid(matchId, "blue1", 150)
    TestRunner.Assert(ok2 == true, "Bid should succeed")

    print("[TeamBattleSystem] 出价测试完成")
end

-- ============================================================================
-- 测试：结算回合
-- ============================================================================
function tests.TestSettleRound()
    TeamBattleSystem.Reset()

    local team1Id = TeamBattleSystem.CreateTeam("red1")
    TeamBattleSystem.JoinTeam(team1Id, "red2")

    local team2Id = TeamBattleSystem.CreateTeam("blue1")
    TeamBattleSystem.JoinTeam(team2Id, "blue2")

    local _, matchId = TeamBattleSystem.CreateMatch(team1Id, team2Id)
    TeamBattleSystem.StartMatch(matchId)

    -- 双方出价
    TeamBattleSystem.SubmitTeamBid(matchId, "red1", 100)
    TeamBattleSystem.SubmitTeamBid(matchId, "red2", 50)
    TeamBattleSystem.SubmitTeamBid(matchId, "blue1", 120)
    TeamBattleSystem.SubmitTeamBid(matchId, "blue2", 30)

    local ok = TeamBattleSystem.SettleRound(matchId)
    TestRunner.Assert(ok == true, "Settle should succeed")

    print("[TeamBattleSystem] 回合结算测试完成")
end

-- ============================================================================
-- 测试：使用团队技能
-- ============================================================================
function tests.TestUseTeamSkill()
    TeamBattleSystem.Reset()

    local team1Id = TeamBattleSystem.CreateTeam("red1")
    TeamBattleSystem.JoinTeam(team1Id, "red2")

    local team2Id = TeamBattleSystem.CreateTeam("blue1")
    TeamBattleSystem.JoinTeam(team2Id, "blue2")

    local _, matchId = TeamBattleSystem.CreateMatch(team1Id, team2Id)
    TeamBattleSystem.StartMatch(matchId)

    local ok = TeamBattleSystem.UseTeamSkill(matchId, "red1", "team_boost")
    TestRunner.Assert(ok == true, "Skill use should succeed")

    local ok2 = TeamBattleSystem.UseTeamSkill(matchId, "red1", "team_boost")
    TestRunner.Assert(ok2 == false, "Skill already used should fail")

    print("[TeamBattleSystem] 团队技能测试完成")
end

-- ============================================================================
-- 测试：团队排行榜
-- ============================================================================
function tests.TestGetTeamLeaderboard()
    TeamBattleSystem.Reset()

    TeamBattleSystem.CreateTeam("player1", { name = "团队A" })
    TeamBattleSystem.CreateTeam("player2", { name = "团队B" })

    local leaderboard = TeamBattleSystem.GetTeamLeaderboard(10)
    TestRunner.Assert(#leaderboard >= 2, "Should have at least 2 teams")

    print("[TeamBattleSystem] 排行榜测试完成")
end

-- ============================================================================
-- 运行所有测试
-- ============================================================================
TestRunner.Run(tests)

return tests
