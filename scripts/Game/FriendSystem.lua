-- ============================================================================
-- FriendSystem.lua - 好友系统
-- ----------------------------------------------------------------------------
-- 功能：
--   1. 添加 / 删除好友
--   2. 在线状态管理
--   3. 好友战绩查看
--   4. 邀请好友组队
--   5. serverCloud 持久化存储
-- ============================================================================

local Config = require("Config")
local EventBus = require("Utils.EventBus")

local FriendSystem = {}

-- ============================================================================
-- 内部状态
-- ============================================================================
local _friendCache = {}    -- { uid = { friends = { {uid, nickname, addedTime, isOnline} } } }
local _onlineTimestamps = {}  -- 在线状态缓存 { uid = lastSeenTime }

-- ============================================================================
-- 辅助：获取当前时间
-- ============================================================================
local function _Now()
    if os and os.time then
        return os.time()
    end
    return 0
end

-- ============================================================================
-- 获取玩家好友列表
-- ============================================================================
local function _GetFriendData(uid)
    if not uid then return nil end

    if _friendCache[uid] then
        return _friendCache[uid]
    end

    -- 尝试从 serverCloud 加载
    local data = {
        friends = {},
        pendingInvites = {},  -- 待处理邀请 { uid, time }
        sentInvites = {},      -- 已发送邀请
        lastSync = _Now()
    }

    if serverCloud and serverCloud.game and serverCloud.game.friends then
        pcall(function()
            serverCloud.game.friends:Get(uid, {
                ok = function(saved)
                    if saved and type(saved) == "table" then
                        data = saved
                        data.lastSync = _Now()
                    end
                end
            })
        end)
    end

    _friendCache[uid] = data
    return data
end

-- ============================================================================
-- 保存好友数据
-- ============================================================================
local function _SaveFriendData(uid, data)
    if not serverCloud or not serverCloud.game or not serverCloud.game.friends then
        return false
    end
    pcall(function()
        serverCloud.game.friends:Post(uid, data)
    end)
    return true
end

-- ============================================================================
-- 添加好友
-- ============================================================================
function FriendSystem.AddFriend(uid, friendUid, friendInfo)
    local data = _GetFriendData(uid)
    if not data then return false end

    -- 检查是否已在好友列表
    for _, f in ipairs(data.friends) do
        if f.uid == friendUid then
            print("[FriendSystem] 已是好友：" .. tostring(friendUid))
            return false
        end
    end

    -- 检查最大好友数限制
    local maxFriends = Config.Friends and Config.Friends.MaxFriends or 50
    if #data.friends >= maxFriends then
        print("[FriendSystem] 好友数已达上限")
        return false
    end

    table.insert(data.friends, {
        uid = friendUid,
        nickname = friendInfo and friendInfo.nickname or ("玩家" .. tostring(friendUid)),
        avatar = friendInfo and friendInfo.avatar or "A001",
        addedTime = _Now(),
        isOnline = false
    })

    _SaveFriendData(uid, data)
    print("[FriendSystem] 添加好友：" .. tostring(friendUid))
    return true
end

-- ============================================================================
-- 删除好友
-- ============================================================================
function FriendSystem.RemoveFriend(uid, friendUid)
    local data = _GetFriendData(uid)
    if not data then return false end

    for i = #data.friends, 1, -1 do
        if data.friends[i].uid == friendUid then
            table.remove(data.friends, i)
            _SaveFriendData(uid, data)
            print("[FriendSystem] 删除好友：" .. tostring(friendUid))
            return true
        end
    end
    return false
end

-- ============================================================================
-- 获取好友列表
-- ============================================================================
function FriendSystem.GetFriends(uid)
    local data = _GetFriendData(uid)
    if not data then return {} end

    -- 更新在线状态
    local timeout = Config.Friends and Config.Friends.OnlineTimeout or 300
    local now = _Now()
    for _, f in ipairs(data.friends) do
        local lastSeen = _onlineTimestamps[f.uid] or 0
        f.isOnline = (now - lastSeen) < timeout
    end

    return data.friends
end

-- ============================================================================
-- 检查是否为好友
-- ============================================================================
function FriendSystem.IsFriend(uid, friendUid)
    local friends = FriendSystem.GetFriends(uid)
    for _, f in ipairs(friends) do
        if f.uid == friendUid then return true end
    end
    return false
end

-- ============================================================================
-- 更新玩家在线状态
-- ============================================================================
function FriendSystem.UpdateOnlineStatus(uid, isOnline)
    _onlineTimestamps[uid] = _Now()
    print("[FriendSystem] 在线状态更新：" .. tostring(uid) .. " = " .. tostring(isOnline and "在线" or "离线"))
end

