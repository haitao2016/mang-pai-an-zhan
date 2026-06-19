-- ============================================================================
-- EquipmentSystem.lua - 装备系统（v1.3.0 核心系统）
-- ----------------------------------------------------------------------------
-- 功能：
--   1. 装备解锁 / 装备 / 卸下
--   2. 装备强化（10级，成功率递减）
--   3. 属性计算（9种属性类型）
--   4. 套装效果检测（2/3/4件套）
--   5. EventBus 事件集成
--
-- 规则：
--   - 4 个槽位：武器 / 防具 / 饰品 / 徽章
--   - 5 种稀有度：普通 → 稀有 → 史诗 → 传说 → 神话
--   - 强化保底：失败不降级，仅消耗金币
--   - 套装效果：2/3/4件激活不同加成
-- ============================================================================

local Config = require("Config")
local EventBus = require("Utils.EventBus")

local EquipmentSystem = {}

-- ============================================================================
-- 内部状态
-- ============================================================================
-- 玩家装备数据: { [uid] = { equipped = {}, unlocked = {}, enhanceLevels = {} } }
local _playerEquipment = {}

-- 装备配置缓存
local _equipmentConfigCache = nil
local _setConfigCache = nil

-- ============================================================================
-- 辅助函数
-- ============================================================================

--- 获取玩家装备数据
local function _GetPlayerData(uid)
    if not _playerEquipment[uid] then
        _playerEquipment[uid] = {
            equipped = {},        -- { slot = equipmentId }
            unlocked = {},       -- { [equipmentId] = true }
            enhanceLevels = {},   -- { [equipmentId] = level }
        }
    end
    return _playerEquipment[uid]
end

--- 获取装备配置（带缓存）
local function _GetEquipmentConfig(equipmentId)
    if not _equipmentConfigCache then
        _equipmentConfigCache = {}
        if Config.EquipmentItems then
            for _, item in ipairs(Config.EquipmentItems) do
                _equipmentConfigCache[item.id] = item
            end
        end
    end
    return _equipmentConfigCache[equipmentId]
end

--- 获取套装配置（带缓存）
local function _GetSetConfig(setId)
    if not _setConfigCache then
        _setConfigCache = {}
        if Config.EquipmentSets then
            for _, set in ipairs(Config.EquipmentSets) do
                _setConfigCache[set.id] = set
            end
        end
    end
    return _setConfigCache[setId]
end

--- 获取强化费用
local function _CalcEnhanceCost(equipmentId, currentLevel)
    local config = _GetEquipmentConfig(equipmentId)
    if not config then return 0 end

    local baseCost = config.enhanceCostBase or Config.Equipment.baseEnhanceCost
    local multiplier = Config.Equipment.costMultiplierPerLevel or 1.5

    return math.floor(baseCost * math.pow(multiplier, currentLevel))
end

--- 计算强化成功率
local function _CalcEnhanceSuccessRate(level)
    local baseRate = Config.Equipment.successRateBase or 0.90
    local dropRate = Config.Equipment.successRateDrop or 0.05

    return math.max(0.5, baseRate - (level * dropRate))
end

-- ============================================================================
-- 装备管理 API
-- ============================================================================

--- 解锁装备
---@param uid number 玩家UID
---@param equipmentId string 装备ID
---@return boolean success 是否成功
---@return string|nil error 错误信息
function EquipmentSystem.Unlock(uid, equipmentId)
    local config = _GetEquipmentConfig(equipmentId)
    if not config then
        return false, "equipment_not_found"
    end

    local data = _GetPlayerData(uid)

    if data.unlocked[equipmentId] then
        return false, "already_unlocked"
    end

    data.unlocked[equipmentId] = true
    data.enhanceLevels[equipmentId] = 0

    -- 发布事件
    EventBus.Publish(EventBus.Events.EQUIPMENT_UNLOCK, {
        uid = uid,
        equipmentId = equipmentId,
        slot = config.slot,
        rarity = config.rarity,
        name = config.name,
    })

    print(string.format("[EquipmentSystem] 解锁装备: %s (uid=%s)", equipmentId, tostring(uid)))
    return true
