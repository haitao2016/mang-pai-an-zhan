-- ============================================================================
-- TutorialManager.lua - 新手引导系统
-- 提供分步引导、提示高亮、进度追踪
-- v1.0.0 更新：角色选择说明、确认弹窗、持久化状态
-- ============================================================================

local Config = require("Config")
local cjson  = require("cjson")

local TutorialManager = {}

-- ============================================================================
-- 教程步骤定义
-- ============================================================================

TutorialManager.StepType = {
    HIGHLIGHT    = "highlight",
    TOAST        = "toast",
    WAIT_CLICK   = "wait_click",
    WAIT_EVENT   = "wait_event",
    DELAY        = "delay",
    CONDITION    = "condition",
    END          = "end",
}

-- 新手教程步骤序列
TutorialManager.Steps = {
    -- ================================================================
    -- 第一章：游戏介绍
    -- ================================================================
    {
        id = "intro_welcome",
        type = TutorialManager.StepType.TOAST,
        title = "欢迎来到《盲拍暗战》",
        content = "在开始之前，让我们先了解一下游戏的基本规则。\n\n本游戏以「暗拍」为核心—— 你看不到对手的出价， 只能通过各种线索来推断局势。",
        duration = 5,
        canSkip = true,
    },
    {
        id = "intro_blind_auction",
        type = TutorialManager.StepType.TOAST,
        title = "🎯 暗拍机制",
        content = "每位玩家独立出价，直到结算前都不知道对手出了多少。\n\n总出价最高者获得本轮的收藏品。\n\n这是一个策略与心理博弈的游戏！",
        duration = 5,
        canSkip = true,
    },
    {
        id = "intro_speed_win",
        type = TutorialManager.StepType.TOAST,
        title = "⚡ 速胜机制",
        content = "如果你出价碾压对手，可以提前结束游戏！\n\n• 第1轮：需超过对手 200%\n• 第2轮：需超过对手 160%\n• 第3轮：需超过对手 140%\n• 第4轮：需超过对手 120%\n\n第5轮无法速胜，正常结算。",
        duration = 6,
        canSkip = true,
    },

    -- ================================================================
    -- 第二章：拍卖厅选择
    -- ================================================================
    {
        id = "select_hall",
        type = TutorialManager.StepType.TOAST,
        title = "🏛️ 选择拍卖厅",
        content = "共有4个主题拍卖厅：\n\n• 新手厅：入门级，适合练手\n• 雅集厅：中等级，偶有珍品\n• 珍宝阁：高等级，常有史诗藏品\n• 天工殿：殿堂级，传说级藏品所在地\n\n请选择你想要进入的拍卖厅！",
        duration = 5,
        waitFor = "hall_select",
        highlightTarget = "hall_panel",
    },

    -- ================================================================
    -- 第三章：角色选择
    -- ================================================================
    {
        id = "char_intro",
        type = TutorialManager.StepType.TOAST,
        title = "👤 选择你的角色",
        content = "每位角色都有独特的：\n\n• 主动技能：需要手动触发\n• 被动技能：自动生效\n\n不同角色适合不同风格的玩家 —— 有擅长估价的，有擅长刺探的，也有擅长干扰对手的。\n\n选择一个与你风格匹配的角色吧！",
        duration = 6,
        canSkip = true,
    },
    {
        id = "char_detail",
        type = TutorialManager.StepType.HIGHLIGHT,
        target = "char_card",
        content = "📋 点击每个角色卡片， 查看详细的技能描述。\n\n💡 建议先阅读至少 2-3 个角色的技能。",
        duration = 5,
        waitFor = "char_viewed",
    },
    {
        id = "skill_intro",
        type = TutorialManager.StepType.HIGHLIGHT,
        target = "skill_section",
        content = "✨ 这是你的技能区域。\n\n• 主动技能（如「精准估价」、「窥探底牌」）： 需要点击使用\n• 被动技能：自动在回合内生效\n\n每个技能都有冷却时间和使用上限， 合理使用是获胜的关键！",
        duration = 6,
    },

    -- ================================================================
    -- 第四章：出价教学
    -- ================================================================
    {
        id = "bid_intro",
        type = TutorialManager.StepType.TOAST,
        title = "💰 出价教学",
        content = "每轮你都会有一定的可用资金。\n\n拖动底部滑块设置出价金额， 然后点击「确认出价」提交。\n\n⚠️ 记住：\n1. 出价越高，越有机会赢得藏品\n2. 但出价过高可能会亏损\n3. 可以随时调整出价，只要在倒计时结束前确认即可",
        duration = 6,
        canSkip = true,
    },
    {
        id = "bid_wait",
        type = TutorialManager.StepType.HIGHLIGHT,
        target = "bid_slider",
        content = "现在轮到你出价了！\n\n👉 拖动滑块调整金额\n👉 点击「确认出价」提交\n\n💡 建议：先保守一些，观察对手的模式。",
        duration = 0,
        waitFor = "bid_submitted",
    },
    {
        id = "bid_result",
        type = TutorialManager.StepType.TOAST,
        title = "📊 回合结算",
        content = "每轮结束后，你会收到模糊的排名提示：\n\n• 「领先」：你是最高出价者\n• 「接近」：你在前两名\n• 「落后」：你在第三名左右\n• 「垫底」：你出价最低\n\n这些信息帮助你判断下一轮该如何出价。",
        duration = 5,
    },
    {
        id = "hint_guide",
        type = TutorialManager.StepType.TOAST,
        title = "🔍 信息解读",
        content = "如何利用排名提示：\n\n• 如果多轮「领先」：你可能出价过高， 可以适当降低\n• 如果多轮「落后」：你可能过于保守， 可以提高出价\n• 结合角色技能：如「窥探底牌」 可以查看对手具体出价\n\n🎯 目标：以最低的必要出价赢得藏品！",
        duration = 6,
    },

    -- ================================================================
    -- 第五章：开箱揭示
    -- ================================================================
    {
        id = "reveal_intro",
        type = TutorialManager.StepType.TOAST,
        title = "🎁 开箱揭示",
        content = "竞拍结束后，获胜者将开箱展示藏品。\n\n• 藏品会逐件从迷雾中显现\n• 稀有度越高，视觉效果越华丽\n• 最终展示本次总价值\n\n🤑 总价值 > 总出价 = 盈利！",
        duration = 5,
    },
    {
        id = "rarity_guide",
        type = TutorialManager.StepType.TOAST,
        title = "💎 稀有度说明",
        content = "稀有度从低到高：\n\n• ⚪ 普通：价值较低\n• 🔵 稀有：价值中等\n• 🟣 史诗：价值较高\n• 🟡 传说：价值极高，极为罕见\n\n传说级藏品可能单价比普通藏品高出数倍！",
        duration = 5,
    },

    -- ================================================================
    -- 第六章：经济循环
    -- ================================================================
    {
        id = "economy_intro",
        type = TutorialManager.StepType.TOAST,
        title = "🔄 经济循环",
        content = "游戏中的经济循环：\n\n1. 每局获得初始资金\n2. 用于竞拍出价\n3. 赢得藏品后进入收藏馆\n4. 在收藏馆可以出售藏品获得金币\n5. 金币用于下一局的更高额竞拍\n\n💰 合理分配资金、选择出售时机 是长期获胜的关键！",
        duration = 6,
        canSkip = true,
    },

    -- ================================================================
    -- 完成
    -- ================================================================
    {
        id = "tutorial_complete",
        type = TutorialManager.StepType.TOAST,
        title = "🎉 教程完成！",
        content = "你已经掌握了《盲拍暗战》的基本规则。\n\n祝你在拍卖厅中大展身手， 赢得稀有藏品， 成为传奇拍卖师！\n\n\n💡 小提示：\n• 新获得的成就可以在成就页查看\n• 每日任务有额外金币奖励\n• 不同角色体验不同，多试几个！",
        duration = 7,
        markComplete = true,
    },
}

