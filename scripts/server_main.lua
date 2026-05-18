-- ============================================================================
-- server_main.lua - 《盲拍暗战》服务端入口
-- 多人模式服务端：游戏逻辑 + 网络同步
-- ============================================================================

local Server = require("Network.Server")

--- 引擎入口（服务端）
function Start()
    Server.Start()
    print("[ServerMain] Server started")
end

--- 引擎退出
function Stop()
    print("[ServerMain] Server stopped")
end
