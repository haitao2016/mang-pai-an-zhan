-- ============================================================================
-- TestEquipmentSystem.lua - 装备系统单元测试（v1.3）
-- ============================================================================

local TestRunner = require("Utils.TestRunner")
local EquipmentSystem = require("Game.EquipmentSystem")

local tests = TestRunner.NewSuite("EquipmentSystem")

-- ============================================================================
-- 测试：解锁装备
-- ============================================================================
function tests.TestUnlockEquipment()
    EquipmentSystem.Reset()

    local ok, err = EquipmentSystem.Unlock(1, "weapon_basic_hammer")
    TestRunner.Assert(ok == true, "解锁装备应该成功")

    local ok2 = EquipmentSystem.IsUnlocked(1, "weapon_basic_hammer")
    TestRunner.Assert(ok2 == true, "装备应该已解锁")

    local ok3, err3 = EquipmentSystem.Unlock(1, "weapon_basic_hammer")
    TestRunner.Assert(ok3 == false, "重复解锁应该失败")
    TestRunner.Assert(err3 == "already_unlocked", "错误应该是 already_unlocked")

    local ok4, err4 = EquipmentSystem.Unlock(1, "nonexistent_item")
    TestRunner.Assert(ok4 == false, "不存在的装备应该解锁失败")
    TestRunner.Assert(err4 == "equipment_not_found", "错误应该是 equipment_not_found")

    print("[EquipmentSystem] 解锁装备测试通过")
end

-- ============================================================================
-- 测试：装备物品
-- ============================================================================
function tests.TestEquip()
    EquipmentSystem.Reset()

    -- 未解锁时不能装备
    local ok, err = EquipmentSystem.Equip(2, "weapon_basic_hammer", "weapon")
    TestRunner.Assert(ok == false, "未解锁不能装备")
    TestRunner.Assert(err == "not_unlocked", "错误应该是 not_unlocked")

    -- 解锁后装备
    EquipmentSystem.Unlock(2, "weapon_basic_hammer")
    local ok2 = EquipmentSystem.Equip(2, "weapon_basic_hammer", "weapon")
    TestRunner.Assert(ok2 == true, "装备应该成功")

    -- 验证装备上了
    local equipped = EquipmentSystem.GetEquipped(2, "weapon")
    TestRunner.Assert(equipped == "weapon_basic_hammer", "槽位应该装备正确")

    -- 槽位不匹配
    EquipmentSystem.Unlock(2, "armor_basic_cloak")
    local ok3, err3 = EquipmentSystem.Equip(2, "armor_basic_cloak", "weapon")
    TestRunner.Assert(ok3 == false, "槽位不匹配应该失败")
    TestRunner.Assert(err3 == "slot_mismatch", "错误应该是 slot_mismatch")

    print("[EquipmentSystem] 装备物品测试通过")
end

-- ============================================================================
-- 测试：卸下装备
-- ============================================================================
function tests.TestUnequip()
    EquipmentSystem.Reset()

    -- 空槽位卸下失败
    local ok, err = EquipmentSystem.Unequip(3, "weapon")
    TestRunner.Assert(ok == false, "空槽位卸下应该失败")
    TestRunner.Assert(err == "slot_empty", "错误应该是 slot_empty")

    -- 装备后卸下
    EquipmentSystem.Unlock(3, "weapon_basic_hammer")
    EquipmentSystem.Equip(3, "weapon_basic_hammer", "weapon")

    local ok2 = EquipmentSystem.Unequip(3, "weapon")
    TestRunner.Assert(ok2 == true, "卸下应该成功")

    local equipped = EquipmentSystem.GetEquipped(3, "weapon")
    TestRunner.Assert(equipped == nil, "槽位应该为空")

    print("[EquipmentSystem] 卸下装备测试通过")
end

-- ============================================================================
-- 测试：获取所有已装备物品
-- ============================================================================
function tests.TestGetAllEquipped()
    EquipmentSystem.Reset()

    -- 装备多个槽位
    EquipmentSystem.Unlock(4, "weapon_basic_hammer")
    EquipmentSystem.Unlock(4, "armor_basic_cloak")
    EquipmentSystem.Unlock(4, "acc_lucky_coin")
    EquipmentSystem.Unlock(4, "badge_bronze_star")

    EquipmentSystem.Equip(4, "weapon_basic_hammer", "weapon")
    EquipmentSystem.Equip(4, "armor_basic_cloak", "armor")
    EquipmentSystem.Equip(4, "acc_lucky_coin", "accessory")
    EquipmentSystem.Equip(4, "badge_bronze_star", "badge")

    local allEquipped = EquipmentSystem.GetAllEquipped(4)
    TestRunner.Assert(allEquipped["weapon"] ~= nil, "武器槽应该有装备")
    TestRunner.Assert(allEquipped["armor"] ~= nil, "防具槽应该有装备")
    TestRunner.Assert(allEquipped["accessory"] ~= nil, "饰品槽应该有装备")
    TestRunner.Assert(allEquipped["badge"] ~= nil, "徽章槽应该有装备")

    local count = EquipmentSystem.GetEquippedCount(4)
    TestRunner.Assert(count == 4, "应该有4个已装备槽位")

    print("[EquipmentSystem] 获取所有已装备物品测试通过")
