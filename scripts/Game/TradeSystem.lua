-- ============================================================================
-- TradeSystem.lua - 藏品交易市场系统
-- ----------------------------------------------------------------------------
-- 功能：
--   1. 玩家之间藏品交易
--   2. 市场挂单（上架/下架）
--   3. 金币交易
--   4. 交易历史记录
--   5. 黑名单管理
--
-- 规则：
--   - 藏品明码标价，玩家用金币购买
--   - 玩家之间可以自由交易藏品
--   - 系统收取少量手续费
--   - 交易完成后藏品直接转入买家仓库
-- ============================================================================

local Config = require("Config")
local EventBus = require("Utils.EventBus")

local TradeSystem = {}

-- ============================================================================
-- 内部状态
-- ============================================================================
local _listings = {}     -- { [listingId] = ListingData }
local _trades = {}       -- { [tradeId] = TradeData }
local _playerListings = {}  -- { [uid] = { listingId1, listingId2 } }
local _blacklist = {}    -- { [uid] = { blacklistedUid1, blacklistedUid2 } }

-- ============================================================================
-- 配置
-- ============================================================================
TradeSystem.Config = {
    feeRate = 0.05,          -- 5% 交易手续费
    minPrice = 10,           -- 最低挂牌价
    maxPrice = 1000000,      -- 最高挂牌价
    maxListingsPerPlayer = 10,  -- 每玩家最多挂牌数
    maxBlacklist = 20,       -- 最多拉黑人数
    listingExpireDays = 7,   -- 挂牌有效期（天）
    maxTradeHistory = 100    -- 最多保存交易记录
}

-- ============================================================================
-- 辅助函数
-- ============================================================================
local function _GenerateListingId()
    return "LIST_" .. os.date("%Y%m%d") .. "_" .. string.format("%06d", math.random(1, 999999))
end

local function _GenerateTradeId()
    return "TRADE_" .. os.date("%Y%m%d%H%M%S") .. "_" .. string.format("%04d", math.random(1, 9999))
end

local function _Now()
    if os and os.time then return os.time() end
    return 0
end

local function _GetExpireTime()
    return _Now() + (TradeSystem.Config.listingExpireDays or 7) * 24 * 60 * 60
end

-- ============================================================================
-- 挂单（上架藏品）
-- ============================================================================
function TradeSystem.CreateListing(sellerUid, itemId, itemData, price)
    -- 参数验证
    if price < TradeSystem.Config.minPrice then
        return false, "price_too_low"
    end
    if price > TradeSystem.Config.maxPrice then
        return false, "price_too_high"
    end

    -- 检查玩家挂牌数
    local playerListings = _playerListings[sellerUid] or {}
    if #playerListings >= TradeSystem.Config.maxListingsPerPlayer then
        return false, "too_many_listings"
    end

    local listingId = _GenerateListingId()

    local listing = {
        id = listingId,
        sellerUid = sellerUid,
        sellerName = itemData and itemData.sellerName or ("玩家" .. tostring(sellerUid)),

        -- 藏品信息
        itemId = itemId,
        itemName = itemData and itemData.name or "未知藏品",
        itemRarity = itemData and itemData.rarity or 1,
        itemCategory = itemData and itemData.category or "misc",
        itemSeries = itemData and itemData.series,

        -- 价格信息
        price = price,
        originalPrice = itemData and itemData.value or price,  -- 原始估价

        -- 状态
        status = "active",  -- active, sold, cancelled, expired

        -- 时间
        createdAt = _Now(),
        expiresAt = _GetExpireTime(),
        soldAt = nil
    }

    _listings[listingId] = listing

    -- 更新玩家挂牌列表
    if not _playerListings[sellerUid] then
        _playerListings[sellerUid] = {}
    end
    table.insert(_playerListings[sellerUid], listingId)

    EventBus.Publish(EventBus.Events.TRADE_LISTING, {
        listingId = listingId,
        sellerUid = sellerUid,
        itemName = listing.itemName,
        itemRarity = listing.itemRarity,
        price = price
    })

    print("[Trade] 挂单创建: " .. listingId .. " - " .. listing.itemName .. " @ " .. price)
    return true, listingId
