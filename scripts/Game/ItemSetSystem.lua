-- ============================================================================
-- ItemSetSystem.lua - 藏品套装收集系统
-- ----------------------------------------------------------------------------
-- 功能：
--   1. 追踪玩家的套装收集进度
--   2. 东方艺术品系列、西洋收藏系列
--   3. 套装奖励发放
--   4. 与 serverCloud 持久化
-- ============================================================================

local Config = require("Config")
local EventBus = require("Utils.EventBus")

local ItemSetSystem = {}

-- ============================================================================
-- 内部状态
-- ============================================================================
local _playerSets = {}  -- { uid = { [setId] = { collected = { itemId1, itemId2 }, rewardClaimed = false } } }

-- ============================================================================
-- 辅助
-- ============================================================================
local function _Now()
    if os and os.time then return os.time() end
    return 0
end

-- ============================================================================
-- 获取玩家套装数据
-- ============================================================================
local function _GetPlayerData(uid)
    if not uid then return nil end

    if not _playerSets[uid] then
        _playerSets[uid] = {
            sets = {},
            lastUpdate = _Now()
        }

        -- 初始化所有套装
        if Config.ItemSets then
            for _, set in ipairs(Config.ItemSets) do
                _playerSets[uid].sets[set.id] = {
                    collected = {},      -- 已收集的物品 ID 列表
                    rewardClaimed = false,
                    totalCount = 0
                }
            end
        end
    end

    return _playerSets[uid]
end

-- ============================================================================
-- 获取所有套装配置
-- ============================================================================
function ItemSetSystem.GetAllSets()
    if not Config.ItemSets then
        return {}
    end

    local result = {}
    for _, set in ipairs(Config.ItemSets) do
        table.insert(result, {
            id = set.id,
            name = set.name,
            description = set.description,
            itemCount = set.itemCount,
            minRarity = set.minRarity,
            reward = set.reward
        })
    end

    return result
end

-- ============================================================================
-- 获取玩家套装进度
-- ============================================================================
function ItemSetSystem.GetPlayerProgress(uid)
    local data = _GetPlayerData(uid)
    if not data then return {} end

    local result = {}
    for _, set in ipairs(Config.ItemSets or {}) do
        local playerSet = data.sets[set.id]
        if playerSet then
            local progress = {
                id = set.id,
                name = set.name,
                collected = #playerSet.collected,
                required = set.itemCount,
                percent = math.floor(#playerSet.collected / set.itemCount * 100),
                rewardClaimed = playerSet.rewardClaimed,
                isComplete = #playerSet.collected >= set.itemCount
            }
            table.insert(result, progress)
        end
    end

    return result
end

-- ============================================================================
-- 添加藏品到套装
-- ============================================================================
function ItemSetSystem.CollectItem(uid, itemId, itemSeries, itemRarity)
    local data = _GetPlayerData(uid)
    if not data then return false end

    local changed = false

    -- 检查所有套装
    for _, set in ipairs(Config.ItemSets or {}) do
        local playerSet = data.sets[set.id]
        if not playerSet then goto continue end

        -- 检查是否已领取奖励
        if playerSet.rewardClaimed then goto continue end

        -- 检查是否满足系列条件
        local canAdd = false

        if set.itemCount and not set.minRarity then
            -- 按物品数量收集
            if itemSeries == set.id or itemSeries == set.id:gsub("set_", "") then
                canAdd = true
            end
        elseif set.minRarity then
            -- 按稀有度收集
            if itemRarity and itemRarity >= set.minRarity then
                canAdd = true
            end
        end

        if canAdd then
            -- 检查是否已收集
            local already = false
            for _, collected in ipairs(playerSet.collected) do
                if collected == itemId then
                    already = true
                    break
                end
            end

            if not already then
                table.insert(playerSet.collected, itemId)
                playerSet.totalCount = #playerSet.collected
                changed = true

                -- 检查是否完成
                if #playerSet.collected >= set.itemCount then
                    print("[ItemSet] 🎉 玩家 " .. tostring(uid) .. " 集齐套装：" .. set.name)
                    EventBus.Publish("itemset_complete", {
                        uid = uid,
                        setId = set.id,
                        setName = set.name,
                        reward = set.reward
                    })
                end
            end
        end

        ::continue::
    end

    if changed then
        data.lastUpdate = _Now()
    end

    return changed
end

-- ============================================================================
-- 检查套装是否完成
-- ============================================================================
function ItemSetSystem.IsSetComplete(uid, setId)
    local data = _GetPlayerData(uid)
    if not data then return false end

    local playerSet = data.sets[setId]
    if not playerSet then return false end

    return #playerSet.collected >= playerSet.required or false
end

-- ============================================================================
-- 获取套装收集详情
-- ============================================================================
function ItemSetSystem.GetSetDetails(uid, setId)
    local data = _GetPlayerData(uid)
    if not data then return nil end

    local playerSet = data.sets[setId]
    if not playerSet then return nil end

    -- 查找配置
    local config = nil
    for _, set in ipairs(Config.ItemSets or {}) do
        if set.id == setId then
            config = set
            break
        end
    end

    if not config then return nil end

    return {
        id = setId,
        name = config.name,
        description = config.description,
        collected = playerSet.collected,
        totalCount = #playerSet.collected,
        required = config.itemCount,
        rewardClaimed = playerSet.rewardClaimed,
        isComplete = #playerSet.collected >= config.itemCount
    }
end

-- ============================================================================
-- 领取套装奖励
-- ============================================================================
function ItemSetSystem.ClaimReward(uid, setId)
    local data = _GetPlayerData(uid)
    if not data then return false, "no_data" end

    local playerSet = data.sets[setId]
    if not playerSet then return false, "no_set" end

    if playerSet.rewardClaimed then
        return false, "already_claimed"
    end

    -- 查找配置
    local config = nil
    for _, set in ipairs(Config.ItemSets or {}) do
        if set.id == setId then
            config = set
            break
        end
    end

    if not config then return false, "no_config" end

    if #playerSet.collected < config.itemCount then
        return false, "not_complete"
    end

    -- 标记为已领取
    playerSet.rewardClaimed = true
    data.lastUpdate = _Now()

    print("[ItemSet] 🏆 玩家 " .. tostring(uid) .. " 领取套装奖励：" .. config.name)

    return true, config.reward
end

-- ============================================================================
-- 获取可领取奖励的套装列表
-- ============================================================================
function ItemSetSystem.GetClaimableSets(uid)
    local progress = ItemSetSystem.GetPlayerProgress(uid)
    local claimable = {}

    for _, p in ipairs(progress) do
        if p.isComplete and not p.rewardClaimed then
            table.insert(claimable, {
                id = p.id,
                name = p.name,
                collected = p.collected,
                required = p.required
            })
        end
    end

    return claimable
end

-- ============================================================================
-- 注册事件监听
-- ============================================================================
function ItemSetSystem.RegisterEvents()
    if not EventBus then return end

    EventBus.Subscribe(EventBus.Events.ITEM_COLLECT, function(data)
        if not data then return end
        local uid = data.playerId or data.uid or data.seat
        ItemSetSystem.CollectItem(uid, data.itemId, data.series, data.rarity)
    end, "ItemSetSystem")

    print("[ItemSetSystem] 事件监听已注册")
end

-- ============================================================================
-- 重置
-- ============================================================================
function ItemSetSystem.Reset(uid)
    if uid then
        _playerSets[uid] = nil
    else
        _playerSets = {}
    end
end

return ItemSetSystem
