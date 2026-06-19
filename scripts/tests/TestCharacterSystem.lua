-- ============================================================================
-- TestCharacterSystem.lua - CharacterSystem 单元测试
-- ============================================================================

local TestRunner = require("Utils.TestRunner")
local Config = require("Config")
local CharacterData = require("Data.CharacterData")
local CharacterSystem = require("Game.CharacterSystem")

-- 测试套件
local tests = {
    -- 基础创建测试
    test_create = function()
        local cs = CharacterSystem.New(4)
        TestRunner.Assert(cs ~= nil, "CharacterSystem should be created")
        TestRunner.AssertEqual(4, cs.maxSeats, "maxSeats should be 4")
    end,

    test_default_max_seats = function()
        local cs = CharacterSystem.New()
        TestRunner.AssertEqual(4, cs.maxSeats, "Default maxSeats should be 4")
    end,

    -- 重置测试
    test_reset = function()
        local cs = CharacterSystem.New(4)
        cs:SelectCharacter(1, "lin_jian")
        TestRunner.Assert(cs.seats[1] ~= nil, "Seat 1 should have character")

        cs:Reset()
        TestRunner.Assert(cs.seats[1] == nil, "After reset, seat 1 should be empty")
        TestRunner.AssertEqual(0, #(cs.selectedIds), "selectedIds should be empty after reset")
    end,

    -- 角色选择测试
    test_select_character = function()
        local cs = CharacterSystem.New(4)
        local ok, err = cs:SelectCharacter(1, "lin_jian")
        TestRunner.Assert(ok, "Should select character: " .. tostring(err))
        TestRunner.Assert(cs.seats[1] ~= nil, "Seat 1 should have character data")
        TestRunner.AssertEqual("lin_jian", cs.seats[1].characterId, "Character ID should match")
    end,

    test_select_invalid_seat = function()
        local cs = CharacterSystem.New(4)
        local ok, err = cs:SelectCharacter(5, "lin_jian")
        TestRunner.Assert(not ok, "Should reject invalid seat")
        TestRunner.Assert(err ~= nil, "Should have error message")
    end,

    test_select_invalid_character = function()
        local cs = CharacterSystem.New(4)
        local ok, err = cs:SelectCharacter(1, "invalid_char")
        TestRunner.Assert(not ok, "Should reject invalid character")
        TestRunner.Assert(err ~= nil, "Should have error message")
    end,

    test_duplicate_selection_prevented = function()
        local cs = CharacterSystem.New(4)
        cs:SelectCharacter(1, "lin_jian")

        local ok, err = cs:SelectCharacter(2, "lin_jian")
        TestRunner.Assert(not ok, "Should prevent duplicate selection")
        TestRunner.Assert(cs.selectedIds["lin_jian"] == 1, "lin_jian should still be at seat 1")
    end,

    test_reselect_character = function()
        local cs = CharacterSystem.New(4)
        cs:SelectCharacter(1, "lin_jian")

        local ok, err = cs:SelectCharacter(1, "tang_yuan")
        TestRunner.Assert(ok, "Should allow reselecting on same seat")
        TestRunner.AssertEqual("tang_yuan", cs.seats[1].characterId, "Should be tang_yuan now")
        TestRunner.Assert(cs.selectedIds["lin_jian"] == nil, "lin_jian should be released")
        TestRunner.Assert(cs.selectedIds["tang_yuan"] == 1, "tang_yuan should be at seat 1")
    end,

    -- AI 自动选角测试
    test_auto_select = function()
        local cs = CharacterSystem.New(4)
        -- 选择所有角色确保无冲突
        for i = 1, 4 do
            local charId = cs:AutoSelectForAI(i)
            TestRunner.Assert(charId ~= nil, "Should auto-select for seat " .. i)
            TestRunner.Assert(cs.seats[i] ~= nil, "Seat " .. i .. " should have character")
        end
    end,

    -- 获取座位信息测试
    test_get_seat_info = function()
        local cs = CharacterSystem.New(4)
        cs:SelectCharacter(1, "lin_jian")

        local info = cs:GetSeatInfo(1)
        TestRunner.Assert(info ~= nil, "Should get seat info")
        TestRunner.AssertEqual("lin_jian", info.characterId, "Character ID should match")
    end,

    test_get_character_name = function()
        local cs = CharacterSystem.New(4)
        cs:SelectCharacter(1, "lin_jian")

        local name = cs:GetCharacterName(1)
        TestRunner.Assert(name ~= nil, "Should get character name")
        TestRunner.Assert(name ~= "未知", "Should not be unknown")
    end,

    test_unknown_seat_name = function()
        local cs = CharacterSystem.New(4)
        local name = cs:GetCharacterName(1)
        TestRunner.AssertEqual("未知", name, "Empty seat should return unknown")
    end,

    -- 主动技能测试
    test_use_skill_no_character = function()
        local cs = CharacterSystem.New(4)
        local ok, err, logic = cs:UseActiveSkill(1, nil)
        TestRunner.Assert(not ok, "Should fail when no character selected")
        TestRunner.Assert(err ~= nil, "Should have error")
    end,

    test_use_skill_normal = function()
        local cs = CharacterSystem.New(4)
        cs:SelectCharacter(1, "lin_jian")

        local ok, err, logic = cs:UseActiveSkill(1, nil)
        TestRunner.Assert(ok, "Should use skill: " .. tostring(err))
        TestRunner.Assert(logic ~= nil, "Should return skill logic")
        TestRunner.Assert(cs.seats[1].activeUses == 1, "Uses should be 1")
    end,

    test_skill_cooldown = function()
        local cs = CharacterSystem.New(4)
        cs:SelectCharacter(1, "lin_jian")

        -- 首次使用
        cs:UseActiveSkill(1, nil)
        TestRunner.Assert(cs.seats[1].activeCD > 0, "Cooldown should be set after use")

        -- 立即再次使用应该失败
        local ok, err, _ = cs:UseActiveSkill(1, nil)
        TestRunner.Assert(not ok, "Should fail during cooldown")
        TestRunner.Assert(string.find(err, "冷却"), "Error should mention cooldown")
    end,

    test_skill_max_uses = function()
        local cs = CharacterSystem.New(4)
        -- 找一个 maxUses 有限的角色
        local charData = CharacterData.GetCharacter("lin_jian")
        local maxUses = charData.activeSkill.maxUses

        if maxUses > 0 then
            cs:SelectCharacter(1, "lin_jian")

            -- 使用 maxUses 次
            for i = 1, maxUses do
                local ok, _, _ = cs:UseActiveSkill(1, nil)
                TestRunner.Assert(ok, "Use " .. i .. " should succeed")
            end

            -- 再使用应该失败
            local ok, err, _ = cs:UseActiveSkill(1, nil)
            TestRunner.Assert(not ok, "Should fail after max uses")
            TestRunner.Assert(string.find(err, "用完"), "Error should mention uses")
        end
    end,

    test_skill_needs_target = function()
        local cs = CharacterSystem.New(4)
        cs:SelectCharacter(1, "zhao_mi")

        -- zhao_mi 的技能是 SKILL_SPY，需要目标
        local ok, err, _ = cs:UseActiveSkill(1, nil)
        TestRunner.Assert(not ok, "Should fail without target")
        TestRunner.Assert(string.find(err, "目标"), "Error should mention target")
    end,

    test_skill_target_self = function()
        local cs = CharacterSystem.New(4)
        cs:SelectCharacter(1, "zhao_mi")
        cs:SelectCharacter(2, "lin_jian")

        local ok, err, _ = cs:UseActiveSkill(1, 1)
        TestRunner.Assert(not ok, "Should fail when targeting self")
        TestRunner.Assert(string.find(err, "自己"), "Error should mention self")
    end,

    -- 回合结束测试
    test_round_end_cooldown = function()
        local cs = CharacterSystem.New(4)
        cs:SelectCharacter(1, "lin_jian")

        cs:UseActiveSkill(1, nil)
        local cdBefore = cs.seats[1].activeCD

        cs:OnRoundEnd()
        local cdAfter = cs.seats[1].activeCD

        TestRunner.AssertEqual(cdBefore - 1, cdAfter, "Cooldown should decrease by 1")
    end,

    test_round_end_clear_temp_state = function()
        local cs = CharacterSystem.New(4)
        cs:SelectCharacter(1, "lin_jian")

        -- 使用需要临时状态的技能
        cs:SelectCharacter(1, "yuan_fang")  -- 追加预算
        cs:UseActiveSkill(1, nil)
        TestRunner.Assert(cs.seats[1].budgetBoost == true, "Should have budgetBoost")

        cs:OnRoundEnd()
        TestRunner.Assert(cs.seats[1].budgetBoost == false, "budgetBoost should be cleared")
    end,

    -- 被动技能查询测试
    test_get_passives_by_trigger = function()
        local cs = CharacterSystem.New(4)
        cs:SelectCharacter(1, "lin_jian")  -- 主动技能角色

        local passives = cs:GetPassivesByTrigger("round_start")
        TestRunner.Assert(passives ~= nil, "Should return passive list")
    end,

    -- 状态查询测试
    test_is_shielded = function()
        local cs = CharacterSystem.New(4)
        cs:SelectCharacter(1, "zhao_mi")  -- 有信息屏障的角色

        TestRunner.Assert(not cs:IsShielded(1), "Should not be shielded initially")

        cs:UseActiveSkill(1, 2)
        TestRunner.Assert(cs:IsShielded(1), "Should be shielded after using shield skill")
    end,

    test_has_budget_boost = function()
        local cs = CharacterSystem.New(4)
        cs:SelectCharacter(1, "yuan_fang")

        TestRunner.Assert(not cs:HasBudgetBoost(1), "Should not have boost initially")

        cs:UseActiveSkill(1, nil)
        TestRunner.Assert(cs:HasBudgetBoost(1), "Should have boost after using skill")
    end,

    test_has_fortune = function()
        local cs = CharacterSystem.New(4)
        cs:SelectCharacter(1, "ye_xinglan")

        TestRunner.Assert(not cs:HasFortune(1), "Should not have fortune initially")

        cs:UseActiveSkill(1, nil)
        TestRunner.Assert(cs:HasFortune(1), "Should have fortune after using skill")
    end,

    test_roll_fortune = function()
        local cs = CharacterSystem.New(4)

        local results = {}
        for i = 1, 100 do
            local mult = cs:RollFortune()
            table.insert(results, mult)
            TestRunner.Assert(mult > 0.8, "Fortune multiplier should be > 0.8")
            TestRunner.Assert(mult < 1.3, "Fortune multiplier should be < 1.3")
        end

        -- 检查范围
        local min = results[1]
        local max = results[1]
        for _, v in ipairs(results) do
            if v < min then min = v end
            if v > max then max = v end
        end
        print(string.format("[Test] Fortune range: %.3f - %.3f", min, max))
    end,

    test_get_poker_face_offset = function()
        local cs = CharacterSystem.New(4)
        cs:SelectCharacter(1, "xu_mei")  -- 扑克脸角色

        local offset = cs:GetPokerFaceOffset(1)
        TestRunner.AssertEqual(-1, offset, "Poker face should return -1 offset")
    end,

    test_get_lucky_bonus = function()
        local cs = CharacterSystem.New(4)
        cs:SelectCharacter(1, "ye_xinglan")  -- 锦鲤体质角色

        local bonus = cs:GetLuckyBonus(1)
        TestRunner.Assert(bonus > 0, "Lucky bonus should be positive")
        TestRunner.AssertEqual(Config.Skill.LuckyBoxBonus, bonus, "Bonus should match config")
    end,

    test_get_frugal_rate = function()
        local cs = CharacterSystem.New(4)
        cs:SelectCharacter(1, "yuan_fang")  -- 精打细算角色

        local rate = cs:GetFrugalRate(1)
        TestRunner.Assert(rate > 0, "Frugal rate should be positive")
        TestRunner.AssertEqual(Config.Skill.FrugalRefund, rate, "Rate should match config")
    end,

    -- 技能状态摘要测试
    test_get_active_skill_status = function()
        local cs = CharacterSystem.New(4)
        cs:SelectCharacter(1, "lin_jian")

        local status = cs:GetActiveSkillStatus(1)
        TestRunner.Assert(status ~= nil, "Should get skill status")
        TestRunner.Assert(status.skillId ~= nil, "Should have skillId")
        TestRunner.Assert(status.skillName ~= nil, "Should have skillName")
        TestRunner.AssertEqual(0, status.cd, "Initial CD should be 0")
    end,

    test_get_active_skill_status_no_character = function()
        local cs = CharacterSystem.New(4)

        local status = cs:GetActiveSkillStatus(1)
        TestRunner.AssertEqual("", status.skillId, "Should return empty for no character")
    end,

    -- 压力目标测试
    test_get_pressure_target = function()
        local cs = CharacterSystem.New(4)
        cs:SelectCharacter(1, "su_mu")
        cs:SelectCharacter(2, "lin_jian")

        cs:UseActiveSkill(1, 2)  -- 施压目标 2
        local target = cs:GetPressureTarget(1)
        TestRunner.AssertEqual(2, target, "Pressure target should be 2")
    end,

    test_get_misinform_target = function()
        local cs = CharacterSystem.New(4)
        cs:SelectCharacter(1, "han_sheng")
        cs:SelectCharacter(2, "lin_jian")

        cs:UseActiveSkill(1, 2)  -- 虚假情报目标 2
        local target = cs:GetMisinformTarget(1)
        TestRunner.AssertEqual(2, target, "Misinform target should be 2")
    end,
}

-- 运行测试
TestRunner.RunSuite("CharacterSystem", tests)
TestRunner.PrintSummary()

return TestRunner.results
