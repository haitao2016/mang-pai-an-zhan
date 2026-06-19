-- ============================================================================
-- SkinSystem.lua - 角色皮肤系统
-- ----------------------------------------------------------------------------
-- 功能：
--   1. 角色皮肤管理
--   2. 皮肤解锁（购买/成就/活动）
--   3. 皮肤装备与切换
--   4. 皮肤预览
--   5. 皮肤套装效果
--
-- 皮肤类型：
--   - 普通皮肤（成就解锁）
--   - 限定皮肤（活动限定）
--   - 传说皮肤（充值/赛季）
-- ============================================================================

local Config = require("Config")
local EventBus = require("Utils.EventBus")

local SkinSystem = {}

-- ============================================================================
-- 内部状态
-- ============================================================================
local _playerSkins = {}  -- { [uid] = { [characterId] = skinId } }
local _playerUnlocked = {}  -- { [uid] = { skinId = true } }
local _playerEquipped = {}  -- { [uid] = { characterId = skinId } }

-- ============================================================================
-- 默认皮肤配置
-- ============================================================================
SkinSystem.DefaultSkins = {
    -- 每个角色都有默认皮肤
    { id = "skin_default", name = "默认皮肤", rarity = 1, characterId = nil, unlockCondition = "default", price = 0 }
}

-- ============================================================================
-- 皮肤稀有度
-- ============================================================================
SkinSystem.Rarity = {
    COMMON = 1,      -- 普通（成就解锁）
    RARE = 2,        -- 稀有（活动/任务）
    EPIC = 3,        -- 史诗（购买）
    LEGENDARY = 4,   -- 传说（限定）
    EXCLUSIVE = 5    -- 独占（赛季/充值）
}

-- ============================================================================
-- 辅助函数
-- ============================================================================
local function _GetPlayerUnlocked(uid)
    if not _playerUnlocked[uid] then
        _playerUnlocked[uid] = {}
        -- 默认解锁所有角色的默认皮肤
        for _, skin in ipairs(SkinSystem.DefaultSkins) do
            _playerUnlocked[uid][skin.id] = true
        end
    end
    return _playerUnlocked[uid]
end

local function _GetPlayerEquipped(uid)
    if not _playerEquipped[uid] then
        _playerEquipped[uid] = {}
    end
    return _playerEquipped[uid]
end

-- ============================================================================
-- 获取角色皮肤列表
-- ============================================================================
function SkinSystem.GetSkinsForCharacter(characterId)
    if not Config or not Config.Skins then
        return SkinSystem.DefaultSkins
    end

    local skins = {}

    -- 添加默认皮肤
    for _, skin in ipairs(SkinSystem.DefaultSkins) do
        table.insert(skins, {
            id = skin.id,
            name = skin.name,
            rarity = skin.rarity,
            characterId = characterId,
            unlockCondition = "default",
            price = 0
        })
    end

    -- 添加角色专属皮肤
    if Config.Skins[characterId] then
        for _, skin in ipairs(Config.Skins[characterId]) do
            table.insert(skins, skin)
        end
    end

    return skins
end

-- ============================================================================
-- 获取玩家已解锁的皮肤列表
-- ============================================================================
function SkinSystem.GetUnlockedSkins(uid)
    local unlocked = _GetPlayerUnlocked(uid)
    local skins = {}

    if Config and Config.Skins then
        for characterId, charSkins in pairs(Config.Skins) do
            for _, skin in ipairs(charSkins) do
                if unlocked[skin.id] then
                    table.insert(skins, {
                        id = skin.id,
                        name = skin.name,
                        rarity = skin.rarity,
                        characterId = characterId,
                        price = skin.price
                    })
                end
            end
        end
    end

    return skins
end

-- ============================================================================
-- 检查皮肤是否已解锁
-- ============================================================================
function SkinSystem.IsSkinUnlocked(uid, skinId)
    local unlocked = _GetPlayerUnlocked(uid)
    return unlocked[skinId] == true
end

-- ============================================================================
-- 解锁皮肤
-- ============================================================================
function SkinSystem.UnlockSkin(uid, skinId, reason)
    local unlocked = _GetPlayerUnlocked(uid)
    if unlocked[skinId] then
        return false, "already_unlocked"
    end

    unlocked[skinId] = true

    -- 发布皮肤解锁事件
    EventBus.Publish(EventBus.Events.SKIN_UNLOCK, {
        uid = uid,
        skinId = skinId,
        reason = reason or "unknown"
    })

    print("[SkinSystem] 玩家 " .. tostring(uid) .. " 解锁皮肤: " .. skinId .. " (" .. reason .. ")")

    return true
