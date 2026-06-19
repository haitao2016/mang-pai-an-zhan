-- ============================================================================
-- TestAchievementSystem.lua - 成就系统单元测试（v1.3 扩展）
-- ============================================================================

local TestRunner = require("Utils.TestRunner")
local AchievementSystem = require("Game.AchievementSystem")

local tests = TestRunner.NewSuite("AchievementSystem")

-- ============================================================================
-- 测试：记录胜利
-- ============================================================================
function tests.TestRecordVictory()
    AchievementSystem.ResetForTesting(1)

    local unlocked = AchievementSystem.RecordVictory(1, "hall_beginner", 1500, 1000)
    TestRunner.Assert(type(unlocked) == "table", "应该返回解锁的成就列表")

    local winCount = AchievementSystem.GetStat(1, "win_count")
    TestRunner.Assert(winCount >= 1, "胜场数应该至少为1")

    local gameCount = AchievementSystem.GetStat(1, "game_count")
    TestRunner.Assert(gameCount >= 1, "游戏局数应该至少为1")

    local positiveGain = AchievementSystem.GetStat(1, "positive_gain")
    TestRunner.Assert(positiveGain >= 1, "正收益局数应该至少为1")

    print("[AchievementSystem] 记录胜利测试通过 (胜场: " .. winCount .. ")")
end

-- ============================================================================
-- 测试：记录失败
-- ============================================================================
function tests.TestRecordGameEnd()
    AchievementSystem.ResetForTesting(2)

    AchievementSystem.RecordGameEnd(2)
    local gameCount = AchievementSystem.GetStat(2, "game_count")
    TestRunner.Assert(gameCount >= 1, "游戏局数应该至少为1")

    local loseStreak = AchievementSystem.GetStat(2, "lose_streak")
    TestRunner.Assert(loseStreak >= 1, "连败应该至少为1")

    print("[AchievementSystem] 记录失败测试通过 (连败: " .. loseStreak .. ")")
end

-- ============================================================================
-- 测试：记录速胜
-- ============================================================================
function tests.TestRecordSpeedWin()
    AchievementSystem.ResetForTesting(3)

    AchievementSystem.RecordSpeedWin(3)
    AchievementSystem.RecordSpeedWin(3)
    AchievementSystem.RecordSpeedWin(3)

    local speedWins = AchievementSystem.GetStat(3, "speed_win_count")
    TestRunner.Assert(speedWins == 3, "速胜次数应该为3")

    print("[AchievementSystem] 速胜测试通过 (速胜: " .. speedWins .. ")")
end

-- ============================================================================
-- 测试：记录藏品
-- ============================================================================
function tests.TestRecordItemObtained()
    AchievementSystem.ResetForTesting(4)

    AchievementSystem.RecordItemObtained(4, 2, 500)
    AchievementSystem.RecordItemObtained(4, 2, 300)
    AchievementSystem.RecordItemObtained(4, 4, 2000)

    local collectedItems = AchievementSystem.GetStat(4, "collected_items")
    TestRunner.Assert(collectedItems == 3, "藏品数应该为3")

    local legendCount = AchievementSystem.GetStat(4, "legend_count")
    TestRunner.Assert(legendCount == 1, "传说藏品数应该为1")

    local collectionValue = AchievementSystem.GetStat(4, "collection_value")
    TestRunner.Assert(collectionValue >= 2800, "收藏价值应该至少为2800")

    print("[AchievementSystem] 藏品测试通过 (藏品: " .. collectedItems .. ", 传说: " .. legendCount .. ")")
end

-- ============================================================================
-- 测试：记录技能使用
-- ============================================================================
function tests.TestRecordSkillUse()
    AchievementSystem.ResetForTesting(5)

    for i = 1, 10 do
        AchievementSystem.RecordSkillUse(5)
    end

    local skillUses = AchievementSystem.GetStat(5, "skill_uses")
    TestRunner.Assert(skillUses == 10, "技能使用次数应该为10")

    print("[AchievementSystem] 技能使用测试通过 (次数: " .. skillUses .. ")")
end

-- ============================================================================
-- 测试：连胜/连败记录
-- ============================================================================
function tests.TestWinLoseStreak()
    AchievementSystem.ResetForTesting(6)

    -- 连续胜利5次
    for i = 1, 5 do
        AchievementSystem.RecordVictory(6, nil, 1500, 1000)
    end

    local streakInfo = AchievementSystem.GetStreakInfo(6)
    TestRunner.Assert(streakInfo.currentWinStreak == 5, "当前连胜应该为5")
    TestRunner.Assert(streakInfo.maxWinStreak == 5, "最高连胜应该为5")

    -- 失败3次
    for i = 1, 3 do
        AchievementSystem.RecordGameEnd(6)
    end

    local streakInfo2 = AchievementSystem.GetStreakInfo(6)
    TestRunner.Assert(streakInfo2.currentLoseStreak == 3, "当前连败应该为3")
    TestRunner.Assert(streakInfo2.maxWinStreak == 5, "最高连胜应该保持为5")

    -- 再胜2次验证最高连胜仍然保持
    for i = 1, 2 do
        AchievementSystem.RecordVictory(6, nil, 1500, 1000)
    end
    local streakInfo3 = AchievementSystem.GetStreakInfo(6)
    TestRunner.Assert(streakInfo3.maxWinStreak == 5, "最高连胜应该仍然保持为5")

    print("[AchievementSystem] 连胜/连败测试通过 (最高连胜: " .. streakInfo3.maxWinStreak .. ")")
