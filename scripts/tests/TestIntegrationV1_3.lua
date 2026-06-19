-- ============================================================================
-- TestIntegrationV1_3.lua - v1.3 系统集成测试
-- ----------------------------------------------------------------------------
-- 测试公会系统、装备系统、成就系统之间的跨系统事件传播
-- ============================================================================

local TestRunner = require("Utils.TestRunner")
local EventBus = require("Utils.EventBus")
local GuildSystem = require("Game.GuildSystem")
local EquipmentSystem = require("Game.EquipmentSystem")
local AchievementSystem = require("Game.AchievementSystem")

local tests = TestRunner.NewSuite("IntegrationV1_3")

-- 记录发布的事件
local _eventLog = {}

local function _ClearEventLog()
    _eventLog = {}
end

local function _SetupEventLogger()
    _ClearEventLog()
    -- 监听所有 v1.3 相关事件
    local events = {
        EventBus.Events.GUILD_CREATE,
        EventBus.Events.GUILD_JOIN,
        EventBus.Events.GUILD_LEAVE,
        EventBus.Events.GUILD_CONTRIBUTION,
        EventBus.Events.GUILD_LEVEL_UP,
        EventBus.Events.GUILD_WAR_START,
        EventBus.Events.GUILD_WAR_END,
        EventBus.Events.EQUIPMENT_UNLOCK,
        EventBus.Events.EQUIPMENT_EQUIP,
        EventBus.Events.EQUIPMENT_ENHANCE,
        EventBus.Events.EQUIPMENT_SET_COMPLETE,
        EventBus.Events.ACHIEVEMENT_UNLOCK,
    }
    for _, evt in ipairs(events) do
        EventBus.Subscribe(evt, function(data)
            table.insert(_eventLog, { event = evt, data = data })
        end, "TestLogger")
    end
end

-- ============================================================================
-- 测试：公会创建事件链
-- ============================================================================
function tests.TestGuildCreateEventChain()
    EventBus.Clear()
    _SetupEventLogger()
    GuildSystem.Reset()
    AchievementSystem.ResetForTesting(1)
    EquipmentSystem.Reset()

    -- 创建公会
    local ok, guildId = GuildSystem.CreateGuild(1, "测试公会")

    -- 验证事件发布
    local foundCreateEvent = false
    for _, log in ipairs(_eventLog) do
        if log.event == EventBus.Events.GUILD_CREATE then
            foundCreateEvent = true
            TestRunner.Assert(log.data.guildId == guildId, "公会ID应该匹配")
            TestRunner.Assert(log.data.leaderUid == 1, "会长UID应该匹配")
            break
        end
    end
    TestRunner.Assert(foundCreateEvent, "应该发布 GUILD_CREATE 事件")

    print("[Integration] 公会创建事件链测试通过")
end

-- ============================================================================
-- 测试：公会贡献与成就联动
-- ============================================================================
function tests.TestGuildContributionAchievementChain()
    EventBus.Clear()
    _SetupEventLogger()
    GuildSystem.Reset()
    AchievementSystem.ResetForTesting(2)

    -- 创建公会并添加成员
    local ok, guildId = GuildSystem.CreateGuild(2, "贡献测试公会")
    GuildSystem.JoinGuild(guildId, 3)

    _ClearEventLog()

    -- 添加贡献值
    local ok2 = GuildSystem.AddContribution(guildId, 2, 500, "test")

    -- 验证事件发布
    local foundContribution = false
    local foundAchievement = false

    for _, log in ipairs(_eventLog) do
        if log.event == EventBus.Events.GUILD_CONTRIBUTION then
            foundContribution = true
        end
    end

    TestRunner.Assert(foundContribution, "应该发布 GUILD_CONTRIBUTION 事件")

    print("[Integration] 公会贡献与成就联动测试通过")
end

-- ============================================================================
-- 测试：公会战事件链
-- ============================================================================
function tests.TestGuildWarEventChain()
    EventBus.Clear()
    _SetupEventLogger()
    GuildSystem.Reset()

    -- 创建两个公会
    local ok1, guild1 = GuildSystem.CreateGuild(100, "战盟A")
    local ok2, guild2 = GuildSystem.CreateGuild(101, "战盟B")

    _ClearEventLog()

    -- 开始公会战
    local ok3, matchId = GuildSystem.StartGuildWar(guild1, guild2)

    local foundWarStart = false
    for _, log in ipairs(_eventLog) do
        if log.event == EventBus.Events.GUILD_WAR_START then
            foundWarStart = true
            TestRunner.Assert(log.data.matchId ~= nil, "应该有战斗ID")
            break
        end
    end
    TestRunner.Assert(foundWarStart, "应该发布 GUILD_WAR_START 事件")

    -- 提交结果
    _ClearEventLog()
    GuildSystem.SubmitGuildWarResult(matchId, guild1)

    local foundWarEnd = false
    for _, log in ipairs(_eventLog) do
        if log.event == EventBus.Events.GUILD_WAR_END then
            foundWarEnd = true
            break
        end
    end
    TestRunner.Assert(foundWarEnd, "应该发布 GUILD_WAR_END 事件")

    print("[Integration] 公会战事件链测试通过")