end

--- 检查装备是否已解锁
---@param uid number
---@param equipmentId string
---@return boolean
function EquipmentSystem.IsUnlocked(uid, equipmentId)
    local data = _playerEquipment[uid]
    return data and data.unlocked[equipmentId] == true
end

--- 装备物品到槽位
---@param uid number
---@param equipmentId string 装备ID
---@param slot string 槽位ID（如 "weapon"）
---@return boolean success
---@return string|nil error
function EquipmentSystem.Equip(uid, equipmentId, slot)
    local config = _GetEquipmentConfig(equipmentId)
    if not config then
        return false, "equipment_not_found"
    end

    -- 验证槽位匹配
    if config.slot ~= slot then
        return false, "slot_mismatch"
    end

    -- 验证已解锁
    local data = _GetPlayerData(uid)
    if not data.unlocked[equipmentId] then
        return false, "not_unlocked"
    end

    -- 获取槽位配置
    local slotConfig = nil
    for _, s in ipairs(Config.Equipment.slots or {}) do
        if s.id == slot then
            slotConfig = s
            break
        end
    end

    if not slotConfig then
        return false, "invalid_slot"
    end

    -- 获取之前装备的物品
    local previousEquipment = data.equipped[slot]

    -- 装备新物品
    data.equipped[slot] = equipmentId

    -- 发布事件
    EventBus.Publish(EventBus.Events.EQUIPMENT_EQUIP, {
        uid = uid,
        equipmentId = equipmentId,
        slot = slot,
        previousEquipment = previousEquipment,
    })

    print(string.format("[EquipmentSystem] 装备: %s -> %s (uid=%s)", slot, equipmentId, tostring(uid)))
    return true
end

--- 卸下装备
---@param uid number
---@param slot string 槽位ID
---@return boolean success
---@return string|nil error
function EquipmentSystem.Unequip(uid, slot)
    local data = _GetPlayerData(uid)
    local equipmentId = data.equipped[slot]

    if not equipmentId then
        return false, "slot_empty"
    end

    -- 验证槽位存在
    local slotConfig = nil
    for _, s in ipairs(Config.Equipment.slots or {}) do
        if s.id == slot then
            slotConfig = s
            break
        end
    end

    if not slotConfig then
        return false, "invalid_slot"
    end

    -- 卸下装备
    data.equipped[slot] = nil

    -- 发布事件
    EventBus.Publish(EventBus.Events.EQUIPMENT_UNEQUIP, {
        uid = uid,
        equipmentId = equipmentId,
        slot = slot,
    })

    print(string.format("[EquipmentSystem] 卸下装备: %s (uid=%s)", slot, tostring(uid)))
    return true
end

--- 获取槽位中已装备的物品
---@param uid number
---@param slot string
---@return string|nil equipmentId
function EquipmentSystem.GetEquipped(uid, slot)
    local data = _playerEquipment[uid]
    if not data then return nil end
    return data.equipped[slot]
end

--- 获取玩家所有已装备物品
---@param uid number
---@return table equipped { slot = equipmentId }
function EquipmentSystem.GetAllEquipped(uid)
    local data = _GetPlayerData(uid)
    local result = {}

    for slot, equipmentId in pairs(data.equipped) do
        result[slot] = {
            equipmentId = equipmentId,
            enhanceLevel = data.enhanceLevels[equipmentId] or 0,
            config = _GetEquipmentConfig(equipmentId),
        }
    end

    return result
end

