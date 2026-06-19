-- ============================================================================
-- SystemManager.lua - 游戏系统统一管理器
-- ----------------------------------------------------------------------------
-- 功能：
--   1. 统一初始化所有游戏系统（v1.0 / v1.1 / v1.2）
--   2. 管理系统间的依赖关系
--   3. 统一注册所有事件监听器
--   4. 提供系统查询和控制接口
--
-- 使用方式：
--   local SystemManager = require("Game.SystemManager")
--   SystemManager.Init()  -- 初始化所有系统
--   SystemManager.Start() -- 启动所有系统
-- ============================================================================

local Config = require("Config")
local EventBus = require("Utils.EventBus")

local SystemManager = {}

-- ============================================================================
-- 内部状态
-- ============================================================================
local _systems = {}          -- { systemName = { instance, initialized, started } }
local _initialized = false
local _started = false

-- ============================================================================
-- 系统注册表：定义所有游戏系统及其依赖
-- ============================================================================
-- 每个系统定义：name, module, dependencies, priority
--   priority 越小越先初始化
-- ============================================================================
SystemManager.SystemRegistry = {
    -- ── v1.0 核心系统 ──
    { name = "EventBus",         module = "Utils.EventBus",          priority = 1 },
    { name = "Config",           module = "Config",                   priority = 1 },

    -- ── v1.1 游戏系统 ──
    { name = "SeasonSystem",     module = "Game.SeasonSystem",        priority = 10 },
    { name = "FriendSystem",     module = "Game.FriendSystem",        priority = 10 },
    { name = "LeaderboardSystem", module = "Game.LeaderboardSystem", priority = 10 },
    { name = "ProfileSystem",    module = "Game.ProfileSystem",       priority = 10 },
    { name = "ItemSetSystem",    module = "Game.ItemSetSystem",       priority = 10 },
    { name = "EventModeSystem",  module = "Game.EventModeSystem",     priority = 10 },
    { name = "RoomSystem",       module = "Game.RoomSystem",          priority = 10 },

    -- ── v1.2 新系统 ──
    { name = "TournamentSystem", module = "Game.TournamentSystem",    priority = 20 },
    { name = "TeamBattleSystem", module = "Game.TeamBattleSystem",    priority = 20 },
    { name = "TradeSystem",      module = "Game.TradeSystem",         priority = 20 },
    { name = "SkinSystem",       module = "Game.SkinSystem",          priority = 20 },

    -- ── v1.3 新系统 ──
    { name = "GuildSystem",      module = "Game.GuildSystem",         priority = 30 },
    { name = "EquipmentSystem",  module = "Game.EquipmentSystem",     priority = 30 },
}

-- ============================================================================
-- 获取系统数量统计
-- ============================================================================
function SystemManager.GetSystemStats()
    local v1_0 = 0
    local v1_1 = 0
    local v1_2 = 0
    local v1_3 = 0

    for _, sys in ipairs(SystemManager.SystemRegistry) do
        if sys.priority == 1 then
            v1_0 = v1_0 + 1
        elseif sys.priority == 10 then
            v1_1 = v1_1 + 1
        elseif sys.priority == 20 then
            v1_2 = v1_2 + 1
        elseif sys.priority == 30 then
            v1_3 = v1_3 + 1
        end
    end

    return {
        total = #SystemManager.SystemRegistry,
        v1_0 = v1_0,
        v1_1 = v1_1,
        v1_2 = v1_2,
        v1_3 = v1_3
    }
end

