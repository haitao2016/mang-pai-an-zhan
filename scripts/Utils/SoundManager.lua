-- ============================================================================
-- SoundManager.lua - 音效与音乐管理器
-- 管理 BGM、环境音效、技能音效、UI 音效
-- ============================================================================

local SoundManager = {}

-- ============================================================================
-- 音效配置
-- ============================================================================

-- 背景音乐列表
SoundManager.BGM = {
    LOBBY      = "Music/lobby.mp3",      -- 大厅音乐
    BIDDING    = "Music/bidding.mp3",      -- 竞拍紧张音乐
    SPEED_WIN  = "Music/speed_win.mp3",    -- 速胜音乐
    REVEAL     = "Music/reveal.mp3",       -- 开箱揭示音乐
    RESULT     = "Music/result.mp3",       -- 结算音乐
}

-- UI 音效
SoundManager.SFX = {
    CLICK       = "SFX/ui_click.mp3",       -- 按钮点击
    BID_CONFIRM = "SFX/bid_confirm.mp3",    -- 出价确认
    BID_LOCK    = "SFX/bid_lock.mp3",      -- 出价锁定
    TIMER_TICK  = "SFX/timer_tick.mp3",     -- 倒计时滴答（最后5秒）
    ROUND_START = "SFX/round_start.mp3",   -- 回合开始
    ROUND_END   = "SFX/round_end.mp3",     -- 回合结束
    SPEED_WIN   = "SFX/speed_win.mp3",     -- 速胜触发
    GAME_WIN    = "SFX/game_win.mp3",      -- 获胜
    GAME_LOSE   = "SFX/game_lose.mp3",     -- 失败
    ITEM_REVEAL = "SFX/item_reveal.mp3",   -- 物品揭示
    RARE_ITEM   = "SFX/rare_item.mp3",     -- 稀有物品出现
    LEGEND_ITEM = "SFX/legend_item.mp3",   -- 传说物品出现
    SKILL_USE   = "SFX/skill_use.mp3",     -- 技能使用
    SKILL_READY = "SFX/skill_ready.mp3",   -- 技能就绪
    ERROR       = "SFX/error.mp3",         -- 操作错误
    NOTIFICATION = "SFX/notification.mp3", -- 系统通知
    EMOTE       = "SFX/emote.mp3",         -- 表情音效
}

-- 音量配置
SoundManager.Volume = {
    master = 1.0,    -- 主音量
    music  = 0.6,    -- 音乐音量
    sfx    = 0.8,   -- 音效音量
}

-- ============================================================================
-- 模块变量
-- ============================================================================

---@type SoundSource
local bgmSource_ = nil
---@type SoundSource
local sfxSource_ = nil

local currentBGM_ = nil
local bgmEnabled_ = true
local sfxEnabled_ = true

-- ============================================================================
-- 初始化
-- ============================================================================

function SoundManager.Init(scene)
    if not scene then
        scene = engine:GetScene()
    end

    -- 创建 BGM 播放源（循环播放）
    local bgmNode = scene:CreateChild("BGMNode")
    bgmSource_ = bgmNode:CreateComponent("SoundSource")
    bgmSource_:SetSoundType(SOUND_MUSIC)

    -- 创建 SFX 播放源（单次播放）
    local sfxNode = scene:CreateChild("SFXNode")
    sfxSource_ = sfxNode:CreateComponent("SoundSource")
    sfxSource_:SetSoundType(SOUND_EFFECT)

    print("[SoundManager] Initialized")
end

-- ============================================================================
-- 音乐控制
-- ============================================================================

--- 播放背景音乐
---@param bgmKey string BGM 键名
---@param fadeIn number 淡入时长（秒），可选
function SoundManager.PlayBGM(bgmKey, fadeIn)
    if not bgmSource_ then
        print("[SoundManager] Not initialized")
        return
    end

    if not bgmEnabled_ then
        return
    end

    local path = SoundManager.BGM[bgmKey]
    if not path then
        print("[SoundManager] Unknown BGM key: " .. tostring(bgmKey))
        return
    end

    local sound = cache:GetResource("Sound", path)
    if not sound then
        print("[SoundManager] BGM not found: " .. path)
        return
    end

    sound:SetLooped(true)

    if fadeIn and fadeIn > 0 then
        bgmSource_:SetFadeInTime(fadeIn)
    end

    bgmSource_:Play(sound)
    currentBGM_ = bgmKey

    print("[SoundManager] Playing BGM: " .. bgmKey)
