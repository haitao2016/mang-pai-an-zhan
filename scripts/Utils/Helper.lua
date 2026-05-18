-- ============================================================================
-- Helper.lua - 工具函数
-- ============================================================================

local Helper = {}

--- 延迟一帧执行回调
---@param callback function
function Helper.DelayOneFrame(callback)
    local pending = true
    SubscribeToEvent("Update", function()
        if pending then
            pending = false
            callback()
        end
    end)
end

--- 延迟多帧执行回调（只执行一次）
---@param frames number
---@param callback function
function Helper.DelayFrames(frames, callback)
    local count = 0
    local fired = false
    SubscribeToEvent("Update", function()
        if fired then return end
        count = count + 1
        if count >= frames then
            fired = true
            callback()
        end
    end)
end

--- 安全解析 JSON（返回 nil 表示失败）
---@param jsonStr string
---@return table|nil
function Helper.SafeJsonDecode(jsonStr)
    local cjson = require("cjson")
    local ok, result = pcall(cjson.decode, jsonStr)
    if ok then
        return result
    end
    print("[Helper] JSON decode error: " .. tostring(result))
    return nil
end

--- 格式化余额显示
---@param amount number
---@return string
function Helper.FormatMoney(amount)
    amount = math.floor(amount)
    if amount >= 10000 then
        return string.format("%.1fw", amount / 10000)
    end
    -- 千位分隔
    local formatted = tostring(amount)
    local k = #formatted
    if k > 3 then
        formatted = formatted:sub(1, k - 3) .. "," .. formatted:sub(k - 2)
    end
    return formatted
end

--- 创建 PBR 无贴图材质
---@param color table {r, g, b, a} 0-255
---@param metallic number 0-1
---@param roughness number 0-1
---@return Material
function Helper.CreatePBRMaterial(color, metallic, roughness)
    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    mat:SetShaderParameter("MatDiffColor",
        Variant(Vector4(color[1] / 255, color[2] / 255, color[3] / 255, (color[4] or 255) / 255)))
    mat:SetShaderParameter("Metallic", Variant(metallic or 0.0))
    mat:SetShaderParameter("Roughness", Variant(roughness or 0.5))
    return mat
end

return Helper
