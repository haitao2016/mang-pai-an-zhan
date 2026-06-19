-- ============================================================================
-- UIUtils.lua - UI 美化辅助工具
-- v1.0.0 新增：统一动画时长、稀有度渲染、视觉增强
-- ============================================================================

local Config = require("Config")

local UIUtils = {}

-- ============================================================================
-- 稀有度配置（渐变色映射）
-- ============================================================================

UIUtils.RarityConfig = {
    {  -- 普通 (灰色)
        bgColor = { r = 80, g = 80, b = 80 },
        borderColor = { r = 120, g = 120, b = 120 },
        textColor = { r = 220, g = 220, b = 220 },
        glowColor = { r = 100, g = 100, b = 100 },
        name = "普通",
    },
    {  -- 稀有 (蓝色)
        bgColor = { r = 30, g = 60, b = 120 },
        borderColor = { r = 80, g = 160, b = 255 },
        textColor = { r = 200, g = 230, b = 255 },
        glowColor = { r = 80, g = 160, b = 255 },
        name = "稀有",
    },
    {  -- 史诗 (紫色)
        bgColor = { r = 80, g = 30, b = 120 },
        borderColor = { r = 180, g = 80, b = 255 },
        textColor = { r = 230, g = 200, b = 255 },
        glowColor = { r = 180, g = 80, b = 255 },
        name = "史诗",
    },
    {  -- 传说 (金色)
        bgColor = { r = 120, g = 90, b = 20 },
        borderColor = { r = 255, g = 200, b = 50 },
        textColor = { r = 255, g = 230, b = 150 },
        glowColor = { r = 255, g = 200, b = 50 },
        name = "传说",
    },
}

-- ============================================================================
-- 动画配置（从 Config 读取）
-- ============================================================================

UIUtils.Animations = Config.Animations or {
    UITransition = 0.3,
    BidSubmit = 0.5,
    RevealItem = 0.8,
    FadeInOut = 0.2,
    ToastDuration = 2.0,
    ToastFast = 1.0,
}

-- ============================================================================
-- 动画时长查询
-- ============================================================================

--- 获取 UI 过渡动画时长（淡入淡出，面板切换
function UIUtils.GetTransitionTime()
    return UIUtils.Animations.UITransition
end

--- 获取出价提交动画时长
function UIUtils.GetBidSubmitTime()
    return UIUtils.Animations.BidSubmit
end

--- 获取开箱揭示动画时长
function UIUtils.GetRevealItemTime()
    return UIUtils.Animations.RevealItem
end

--- 获取 Toast 显示时长
function UIUtils.GetToastDuration()
    return UIUtils.Animations.ToastDuration
end

--- 获取快速 Toast 时长
function UIUtils.GetFastToastDuration()
    return UIUtils.Animations.ToastFast
end

-- ============================================================================
-- 颜色工具函数
-- ============================================================================

--- 线性插值两个颜色
---@param c1 table {r, g, b}
---@param c2 table {r, g, b}
---@param t number 0-1
---@return table
function UIUtils.LerpColor(c1, c2, t)
    t = math.max(0, math.min(1, t))
    return {
        r = c1.r + (c2.r - c1.r) * t,
        g = c1.g + (c2.g - c1.g) * t,
        b = c1.b + (c2.b - c1.b) * t,
    }
end

--- 获取稀有度颜色配置
---@param rarity number 1-4
---@return table
function UIUtils.GetRarityColors(rarity)
    rarity = math.max(1, math.min(4, rarity or 1))
    return UIUtils.RarityConfig[rarity]
end

--- 获取传说级别的金色渐变
function UIUtils.GetLegendColors()
    local darkGold = { r = 140, g = 100, b = 30 }
    local lightGold = { r = 255, g = 215, b = 80 }
    return darkGold, lightGold
end

-- ============================================================================
-- 布局工具
-- ============================================================================

--- 计算最佳列数（根据容器宽度
---@param containerWidth number
---@param minColumnWidth number
---@param maxColumns number
---@return number
function UIUtils.CalculateColumns(containerWidth, minColumnWidth, maxColumns)
    local columns = math.floor(containerWidth / minColumnWidth)
    columns = math.max(1, math.min(columns, maxColumns or 4))
    return columns