-- ============================================================================
-- 教程状态
-- ============================================================================

TutorialManager.state = {
    active       = false,
    currentStep  = 0,
    completed    = {},
    skipped      = false,
    paused       = false,
    persistLoaded = false,
}

-- 外部回调
TutorialManager.onStepStart = nil
TutorialManager.onStepEnd   = nil
TutorialManager.onComplete  = nil
TutorialManager.onSkip      = nil
TutorialManager.onSkipRequest = nil   -- 请求显示跳过确认弹窗

-- ============================================================================
-- 持久化（serverCloud）
-- ============================================================================

--- 加载教程完成状态
---@param uid number
---@param callback fun(ok: boolean, alreadyCompleted: boolean)
function TutorialManager.LoadState(uid, callback)
    print(string.format("[TutorialManager] Loading state for uid=%s", tostring(uid)))

    serverCloud.game.tutorial:Get(uid, {
        ok = function(data)
            local alreadyCompleted = false
            for _, entry in ipairs(data) do
                if entry.key == "completed" then
                    alreadyCompleted = (entry.value == "true")
                elseif entry.key == "skipped" then
                    if entry.value == "true" then
                        TutorialManager.state.skipped = true
                    end
                end
            end

            TutorialManager.state.persistLoaded = true
            if alreadyCompleted then
                TutorialManager.state.completed["tutorial_complete"] = true
            end

            print(string.format("[TutorialManager] Loaded, alreadyCompleted=%s", tostring(alreadyCompleted)))
            if callback then callback(true, alreadyCompleted) end
        end,
        err = function(msg)
            print(string.format("[TutorialManager] Load failed: %s", tostring(msg)))
            TutorialManager.state.persistLoaded = true
            if callback then callback(false, false) end
        end,
    })