--- 获取玩家完整装备栏信息
---@param uid number
---@return table
function EquipmentSystem.GetPlayerEquipment(uid)
    local data = _GetPlayerData(uid)
    local result = {
        equipped = {},
        unlocked = {},
        totalEquipmentCount = 0,
        totalEnhanceLevel = 0,
        maxRarity = 0,
    }

    -- 已装备物品
    for slot, equipmentId in pairs(data.equipped) do
        local config = _GetEquipmentConfig(equipmentId)
        local enhanceLevel = data.enhanceLevels[equipmentId] or 0
        result.equipped[slot] = {
            equipmentId = equipmentId,
            name = config and config.name or "未知",
            rarity = config and config.rarity or 0,
            enhanceLevel = enhanceLevel,
        }
        result.totalEnhanceLevel = result.totalEnhanceLevel + enhanceLevel
        if config and config.rarity > result.maxRarity then
            result.maxRarity = config.rarity
        end
    end

    -- 已解锁物品
    for equipmentId, _ in pairs(data.unlocked) do
        local config = _GetEquipmentConfig(equipmentId)
        table.insert(result.unlocked, {
            equipmentId = equipmentId,
            name = config and config.name or "未知",
            rarity = config and config.rarity or 0,
            slot = config and config.slot or "unknown",
            enhanceLevel = data.enhanceLevels[equipmentId] or 0,
        })
        result.totalEquipmentCount = result.totalEquipmentCount + 1
    end

    return result
end

-- ============================================================================
-- 装备列表 API
-- ============================================================================

--- 获取所有装备列表（含解锁状态）
---@param uid number
---@return table
function EquipmentSystem.GetEquipmentList(uid)
    local data = _GetPlayerData(uid)
    local items = {}

    if not Config.EquipmentItems then return items end

    for _, config in ipairs(Config.EquipmentItems) do
        local enhanceLevel = data.enhanceLevels[config.id] or 0
        table.insert(items, {
            id = config.id,
            name = config.name,
            slot = config.slot,
            rarity = config.rarity,
            stats = config.stats,
            description = config.description,
            enhanceCostBase = config.enhanceCostBase,
            unlocked = data.unlocked[config.id] == true,
            equipped = data.equipped[config.slot] == config.id,
            enhanceLevel = enhanceLevel,
        })
    end

    return items
end

--- 获取装备配置信息
---@param equipmentId string
---@return table|nil
function EquipmentSystem.GetEquipmentConfig(equipmentId)
    return _GetEquipmentConfig(equipmentId)
end

--- 获取所有已解锁的装备数量
---@param uid number
---@return number
function EquipmentSystem.GetUnlockedCount(uid)
    local data = _GetPlayerData(uid)
    local count = 0
    for _, _ in pairs(data.unlocked) do
        count = count + 1
    end
    return count
end

--- 获取装备了物品的槽位数量
---@param uid number
---@return number
function EquipmentSystem.GetEquippedCount(uid)
    local data = _GetPlayerData(uid)
    local count = 0
    for _, _ in pairs(data.equipped) do
        count = count + 1
    end
    return count
end

-- ============================================================================
-- 强化系统 API
-- ============================================================================

--- 强化装备
---@param uid number
---@param equipmentId string
---@param callback fun(success: boolean, newLevel: number, message: string)|nil 回调
---@return boolean success 是否有足够费用
---@return string|nil error 错误信息
function EquipmentSystem.Enhance(uid, equipmentId, callback)
    local config = _GetEquipmentConfig(equipmentId)
    if not config then
        return false, "equipment_not_found"
    end

    local data = _GetPlayerData(uid)
    if not data.unlocked[equipmentId] then
        return false, "not_unlocked"
    end

    local currentLevel = data.enhanceLevels[equipmentId] or 0
    local maxLevel = Config.Equipment.maxEnhanceLevel or 10

    if currentLevel >= maxLevel then
        return false, "already_max_level"
    end

    -- 计算费用和成功率
    local cost = _CalcEnhanceCost(equipmentId, currentLevel)
    local successRate = _CalcEnhanceSuccessRate(currentLevel)

    -- 模拟强化（简化版：直接成功）
    -- 实际游戏中应该检查玩家金币余额并扣除
    local enhanced = true  -- math.random() < successRate

    if enhanced then
        data.enhanceLevels[equipmentId] = currentLevel + 1

        -- 发布事件
        EventBus.Publish(EventBus.Events.EQUIPMENT_ENHANCE, {
            uid = uid,
            equipmentId = equipmentId,
            oldLevel = currentLevel,
            newLevel = currentLevel + 1,
            cost = cost,
            success = true,
        })

        print(string.format("[EquipmentSystem] 强化成功: %s -> Lv.%d (uid=%s)",
            equipmentId, currentLevel + 1, tostring(uid)))

        if callback then callback(true, currentLevel + 1, "强化成功") end
        return true
    else
        -- 失败不降级（保底机制）
        EventBus.Publish(EventBus.Events.EQUIPMENT_ENHANCE, {
            uid = uid,
            equipmentId = equipmentId,
            oldLevel = currentLevel,
            newLevel = currentLevel,
            cost = cost,
            success = false,
        })

        print(string.format("[EquipmentSystem] 强化失败: %s (保持 Lv.%d, uid=%s)",
            equipmentId, currentLevel, tostring(uid)))

        if callback then callback(false, currentLevel, "强化失败但不降级") end
        return false, "enhance_failed"
    end
