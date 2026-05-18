-- ============================================================================
-- PlayerDataManager.lua - 玩家持久化数据管理器（服务端）
-- 封装 serverCloud API，提供余额、藏品收藏、教学状态的读写
-- ============================================================================

local Config = require("Config")
local cjson  = require("cjson")

local PlayerDataManager = {}

-- 内存缓存 { [uid] = { balance=number, loaded=boolean } }
local cache_ = {}

-- ============================================================================
-- 内部辅助
-- ============================================================================

--- 获取或创建缓存条目
---@param uid number
---@return table
local function _GetCache(uid)
    if not cache_[uid] then
        cache_[uid] = { balance = 0, loaded = false }
    end
    return cache_[uid]
end

-- ============================================================================
-- 加载玩家数据
-- ============================================================================

--- 加载玩家持久化数据（余额）
--- 首次玩家自动初始化 InitialBalance
---@param uid number 玩家 userId
---@param callback fun(ok: boolean, data: table) data = { balance }
function PlayerDataManager.LoadPlayerData(uid, callback)
    print(string.format("[PlayerDataManager] Loading data for uid=%s", tostring(uid)))

    serverCloud.money:Get(uid, {
        ok = function(moneys)
            local c = _GetCache(uid)
            local goldEntry = nil
            for _, m in ipairs(moneys) do
                if m.key == "balance" then
                    goldEntry = m
                    break
                end
            end

            if goldEntry then
                c.balance = goldEntry.amount
            else
                -- 首次玩家：初始化余额
                c.balance = Config.Economy.InitialBalance
                serverCloud.money:Add(uid, "balance", Config.Economy.InitialBalance)
                print(string.format("[PlayerDataManager] New player uid=%s, init balance=%d",
                    tostring(uid), Config.Economy.InitialBalance))
            end

            c.loaded = true
            print(string.format("[PlayerDataManager] Loaded uid=%s: balance=%d",
                tostring(uid), c.balance))

            if callback then
                callback(true, { balance = c.balance })
            end
        end,
        error = function(code, reason)
            print(string.format("[PlayerDataManager] money:Get error for uid=%s: %s",
                tostring(uid), tostring(reason)))
            if callback then
                callback(false, { balance = 0 })
            end
        end,
    })
end

-- ============================================================================
-- 入场费
-- ============================================================================

--- 扣除入场费
---@param uid number
---@param fee number 入场费金额
---@param callback fun(ok: boolean, newBalance: number)
function PlayerDataManager.DeductEntryFee(uid, fee, callback)
    if fee <= 0 then
        -- 免费厅，不扣费
        local c = _GetCache(uid)
        if callback then callback(true, c.balance) end
        return
    end

    serverCloud.money:Cost(uid, "balance", fee, {
        ok = function()
            local c = _GetCache(uid)
            c.balance = c.balance - fee
            print(string.format("[PlayerDataManager] uid=%s entry fee -%d, balance=%d",
                tostring(uid), fee, c.balance))
            if callback then callback(true, c.balance) end
        end,
        error = function(code, reason)
            print(string.format("[PlayerDataManager] DeductEntryFee error uid=%s: %s",
                tostring(uid), tostring(reason)))
            if callback then
                local c = _GetCache(uid)
                callback(false, c.balance)
            end
        end,
    })
end

-- ============================================================================
-- 奖励持久化
-- ============================================================================