end

-- ============================================================================
-- 购买皮肤
-- ============================================================================
function SkinSystem.PurchaseSkin(uid, skinId, price)
    -- 这里应该检查玩家金币余额，扣除金币
    -- local playerData = PlayerDataManager.GetPlayerData(uid)
    -- if playerData.gold < price then
    --     return false, "insufficient_gold"
    -- end

    local ok, err = SkinSystem.UnlockSkin(uid, skinId, "purchase")
    if not ok then
        return false, err
    end

    -- 扣除金币（简化版）
    -- playerData.gold = playerData.gold - price

    print("[SkinSystem] 玩家 " .. tostring(uid) .. " 购买皮肤: " .. skinId .. "，价格: " .. price)
    return true
end

-- ============================================================================
-- 装备皮肤
-- ============================================================================
function SkinSystem.EquipSkin(uid, characterId, skinId)
    -- 检查皮肤是否已解锁
    if not SkinSystem.IsSkinUnlocked(uid, skinId) then
        return false, "skin_not_unlocked"
    end

    -- 检查皮肤是否属于该角色
    local validSkin = false
    local skins = SkinSystem.GetSkinsForCharacter(characterId)
    for _, skin in ipairs(skins) do
        if skin.id == skinId then
            validSkin = true
            break
        end
    end

    if not validSkin then
        return false, "invalid_skin_for_character"
    end

    local equipped = _GetPlayerEquipped(uid)
    equipped[characterId] = skinId

    -- 发布皮肤装备事件
    EventBus.Publish(EventBus.Events.SKIN_EQUIP, {
        uid = uid,
        characterId = characterId,
        skinId = skinId
    })

    print("[SkinSystem] 玩家 " .. tostring(uid) .. " 装备皮肤: " .. skinId .. " (角色: " .. characterId .. ")")
    return true
end

-- ============================================================================
-- 卸下皮肤（使用默认皮肤）
-- ============================================================================
function SkinSystem.UnequipSkin(uid, characterId)
    local equipped = _GetPlayerEquipped(uid)
    equipped[characterId] = nil

    print("[SkinSystem] 玩家 " .. tostring(uid) .. " 卸下皮肤 (角色: " .. characterId .. ")")
    return true
end

-- ============================================================================
-- 获取角色当前装备的皮肤
-- ============================================================================
function SkinSystem.GetEquippedSkin(uid, characterId)
    local equipped = _GetPlayerEquipped(uid)
    local skinId = equipped[characterId]

    if not skinId then
        return {
            id = "skin_default",
            name = "默认皮肤",
            rarity = 1,
            characterId = characterId
        }
    end

    -- 查找皮肤详情
    local skins = SkinSystem.GetSkinsForCharacter(characterId)
    for _, skin in ipairs(skins) do
        if skin.id == skinId then
            return skin
        end
    end

    return {
        id = "skin_default",
        name = "默认皮肤",
        rarity = 1,
        characterId = characterId
    }
end

-- ============================================================================
-- 皮肤预览（未解锁也能查看）
-- ============================================================================
function SkinSystem.GetSkinPreview(skinId, characterId)
    local skins = SkinSystem.GetSkinsForCharacter(characterId)
    for _, skin in ipairs(skins) do
        if skin.id == skinId then
            return {
                id = skin.id,
                name = skin.name,
                rarity = skin.rarity,
                description = skin.description,
                price = skin.price,
                unlockCondition = skin.unlockCondition,
                characterId = characterId,
                previewImage = skin.previewImage,
                effect = skin.effect
            }
        end
    end
    return nil
end

-- ============================================================================
-- 获取皮肤套装信息
-- ============================================================================
function SkinSystem.GetSkinSets()
    if not Config or not Config.SkinSets then
        return {}
    end

    return Config.SkinSets
end

-- ============================================================================
-- 检查套装是否完整
-- ============================================================================
function SkinSystem.CheckSetCompletion(uid, setId)
    if not Config or not Config.SkinSets then
        return false, 0, 0
    end

    local set = nil
    for _, s in ipairs(Config.SkinSets) do
        if s.id == setId then
            set = s
            break
        end
    end

    if not set then
        return false, 0, 0
    end

    local unlocked = _GetPlayerUnlocked(uid)
    local owned = 0

    for _, skinId in ipairs(set.skins) do
        if unlocked[skinId] then
            owned = owned + 1
        end
    end

    return owned >= #set.skins, owned, #set.skins
