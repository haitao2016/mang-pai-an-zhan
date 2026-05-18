-- ============================================================================
-- ItemPool.lua - 藏品池（服务端）
-- 数据驱动，从 ItemData 加载 300 件藏品，支持分厅稀有度/价值区间
-- ============================================================================

local Config   = require("Config")
local ItemData = require("Data.ItemData")

---@class ItemPool
local ItemPool = {}
ItemPool.__index = ItemPool

--- 在范围内随机一个整数
---@param min number
---@param max number
---@return number
local function RandomRange(min, max)
    return math.random(math.floor(min), math.floor(max))
end

--- 创建藏品池
---@param hallConfig table|nil 拍卖厅配置（来自 Config.AuctionHalls[i]），为 nil 时使用默认
---@return ItemPool
function ItemPool.New(hallConfig)
    local self = setmetatable({}, ItemPool)

    -- 拍卖厅相关参数
    local hall = hallConfig or Config.AuctionHalls[1]
    self.hallId = hall.id
    self.itemValueRange = hall.itemValueRange or {100, 14000}
    self.itemCountPerBox = hall.itemCountPerBox or 5

    -- 稀有度权重：优先使用厅的 rarityWeights，否则用全局 Config.Rarity
    local rw = hall.rarityWeights
    self.rarityWeights = {}
    self.totalWeight = 0
    for i = 1, 4 do
        local w = rw and rw[i] or Config.Rarity[i].weight
        self.rarityWeights[i] = w
        self.totalWeight = self.totalWeight + w
    end

    -- 从 ItemData 按稀有度分组，并过滤价值区间
    self.templatesByRarity = { {}, {}, {}, {} }
    local vMin, vMax = self.itemValueRange[1], self.itemValueRange[2]

    for _, tmpl in ipairs(ItemData.Items) do
        -- 只保留价值区间与本厅有交集的藏品
        if tmpl.valueRange[2] >= vMin and tmpl.valueRange[1] <= vMax then
            table.insert(self.templatesByRarity[tmpl.rarity], tmpl)
        end
    end

    -- 调试日志
    local counts = {}
    for i = 1, 4 do counts[i] = #self.templatesByRarity[i] end
    print(string.format("[ItemPool] Hall=%s templates: %d/%d/%d/%d (普/稀/史/传)",
        self.hallId, counts[1], counts[2], counts[3], counts[4]))

    return self
end

--- 按加权随机选择稀有度
---@return number rarity 1-4
function ItemPool:_RollRarity()
    local roll = math.random() * self.totalWeight
    local acc = 0
    for i = 1, 4 do
        acc = acc + self.rarityWeights[i]
        if roll <= acc then
            return i
        end
    end
    return 1
end

--- 带锦鲤体质修正的稀有度骰子
---@param luckyBonus number|nil 提升概率（如 0.10 = +10%）
---@return number rarity 1-4
function ItemPool:_RollRarityWithBonus(luckyBonus)
    if not luckyBonus or luckyBonus <= 0 then
        return self:_RollRarity()
    end

    -- 将部分普通权重转移到稀有/史诗/传说
    local adjusted = {}
    local bonus = self.rarityWeights[1] * luckyBonus  -- 从普通权重借走
    adjusted[1] = self.rarityWeights[1] - bonus
    -- 将借走的权重按比例分配给高稀有度
    adjusted[2] = self.rarityWeights[2] + bonus * 0.50
    adjusted[3] = self.rarityWeights[3] + bonus * 0.30
    adjusted[4] = self.rarityWeights[4] + bonus * 0.20

    local total = 0
    for i = 1, 4 do total = total + adjusted[i] end

    local roll = math.random() * total
    local acc = 0
    for i = 1, 4 do
        acc = acc + adjusted[i]
        if roll <= acc then return i end
    end
    return 1
end

--- 生成一个随机藏品
---@param luckyBonus number|nil 锦鲤体质加成
---@return table { name, category, rarity, value, rarityName, rarityColor }
function ItemPool:GenerateItem(luckyBonus)
    local rarity = self:_RollRarityWithBonus(luckyBonus)
    local templates = self.templatesByRarity[rarity]

    -- 如果该稀有度没有模板，降级
    while #templates == 0 and rarity > 1 do
        rarity = rarity - 1
        templates = self.templatesByRarity[rarity]
    end
    -- 保底：如果全空，从 1 级开始升级
    if #templates == 0 then
        for r = 1, 4 do
            if #self.templatesByRarity[r] > 0 then
                rarity = r
                templates = self.templatesByRarity[r]
                break
            end
        end
    end

    local tmpl = templates[math.random(1, #templates)]

    -- 价值在模板范围内随机，但 clamp 到厅的价值区间
    local vMin = math.max(tmpl.valueRange[1], self.itemValueRange[1])
    local vMax = math.min(tmpl.valueRange[2], self.itemValueRange[2])
    if vMin > vMax then vMin = tmpl.valueRange[1]; vMax = tmpl.valueRange[2] end
    local value = RandomRange(vMin, vMax)

    local rarityInfo = Config.Rarity[rarity]
    return {
        name       = tmpl.name,
        category   = tmpl.category or "",
        rarity     = rarity,
        value      = value,
        valueRange = { vMin, vMax },
        rarityName = rarityInfo.name,
        rarityColor = rarityInfo.color,
    }
end

--- 生成一箱藏品（多件，总价值在合理范围内）
---@param itemCount number|nil 藏品数量（默认使用厅配置）
---@param targetTotalMin number|nil 目标最低总价值（可选）
---@param targetTotalMax number|nil 目标最高总价值（可选）
---@param luckyBonus number|nil 锦鲤体质加成
---@return table items 藏品列表
---@return number totalValue 总价值
function ItemPool:GenerateBox(itemCount, targetTotalMin, targetTotalMax, luckyBonus)
    itemCount = itemCount or self.itemCountPerBox

    -- 根据厅的价值区间自动计算合理的总价值范围
    if not targetTotalMin then
        targetTotalMin = self.itemValueRange[1] * itemCount * 0.6
    end
    if not targetTotalMax then
        targetTotalMax = self.itemValueRange[2] * itemCount * 0.5
    end

    -- 尝试生成，确保总价值在范围内（最多重试 20 次）
    for _ = 1, 20 do
        local items = {}
        local totalValue = 0

        for _ = 1, itemCount do
            local item = self:GenerateItem(luckyBonus)
            table.insert(items, item)
            totalValue = totalValue + item.value
        end

        if totalValue >= targetTotalMin and totalValue <= targetTotalMax then
            print(string.format("[ItemPool] Box generated: %d items, total=%d, hall=%s",
                itemCount, totalValue, self.hallId))
            return items, totalValue
        end
    end

    -- 兜底：直接返回最后一次
    local items = {}
    local totalValue = 0
    for _ = 1, itemCount do
        local item = self:GenerateItem(luckyBonus)
        table.insert(items, item)
        totalValue = totalValue + item.value
    end
    print(string.format("[ItemPool] Box generated (fallback): %d items, total=%d, hall=%s",
        itemCount, totalValue, self.hallId))
    return items, totalValue
end

--- 获取本厅中最高稀有度藏品的分类列表（用于慧眼识珠被动）
---@return string|nil categoryName 最高稀有度藏品的分类名
---@return number maxRarity 最高稀有度
function ItemPool:GetTopRarityCategory()
    for r = 4, 1, -1 do
        if #self.templatesByRarity[r] > 0 then
            local templates = self.templatesByRarity[r]
            local tmpl = templates[math.random(1, #templates)]
            return tmpl.category, r
        end
    end
    return nil, 0
end

return ItemPool
