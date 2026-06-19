-- ============================================================================
-- TutorialManager.lua - 新手引导系统
-- 提供分步引导、提示高亮、进度追踪
-- ============================================================================

local TutorialManager = {}

-- ============================================================================
-- 教程步骤定义
-- ============================================================================

TutorialManager.StepType = {
    HIGHLIGHT    = "highlight",   -- 高亮指定 UI 元素
    TOAST        = "toast",      -- 显示提示文字
    WAIT_CLICK   = "wait_click", -- 等待点击
    WAIT_EVENT   = "wait_event", -- 等待特定事件
    DELAY        = "delay",      -- 延迟
    CONDITION    = "condition", -- 条件判断
    END          = "end",        -- 教程结束
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
        content = "在开始之前，让我们先了解一下游戏的基本规则。",
        duration = 3,
    },
    {
        id = "intro_blind_auction",
        type = TutorialManager.StepType.TOAST,
        title = "暗拍机制",
        content = "本游戏的核心理念是「暗拍」—— 你看不到对手的出价！只能通过各种线索来推断局势。",
        duration = 4,
    },
    {
        id = "intro_speed_win",
        type = TutorialManager.StepType.TOAST,
        title = "速胜机制",
        content = "如果你的出价远超对手，可以在第1-4轮提前锁定胜局！第1轮需200%碾压，第2轮160%，以此类推。",
        duration = 4,
    },

    -- ================================================================
    -- 第二章：角色选择
    -- ================================================================
    {
        id = "select_hall",
        type = TutorialManager.StepType.TOAST,
        title = "选择拍卖厅",
        content = "首先，选择一个拍卖厅。新手厅适合练手，高级厅有更多稀有藏品。",
        duration = 3,
        waitFor = "hall_select",
    },
    {
        id = "char_intro",
        type = TutorialManager.StepType.TOAST,
        title = "选择角色",
        content = "每位角色都有独特的主动技能和被动技能。仔细阅读技能描述，选择适合你风格的角色。",
        duration = 4,
    },
    {
        id = "skill_intro",
        type = TutorialManager.StepType.HIGHLIGHT,
        target = "skill_section",
        content = "这是你的技能区域。主动技能需要手动使用，被动技能自动生效。",
        duration = 5,
    },

    -- ================================================================
    -- 第三章：出价教学
    -- ================================================================
    {
        id = "bid_intro",
        type = TutorialManager.StepType.TOAST,
        title = "出价教学",
        content = "拖动滑块设置出价金额，然后点击「确认出价」提交。",
        duration = 3,
    },
    {
        id = "bid_wait",
        type = TutorialManager.StepType.HIGHLIGHT,
        target = "bid_slider",
        content = "现在轮到你出价了！记住，暗拍阶段对手看不到你的出价。",
        duration = 0,
        waitFor = "bid_submitted",
    },
    {
        id = "bid_result",
        type = TutorialManager.StepType.TOAST,
        title = "回合结算",
        content = "每轮结束后，你会收到模糊的排名提示：「领先」「接近」「落后」或「垫底」。",
        duration = 4,
    },
    {
        id = "hint_guide",
        type = TutorialManager.StepType.TOAST,
        title = "排名提示解读",
        content = "「领先」表示你是最高出价者；「接近」表示你在前两名；「落后」表示你在第三名左右。",
        duration = 4,
    },

    -- ================================================================
    -- 第四章：开箱揭示
    -- ================================================================
    {
        id = "reveal_intro",
        type = TutorialManager.StepType.TOAST,
        title = "开箱揭示",
        content = "竞拍结束后，获胜者将开箱展示藏品。藏品会逐件从迷雾中显现，稀有度越高越珍贵！",
        duration = 4,
    },
    {
        id = "rarity_guide",
        type = TutorialManager.StepType.TOAST,
        title = "稀有度说明",
        content = "普通(灰) → 稀有(蓝) → 史诗(紫) → 传说(金)。传说藏品极为罕见！",
        duration = 3,
    },

    -- ================================================================
    -- 第五章：经济循环
    -- ================================================================
    {
        id = "economy_intro",
        type = TutorialManager.StepType.TOAST,
        title = "经济循环",
        content = "赢得藏品后可以在收藏馆出售，获得的金币可用于下一场竞拍。合理分配资金是获胜的关键！",
        duration = 4,
    },

    -- ================================================================
    -- 完成
    -- ================================================================
    {
        id = "tutorial_complete",
        type = TutorialManager.StepType.TOAST,
        title = "教程完成！",
        content = "你已经掌握了基本规则。现在开始你的盲拍之旅吧！祝你好运！",
        duration = 4,
        markComplete = true,
    },
}

