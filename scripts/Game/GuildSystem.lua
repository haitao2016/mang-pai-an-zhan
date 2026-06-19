-- ============================================================================
-- GuildSystem.lua - 公会系统（v1.3.0 核心系统）
-- ----------------------------------------------------------------------------
-- 功能：
--   1. 公会创建 / 加入 / 邀请 / 离开 / 踢出
--   2. 公会等级系统（1-10级，贡献值升级）
--   3. 公会战系统（公会 vs 公会 团队战）
--   4. 公会商店（使用贡献值兑换专属道具）
--   5. EventBus 事件集成（v1.2 统一事件系统）
--
-- 规则：
--   - 创建公会需要 5000 金币
--   - 公会成员上限：10 + (等级-1) * 5 人
--   - 贡献值来源：公会战胜利 / 参与活动 / 每日签到
--   - 公会战：每局胜利 +100 公会贡献，成员各 +20 个人贡献
-- ============================================================================

local Config = require("Config")
local EventBus = require("Utils.EventBus")

local GuildSystem = {}

-- ============================================================================
-- 内部状态
-- ============================================================================
local _guilds = {}           -- { [guildId] = GuildData }
local _playerGuilds = {}     -- { [uid] = guildId }
local _pendingInvites = {}   -- { [uid] = { guildId, inviterUid, timestamp } }
local _guildWarMatches = {}  -- { [matchId] = GuildWarMatch }
local _shopPurchases = {}    -- { [uid] = { itemId = lastPurchaseTime } }

-- ============================================================================
-- 公会配置
-- ============================================================================
GuildSystem.Config = {
    createCost = 5000,          -- 创建公会费用
    maxNameLength = 12,          -- 公会名称长度上限
    baseMaxMembers = 10,         -- 基础成员数
    membersPerLevel = 5,         -- 每级增加成员数
    maxLevel = 10,               -- 最高等级
    expPerLevel = 500,           -- 每级所需经验（递增）
    warVictoryGuildExp = 100,    -- 公会战胜利公会经验
    warVictoryMemberContribution = 20,  -- 成员个人贡献值
    warVictoryReward = 500,       -- 公会战胜利金币奖励
    dailySignInContribution = 5,  -- 每日签到贡献值
}

-- ============================================================================
-- 公会商店配置
-- ============================================================================
GuildSystem.ShopItems = {
    { id = "guild_gold_pack", name = "公会金币包", rarity = 2, cost = 50, reward = { gold = 1000 } },
    { id = "guild_item_pack", name = "公会藏品包", rarity = 3, cost = 100, reward = { item = true } },
    { id = "guild_skill_boost", name = "技能强化符", rarity = 3, cost = 150, reward = { skillBoost = true } },
    { id = "guild_avatar_frame", name = "公会专属头像框", rarity = 4, cost = 300, reward = { avatarFrame = "guild" } },
    { id = "guild_title", name = "公会精英称号", rarity = 4, cost = 500, reward = { title = "guild_elite" } },
    { id = "guild_legendary_item", name = "公会传说藏品", rarity = 5, cost = 1000, reward = { legendaryItem = true } },
}

-- ============================================================================
-- 辅助函数
-- ============================================================================
local function _Now()
    if os and os.time then return os.time() end
    return 0
end

local function _GenerateGuildId()
    return "GUILD_" .. tostring(_Now()) .. "_" .. string.sub(tostring(math.random(1000, 9999)), 1, 4)
end

local function _GetGuild(guildId)
    return _guilds[guildId]
end

local function _GetPlayerGuild(uid)
    local gid = _playerGuilds[uid]
    if gid and _guilds[gid] then
        return _guilds[gid], gid
    end
    return nil, nil
end

-- ============================================================================
-- 公会核心管理
-- ============================================================================

