-- ============================================================================
-- TestRunner.lua - 自动化测试框架
-- 用于核心模块的单元测试和集成测试
-- ============================================================================

local TestRunner = {}

-- ============================================================================
-- 测试结果收集
-- ============================================================================

TestRunner.results = {
    passed = 0,
    failed = 0,
    errors = {},
}

-- ============================================================================
-- 断言函数
-- ============================================================================

--- 断言条件为真
---@param condition boolean
---@param message string 失败时的消息
function TestRunner.Assert(condition, message)
    if not condition then
        error(message or "Assertion failed")
    end
end

--- 断言两个值相等
---@param expected any
---@param actual any
---@param message string|nil
function TestRunner.AssertEqual(expected, actual, message)
    if expected ~= actual then
        local msg = string.format("Expected %s, got %s", tostring(expected), tostring(actual))
        if message then
            msg = msg .. ": " .. message
        end
        error(msg)
    end
end

--- 断言两个值近似相等（用于浮点数）
---@param expected number
---@param actual number
---@param epsilon number 允许的误差
---@param message string|nil
function TestRunner.AssertApprox(expected, actual, epsilon, message)
    epsilon = epsilon or 0.0001
    if math.abs(expected - actual) > epsilon then
        local msg = string.format("Expected ~%f, got %f", expected, actual)
        if message then
            msg = msg .. ": " .. message
        end
        error(msg)
    end
end

--- 断言函数抛出错误
---@param fn function
---@param message string|nil
function TestRunner.AssertError(fn, message)
    local ok, err = pcall(fn)
    if ok then
        error("Expected function to throw, but it succeeded")
    end
    -- 函数正确抛出了错误
end

-- ============================================================================
-- 测试运行器
-- ============================================================================

--- 运行单个测试
---@param name string 测试名称
---@param fn function 测试函数
function TestRunner.Run(name, fn)
    local ok, err = pcall(fn)
    if ok then
        TestRunner.results.passed = TestRunner.results.passed + 1
        print("[PASS] " .. name)
        return true
    else
        TestRunner.results.failed = TestRunner.results.failed + 1
        table.insert(TestRunner.results.errors, { name = name, error = err })
        print("[FAIL] " .. name)
        print("       " .. tostring(err))
        return false
    end
end

--- 运行测试套件
---@param suiteName string
---@param tests table 测试函数表 { name = fn, ... }
function TestRunner.RunSuite(suiteName, tests)
    print("\n========================================")
    print("Test Suite: " .. suiteName)
    print("========================================")

    for name, fn in pairs(tests) do
        TestRunner.Run(name, fn)
    end
end

--- 打印测试结果摘要
function TestRunner.PrintSummary()
    print("\n========================================")
    print("Test Results")
    print("========================================")
    print(string.format("Passed: %d", TestRunner.results.passed))
    print(string.format("Failed: %d", TestRunner.results.failed))

    if #TestRunner.results.errors > 0 then
        print("\nFailed Tests:")
        for _, e in ipairs(TestRunner.results.errors) do
            print(string.format("  - %s: %s", e.name, tostring(e.error)))
        end
    end

    print("========================================\n")
end

--- 重置测试结果
function TestRunner.Reset()
    TestRunner.results = {
        passed = 0,
        failed = 0,
        errors = {},
    }
end

return TestRunner