-- ============================================================================
-- 发送好友邀请
-- ============================================================================
function FriendSystem.SendInvite(fromUid, toUid, fromInfo)
    if FriendSystem.IsFriend(fromUid, toUid) then
        return false, "already_friends"
    end

    local targetData = _GetFriendData(toUid)
    if not targetData then return false, "load_failed" end

    -- 检查是否已有待处理邀请
    for _, inv in ipairs(targetData.pendingInvites) do
        if inv.fromUid == fromUid then
            return false, "already_pending"
        end
    end

    table.insert(targetData.pendingInvites, {
        fromUid = fromUid,
        nickname = fromInfo and fromInfo.nickname or ("玩家" .. tostring(fromUid)),
        avatar = fromInfo and fromInfo.avatar or "A001",
        time = _Now()
    })

    _SaveFriendData(toUid, targetData)
    print("[FriendSystem] 邀请已发送：" .. tostring(fromUid) .. " -> " .. tostring(toUid))
    return true
end

-- ============================================================================
-- 获取收到的邀请
-- ============================================================================
function FriendSystem.GetPendingInvites(uid)
    local data = _GetFriendData(uid)
    if not data then return {} end

    -- 过滤过期邀请
    local timeout = Config.Friends and Config.Friends.InviteExpire or 86400
    local now = _Now()
    local valid = {}
    for _, inv in ipairs(data.pendingInvites) do
        if (now - inv.time) < timeout then
            table.insert(valid, inv)
        end
    end

    if #valid ~= #data.pendingInvites then
        data.pendingInvites = valid
        _SaveFriendData(uid, data)
    end

    return valid
end

-- ============================================================================
-- 接受邀请
-- ============================================================================
function FriendSystem.AcceptInvite(uid, fromUid)
    local data = _GetFriendData(uid)
    if not data then return false end

    -- 从待处理列表中移除
    for i = #data.pendingInvites, 1, -1 do
        if data.pendingInvites[i].fromUid == fromUid then
            table.remove(data.pendingInvites, i)
            break
        end
    end

    _SaveFriendData(uid, data)

    -- 添加为双向好友
    FriendSystem.AddFriend(uid, fromUid)
    FriendSystem.AddFriend(fromUid, uid)

    -- 发布事件
    EventBus.Publish("friend_added", {
        uid = uid,
        friendUid = fromUid
    })

    return true
end

-- ============================================================================
-- 拒绝邀请
-- ============================================================================
function FriendSystem.RejectInvite(uid, fromUid)
    local data = _GetFriendData(uid)
    if not data then return false end

    for i = #data.pendingInvites, 1, -1 do
        if data.pendingInvites[i].fromUid == fromUid then
            table.remove(data.pendingInvites, i)
            break
        end
    end

    _SaveFriendData(uid, data)
    return true
end

-- ============================================================================
-- 获取在线好友数
-- ============================================================================
function FriendSystem.GetOnlineFriendCount(uid)
    local friends = FriendSystem.GetFriends(uid)
    local count = 0
    for _, f in ipairs(friends) do
        if f.isOnline then count = count + 1 end
    end
    return count
end

-- ============================================================================
-- 获取好友总数
-- ============================================================================
function FriendSystem.GetFriendCount(uid)
    local data = _GetFriendData(uid)
    return data and #data.friends or 0
end

-- ============================================================================
-- 邀请好友加入游戏房间
-- ============================================================================
function FriendSystem.InviteToRoom(uid, friendUid, roomInfo)
    if not FriendSystem.IsFriend(uid, friendUid) then
        return false, "not_friends"
    end

    print("[FriendSystem] 游戏邀请：" .. tostring(uid) .. " -> " .. tostring(friendUid))

    -- 发布邀请事件
    EventBus.Publish("friend_game_invite", {
        fromUid = uid,
        toUid = friendUid,
        roomId = roomInfo and roomInfo.roomId or "default",
        mode = roomInfo and roomInfo.mode or "standard"
    })

    return true
end

-- ============================================================================
-- 注册事件监听
-- ============================================================================
function FriendSystem.RegisterEvents()
    if not EventBus then return end

    EventBus.Subscribe(EventBus.Events.PLAYER_JOIN, function(data)
        if data and data.uid then
            FriendSystem.UpdateOnlineStatus(data.uid, true)
        end
    end, "FriendSystem")

    EventBus.Subscribe(EventBus.Events.PLAYER_LEAVE, function(data)
        if data and data.uid then
            FriendSystem.UpdateOnlineStatus(data.uid, false)
        end
    end, "FriendSystem")

    print("[FriendSystem] 事件监听已注册")
end

-- ============================================================================
-- 重置测试
-- ============================================================================
function FriendSystem.Reset(uid)
    if uid then
        _friendCache[uid] = nil
    else
        _friendCache = {}
        _onlineTimestamps = {}
    end
end

return FriendSystem