-- 创建公会
function GuildSystem.CreateGuild(leaderUid, name, description)
    -- 检查是否已有公会
    if _playerGuilds[leaderUid] then
        return false, "already_in_guild", "你已经加入了一个公会"
    end

    -- 检查名称
    if not name or #name == 0 then
        return false, "invalid_name", "公会名称不能为空"
    end
    if #name > GuildSystem.Config.maxNameLength then
        return false, "name_too_long", "公会名称过长"
    end

    -- 检查名称是否已存在
    for _, g in pairs(_guilds) do
        if g.name == name then
            return false, "name_exists", "该公会名称已被使用"
        end
    end

    -- 创建公会
    local guildId = _GenerateGuildId()
    local guild = {
        id = guildId,
        name = name,
        description = description or "",
        leaderUid = leaderUid,
        level = 1,
        experience = 0,
        totalContribution = 0,
        createdAt = _Now(),
        members = {
            {
                uid = leaderUid,
                role = "leader",         -- leader, officer, member
                joinedAt = _Now(),
                personalContribution = 0,
                totalContribution = 0,
                warWins = 0,
            }
        },
        memberCount = 1,
        warWins = 0,
        warLosses = 0,
    }

    _guilds[guildId] = guild
    _playerGuilds[leaderUid] = guildId

    -- 发布事件
    EventBus.Publish(EventBus.Events.GUILD_CREATE, {
        guildId = guildId,
        leaderUid = leaderUid,
        name = name,
    })

    print(string.format("[GuildSystem] 公会创建成功: %s (id=%s, leader=%s)", name, guildId, tostring(leaderUid)))
    return true, guildId
end

-- 邀请玩家加入公会
function GuildSystem.InviteMember(guildId, inviterUid, targetUid)
    local guild = _GetGuild(guildId)
    if not guild then
        return false, "guild_not_found", "公会不存在"
    end

    -- 检查邀请者是否在公会中
    local isMember = false
    local isOfficerOrLeader = false
    for _, m in ipairs(guild.members) do
        if m.uid == inviterUid then
            isMember = true
            if m.role == "leader" or m.role == "officer" then
                isOfficerOrLeader = true
            end
            break
        end
    end
    if not isMember then
        return false, "not_member", "你不在公会中"
    end
    if not isOfficerOrLeader then
        return false, "no_permission", "只有会长和官员可以邀请"
    end

    -- 检查目标是否已有公会
    if _playerGuilds[targetUid] then
        return false, "target_in_guild", "对方已经加入了公会"
    end

    -- 创建邀请
    _pendingInvites[targetUid] = {
        guildId = guildId,
        inviterUid = inviterUid,
        timestamp = _Now(),
    }

    -- 发布事件
    EventBus.Publish(EventBus.Events.GUILD_INVITE, {
        guildId = guildId,
        inviterUid = inviterUid,
        targetUid = targetUid,
    })

    print(string.format("[GuildSystem] 邀请发送: %s -> %s (guild=%s)", tostring(inviterUid), tostring(targetUid), guildId))
    return true
end

-- 玩家加入公会（通过邀请）
function GuildSystem.JoinGuild(guildId, uid)
    -- 检查是否已有公会
    if _playerGuilds[uid] then
        return false, "already_in_guild", "你已经加入了一个公会"
    end

    -- 检查公会
    local guild = _GetGuild(guildId)
    if not guild then
        return false, "guild_not_found", "公会不存在"
    end

    -- 检查成员上限
    local maxMembers = GuildSystem.Config.baseMaxMembers + (guild.level - 1) * GuildSystem.Config.membersPerLevel
    if #guild.members >= maxMembers then
        return false, "guild_full", "公会成员已满"
    end

    -- 添加成员
    table.insert(guild.members, {
        uid = uid,
        role = "member",
        joinedAt = _Now(),
        personalContribution = 0,
        totalContribution = 0,
        warWins = 0,
    })
    guild.memberCount = #guild.members
    _playerGuilds[uid] = guildId

    EventBus.Publish(EventBus.Events.GUILD_JOIN, {
        guildId = guildId,
        uid = uid,
        memberCount = guild.memberCount,
    })

    print(string.format("[GuildSystem] 玩家 %s 加入公会 %s", tostring(uid), guildId))
    return true
end

