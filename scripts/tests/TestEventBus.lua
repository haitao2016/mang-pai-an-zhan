-- ============================================================================
-- TestEventBus.lua - 事件总线单元测试
-- ============================================================================

local TestRunner = require("Utils.TestRunner")
local EventBus = require("Utils.EventBus")

local tests = TestRunner.NewSuite("EventBus")

-- ============================================================================
-- 测试：标准事件定义
-- ============================================================================
function tests.TestEventConstants()
    TestRunner.Assert(EventBus.Events.GAME_START ~= nil, "Should have GAME_START event")
    TestRunner.Assert(EventBus.Events.GAME_END ~= nil, "Should have GAME_END event")
    TestRunner.Assert(EventBus.Events.ROUND_START ~= nil, "Should have ROUND_START event")
    TestRunner.Assert(EventBus.Events.ROUND_END ~= nil, "Should have ROUND_END event")
    TestRunner.Assert(EventBus.Events.BID_SUBMIT ~= nil, "Should have BID_SUBMIT event")
    TestRunner.Assert(EventBus.Events.ITEM_COLLECT ~= nil, "Should have ITEM_COLLECT event")
    TestRunner.Assert(EventBus.Events.SKILL_USE ~= nil, "Should have SKILL_USE event")

    print("[EventBus] 事件常量测试通过")
end

-- ============================================================================
-- 测试：订阅事件
-- ============================================================================
function tests.TestSubscribe()
    -- 清空之前的状态
    EventBus.Clear()

    local callCount = 0
    local function testCallback(data)
        callCount = callCount + 1
    end

    local subId = EventBus.Subscribe("test_event", testCallback, "TestSubscriber")
    TestRunner.Assert(subId ~= nil, "Should return subscriber ID")
    TestRunner.Assert(type(subId) == "number", "Subscriber ID should be number")

    print("[EventBus] 订阅测试通过, ID: " .. subId)
end

-- ============================================================================
-- 测试：发布事件
-- ============================================================================
function tests.TestPublish()
    EventBus.Clear()

    local receivedData = nil
    local callCount = 0

    EventBus.Subscribe("test_event_2", function(data)
        receivedData = data
        callCount = callCount + 1
    end, "TestPublisher")

    EventBus.Publish("test_event_2", { message = "hello" })

    TestRunner.Assert(callCount == 1, "Callback should be called once")
    TestRunner.Assert(receivedData.message == "hello", "Should receive correct data")

    print("[EventBus] 发布测试通过")
end

-- ============================================================================
-- 测试：多个订阅者
-- ============================================================================
function tests.TestMultipleSubscribers()
    EventBus.Clear()

    local count1, count2 = 0, 0

    EventBus.Subscribe("multi_event", function() count1 = count1 + 1 end, "Sub1")
    EventBus.Subscribe("multi_event", function() count2 = count2 + 1 end, "Sub2")
    EventBus.Subscribe("multi_event", function() count2 = count2 + 1 end, "Sub3")

    EventBus.Publish("multi_event", {})

    TestRunner.Assert(count1 == 1, "First subscriber should be called")
    TestRunner.Assert(count2 == 2, "Other subscribers should be called")

    print("[EventBus] 多订阅者测试通过")
end

-- ============================================================================
-- 测试：取消订阅
-- ============================================================================
function tests.TestUnsubscribe()
    EventBus.Clear()

    local callCount = 0
    local callback = function() callCount = callCount + 1 end

    local subId = EventBus.Subscribe("unsub_event", callback, "UnsubTest")
    EventBus.Publish("unsub_event", {})
    TestRunner.Assert(callCount == 1, "Should be called once before unsubscribe")

    EventBus.Unsubscribe(subId)
    EventBus.Publish("unsub_event", {})
    TestRunner.Assert(callCount == 1, "Should NOT be called after unsubscribe")

    print("[EventBus] 取消订阅测试通过")
end