end

-- ============================================================================
-- 测试：强化装备
-- ============================================================================
function tests.TestEnhance()
    EquipmentSystem.Reset()

    EquipmentSystem.Unlock(5, "weapon_basic_hammer")

    -- 初始强化等级为0
    local level0 = EquipmentSystem.GetEnhanceLevel(5, "weapon_basic_hammer")
    TestRunner.Assert(level0 == 0, "初始强化等级应该是0")

    -- 强化
    local ok, err = EquipmentSystem.Enhance(5, "weapon_basic_hammer")
    TestRunner.Assert(ok == true, "强化应该成功")

    local level1 = EquipmentSystem.GetEnhanceLevel(5, "weapon_basic_hammer")
    TestRunner.Assert(level1 == 1, "强化后等级应该是1")

    -- 继续强化
    EquipmentSystem.Enhance(5, "weapon_basic_hammer")
    EquipmentSystem.Enhance(5, "weapon_basic_hammer")
    local level3 = EquipmentSystem.GetEnhanceLevel(5, "weapon_basic_hammer")
    TestRunner.Assert(level3 == 3, "强化后等级应该是3")

    -- 强化不存在的装备
    local ok2, err2 = EquipmentSystem.Enhance(5, "nonexistent")
    TestRunner.Assert(ok2 == false, "强化不存在的装备应该失败")

    print("[EquipmentSystem] 强化装备测试通过 (当前等级: " .. level3 .. ")")
end

-- ============================================================================
-- 测试：强化费用计算
-- ============================================================================
function tests.TestEnhanceCost()
    EquipmentSystem.Reset()

    local cost0 = EquipmentSystem.GetEnhanceCost("weapon_basic_hammer", 0)
    local cost1 = EquipmentSystem.GetEnhanceCost("weapon_basic_hammer", 1)
    local cost2 = EquipmentSystem.GetEnhanceCost("weapon_basic_hammer", 2)

    TestRunner.Assert(cost0 > 0, "0级强化费用应该大于0")
    TestRunner.Assert(cost1 > cost0, "1级强化费用应该大于0级")
    TestRunner.Assert(cost2 > cost1, "2级强化费用应该大于1级")

    print("[EquipmentSystem] 强化费用测试通过 (Lv0: " .. cost0 .. ", Lv1: " .. cost1 .. ", Lv2: " .. cost2 .. ")")
end

-- ============================================================================
-- 测试：强化成功率
-- ============================================================================
function tests.TestEnhanceSuccessRate()
    EquipmentSystem.Reset()

    local rate0 = EquipmentSystem.GetEnhanceSuccessRate(0)
    local rate5 = EquipmentSystem.GetEnhanceSuccessRate(5)
    local rate9 = EquipmentSystem.GetEnhanceSuccessRate(9)

    TestRunner.Assert(rate0 > 0.8, "0级成功率应该大于80%")
    TestRunner.Assert(rate5 > 0, "5级成功率应该大于0")
    TestRunner.Assert(rate9 > 0.5, "9级成功率应该大于50%")
    TestRunner.Assert(rate5 < rate0, "5级成功率应该小于0级")

    print("[EquipmentSystem] 强化成功率测试通过 (Lv0: " .. rate0 .. ", Lv5: " .. rate5 .. ", Lv9: " .. rate9 .. ")")
end

-- ============================================================================
-- 测试：属性计算
-- ============================================================================
function tests.TestGetTotalStats()
    EquipmentSystem.Reset()

    -- 无装备时属性为0
    local stats0 = EquipmentSystem.GetTotalStats(6)
    TestRunner.Assert(stats0.bidAccuracy == 0, "无装备时出价精准度应为0")

    -- 装备后属性增加
    EquipmentSystem.Unlock(6, "weapon_gold_sword")
    EquipmentSystem.Equip(6, "weapon_gold_sword", "weapon")

    local stats1 = EquipmentSystem.GetTotalStats(6)
    TestRunner.Assert(stats1.bidAccuracy > 0, "装备后出价精准度应该大于0")
    TestRunner.Assert(stats1.finalBonus > 0, "装备后最终收益加成应该大于0")

    print("[EquipmentSystem] 属性计算测试通过 (bidAccuracy: " .. stats1.bidAccuracy .. ")")