--- 保存竞拍奖励（扣除竞拍出价 + 藏品入库 + 获胜者返现奖励）
---@param uid number
---@param items table[] 藏品列表 { {name, category, rarity, value, rarityName}, ... }
---@param bonusAmount number 获胜者奖金（出价总额 × WinnerBonusRatio）
---@param bidTotal number 赢家竞拍出价总额（从余额中扣除）
---@param callback fun(ok: boolean)
function PlayerDataManager.SaveReward(uid, items, bonusAmount, bidTotal, callback)
    local c = serverCloud:BatchCommit("save_reward")

    -- 扣除竞拍出价总额
    if bidTotal and bidTotal > 0 then
        c:MoneyCost(uid, "balance", bidTotal)
    end

    -- 奖金入账
    if bonusAmount > 0 then
        c:MoneyAdd(uid, "balance", bonusAmount)
    end

    -- 藏品逐件入库
    for _, item in ipairs(items) do
        local itemData = {
            name     = item.name,
            category = item.category or "",
            rarity   = item.rarity,
            value    = item.value,
        }
        c:ListAdd(uid, "collection", itemData)
    end

    c:Commit({
        ok = function()
            local cache = _GetCache(uid)
            cache.balance = cache.balance - (bidTotal or 0) + bonusAmount
            print(string.format("[PlayerDataManager] SaveReward uid=%s: %d items, bidTotal=%d, bonus=%d, balance=%d",
                tostring(uid), #items, bidTotal or 0, bonusAmount, cache.balance))
            if callback then callback(true) end
        end,
        error = function(code, reason)
            print(string.format("[PlayerDataManager] SaveReward error uid=%s: %s",
                tostring(uid), tostring(reason)))
            if callback then callback(false) end
        end,
    })
end

-- ============================================================================
-- 出售藏品
-- ============================================================================

--- 出售一件藏品
---@param uid number
---@param listId string 藏品在 serverCloud.list 中的 id
---@param itemValue number 藏品原始价值
---@param callback fun(ok: boolean, sellPrice: number, newBalance: number)
function PlayerDataManager.SellItem(uid, listId, itemValue, callback)
    local sellPrice = math.floor(itemValue * Config.Economy.SellPriceRatio)

    local c = serverCloud:BatchCommit("sell_item")
    c:ListDelete(listId)
    c:MoneyAdd(uid, "balance", sellPrice)

    c:Commit({
        ok = function()
            local cache = _GetCache(uid)
            cache.balance = cache.balance + sellPrice
            print(string.format("[PlayerDataManager] SellItem uid=%s: listId=%s, price=%d, balance=%d",
                tostring(uid), tostring(listId), sellPrice, cache.balance))
            if callback then callback(true, sellPrice, cache.balance) end
        end,
        error = function(code, reason)
            print(string.format("[PlayerDataManager] SellItem error uid=%s: %s",
                tostring(uid), tostring(reason)))
            local cache = _GetCache(uid)
            if callback then callback(false, 0, cache.balance) end
        end,
    })
end

-- ============================================================================
-- 藏品收藏馆
-- ============================================================================

--- 获取玩家藏品列表
---@param uid number
---@param callback fun(ok: boolean, collection: table[], totalCount: number, totalValue: number)
function PlayerDataManager.GetCollection(uid, callback)
    serverCloud.list:Get(uid, "collection", {
        ok = function(list)
            local totalValue = 0
            local items = {}
            for _, entry in ipairs(list) do
                local itemData = entry.value or {}
                table.insert(items, {
                    id       = entry.id,        -- serverCloud list item id（用于出售）
                    name     = itemData.name or "???",
                    category = itemData.category or "",
                    rarity   = itemData.rarity or 1,
                    value    = itemData.value or 0,
                })
                totalValue = totalValue + (itemData.value or 0)
            end
            print(string.format("[PlayerDataManager] GetCollection uid=%s: %d items, total=%d",
                tostring(uid), #items, totalValue))
            if callback then callback(true, items, #items, totalValue) end
        end,
        error = function(code, reason)
            print(string.format("[PlayerDataManager] GetCollection error uid=%s: %s",
                tostring(uid), tostring(reason)))
            if callback then callback(false, {}, 0, 0) end
        end,
    })
end

-- ============================================================================
-- 缓存查询（同步，需先 LoadPlayerData）
-- ============================================================================

--- 获取缓存的余额（同步）
---@param uid number
---@return number
function PlayerDataManager.GetCachedBalance(uid)
    return _GetCache(uid).balance
end

--- 更新缓存余额（非持久化，仅内存同步用）
---@param uid number
---@param newBalance number
function PlayerDataManager.SetCachedBalance(uid, newBalance)
    _GetCache(uid).balance = newBalance
end

--- 是否已加载
---@param uid number
---@return boolean
function PlayerDataManager.IsLoaded(uid)
    return _GetCache(uid).loaded
end

--- 清除缓存（玩家断开时调用）
---@param uid number
function PlayerDataManager.ClearCache(uid)
    cache_[uid] = nil
end

return PlayerDataManager