end

-- ============================================================================
-- 测试：v1.3 新增统计字段
-- ============================================================================
function tests.TestV13Stats()
    AchievementSystem.ResetForTesting(7)

    -- 拍卖次数
    for i = 1, 8 do
        AchievementSystem.RecordAuction(7)
    end

    -- 锦标赛胜利
    AchievementSystem.RecordTournamentWin(7, "TRN_TEST")
    AchievementSystem.RecordTournamentWin(7, "TRN_TEST2")

    -- 团队战
    for i = 1, 5 do
        AchievementSystem.RecordTeamBattle(7, i % 2 == 1)
    end

    -- 公会贡献
    AchievementSystem.RecordGuildContribution(7, 500)
    AchievementSystem.RecordGuildContribution(7, 800)

    -- 皮肤解锁
    AchievementSystem.RecordSkinUnlock(7)
    AchievementSystem.RecordSkinUnlock(7)

    -- 金币获得
    AchievementSystem.RecordGoldObtained(7, 3000)

    local playerStats = AchievementSystem.GetPlayerStats(7)
    TestRunner.Assert(playerStats.auctionCount == 8, "拍卖次数应该为8")
    TestRunner.Assert(playerStats.tournamentWins == 2, "锦标赛胜利应该为2")
    TestRunner.Assert(playerStats.teamBattleCount == 5, "团队战次数应该为5")
    TestRunner.Assert(playerStats.guildContribution == 1300, "公会贡献应该为1300")
    TestRunner.Assert(playerStats.skinUnlocks == 2, "皮肤解锁应该为2")
    TestRunner.Assert(playerStats.totalGold == 3000, "金币获得应该为3000")

    print("[AchievementSystem] v1.3新增统计字段测试通过")
end

