-- ============================================================================
-- ProfileSystem.lua - 玩家头像与个性化系统
-- ----------------------------------------------------------------------------
-- 功能：
--   1. 头像选择（默认 / 成就解锁 / 赛季解锁）
--   2. 称号系统（通过成就、赛季、特殊事件获得）
--   3. 个人资料展示
--   4. serverCloud 持久化
-- ============================================================================

local Config = require("Config")

local ProfileSystem = {}

-- ============================================================================
-- 内部状态
-- ============================================================================
local _profileCache = {}  -- { uid = { avatar, title, nickname, lastLogin } }

-- ============================================================================
-- 辅助
-- ============================================================================
local function _Now()
    if os and os.time then return os.time() end
    return 0
end

-- ============================================================================
-- 获取玩家个人资料
-- ============================================================================
local function _GetProfile(uid)
    if not uid then return nil end

    if _profileCache[uid] then
        return _profileCache[uid]
    end

    local defaultAvatar = Config.Profiles and Config.Profiles.DefaultAvatar or "A001"
    local data = {
        uid = uid,
        nickname = "玩家" .. tostring(uid),
        avatar = defaultAvatar,
        title = nil,
        unlockedAvatars = { defaultAvatar },
        unlockedTitles = {},
        lastLogin = _Now(),
        playTime = 0
    }

    -- 尝试从 serverCloud 加载
    if serverCloud and serverCloud.game and serverCloud.game.profile then
        pcall(function()
            serverCloud.game.profile:Get(uid, {
                ok = function(saved)
                    if saved and type(saved) == "table" then
                        data = saved
                        data.lastLogin = _Now()
                    end
                end
            })
        end)
    end

    _profileCache[uid] = data
    return data
end

-- ============================================================================
-- 保存
-- ============================================================================
local function _SaveProfile(uid, data)
    if not serverCloud or not serverCloud.game or not serverCloud.game.profile then
        return false
    end
    pcall(function()
        serverCloud.game.profile:Post(uid, data)
    end)
    return true
end

-- ============================================================================
-- 获取所有可用头像
-- ============================================================================
function ProfileSystem.GetAllAvatars(uid)
    if not Config.Profiles or not Config.Profiles.Avatars then
        return {}
    end

    local profile = _GetProfile(uid)
    if not profile then return {} end

    local result = {}
    for _, avatar in ipairs(Config.Profiles.Avatars) do
        local unlocked = avatar.unlocked
        if not unlocked then
            -- 检查解锁条件
            if avatar.requireAchievement then
                local ok, AchSys = pcall(require, "Game.AchievementSystem")
                if ok and AchSys and AchSys.IsUnlocked then
                    unlocked = AchSys.IsUnlocked(uid, avatar.requireAchievement)
                end
            elseif avatar.requireSeasonLevel then
                local ok, SeasonSys = pcall(require, "Game.SeasonSystem")
                if ok and SeasonSys and SeasonSys.GetPlayerStatus then
                    local status = SeasonSys.GetPlayerStatus(uid)
                    unlocked = status and status.level >= avatar.requireSeasonLevel
                end
            end
        end

        table.insert(result, {
            id = avatar.id,
            name = avatar.name,
            image = avatar.image or ("avatar_" .. avatar.id),
            unlocked = unlocked == true,
            isCurrent = profile.avatar == avatar.id
        })
    end

    return result
end

-- ============================================================================
-- 选择头像
-- ============================================================================
function ProfileSystem.SelectAvatar(uid, avatarId)
    local profile = _GetProfile(uid)
    if not profile then return false end

    -- 检查是否可用
    local avatars = ProfileSystem.GetAllAvatars(uid)
    for _, a in ipairs(avatars) do
        if a.id == avatarId and a.unlocked then
            profile.avatar = avatarId
            _SaveProfile(uid, profile)
            print("[ProfileSystem] 头像更新：" .. tostring(avatarId))
            return true
        end
    end

    return false
end