-- 教程状态
TutorialManager.state = {
    active       = false,           -- 教程是否进行中
    currentStep  = 0,               -- 当前步骤索引
    completed    = {},              -- 已完成的步骤 id 集合
    skipped      = false,           -- 是否被跳过
    paused       = false,           -- 是否暂停
}

-- 外部回调
TutorialManager.onStepStart = nil  -- function(step)
TutorialManager.onStepEnd   = nil  -- function(step)
TutorialManager.onComplete  = nil  -- function()
TutorialManager.onSkip      = nil  -- function()

-- ============================================================================
-- 教程控制
-- ============================================================================

--- 开始新手教程
---@param startStepId string|nil 从指定步骤开始
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

--- 跳过教程
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

--- 暂停教程
function TutorialManager.Pause()
    TutorialManager.state.paused = true
    print("[TutorialManager] Tutorial paused")
end

--- 恢复教程
function TutorialManager.Resume()
    TutorialManager.state.paused = false
    print("[TutorialManager] Tutorial resumed")
end

--- 重置教程进度
function TutorialManager.Reset()
    TutorialManager.state = {
        active = false,
        currentStep = 0,
        completed = {},
        skipped = false,
        paused = false,
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
---@param elementId string 点击的元素 ID
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

--- 进入下一步
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

--- 结束当前步骤
function TutorialManager._EndStep()
    local step = TutorialManager.Steps[TutorialManager.state.currentStep]

    if TutorialManager.onStepEnd then
        TutorialManager.onStepEnd(step)
    end

    TutorialManager._ClearHighlight()
    TutorialManager._NextStep()
end

--- 执行步骤内容
---@param step table
function TutorialManager._ExecuteStep(step)
    if step.type == TutorialManager.StepType.TOAST then
        TutorialManager._ShowToast(step)

    elseif step.type == TutorialManager.StepType.HIGHLIGHT then
        TutorialManager._ShowHighlight(step)

    elseif step.type == TutorialManager.StepType.WAIT_CLICK then
        TutorialManager._ShowHighlight(step)
        -- 等待点击，不自动前进

    elseif step.type == TutorialManager.StepType.WAIT_EVENT then
        TutorialManager._ShowToast(step)
        -- 等待事件，不自动前进

    elseif step.type == TutorialManager.StepType.DELAY then
        TutorialManager._ShowToast(step)
        Helper.DelayFrames(step.frames or 60, function()
            TutorialManager._EndStep()
        end)

    elseif step.type == TutorialManager.StepType.CONDITION then
        -- 条件判断，暂时跳过
        TutorialManager._NextStep()

    elseif step.type == TutorialManager.StepType.END then
        TutorialManager._Complete()
    end
end

--- 显示提示
---@param step table
function TutorialManager._ShowToast(step)
    -- 实际的 UI 显示由 GameUI 处理
    -- 这里只记录日志
    print(string.format("[Tutorial] [%s] %s: %s",
        step.title or "", step.content or ""))
end

--- 显示高亮
---@param step table
function TutorialManager._ShowHighlight(step)
    -- 高亮指定的 UI 元素
    -- 实际的 UI 处理由 GameUI 执行
    if step.target then
        print("[TutorialManager] Highlighting: " .. step.target)
    end
    if step.content then
        TutorialManager._ShowToast(step)
    end
end

--- 清除高亮
function TutorialManager._ClearHighlight()
    print("[TutorialManager] Clearing highlight")
end

--- 教程完成
function TutorialManager._Complete()
    TutorialManager.state.active = false

    -- 标记教程完成
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

--- 是否正在教程中
---@return boolean
function TutorialManager.IsActive()
    return TutorialManager.state.active
end

--- 是否已完成教程
---@return boolean
function TutorialManager.IsCompleted()
    return TutorialManager.state.completed["tutorial_complete"] == true
end

--- 是否跳过了教程
---@return boolean
function TutorialManager.IsSkipped()
    return TutorialManager.state.skipped
end

--- 获取当前步骤
---@return table|nil
function TutorialManager.GetCurrentStep()
    return TutorialManager.Steps[TutorialManager.state.currentStep + 1]
end

--- 获取教程进度
---@return number current, number total
function TutorialManager.GetProgress()
    return TutorialManager.state.currentStep, #TutorialManager.Steps
end

return TutorialManager
