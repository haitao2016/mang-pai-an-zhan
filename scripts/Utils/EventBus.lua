-- ============================================================================
-- EventBus.lua - 事件总线系统
-- ----------------------------------------------------------------------------
-- 用途：为所有游戏系统提供统一的事件发布-订阅机制
-- 模式：Publish-Subscribe（发布-订阅）
-- 优势：
--   1. 解耦系统间的依赖（如成就系统不需要知道拍卖管理器）
--   2. 易于扩展（新系统只需订阅感兴趣的事件）
--   3. 便于调试（可追踪所有事件流）
--
-- 使用示例：
--   local EventBus = require("Utils.EventBus")
--
--   -- 订阅事件
--   EventBus.Subscribe("game_end", function(data)
--       print("游戏结束，胜者：" .. data.winnerId)
--   end, "AchievementSystem")
--
--   -- 发布事件
--   EventBus.Publish("game_end", {
--       winnerId = "player_1",
--       totalRounds = 5,
--       duration = 120
--   })
-- ============================================================================

local EventBus = {}

-- ============================================================================
-- 标准事件类型定义（所有系统都应使用这些标准事件）
-- ============================================================================
EventBus.Events = {
    -- --- 游戏生命周期 ---
    GAME_START      = "game_start",      -- 游戏开始
    GAME_END        = "game_end",        -- 游戏结束
    GAME_ABORT      = "game_abort",      -- 游戏异常终止

    -- --- 回合相关 ---
    ROUND_START     = "round_start",     -- 某回合开始
    ROUND_END       = "round_end",       -- 某回合结束
    BID_SUBMIT      = "bid_submit",      -- 玩家提交出价

    -- --- 玩家相关 ---
    PLAYER_JOIN     = "player_join",     -- 玩家加入
    PLAYER_LEAVE    = "player_leave",    -- 玩家离开
    PLAYER_BALANCE  = "player_balance",  -- 余额变化
    PLAYER_CHARACTER = "player_character", -- 玩家选择角色

    -- --- 藏品相关 ---
    ITEM_REVEAL     = "item_reveal",     -- 藏品揭示
    ITEM_COLLECT    = "item_collect",    -- 玩家获得藏品
    ITEM_SELL       = "item_sell",       -- 玩家出售藏品

    -- --- 技能相关 ---
    SKILL_USE       = "skill_use",       -- 技能使用
    SKILL_RESULT    = "skill_result",    -- 技能生效

    -- --- 成就与任务 ---
    ACHIEVEMENT_UNLOCK = "achievement_unlock", -- 成就解锁
    MISSION_COMPLETE   = "mission_complete",   -- 任务完成
    SEASON_PROGRESS    = "season_progress",    -- 赛季进度更新
    SEASON_LEVELUP     = "season_levelup",     -- 赛季升级

    -- --- 系统相关 ---
    SYSTEM_INIT     = "system_init",     -- 系统初始化完成
    CONFIG_RELOAD   = "config_reload",   -- 配置热更新
    ERROR           = "error_event",     -- 系统错误
}

-- ============================================================================
-- 内部状态
-- ============================================================================
local _subscribers = {}    -- { eventType = { { id, callback, owner, priority } } }
local _history = {}        -- 事件历史记录（用于调试）
local _historyMaxSize = 100
local _isInitialized = false
local _nextSubscriberId = 1

-- ============================================================================
-- 辅助函数
-- ============================================================================
local function _GetTimestamp()
    if os and os.time then
        return os.time()
    end
    return 0
end

local function _AddHistory(eventType, data)
    table.insert(_history, {
        type = eventType,
        data = data,
        time = _GetTimestamp()
    })

    -- 限制历史记录大小
    if #_history > _historyMaxSize then
        table.remove(_history, 1)
    end
end

-- ============================================================================
-- 订阅事件
-- ============================================================================
-- 参数：
--   eventType : string              - 事件类型（见 EventBus.Events）
--   callback  : function(data)      - 回调函数
--   owner     : string (可选)       - 订阅者标识（方便调试与取消）
--   priority  : number (可选)       - 优先级，数值越小越先执行
-- 返回：
--   subscriberId : number           - 订阅 ID（用于取消订阅）
-- ============================================================================
function EventBus.Subscribe(eventType, callback, owner, priority)
    if not eventType or type(callback) ~= "function" then
        print("[EventBus] Subscribe 失败：参数无效")
        return nil
    end

    if not _subscribers[eventType] then
        _subscribers[eventType] = {}
    end

    local subscriber = {
        id       = _nextSubscriberId,
        callback = callback,
        owner    = owner or "unknown",
        priority = priority or 100
    }
    _nextSubscriberId = _nextSubscriberId + 1

    table.insert(_subscribers[eventType], subscriber)

    -- 按优先级排序
    table.sort(_subscribers[eventType], function(a, b)
        return a.priority < b.priority
    end)

    return subscriber.id