-- 离开公会
function GuildSystem.LeaveGuild(uid)
    local guild, gid = _GetPlayerGuild(uid)
    if not guild then
        return false, "not_in_guild", "你没有加入公会"
    end

    -- 会长不能直接离开，需要先转让
    for _, m in ipairs(guild.members) do
        if m.uid == uid and m.role == "leader" and guild.memberCount > 1 then
            return false, "leader_cannot_leave", "请先转让会长后再离开"
        end
    end

    -- 移除成员
    for i, m in ipairs(guild.members) do
        if m.uid == uid then
            table.remove(guild.members, i)
            break
        end
    end
    guild.memberCount = #guild.members
    _playerGuilds[uid] = nil

    -- 如果公会为空，则解散
    if guild.memberCount == 0 then
        _guilds[gid] = nil
        print(string.format("[GuildSystem] 公会解散: %s", gid))
    end

    EventBus.Publish(EventBus.Events.GUILD_LEAVE, {
        guildId = gid,
        uid = uid,
    })

    print(string.format("[GuildSystem] 玩家 %s 离开公会 %s", tostring(uid), gid))
    return true
end

-- 踢出成员
function GuildSystem.KickMember(guildId, kickerUid, targetUid)
    local guild = _GetGuild(guildId)
    if not guild then
        return false, "guild_not_found", "公会不存在"
    end

    -- 检查权限
    local kickerRole = nil
    local targetRole = nil
    for _, m in ipairs(guild.members) do
        if m.uid == kickerUid then
            kickerRole = m.role
        end
        if m.uid == targetUid then
            targetRole = m.role
        end
    end

    if not kickerRole then
        return false, "not_member", "你不在公会中"
    end
    if not targetRole then
        return false, "target_not_member", "对方不在公会中"
    end
    if kickerRole ~= "leader" and kickerRole ~= "officer" then
        return false, "no_permission", "没有权限"
    end
    if kickerRole == "officer" and targetRole ~= "member" then
        return false, "cannot_kick_same_level", "官员不能踢出同级或上级"
    end
    if targetUid == kickerUid then
        return false, "cannot_kick_self", "不能踢出自己"
    end

    -- 执行踢出
    for i, m in ipairs(guild.members) do
        if m.uid == targetUid then
            table.remove(guild.members, i)
            break
        end
    end
    guild.memberCount = #guild.members
    _playerGuilds[targetUid] = nil

    -- 发布事件
    EventBus.Publish(EventBus.Events.GUILD_KICK, {
        guildId = guildId,
        targetUid = targetUid,
        kickerUid = kickerUid,
        role = targetRole,
    })

    print(string.format("[GuildSystem] 玩家 %s 被踢出公会 %s (by %s)", tostring(targetUid), guildId, tostring(kickerUid)))
    return true
end

-- ============================================================================
-- 公会等级与贡献值
-- ============================================================================

-- 增加贡献值（同时升级公会）
function GuildSystem.AddContribution(guildId, uid, amount, reason)
    local guild = _GetGuild(guildId)
    if not guild then
        return false, "guild_not_found"
    end

    -- 更新成员贡献
    for _, m in ipairs(guild.members) do
        if m.uid == uid then
            m.personalContribution = m.personalContribution + amount
            m.totalContribution = m.totalContribution + amount
            break
        end
    end

    -- 更新公会总贡献和经验
    guild.totalContribution = guild.totalContribution + amount
    guild.experience = guild.experience + amount

    -- 检查升级
    local leveledUp = false
    while guild.level < GuildSystem.Config.maxLevel do
        local requiredExp = guild.level * GuildSystem.Config.expPerLevel
        if guild.experience >= requiredExp then
            guild.experience = guild.experience - requiredExp
            guild.level = guild.level + 1
            leveledUp = true
        else
            break
        end
    end

    -- 发布事件
    EventBus.Publish(EventBus.Events.GUILD_CONTRIBUTION, {
        guildId = guildId,
        uid = uid,
        amount = amount,
        totalContribution = guild.totalContribution,
        level = guild.level,
    })

    if leveledUp then
        EventBus.Publish(EventBus.Events.GUILD_LEVEL_UP, {
            guildId = guildId,
            newLevel = guild.level,
            uid = uid,
        })
        print(string.format("[GuildSystem] 公会 %s 升级到 %d 级", guildId, guild.level))
    end

    return true
