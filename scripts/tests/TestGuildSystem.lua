-- ============================================================================
-- TestGuildSystem.lua - 公会系统单元测试（v1.3）
-- ============================================================================

local TestRunner = require("Utils.TestRunner")
local GuildSystem = require("Game.GuildSystem")

local tests = TestRunner.NewSuite("GuildSystem")

-- ============================================================================
-- 测试：创建公会
-- ============================================================================
function tests.TestCreateGuild()
    GuildSystem.Reset()

    local ok, guildId = GuildSystem.CreateGuild(1001, "测试公会", "测试公会描述")
    TestRunner.Assert(ok == true, "创建公会应该成功")
    TestRunner.Assert(type(guildId) == "string", "公会ID应该是字符串")
    TestRunner.Assert(string.match(guildId, "^GUILD_"), "公会ID应该以GUILD_开头")

    local info = GuildSystem.GetGuildInfo(guildId)
    TestRunner.Assert(info ~= nil, "应该能获取公会信息")
    TestRunner.Assert(info.name == "测试公会", "公会名称应该正确")
    TestRunner.Assert(info.leaderUid == 1001, "会长UID应该正确")
    TestRunner.Assert(info.level == 1, "初始等级应为1")
    TestRunner.Assert(info.memberCount == 1, "初始成员数应为1")

    print("[GuildSystem] 创建公会: " .. guildId)
end

-- ============================================================================
-- 测试：重复创建公会（失败）
-- ============================================================================
function tests.TestCreateDuplicateGuild()
    GuildSystem.Reset()

    local ok, id = GuildSystem.CreateGuild(2001, "公会A")
    TestRunner.Assert(ok == true, "第一次创建公会应该成功")

    local ok2, err = GuildSystem.CreateGuild(2001, "公会B")
    TestRunner.Assert(ok2 == false, "已在公会中的玩家再次创建应该失败")
    TestRunner.Assert(err == "already_in_guild", "错误应该是already_in_guild")

    print("[GuildSystem] 重复创建公会测试通过")
end

-- ============================================================================
-- 测试：加入公会
-- ============================================================================
function tests.TestJoinGuild()
    GuildSystem.Reset()

    local ok, guildId = GuildSystem.CreateGuild(3001, "加入测试公会")
    TestRunner.Assert(ok == true, "创建公会应该成功")

    local ok2 = GuildSystem.JoinGuild(guildId, 3002)
    TestRunner.Assert(ok2 == true, "加入公会应该成功")

    local info = GuildSystem.GetGuildInfo(guildId)
    TestRunner.Assert(info.memberCount == 2, "成员数应该增加到2")

    local playerInfo = GuildSystem.GetPlayerGuild(3002)
    TestRunner.Assert(playerInfo ~= nil, "玩家应该能获取公会信息")
    TestRunner.Assert(playerInfo.name == "加入测试公会", "公会名称应该正确")

    print("[GuildSystem] 加入公会测试通过")
end

-- ============================================================================
-- 测试：离开公会
-- ============================================================================
function tests.TestLeaveGuild()
    GuildSystem.Reset()

    local ok, guildId = GuildSystem.CreateGuild(4001, "离开测试公会")
    local ok2 = GuildSystem.JoinGuild(guildId, 4002)

    TestRunner.Assert(ok == true, "创建公会应该成功")
    TestRunner.Assert(ok2 == true, "加入公会应该成功")

    local ok3 = GuildSystem.LeaveGuild(4002)
    TestRunner.Assert(ok3 == true, "离开公会应该成功")

    local playerGuild = GuildSystem.GetPlayerGuild(4002)
    TestRunner.Assert(playerGuild == nil or playerGuild.guildId == nil or playerGuild.guildId ~= guildId,
        "玩家应该不再在该公会中")

    local info = GuildSystem.GetGuildInfo(guildId)
    TestRunner.Assert(info.memberCount == 1, "成员数应该减少到1")

    print("[GuildSystem] 离开公会测试通过")
end

