-- ============================================================================
-- LeaderboardSystem.lua - 本地排行榜系统
-- ----------------------------------------------------------------------------
-- 5 种排行榜：
--   1. wins       - 累计胜场数
--   2. winrate    - 胜率排行
--   3. items      - 获得藏品总价值
--   4. games      - 参与游戏次数
--   5. seasonExp  - 当前赛季经验值
-- ============================================================================

local Config = require("Config")

local LeaderboardSystem = {}

-- ============================================================================
-- 内部状态
-- ============================================================================
local _rankCache = {}   -- { boardId = { { rank, uid, nickname, value, extra } } }
local _lastUpdate = 0
local _playerStats = {}  -- 玩家本地统计 { uid = { games, wins, items, value } }

-- ============================================================================
-- 辅助
-- ============================================================================
local function _Now()
    if os and os.time then return os.time() end
    return 0
end

-- ============================================================================
-- 获取排行榜配置
-- ============================================================================
function LeaderboardSystem.GetBoardConfig(boardId)
    if not Config.Leaderboards or not Config.Leaderboards.Boards then
        return nil
    end
    for _, b in ipairs(Config.Leaderboards.Boards) do
        if b.id == boardId then
            return b
        end
    end
    return nil
end

-- ============================================================================
-- 获取所有可用的排行榜
-- ============================================================================
function LeaderboardSystem.GetAvailableBoards()
    if not Config.Leaderboards or not Config.Leaderboards.Boards then
        return {}
    end
    local result = {}
    for _, b in ipairs(Config.Leaderboards.Boards) do
        table.insert(result, {
            id = b.id,
            name = b.name,
            desc = b.desc
        })
    end
    return result
end

-- ============================================================================
-- 更新玩家统计
-- ============================================================================
function LeaderboardSystem.UpdatePlayerStats(uid, stats)
    if not uid or not stats then return end
    if not _playerStats[uid] then
        _playerStats[uid] = {
            games = 0,
            wins = 0,
            items = 0,
            totalValue = 0,
            seasonExp = 0
        }
    end

    local ps = _playerStats[uid]
    if stats.games then ps.games = ps.games + stats.games end
    if stats.wins then ps.wins = ps.wins + stats.wins end
    if stats.items then ps.items = ps.items + stats.items end
    if stats.totalValue then ps.totalValue = ps.totalValue + stats.totalValue end
    if stats.seasonExp then ps.seasonExp = ps.seasonExp + stats.seasonExp end

    -- 清除缓存，下次获取时重新计算
    _rankCache = {}
    _lastUpdate = 0
end

-- ============================================================================
-- 计算胜率
-- ============================================================================
local function _CalcWinRate(uid)
    local ps = _playerStats[uid]
    if not ps or ps.games <= 0 then return 0.0 end
    return ps.wins / ps.games
end

-- ============================================================================
-- 获取某排行榜的数据
-- ============================================================================
function LeaderboardSystem.GetBoard(boardId, limit)
    limit = limit or (Config.Leaderboards and Config.Leaderboards.MaxEntries) or 100

    -- 检查缓存
    if _rankCache[boardId] then
        local timeout = (Config.Leaderboards and Config.Leaderboards.UpdateInterval) or 300
        if (_Now() - _lastUpdate) < timeout then
            return _rankCache[boardId]
        end
    end

    -- 根据类型计算
    local entries = {}
    for uid, stats in pairs(_playerStats) do
        local value = 0
        if boardId == "wins" then
            value = stats.wins
        elseif boardId == "winrate" then
            value = _CalcWinRate(uid)
        elseif boardId == "items" then
            value = stats.totalValue
        elseif boardId == "games" then
            value = stats.games
        elseif boardId == "seasonExp" then
            value = stats.seasonExp
        end

        if value > 0 then
            table.insert(entries, {
                uid = uid,
                nickname = "玩家" .. tostring(uid),
                value = value
            })
        end
    end

    -- 降序排序
    table.sort(entries, function(a, b)
        return a.value > b.value
    end)

    -- 限制数量 + 添加排名
    local result = {}
    for rank, entry in ipairs(entries) do
        if rank > limit then break end
        table.insert(result, {
            rank = rank,
            uid = entry.uid,
            nickname = entry.nickname,
            value = entry.value
        })
    end

    _rankCache[boardId] = result
    _lastUpdate = _Now()

    return result
end

-- ============================================================================
-- 获取玩家在某排行榜中的排名
-- ============================================================================
function LeaderboardSystem.GetPlayerRank(boardId, uid)
    local board = LeaderboardSystem.GetBoard(boardId)
    for _, entry in ipairs(board) do
        if entry.uid == uid then
            return entry
        end
    end
    return nil
end

-- ============================================================================
-- 获取玩家所有排名信息
-- ============================================================================
function LeaderboardSystem.GetAllPlayerRanks(uid)
    local result = {}
    local boards = LeaderboardSystem.GetAvailableBoards()
    for _, b in ipairs(boards) do
        local rank = LeaderboardSystem.GetPlayerRank(b.id, uid)
        table.insert(result, {
            boardId = b.id,
            boardName = b.name,
            rank = rank and rank.rank or nil,
            value = rank and rank.value or 0,
            totalCount = #LeaderboardSystem.GetBoard(b.id, 1000)
        })
    end
    return result
end

-- ============================================================================
-- 获取前 N 名
-- ============================================================================
function LeaderboardSystem.GetTopN(boardId, n)
    n = n or 10
    local board = LeaderboardSystem.GetBoard(boardId, n)
    local result = {}
    for i = 1, math.min(n, #board) do
        table.insert(result, board[i])
    end
    return result
end

-- ============================================================================
-- 重置排行榜
-- ============================================================================
function LeaderboardSystem.Reset()
    _rankCache = {}
    _playerStats = {}
    _lastUpdate = 0
    print("[LeaderboardSystem] 排行榜已重置")
end

-- ============================================================================
-- 注册事件监听
-- ============================================================================
function LeaderboardSystem.RegisterEvents()
    local ok, EventBus = pcall(require, "Utils.EventBus")
    if not ok or not EventBus then return end

    EventBus.Subscribe(EventBus.Events.GAME_END, function(data)
        if not data then return end
        local uid = data.playerId or data.uid or data.seat
        LeaderboardSystem.UpdatePlayerStats(uid, {
            games = 1,
            wins = (data.isWinner or data.winner) and 1 or 0
        })
    end, "LeaderboardSystem")

    EventBus.Subscribe(EventBus.Events.ITEM_COLLECT, function(data)
        if not data then return end
        local uid = data.playerId or data.uid or data.seat
        LeaderboardSystem.UpdatePlayerStats(uid, {
            items = 1,
            totalValue = data.value or 100
        })
    end, "LeaderboardSystem")

    print("[LeaderboardSystem] 事件监听已注册")
end

return LeaderboardSystem
