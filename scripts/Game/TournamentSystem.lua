-- ============================================================================
-- TournamentSystem.lua - 锦标赛系统
-- ----------------------------------------------------------------------------
-- 功能：
--   1. 单败淘汰制锦标赛
--   2. 锦标赛报名与分组
--   3. 自动匹配对战
--   4. 冠军奖励发放
--   5. 锦标赛历史记录
--
-- 规则：
--   - 8 人或 16 人参赛
--   - 单败淘汰（输一场即出局）
--   - 每轮胜者晋级，直到决出冠军
-- ============================================================================

local Config = require("Config")
local EventBus = require("Utils.EventBus")

local TournamentSystem = {}

-- ============================================================================
-- 内部状态
-- ============================================================================
local _tournaments = {}  -- { [tournamentId] = TournamentData }
local _playerTournaments = {}  -- { [uid] = { tournamentId, status } }

-- ============================================================================
-- 锦标赛状态枚举
-- ============================================================================
TournamentSystem.Status = {
    REGISTRATION = "registration",   -- 报名中
    GROUPING = "grouping",           -- 分组中
    IN_PROGRESS = "in_progress",    -- 进行中
    COMPLETED = "completed",        -- 已结束
    CANCELLED = "cancelled"         -- 已取消
}

-- ============================================================================
-- 辅助函数
-- ============================================================================
local function _GenerateTournamentId()
    return "TRN_" .. os.date("%Y%m%d") .. "_" .. string.format("%04d", math.random(1, 9999))
end

local function _Now()
    if os and os.time then return os.time() end
    return 0
end

-- ============================================================================
-- 创建锦标赛
-- ============================================================================
function TournamentSystem.CreateTournament(options)
    options = options or {}

    local tournamentId = _GenerateTournamentId()

    local tournament = {
        id = tournamentId,
        name = options.name or ("锦标赛 " .. os.date("%m-%d")),
        description = options.description or "单败淘汰赛",

        -- 赛制配置
        format = options.format or "single_elimination",  -- single_elimination
        maxPlayers = options.maxPlayers or 8,             -- 8 或 16
        entryFee = options.entryFee or 0,
        prize = options.prize or 10000,

        -- 时间安排
        registrationStart = options.registrationStart or _Now(),
        registrationEnd = options.registrationEnd or (_Now() + 3600),  -- 1小时后截止
        startTime = options.startTime or (_Now() + 7200),               -- 2小时后开始

        -- 状态
        status = TournamentSystem.Status.REGISTRATION,

        -- 参赛者
        players = {},  -- { { uid, nickname, registeredAt, eliminated = false } }
        playerCount = 0,

        -- 淘汰赛结构
        rounds = {},  -- { roundIndex = { matches = { { player1, player2, winner, status } } } }
        currentRound = 0,

        -- 奖励
        rewards = {
            { place = 1, reward = options.prize or 10000, title = "冠军" },
            { place = 2, reward = math.floor((options.prize or 10000) * 0.5), title = "亚军" },
            { place = 3, reward = math.floor((options.prize or 10000) * 0.25), title = "四强" }
        },

        -- 统计
        createdAt = _Now(),
        startedAt = nil,
        completedAt = nil,
        winner = nil
    }

    _tournaments[tournamentId] = tournament

    -- 发布事件
    EventBus.Publish("tournament_created", {
        tournamentId = tournamentId,
        name = tournament.name,
        startTime = tournament.startTime
    })

    print("[Tournament] 锦标赛创建: " .. tournamentId .. " - " .. tournament.name)
    return tournamentId
end

-- ============================================================================
-- 报名参加锦标赛
-- ============================================================================
function TournamentSystem.Register(tournamentId, uid, nickname)
    local tournament = _tournaments[tournamentId]
    if not tournament then
        return false, "tournament_not_found"
    end

    if tournament.status ~= TournamentSystem.Status.REGISTRATION then
        return false, "registration_closed"
    end

    if _Now() > tournament.registrationEnd then
        return false, "registration_expired"
    end

    if tournament.playerCount >= tournament.maxPlayers then
        return false, "tournament_full"
    end

    -- 检查是否已报名
    for _, player in ipairs(tournament.players) do
        if player.uid == uid then
            return false, "already_registered"
        end
    end

    -- 添加玩家
    table.insert(tournament.players, {
        uid = uid,
        nickname = nickname or ("玩家" .. tostring(uid)),
        registeredAt = _Now(),
        eliminated = false,
        currentMatch = nil,
        roundWins = 0
    })
    tournament.playerCount = #tournament.players

    -- 记录玩家参与的锦标赛
    _playerTournaments[uid] = {
        tournamentId = tournamentId,
        status = "registered"
    }

    EventBus.Publish(EventBus.Events.TOURNAMENT_REGISTER, {
        tournamentId = tournamentId,
        uid = uid,
        playerCount = tournament.playerCount
    })

    print("[Tournament] 玩家 " .. tostring(uid) .. " 报名锦标赛 " .. tournamentId)

    -- 检查是否达到人数，开始分组
    if tournament.playerCount >= tournament.maxPlayers then
        TournamentSystem.StartTournament(tournamentId)
    end

    return true