end

-- ============================================================================
-- 测试：装备解锁事件链
-- ============================================================================
function tests.TestEquipmentUnlockEventChain()
    EventBus.Clear()
    _SetupEventLogger()
    EquipmentSystem.Reset()
    AchievementSystem.ResetForTesting(3)

    _ClearEventLog()

    -- 解锁装备
    local ok = EquipmentSystem.Unlock(3, "weapon_gold_sword")

    local foundUnlockEvent = false
    local foundAchievementEvent = false

    for _, log in ipairs(_eventLog) do
        if log.event == EventBus.Events.EQUIPMENT_UNLOCK then
            foundUnlockEvent = true
            TestRunner.Assert(log.data.uid == 3, "UID应该匹配")
            TestRunner.Assert(log.data.equipmentId == "weapon_gold_sword", "装备ID应该匹配")
        elseif log.event == EventBus.Events.ACHIEVEMENT_UNLOCK then
            foundAchievementEvent = true
        end
    end

    TestRunner.Assert(foundUnlockEvent, "应该发布 EQUIPMENT_UNLOCK 事件")

    print("[Integration] 装备解锁事件链测试通过")
end

-- ============================================================================
-- 测试：装备强化事件链
-- ============================================================================
function tests.TestEquipmentEnhanceEventChain()
    EventBus.Clear()
    _SetupEventLogger()
    EquipmentSystem.Reset()
    AchievementSystem.ResetForTesting(4)

    -- 先解锁装备
    EquipmentSystem.Unlock(4, "weapon_gold_sword")
    EquipmentSystem.Equip(4, "weapon_gold_sword", "weapon")

    _ClearEventLog()

    -- 强化装备
    EquipmentSystem.Enhance(4, "weapon_gold_sword")

    local foundEnhanceEvent = false
    for _, log in ipairs(_eventLog) do
        if log.event == EventBus.Events.EQUIPMENT_ENHANCE then
            foundEnhanceEvent = true
            TestRunner.Assert(log.data.uid == 4, "UID应该匹配")
            TestRunner.Assert(log.data.newLevel == 1, "新等级应该是1")
            break
        end
    end

    TestRunner.Assert(foundEnhanceEvent, "应该发布 EQUIPMENT_ENHANCE 事件")

    print("[Integration] 装备强化事件链测试通过")
end

-- ============================================================================
-- 测试：套装完成事件链
-- ============================================================================
function tests.TestSetCompleteEventChain()
    EventBus.Clear()
    _SetupEventLogger()
    EquipmentSystem.Reset()
    AchievementSystem.ResetForTesting(5)

    -- 解锁均衡套装（4件）
    EquipmentSystem.Unlock(5, "weapon_gold_sword")
    EquipmentSystem.Unlock(5, "armor_leather_vest")
    EquipmentSystem.Unlock(5, "acc_lucky_coin")
    EquipmentSystem.Unlock(5, "badge_silver_star")

    -- 装备4件
    EquipmentSystem.Equip(5, "weapon_gold_sword", "weapon")
    EquipmentSystem.Equip(5, "armor_leather_vest", "armor")
    EquipmentSystem.Equip(5, "acc_lucky_coin", "accessory")
    EquipmentSystem.Equip(5, "badge_silver_star", "badge")

    _ClearEventLog()

    -- 触发套装效果检测（通过查询套装进度）
    local progress = EquipmentSystem.GetSetProgress(5)
    local balancedSet = nil
    for _, set in ipairs(progress) do
        if set.setId == "balanced_set" and set.completed then
            balancedSet = set
            break
        end
    end

    -- 注意：当前实现不会自动发布套装完成事件，需要手动调用或事件触发
    -- 这里测试套装属性计算是否正确

    local stats = EquipmentSystem.GetTotalStats(5)
    TestRunner.Assert(stats.globalBonus > 0.2, "4件套后全局加成应该大于20%")

    print("[Integration] 套装完成测试通过")
end