end

--- 保存教程完成状态
---@param uid number
function TutorialManager.SaveState(uid)
    if TutorialManager.IsCompleted() then
        serverCloud.game.tutorial:Post(uid, {
            key = "completed",
            value = "true",
        })
    end

    if TutorialManager.state.skipped then
        serverCloud.game.tutorial:Post(uid, {
            key = "skipped",
            value = "true",
        })
    end
end

-- ============================================================================
-- 教程控制
-- ============================================================================

--- 开始新手教程
---@param startStepId string|nil
function TutorialManager.Start(startStepId)
    if TutorialManager.state.active then
        print("[TutorialManager] Tutorial already active")
        return
    end

    TutorialManager.state.active = true
    TutorialManager.state.currentStep = 0
    TutorialManager.state.skipped = false
    TutorialManager.state.paused = false

    if startStepId then
        for i, step in ipairs(TutorialManager.Steps) do
            if step.id == startStepId then
                TutorialManager.state.currentStep = i - 1
                break
            end
        end
    end

    print("[TutorialManager] Tutorial started")
    TutorialManager._NextStep()
end

--- 请求跳过教程（需要用户确认）
function TutorialManager.RequestSkip()
    if not TutorialManager.state.active then
        return
    end

    local currentStep = TutorialManager.GetCurrentStep()
    if currentStep and not currentStep.canSkip then
        print("[TutorialManager] Current step cannot be skipped individually")
        return
    end

    -- 由 UI 层展示确认弹窗
    if TutorialManager.onSkipRequest then
        TutorialManager.onSkipRequest(function(confirmed)
            if confirmed then
                TutorialManager.Skip()
            end
        end)
    else
        -- 没有注册弹窗处理器，直接跳过
        TutorialManager.Skip()
    end
end

--- 直接跳过教程（不需要确认）
function TutorialManager.Skip()
    if not TutorialManager.state.active then
        return
    end

    TutorialManager.state.skipped = true
    TutorialManager.state.active = false
    TutorialManager._ClearHighlight()

    if TutorialManager.onSkip then
        TutorialManager.onSkip()
    end

    print("[TutorialManager] Tutorial skipped")
end

function TutorialManager.Pause()
    TutorialManager.state.paused = true
    print("[TutorialManager] Tutorial paused")
end

function TutorialManager.Resume()
    TutorialManager.state.paused = false
    print("[TutorialManager] Tutorial resumed")
end

function TutorialManager.Reset()
    TutorialManager.state = {
        active = false,
        currentStep = 0,
        completed = {},
        skipped = false,
        paused = false,
        persistLoaded = false,
    }
    TutorialManager._ClearHighlight()
    print("[TutorialManager] Tutorial reset")
end

-- ============================================================================
-- 事件处理
-- ============================================================================

--- 通知教程系统某个事件发生
---@param eventName string
function TutorialManager.NotifyEvent(eventName)
    if not TutorialManager.state.active then
        return
    end

    local step = TutorialManager.Steps[TutorialManager.state.currentStep + 1]
    if not step then
        return
    end

    if step.waitFor == eventName then
        print("[TutorialManager] Event received: " .. eventName .. ", advancing tutorial")
        TutorialManager._EndStep()
    end
