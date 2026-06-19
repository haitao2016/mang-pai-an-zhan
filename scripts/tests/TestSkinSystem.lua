-- ============================================================================
-- TestSkinSystem.lua - 角色皮肤系统单元测试
-- ============================================================================

local TestRunner = require("Utils.TestRunner")
local SkinSystem = require("Game.SkinSystem")

local tests = TestRunner.NewSuite("SkinSystem")

-- ============================================================================
-- 测试：获取角色皮肤列表
-- ============================================================================
function tests.TestGetSkinsForCharacter()
    SkinSystem.Reset()

    local skins = SkinSystem.GetSkinsForCharacter(1)

    TestRunner.Assert(type(skins) == "table", "Should return table")
    TestRunner.Assert(#skins >= 1, "Should have at least default skin")

    -- 检查默认皮肤
    local hasDefault = false
    for _, skin in ipairs(skins) do
        if skin.id == "skin_default" then
            hasDefault = true
            break
        end
    end
    TestRunner.Assert(hasDefault, "Should have default skin")

    print("[SkinSystem] 皮肤列表测试完成，共 " .. #skins .. " 个皮肤")
end

-- ============================================================================
-- 测试：解锁皮肤
-- ============================================================================
function tests.TestUnlockSkin()
    SkinSystem.Reset("player1")

    local ok = SkinSystem.UnlockSkin("player1", "skin_001", "test")
    TestRunner.Assert(ok == true, "Unlock should succeed")

    local ok2, err2 = SkinSystem.UnlockSkin("player1", "skin_001", "test")
    TestRunner.Assert(ok2 == false, "Duplicate unlock should fail")
    TestRunner.Assert(err2 == "already_unlocked", "Should return already_unlocked")

    print("[SkinSystem] 解锁皮肤测试完成")
end

-- ============================================================================
-- 测试：检查皮肤是否已解锁
-- ============================================================================
function tests.TestIsSkinUnlocked()
    SkinSystem.Reset("player1")

    SkinSystem.UnlockSkin("player1", "skin_001", "test")

    local unlocked1 = SkinSystem.IsSkinUnlocked("player1", "skin_001")
    TestRunner.Assert(unlocked1 == true, "Should be unlocked")

    local unlocked2 = SkinSystem.IsSkinUnlocked("player1", "skin_999")
    TestRunner.Assert(unlocked2 == false, "Should not be unlocked")

    print("[SkinSystem] 解锁检查测试完成")
end

-- ============================================================================
-- 测试：购买皮肤
-- ============================================================================
function tests.TestPurchaseSkin()
    SkinSystem.Reset("player1")

    local ok = SkinSystem.PurchaseSkin("player1", "skin_001", 100)
    TestRunner.Assert(ok == true, "Purchase should succeed")

    local ok2 = SkinSystem.IsSkinUnlocked("player1", "skin_001")
    TestRunner.Assert(ok2 == true, "Should be unlocked after purchase")

    print("[SkinSystem] 购买皮肤测试完成")
end

-- ============================================================================
-- 测试：装备皮肤
-- ============================================================================
function tests.TestEquipSkin()
    SkinSystem.Reset("player1")

    -- 先解锁一个皮肤（模拟）
    local skins = SkinSystem.GetSkinsForCharacter(1)
    if #skins > 1 then
        local skinToEquip = skins[2].id

        -- 由于没有配置，直接测试装备逻辑
        local ok = SkinSystem.EquipSkin("player1", 1, "skin_default")
        TestRunner.Assert(ok == true, "Should equip default skin")
    end

    print("[SkinSystem] 装备皮肤测试完成")
end

-- ============================================================================
-- 测试：卸下皮肤
-- ============================================================================
function tests.TestUnequipSkin()
    SkinSystem.Reset("player1")

    SkinSystem.EquipSkin("player1", 1, "skin_default")

    local ok = SkinSystem.UnequipSkin("player1", 1)
    TestRunner.Assert(ok == true, "Unequip should succeed")

    local equipped = SkinSystem.GetEquippedSkin("player1", 1)
    TestRunner.Assert(equipped.id == "skin_default", "Should return default skin")

    print("[SkinSystem] 卸下皮肤测试完成")
end

-- ============================================================================
-- 测试：获取已装备皮肤
-- ============================================================================
function tests.TestGetEquippedSkin()
    SkinSystem.Reset("player1")

    local equipped = SkinSystem.GetEquippedSkin("player1", 1)
    TestRunner.Assert(equipped ~= nil, "Should return skin")
    TestRunner.Assert(equipped.id == "skin_default", "Should be default skin")

    SkinSystem.EquipSkin("player1", 1, "skin_default")

    local equipped2 = SkinSystem.GetEquippedSkin("player1", 1)
    TestRunner.Assert(equipped2.id == "skin_default", "Should be equipped skin")

    print("[SkinSystem] 获取已装备皮肤测试完成")
end

-- ============================================================================
-- 测试：皮肤预览
-- ============================================================================
function tests.TestGetSkinPreview()
    SkinSystem.Reset()

    local preview = SkinSystem.GetSkinPreview("skin_default", 1)
    TestRunner.Assert(preview ~= nil, "Should return preview")
    TestRunner.Assert(preview.id == "skin_default", "Should have correct id")

    print("[SkinSystem] 皮肤预览测试完成")
end

-- ============================================================================
-- 测试：获取皮肤套装
-- ============================================================================
function tests.TestGetSkinSets()
    SkinSystem.Reset()

    local sets = SkinSystem.GetSkinSets()
    TestRunner.Assert(type(sets) == "table", "Should return table")

    print("[SkinSystem] 皮肤套装测试完成")
end

-- ============================================================================
-- 测试：获取稀有度名称
-- ============================================================================
function tests.TestGetRarityName()
    SkinSystem.Reset()

    local name1 = SkinSystem.GetRarityName(1)
    TestRunner.Assert(name1 == "普通", "Rarity 1 should be 普通")

    local name4 = SkinSystem.GetRarityName(4)
    TestRunner.Assert(name4 == "传说", "Rarity 4 should be 传说")

    local name5 = SkinSystem.GetRarityName(5)
    TestRunner.Assert(name5 == "独占", "Rarity 5 should be 独占")

    print("[SkinSystem] 稀有度名称测试完成")
end

-- ============================================================================
-- 测试：获取玩家皮肤统计
-- ============================================================================
function tests.TestGetPlayerStats()
    SkinSystem.Reset("player1")

    local stats = SkinSystem.GetPlayerStats("player1")
    TestRunner.Assert(stats ~= nil, "Should return stats")
    TestRunner.Assert(stats.totalUnlocked >= 0, "Should have total unlocked")
    TestRunner.Assert(stats.byRarity ~= nil, "Should have rarity breakdown")

    print("[SkinSystem] 玩家统计测试完成")
end

-- ============================================================================
-- 测试：重置功能
-- ============================================================================
function tests.TestReset()
    SkinSystem.Reset("player1")
    SkinSystem.UnlockSkin("player1", "skin_001", "test")

    SkinSystem.Reset("player1")

    local unlocked = SkinSystem.IsSkinUnlocked("player1", "skin_001")
    TestRunner.Assert(unlocked == false, "Should be reset")

    print("[SkinSystem] 重置测试完成")
end

-- ============================================================================
-- 运行所有测试
-- ============================================================================
TestRunner.Run(tests)

return tests