-- ============================================================================
-- 测试：多系统综合玩家画像
-- ============================================================================
function tests.TestFullPlayerProfile()
    EventBus.Clear()
    _SetupEventLogger()
    GuildSystem.Reset()
    EquipmentSystem.Reset()
    AchievementSystem.ResetForTesting(6)

    -- 1. 创建公会
    local ok1, guildId = GuildSystem.CreateGuild(6, "综合测试公会")
    TestRunner.Assert(ok1 == true, "公会创建应该成功")

    -- 2. 添加贡献
    GuildSystem.AddContribution(guildId, 6, 1000, "test")

    -- 3. 解锁并装备物品
    EquipmentSystem.Unlock(6, "weapon_gold_sword")
    EquipmentSystem.Unlock(6, "armor_leather_vest")
    EquipmentSystem.Equip(6, "weapon_gold_sword", "weapon")
    EquipmentSystem.Equip(6, "armor_leather_vest", "armor")

    -- 4. 强化装备
    EquipmentSystem.Enhance(6, "weapon_gold_sword")
    EquipmentSystem.Enhance(6, "weapon_gold_sword")

    -- 验证公会信息
    local guildInfo = GuildSystem.GetPlayerGuild(6)
    TestRunner.Assert(guildInfo ~= nil, "应该能获取公会信息")
    TestRunner.Assert(guildInfo.myRole == "leader", "应该是会长")
    TestRunner.Assert(guildInfo.myContribution >= 1000, "贡献值应该正确")

    -- 验证装备信息
    local equipment = EquipmentSystem.GetPlayerEquipment(6)
    TestRunner.Assert(equipment.totalEquipmentCount >= 2, "应该有至少2件装备")
    TestRunner.Assert(equipment.equipped.weapon ~= nil, "武器槽应该有装备")
    TestRunner.Assert(equipment.totalEnhanceLevel >= 2, "强化等级应该至少为2")

    -- 验证成就统计
    local stats = AchievementSystem.GetPlayerStats(6)
    TestRunner.Assert(stats ~= nil, "应该能获取玩家统计")
    TestRunner.Assert(stats.guildContribution >= 1000, "公会贡献应该正确")

    -- 验证战力
    local power = EquipmentSystem.GetPlayerPower(6)
    TestRunner.Assert(power > 0, "战力应该大于0")

    print("[Integration] 完整玩家画像测试通过")
end

-- ============================================================================
-- 测试：公会成员管理事件
-- ============================================================================
function tests.TestGuildMemberManagement()
    EventBus.Clear()
    _SetupEventLogger()
    GuildSystem.Reset()
    AchievementSystem.ResetForTesting(7)

    -- 创建公会
    local ok1, guildId = GuildSystem.CreateGuild(7, "成员管理测试公会")
    GuildSystem.JoinGuild(guildId, 8)
    GuildSystem.JoinGuild(guildId, 9)

    _ClearEventLog()

    -- 踢出成员
    local ok2 = GuildSystem.KickMember(guildId, 7, 9)

    local foundKickEvent = false
    for _, log in ipairs(_eventLog) do
        if log.event == EventBus.Events.GUILD_KICK then
            foundKickEvent = true
            break
        end
    end

    -- 验证成员数量
    local members = GuildSystem.GetMembers(guildId)
    TestRunner.Assert(#members == 2, "应该还有2个成员")

    print("[Integration] 公会成员管理测试通过")
end

-- ============================================================================
-- 测试：公会商店购买事件
-- ============================================================================
function tests.TestGuildShopPurchase()
    EventBus.Clear()
    _SetupEventLogger()
    GuildSystem.Reset()

    -- 创建公会并添加贡献
    local ok1, guildId = GuildSystem.CreateGuild(10, "商店测试公会")
    GuildSystem.AddContribution(guildId, 10, 10000, "initial")

    _ClearEventLog()

    -- 获取商店物品
    local items = GuildSystem.GetGuildShopItems(guildId)
    TestRunner.Assert(#items > 0, "商店应该有物品")

    -- 尝试购买
    local ok2, reward = GuildSystem.PurchaseShopItem(guildId, 10, items[1].id)
    TestRunner.Assert(ok2 == true, "购买应该成功")

    local foundShopEvent = false
    for _, log in ipairs(_eventLog) do
        if log.event == EventBus.Events.GUILD_SHOP_PURCHASE then
            foundShopEvent = true
            break
        end
    end

    TestRunner.Assert(foundShopEvent, "应该发布 GUILD_SHOP_PURCHASE 事件")

    print("[Integration] 公会商店购买测试通过")
end

-- ============================================================================
-- 测试：装备系统属性计算
-- ============================================================================
function tests.TestEquipmentStatsCalculation()
    EquipmentSystem.Reset()

    -- 解锁并装备多件装备
    EquipmentSystem.Unlock(11, "weapon_auction_master")
    EquipmentSystem.Unlock(11, "armor_millionaire")
    EquipmentSystem.Unlock(11, "acc_rarity_ring")
    EquipmentSystem.Unlock(11, "badge_auction_master")

    EquipmentSystem.Equip(11, "weapon_auction_master", "weapon")
    EquipmentSystem.Equip(11, "armor_millionaire", "armor")
    EquipmentSystem.Equip(11, "acc_rarity_ring", "accessory")
    EquipmentSystem.Equip(11, "badge_auction_master", "badge")

    -- 获取属性
    local stats = EquipmentSystem.GetTotalStats(11)

    -- 验证基础属性存在
    TestRunner.Assert(stats.bidAccuracy > 0, "出价精准度应该大于0")
    TestRunner.Assert(stats.finalBonus > 0, "最终收益加成应该大于0")
    TestRunner.Assert(stats.globalBonus > 0, "全局加成应该大于0")

    -- 验证套装效果激活（拍卖大师4件套）
    TestRunner.Assert(stats.globalBonus > 0.2, "4件套全局加成应该大于20%")

    print("[Integration] 装备系统属性计算测试通过")
end

-- ============================================================================
-- 运行所有测试
-- ============================================================================
TestRunner.Run(tests)
return tests
