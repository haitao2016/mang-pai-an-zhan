-- ============================================================================
-- TeamBattleSystem.lua - 2v2 团队战系统
-- ----------------------------------------------------------------------------
-- 功能：
--   1. 2v2 组队对战
--   2. 团队匹配系统
--   3. 团队积分与排名
--   4. 团队技能（协作技能）
--   5. 团队成就与奖励
--
-- 规则：
--   - 4 名玩家组成 2 队（红队 vs 蓝队）
--   每队 2 人，共享团队资金池
--   - 每轮两队同时暗拍，价高者得
--   - 团队积分 = 所有成员藏品总价值
-- ============================================================================

local Config = require("Config")
local EventBus = require("Utils.EventBus")

local TeamBattleSystem = {}

-- ============================================================================
-- 内部状态
-- ============================================================================
local _teams = {}      -- { [teamId] = TeamData }
local _matches = {}    -- { [matchId] = MatchData }
local _playerTeams = {}  -- { [uid] = teamId }

-- ============================================================================
-- 团队状态枚举
-- ============================================================================
TeamBattleSystem.MatchStatus = {
    PENDING = "pending",           -- 等待开始
    BIDDING = "bidding",          -- 出价中
    ROUND_END = "round_end",      -- 回合结束
    MATCH_END = "match_end"       -- 比赛结束
}

-- ============================================================================
-- 团队颜色
-- ============================================================================
TeamBattleSystem.TeamColors = {
    RED = {
        id = "red",
        name = "红队",
        color = { r = 220, g = 80, b = 80 },
        icon = "🔴"
    },
    BLUE = {
        id = "blue",
        name = "蓝队",
        color = { r = 80, g = 120, b = 220 },
        icon = "🔵"
    }
}

-- ============================================================================
-- 辅助函数
-- ============================================================================
local function _GenerateTeamId()
    return "TEAM_" .. string.format("%06d", math.random(1, 999999))
end

local function _GenerateMatchId()
    return "MATCH_" .. os.date("%Y%m%d%H%M%S") .. "_" .. string.format("%04d", math.random(1, 9999))
end

local function _Now()
    if os and os.time then return os.time() end
    return 0
end

-- ============================================================================
-- 创建团队
-- ============================================================================
function TeamBattleSystem.CreateTeam(captainUid, options)
    options = options or {}

    local teamId = _GenerateTeamId()

    local team = {
        id = teamId,
        name = options.name or ("团队" .. teamId:sub(-4)),
        tag = options.tag or "TAG",  -- 3-4字符标签
        captain = captainUid,

        -- 成员（队长 + 1 名队友）
        members = {
            {
                uid = captainUid,
                role = "captain",
                joinedAt = _Now(),
                stats = {
                    gamesPlayed = 0,
                    wins = 0,
                    totalScore = 0
                }
            }
        },

        -- 团队总积分
        teamScore = 0,
        teamWins = 0,
        teamGamesPlayed = 0,

        -- 团队成就
        achievements = {},

        -- 设置
        settings = {
            public = options.public ~= false,  -- 默认公开招募
            minRank = options.minRank or 0,
            autoMatch = options.autoMatch or false
        },

        createdAt = _Now()
    }

    _teams[teamId] = team
    _playerTeams[captainUid] = teamId

    EventBus.Publish(EventBus.Events.TEAM_CREATE, {
        teamId = teamId,
        name = team.name,
        captain = captainUid
    })

    print("[TeamBattle] 团队创建: " .. teamId .. " - " .. team.name)
    return teamId
end

-- ============================================================================
-- 邀请玩家加入团队
-- ============================================================================
function TeamBattleSystem.InviteToTeam(teamId, inviterUid, targetUid)
    local team = _teams[teamId]
    if not team then
        return false, "team_not_found"
    end

    if team.captain ~= inviterUid then
        return false, "not_captain"
    end

    if #team.members >= 2 then
        return false, "team_full"
    end

    if _playerTeams[targetUid] then
        return false, "already_in_team"
    end

    EventBus.Publish("team_invite", {
        teamId = teamId,
        inviter = inviterUid,
        target = targetUid,
        teamName = team.name
    })

    print("[TeamBattle] 邀请 " .. tostring(targetUid) .. " 加入团队 " .. teamId)
    return true
end