end

-- ============================================================================
-- 购买藏品（直接购买）
-- ============================================================================
function TradeSystem.Purchase(buyerUid, listingId)
    local listing = _listings[listingId]
    if not listing then
        return false, "listing_not_found"
    end

    if listing.status ~= "active" then
        return false, "listing_not_available"
    end

    if _Now() > listing.expiresAt then
        listing.status = "expired"
        return false, "listing_expired"
    end

    if listing.sellerUid == buyerUid then
        return false, "cannot_buy_own_listing"
    end

    -- 检查黑名单
    local buyerBlacklist = _blacklist[buyerUid] or {}
    for _, blockedUid in ipairs(buyerBlacklist) do
        if blockedUid == listing.sellerUid then
            return false, "seller_blocked"
        end
    end
    local sellerBlacklist = _blacklist[listing.sellerUid] or {}
    for _, blockedUid in ipairs(sellerBlacklist) do
        if blockedUid == buyerUid then
            return false, "buyer_blocked"
        end
    end

    -- 计算手续费
    local fee = math.floor(listing.price * TradeSystem.Config.feeRate)
    local totalCost = listing.price + fee

    -- 创建交易记录
    local tradeId = _GenerateTradeId()
    local trade = {
        id = tradeId,
        listingId = listingId,
        buyerUid = buyerUid,
        sellerUid = listing.sellerUid,
        itemId = listing.itemId,
        itemName = listing.itemName,
        itemRarity = listing.itemRarity,
        price = listing.price,
        fee = fee,
        netAmount = listing.price - fee,
        status = "completed",
        completedAt = _Now()
    }

    _trades[tradeId] = trade

    -- 更新挂牌状态
    listing.status = "sold"
    listing.soldAt = _Now()
    listing.buyerUid = buyerUid
    listing.tradeId = tradeId

    -- 从卖家挂牌列表移除
    if _playerListings[listing.sellerUid] then
        for i, lid in ipairs(_playerListings[listing.sellerUid]) do
            if lid == listingId then
                table.remove(_playerListings[listing.sellerUid], i)
                break
            end
        end
    end

    EventBus.Publish(EventBus.Events.TRADE_PURCHASE, {
        tradeId = tradeId,
        buyerUid = buyerUid,
        sellerUid = listing.sellerUid,
        itemName = listing.itemName,
        price = listing.price,
        fee = fee
    })

    -- 交易成功触发藏品收集事件（v1.1 系统集成）
    EventBus.Publish(EventBus.Events.ITEM_COLLECT, {
        uid = buyerUid,
        itemName = listing.itemName,
        itemRarity = listing.itemRarity,
        source = "trade_market"
    })

    print("[Trade] 交易完成: " .. tradeId .. " - " .. listing.itemName .. "，" .. tostring(buyerUid) .. " 购买")

    return true, tradeId, {
        itemId = listing.itemId,
        itemName = listing.itemName,
        itemRarity = listing.itemRarity,
        price = listing.price,
        fee = fee,
        totalCost = totalCost,
        tradeId = tradeId
    }
end

-- ============================================================================
-- 取消挂单
-- ============================================================================
function TradeSystem.CancelListing(uid, listingId)
    local listing = _listings[listingId]
    if not listing then
        return false, "listing_not_found"
    end

    if listing.sellerUid ~= uid then
        return false, "not_owner"
    end

    if listing.status ~= "active" then
        return false, "cannot_cancel"
    end

    listing.status = "cancelled"

    -- 从挂牌列表移除
    if _playerListings[uid] then
        for i, lid in ipairs(_playerListings[uid]) do
            if lid == listingId then
                table.remove(_playerListings[uid], i)
                break
            end
        end
    end

    EventBus.Publish(EventBus.Events.TRADE_CANCEL, {
        listingId = listingId,
        uid = uid
    })

    print("[Trade] 挂单取消: " .. listingId)
    return true