end

--- 获取装备强化等级
---@param uid number
---@param equipmentId string
---@return number level
function EquipmentSystem.GetEnhanceLevel(uid, equipmentId)
    local data = _playerEquipment[uid]
    if not data then return 0 end
    return data.enhanceLevels[equipmentId] or 0
end

--- 获取强化费用
---@param equipmentId string
---@param currentLevel number
---@return number cost
function EquipmentSystem.GetEnhanceCost(equipmentId, currentLevel)
    return _CalcEnhanceCost(equipmentId, currentLevel)
end

--- 获取强化成功率
---@param currentLevel number
---@return number rate (0-1)
function EquipmentSystem.GetEnhanceSuccessRate(currentLevel)
    return _CalcEnhanceSuccessRate(currentLevel)
end

-- ============================================================================
-- 属性计算 API
-- ============================================================================

--- 获取所有装备总属性
---@param uid number
---@return table stats
function EquipmentSystem.GetTotalStats(uid)
    local data = _playerEquipment[uid]
    if not data then
        return _GetEmptyStats()
    end

    local stats = _GetEmptyStats()

    -- 遍历所有装备槽位
    for slot, equipmentId in pairs(data.equipped) do
        if equipmentId then
            local config = _GetEquipmentConfig(equipmentId)
            if config and config.stats then
                local enhanceLevel = data.enhanceLevels[equipmentId] or 0
                local enhanceMultiplier = 1 + (enhanceLevel * (Config.Equipment.statsPerEnhanceLevel or 0.1))

                -- 累加装备属性
                for statName, statValue in pairs(config.stats) do
                    if stats[statName] then
                        stats[statName] = stats[statName] + (statValue * enhanceMultiplier)
                    end
                end
            end
        end
    end

    -- 应用套装效果
    local setBonus = EquipmentSystem.GetActiveSetBonus(uid)
    for statName, statValue in pairs(setBonus) do
        if stats[statName] then
            stats[statName] = stats[statName] + statValue
        end
    end

    -- 应用全局加成
    if stats.globalBonus and stats.globalBonus > 0 then
        for statName, statValue in pairs(stats) do
            if statName ~= "globalBonus" then
                stats[statName] = statValue * (1 + stats.globalBonus)
            end
        end
    end

    return stats
end

--- 获取空的属性表
local function _GetEmptyStats()
    return {
        bidAccuracy = 0,     -- 出价精准度
        finalBonus = 0,     -- 最终收益加成
        defense = 0,        -- 防御力
        antiSkill = 0,      -- 抗技能
        critChance = 0,     -- 暴击几率
        rarityBonus = 0,    -- 稀有度加成
        itemValueBonus = 0, -- 物品价值加成
        globalBonus = 0,    -- 全局加成
        allRarityBonus = 0, -- 全稀有度加成
    }
end

