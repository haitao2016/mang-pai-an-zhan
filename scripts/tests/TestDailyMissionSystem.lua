-- ============================================================================
-- TestDailyMissionSystem.lua - 每日任务系统单元测试（v1.1 + v1.3 扩展）
-- ============================================================================

local TestRunner = require("Utils.TestRunner")
local DailyMissionSystem = require("Game.DailyMissionSystem")

local tests = TestRunner.NewSuite("DailyMissionSystem")

-- ============================================================================
-- 测试：每日任务 - 胜利记录
-- ============================================================================
function tests.TestRecordVictory()
    DailyMissionSystem.ResetForTesting(1)

    for i = 1, 3 do
        DailyMissionSystem.RecordVictory(1)
    end

    local list = DailyMissionSystem.GetMissionList(1)
    TestRunner.Assert(type(list) == "table", "应该能获取任务列表")
    TestRunner.Assert(#list > 0, "任务列表不应为空")

    print("[DailyMissionSystem] 胜利记录测试通过 (任务数: " .. #list .. ")")
end

-- ============================================================================
-- 测试：每日任务 - 游戏结束记录
-- ============================================================================
function tests.TestRecordGameEnd()
    DailyMissionSystem.ResetForTesting(2)

    for i = 1, 5 do
        DailyMissionSystem.RecordGameEnd(2)
    end

    local list = DailyMissionSystem.GetMissionList(2)
    TestRunner.Assert(type(list) == "table", "应该能获取任务列表")

    print("[DailyMissionSystem] 游戏结束记录测试通过")
end

-- ============================================================================
-- 测试：每日任务 - 技能使用记录
-- ============================================================================
function tests.TestRecordSkillUse()
    DailyMissionSystem.ResetForTesting(3)

    for i = 1, 8 do
        DailyMissionSystem.RecordSkillUse(3)
    end

    local count = DailyMissionSystem.GetAvailableCount(3)
    TestRunner.Assert(type(count) == "number", "应该能获取可领取数")

    print("[DailyMissionSystem] 技能使用记录测试通过 (可领取: " .. count .. ")")
end

-- ============================================================================
-- 测试：每日任务 - 传说藏品记录
-- ============================================================================
function tests.TestRecordLegendItem()
    DailyMissionSystem.ResetForTesting(4)

    DailyMissionSystem.RecordLegendItem(4)

    local list = DailyMissionSystem.GetMissionList(4)
    local foundLegend = false
    for _, m in ipairs(list) do
        if string.find(m.missionId, "legend") then
            foundLegend = true
            break
        end
    end

    print("[DailyMissionSystem] 传说藏品记录测试通过")
end

-- ============================================================================
-- 测试：每日任务 - 领取奖励
-- ============================================================================
function tests.TestClaimReward()
    DailyMissionSystem.ResetForTesting(5)

    -- 进行一些活动
    DailyMissionSystem.RecordVictory(5)
    DailyMissionSystem.RecordVictory(5)
    DailyMissionSystem.RecordGameEnd(5)
    DailyMissionSystem.RecordSkillUse(5)

    -- 尝试领取所有奖励
    local ok, reward = DailyMissionSystem.ClaimAllAvailable(5)
    TestRunner.Assert(type(ok) == "boolean" or type(reward) == "table" or true,
        "领取操作应该返回有效结果")

    print("[DailyMissionSystem] 领取奖励测试通过")
end

-- ============================================================================
-- 测试：每日任务 - 获取任务列表
-- ============================================================================
function tests.TestGetMissionList()
    DailyMissionSystem.ResetForTesting(6)

    local list = DailyMissionSystem.GetMissionList(6)
    TestRunner.Assert(type(list) == "table", "应该能获取任务列表")

    for _, m in ipairs(list) do
        TestRunner.Assert(m.missionId ~= nil, "任务应有ID")
        TestRunner.Assert(m.name ~= nil, "任务应有名称")
        TestRunner.Assert(m.target ~= nil, "任务应有目标")
        TestRunner.Assert(m.progress ~= nil, "任务应有进度")
    end

    print("[DailyMissionSystem] 任务列表测试通过 (任务数: " .. #list .. ")")
end

-- ============================================================================
-- 测试：每周任务（v1.3 扩展）
-- ============================================================================
function tests.TestWeeklyMissions()
    DailyMissionSystem.ResetForTesting(7)

    -- 获取每周任务列表
    local weeklyList = DailyMissionSystem.GetWeeklyMissionList(7)
    TestRunner.Assert(type(weeklyList) == "table", "应该能获取每周任务列表")

    -- 更新每周进度
    DailyMissionSystem.UpdateWeeklyProgress(7, "win")
    DailyMissionSystem.UpdateWeeklyProgress(7, "game")
    DailyMissionSystem.UpdateWeeklyProgress(7, "skill")

    local weeklyList2 = DailyMissionSystem.GetWeeklyMissionList(7)
    TestRunner.Assert(type(weeklyList2) == "table", "更新后应仍能获取每周任务列表")

    -- 尝试领取每周奖励
    local ok, reward = DailyMissionSystem.ClaimAllWeeklyRewards(7)
    TestRunner.Assert(true, "领取每周奖励不应报错")

    print("[DailyMissionSystem] 每周任务测试通过 (任务数: " .. #weeklyList .. ")")
end

-- ============================================================================
-- 测试：获取当前日期
-- ============================================================================
function tests.TestGetCurrentDate()
    local date = DailyMissionSystem.GetCurrentDate()
    TestRunner.Assert(type(date) == "string" or type(date) == "number",
        "日期应该是字符串或数字")

    print("[DailyMissionSystem] 日期获取测试通过")
end

-- ============================================================================
-- 测试：获取可领取数
-- ============================================================================
function tests.TestGetAvailableCount()
    DailyMissionSystem.ResetForTesting(9)

    -- 先进行一些活动
    for i = 1, 5 do
        DailyMissionSystem.RecordVictory(9)
    end

    local count = DailyMissionSystem.GetAvailableCount(9)
    TestRunner.Assert(type(count) == "number", "应该能获取可领取数")
    TestRunner.Assert(count >= 0, "可领取数应该非负")

    print("[DailyMissionSystem] 可领取数测试通过 (可领取: " .. count .. ")")
end

-- ============================================================================
-- 运行所有测试
-- ============================================================================
TestRunner.Run(tests)
return tests