end

-- ============================================================================
-- 获取市场列表
-- ============================================================================
function TradeSystem.GetMarketList(filter)
    filter = filter or {}

    local results = {}

    for _, listing in pairs(_listings) do
        if listing.status == "active" and _Now() <= listing.expiresAt then
            -- 应用筛选
            if filter.rarity and listing.itemRarity ~= filter.rarity then
                goto continue
            end
            if filter.category and listing.itemCategory ~= filter.category then
                goto continue
            end
            if filter.series and listing.itemSeries ~= filter.series then
                goto continue
            end
            if filter.minPrice and listing.price < filter.minPrice then
                goto continue
            end
            if filter.maxPrice and listing.price > filter.maxPrice then
                goto continue
            end

            table.insert(results, {
                id = listing.id,
                itemId = listing.itemId,
                itemName = listing.itemName,
                itemRarity = listing.itemRarity,
                category = listing.itemCategory,
                price = listing.price,
                sellerName = listing.sellerName,
                expiresAt = listing.expiresAt
            })

            ::continue::
        end
    end

    -- 排序
    local sortBy = filter.sortBy or "recent"  -- recent, price_asc, price_desc, rarity
    if sortBy == "recent" then
        table.sort(results, function(a, b)
            return a.expiresAt < b.expiresAt  -- 快过期的排前面
        end)
    elseif sortBy == "price_asc" then
        table.sort(results, function(a, b) return a.price < b.price end)
    elseif sortBy == "price_desc" then
        table.sort(results, function(a, b) return a.price > b.price end)
    elseif sortBy == "rarity" then
        table.sort(results, function(a, b) return a.itemRarity > b.itemRarity end)
    end

    return results
end

-- ============================================================================
-- 获取玩家自己的挂单
-- ============================================================================
function TradeSystem.GetMyListings(uid)
    local listingIds = _playerListings[uid] or {}
    local results = {}

    for _, listingId in ipairs(listingIds) do
        local listing = _listings[listingId]
        if listing and listing.status == "active" then
            table.insert(results, {
                id = listing.id,
                itemId = listing.itemId,
                itemName = listing.itemName,
                itemRarity = listing.itemRarity,
                price = listing.price,
                expiresAt = listing.expiresAt,
                views = listing.views or 0
            })
        end
    end

    return results
end