-- ============================================================================
-- 接受邀请加入团队
-- ============================================================================
function TeamBattleSystem.JoinTeam(teamId, uid)
    local team = _teams[teamId]
    if not team then
        return false, "team_not_found"
    end

    if #team.members >= 2 then
        return false, "team_full"
    end

    if _playerTeams[uid] then
        return false, "already_in_team"
    end

    table.insert(team.members, {
        uid = uid,
        role = "member",
        joinedAt = _Now(),
        stats = {
            gamesPlayed = 0,
            wins = 0,
            totalScore = 0
        }
    })

    _playerTeams[uid] = teamId

    EventBus.Publish(EventBus.Events.TEAM_JOIN, {
        teamId = teamId,
        uid = uid,
        memberCount = #team.members
    })

    print("[TeamBattle] 玩家 " .. tostring(uid) .. " 加入团队 " .. teamId)
    return true
end

-- ============================================================================
-- 离开团队
-- ============================================================================
function TeamBattleSystem.LeaveTeam(uid)
    local teamId = _playerTeams[uid]
    if not teamId then
        return false, "not_in_team"
    end

    local team = _teams[teamId]
    if not team then
        _playerTeams[uid] = nil
        return false, "team_not_found"
    end

    -- 移除成员
    for i = #team.members, 1, -1 do
        if team.members[i].uid == uid then
            table.remove(team.members, i)
            break
        end
    end

    _playerTeams[uid] = nil

    -- 如果队长离开，转移给其他成员或解散团队
    if team.captain == uid then
        if #team.members > 0 then
            team.captain = team.members[1].uid
            team.members[1].role = "captain"
        else
            _teams[teamId] = nil
            print("[TeamBattle] 团队解散: " .. teamId)
        end
    end

    EventBus.Publish("team_member_left", {
        teamId = teamId,
        uid = uid
    })

    return true
end

-- ============================================================================
-- 获取玩家的团队
-- ============================================================================
function TeamBattleSystem.GetPlayerTeam(uid)
    local teamId = _playerTeams[uid]
    if not teamId then return nil end
    return _teams[teamId]
end

-- ============================================================================
-- 获取团队信息
-- ============================================================================
function TeamBattleSystem.GetTeamInfo(teamId)
    local team = _teams[teamId]
    if not team then return nil end

    return {
        id = team.id,
        name = team.name,
        tag = team.tag,
        captain = team.captain,
        members = team.members,
        memberCount = #team.members,
        teamScore = team.teamScore,
        teamWins = team.teamWins,
        teamGamesPlayed = team.teamGamesPlayed,
        winRate = team.teamGamesPlayed > 0 and math.floor(team.teamWins / team.teamGamesPlayed * 100) or 0
    }
end

-- ============================================================================
-- 创建团队战匹配
-- ============================================================================
function TeamBattleSystem.CreateMatch(team1Id, team2Id)
    local team1 = _teams[team1Id]
    local team2 = _teams[team2Id]

    if not team1 or not team2 then
        return false, "team_not_found"
    end

    if #team1.members < 2 or #team2.members < 2 then
        return false, "incomplete_teams"
    end

    local matchId = _GenerateMatchId()

    local match = {
        id = matchId,
        status = TeamBattleSystem.MatchStatus.PENDING,

        -- 两支队伍
        redTeam = {
            id = team1Id,
            name = team1.name,
            members = team1.members,
            teamBalance = Config.Auction and Config.Auction.InitialFunds or 10000,
            totalValue = 0,
            bids = {}  -- { roundIndex = { uid = bidAmount } }
        },
        blueTeam = {
            id = team2Id,
            name = team2.name,
            members = team2.members,
            teamBalance = Config.Auction and Config.Auction.InitialFunds or 10000,
            totalValue = 0,
            bids = {}
        },

        -- 比赛配置
        config = {
            rounds = 5,
            bidTimeLimit = 15,
            entryFee = 0
        },

        -- 当前回合
        currentRound = 0,
        roundHistory = {},

        -- 时间
        createdAt = _Now(),
        startedAt = nil,
        endedAt = nil,

        -- 获胜队伍
        winner = nil,

        -- 团队技能冷却
        teamSkills = {
            redTeam = { used = false, cooldown = 0 },
            blueTeam = { used = false, cooldown = 0 }
        }
    }

    _matches[matchId] = match

    EventBus.Publish("team_match_created", {
        matchId = matchId,
        redTeam = team1Id,
        blueTeam = team2Id
    })

    print("[TeamBattle] 团队战匹配创建: " .. matchId)
    return true, matchId
end

-- ============================================================================
-- 开始团队战
-- ============================================================================
function TeamBattleSystem.StartMatch(matchId)
    local match = _matches[matchId]
    if not match then
        return false, "match_not_found"
    end

    match.status = TeamBattleSystem.MatchStatus.BIDDING
    match.startedAt = _Now()
    match.currentRound = 1

    EventBus.Publish(EventBus.Events.TEAM_START, {
        matchId = matchId,
        rounds = match.config.rounds
    })

    print("[TeamBattle] 团队战开始: " .. matchId .. "，第 1 轮")
    return true