end

--- 停止背景音乐
---@param fadeOut number 淡出时长（秒），可选
function SoundManager.StopBGM(fadeOut)
    if not bgmSource_ then return end

    if fadeOut and fadeOut > 0 then
        bgmSource_:SetFadeOutTime(fadeOut)
    end

    bgmSource_:Stop()
    currentBGM_ = nil

    print("[SoundManager] BGM stopped")
end

--- 暂停背景音乐
function SoundManager.PauseBGM()
    if bgmSource_ then
        bgmSource_:Pause()
        print("[SoundManager] BGM paused")
    end
end

--- 恢复背景音乐
function SoundManager.ResumeBGM()
    if bgmSource_ then
        bgmSource_:Play()
        print("[SoundManager] BGM resumed")
    end
end

--- 切换 BGM（带交叉淡入淡出）
---@param bgmKey string
---@param crossfade number 交叉淡入淡出时长（秒）
function SoundManager.CrossfadeBGM(bgmKey, crossfade)
    crossfade = crossfade or 1.0
    SoundManager.PlayBGM(bgmKey, crossfade)
end

-- ============================================================================
-- 音效控制
-- ============================================================================

--- 播放音效
---@param sfxKey string SFX 键名
---@param volume number 音量倍率（0.0-1.0），可选
function SoundManager.PlaySFX(sfxKey, volume)
    if not sfxSource_ then
        print("[SoundManager] Not initialized")
        return
    end

    if not sfxEnabled_ then
        return
    end

    local path = SoundManager.SFX[sfxKey]
    if not path then
        print("[SoundManager] Unknown SFX key: " .. tostring(sfxKey))
        return
    end

    local sound = cache:GetResource("Sound", path)
    if not sound then
        print("[SoundManager] SFX not found: " .. path)
        return
    end

    sound:SetLooped(false)

    local vol = SoundManager.Volume.sfx
    if volume then
        vol = vol * volume
    end

    sfxSource_:SetVolume(vol)
    sfxSource_:Play(sound)

    print("[SoundManager] Playing SFX: " .. sfxKey)
end