-- ============================================================================
-- 测试：按 Owner 取消订阅
-- ============================================================================
function tests.TestUnsubscribeByOwner()
    EventBus.Clear()

    local count = 0

    EventBus.Subscribe("owner_event_1", function() count = count + 1 end, "OwnerA")
    EventBus.Subscribe("owner_event_2", function() count = count + 1 end, "OwnerA")
    EventBus.Subscribe("owner_event_3", function() count = count + 1 end, "OwnerB")

    EventBus.Publish("owner_event_1", {})
    EventBus.Publish("owner_event_2", {})
    EventBus.Publish("owner_event_3", {})

    TestRunner.Assert(count == 3, "All should be called before unsubscribe")

    local removed = EventBus.UnsubscribeByOwner("OwnerA")
    TestRunner.Assert(removed == 2, "Should remove 2 subscriptions for OwnerA")

    EventBus.Clear()
    EventBus.Publish("owner_event_1", {})
    EventBus.Publish("owner_event_2", {})
    EventBus.Publish("owner_event_3", {})

    TestRunner.Assert(count == 3, "OwnerA events should NOT trigger after clear")
    TestRunner.Assert(EventBus.GetSubscriberCount("owner_event_3") == 0, "All should be cleared")

    print("[EventBus] 按 Owner 取消订阅测试通过")
end

-- ============================================================================
-- 测试：订阅者数量
-- ============================================================================
function tests.TestGetSubscriberCount()
    EventBus.Clear()

    TestRunner.Assert(EventBus.GetSubscriberCount("nonexistent") == 0, "Should return 0 for nonexistent")

    EventBus.Subscribe("count_test", function() end, "Test1")
    EventBus.Subscribe("count_test", function() end, "Test2")

    TestRunner.Assert(EventBus.GetSubscriberCount("count_test") == 2, "Should have 2 subscribers")

    print("[EventBus] 订阅者数量测试通过")
end

-- ============================================================================
-- 测试：事件历史
-- ============================================================================
function tests.TestHistory()
    EventBus.Clear()

    EventBus.Publish("history_1", { data = 1 })
    EventBus.Publish("history_2", { data = 2 })

    local history = EventBus.GetHistory(10)
    TestRunner.Assert(#history >= 2, "Should have at least 2 history entries")

    print("[EventBus] 事件历史测试通过，共 " .. #history .. " 条记录")
end

-- ============================================================================
-- 测试：批量订阅
-- ============================================================================
function tests.TestBatchSubscribe()
    EventBus.Clear()

    local calls = {}
    local subs = EventBus.BatchSubscribe({
        eventA = function() calls.A = true end,
        eventB = function() calls.B = true end,
        eventC = function() calls.C = true end
    }, "BatchTest")

    TestRunner.Assert(#subs == 3, "Should have 3 subscriptions")

    EventBus.Publish("eventA", {})
    EventBus.Publish("eventB", {})
    EventBus.Publish("eventC", {})

    TestRunner.Assert(calls.A == true, "eventA should trigger")
    TestRunner.Assert(calls.B == true, "eventB should trigger")
    TestRunner.Assert(calls.C == true, "eventC should trigger")

    print("[EventBus] 批量订阅测试通过")
end

-- ============================================================================
-- 测试：优先级排序
-- ============================================================================
function tests.TestPriority()
    EventBus.Clear()

    local order = {}
    EventBus.Subscribe("priority_test", function() table.insert(order, 3) end, "Low", 300)
    EventBus.Subscribe("priority_test", function() table.insert(order, 1) end, "High", 100)
    EventBus.Subscribe("priority_test", function() table.insert(order, 2) end, "Medium", 200)

    EventBus.Publish("priority_test", {})

    TestRunner.Assert(order[1] == 1, "High priority should execute first")
    TestRunner.Assert(order[2] == 2, "Medium priority should execute second")
    TestRunner.Assert(order[3] == 3, "Low priority should execute last")

    print("[EventBus] 优先级测试通过，执行顺序: " .. table.concat(order, " < "))
end

-- ============================================================================
-- 测试：Clear 重置
-- ============================================================================
function tests.TestClear()
    EventBus.Subscribe("clear_test", function() end, "Test")

    TestRunner.Assert(EventBus.GetSubscriberCount("clear_test") > 0, "Should have subscribers before clear")

    EventBus.Clear()

    TestRunner.Assert(EventBus.GetSubscriberCount("clear_test") == 0, "Should have no subscribers after clear")

    print("[EventBus] 清空测试通过")
end

-- ============================================================================
-- 运行所有测试
-- ============================================================================
TestRunner.Run(tests)

return tests
