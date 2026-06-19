-- ============================================================================
-- RoomSystem.lua - 自定义房间系统
-- ----------------------------------------------------------------------------
-- 功能：
--   1. 创建自定义房间
--   2. 设置房间规则（轮数、时限、起拍金额）
--   3. 邀请好友加入
--   4. 房间号 + 密码保护
--   5. 房主权限管理
-- ============================================================================

local Config = require("Config")
local EventBus = require("Utils.EventBus")

local RoomSystem = {}

-- ============================================================================
-- 内部状态
-- ============================================================================
local _rooms = {}  -- { [roomId] = RoomData }
local _playerRooms = {}  -- { [uid] = roomId }  玩家当前所在房间
local _roomIdCounter = 1

-- ============================================================================
-- 辅助
-- ============================================================================
local function _GenerateRoomId()
    local id = string.format("%06d", _roomIdCounter)
    _roomIdCounter = _roomIdCounter + 1
    return "ROOM_" .. id
end

local function _GenerateInviteCode()
    local chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    local code = {}
    for i = 1, 6 do
        code[i] = chars:sub(math.random(1, #chars), math.random(1, #chars))
    end
    return table.concat(code)
end

-- ============================================================================
-- 创建房间
-- ============================================================================
function RoomSystem.CreateRoom(hostUid, options)
    options = options or {}

    if _playerRooms[hostUid] then
        return false, "already_in_room"
    end

    local roomId = _GenerateRoomId()
    local inviteCode = _GenerateInviteCode()

    local room = {
        roomId = roomId,
        inviteCode = inviteCode,
        hostUid = hostUid,
        name = options.name or ("房间" .. roomId),
        mode = options.mode or "standard",
        password = options.password or nil,
        hasPassword = options.password and #options.password > 0,

        -- 房间规则
        rules = {
            maxPlayers = options.maxPlayers or 4,
            rounds = options.rounds or 5,
            bidTimeLimit = options.bidTimeLimit or 15,
            initialFunds = options.initialFunds or 10000,
            entryFee = options.entryFee or 0,
            hallId = options.hallId or "hall_standard"
        },

        -- 玩家列表
        players = {
            {
                uid = hostUid,
                seat = 1,
                isHost = true,
                isReady = true,
                characterId = nil
            }
        },

        -- 状态
        status = "waiting",  -- waiting / ready / starting / playing
        createdAt = os and os.time() or 0,
        settings = {
            allowSpectators = options.allowSpectators or false,
            autoStart = options.autoStart or false,
            autoFillWithAI = options.autoFillWithAI or true
        }
    }

    _rooms[roomId] = room
    _playerRooms[hostUid] = roomId

    -- 发布事件
    EventBus.Publish("room_created", {
        roomId = roomId,
        hostUid = hostUid,
        roomName = room.name
    })

    print("[RoomSystem] 房间创建: " .. roomId .. " by " .. tostring(hostUid))
    return true, roomId, inviteCode
end

-- ============================================================================
-- 加入房间
-- ============================================================================
function RoomSystem.JoinRoom(uid, roomIdOrCode, password)
    -- 查找房间
    local room = nil
    for _, r in pairs(_rooms) do
        if r.roomId == roomIdOrCode or r.inviteCode == roomIdOrCode then
            room = r
            break
        end
    end

    if not room then
        return false, "room_not_found"
    end

    if room.status ~= "waiting" then
        return false, "room_not_joinable"
    end

    if #room.players >= room.rules.maxPlayers then
        return false, "room_full"
    end

    if room.hasPassword then
        if password ~= room.password then
            return false, "wrong_password"
        end
    end

    if _playerRooms[uid] then
        return false, "already_in_room"
    end

    -- 检查是否已在房间中
    for _, p in ipairs(room.players) do
        if p.uid == uid then
            return false, "already_in_this_room"
        end
    end

    -- 添加玩家
    local seat = #room.players + 1
    table.insert(room.players, {
        uid = uid,
        seat = seat,
        isHost = false,
        isReady = false,
        characterId = nil
    })

    _playerRooms[uid] = room.roomId

    -- 发布事件
    EventBus.Publish("player_joined_room", {
        roomId = room.roomId,
        uid = uid,
        playerCount = #room.players
    })

    print("[RoomSystem] 玩家 " .. tostring(uid) .. " 加入房间 " .. room.roomId)
    return true, room
end

-- ============================================================================
-- 离开房间
-- ============================================================================
function RoomSystem.LeaveRoom(uid)
    local roomId = _playerRooms[uid]
    if not roomId then
        return false, "not_in_room"
    end

    local room = _rooms[roomId]
    if not room then
        _playerRooms[uid] = nil
        return false, "room_not_found"
    end

    -- 从玩家列表中移除
    for i = #room.players, 1, -1 do
        if room.players[i].uid == uid then
            table.remove(room.players, i)
            break
        end
    end

    _playerRooms[uid] = nil

    -- 如果是房主离开，转移房主或解散房间
    if room.hostUid == uid then
        if #room.players > 0 then
            -- 转移房主给第一个玩家
            room.hostUid = room.players[1].uid
            room.players[1].isHost = true
        else
            -- 解散房间
            _rooms[roomId] = nil
            print("[RoomSystem] 房间解散: " .. roomId)
            return true, "room_dissolved"
        end
    end

    -- 发布事件
    EventBus.Publish("player_left_room", {
        roomId = roomId,
        uid = uid,
        playerCount = #room.players
    })

    print("[RoomSystem] 玩家 " .. tostring(uid) .. " 离开房间 " .. roomId)
    return true, "left"
end

-- ============================================================================
-- 获取房间信息
-- ============================================================================
function RoomSystem.GetRoomInfo(roomId)
    local room = _rooms[roomId]
    if not room then return nil end

    return {
        roomId = room.roomId,
        name = room.name,
        hostUid = room.hostUid,
        mode = room.mode,
        hasPassword = room.hasPassword,
        playerCount = #room.players,
        maxPlayers = room.rules.maxPlayers,
        rules = room.rules,
        status = room.status,
        settings = room.settings
    }
end

-- ============================================================================
-- 获取玩家所在房间
-- ============================================================================
function RoomSystem.GetPlayerRoom(uid)
    local roomId = _playerRooms[uid]
    if not roomId then return nil end
    return RoomSystem.GetRoomInfo(roomId)
end

-- ============================================================================
-- 设置准备状态
-- ============================================================================
function RoomSystem.SetReady(uid, isReady)
    local roomId = _playerRooms[uid]
    if not roomId then return false, "not_in_room" end

    local room = _rooms[roomId]
    if not room then return false, "room_not_found" end

    for _, player in ipairs(room.players) do
        if player.uid == uid then
            player.isReady = isReady
            break
        end
    end

    -- 检查是否所有人都准备好了
    if room.settings.autoStart then
        local allReady = true
        for _, player in ipairs(room.players) do
            if not player.isReady then
                allReady = false
                break
            end
        end

        if allReady and #room.players >= 2 then
            RoomSystem.StartRoom(roomId)
        end
    end

    return true
end

-- ============================================================================
-- 选择角色
-- ============================================================================
function RoomSystem.SelectCharacter(uid, characterId)
    local roomId = _playerRooms[uid]
    if not roomId then return false, "not_in_room" end

    local room = _rooms[roomId]
    if not room then return false, "room_not_found" end

    for _, player in ipairs(room.players) do
        if player.uid == uid then
            player.characterId = characterId
            break
        end
    end

    return true
end

-- ============================================================================
-- 开始游戏（房主）
-- ============================================================================
function RoomSystem.StartRoom(roomId)
    local room = _rooms[roomId]
    if not room then return false, "room_not_found" end

    if room.status ~= "waiting" then
        return false, "room_not_waiting"
    end

    if #room.players < 2 then
        return false, "not_enough_players"
    end

    room.status = "starting"

    -- 发布事件，通知游戏开始
    EventBus.Publish("room_game_start", {
        roomId = roomId,
        hostUid = room.hostUid,
        players = room.players,
        rules = room.rules
    })

    print("[RoomSystem] 房间 " .. roomId .. " 开始游戏")
    return true
end

-- ============================================================================
-- 更新房间设置（房主）
-- ============================================================================
function RoomSystem.UpdateRoomSettings(uid, settings)
    local roomId = _playerRooms[uid]
    if not roomId then return false, "not_in_room" end

    local room = _rooms[roomId]
    if not room then return false, "room_not_found" end

    if room.hostUid ~= uid then
        return false, "not_host"
    end

    if settings.rounds then room.rules.rounds = settings.rounds end
    if settings.bidTimeLimit then room.rules.bidTimeLimit = settings.bidTimeLimit end
    if settings.initialFunds then room.rules.initialFunds = settings.initialFunds end
    if settings.maxPlayers then room.rules.maxPlayers = settings.maxPlayers end

    return true
end

-- ============================================================================
-- 踢出玩家（房主）
-- ============================================================================
function RoomSystem.KickPlayer(hostUid, targetUid)
    local roomId = _playerRooms[hostUid]
    if not roomId then return false, "not_in_room" end

    local room = _rooms[roomId]
    if not room then return false, "room_not_found" end

    if room.hostUid ~= hostUid then
        return false, "not_host"
    end

    if targetUid == hostUid then
        return false, "cannot_kick_self"
    end

    return RoomSystem.LeaveRoom(targetUid)
end

-- ============================================================================
-- 获取所有等待中的房间
-- ============================================================================
function RoomSystem.GetWaitingRooms()
    local result = {}
    for _, room in pairs(_rooms) do
        if room.status == "waiting" then
            table.insert(result, {
                roomId = room.roomId,
                name = room.name,
                hostUid = room.hostUid,
                playerCount = #room.players,
                maxPlayers = room.rules.maxPlayers,
                hasPassword = room.hasPassword,
                mode = room.mode
            })
        end
    end
    return result
end

-- ============================================================================
-- 注册事件
-- ============================================================================
function RoomSystem.RegisterEvents()
    print("[RoomSystem] 系统已注册")
end

-- ============================================================================
-- 重置（测试用）
-- ============================================================================
function RoomSystem.Reset()
    _rooms = {}
    _playerRooms = {}
    _roomIdCounter = 1
    print("[RoomSystem] 数据已重置")
end

return RoomSystem
