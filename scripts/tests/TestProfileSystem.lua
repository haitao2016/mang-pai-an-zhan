-- ============================================================================
-- TestProfileSystem.lua - 个人资料系统单元测试（v1.1）
-- ============================================================================

local TestRunner = require("Utils.TestRunner")
local ProfileSystem = require("Game.ProfileSystem")

local tests = TestRunner.NewSuite("ProfileSystem")

-- ============================================================================
-- 测试：获取所有头像
-- ============================================================================
function tests.TestGetAllAvatars()
    local avatars = ProfileSystem.GetAllAvatars(1)
    TestRunner.Assert(type(avatars) == "table", "应该能获取头像列表")

    for _, avatar in ipairs(avatars) do
        TestRunner.Assert(avatar.id ~= nil, "头像应有ID")
    end

    print("[ProfileSystem] 获取头像测试通过 (数量: " .. #avatars .. ")")
end

-- ============================================================================
-- 测试：选择头像
-- ============================================================================
function tests.TestSelectAvatar()
    local avatars = ProfileSystem.GetAllAvatars(2)
    TestRunner.Assert(#avatars > 0, "至少应有一个头像")

    local firstAvatar = avatars[1]
    local ok = ProfileSystem.SelectAvatar(2, firstAvatar.id)

    local current = ProfileSystem.GetCurrentAvatar(2)
    TestRunner.Assert(current ~= nil, "当前头像不应为空")
    TestRunner.Assert(current.id == firstAvatar.id, "当前头像应该正确")

    print("[ProfileSystem] 选择头像测试通过 (头像: " .. firstAvatar.id .. ")")
end

-- ============================================================================
-- 测试：获取当前头像
-- ============================================================================
function tests.TestGetCurrentAvatar()
    local current = ProfileSystem.GetCurrentAvatar(3)
    TestRunner.Assert(current ~= nil, "应该能获取当前头像")
    TestRunner.Assert(current.id ~= nil, "当前头像应有ID")

    print("[ProfileSystem] 获取当前头像测试通过")
end

-- ============================================================================
-- 测试：获取所有称号
-- ============================================================================
function tests.TestGetAllTitles()
    local titles = ProfileSystem.GetAllTitles(4)
    TestRunner.Assert(type(titles) == "table", "应该能获取称号列表")

    for _, title in ipairs(titles) do
        TestRunner.Assert(title.id ~= nil, "称号应有ID")
    end

    print("[ProfileSystem] 获取称号测试通过 (数量: " .. #titles .. ")")
end

-- ============================================================================
-- 测试：解锁称号
-- ============================================================================
function tests.TestUnlockTitle()
    local titles = ProfileSystem.GetAllTitles(5)
    local firstTitle = nil

    for _, title in ipairs(titles) do
        firstTitle = title
        break
    end

    TestRunner.Assert(firstTitle ~= nil, "至少应有一个称号")

    local ok = ProfileSystem.UnlockTitle(5, firstTitle.id)

    print("[ProfileSystem] 解锁称号测试通过 (称号: " .. firstTitle.id .. ")")
end

-- ============================================================================
-- 测试：选择称号
-- ============================================================================
function tests.TestSelectTitle()
    local titles = ProfileSystem.GetAllTitles(6)
    TestRunner.Assert(#titles > 0, "至少应有一个称号")

    local firstTitle = titles[1]
    local ok = ProfileSystem.SelectTitle(6, firstTitle.id)

    local current = ProfileSystem.GetCurrentTitle(6)
    TestRunner.Assert(current ~= nil, "当前称号不应为空")

    print("[ProfileSystem] 选择称号测试通过")
end

-- ============================================================================
-- 测试：获取当前称号
-- ============================================================================
function tests.TestGetCurrentTitle()
    local current = ProfileSystem.GetCurrentTitle(7)
    TestRunner.Assert(current ~= nil, "应该能获取当前称号")

    print("[ProfileSystem] 获取当前称号测试通过")
end

-- ============================================================================
-- 测试：获取完整个人资料
-- ============================================================================
function tests.TestGetProfile()
    local profile = ProfileSystem.GetProfile(8)
    TestRunner.Assert(type(profile) == "table", "应该能获取个人资料")
    TestRunner.Assert(profile.uid ~= nil, "资料应有UID")
    TestRunner.Assert(profile.avatar ~= nil, "资料应有头像")
    TestRunner.Assert(profile.title ~= nil, "资料应有称号")

    print("[ProfileSystem] 获取完整资料测试通过")
end

-- ============================================================================
-- 测试：设置昵称
-- ============================================================================
function tests.TestSetNickname()
    local ok = ProfileSystem.SetNickname(9, "测试玩家")
    TestRunner.Assert(ok == true, "设置昵称应该成功")

    local profile = ProfileSystem.GetProfile(9)
    TestRunner.Assert(profile.nickname == "测试玩家", "昵称应该正确")

    print("[ProfileSystem] 设置昵称测试通过 (昵称: 测试玩家)")
end

-- ============================================================================
-- 测试：重置
-- ============================================================================
function tests.TestReset()
    ProfileSystem.SelectAvatar(10, "test_avatar")
    ProfileSystem.SetNickname(10, "测试昵称")

    ProfileSystem.Reset(10)

    local profile = ProfileSystem.GetProfile(10)
    TestRunner.Assert(profile ~= nil, "重置后应该仍能获取资料")

    print("[ProfileSystem] 重置测试通过")
end

-- ============================================================================
-- 测试：完整的资料设置流程
-- ============================================================================
function tests.TestFullProfileSetup()
    local uid = 11

    -- 获取所有头像并选择
    local avatars = ProfileSystem.GetAllAvatars(uid)
    if #avatars > 0 then
        ProfileSystem.SelectAvatar(uid, avatars[1].id)
    end

    -- 获取所有称号并选择
    local titles = ProfileSystem.GetAllTitles(uid)
    if #titles > 0 then
        ProfileSystem.SelectTitle(uid, titles[1].id)
    end

    -- 设置昵称
    ProfileSystem.SetNickname(uid, "完整资料玩家")

    -- 获取完整资料验证
    local profile = ProfileSystem.GetProfile(uid)
    TestRunner.Assert(profile.uid == 11, "UID应该正确")
    TestRunner.Assert(profile.nickname == "完整资料玩家", "昵称应该正确")

    print("[ProfileSystem] 完整资料设置测试通过")
end

-- ============================================================================
-- 运行所有测试
-- ============================================================================
TestRunner.Run(tests)
return tests