end

-- 获取玩家贡献
function GuildSystem.GetContribution(guildId, uid)
    local guild = _GetGuild(guildId)
    if not guild then return 0 end
    for _, m in ipairs(guild.members) do
        if m.uid == uid then
            return m.personalContribution, m.totalContribution
        end
    end
    return 0, 0
end

-- 获取公会等级信息
function GuildSystem.GetGuildLevel(guildId)
    local guild = _GetGuild(guildId)
    if not guild then return nil end
    return {
        level = guild.level,
        experience = guild.experience,
        requiredExp = guild.level * GuildSystem.Config.expPerLevel,
        maxLevel = GuildSystem.Config.maxLevel,
    }
end

-- 每日签到
function GuildSystem.DailySignIn(guildId, uid)
    return GuildSystem.AddContribution(guildId, uid, GuildSystem.Config.dailySignInContribution, "daily_signin")
end

-- ============================================================================
-- 公会战系统
-- ============================================================================

-- 开始公会战
function GuildSystem.StartGuildWar(guild1Id, guild2Id)
    local guild1 = _GetGuild(guild1Id)
    local guild2 = _GetGuild(guild2Id)

    if not guild1 or not guild2 then
        return false, "guild_not_found"
    end

    local matchId = "GW_" .. tostring(_Now()) .. "_" .. string.sub(tostring(math.random(1000,9999)), 1, 4)
    local match = {
        id = matchId,
        guild1 = guild1Id,
        guild2 = guild2Id,
        guild1Score = 0,
        guild2Score = 0,
        status = "active",
        startedAt = _Now(),
        rounds = {},
    }

    _guildWarMatches[matchId] = match

    EventBus.Publish(EventBus.Events.GUILD_WAR_START, {
        matchId = matchId,
        guild1Id = guild1Id,
        guild2Id = guild2Id,
    })

    print(string.format("[GuildSystem] 公会战开始: %s vs %s (match=%s)", guild1Id, guild2Id, matchId))
    return true, matchId
end

-- 提交公会战结果
function GuildSystem.SubmitGuildWarResult(matchId, winnerGuildId)
    local match = _guildWarMatches[matchId]
    if not match then
        return false, "match_not_found"
    end

    if match.status ~= "active" then
        return false, "match_not_active"
    end

    match.status = "completed"
    match.winner = winnerGuildId
    match.endedAt = _Now()

    local loserGuildId = winnerGuildId == match.guild1 and match.guild2 or match.guild1

    -- 更新战绩
    local winnerGuild = _GetGuild(winnerGuildId)
    local loserGuild = _GetGuild(loserGuildId)

    if winnerGuild then
        winnerGuild.warWins = winnerGuild.warWins + 1

        -- 给所有成员增加贡献值
        for _, m in ipairs(winnerGuild.members) do
            m.warWins = m.warWins + 1
            GuildSystem.AddContribution(winnerGuildId, m.uid, GuildSystem.Config.warVictoryMemberContribution, "guild_war_victory")
        end

        -- 公会经验
        winnerGuild.experience = winnerGuild.experience + GuildSystem.Config.warVictoryGuildExp
        winnerGuild.totalContribution = winnerGuild.totalContribution + GuildSystem.Config.warVictoryGuildExp
    end

    if loserGuild then
        loserGuild.warLosses = loserGuild.warLosses + 1
    end

    -- 发布事件
    EventBus.Publish(EventBus.Events.GUILD_WAR_END, {
        matchId = matchId,
        winnerGuildId = winnerGuildId,
        loserGuildId = loserGuildId,
    })

    print(string.format("[GuildSystem] 公会战结束: 胜者=%s, 败者=%s (match=%s)", winnerGuildId, loserGuildId, matchId))
    return true
end