-- ============================================================================
-- 获取交易历史
-- ============================================================================
function TradeSystem.GetTradeHistory(uid, limit)
    limit = limit or 20
    local results = {}

    for _, trade in pairs(_trades) do
        if trade.buyerUid == uid or trade.sellerUid == uid then
            table.insert(results, {
                id = trade.id,
                type = trade.buyerUid == uid and "purchased" or "sold",
                itemName = trade.itemName,
                itemRarity = trade.itemRarity,
                price = trade.price,
                fee = trade.fee,
                completedAt = trade.completedAt,
                counterparty = trade.buyerUid == uid and trade.sellerUid or trade.buyerUid
            })
        end
    end

    -- 按时间倒序
    table.sort(results, function(a, b)
        return a.completedAt > b.completedAt
    end)

    -- 限制数量
    local final = {}
    for i = 1, math.min(limit, #results) do
        table.insert(final, results[i])
    end

    return final
end

-- ============================================================================
-- 拉黑玩家
-- ============================================================================
function TradeSystem.BlockPlayer(uid, blockedUid)
    if uid == blockedUid then
        return false, "cannot_block_self"
    end

    if not _blacklist[uid] then
        _blacklist[uid] = {}
    end

    -- 检查是否已拉黑
    for _, blocked in ipairs(_blacklist[uid]) do
        if blocked == blockedUid then
            return false, "already_blocked"
        end
    end

    -- 检查上限
    if #_blacklist[uid] >= TradeSystem.Config.maxBlacklist then
        return false, "blacklist_full"
    end

    table.insert(_blacklist[uid], blockedUid)

    EventBus.Publish(EventBus.Events.TRADE_BLOCK, {
        uid = uid,
        blockedUid = blockedUid
    })

    print("[Trade] 拉黑玩家: " .. tostring(uid) .. " -> " .. tostring(blockedUid))
    return true
end

-- ============================================================================
-- 解除拉黑
-- ============================================================================
function TradeSystem.UnblockPlayer(uid, blockedUid)
    if not _blacklist[uid] then
        return false, "not_blocked"
    end

    for i, blocked in ipairs(_blacklist[uid]) do
        if blocked == blockedUid then
            table.remove(_blacklist[uid], i)
            EventBus.Publish("player_unblocked", {
                uid = uid,
                blockedUid = blockedUid
            })
            return true
        end
    end

    return false, "not_blocked"
end

-- ============================================================================
-- 获取黑名单列表
-- ============================================================================
function TradeSystem.GetBlacklist(uid)
    return _blacklist[uid] or {}
end

-- ============================================================================
-- 举报挂单/交易
-- ============================================================================
function TradeSystem.ReportListing(reporterUid, listingId, reason)
    EventBus.Publish("listing_reported", {
        reporterUid = reporterUid,
        listingId = listingId,
        reason = reason or "unknown"
    })

    print("[Trade] 举报挂单: " .. listingId .. " by " .. tostring(reporterUid))
    return true
end

-- ============================================================================
-- 获取市场统计
-- ============================================================================
function TradeSystem.GetMarketStats()
    local stats = {
        totalListings = 0,
        activeListings = 0,
        totalTrades = 0,
        todayTrades = 0,
        byRarity = {},
        byCategory = {}
    }

    local todayStart = _Now() - (_Now() % 86400)

    for _, listing in pairs(_listings) do
        stats.totalListings = stats.totalListings + 1
        if listing.status == "active" and _Now() <= listing.expiresAt then
            stats.activeListings = stats.activeListings + 1

            -- 按稀有度统计
            local rarityKey = "rarity_" .. listing.itemRarity
            stats.byRarity[rarityKey] = (stats.byRarity[rarityKey] or 0) + 1

            -- 按分类统计
            local catKey = listing.itemCategory
            stats.byCategory[catKey] = (stats.byCategory[catKey] or 0) + 1
        end
    end

    for _, trade in pairs(_trades) do
        stats.totalTrades = stats.totalTrades + 1
        if trade.completedAt >= todayStart then
            stats.todayTrades = stats.todayTrades + 1
        end
    end

    return stats
end

-- ============================================================================
-- 重置（测试用）
-- ============================================================================
function TradeSystem.Reset()
    _listings = {}
    _trades = {}
    _playerListings = {}
    _blacklist = {}
    print("[Trade] 数据已重置")
end

-- ============================================================================
-- 注册事件监听
-- ============================================================================
function TradeSystem.RegisterEvents()
    -- 订阅赛季系统事件（v1.1 集成）
    EventBus.Subscribe(EventBus.Events.SEASON_LEVELUP, function(data)
        print("[TradeSystem] 赛季升级，解锁更高等级的藏品交易: " .. tostring(data.uid))
    end, "TradeSystem")

    -- 订阅藏品相关事件（v1.1 集成）
    EventBus.Subscribe(EventBus.Events.ITEM_COLLECT, function(data)
        print("[TradeSystem] 玩家获得藏品，可上架市场: " .. tostring(data.uid))
    end, "TradeSystem")

    -- 订阅成就事件（v1.1 集成）
    EventBus.Subscribe(EventBus.Events.ACHIEVEMENT_UNLOCK, function(data)
        print("[TradeSystem] 成就解锁，获得藏品加成: " .. tostring(data.uid))
    end, "TradeSystem")

    print("[TradeSystem] 事件监听已注册")
end

return TradeSystem
