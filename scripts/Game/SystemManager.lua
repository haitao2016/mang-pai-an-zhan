-- ============================================================================
-- SystemManager.lua - 系统统一管理器
-- ----------------------------------------------------------------------------
-- 用途：
--   1. 统一管理所有游戏系统的初始化顺序
--   2. 管理系统间的依赖关系
--   3. 提供统一的系统查询与状态管理
--   4. 与 EventBus 集成，自动注册事件订阅
--
-- 系统初始化顺序：
--   Config → EventBus → AntiCheat → PlayerData → AuctionManager
--   → BidSystem → RoundManager → CharacterSystem → RevealSystem
--   → ItemPool → SoundManager → AchievementSystem → DailyMissionSystem
--   → SeasonSystem → FriendSystem → Leaderboard → Profile
--   → TutorialManager → GameUI
-- ============================================================================

local Config = require("Config")
local EventBus = require("Utils.EventBus")

local SystemManager = {}

-- ============================================================================
-- 系统注册表
-- ============================================================================
-- 每个系统的定义：
--   name     : 系统名称
--   module   : Lua 模块路径（require 路径）
--   depends  : 依赖的系统名称列表
--   priority : 初始化优先级（越小越早）
--   optional : 是否为可选系统
-- ============================================================================
local _SystemRegistry = {
    -- --- 基础工具（最高优先级）---
    {
        name     = "EventBus",
        module   = "Utils.EventBus",
        depends  = {},
        priority = 1,
        instance = nil,
        init     = function(m) m.Init() end
    },
    {
        name     = "Helper",
        module   = "Utils.Helper",
        depends  = {},
        priority = 2,
        instance = nil
    },
    {
        name     = "AntiCheat",
        module   = "Utils.AntiCheat",
        depends  = { "EventBus" },
        priority = 5,
        instance = nil,
        init     = function(m) m.Init() end
    },
    {
        name     = "SoundManager",
        module   = "Utils.SoundManager",
        depends  = { "EventBus" },
        priority = 6,
        instance = nil,
        init     = function(m)
            -- 需要外部传入 scene，这里做延迟初始化
            if m.Init then
                -- 跳过，由 GameUI 统一管理
            end
        end
    },

    -- --- 玩家与数据管理 ---
    {
        name     = "PlayerDataManager",
        module   = "Game.PlayerDataManager",
        depends  = { "EventBus" },
        priority = 10,
        instance = nil
    },

    -- --- 游戏核心系统 ---
    {
        name     = "BidSystem",
        module   = "Game.BidSystem",
        depends  = { "EventBus" },
        priority = 20,
        instance = nil
    },
    {
        name     = "RoundManager",
        module   = "Game.RoundManager",
        depends  = { "BidSystem", "EventBus" },
        priority = 21,
        instance = nil
    },
    {
        name     = "CharacterSystem",
        module   = "Game.CharacterSystem",
        depends  = { "EventBus" },
        priority = 22,
        instance = nil
    },
    {
        name     = "ItemPool",
        module   = "Game.ItemPool",
        depends  = { "EventBus" },
        priority = 23,
        instance = nil
    },
    {
        name     = "RevealSystem",
        module   = "Game.RevealSystem",
        depends  = { "ItemPool", "EventBus" },
        priority = 24,
        instance = nil
    },
    {
        name     = "AuctionManager",
        module   = "Game.AuctionManager",
        depends  = { "RoundManager", "BidSystem", "RevealSystem", "EventBus" },
        priority = 25,
        instance = nil
    },

    -- --- 扩展系统（v1.0 已存在）---
    {
        name     = "AchievementSystem",
        module   = "Game.AchievementSystem",
        depends  = { "EventBus", "PlayerDataManager" },
        priority = 30,
        instance = nil,
        init     = function(m)
            if m.RegisterEvents then m.RegisterEvents() end
        end
    },
    {
        name     = "DailyMissionSystem",
        module   = "Game.DailyMissionSystem",
        depends  = { "EventBus", "PlayerDataManager" },
        priority = 31,
        instance = nil,
        init     = function(m)
            if m.RegisterEvents then m.RegisterEvents() end
        end
    },

    -- --- 扩展系统（v1.1 新增）---
    {
        name     = "SeasonSystem",
        module   = "Game.SeasonSystem",
        depends  = { "EventBus", "PlayerDataManager", "AchievementSystem" },
        priority = 32,
        instance = nil,
        init     = function(m)
            if m.RegisterEvents then m.RegisterEvents() end
        end,
        optional = true  -- 如果找不到模块不会报错
    },
    {
        name     = "FriendSystem",
        module   = "Game.FriendSystem",
        depends  = { "EventBus", "PlayerDataManager" },
        priority = 33,
        instance = nil,
        optional = true
    },
    {
        name     = "LeaderboardSystem",
        module   = "Game.LeaderboardSystem",
        depends  = { "EventBus", "PlayerDataManager" },
        priority = 34,
        instance = nil,
        optional = true
    },
    {
        name     = "ProfileSystem",
        module   = "Game.ProfileSystem",
        depends  = { "EventBus", "PlayerDataManager" },
        priority = 35,
        instance = nil,
        optional = true
    },
    {
        name     = "RoomSystem",
        module   = "Game.RoomSystem",
        depends  = { "EventBus", "AuctionManager" },
        priority = 36,
        instance = nil,
        optional = true
    },

    -- --- 新手引导 ---
    {
        name     = "TutorialManager",
        module   = "Utils.TutorialManager",
        depends  = { "EventBus" },
        priority = 40,
        instance = nil,
        init     = function(m)
            if m.Init then m.Init() end
        end
    },
}