-- 获取公会战历史
function GuildSystem.GetGuildWarHistory(guildId, limit)
    limit = limit or 20
    local history = {}
    for _, match in pairs(_guildWarMatches) do
        if match.guild1 == guildId or match.guild2 == guildId then
            table.insert(history, {
                matchId = match.id,
                opponentId = match.guild1 == guildId and match.guild2 or match.guild1,
                won = match.winner == guildId,
                status = match.status,
                startedAt = match.startedAt,
                endedAt = match.endedAt,
            })
        end
    end

    -- 按时间倒序
    table.sort(history, function(a, b) return a.startedAt > b.startedAt end)

    local result = {}
    for i = 1, math.min(limit, #history) do
        table.insert(result, history[i])
    end
    return result
end

-- ============================================================================
-- 公会商店
-- ============================================================================

-- 获取商店物品列表
function GuildSystem.GetGuildShopItems(guildId)
    local items = {}
    for _, item in ipairs(GuildSystem.ShopItems) do
        table.insert(items, {
            id = item.id,
            name = item.name,
            rarity = item.rarity,
            cost = item.cost,
            description = item.description,
        })
    end
    return items
end

-- 购买商店物品
function GuildSystem.PurchaseShopItem(guildId, uid, itemId)
    local guild = _GetGuild(guildId)
    if not guild then
        return false, "guild_not_found"
    end

    -- 查找玩家贡献
    local playerContribution = nil
    for _, m in ipairs(guild.members) do
        if m.uid == uid then
            playerContribution = m.personalContribution
            break
        end
    end
    if playerContribution == nil then
        return false, "not_member"
    end

    -- 查找物品
    local shopItem = nil
    for _, item in ipairs(GuildSystem.ShopItems) do
        if item.id == itemId then
            shopItem = item
            break
        end
    end
    if not shopItem then
        return false, "item_not_found"
    end

    -- 检查贡献值
    if playerContribution < shopItem.cost then
        return false, "insufficient_contribution",
            "贡献值不足，需要: " .. shopItem.cost .. ", 当前: " .. playerContribution
    end

    -- 扣除贡献值
    for _, m in ipairs(guild.members) do
        if m.uid == uid then
            m.personalContribution = m.personalContribution - shopItem.cost
            break
        end
    end

    print(string.format("[GuildSystem] 玩家 %s 购买了 %s (花费 %d 贡献)", tostring(uid), shopItem.name, shopItem.cost))

    -- 发布事件
    EventBus.Publish(EventBus.Events.GUILD_SHOP_PURCHASE, {
        guildId = guildId,
        uid = uid,
        itemId = itemId,
        itemName = shopItem.name,
        cost = shopItem.cost,
        rewardType = shopItem.rewardType or shopItem.reward and shopItem.reward.type or "unknown",
        reward = shopItem.reward,
    })

    return true, shopItem.reward
end

-- ============================================================================
-- 查询接口
-- ============================================================================

-- 获取公会信息
function GuildSystem.GetGuildInfo(guildId)
    local guild = _GetGuild(guildId)
    if not guild then return nil end

    return {
        id = guild.id,
        name = guild.name,
        description = guild.description,
        leaderUid = guild.leaderUid,
        level = guild.level,
        experience = guild.experience,
        requiredExp = guild.level * GuildSystem.Config.expPerLevel,
        totalContribution = guild.totalContribution,
        memberCount = guild.memberCount,
        maxMembers = GuildSystem.Config.baseMaxMembers + (guild.level - 1) * GuildSystem.Config.membersPerLevel,
        warWins = guild.warWins,
        warLosses = guild.warLosses,
        createdAt = guild.createdAt,
    }
end

-- 获取玩家的公会信息
function GuildSystem.GetPlayerGuild(uid)
    local guild, gid = _GetPlayerGuild(uid)
    if not guild then return nil end

    local myMemberInfo = nil
    for _, m in ipairs(guild.members) do
        if m.uid == uid then
            myMemberInfo = m
            break
        end
    end

    return {
        guildId = gid,
        name = guild.name,
        level = guild.level,
        myRole = myMemberInfo and myMemberInfo.role or "member",
        myContribution = myMemberInfo and myMemberInfo.personalContribution or 0,
        myTotalContribution = myMemberInfo and myMemberInfo.totalContribution or 0,
        memberCount = guild.memberCount,
        warWins = guild.warWins,
    }
end

-- 获取公会成员列表
function GuildSystem.GetMembers(guildId)
    local guild = _GetGuild(guildId)
    if not guild then return {} end

    local members = {}
    for _, m in ipairs(guild.members) do
        table.insert(members, {
            uid = m.uid,
            role = m.role,
            joinedAt = m.joinedAt,
            personalContribution = m.personalContribution,
            totalContribution = m.totalContribution,
            warWins = m.warWins,
        })
    end

    -- 按贡献值排序
    table.sort(members, function(a, b) return a.totalContribution > b.totalContribution end)
    return members
end

-- 获取公会排行榜
function GuildSystem.GetGuildLeaderboard(limit)
    limit = limit or 20
    local list = {}
    for gid, g in pairs(_guilds) do
        table.insert(list, {
            guildId = gid,
            name = g.name,
            level = g.level,
            totalContribution = g.totalContribution,
            memberCount = g.memberCount,
            warWins = g.warWins,
        })
    end

    -- 按总贡献排序
    table.sort(list, function(a, b) return a.totalContribution > b.totalContribution end)

    local result = {}
    for i = 1, math.min(limit, #list) do
        table.insert(result, list[i])
        result[i].rank = i
    end
    return result
end

-- 获取可加入的公会列表
function GuildSystem.GetAvailableGuilds(uid, limit)
    limit = limit or 20
    if _playerGuilds[uid] then
        return {}  -- 已加入公会的玩家不返回列表
    end

    local list = {}
    for gid, g in pairs(_guilds) do
        local maxMembers = GuildSystem.Config.baseMaxMembers + (g.level - 1) * GuildSystem.Config.membersPerLevel
        if g.memberCount < maxMembers then
            table.insert(list, {
                guildId = gid,
                name = g.name,
                description = g.description,
                level = g.level,
                memberCount = g.memberCount,
                maxMembers = maxMembers,
                warWins = g.warWins,
            })
        end
    end

    -- 按等级和成员数排序
    table.sort(list, function(a, b)
        if a.level == b.level then return a.memberCount > b.memberCount end
        return a.level > b.level
    end)

    local result = {}
    for i = 1, math.min(limit, #list) do
        table.insert(result, list[i])
    end
    return result
end

-- ============================================================================
-- 统计接口
-- ============================================================================

function GuildSystem.GetStats()
    local count = 0
    local totalMembers = 0
    for _, g in pairs(_guilds) do
        count = count + 1
        totalMembers = totalMembers + g.memberCount
    end
    return {
        guildCount = count,
        totalMembers = totalMembers,
        avgMembers = count > 0 and totalMembers / count or 0,
    }
end

-- ============================================================================
-- 重置（测试用）
-- ============================================================================
function GuildSystem.Reset()
    _guilds = {}
    _playerGuilds = {}
    _pendingInvites = {}
    _guildWarMatches = {}
    _shopPurchases = {}
    print("[GuildSystem] 系统已重置")
end

-- ============================================================================
-- EventBus 事件注册
-- ============================================================================
function GuildSystem.RegisterEvents()
    -- 监听任务完成事件（v1.1 系统集成）
    EventBus.Subscribe(EventBus.Events.MISSION_COMPLETE, function(data)
        if data and data.uid then
            local guild, gid = _GetPlayerGuild(data.uid)
            if guild then
                GuildSystem.AddContribution(gid, data.uid, math.floor((data.rewardGold or 0) / 100), "mission")
            end
        end
    end, "GuildSystem")

    -- 监听赛季进度事件（v1.1 系统集成）
    EventBus.Subscribe(EventBus.Events.SEASON_PROGRESS, function(data)
        if data and data.uid then
            local guild, gid = _GetPlayerGuild(data.uid)
            if guild and data.xp and data.xp > 10 then
                GuildSystem.AddContribution(gid, data.uid, math.floor(data.xp / 10), "season_activity")
            end
        end
    end, "GuildSystem")

    print("[GuildSystem] 事件监听已注册")
end

return GuildSystem