-- ============================================================================
-- 测试：成就列表与解锁检测
-- ============================================================================
function tests.TestAchievementList()
    AchievementSystem.ResetForTesting(8)

    -- 获取完整成就列表
    local list = AchievementSystem.GetAchievementList(8)
    TestRunner.Assert(type(list) == "table", "应该返回成就列表")
    TestRunner.Assert(#list > 0, "成就列表不应为空")

    -- 每个成就应该有必要字段
    for _, a in ipairs(list) do
        TestRunner.Assert(a.id ~= nil, "成就应有ID")
        TestRunner.Assert(a.name ~= nil, "成就应有名称")
        TestRunner.Assert(a.level ~= nil, "成就应有等级")
        TestRunner.Assert(a.category ~= nil, "成就应有类别")
    end

    local unlocked = AchievementSystem.GetUnlockedCount(8)
    local total = AchievementSystem.GetTotalCount()
    TestRunner.Assert(total >= unlocked, "总数应大于等于已解锁数")

    print("[AchievementSystem] 成就列表测试通过 (总数: " .. total .. ", 已解锁: " .. unlocked .. ")")
end

-- ============================================================================
-- 测试：按等级/类别筛选
-- ============================================================================
function tests.TestFilterByLevelAndCategory()
    AchievementSystem.ResetForTesting(9)

    -- 测试按等级筛选
    local goldAchievements = AchievementSystem.GetAchievementsByLevel(9, "gold")
    TestRunner.Assert(type(goldAchievements) == "table", "应该能获取金牌成就")

    local silverAchievements = AchievementSystem.GetAchievementsByLevel(9, "silver")
    TestRunner.Assert(type(silverAchievements) == "table", "应该能获取银牌成就")

    -- 测试按类别筛选
    local competitionAchievements = AchievementSystem.GetAchievementsByCategory(9, "competition")
    TestRunner.Assert(type(competitionAchievements) == "table", "应该能获取竞技类成就")

    local growthAchievements = AchievementSystem.GetAchievementsByCategory(9, "growth")
    TestRunner.Assert(type(growthAchievements) == "table", "应该能获取成长类成就")

    print("[AchievementSystem] 筛选测试通过 (金: " .. #goldAchievements .. ", 银: " .. #silverAchievements ..
          ", 竞技: " .. #competitionAchievements .. ", 成长: " .. #growthAchievements .. ")")
end

-- ============================================================================
-- 测试：成就统计汇总
-- ============================================================================
function tests.TestAchievementSummary()
    AchievementSystem.ResetForTesting(10)

    -- 先解锁一些成就
    for i = 1, 3 do
        AchievementSystem.RecordVictory(10, "hall_beginner", 1500, 1000)
    end

    local summary = AchievementSystem.GetAchievementSummary(10)
    TestRunner.Assert(type(summary) == "table", "应该能获取成就汇总")
    TestRunner.Assert(summary.totalCount > 0, "总成就数应该大于0")
    TestRunner.Assert(summary.unlockedCount >= 0, "已解锁成就数应该非负")
    TestRunner.Assert(summary.completionRate >= 0 and summary.completionRate <= 1,
        "完成度应该在0-1之间")
    TestRunner.Assert(type(summary.byLevel) == "table", "应该有按等级统计")
    TestRunner.Assert(type(summary.byCategory) == "table", "应该有按类别统计")
    TestRunner.Assert(type(summary.unlockedByLevel) == "table", "应该有已解锁按等级统计")
    TestRunner.Assert(type(summary.unlockedByCategory) == "table", "应该有已解锁按类别统计")

    print("[AchievementSystem] 成就汇总测试通过 (完成度: " .. string.format("%.2f%%", summary.completionRate * 100) .. ")")
end

-- ============================================================================
-- 测试：等级与类别元数据
-- ============================================================================
function tests.TestLevelsAndCategories()
    local levels = AchievementSystem.GetAllLevels()
    TestRunner.Assert(type(levels) == "table", "应该能获取等级列表")
    TestRunner.Assert(#levels == 5, "应该有5个等级（铜/银/金/铂金/钻石）")

    local categories = AchievementSystem.GetAllCategories()
    TestRunner.Assert(type(categories) == "table", "应该能获取类别列表")
    TestRunner.Assert(#categories == 5, "应该有5个类别（竞技/社交/收集/成长/特殊）")

    for _, level in ipairs(levels) do
        TestRunner.Assert(level.id ~= nil, "等级应有ID")
        TestRunner.Assert(level.name ~= nil, "等级应有名称")
        TestRunner.Assert(level.color ~= nil, "等级应有颜色")
    end

    print("[AchievementSystem] 等级与类别元数据测试通过")
end

-- ============================================================================
-- 测试：玩家统计数据
-- ============================================================================
function tests.TestPlayerStats()
    AchievementSystem.ResetForTesting(11)

    -- 进行一些活动
    AchievementSystem.RecordVictory(11, "hall_beginner", 1500, 1000)
    AchievementSystem.RecordVictory(11, "hall_intermediate", 2000, 1000)
    AchievementSystem.RecordSpeedWin(11)
    AchievementSystem.RecordItemObtained(11, 4, 3000)
    AchievementSystem.RecordSkillUse(11)
    AchievementSystem.RecordBidRanks(11, {1, 2, 1, 3, 1})
    AchievementSystem.RecordAuction(11)
    AchievementSystem.RecordTournamentWin(11, "TRN_TEST")

    local stats = AchievementSystem.GetPlayerStats(11)
    TestRunner.Assert(stats.winCount >= 2, "胜场数应该至少为2")
    TestRunner.Assert(stats.gameCount >= 2, "游戏局数应该至少为2")
    TestRunner.Assert(stats.speedWinCount == 1, "速胜次数应该为1")
    TestRunner.Assert(stats.legendCount == 1, "传说藏品数应该为1")
    TestRunner.Assert(stats.skillUses == 1, "技能使用次数应该为1")
    TestRunner.Assert(stats.auctionCount == 1, "拍卖次数应该为1")
    TestRunner.Assert(stats.tournamentWins == 1, "锦标赛胜场应该为1")

    print("[AchievementSystem] 玩家统计测试通过 (胜场: " .. stats.winCount .. ", 藏品: " .. stats.collectedItems .. ")")
end

-- ============================================================================
-- 测试：成就解锁检测
-- ============================================================================
function tests.TestAchievementUnlock()
    AchievementSystem.ResetForTesting(12)

    -- 初始状态应该没有解锁
    local unlockedBefore = AchievementSystem.GetUnlockedCount(12)

    -- 多次胜利以触发成就
    for i = 1, 15 do
        AchievementSystem.RecordVictory(12, "hall_beginner", 1500, 1000)
    end

    local unlockedAfter = AchievementSystem.GetUnlockedCount(12)
    TestRunner.Assert(unlockedAfter >= unlockedBefore, "活动后解锁的成就不应减少")

    -- 检查特定成就是否解锁
    local isFirstWinUnlocked = AchievementSystem.IsUnlocked(12, "first_win")
    print("[AchievementSystem] first_win成就: " .. tostring(isFirstWinUnlocked))

    print("[AchievementSystem] 成就解锁测试通过 (解锁数: " .. unlockedBefore .. " -> " .. unlockedAfter .. ")")
end

-- ============================================================================
-- 测试：回合排名记录
-- ============================================================================
function tests.TestBidRanks()
    AchievementSystem.ResetForTesting(13)

    AchievementSystem.RecordBidRanks(13, {1, 1, 1, 2, 3})
    local perfect = AchievementSystem.GetStat(13, "perfect_rounds")
    TestRunner.Assert(perfect == 3, "完美回合应该为3")

    local top2 = AchievementSystem.GetStat(13, "top2_rounds")
    TestRunner.Assert(top2 == 4, "前2排名回合应该为4")

    print("[AchievementSystem] 回合排名测试通过 (完美: " .. perfect .. ", 前2: " .. top2 .. ")")
end

-- ============================================================================
-- 运行所有测试
-- ============================================================================
TestRunner.Run(tests)
return tests