end

-- ============================================================================
-- 提交团队出价
-- ============================================================================
function TeamBattleSystem.SubmitTeamBid(matchId, uid, bidAmount)
    local match = _matches[matchId]
    if not match then
        return false, "match_not_found"
    end

    if match.status ~= TeamBattleSystem.MatchStatus.BIDDING then
        return false, "not_bidding_phase"
    end

    -- 确定队伍
    local team = nil
    for _, member in ipairs(match.redTeam.members) do
        if member.uid == uid then
            team = match.redTeam
            break
        end
    end
    if not team then
        for _, member in ipairs(match.blueTeam.members) do
            if member.uid == uid then
                team = match.blueTeam
                break
            end
        end
    end

    if not team then
        return false, "not_in_match"
    end

    -- 检查余额
    if bidAmount > team.teamBalance then
        return false, "insufficient_balance"
    end

    -- 记录出价
    match.redTeam.bids[match.currentRound] = match.redTeam.bids[match.currentRound] or {}
    match.blueTeam.bids[match.currentRound] = match.blueTeam.bids[match.currentRound] or {}

    team.bids[match.currentRound][uid] = bidAmount

    EventBus.Publish("team_bid_submitted", {
        matchId = matchId,
        uid = uid,
        teamId = team.id,
        round = match.currentRound,
        bidAmount = bidAmount
    })

    print("[TeamBattle] 出价: " .. tostring(uid) .. " = " .. bidAmount)

    return true
end

-- ============================================================================
-- 检查回合是否完成（两队都出价）
-- ============================================================================
function TeamBattleSystem.CheckRoundComplete(matchId)
    local match = _matches[matchId]
    if not match then return false end

    local roundBids = match.redTeam.bids[match.currentRound]
    if not roundBids then return false end

    -- 检查红队全员出价
    local redBidCount = 0
    for _ in pairs(roundBids) do redBidCount = redBidCount + 1 end
    if redBidCount < #match.redTeam.members then return false end

    -- 检查蓝队全员出价
    local blueBids = match.blueTeam.bids[match.currentRound] or {}
    local blueBidCount = 0
    for _ in pairs(blueBids) do blueBidCount = blueBidCount + 1 end
    if blueBidCount < #match.blueTeam.members then return false end

    return true
end

-- ============================================================================
-- 结算当前回合
-- ============================================================================
function TeamBattleSystem.SettleRound(matchId)
    local match = _matches[matchId]
    if not match then
        return false, "match_not_found"
    end

    -- 计算两队总出价
    local redTotal = 0
    for _, amount in pairs(match.redTeam.bids[match.currentRound] or {}) do
        redTotal = redTotal + amount
    end

    local blueTotal = 0
    for _, amount in pairs(match.blueTeam.bids[match.currentRound] or {}) do
        blueTotal = blueTotal + amount
    end

    -- 胜者获得对方出价金额的道具价值（简化版）
    local roundWinner = nil
    local loserTeam = nil

    if redTotal > blueTotal then
        roundWinner = match.redTeam
        loserTeam = match.blueTeam
    elseif blueTotal > redTotal then
        roundWinner = match.blueTeam
        loserTeam = match.redTeam
    end

    -- 扣除出价
    match.redTeam.teamBalance = match.redTeam.teamBalance - redTotal
    match.blueTeam.teamBalance = match.blueTeam.teamBalance - blueTotal

    -- 记录回合结果
    local roundResult = {
        round = match.currentRound,
        redTotalBids = redTotal,
        blueTotalBids = blueTotal,
        winner = roundWinner and roundWinner.id,
        redRemainingBalance = match.redTeam.teamBalance,
        blueRemainingBalance = match.blueTeam.teamBalance,
        items = {}  -- 本回合获得的物品
    }

    table.insert(match.roundHistory, roundResult)

    EventBus.Publish("team_round_completed", {
        matchId = matchId,
        round = match.currentRound,
        winner = roundWinner and roundWinner.id,
        redTotal = redTotal,
        blueTotal = blueTotal
    })

    -- 检查是否结束
    if match.currentRound >= match.config.rounds then
        return TeamBattleSystem.EndMatch(matchId)
    end

    -- 下一回合
    match.currentRound = match.currentRound + 1

    EventBus.Publish("team_next_round", {
        matchId = matchId,
        round = match.currentRound
    })

    return true
end

