-- ============================================================================
-- TestRoomSystem.lua - 房间系统单元测试
-- ============================================================================

local TestRunner = require("Utils.TestRunner")
local RoomSystem = require("Game.RoomSystem")

local tests = TestRunner.NewSuite("RoomSystem")

-- ============================================================================
-- 测试：创建房间
-- ============================================================================
function tests.TestCreateRoom()
    RoomSystem.Reset()

    local ok, roomId, inviteCode = RoomSystem.CreateRoom("host_001", {
        name = "测试房间",
        rounds = 3,
        maxPlayers = 4
    })

    TestRunner.Assert(ok == true, "Should create room successfully")
    TestRunner.Assert(roomId ~= nil, "Should return roomId")
    TestRunner.Assert(inviteCode ~= nil, "Should return inviteCode")
    TestRunner.Assert(string.len(inviteCode) == 6, "Invite code should be 6 chars")

    print("[RoomSystem] 创建房间测试通过: " .. roomId)
end

-- ============================================================================
-- 测试：加入房间
-- ============================================================================
function tests.TestJoinRoom()
    RoomSystem.Reset()
    RoomSystem.CreateRoom("host_001")

    local ok, room = RoomSystem.JoinRoom("player_002", "ROOM_000001")
    TestRunner.Assert(ok == true, "Should join room successfully")
    TestRunner.Assert(room ~= nil, "Should return room data")

    print("[RoomSystem] 加入房间测试通过")
end

-- ============================================================================
-- 测试：房间人数限制
-- ============================================================================
function tests.TestMaxPlayers()
    RoomSystem.Reset()
    RoomSystem.CreateRoom("host_001", { maxPlayers = 2 })

    RoomSystem.JoinRoom("player_002", "ROOM_000001")
    local ok = RoomSystem.JoinRoom("player_003", "ROOM_000001")

    TestRunner.Assert(ok == false, "Should not allow more than max players")

    print("[RoomSystem] 人数限制测试通过")
end

-- ============================================================================
-- 测试：离开房间
-- ============================================================================
function tests.TestLeaveRoom()
    RoomSystem.Reset()
    RoomSystem.CreateRoom("host_001")
    RoomSystem.JoinRoom("player_002", "ROOM_000001")

    local ok = RoomSystem.LeaveRoom("player_002")
    TestRunner.Assert(ok == true, "Should leave room successfully")

    local playerRoom = RoomSystem.GetPlayerRoom("player_002")
    TestRunner.Assert(playerRoom == nil, "Should not be in any room after leaving")

    print("[RoomSystem] 离开房间测试通过")
end

-- ============================================================================
-- 测试：房间信息获取
-- ============================================================================
function tests.TestGetRoomInfo()
    RoomSystem.Reset()
    RoomSystem.CreateRoom("host_001", { name = "测试房间", rounds = 3 })

    local info = RoomSystem.GetRoomInfo("ROOM_000001")
    TestRunner.Assert(info ~= nil, "Should return room info")
    TestRunner.Assert(info.name == "测试房间", "Should have correct name")
    TestRunner.Assert(info.rules.rounds == 3, "Should have correct rounds")
    TestRunner.Assert(info.playerCount == 1, "Should have 1 player")

    print("[RoomSystem] 房间信息测试通过")
end

-- ============================================================================
-- 测试：准备状态
-- ============================================================================
function tests.TestReadyStatus()
    RoomSystem.Reset()
    RoomSystem.CreateRoom("host_001")
    RoomSystem.JoinRoom("player_002", "ROOM_000001")

    local ok = RoomSystem.SetReady("player_002", true)
    TestRunner.Assert(ok == true, "Should set ready successfully")

    local room = RoomSystem.GetRoomInfo("ROOM_000001")
    TestRunner.Assert(room ~= nil, "Should get room info")

    print("[RoomSystem] 准备状态测试通过")
end

-- ============================================================================
-- 测试：房主转移
-- ============================================================================
function tests.TestHostTransfer()
    RoomSystem.Reset()
    RoomSystem.CreateRoom("host_001")
    RoomSystem.JoinRoom("player_002", "ROOM_000001")

    RoomSystem.LeaveRoom("host_001")

    local room = RoomSystem.GetRoomInfo("ROOM_000001")
    TestRunner.Assert(room.hostUid == "player_002", "Host should transfer to player_002")

    print("[RoomSystem] 房主转移测试通过")
end

-- ============================================================================
-- 测试：密码保护
-- ============================================================================
function tests.TestPassword()
    RoomSystem.Reset()
    RoomSystem.CreateRoom("host_001", { password = "123456" })

    local ok = RoomSystem.JoinRoom("player_002", "ROOM_000001", "wrong")
    TestRunner.Assert(ok == false, "Should not join with wrong password")

    ok = RoomSystem.JoinRoom("player_002", "ROOM_000001", "123456")
    TestRunner.Assert(ok == true, "Should join with correct password")

    print("[RoomSystem] 密码保护测试通过")
end

-- ============================================================================
-- 测试：邀请码加入
-- ============================================================================
function tests.TestInviteCodeJoin()
    RoomSystem.Reset()
    local _, _, inviteCode = RoomSystem.CreateRoom("host_001")

    RoomSystem.LeaveRoom("host_001")
    RoomSystem.CreateRoom("host_002")

    local ok = RoomSystem.JoinRoom("player_001", inviteCode)
    TestRunner.Assert(ok == true, "Should join via invite code")

    print("[RoomSystem] 邀请码测试通过: " .. inviteCode)
end

-- ============================================================================
-- 测试：获取等待中的房间列表
-- ============================================================================
function tests.TestGetWaitingRooms()
    RoomSystem.Reset()
    RoomSystem.CreateRoom("host_001", { name = "房间1" })
    RoomSystem.CreateRoom("host_002", { name = "房间2" })

    local rooms = RoomSystem.GetWaitingRooms()
    TestRunner.Assert(#rooms >= 2, "Should list waiting rooms")

    print("[RoomSystem] 房间列表测试通过，共 " .. #rooms .. " 个房间")
end

-- ============================================================================
-- 测试：角色选择
-- ============================================================================
function tests.TestSelectCharacter()
    RoomSystem.Reset()
    RoomSystem.CreateRoom("host_001")
    RoomSystem.JoinRoom("player_002", "ROOM_000001")

    local ok = RoomSystem.SelectCharacter("player_002", "budget_master")
    TestRunner.Assert(ok == true, "Should select character successfully")

    print("[RoomSystem] 角色选择测试通过")
end

-- ============================================================================
-- 运行所有测试
-- ============================================================================
TestRunner.Run(tests)

return tests