end

--- 教程中的点击处理
---@param elementId string
function TutorialManager.HandleClick(elementId)
    if not TutorialManager.state.active then
        return false
    end

    local step = TutorialManager.Steps[TutorialManager.state.currentStep + 1]
    if not step then
        return false
    end

    if step.type == TutorialManager.StepType.WAIT_CLICK then
        if step.target == elementId or step.target == "any" then
            print("[TutorialManager] Click on " .. elementId .. ", advancing tutorial")
            TutorialManager._EndStep()
            return true
        end
    end

    return false
end

-- ============================================================================
-- 内部方法
-- ============================================================================

function TutorialManager._NextStep()
    if not TutorialManager.state.active then
        return
    end

    TutorialManager.state.currentStep = TutorialManager.state.currentStep + 1

    if TutorialManager.state.currentStep > #TutorialManager.Steps then
        TutorialManager._Complete()
        return
    end

    local step = TutorialManager.Steps[TutorialManager.state.currentStep]
    print(string.format("[TutorialManager] Step %d/%d: %s",
        TutorialManager.state.currentStep, #TutorialManager.Steps, step.id))

    if TutorialManager.onStepStart then
        TutorialManager.onStepStart(step)
    end

    TutorialManager._ExecuteStep(step)
end

function TutorialManager._EndStep()
    local step = TutorialManager.Steps[TutorialManager.state.currentStep]

    if TutorialManager.onStepEnd then
        TutorialManager.onStepEnd(step)
    end

    TutorialManager._ClearHighlight()
    TutorialManager._NextStep()
end

function TutorialManager._ExecuteStep(step)
    if step.type == TutorialManager.StepType.TOAST then
        TutorialManager._ShowToast(step)

    elseif step.type == TutorialManager.StepType.HIGHLIGHT then
        TutorialManager._ShowHighlight(step)

    elseif step.type == TutorialManager.StepType.WAIT_CLICK then
        TutorialManager._ShowHighlight(step)

    elseif step.type == TutorialManager.StepType.WAIT_EVENT then
        TutorialManager._ShowToast(step)

    elseif step.type == TutorialManager.StepType.DELAY then
        TutorialManager._ShowToast(step)
        -- 延迟由 UI 层使用 Animations.UITransition 处理
        local durationMs = (step.duration or 1.0) * 1000
        if UI and UI.Schedule then
            UI.Schedule(durationMs, function()
                if TutorialManager.state.active then
                    TutorialManager._EndStep()
                end
            end)
        end

    elseif step.type == TutorialManager.StepType.CONDITION then
        TutorialManager._NextStep()

    elseif step.type == TutorialManager.StepType.END then
        TutorialManager._Complete()
    end
end

function TutorialManager._ShowToast(step)
    print(string.format("[Tutorial] [%s] %s", step.title or "", step.content or ""))
end

function TutorialManager._ShowHighlight(step)
    if step.target then
        print("[TutorialManager] Highlighting: " .. step.target)
    end
    if step.content then
        TutorialManager._ShowToast(step)
    end
end

function TutorialManager._ClearHighlight()
    print("[TutorialManager] Clearing highlight")
end

function TutorialManager._Complete()
    TutorialManager.state.active = false

    for _, step in ipairs(TutorialManager.Steps) do
        TutorialManager.state.completed[step.id] = true
    end

    print("[TutorialManager] Tutorial completed!")

    if TutorialManager.onComplete then
        TutorialManager.onComplete()
    end
end

-- ============================================================================
-- 状态查询
-- ============================================================================

function TutorialManager.IsActive()
    return TutorialManager.state.active
end

function TutorialManager.IsCompleted()
    return TutorialManager.state.completed["tutorial_complete"] == true
end

function TutorialManager.IsSkipped()
    return TutorialManager.state.skipped
end

function TutorialManager.GetCurrentStep()
    return TutorialManager.Steps[TutorialManager.state.currentStep + 1]
end

function TutorialManager.GetProgress()
    return TutorialManager.state.currentStep, #TutorialManager.Steps
end

--- 获取总步骤数
---@return number
function TutorialManager.GetTotalSteps()
    return #TutorialManager.Steps
end

--- 获取当前步骤索引
---@return number
function TutorialManager.GetCurrentStepIndex()
    return TutorialManager.state.currentStep
end

return TutorialManager