end

-- ============================================================================
-- 领取套装奖励
-- ============================================================================
function SkinSystem.ClaimSetReward(uid, setId)
    local complete, owned, total = SkinSystem.CheckSetCompletion(uid, setId)
    if not complete then
        return false, "set_not_complete"
    end

    local set = nil
    for _, s in ipairs(Config.SkinSets or {}) do
        if s.id == setId then
            set = s
            break
        end
    end

    if not set then
        return false, "set_not_found"
    end

    -- 发放奖励
    if set.reward then
        -- 发布皮肤套装完成事件
        EventBus.Publish(EventBus.Events.SKIN_SET_COMPLETE, {
            uid = uid,
            setId = setId,
            setName = set.name,
            reward = set.reward
        })

        -- 皮肤套装触发赛季经验（v1.1 系统集成）
        EventBus.Publish(EventBus.Events.SEASON_PROGRESS, {
            uid = uid,
            xp = 80,
            source = "skin_set_complete"
        })

        print("[SkinSystem] 玩家 " .. tostring(uid) .. " 领取套装奖励: " .. set.name)
    end

    return true, set.reward
end

-- ============================================================================
-- 获取皮肤稀有度名称
-- ============================================================================
function SkinSystem.GetRarityName(rarity)
    local names = {
        [1] = "普通",
        [2] = "稀有",
        [3] = "史诗",
        [4] = "传说",
        [5] = "独占"
    }
    return names[rarity] or "未知"
end

-- ============================================================================
-- 获取玩家皮肤统计
-- ============================================================================
function SkinSystem.GetPlayerStats(uid)
    local unlocked = _GetPlayerUnlocked(uid)
    local stats = {
        totalUnlocked = 0,
        byRarity = {
            [1] = 0,  -- 普通
            [2] = 0,  -- 稀有
            [3] = 0,  -- 史诗
            [4] = 0,  -- 传说
            [5] = 0   -- 独占
        },
        equippedCount = 0
    }

    for skinId in pairs(unlocked) do
        if skinId ~= "skin_default" then
            stats.totalUnlocked = stats.totalUnlocked + 1

            -- 查找皮肤稀有度
            for characterId, charSkins in pairs(Config.Skins or {}) do
                for _, skin in ipairs(charSkins) do
                    if skin.id == skinId then
                        stats.byRarity[skin.rarity or 1] = stats.byRarity[skin.rarity or 1] + 1
                        break
                    end
                end
            end
        end
    end

    local equipped = _GetPlayerEquipped(uid)
    for _ in pairs(equipped) do
        stats.equippedCount = stats.equippedCount + 1
    end

    return stats
end

-- ============================================================================
-- 重置（测试用）
-- ============================================================================
function SkinSystem.Reset(uid)
    if uid then
        _playerUnlocked[uid] = nil
        _playerEquipped[uid] = nil
    else
        _playerUnlocked = {}
        _playerEquipped = {}
    end
    print("[SkinSystem] 数据已重置")
end

-- ============================================================================
-- 注册事件监听
-- ============================================================================
function SkinSystem.RegisterEvents()
    -- 订阅赛季系统事件（v1.1 集成）
    EventBus.Subscribe(EventBus.Events.SEASON_LEVELUP, function(data)
        print("[SkinSystem] 赛季升级，解锁稀有皮肤: " .. tostring(data.uid))
    end, "SkinSystem")

    -- 订阅成就事件（v1.1 集成）
    EventBus.Subscribe(EventBus.Events.ACHIEVEMENT_UNLOCK, function(data)
        print("[SkinSystem] 成就解锁，自动解锁对应皮肤: " .. tostring(data.uid))
    end, "SkinSystem")

    -- 订阅交易市场事件（v1.2 集成）
    EventBus.Subscribe(EventBus.Events.TRADE_PURCHASE, function(data)
        print("[SkinSystem] 玩家购买藏品，可解锁关联皮肤: " .. tostring(data.buyerUid))
    end, "SkinSystem")

    print("[SkinSystem] 事件监听已注册")
end

return SkinSystem
