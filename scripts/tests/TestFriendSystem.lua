-- ============================================================================
-- TestFriendSystem.lua - 好友系统单元测试
-- ============================================================================

local TestRunner = require("Utils.TestRunner")
local FriendSystem = require("Game.FriendSystem")

local tests = TestRunner.NewSuite("FriendSystem")

-- ============================================================================
-- 测试：添加好友
-- ============================================================================
function tests.TestAddFriend()
    -- 重置测试数据
    FriendSystem.Reset("test_user_001")

    local ok = FriendSystem.AddFriend("test_user_001", "test_user_002", { nickname = "测试玩家2" })
    TestRunner.Assert(ok == true, "Should successfully add friend")

    print("[FriendSystem] 添加好友测试通过")
end

-- ============================================================================
-- 测试：检查好友关系
-- ============================================================================
function tests.TestIsFriend()
    local isFriend = FriendSystem.IsFriend("test_user_001", "test_user_002")
    TestRunner.Assert(isFriend == true, "Should be friends")

    local notFriend = FriendSystem.IsFriend("test_user_001", "test_user_999")
    TestRunner.Assert(notFriend == false, "Should NOT be friends")

    print("[FriendSystem] 好友关系检查通过")
end

-- ============================================================================
-- 测试：获取好友列表
-- ============================================================================
function tests.TestGetFriends()
    local friends = FriendSystem.GetFriends("test_user_001")
    TestRunner.Assert(type(friends) == "table", "Should return table")
    TestRunner.Assert(#friends >= 1, "Should have at least 1 friend")

    print("[FriendSystem] 好友数量: " .. #friends)
end

-- ============================================================================
-- 测试：删除好友
-- ============================================================================
function tests.TestRemoveFriend()
    local ok = FriendSystem.AddFriend("test_user_001", "test_user_003", { nickname = "测试玩家3" })
    TestRunner.Assert(ok == true, "Should add friend first")

    local removed = FriendSystem.RemoveFriend("test_user_001", "test_user_003")
    TestRunner.Assert(removed == true, "Should successfully remove friend")

    local stillThere = FriendSystem.IsFriend("test_user_001", "test_user_003")
    TestRunner.Assert(stillThere == false, "Friend should be removed")

    print("[FriendSystem] 删除好友测试通过")
end

-- ============================================================================
-- 测试：在线状态
-- ============================================================================
function tests.TestOnlineStatus()
    FriendSystem.UpdateOnlineStatus("test_user_001", true)
    FriendSystem.UpdateOnlineStatus("test_user_002", false)

    local friends = FriendSystem.GetFriends("test_user_001")
    TestRunner.Assert(type(friends) == "table", "Should return friends list")

    print("[FriendSystem] 在线状态测试通过")
end

-- ============================================================================
-- 测试：好友数量限制
-- ============================================================================
function tests.TestMaxFriendsLimit()
    -- 重置
    FriendSystem.Reset("test_user_limit")

    -- 尝试添加超过上限的好友（假设上限 50）
    for i = 1, 55 do
        FriendSystem.AddFriend("test_user_limit", "friend_" .. i, { nickname = "朋友" .. i })
    end

    local count = FriendSystem.GetFriendCount("test_user_limit")
    TestRunner.Assert(count <= 50, "Should not exceed max friends limit (50)")

    print("[FriendSystem] 好友数量上限测试: " .. count)
end

-- ============================================================================
-- 测试：发送邀请
-- ============================================================================
function tests.TestSendInvite()
    FriendSystem.Reset("invite_sender")
    FriendSystem.Reset("invite_receiver")

    local ok, err = FriendSystem.SendInvite("invite_sender", "invite_receiver", { nickname = "发送者" })
    TestRunner.Assert(ok == true, "Should send invite successfully")

    print("[FriendSystem] 邀请发送测试通过")
end

-- ============================================================================
-- 测试：获取待处理邀请
-- ============================================================================
function tests.TestGetPendingInvites()
    local invites = FriendSystem.GetPendingInvites("invite_receiver")
    TestRunner.Assert(type(invites) == "table", "Should return table")
    TestRunner.Assert(#invites >= 1, "Should have pending invite")

    print("[FriendSystem] 待处理邀请数: " .. #invites)
end

-- ============================================================================
-- 测试：接受邀请
-- ============================================================================
function tests.TestAcceptInvite()
    local ok = FriendSystem.AcceptInvite("invite_receiver", "invite_sender")
    TestRunner.Assert(ok == true, "Should accept invite successfully")

    local isFriend = FriendSystem.IsFriend("invite_receiver", "invite_sender")
    TestRunner.Assert(isFriend == true, "Should now be friends")

    print("[FriendSystem] 接受邀请测试通过")
end

-- ============================================================================
-- 测试：拒绝邀请
-- ============================================================================
function tests.TestRejectInvite()
    -- 先发送一个新邀请
    FriendSystem.SendInvite("reject_sender", "reject_receiver", { nickname = "拒绝发送者" })

    local ok = FriendSystem.RejectInvite("reject_receiver", "reject_sender")
    TestRunner.Assert(ok == true, "Should reject invite successfully")

    print("[FriendSystem] 拒绝邀请测试通过")
end

-- ============================================================================
-- 测试：邀请加入房间
-- ============================================================================
function tests.TestInviteToRoom()
    -- 先添加好友
    FriendSystem.AddFriend("room_host", "room_guest", { nickname = "房间客人" })

    local ok, err = FriendSystem.InviteToRoom("room_host", "room_guest", {
        roomId = "ROOM_123",
        mode = "standard"
    })
    TestRunner.Assert(ok == true, "Should send room invite")

    print("[FriendSystem] 房间邀请测试通过")
end

-- ============================================================================
-- 测试：在线好友数
-- ============================================================================
function tests.TestGetOnlineFriendCount()
    FriendSystem.UpdateOnlineStatus("online_friend_1", true)
    FriendSystem.UpdateOnlineStatus("online_friend_2", true)
    FriendSystem.UpdateOnlineStatus("offline_friend", false)

    local count = FriendSystem.GetOnlineFriendCount("test_user_001")
    TestRunner.Assert(type(count) == "number", "Should return number")

    print("[FriendSystem] 在线好友数: " .. count)
end

-- ============================================================================
-- 运行所有测试
-- ============================================================================
TestRunner.Run(tests)

return tests