end

--- 计算内边距像素值
---@param density number 0.5 - 2.0
---@param base number 基础像素
---@return number
function UIUtils.ScaleForDensity(base, density)
    density = density or 1.0
    return math.floor(base * density)
end

-- ============================================================================
-- 文本格式化工具
-- ============================================================================

--- 格式化金币数字（带千分位分隔
---@param amount number
---@return string
function UIUtils.FormatGold(amount)
    if amount == nil then return "0" end
    local formatted = tostring(math.floor(amount + 0.5))
    local result = ""
    local len = #formatted
    for i = 1, len do
        if i > 1 and (len - i) % 3 == 0 then
            result = result .. ","
        end
        result = result .. formatted:sub(i, i)
    end
    return result
end

--- 格式化时间（秒）
---@param seconds number
---@return string MM:SS 或 HH:MM:SS
function UIUtils.FormatTime(seconds)
    seconds = math.max(0, math.floor(seconds))
    if seconds < 60 then
        return string.format("%ds", seconds)
    elseif seconds < 3600 then
        return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
    else
        return string.format("%d:%02d:%02d",
            math.floor(seconds / 3600),
            math.floor((seconds % 3600) / 60),
            seconds % 60)
    end
end

--- 截断文本添加省略号
---@param text string
---@param maxLength number
---@return string
function UIUtils.TruncateText(text, maxLength)
    if not text then return "" end
    if #text <= maxLength then return text end
    return string.sub(text, 1, maxLength - 3) .. "..."
end

-- ============================================================================
-- 消息提示级别（用于 toast 样式）
-- ============================================================================

UIUtils.NotificationLevel = {
    INFO = {
        bgColor = { r = 30, g = 50, b = 100 },
        borderColor = { r = 80, g = 160, b = 255 },
        textColor = { r = 230, g = 240, b = 255 },
    },
    SUCCESS = {
        bgColor = { r = 30, g = 80, b = 50 },
        borderColor = { r = 80, g = 200, b = 120 },
        textColor = { r = 220, g = 255, b = 230 },
    },
    WARNING = {
        bgColor = { r = 120, g = 80, b = 20 },
        borderColor = { r = 255, g = 180, b = 50 },
        textColor = { r = 255, g = 240, b = 200 },
    },
    ERROR = {
        bgColor = { r = 100, g = 30, b = 30 },
        borderColor = { r = 240, g = 80, b = 80 },
        textColor = { r = 255, g = 230, b = 230 },
    },
    LEGEND = {  -- 获得传说级藏品
        bgColor = { r = 120, g = 90, b = 20 },
        borderColor = { r = 255, g = 200, b = 50 },
        textColor = { r = 255, g = 240, b = 200 },
    },
}

-- ============================================================================
-- 工具辅助
-- ============================================================================

--- 检查字符串是否为空
function UIUtils.IsNullOrEmpty(text)
    return text == nil or text == ""
end

--- 安全获取表字段，嵌套表访问也安全
---@param tbl table
---@param keyPath string
---@param default any
---@return any
function UIUtils.SafeGet(tbl, keyPath, default)
    if tbl == nil then return default end

    local value = tbl
    for key in string.gmatch(keyPath, "[^%.]+") do
        value = value[key]
        if value == nil then return default end
    end

    return value
end

--- 限制数值范围
function UIUtils.Clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

--- 版本号比较（用于版本检测
---@return number: 1 = v1 > v2, -1 = v1 < v2, 0 = equal
function UIUtils.CompareVersions(v1, v2)
    local function parseVersion(v)
        local parts = {}
        for part in string.gmatch(v, "%d+") do
            table.insert(parts, tonumber(part) or 0)
        end
        return parts
    end

    local p1 = parseVersion(v1)
    local p2 = parseVersion(v2)

    for i = 1, math.max(#p1, #p2) do
        local a = p1[i] or 0
        local b = p2[i] or 0
        if a > b then return 1 end
        if a < b then return -1 end
    end

    return 0
end

return UIUtils