-- ============================================================================
-- 测试：贡献值与等级提升
-- ============================================================================
function tests.TestContributionAndLevel()
    GuildSystem.Reset()

    local ok, guildId = GuildSystem.CreateGuild(5001, "升级测试公会")
    TestRunner.Assert(ok == true, "创建公会应该成功")

    -- 添加贡献值
    local ok2 = GuildSystem.AddContribution(guildId, 5001, 1000, "activity")
    TestRunner.Assert(ok2 == true, "添加贡献值应该成功")

    local contribution = GuildSystem.GetContribution(guildId, 5001)
    TestRunner.Assert(contribution >= 1000, "贡献值应该至少为1000")

    local levelInfo = GuildSystem.GetGuildLevel(guildId)
    TestRunner.Assert(levelInfo ~= nil, "应该能获取等级信息")
    TestRunner.Assert(levelInfo.level >= 1, "等级应该至少为1")

    print("[GuildSystem] 贡献值与等级测试通过 (当前等级: " .. levelInfo.level .. ")")
end

-- ============================================================================
-- 测试：每日签到
-- ============================================================================
function tests.TestDailySignIn()
    GuildSystem.Reset()

    local ok, guildId = GuildSystem.CreateGuild(6001, "签到测试公会")
    TestRunner.Assert(ok == true, "创建公会应该成功")

    local before = GuildSystem.GetContribution(guildId, 6001)

    local ok2 = GuildSystem.DailySignIn(guildId, 6001)
    TestRunner.Assert(ok2 == true, "签到应该成功")

    local after = GuildSystem.GetContribution(guildId, 6001)
    TestRunner.Assert(after > before, "签到后贡献值应该增加")

    print("[GuildSystem] 每日签到测试通过 (贡献值: " .. before .. " -> " .. after .. ")")
end

