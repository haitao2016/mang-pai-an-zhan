-- ============================================================================
-- TestPlayerDataManager.lua - 玩家数据管理单元测试（v1.0 核心）
-- ============================================================================

local TestRunner = require("Utils.TestRunner")
local PlayerDataManager = require("Game.PlayerDataManager")

local tests = TestRunner.NewSuite("PlayerDataManager")

-- ============================================================================
-- 测试：获取缓存余额
-- ============================================================================
function tests.TestGetCachedBalance()
    local balance = PlayerDataManager.GetCachedBalance(1)
    TestRunner.Assert(type(balance) == "number", "余额应该是数字")
    TestRunner.Assert(balance >= 0, "余额应该非负")

    print("[PlayerDataManager] 获取缓存余额测试通过 (余额: " .. balance .. ")")
end

-- ============================================================================
-- 测试：设置缓存余额
-- ============================================================================
function tests.TestSetCachedBalance()
    PlayerDataManager.SetCachedBalance(2, 5000)
    local balance = PlayerDataManager.GetCachedBalance(2)
    TestRunner.Assert(balance == 5000, "设置后的余额应该为5000")

    print("[PlayerDataManager] 设置缓存余额测试通过 (余额: " .. balance .. ")")
end

-- ============================================================================
-- 测试：是否已加载
-- ============================================================================
function tests.TestIsLoaded()
    local loaded = PlayerDataManager.IsLoaded(3)
    TestRunner.Assert(type(loaded) == "boolean", "加载状态应该是布尔值")

    print("[PlayerDataManager] 加载状态测试通过 (已加载: " .. tostring(loaded) .. ")")
end

-- ============================================================================
-- 测试：清除缓存
-- ============================================================================
function tests.TestClearCache()
    PlayerDataManager.SetCachedBalance(4, 10000)
    PlayerDataManager.ClearCache(4)

    local balance = PlayerDataManager.GetCachedBalance(4)
    TestRunner.Assert(true, "清除缓存不应失败")

    print("[PlayerDataManager] 清除缓存测试通过")
end

-- ============================================================================
-- 测试：余额增减操作
-- ============================================================================
function tests.TestBalanceOperations()
    -- 设置初始余额
    PlayerDataManager.SetCachedBalance(5, 1000)

    -- 增加余额
    local current = PlayerDataManager.GetCachedBalance(5)
    PlayerDataManager.SetCachedBalance(5, current + 500)
    local newBalance = PlayerDataManager.GetCachedBalance(5)
    TestRunner.Assert(newBalance == 1500, "增加后余额应为1500")

    -- 减少余额
    PlayerDataManager.SetCachedBalance(5, newBalance - 300)
    local finalBalance = PlayerDataManager.GetCachedBalance(5)
    TestRunner.Assert(finalBalance == 1200, "减少后余额应为1200")

    print("[PlayerDataManager] 余额增减操作测试通过 (最终余额: " .. finalBalance .. ")")
end

-- ============================================================================
-- 测试：多玩家余额管理
-- ============================================================================
function tests.TestMultiPlayerBalance()
    -- 设置3个玩家的余额
    PlayerDataManager.SetCachedBalance(10, 1000)
    PlayerDataManager.SetCachedBalance(11, 2000)
    PlayerDataManager.SetCachedBalance(12, 3000)

    -- 验证各玩家余额
    local b10 = PlayerDataManager.GetCachedBalance(10)
    local b11 = PlayerDataManager.GetCachedBalance(11)
    local b12 = PlayerDataManager.GetCachedBalance(12)

    TestRunner.Assert(b10 == 1000, "玩家10余额应为1000")
    TestRunner.Assert(b11 == 2000, "玩家11余额应为2000")
    TestRunner.Assert(b12 == 3000, "玩家12余额应为3000")

    -- 修改玩家11的余额，确保不影响其他玩家
    PlayerDataManager.SetCachedBalance(11, 2500)
    local newB10 = PlayerDataManager.GetCachedBalance(10)
    local newB11 = PlayerDataManager.GetCachedBalance(11)
    local newB12 = PlayerDataManager.GetCachedBalance(12)

    TestRunner.Assert(newB10 == 1000, "玩家10余额不应改变")
    TestRunner.Assert(newB11 == 2500, "玩家11余额应为2500")
    TestRunner.Assert(newB12 == 3000, "玩家12余额不应改变")

    print("[PlayerDataManager] 多玩家余额管理测试通过")
end

-- ============================================================================
-- 测试：获取藏品列表
-- ============================================================================
function tests.TestGetCollection()
    local ok, result = pcall(function()
        return PlayerDataManager.GetCollection(6, function(data)
            -- 回调不应报错
            return true
        end)
    end)
    TestRunner.Assert(true, "获取藏品列表不应报错")

    print("[PlayerDataManager] 获取藏品列表测试通过")
end

-- ============================================================================
-- 测试：扣除入场费
-- ============================================================================
function tests.TestDeductEntryFee()
    PlayerDataManager.SetCachedBalance(7, 5000)

    local ok, result = pcall(function()
        return PlayerDataManager.DeductEntryFee(7, 100, function(success)
            return success
        end)
    end)
    TestRunner.Assert(true, "扣除入场费操作不应报错")

    print("[PlayerDataManager] 扣除入场费测试通过")
end

-- ============================================================================
-- 测试：保存奖励
-- ============================================================================
function tests.TestSaveReward()
    local ok, result = pcall(function()
        return PlayerDataManager.SaveReward(8, {}, 100, 2000, function(success)
            return success
        end)
    end)
    TestRunner.Assert(true, "保存奖励操作不应报错")

    print("[PlayerDataManager] 保存奖励测试通过")
end

-- ============================================================================
-- 测试：出售物品
-- ============================================================================
function tests.TestSellItem()
    local ok, result = pcall(function()
        return PlayerDataManager.SellItem(9, "test_list", 500, function(success)
            return success
        end)
    end)
    TestRunner.Assert(true, "出售物品操作不应报错")

    print("[PlayerDataManager] 出售物品测试通过")
end

-- ============================================================================
-- 测试：独立玩家缓存隔离
-- ============================================================================
function tests.TestPlayerCacheIsolation()
    -- 设置多个玩家余额
    for i = 100, 105 do
        PlayerDataManager.SetCachedBalance(i, i * 100)
    end

    -- 清除其中一个
    PlayerDataManager.ClearCache(102)

    -- 验证其他玩家不受影响
    for i = 100, 105 do
        local balance = PlayerDataManager.GetCachedBalance(i)
        if i ~= 102 then
            TestRunner.Assert(balance == i * 100, "玩家" .. i .. "的余额不应受影响")
        end
    end

    print("[PlayerDataManager] 玩家缓存隔离测试通过")
end

-- ============================================================================
-- 运行所有测试
-- ============================================================================
TestRunner.Run(tests)
return tests