-- ============================================================================
-- 结束比赛
-- ============================================================================
function TeamBattleSystem.EndMatch(matchId)
    local match = _matches[matchId]
    if not match then
        return false, "match_not_found"
    end

    match.status = TeamBattleSystem.MatchStatus.MATCH_END
    match.endedAt = _Now()

    -- 计算总价值（简化版：余额 + 已获得物品价值）
    match.redTeam.totalValue = match.redTeam.teamBalance
    match.blueTeam.totalValue = match.blueTeam.teamBalance

    -- 确定胜者
    if match.redTeam.totalValue > match.blueTeam.totalValue then
        match.winner = match.redTeam.id
    elseif match.blueTeam.totalValue > match.redTeam.totalValue then
        match.winner = match.blueTeam.id
    end

    -- 更新团队统计
    if match.winner then
        local winnerTeam = match.winner == match.redTeam.id and match.redTeam or match.blueTeam
        local loserTeam = match.winner == match.redTeam.id and match.blueTeam or match.redTeam

        for _, member in ipairs(winnerTeam.members) do
            member.stats.gamesPlayed = member.stats.gamesPlayed + 1
            member.stats.wins = member.stats.wins + 1

            -- 团队战胜利触发赛季经验（v1.1 系统集成）
            EventBus.Publish(EventBus.Events.SEASON_PROGRESS, {
                uid = member.uid,
                xp = 30,
                source = "team_win"
            })
        end
        for _, member in ipairs(loserTeam.members) do
            member.stats.gamesPlayed = member.stats.gamesPlayed + 1
        end

        EventBus.Publish(EventBus.Events.TEAM_WIN, {
            matchId = matchId,
            winnerTeamId = match.winner,
            redScore = match.redTeam.totalValue,
            blueScore = match.blueTeam.totalValue
        })
    end

    print("[TeamBattle] 团队战结束: " .. matchId .. "，胜者: " .. tostring(match.winner))
    return true
end

-- ============================================================================
-- 使用团队技能
-- ============================================================================
function TeamBattleSystem.UseTeamSkill(matchId, uid, skillId)
    local match = _matches[matchId]
    if not match then
        return false, "match_not_found"
    end

    -- 确定队伍
    local teamKey = nil
    for _, member in ipairs(match.redTeam.members) do
        if member.uid == uid then
            teamKey = "redTeam"
            break
        end
    end
    if not teamKey then
        for _, member in ipairs(match.blueTeam.members) do
            if member.uid == uid then
                teamKey = "blueTeam"
                break
            end
        end
    end

    if not teamKey then
        return false, "not_in_match"
    end

    local teamSkill = match.teamSkills[teamKey]
    if teamSkill.used then
        return false, "skill_already_used"
    end

    teamSkill.used = true

    EventBus.Publish(EventBus.Events.TEAM_SKILL_USE, {
        matchId = matchId,
        teamId = match[teamKey].id,
        uid = uid,
        skillId = skillId
    })

    print("[TeamBattle] 团队技能使用: " .. skillId .. " by " .. teamKey)
    return true
end

-- ============================================================================
-- 获取团队排行榜
-- ============================================================================
function TeamBattleSystem.GetTeamLeaderboard(limit)
    limit = limit or 20
    local sorted = {}

    for _, team in pairs(_teams) do
        table.insert(sorted, {
            id = team.id,
            name = team.name,
            tag = team.tag,
            teamScore = team.teamScore,
            teamWins = team.teamWins,
            teamGamesPlayed = team.teamGamesPlayed,
            winRate = team.teamGamesPlayed > 0 and math.floor(team.teamWins / team.teamGamesPlayed * 100) or 0
        })
    end

    -- 排序
    table.sort(sorted, function(a, b)
        return a.teamScore > b.teamScore
    end)

    -- 限制数量
    local result = {}
    for i = 1, math.min(limit, #sorted) do
        sorted[i].rank = i
        table.insert(result, sorted[i])
    end

    return result
end

-- ============================================================================
-- 重置（测试用）
-- ============================================================================
function TeamBattleSystem.Reset()
    _teams = {}
    _matches = {}
    _playerTeams = {}
    print("[TeamBattle] 数据已重置")
end

-- ============================================================================
-- 注册事件监听
-- ============================================================================
function TeamBattleSystem.RegisterEvents()
    -- 订阅赛季系统事件（v1.1 集成）
    EventBus.Subscribe(EventBus.Events.SEASON_LEVELUP, function(data)
        print("[TeamBattleSystem] 赛季升级，解锁团队战奖励: " .. tostring(data.uid))
    end, "TeamBattleSystem")

    -- 订阅锦标赛事件（v1.2 集成）
    EventBus.Subscribe(EventBus.Events.TOURNAMENT_WIN, function(data)
        print("[TeamBattleSystem] 锦标赛胜利提升团队排名，玩家: " .. tostring(data.uid))
    end, "TeamBattleSystem")

    print("[TeamBattleSystem] 事件监听已注册")
end

return TeamBattleSystem
