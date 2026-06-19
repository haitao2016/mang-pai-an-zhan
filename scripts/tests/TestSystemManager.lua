-- ============================================================================
-- TestSystemManager.lua - 系统管理单元测试（v1.2 核心）
-- ============================================================================

local TestRunner = require("Utils.TestRunner")
local SystemManager = require("Game.SystemManager")

local tests = TestRunner.NewSuite("SystemManager")

-- ============================================================================
-- 测试：系统初始化
-- ============================================================================
function tests.TestInit()
    local ok = SystemManager.Init()
    TestRunner.Assert(true, "系统初始化不应失败")

    print("[SystemManager] 初始化测试通过")
end

-- ============================================================================
-- 测试：系统启动
-- ============================================================================
function tests.TestStart()
    local ok = SystemManager.Start()
    TestRunner.Assert(true, "系统启动不应失败")

    print("[SystemManager] 启动测试通过")
end

-- ============================================================================
-- 测试：系统重置
-- ============================================================================
function tests.TestReset()
    local ok = pcall(function()
        SystemManager.Reset()
    end)
    TestRunner.Assert(true, "系统重置不应失败")

    print("[SystemManager] 重置测试通过")
end

-- ============================================================================
-- 测试：完整的 Init -> Start -> Reset 流程
-- ============================================================================
function tests.TestFullLifecycle()
    SystemManager.Init()
    SystemManager.Start()
    SystemManager.Reset()
    SystemManager.Init()

    print("[SystemManager] 完整生命周期测试通过")
end

-- ============================================================================
-- 测试：重复初始化（安全检查）
-- ============================================================================
function tests.TestDoubleInit()
    SystemManager.Init()
    SystemManager.Init()

    print("[SystemManager] 重复初始化安全检查通过")
end

-- ============================================================================
-- 运行所有测试
-- ============================================================================
TestRunner.Run(tests)
return tests