end

-- ============================================================================
-- 测试：强化后属性提升
-- ============================================================================
function tests.TestEnhanceStatsIncrease()
    EquipmentSystem.Reset()

    EquipmentSystem.Unlock(7, "weapon_gold_sword")
    EquipmentSystem.Equip(7, "weapon_gold_sword", "weapon")

    local statsBefore = EquipmentSystem.GetTotalStats(7)

    -- 强化到5级
    for i = 1, 5 do
        EquipmentSystem.Enhance(7, "weapon_gold_sword")
    end

    local statsAfter = EquipmentSystem.GetTotalStats(7)
    TestRunner.Assert(statsAfter.bidAccuracy > statsBefore.bidAccuracy,
        "强化后出价精准度应该提升")
    TestRunner.Assert(statsAfter.finalBonus > statsBefore.finalBonus,
        "强化后最终收益加成应该提升")

    print("[EquipmentSystem] 强化后属性提升测试通过")
end

-- ============================================================================
-- 测试：战力值计算
-- ============================================================================
function tests.TestGetPlayerPower()
    EquipmentSystem.Reset()

    -- 无装备时战力为0
    local power0 = EquipmentSystem.GetPlayerPower(8)
    TestRunner.Assert(power0 == 0, "无装备时战力应该为0")

    -- 装备后战力增加
    EquipmentSystem.Unlock(8, "weapon_auction_master")
    EquipmentSystem.Equip(8, "weapon_auction_master", "weapon")

    local power1 = EquipmentSystem.GetPlayerPower(8)
    TestRunner.Assert(power1 > 0, "装备后战力应该大于0")

    print("[EquipmentSystem] 战力值计算测试通过 (战力: " .. power1 .. ")")
end

-- ============================================================================
-- 测试：套装效果检测
-- ============================================================================
function tests.TestSetBonusDetection()
    EquipmentSystem.Reset()

    -- 测试神秘套装（需要 weapon_mystic_gavel + armor_mystic_robe）
    EquipmentSystem.Unlock(9, "weapon_mystic_gavel")
    EquipmentSystem.Unlock(9, "armor_mystic_robe")

    -- 1件时没有套装效果
    local stats1 = EquipmentSystem.GetTotalStats(9)
    local global1 = stats1.globalBonus

    -- 装备第2件后激活2件套效果
    EquipmentSystem.Equip(9, "weapon_mystic_gavel", "weapon")
    EquipmentSystem.Equip(9, "armor_mystic_robe", "armor")

    local stats2 = EquipmentSystem.GetTotalStats(9)
    TestRunner.Assert(stats2.globalBonus > global1, "2件套后全局加成应该增加")

    print("[EquipmentSystem] 套装效果检测测试通过")
end

-- ============================================================================
-- 测试：完整套装激活
-- ============================================================================
function tests.TestCompleteSetBonus()
    EquipmentSystem.Reset()

    -- 装备均衡套装（4件）
    EquipmentSystem.Unlock(10, "weapon_gold_sword")
    EquipmentSystem.Unlock(10, "armor_leather_vest")
    EquipmentSystem.Unlock(10, "acc_lucky_coin")
    EquipmentSystem.Unlock(10, "badge_silver_star")

    EquipmentSystem.Equip(10, "weapon_gold_sword", "weapon")
    EquipmentSystem.Equip(10, "armor_leather_vest", "armor")
    EquipmentSystem.Equip(10, "acc_lucky_coin", "accessory")
    EquipmentSystem.Equip(10, "badge_silver_star", "badge")

    local stats = EquipmentSystem.GetTotalStats(10)

    -- 4件套效果应该激活
    TestRunner.Assert(stats.globalBonus > 0.2, "4件套后全局加成应该大于20%")
    TestRunner.Assert(stats.defense > 0, "4件套后防御力应该大于0")
    TestRunner.Assert(stats.critChance > 0, "4件套后暴击率应该大于0")

    print("[EquipmentSystem] 完整套装激活测试通过 (globalBonus: " .. stats.globalBonus .. ")")
end

-- ============================================================================
-- 测试：套装进度
-- ============================================================================
function tests.TestGetSetProgress()
    EquipmentSystem.Reset()

    EquipmentSystem.Unlock(11, "weapon_gold_sword")
    EquipmentSystem.Unlock(11, "armor_leather_vest")

    local progress = EquipmentSystem.GetSetProgress(11)
    TestRunner.Assert(type(progress) == "table", "应该返回套装进度列表")

    -- 查找均衡套装的进度
    local balancedSet = nil
    for _, set in ipairs(progress) do
        if set.setId == "balanced_set" then
            balancedSet = set
            break
        end
    end

    TestRunner.Assert(balancedSet ~= nil, "应该能找到均衡套装")
    TestRunner.Assert(balancedSet.matchedCount == 2, "应该有2件匹配")
    TestRunner.Assert(balancedSet.totalCount == 4, "总件数应该为4")
    TestRunner.Assert(balancedSet.completed == false, "不应该完成")

    print("[EquipmentSystem] 套装进度测试通过 (matched: " .. balancedSet.matchedCount .. "/" .. balancedSet.totalCount .. ")")