--- 播放随机音效（用于同一按键对应多个变体）
---@param sfxKeys string[] SFX 键名数组
---@param volume number
function SoundManager.PlayRandomSFX(sfxKeys, volume)
    if not sfxKeys or #sfxKeys == 0 then return end
    local key = sfxKeys[math.random(1, #sfxKeys)]
    SoundManager.PlaySFX(key, volume)
end

-- ============================================================================
-- 音量控制
-- ============================================================================

--- 设置主音量
---@param vol number 0.0-1.0
function SoundManager.SetMasterVolume(vol)
    SoundManager.Volume.master = math.max(0, math.min(1, vol))
    SoundManager._UpdateVolumes()
    print("[SoundManager] Master volume: " .. string.format("%.0f%%", vol * 100))
end

--- 设置音乐音量
---@param vol number 0.0-1.0
function SoundManager.SetMusicVolume(vol)
    SoundManager.Volume.music = math.max(0, math.min(1, vol))
    SoundManager._UpdateVolumes()
    print("[SoundManager] Music volume: " .. string.format("%.0f%%", vol * 100))
end

--- 设置音效音量
---@param vol number 0.0-1.0
function SoundManager.SetSFXVolume(vol)
    SoundManager.Volume.sfx = math.max(0, math.min(1, vol))
    print("[SoundManager] SFX volume: " .. string.format("%.0f%%", vol * 100))
end

--- 更新实际音量
function SoundManager._UpdateVolumes()
    if bgmSource_ then
        bgmSource_:SetVolume(SoundManager.Volume.master * SoundManager.Volume.music)
    end
end

--- 启用/禁用音乐
---@param enabled boolean
function SoundManager.SetBGMEnabled(enabled)
    bgmEnabled_ = enabled
    if not enabled then
        SoundManager.StopBGM(0.5)
    end
end

--- 启用/禁用音效
---@param enabled boolean
function SoundManager.SetSFXEnabled(enabled)
    sfxEnabled_ = enabled
end

-- ============================================================================
-- 游戏事件音效封装
-- ============================================================================

--- 游戏阶段切换时自动播放对应音乐
---@param gameState string Config.GameState 值
function SoundManager.OnGameStateChanged(gameState)
    if not bgmEnabled_ then return end

    if gameState == Config.GameState.WAITING then
        SoundManager.CrossfadeBGM("LOBBY", 1.0)
    elseif gameState == Config.GameState.CHAR_SELECT then
        -- 角色选择阶段使用大厅音乐
        SoundManager.CrossfadeBGM("LOBBY", 0.5)
    elseif gameState == Config.GameState.BIDDING then
        SoundManager.CrossfadeBGM("BIDDING", 0.5)
    elseif gameState == Config.GameState.SETTLING then
        -- 结算时降低音量
        if bgmSource_ then
            bgmSource_:SetVolume(SoundManager.Volume.master * SoundManager.Volume.music * 0.5)
        end
    elseif gameState == Config.GameState.REVEALING then
        SoundManager.PlayBGM("REVEAL", 1.0)
    elseif gameState == Config.GameState.GAME_OVER then
        SoundManager.PlayBGM("RESULT", 1.0)
    end
end

--- 回合开始时播放音效
function SoundManager.OnRoundStart()
    SoundManager.PlaySFX("ROUND_START")
end

--- 回合结算时播放音效
function SoundManager.OnRoundEnd()
    SoundManager.PlaySFX("ROUND_END")
end

--- 速胜触发时播放音效
function SoundManager.OnSpeedWin()
    SoundManager.PlaySFX("SPEED_WIN")
    SoundManager.PlayBGM("SPEED_WIN", 0)
end

--- 物品揭示时播放音效
---@param rarity number 稀有度 1-4
function SoundManager.OnItemReveal(rarity)
    SoundManager.PlaySFX("ITEM_REVEAL")
    if rarity == 4 then
        SoundManager.PlaySFX("LEGEND_ITEM")
    elseif rarity == 3 then
        SoundManager.PlaySFX("RARE_ITEM")
    end
end

--- 获胜时播放音效
function SoundManager.OnGameWin()
    SoundManager.PlaySFX("GAME_WIN")
end

--- 失败时播放音效
function SoundManager.OnGameLose()
    SoundManager.PlaySFX("GAME_LOSE")
end

--- 技能使用时播放音效
function SoundManager.OnSkillUsed()
    SoundManager.PlaySFX("SKILL_USE")
end

--- 技能就绪时播放音效
function SoundManager.OnSkillReady()
    SoundManager.PlaySFX("SKILL_READY")
end

--- 倒计时最后5秒播放滴答声
---@param secondsLeft number
function SoundManager.OnTimerTick(secondsLeft)
    if secondsLeft <= 5 and secondsLeft > 0 then
        SoundManager.PlaySFX("TIMER_TICK")
    end
end

--- UI 按钮点击音效
function SoundManager.OnUIClick()
    SoundManager.PlaySFX("CLICK")
end

--- 出价确认音效
function SoundManager.OnBidConfirm()
    SoundManager.PlaySFX("BID_CONFIRM")
end

--- 出价锁定音效
function SoundManager.OnBidLock()
    SoundManager.PlaySFX("BID_LOCK")
end

--- 错误音效
function SoundManager.OnError()
    SoundManager.PlaySFX("ERROR")
end

--- 通知音效
function SoundManager.OnNotification()
    SoundManager.PlaySFX("NOTIFICATION")
end

--- 表情音效
function SoundManager.OnEmote()
    SoundManager.PlayRandomSFX({"EMOTE"}, 0.5)
end

-- ============================================================================
-- 清理
-- ============================================================================

function SoundManager.Shutdown()
    if bgmSource_ then
        bgmSource_:Stop()
        bgmSource_ = nil
    end
    if sfxSource_ then
        sfxSource_:Stop()
        sfxSource_ = nil
    end
    print("[SoundManager] Shutdown")
end

return SoundManager