end

-- ============================================================================
-- 发布事件
-- ============================================================================
-- 参数：
--   eventType : string  - 事件类型
--   data      : table   - 事件数据（可选）
-- ============================================================================
function EventBus.Publish(eventType, data)
    if not eventType then return end

    local eventData = data or {}
    _AddHistory(eventType, eventData)

    -- 获取该事件的订阅者列表
    local subs = _subscribers[eventType]
    if not subs or #subs == 0 then return end

    -- 遍历所有订阅者并调用回调
    for i = 1, #subs do
        local success, err = pcall(function()
            subs[i].callback(eventData)
        end)
        if not success then
            print("[EventBus] 事件处理失败 [" .. eventType .. "] (" .. subs[i].owner .. ")：" .. tostring(err))
        end
    end
end

-- ============================================================================
-- 取消订阅
-- ============================================================================
-- 参数：
--   subscriberId : number  - 通过 Subscribe() 返回的 ID
-- 返回：
--   success : boolean
-- ============================================================================
function EventBus.Unsubscribe(subscriberId)
    if not subscriberId then return false end

    for eventType, subs in pairs(_subscribers) do
        for i = #subs, 1, -1 do
            if subs[i].id == subscriberId then
                table.remove(subs, i)
                return true
            end
        end
    end
    return false
end

-- ============================================================================
-- 按 owner 取消所有订阅
-- ============================================================================
function EventBus.UnsubscribeByOwner(owner)
    if not owner then return 0 end

    local removedCount = 0
    for eventType, subs in pairs(_subscribers) do
        for i = #subs, 1, -1 do
            if subs[i].owner == owner then
                table.remove(subs, i)
                removedCount = removedCount + 1
            end
        end
    end
    return removedCount
end

-- ============================================================================
-- 检查是否有订阅者
-- ============================================================================
function EventBus.HasSubscribers(eventType)
    local subs = _subscribers[eventType]
    return subs and #subs > 0 or false
end

-- ============================================================================
-- 获取订阅者数量
-- ============================================================================
function EventBus.GetSubscriberCount(eventType)
    local subs = _subscribers[eventType]
    return subs and #subs or 0
end

-- ============================================================================
-- 获取事件历史（调试用）
-- ============================================================================
function EventBus.GetHistory(count)
    count = count or _historyMaxSize
    local startIdx = math.max(1, #_history - count + 1)

    local result = {}
    for i = startIdx, #_history do
        table.insert(result, _history[i])
    end
    return result
end

-- ============================================================================
-- 清空所有订阅（重置用）
-- ============================================================================
function EventBus.Clear()
    _subscribers = {}
    _history = {}
    _nextSubscriberId = 1
end

-- ============================================================================
-- 初始化（集成所有系统的事件订阅）
-- ============================================================================
function EventBus.Init()
    if _isInitialized then
        print("[EventBus] 已初始化，跳过")
        return
    end

    _isInitialized = true

    -- 发布系统初始化事件
    EventBus.Publish(EventBus.Events.SYSTEM_INIT, {
        timestamp = _GetTimestamp()
    })

    print("[EventBus] 事件总线初始化完成")
end

-- ============================================================================
-- 便捷订阅：批量订阅多个事件
-- ============================================================================
-- 参数：
--   subscriptions : { eventType = callback } 或 { { eventType, callback, priority } }
--   owner         : string
-- ============================================================================
function EventBus.BatchSubscribe(subscriptions, owner)
    if not subscriptions then return {} end

    local ids = {}

    -- 处理 table 形式 { eventType = callback }
    if type(subscriptions) == "table" then
        for eventType, callback in pairs(subscriptions) do
            if type(callback) == "function" then
                local id = EventBus.Subscribe(eventType, callback, owner)
                if id then table.insert(ids, id) end
            elseif type(callback) == "table" then
                -- { eventType = { callback, priority } }
                local cb = callback[1]
                local pri = callback[2]
                if type(cb) == "function" then
                    local id = EventBus.Subscribe(eventType, cb, owner, pri)
                    if id then table.insert(ids, id) end
                end
            end
        end
    end

    return ids
end

-- ============================================================================
-- 调试：打印所有订阅信息
-- ============================================================================
function EventBus.DebugPrint()
    print("========== EventBus 订阅信息 ==========")
    local total = 0
    for eventType, subs in pairs(_subscribers) do
        if #subs > 0 then
            local owners = {}
            for _, s in ipairs(subs) do
                table.insert(owners, s.owner .. "(p" .. s.priority .. ")")
            end
            print("[" .. eventType .. "] " .. #subs .. " 个订阅者：" .. table.concat(owners, ", "))
            total = total + #subs
        end
    end
    print("总计：" .. total .. " 个订阅")
    print("历史记录数：" .. #_history)
    print("===========================================")
end

return EventBus