end

-- ============================================================================
-- 开始锦标赛
-- ============================================================================
function TournamentSystem.StartTournament(tournamentId)
    local tournament = _tournaments[tournamentId]
    if not tournament then
        return false, "tournament_not_found"
    end

    if tournament.playerCount < 2 then
        return false, "not_enough_players"
    end

    tournament.status = TournamentSystem.Status.IN_PROGRESS
    tournament.startedAt = _Now()

    EventBus.Publish(EventBus.Events.TOURNAMENT_START, {
        tournamentId = tournamentId,
        playerCount = tournament.playerCount,
        maxPlayers = tournament.maxPlayers
    })

    -- 生成对阵表
    local rounds = math.ceil(math.log(tournament.maxPlayers, 2))
    tournament.rounds = {}
    tournament.currentRound = 1

    -- 第一轮对阵
    local firstRoundMatches = {}
    local shuffledPlayers = TournamentSystem._ShufflePlayers(tournament.players)

    for i = 1, #shuffledPlayers, 2 do
        local match = {
            id = tournamentId .. "_R1_M" .. (#firstRoundMatches + 1),
            round = 1,
            player1 = shuffledPlayers[i],
            player2 = shuffledPlayers[i + 1],
            winner = nil,
            status = "pending"  -- pending, in_progress, completed
        }
        table.insert(firstRoundMatches, match)
    end

    tournament.rounds[1] = {
        roundIndex = 1,
        matches = firstRoundMatches,
        status = "pending"
    }

    EventBus.Publish("tournament_started", {
        tournamentId = tournamentId,
        totalPlayers = tournament.playerCount,
        rounds = rounds
    })

    print("[Tournament] 锦标赛开始: " .. tournamentId .. "，共 " .. rounds .. " 轮")

    return true
end

-- ============================================================================
-- 随机排列玩家（用于对阵表）
-- ============================================================================
function TournamentSystem._ShufflePlayers(players)
    local shuffled = {}
    for _, p in ipairs(players) do
        table.insert(shuffled, p)
    end

    -- Fisher-Yates 洗牌
    for i = #shuffled, 2, -1 do
        local j = math.random(1, i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end

    return shuffled
end

-- ============================================================================
-- 获取当前对阵信息
-- ============================================================================
function TournamentSystem.GetBracket(tournamentId)
    local tournament = _tournaments[tournamentId]
    if not tournament then return nil end

    return {
        id = tournament.id,
        name = tournament.name,
        status = tournament.status,
        currentRound = tournament.currentRound,
        rounds = tournament.rounds,
        players = tournament.players,
        winner = tournament.winner
    }
end

-- ============================================================================
-- 获取玩家的当前比赛
-- ============================================================================
function TournamentSystem.GetPlayerMatch(tournamentId, uid)
    local tournament = _tournaments[tournamentId]
    if not tournament then return nil end

    for _, round in ipairs(tournament.rounds) do
        for _, match in ipairs(round.matches) do
            if (match.player1 and match.player1.uid == uid) or
               (match.player2 and match.player2.uid == uid) then
                return {
                    matchId = match.id,
                    round = match.round,
                    opponent = match.player1.uid == uid and match.player2 or match.player1,
                    status = match.status,
                    isYourTurn = match.status == "in_progress"
                }
            end
        end
    end

    return nil
end

-- ============================================================================
-- 提交比赛结果（由游戏结束触发）
-- ============================================================================
function TournamentSystem.SubmitMatchResult(tournamentId, matchId, winnerUid)
    local tournament = _tournaments[tournamentId]
    if not tournament then
        return false, "tournament_not_found"
    end

    -- 查找比赛
    local match = nil
    local roundIndex = 0
    for ri, round in ipairs(tournament.rounds) do
        for mi, m in ipairs(round.matches) do
            if m.id == matchId then
                match = m
                roundIndex = ri
                break
            end
        end
    end

    if not match then
        return false, "match_not_found"
    end

    if match.status == "completed" then
        return false, "match_already_completed"
    end

    -- 更新比赛结果
    match.winner = winnerUid
    match.status = "completed"

    -- 标记失败者
    local loser = match.player1.uid == winnerUid and match.player2 or match.player1
    if loser then
        loser.eliminated = true
    end

    -- 胜者记录
    local winner = match.player1.uid == winnerUid and match.player1 or match.player2
    if winner then
        winner.roundWins = (winner.roundWins or 0) + 1
    end

    EventBus.Publish(EventBus.Events.TOURNAMENT_MATCH_RESULT, {
        tournamentId = tournamentId,
        matchId = matchId,
        winnerUid = winnerUid,
        loserUid = loser and loser.uid
    })

    -- 检查是否需要生成下一轮
    local currentRound = tournament.rounds[roundIndex]
    local allCompleted = true
    for _, m in ipairs(currentRound.matches) do
        if m.status ~= "completed" then
            allCompleted = false
            break
        end
    end

    if allCompleted and roundIndex < math.ceil(math.log(tournament.maxPlayers, 2)) then
        TournamentSystem._GenerateNextRound(tournament, roundIndex)
    else
        -- 锦标赛结束
        TournamentSystem._CompleteTournament(tournament, winnerUid)
    end

    return true
end

-- ============================================================================
-- 生成下一轮对阵
-- ============================================================================
function TournamentSystem._GenerateNextRound(tournament, previousRoundIndex)
    local nextRoundIndex = previousRoundIndex + 1
    local previousRound = tournament.rounds[previousRoundIndex]
    local winners = {}

    -- 收集上一轮的胜者
    for _, match in ipairs(previousRound.matches) do
        if match.winner then
            table.insert(winners, match.winner)
        end
    end

    if #winners < 2 then
        return false
    end

    -- 生成下一轮比赛
    local nextRoundMatches = {}
    for i = 1, #winners, 2 do
        table.insert(nextRoundMatches, {
            id = tournament.id .. "_R" .. nextRoundIndex .. "_M" .. (#nextRoundMatches + 1),
            round = nextRoundIndex,
            player1 = winners[i],
            player2 = winners[i + 1],
            winner = nil,
            status = "pending"
        })
    end

    tournament.rounds[nextRoundIndex] = {
        roundIndex = nextRoundIndex,
        matches = nextRoundMatches,
        status = "pending"
    }
    tournament.currentRound = nextRoundIndex

    EventBus.Publish("tournament_next_round", {
        tournamentId = tournament.id,
        round = nextRoundIndex,
        matches = #nextRoundMatches
    })

    print("[Tournament] 生成第 " .. nextRoundIndex .. " 轮，共 " .. #nextRoundMatches .. " 场比赛")

    return true
end

-- ============================================================================
-- 完成锦标赛
-- ============================================================================
function TournamentSystem._CompleteTournament(tournament, winnerUid)
    tournament.status = TournamentSystem.Status.COMPLETED
    tournament.completedAt = _Now()
    tournament.winner = winnerUid

    -- 确定排名（亚军是决赛的输家）
    local runnerUp = nil
    local lastRound = tournament.rounds[#tournament.rounds]
    if lastRound and lastRound.matches[1] then
        local finalMatch = lastRound.matches[1]
        runnerUp = finalMatch.player1.uid == winnerUid and finalMatch.player2 or finalMatch.player1
    end

    -- 发放奖励
    if tournament.rewards[1] then
        EventBus.Publish(EventBus.Events.TOURNAMENT_WIN, {
            tournamentId = tournament.id,
            uid = winnerUid,
            place = 1,
            reward = tournament.rewards[1].reward,
            title = tournament.rewards[1].title
        })

        -- 锦标赛胜利触发赛季经验（v1.1 系统集成）
        EventBus.Publish(EventBus.Events.SEASON_PROGRESS, {
            uid = winnerUid,
            xp = 50,
            source = "tournament_win"
        })
    end

    if runnerUp and tournament.rewards[2] then
        EventBus.Publish(EventBus.Events.TOURNAMENT_WIN, {
            tournamentId = tournament.id,
            uid = runnerUp.uid,
            place = 2,
            reward = tournament.rewards[2].reward,
            title = tournament.rewards[2].title
        })

        EventBus.Publish(EventBus.Events.SEASON_PROGRESS, {
            uid = runnerUp.uid,
            xp = 20,
            source = "tournament_runnerup"
        })
    end

    EventBus.Publish(EventBus.Events.TOURNAMENT_END, {
        tournamentId = tournament.id,
        winner = winnerUid,
        totalRounds = #tournament.rounds
    })

    print("[Tournament] 锦标赛结束: " .. tournament.id .. "，冠军: " .. tostring(winnerUid))
end

-- ============================================================================
-- 获取可参加的锦标赛列表
-- ============================================================================
function TournamentSystem.GetAvailableTournaments(uid)
    local available = {}
    local now = _Now()

    for _, tournament in pairs(_tournaments) do
        if tournament.status == TournamentSystem.Status.REGISTRATION then
            if now <= tournament.registrationEnd then
                -- 检查是否已报名
                local registered = false
                for _, player in ipairs(tournament.players) do
                    if player.uid == uid then
                        registered = true
                        break
                    end
                end

                table.insert(available, {
                    id = tournament.id,
                    name = tournament.name,
                    description = tournament.description,
                    playerCount = tournament.playerCount,
                    maxPlayers = tournament.maxPlayers,
                    entryFee = tournament.entryFee,
                    prize = tournament.prize,
                    registrationEnd = tournament.registrationEnd,
                    startTime = tournament.startTime,
                    alreadyRegistered = registered
                })
            end
        end
    end

    return available
end

-- ============================================================================
-- 获取玩家的锦标赛历史
-- ============================================================================
function TournamentSystem.GetPlayerHistory(uid)
    local history = {}

    for _, tournament in pairs(_tournaments) do
        for _, player in ipairs(tournament.players) do
            if player.uid == uid then
                table.insert(history, {
                    tournamentId = tournament.id,
                    tournamentName = tournament.name,
                    status = tournament.status,
                    finalPlace = player.eliminated and "淘汰" or "冠军",
                    roundWins = player.roundWins,
                    registeredAt = player.registeredAt,
                    completedAt = tournament.completedAt
                })
                break
            end
        end
    end

    return history
end

-- ============================================================================
-- 获取锦标赛奖励信息
-- ============================================================================
function TournamentSystem.GetRewards(tournamentId)
    local tournament = _tournaments[tournamentId]
    if not tournament then return nil end

    return tournament.rewards
end

-- ============================================================================
-- 取消锦标赛（管理员）
-- ============================================================================
function TournamentSystem.CancelTournament(tournamentId)
    local tournament = _tournaments[tournamentId]
    if not tournament then
        return false, "tournament_not_found"
    end

    if tournament.status ~= TournamentSystem.Status.REGISTRATION then
        return false, "cannot_cancel_started_tournament"
    end

    tournament.status = TournamentSystem.Status.CANCELLED

    -- 退款（如果有报名费）
    if tournament.entryFee > 0 then
        for _, player in ipairs(tournament.players) do
            EventBus.Publish("tournament_refund", {
                tournamentId = tournamentId,
                uid = player.uid,
                amount = tournament.entryFee
            })
        end
    end

    EventBus.Publish("tournament_cancelled", {
        tournamentId = tournamentId
    })

    print("[Tournament] 锦标赛取消: " .. tournamentId)
    return true
end

-- ============================================================================
-- 重置（测试用）
-- ============================================================================
function TournamentSystem.Reset()
    _tournaments = {}
    _playerTournaments = {}
    print("[Tournament] 数据已重置")
end

-- ============================================================================
-- 注册事件监听
-- ============================================================================
function TournamentSystem.RegisterEvents()
    -- 订阅赛季系统事件（v1.1 集成）
    EventBus.Subscribe(EventBus.Events.SEASON_LEVELUP, function(data)
        print("[TournamentSystem] 赛季升级，解锁新锦标赛资格: " .. tostring(data.uid))
    end, "TournamentSystem")

    -- 订阅任务完成事件（v1.1 集成）
    EventBus.Subscribe(EventBus.Events.MISSION_COMPLETE, function(data)
        print("[TournamentSystem] 任务完成，玩家可参加特殊锦标赛: " .. tostring(data.uid))
    end, "TournamentSystem")

    print("[TournamentSystem] 事件监听已注册")
end

return TournamentSystem
