-- ============================================================================
-- RevealSystem.lua - 开箱揭示系统（服务端逻辑）
-- 管理获胜后的开箱揭示流程：逐件揭示 + 总价值揭晓
-- ============================================================================

local Config = require("Config")

---@class RevealSystem
local RevealSystem = {}
RevealSystem.__index = RevealSystem

-- 揭示阶段
RevealSystem.Phase = {
    IDLE     = "idle",       -- 未开始
    SHOWING  = "showing",    -- 逐件展示中
    TOTAL    = "total",      -- 总价值揭晓
    DONE     = "done",       -- 完成
}

--- 创建揭示系统
---@return RevealSystem
function RevealSystem.New()
    local self = setmetatable({}, RevealSystem)
    self.phase = RevealSystem.Phase.IDLE
    self.items = {}              -- 待揭示藏品列表
    self.currentIndex = 0        -- 当前揭示到第几件
    self.totalValue = 0          -- 总价值
    self.bidTotal = 0            -- 竞拍总出价
    self.timer = 0               -- 当前阶段计时器
    self.itemInterval = 0.8      -- 每件藏品展示间隔（秒）— 物品已知，快速回顾
    self.totalShowTime = 2.0     -- 总价值展示时间（秒）

    -- 回调
    self.onRevealStart = nil     -- function()
    self.onRevealItem = nil      -- function(index, item)
    self.onRevealTotal = nil     -- function(totalValue, bidTotal, profit)
    self.onRevealDone = nil      -- function()

    return self
end

--- 开始揭示流程
---@param items table 藏品列表 { {name, rarity, value, ...}, ... }
---@param totalValue number 总价值
---@param bidTotal number 竞拍总出价
function RevealSystem:Start(items, totalValue, bidTotal)
    self.items = items
    self.totalValue = totalValue
    self.bidTotal = bidTotal
    self.currentIndex = 0
    self.phase = RevealSystem.Phase.SHOWING
    self.timer = 0.5  -- 开始前短暂延迟

    print(string.format("[RevealSystem] Starting reveal: %d items, total value: %d, bid: %d",
        #items, totalValue, bidTotal))

    if self.onRevealStart then
        self.onRevealStart()
    end
end

--- 每帧更新
---@param dt number
function RevealSystem:Update(dt)
    if self.phase == RevealSystem.Phase.IDLE or self.phase == RevealSystem.Phase.DONE then
        return
    end

    self.timer = self.timer - dt

    if self.phase == RevealSystem.Phase.SHOWING then
        if self.timer <= 0 then
            self.currentIndex = self.currentIndex + 1
            if self.currentIndex <= #self.items then
                -- 揭示下一件
                local item = self.items[self.currentIndex]
                print(string.format("[RevealSystem] Reveal item %d: %s (%s, %d)",
                    self.currentIndex, item.name, item.rarityName, item.value))

                if self.onRevealItem then
                    self.onRevealItem(self.currentIndex, item)
                end

                self.timer = self.itemInterval
            else
                -- 所有物品揭示完毕，进入总价值展示
                self.phase = RevealSystem.Phase.TOTAL
                self.timer = self.totalShowTime

                local profit = self.totalValue - self.bidTotal
                print(string.format("[RevealSystem] All items revealed. Total: %d, Bid: %d, Profit: %d",
                    self.totalValue, self.bidTotal, profit))

                if self.onRevealTotal then
                    self.onRevealTotal(self.totalValue, self.bidTotal, profit)
                end
            end
        end

    elseif self.phase == RevealSystem.Phase.TOTAL then
        if self.timer <= 0 then
            self.phase = RevealSystem.Phase.DONE
            print("[RevealSystem] Reveal done")

            if self.onRevealDone then
                self.onRevealDone()
            end
        end
    end
end

--- 是否正在揭示中
---@return boolean
function RevealSystem:IsActive()
    return self.phase == RevealSystem.Phase.SHOWING or self.phase == RevealSystem.Phase.TOTAL
end

--- 是否已完成
---@return boolean
function RevealSystem:IsDone()
    return self.phase == RevealSystem.Phase.DONE
end

--- 获取当前阶段
---@return string
function RevealSystem:GetPhase()
    return self.phase
end

--- 重置
function RevealSystem:Reset()
    self.phase = RevealSystem.Phase.IDLE
    self.items = {}
    self.currentIndex = 0
    self.totalValue = 0
    self.bidTotal = 0
    self.timer = 0
end

return RevealSystem