-- ============================================================================
-- 初始化所有系统
-- ============================================================================
function SystemManager.Init()
    if _initialized then
        print("[SystemManager] 已初始化，跳过")
        return true
    end

    print("============================================================")
    print("[SystemManager] 开始初始化游戏系统...")
    print("============================================================")

    local stats = SystemManager.GetSystemStats()
    print("[SystemManager] 系统总数: " .. stats.total)
    print("                 v1.0 核心: " .. stats.v1_0)
    print("                 v1.1 游戏: " .. stats.v1_1)
    print("                 v1.2 新系统: " .. stats.v1_2)
    print("                 v1.3 社交: " .. stats.v1_3)

    -- 按优先级排序
    local sorted = {}
    for _, sys in ipairs(SystemManager.SystemRegistry) do
        table.insert(sorted, sys)
    end
    table.sort(sorted, function(a, b)
        return a.priority < b.priority
    end)

    -- 逐个初始化
    local initializedCount = 0
    local failedCount = 0

    for _, sys in ipairs(sorted) do
        local ok, err = pcall(function()
            local systemModule = require(sys.module)

            -- 记录系统
            _systems[sys.name] = {
                module = systemModule,
                initialized = true,
                started = false
            }

            print("[SystemManager]   ✓ " .. sys.name .. " 初始化完成")
            initializedCount = initializedCount + 1
        end)

        if not ok then
            print("[SystemManager]   ✗ " .. sys.name .. " 初始化失败: " .. tostring(err))
            failedCount = failedCount + 1
        end
    end

    _initialized = true

    print("============================================================")
    print("[SystemManager] 初始化完成: " .. initializedCount .. " ✓, " .. failedCount .. " ✗")
    print("============================================================")

    EventBus.Publish(EventBus.Events.SYSTEM_INIT, {
        total = stats.total,
        initialized = initializedCount,
        failed = failedCount
    })

    return failedCount == 0
end

-- ============================================================================
-- 启动所有系统（注册事件监听器）
-- ============================================================================
function SystemManager.Start()
    if not _initialized then
        print("[SystemManager] 错误：未初始化，先调用 Init()")
        return false
    end

    if _started then
        print("[SystemManager] 已启动，跳过")
        return true
    end

    print("============================================================")
    print("[SystemManager] 启动系统事件监听...")
    print("============================================================")

    for sysName, sysData in pairs(_systems) do
        if sysData.module and sysData.module.RegisterEvents then
            local ok, err = pcall(function()
                sysData.module.RegisterEvents()
                sysData.started = true
            end)
            if ok then
                print("[SystemManager]   ✓ " .. sysName .. " 事件监听已注册")
            else
                print("[SystemManager]   ✗ " .. sysName .. " 事件注册失败: " .. tostring(err))
            end
        end
    end

    _started = true

    print("============================================================")
    print("[SystemManager] 所有系统启动完成！")
    print("============================================================")

    return true
end

-- ============================================================================
-- 重置所有系统（用于测试）
-- ============================================================================
function SystemManager.Reset()
    for sysName, sysData in pairs(_systems) do
        if sysData.module and sysData.module.Reset then
            pcall(function()
                sysData.module.Reset()
            end)
        end
    end

    _systems = {}
    _initialized = false
    _started = false

    EventBus.Clear()

    print("[SystemManager] 所有系统已重置")
end

-- ============================================================================
-- 获取系统实例
-- ============================================================================
function SystemManager.GetSystem(systemName)
    if _systems[systemName] then
        return _systems[systemName].module
    end
    return nil
end

-- ============================================================================
-- 检查系统是否已初始化
-- ============================================================================
function SystemManager.IsInitialized()
    return _initialized
end

-- ============================================================================
-- 检查系统是否已启动
-- ============================================================================
function SystemManager.IsStarted()
    return _started
end

-- ============================================================================
-- 打印所有系统状态
-- ============================================================================
function SystemManager.PrintStatus()
    print("========== SystemManager 状态 ==========")
    print("已初始化: " .. tostring(_initialized))
    print("已启动: " .. tostring(_started))
    print("已加载系统:")
    for sysName, sysData in pairs(_systems) do
        local status = sysData.started and "已启动" or "已加载"
        print("  - " .. sysName .. ": " .. status)
    end
    print("========================================")
end

return SystemManager