-- ============================================================================
-- 内部状态
-- ============================================================================
local _initialized = false
local _systemStatus = {}  -- name = "pending" | "loading" | "ready" | "error"
local _initializedSystems = {}

-- ============================================================================
-- 辅助：按优先级排序系统
-- ============================================================================
local function _GetSortedSystems()
    local sorted = {}
    for _, sys in ipairs(_SystemRegistry) do
        table.insert(sorted, sys)
    end
    table.sort(sorted, function(a, b)
        return a.priority < b.priority
    end)
    return sorted
end

-- ============================================================================
-- 辅助：检查依赖是否满足
-- ============================================================================
local function _CheckDependencies(system)
    if not system.depends or #system.depends == 0 then
        return true
    end
    for _, depName in ipairs(system.depends) do
        if _systemStatus[depName] ~= "ready" then
            -- 如果是可选依赖且未加载，跳过
            local depSys = SystemManager.GetSystemInfo(depName)
            if depSys and depSys.optional and _systemStatus[depName] == nil then
                -- 可选且未加载，视为满足（不强制）
            else
                return false
            end
        end
    end
    return true
end

-- ============================================================================
-- 初始化所有系统
-- ============================================================================
function SystemManager.Init()
    if _initialized then
        print("[SystemManager] 已初始化，跳过")
        return true
    end

    print("[SystemManager] 开始初始化系统...")

    -- 按优先级排序系统
    local sortedSystems = _GetSortedSystems()

    -- 初始化每个系统
    for _, sys in ipairs(sortedSystems) do
        _systemStatus[sys.name] = "loading"

        -- 尝试加载模块
        local success, module = pcall(function()
            return require(sys.module)
        end)

        if not success then
            if sys.optional then
                print("[SystemManager] 跳过可选系统：" .. sys.name .. "（模块未找到）")
                _systemStatus[sys.name] = nil
            else
                print("[SystemManager] ❌ 必需系统加载失败：" .. sys.name)
                print("  错误：" .. tostring(module))
                _systemStatus[sys.name] = "error"
            end
            -- 继续下一个
        else
            -- 模块加载成功，存储实例
            sys.instance = module

            -- 检查依赖
            if not _CheckDependencies(sys) then
                print("[SystemManager] ⚠️ 系统" .. sys.name .. "依赖未满足，延迟初始化")
                _systemStatus[sys.name] = "pending"
            else
                -- 执行初始化
                if sys.init then
                    local initOk, initErr = pcall(function()
                        sys.init(module)
                    end)
                    if not initOk then
                        print("[SystemManager] ❌ 系统" .. sys.name .. "初始化失败：" .. tostring(initErr))
                        _systemStatus[sys.name] = "error"
                    else
                        _systemStatus[sys.name] = "ready"
                        table.insert(_initializedSystems, sys.name)
                        print("[SystemManager] ✅ " .. sys.name .. " 初始化完成")
                    end
                else
                    _systemStatus[sys.name] = "ready"
                    table.insert(_initializedSystems, sys.name)
                end
            end
        end
    end

    _initialized = true

    print("[SystemManager] ========================================")
    print("[SystemManager] 初始化完成，共 " .. #_initializedSystems .. " 个系统就绪")
    print("[SystemManager] ========================================")

    -- 发布系统初始化完成事件
    EventBus.Publish(EventBus.Events.SYSTEM_INIT, {
        systems = _initializedSystems,
        count = #_initializedSystems
    })

    return true
end

-- ============================================================================
-- 获取系统状态信息
-- ============================================================================
function SystemManager.GetSystemInfo(name)
    for _, sys in ipairs(_SystemRegistry) do
        if sys.name == name then
            return {
                name = sys.name,
                status = _systemStatus[name] or "not_loaded",
                priority = sys.priority,
                depends = sys.depends,
                optional = sys.optional or false,
                module = sys.module,
                instance = sys.instance
            }
        end
    end
    return nil
end

-- ============================================================================
-- 获取所有已初始化系统的列表
-- ============================================================================
function SystemManager.GetInitializedSystems()
    local list = {}
    for _, name in ipairs(_initializedSystems) do
        table.insert(list, name)
    end
    return list
end

-- ============================================================================
-- 检查系统是否就绪
-- ============================================================================
function SystemManager.IsReady(name)
    return _systemStatus[name] == "ready"
end

-- ============================================================================
-- 注册新系统（运行时扩展）
-- ============================================================================
function SystemManager.RegisterSystem(config)
    if not config or not config.name or not config.module then
        print("[SystemManager] RegisterSystem 失败：配置无效")
        return false
    end

    -- 检查是否已存在
    for _, sys in ipairs(_SystemRegistry) do
        if sys.name == config.name then
            print("[SystemManager] 系统" .. config.name .. "已存在，更新配置")
            sys.module = config.module
            sys.depends = config.depends or sys.depends
            sys.priority = config.priority or sys.priority
            sys.optional = config.optional or sys.optional
            sys.init = config.init or sys.init
            return true
        end
    end

    -- 添加新系统
    local newSys = {
        name = config.name,
        module = config.module,
        depends = config.depends or {},
        priority = config.priority or 100,
        optional = config.optional or false,
        init = config.init,
        instance = nil
    }
    table.insert(_SystemRegistry, newSys)

    -- 如果已初始化完成，尝试初始化新系统
    if _initialized then
        _systemStatus[newSys.name] = "loading"
        local ok, mod = pcall(function() return require(newSys.module) end)
        if ok then
            newSys.instance = mod
            if newSys.init then
                pcall(function() newSys.init(mod) end)
            end
            _systemStatus[newSys.name] = "ready"
            table.insert(_initializedSystems, newSys.name)
            print("[SystemManager] ✅ 动态注册系统：" .. newSys.name)
        elseif not newSys.optional then
            print("[SystemManager] ❌ 动态注册失败：" .. newSys.name)
            _systemStatus[newSys.name] = "error"
        end
    end

    return true
end

-- ============================================================================
-- 重置所有系统状态（调试用）
-- ============================================================================
function SystemManager.Reset()
    _initialized = false
    _systemStatus = {}
    _initializedSystems = {}
    for _, sys in ipairs(_SystemRegistry) do
        sys.instance = nil
    end
    EventBus.Clear()
    print("[SystemManager] 系统状态已重置")
end

-- ============================================================================
-- 打印当前系统状态（调试用）
-- ============================================================================
function SystemManager.DebugPrint()
    print("========== SystemManager 状态 ==========")
    local sorted = _GetSortedSystems()
    for _, sys in ipairs(sorted) do
        local status = _systemStatus[sys.name] or "not_loaded"
        local statusIcon = "⚪"
        if status == "ready" then statusIcon = "✅"
        elseif status == "loading" then statusIcon = "⏳"
        elseif status == "error" then statusIcon = "❌"
        elseif status == "pending" then statusIcon = "⚠️"
        end
        print(statusIcon .. " " .. sys.name .. " (优先级: " .. sys.priority .. ")")
    end
    print("==========================================")
    print("就绪系统数：" .. #_initializedSystems)
end

return SystemManager
