-- ============================================================================
-- client_main.lua - 《盲拍暗战》客户端入口
-- 多人模式客户端：网络连接 + UI 渲染
-- ============================================================================

require "LuaScripts/Utilities/Sample"

local Client = require("Network.Client")
local GameUI = require("UI.GameUI")

--- 引擎入口（客户端）
function Start()
    -- 启动客户端网络
    Client.Start()

    -- 初始化 UI 系统（传入 Client 引用，UI 通过回调驱动）
    GameUI.Init(Client)

    -- 订阅 Update 驱动 UI 定时器（toast 自动隐藏等）
    SubscribeToEvent("Update", "HandleUpdate")

    print("[ClientMain] Client started")
end

--- 每帧更新
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    GameUI.Update(dt)
end

--- 引擎退出
function Stop()
    GameUI.Shutdown()
    print("[ClientMain] Client stopped")
end