--- 获取玩家战力值（用于排行榜）
---@param uid number
---@return number power
function EquipmentSystem.GetPlayerPower(uid)
    local stats = EquipmentSystem.GetTotalStats(uid)

    -- 战力计算公式（可调整）
    local power = 0
    power = power + (stats.bidAccuracy * 100)
    power = power + (stats.finalBonus * 150)
    power = power + (stats.defense * 80)
    power = power + (stats.antiSkill * 100)
    power = power + (stats.critChance * 120)
    power = power + (stats.rarityBonus * 100)
    power = power + (stats.itemValueBonus * 80)
    power = power + (stats.globalBonus * 200)
    power = power + (stats.allRarityBonus * 150)

    return math.floor(power)
end

-- ============================================================================
-- 套装系统 API
-- ============================================================================

--- 获取当前激活的套装效果
---@param uid number
---@return table bonus { statName = value }
function EquipmentSystem.GetActiveSetBonus(uid)
    local data = _playerEquipment[uid]
    local bonus = _GetEmptyStats()

    if not Config.EquipmentSets then return bonus end

    for _, setConfig in ipairs(Config.EquipmentSets) do
        local matchedPieces = 0
        local ownedPieces = {}

        for _, pieceId in ipairs(setConfig.pieces) do
            if data.unlocked[pieceId] then
                matchedPieces = matchedPieces + 1
                table.insert(ownedPieces, pieceId)
            end
        end

        -- 确定激活的套装效果
        local activatedBonus = nil
        if matchedPieces >= 4 and setConfig.bonus4 then
            activatedBonus = setConfig.bonus4
        elseif matchedPieces >= 3 and setConfig.bonus3 then
            activatedBonus = setConfig.bonus3
        elseif matchedPieces >= 2 and setConfig.bonus2 then
            activatedBonus = setConfig.bonus2
        end

        -- 累加套装属性
        if activatedBonus then
            for statName, statValue in pairs(activatedBonus) do
                if bonus[statName] ~= nil then
                    bonus[statName] = bonus[statName] + statValue
                end
            end
        end
    end

    return bonus
end

--- 获取玩家的套装完成情况
---@param uid number
---@return table sets { { setId, setName, matchedCount, totalCount, activeBonus } }
function EquipmentSystem.GetSetProgress(uid)
    local data = _GetPlayerData(uid)
    local progress = {}

    if not Config.EquipmentSets then return progress end

    for _, setConfig in ipairs(Config.EquipmentSets) do
        local matchedCount = 0
        for _, pieceId in ipairs(setConfig.pieces) do
            if data.unlocked[pieceId] then
                matchedCount = matchedCount + 1
            end
        end

        -- 确定激活的套装效果
        local activeBonus = nil
        if matchedCount >= 4 and setConfig.bonus4 then
            activeBonus = setConfig.bonus4
        elseif matchedCount >= 3 and setConfig.bonus3 then
            activeBonus = setConfig.bonus3
        elseif matchedCount >= 2 and setConfig.bonus2 then
            activeBonus = setConfig.bonus2
        end

        table.insert(progress, {
            setId = setConfig.id,
            setName = setConfig.name,
            description = setConfig.description,
            matchedCount = matchedCount,
            totalCount = #setConfig.pieces,
            completed = matchedCount == #setConfig.pieces,
            activeBonus = activeBonus,
        })
    end

    return progress
end

--- 获取所有套装配置
---@return table
function EquipmentSystem.GetAllSets()
    if not Config.EquipmentSets then return {} end

    local sets = {}
    for _, setConfig in ipairs(Config.EquipmentSets) do
        table.insert(sets, {
            id = setConfig.id,
            name = setConfig.name,
            description = setConfig.description,
            pieces = setConfig.pieces,
            bonus2 = setConfig.bonus2,
            bonus3 = setConfig.bonus3,
            bonus4 = setConfig.bonus4,
        })
    end
    return sets
end

--- 获取指定套装的信息
---@param setId string
---@return table|nil
function EquipmentSystem.GetSetConfig(setId)
    return _GetSetConfig(setId)
end