end

-- ============================================================================
-- 测试：装备列表查询
-- ============================================================================
function tests.TestGetEquipmentList()
    EquipmentSystem.Reset()

    local list = EquipmentSystem.GetEquipmentList(12)
    TestRunner.Assert(type(list) == "table", "应该返回装备列表")
    TestRunner.Assert(#list > 0, "装备列表不应为空")

    -- 检查列表项结构
    for _, item in ipairs(list) do
        TestRunner.Assert(item.id ~= nil, "装备应有ID")
        TestRunner.Assert(item.name ~= nil, "装备应有名称")
        TestRunner.Assert(item.slot ~= nil, "装备应有槽位")
        TestRunner.Assert(item.rarity ~= nil, "装备应有稀有度")
        TestRunner.Assert(item.unlocked ~= nil, "装备应有解锁状态")
    end

    print("[EquipmentSystem] 装备列表查询测试通过 (装备数: " .. #list .. ")")
end

-- ============================================================================
-- 测试：解锁计数
-- ============================================================================
function tests.TestGetUnlockedCount()
    EquipmentSystem.Reset()

    local count0 = EquipmentSystem.GetUnlockedCount(13)
    TestRunner.Assert(count0 == 0, "初始解锁数应该为0")

    EquipmentSystem.Unlock(13, "weapon_basic_hammer")
    EquipmentSystem.Unlock(13, "armor_basic_cloak")
    EquipmentSystem.Unlock(13, "acc_lucky_coin")

    local count1 = EquipmentSystem.GetUnlockedCount(13)
    TestRunner.Assert(count1 == 3, "解锁数应该为3")

    print("[EquipmentSystem] 解锁计数测试通过 (解锁数: " .. count1 .. ")")
end

-- ============================================================================
-- 测试：稀有度名称和颜色
-- ============================================================================
function tests.TestRarityInfo()
    local name1 = EquipmentSystem.GetRarityName(1)
    local name2 = EquipmentSystem.GetRarityName(2)
    local name5 = EquipmentSystem.GetRarityName(5)

    TestRunner.Assert(name1 == "普通", "1级稀有度应该是普通")
    TestRunner.Assert(name2 == "稀有", "2级稀有度应该是稀有")
    TestRunner.Assert(name5 == "神话", "5级稀有度应该是神话")

    local color1 = EquipmentSystem.GetRarityColor(1)
    local color5 = EquipmentSystem.GetRarityColor(5)

    TestRunner.Assert(color1 ~= nil, "应该有颜色值")
    TestRunner.Assert(color5 ~= nil, "应该有颜色值")

    print("[EquipmentSystem] 稀有度信息测试通过")
end

-- ============================================================================
-- 测试：系统重置
-- ============================================================================
function tests.TestReset()
    EquipmentSystem.Reset()

    EquipmentSystem.Unlock(14, "weapon_basic_hammer")
    EquipmentSystem.Equip(14, "weapon_basic_hammer", "weapon")

    EquipmentSystem.ResetPlayer(14)

    local isUnlocked = EquipmentSystem.IsUnlocked(14, "weapon_basic_hammer")
    TestRunner.Assert(isUnlocked == false, "重置后装备应该未解锁")

    local stats = EquipmentSystem.GetStats()
    TestRunner.Assert(stats.totalPlayers == 0, "重置后玩家数应该为0")

    print("[EquipmentSystem] 系统重置测试通过")
end

-- ============================================================================
-- 测试：获取所有套装
-- ============================================================================
function tests.TestGetAllSets()
    local sets = EquipmentSystem.GetAllSets()
    TestRunner.Assert(type(sets) == "table", "应该返回套装列表")
    TestRunner.Assert(#sets > 0, "套装列表不应为空")

    for _, set in ipairs(sets) do
        TestRunner.Assert(set.id ~= nil, "套装应有ID")
        TestRunner.Assert(set.name ~= nil, "套装应有名称")
        TestRunner.Assert(#set.pieces > 0, "套装应有部件")
    end

    print("[EquipmentSystem] 获取所有套装测试通过 (套装数: " .. #sets .. ")")
end

-- ============================================================================
-- 运行所有测试
-- ============================================================================
TestRunner.Run(tests)
return tests