-- ============================================================================
-- 获取当前头像
-- ============================================================================
function ProfileSystem.GetCurrentAvatar(uid)
    local profile = _GetProfile(uid)
    if not profile then return nil end

    local avatars = Config.Profiles and Config.Profiles.Avatars or {}
    for _, a in ipairs(avatars) do
        if a.id == profile.avatar then
            return {
                id = a.id,
                name = a.name,
                image = a.image or ("avatar_" .. a.id)
            }
        end
    end
    return { id = "A001", name = "新手玩家", image = "avatar_A001" }
end

-- ============================================================================
-- 获取所有称号
-- ============================================================================
function ProfileSystem.GetAllTitles(uid)
    if not Config.Profiles or not Config.Profiles.Titles then
        return {}
    end

    local profile = _GetProfile(uid)
    if not profile then return {} end

    local result = {}
    for _, title in ipairs(Config.Profiles.Titles) do
        -- 简化：检查是否在已解锁列表中
        local unlocked = false
        for _, t in ipairs(profile.unlockedTitles or {}) do
            if t == title.id then unlocked = true break end
        end

        table.insert(result, {
            id = title.id,
            name = title.name,
            desc = title.desc,
            unlocked = unlocked,
            isCurrent = profile.title == title.id
        })
    end

    return result
end

-- ============================================================================
-- 解锁称号
-- ============================================================================
function ProfileSystem.UnlockTitle(uid, titleId)
    local profile = _GetProfile(uid)
    if not profile then return false end

    -- 检查是否已解锁
    for _, t in ipairs(profile.unlockedTitles) do
        if t == titleId then
            return true  -- 已解锁
        end
    end

    table.insert(profile.unlockedTitles, titleId)
    _SaveProfile(uid, profile)
    print("[ProfileSystem] 称号解锁：" .. tostring(titleId))
    return true
end

-- ============================================================================
-- 选择称号
-- ============================================================================
function ProfileSystem.SelectTitle(uid, titleId)
    local profile = _GetProfile(uid)
    if not profile then return false end

    if titleId == nil then
        profile.title = nil
        _SaveProfile(uid, profile)
        return true
    end

    -- 检查是否已解锁
    for _, t in ipairs(profile.unlockedTitles) do
        if t == titleId then
            profile.title = titleId
            _SaveProfile(uid, profile)
            print("[ProfileSystem] 称号更新：" .. tostring(titleId))
            return true
        end
    end

    return false
end

-- ============================================================================
-- 获取当前称号
-- ============================================================================
function ProfileSystem.GetCurrentTitle(uid)
    local profile = _GetProfile(uid)
    if not profile or not profile.title then return nil end

    local titles = Config.Profiles and Config.Profiles.Titles or {}
    for _, t in ipairs(titles) do
        if t.id == profile.title then
            return {
                id = t.id,
                name = t.name,
                desc = t.desc
            }
        end
    end
    return nil
end

-- ============================================================================
-- 获取玩家完整资料
-- ============================================================================
function ProfileSystem.GetProfile(uid)
    local profile = _GetProfile(uid)
    if not profile then return nil end

    return {
        uid = profile.uid,
        nickname = profile.nickname,
        avatar = ProfileSystem.GetCurrentAvatar(uid),
        title = ProfileSystem.GetCurrentTitle(uid),
        avatarCount = #profile.unlockedAvatars,
        titleCount = #profile.unlockedTitles,
        lastLogin = profile.lastLogin,
        playTime = profile.playTime or 0
    }
end

-- ============================================================================
-- 更新玩家昵称
-- ============================================================================
function ProfileSystem.SetNickname(uid, nickname)
    local profile = _GetProfile(uid)
    if not profile then return false end

    profile.nickname = nickname or profile.nickname
    _SaveProfile(uid, profile)
    print("[ProfileSystem] 昵称更新：" .. tostring(profile.nickname))
    return true
end

-- ============================================================================
-- 重置
-- ============================================================================
function ProfileSystem.Reset(uid)
    if uid then
        _profileCache[uid] = nil
    else
        _profileCache = {}
    end
end

return ProfileSystem