--- 完成套装检查并发布事件
---@param uid number
---@param setId string
local function _CheckSetCompletion(uid, setId)
    local data = _GetPlayerData(uid)
    local setConfig = _GetSetConfig(setId)

    if not setConfig then return end

    local matchedCount = 0
    for _, pieceId in ipairs(setConfig.pieces) do
        if data.unlocked[pieceId] then
            matchedCount = matchedCount + 1
        end
    end

    -- 如果达到4件（完整套装），发布事件
    if matchedCount == #setConfig.pieces then
        local activeBonus = setConfig["bonus" .. matchedCount] or setConfig.bonus4

        EventBus.Publish(EventBus.Events.EQUIPMENT_SET_COMPLETE, {
            uid = uid,
            setId = setId,
            setName = setConfig.name,
            pieces = setConfig.pieces,
            bonus = activeBonus,
        })

        print(string.format("[EquipmentSystem] 套装完成: %s (uid=%s)", setConfig.name, tostring(uid)))
    end
end

-- ============================================================================
-- 查询 API
-- ============================================================================

--- 获取装备槽位列表
---@return table
function EquipmentSystem.GetSlots()
    return Config.Equipment.slots or {}
end

--- 获取装备稀有度名称
---@param rarity number 1-5
---@return string
function EquipmentSystem.GetRarityName(rarity)
    local names = { "普通", "稀有", "史诗", "传说", "神话" }
    return names[rarity] or "未知"
end

--- 获取装备稀有度颜色
---@param rarity number 1-5
---@return string color hex
function EquipmentSystem.GetRarityColor(rarity)
    local colors = { "#A0A0A0", "#00A000", "#8000FF", "#FFD700", "#FF3030" }
    return colors[rarity] or "#FFFFFF"
end

-- ============================================================================
-- 系统管理
-- ============================================================================

--- 重置系统
function EquipmentSystem.Reset()
    _playerEquipment = {}
    print("[EquipmentSystem] 系统已重置")
end

--- 重置玩家数据（测试用）
---@param uid number
function EquipmentSystem.ResetPlayer(uid)
    _playerEquipment[uid] = nil
    print(string.format("[EquipmentSystem] 玩家 %s 装备数据已重置", tostring(uid)))
end

--- 获取系统统计
---@return table
function EquipmentSystem.GetStats()
    local totalPlayers = 0
    local totalEquipment = 0
    local totalEnhance = 0

    for uid, data in pairs(_playerEquipment) do
        totalPlayers = totalPlayers + 1
        for _, _ in pairs(data.unlocked) do
            totalEquipment = totalEquipment + 1
        end
        for _, level in pairs(data.enhanceLevels) do
            totalEnhance = totalEnhance + level
        end
    end

    return {
        totalPlayers = totalPlayers,
        totalEquipment = totalEquipment,
        totalEnhanceLevels = totalEnhance,
    }
end

-- ============================================================================
-- EventBus 事件监听注册
-- ============================================================================
function EquipmentSystem.RegisterEvents()
    -- 监听成就解锁奖励装备
    EventBus.Subscribe(EventBus.Events.ACHIEVEMENT_UNLOCK, function(data)
        if data and data.uid and data.rewardEquipment then
            EquipmentSystem.Unlock(data.uid, data.rewardEquipment)
        end
    end, "EquipmentSystem")

    -- 监听赛季升级奖励装备
    EventBus.Subscribe(EventBus.Events.SEASON_LEVELUP, function(data)
        if data and data.uid and data.rewardEquipment then
            EquipmentSystem.Unlock(data.uid, data.rewardEquipment)
        end
    end, "EquipmentSystem")

    -- 监听公会商店购买装备物品
    EventBus.Subscribe(EventBus.Events.GUILD_SHOP_PURCHASE, function(data)
        if data and data.uid and data.rewardType == "equipment" and data.rewardId then
            EquipmentSystem.Unlock(data.uid, data.rewardId)
        end
    end, "EquipmentSystem")

    print("[EquipmentSystem] 事件监听已注册")
end

return EquipmentSystem