-- ============================================================================
-- 测试：公会战
-- ============================================================================
function tests.TestGuildWar()
    GuildSystem.Reset()

    local ok1, g1 = GuildSystem.CreateGuild(7001, "战盟A")
    local ok2, g2 = GuildSystem.CreateGuild(7002, "战盟B")
    TestRunner.Assert(ok1 and ok2, "创建两个公会应该成功")

    -- 开始公会战
    local ok3, matchId = GuildSystem.StartGuildWar(g1, g2)
    TestRunner.Assert(ok3 == true, "开始公会战应该成功")
    TestRunner.Assert(type(matchId) == "string", "应该返回战斗ID")

    -- 提交结果（g1胜利）
    local ok4 = GuildSystem.SubmitGuildWarResult(matchId, g1)
    TestRunner.Assert(ok4 == true, "提交结果应该成功")

    -- 获取战史
    local history = GuildSystem.GetGuildWarHistory(g1, 5)
    TestRunner.Assert(type(history) == "table", "应该能获取战史")
    TestRunner.Assert(#history >= 1, "战史中至少应有一条记录")

    print("[GuildSystem] 公会战测试通过 (match: " .. matchId .. ")")
end

-- ============================================================================
-- 测试：公会商店
-- ============================================================================
function tests.TestGuildShop()
    GuildSystem.Reset()

    local ok, guildId = GuildSystem.CreateGuild(8001, "商店测试公会")
    TestRunner.Assert(ok == true, "创建公会应该成功")

    -- 添加贡献值
    GuildSystem.AddContribution(guildId, 8001, 2000, "activity")

    -- 获取商店物品
    local items = GuildSystem.GetGuildShopItems(guildId)
    TestRunner.Assert(type(items) == "table", "应该能获取商店物品列表")
    TestRunner.Assert(#items > 0, "商店应该有物品")

    -- 购买物品
    local ok2, reward = GuildSystem.PurchaseShopItem(guildId, 8001, items[1].id)
    TestRunner.Assert(ok2 == true, "购买物品应该成功")
    TestRunner.Assert(reward ~= nil, "应该有奖励")

    print("[GuildSystem] 公会商店测试通过 (购买: " .. items[1].name .. ")")
end

-- ============================================================================
-- 测试：成员列表与排行榜
-- ============================================================================
function tests.TestMembersAndLeaderboard()
    GuildSystem.Reset()

    local ok, guildId = GuildSystem.CreateGuild(9001, "排行测试公会")
    TestRunner.Assert(ok == true, "创建公会应该成功")

    -- 加入成员
    GuildSystem.JoinGuild(guildId, 9002)
    GuildSystem.JoinGuild(guildId, 9003)
    GuildSystem.JoinGuild(guildId, 9004)

    -- 贡献值
    GuildSystem.AddContribution(guildId, 9002, 500, "activity")
    GuildSystem.AddContribution(guildId, 9003, 1500, "activity")
    GuildSystem.AddContribution(guildId, 9004, 800, "activity")

    -- 获取成员列表
    local members = GuildSystem.GetMembers(guildId)
    TestRunner.Assert(type(members) == "table", "应该能获取成员列表")
    TestRunner.Assert(#members == 4, "应该有4个成员")

    -- 验证按贡献值排序（9003 > 9004 > 9002）
    TestRunner.Assert(members[1].personalContribution >= members[2].personalContribution,
        "成员应该按贡献值降序排列")

    -- 获取公会排行榜
    local lb = GuildSystem.GetGuildLeaderboard(10)
    TestRunner.Assert(type(lb) == "table", "应该能获取排行榜")
    TestRunner.Assert(#lb >= 1, "排行榜中至少应有一个公会")

    print("[GuildSystem] 成员列表与排行榜测试通过 (成员数: " .. #members .. ")")
end

-- ============================================================================
-- 测试：可用公会列表
-- ============================================================================
function tests.TestAvailableGuilds()
    GuildSystem.Reset()

    GuildSystem.CreateGuild(1101, "公会Alpha")
    GuildSystem.CreateGuild(1102, "公会Beta")
    GuildSystem.CreateGuild(1103, "公会Gamma")

    -- 新玩家可以看到可用公会
    local available = GuildSystem.GetAvailableGuilds(9999, 10)
    TestRunner.Assert(type(available) == "table", "应该能获取可用公会列表")
    TestRunner.Assert(#available == 3, "应该能看到3个公会")

    -- 已有公会的玩家看不到列表
    local empty = GuildSystem.GetAvailableGuilds(1101, 10)
    TestRunner.Assert(#empty == 0, "有公会的玩家不应该看到列表")

    print("[GuildSystem] 可用公会列表测试通过")
end

-- ============================================================================
-- 测试：踢出成员
-- ============================================================================
function tests.TestKickMember()
    GuildSystem.Reset()

    local ok, guildId = GuildSystem.CreateGuild(1201, "踢人测试公会")
    TestRunner.Assert(ok == true, "创建公会应该成功")

    GuildSystem.JoinGuild(guildId, 1202)
    GuildSystem.JoinGuild(guildId, 1203)

    local infoBefore = GuildSystem.GetGuildInfo(guildId)
    TestRunner.Assert(infoBefore.memberCount == 3, "踢人前应有3个成员")

    local ok2 = GuildSystem.KickMember(guildId, 1201, 1202)
    TestRunner.Assert(ok2 == true, "踢出成员应该成功")

    local infoAfter = GuildSystem.GetGuildInfo(guildId)
    TestRunner.Assert(infoAfter.memberCount == 2, "踢人后应有2个成员")

    print("[GuildSystem] 踢出成员测试通过")
end

-- ============================================================================
-- 测试：系统统计
-- ============================================================================
function tests.TestStats()
    GuildSystem.Reset()

    GuildSystem.CreateGuild(1301, "统计公会1")
    GuildSystem.CreateGuild(1302, "统计公会2")

    local stats = GuildSystem.GetStats()
    TestRunner.Assert(type(stats) == "table", "应该能获取统计信息")
    TestRunner.Assert(stats.guildCount == 2, "应该有2个公会")
    TestRunner.Assert(stats.totalMembers == 2, "应该有2个总成员")

    print("[GuildSystem] 系统统计测试通过 (公会数: " .. stats.guildCount .. ")")
end

-- ============================================================================
-- 运行所有测试
-- ============================================================================
TestRunner.Run(tests)
return tests
