-- ============================================================================
-- GameUI.lua - 《盲拍暗战》客户端 UI 统一入口 (Phase 3)
-- 基于 urhox-libs/UI 组件库（Yoga Flexbox + NanoVG）
-- 由 Client.onStateChanged 驱动，响应式更新
-- Phase 2: 角色选择面板、技能按钮、被动通知、分类显示
-- Phase 3: 大厅选择、余额 HUD、奖励/出售/表情通知
-- ============================================================================

local UI     = require("urhox-libs/UI")
local Config = require("Config")
local Helper = require("Utils.Helper")
local UIUtils = require("Utils.UIUtils")
local CharacterData = require("Data.CharacterData")

local GameUI = {}

-- ============================================================================
-- 模块引用（由 Init 时传入）
-- ============================================================================

local client_ = nil  -- Client 模块引用（用于发送出价等操作）

-- ============================================================================
-- UI 控件引用
-- ============================================================================

-- 顶部 HUD
local hudPanel_ = nil
local roundLabel_ = nil

local timerLabel_ = nil
local stateLabel_ = nil
local charNameLabel_ = nil       -- Phase 2: 显示当前角色名
local balanceLabel_ = nil        -- Phase 3: 持久化账户余额

-- Phase 3: 大厅选择
local hallSelectPanel_ = nil
local hallCardButtons_ = {}      -- 大厅卡片按钮引用 { [hallId] = panelRef }
local selectedHallCard_ = nil    -- 当前选中的卡片引用

-- Phase 3: 表情快捷栏
local emoteBarPanel_ = nil
local emoteBarVisible_ = false

-- Phase 3: 收藏馆面板
local collectionPanel_ = nil
local collectionListPanel_ = nil
local collectionStatLabel_ = nil

-- Phase 3: 通知 toast（浮动在底部被动通知上方）
local toastPanel_ = nil
local toastLabel_ = nil
local toastClearTimer_ = 0

-- 等候大厅
local lobbyPanel_ = nil
local lobbyCountLabel_ = nil

-- Phase 2: 角色选择面板
local charSelectPanel_ = nil
local charGridPanel_ = nil
local charSelectTimerLabel_ = nil
local charSelectHintLabel_ = nil

-- 角色预选面板（匹配前本地选角）
local charPreSelectPanel_ = nil
local charPreSelectGrid_ = nil
local pendingCharId_ = nil       -- 预选的角色 id（匹配后自动提交）
local pendingCharName_ = nil     -- 预选的角色名

-- 出价面板
local bidPanel_ = nil
local bidTitleLabel_ = nil
local bidAmountLabel_ = nil
local bidSlider_ = nil
local bidConfirmBtn_ = nil
local bidHintLabel_ = nil
local currentBidAmount_ = 0

-- 右侧拍品列表
local itemListPanel_ = nil
local itemCards_ = {}     -- { panel, roundLabel, statusLabel } per round

-- Phase 2: 技能区域（嵌入出价面板底部）
local skillSection_ = nil
local skillNameLabel_ = nil
local skillStatusLabel_ = nil
local skillUseBtn_ = nil
local skillResultLabel_ = nil
local targetSection_ = nil    -- 目标选择面板（仅需要目标的技能可见）

-- 结果面板
local resultPanel_ = nil
local resultRankLabel_ = nil
local resultHintLabel_ = nil

-- 速胜/游戏结束覆盖
local overlayPanel_ = nil
local overlayTitleLabel_ = nil
local overlaySubLabel_ = nil

-- 开箱揭示
local revealPanel_ = nil
local revealItemsContainer_ = nil
local revealTotalLabel_ = nil

-- Phase 2: 被动通知 (浮动在底部)
local passivePanel_ = nil
local passiveLabel_ = nil
local passiveClearTimer_ = 0

-- 根容器
local root_ = nil

-- ============================================================================
-- 颜色工具
-- ============================================================================

local C = Config.Colors

local function rgba(colorTable, alpha)
    return { colorTable[1], colorTable[2], colorTable[3], alpha or 255 }
end

local function rarityColor(rarityIdx)
    local r = Config.Rarity[rarityIdx]
    if r then
        return rgba(r.color)
    end
    return rgba(C.TextSecondary)
end

local function rarityName(rarityIdx)
    local r = Config.Rarity[rarityIdx]
    if r then return r.name end
    return "未知"
end

-- ============================================================================
-- 初始化
-- ============================================================================

--- 初始化 UI 系统
---@param clientModule table Client 模块引用
function GameUI.Init(clientModule)
    client_ = clientModule

    -- 初始化 UI 库
    UI.Init({
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } }
        },
        scale = UI.Scale.DEFAULT,
    })

    -- 构建所有 UI
    GameUI._BuildUI()

    -- 设置根
    UI.SetRoot(root_)

    -- 绑定 Client 状态回调
    client_.onStateChanged = function(key, state)
        GameUI._OnStateChanged(key, state)
    end

    -- 初始显示大厅
    GameUI._ShowLobby()

    print("[GameUI] Initialized (Phase 3)")
end

-- ============================================================================
-- 构建 UI 树
-- ============================================================================

function GameUI._BuildUI()
    -- ====== 顶部 HUD ======
    roundLabel_ = UI.Label {
        text = "等待中",
        fontSize = 13,
        fontColor = rgba(C.TextSecondary),
        fontWeight = "bold",
    }
    timerLabel_ = UI.Label {
        text = "",
        fontSize = 18,
        fontColor = rgba(C.Danger),
        fontWeight = "bold",
    }
    stateLabel_ = UI.Label {
        text = "等待玩家加入...",
        fontSize = 11,
        fontColor = rgba(C.TextSecondary),
        textAlign = "center",
    }
    charNameLabel_ = UI.Label {
        text = "",
        fontSize = 11,
        fontColor = rgba(C.Secondary),
        textAlign = "center",
    }
    balanceLabel_ = UI.Label {
        text = "余额: --",
        fontSize = 11,
        fontColor = rgba(C.Success),
    }

    hudPanel_ = UI.Panel {
        width = "100%",
        backgroundColor = rgba(C.Surface, 230),
        padding = { 12, 16 },
        gap = 4,
        children = {
            -- 顶行：回合 + 计时 + 余额
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                children = { roundLabel_ },
            },
            -- 第二行：角色名 + 余额
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                children = { charNameLabel_, balanceLabel_ },
            },
            -- 底行：状态
            stateLabel_,
        },
    }

    -- ====== 等候大厅 ======
    GameUI._BuildLobbyPanel()

    -- ====== 角色选择面板 (Phase 2) ======
    GameUI._BuildCharSelectPanel()

    -- ====== 角色预选面板（匹配前本地选角） ======
    GameUI._BuildCharPreSelectPanel()

    -- ====== 表情快捷栏 (Phase 3，需在出价面板之前构建) ======
    GameUI._BuildEmoteBar()

    -- ====== 出价面板 ======
    GameUI._BuildBidPanel()

    -- ====== 结果面板 ======
    GameUI._BuildResultPanel()

    -- ====== 速胜/结束覆盖 ======
    GameUI._BuildOverlayPanel()

    -- ====== 开箱揭示 ======
    GameUI._BuildRevealPanel()

    -- ====== 大厅选择面板 (Phase 3) ======
    GameUI._BuildHallSelectPanel()

    -- ====== 收藏馆面板 (Phase 3) ======
    GameUI._BuildCollectionPanel()

    -- ====== 通知 toast (Phase 3) ======
    GameUI._BuildToastPanel()

    -- ====== 被动通知 (Phase 2) ======
    passiveLabel_ = UI.Label {
        text = "",
        fontSize = 11,
        fontColor = rgba(C.Secondary),
        textAlign = "center",
    }
    passivePanel_ = UI.Panel {
        width = "100%",
        padding = { 6, 12 },
        backgroundColor = rgba(C.Surface, 200),
        alignItems = "center",
        children = { passiveLabel_ },
    }

    -- ====== 组装根容器 ======
    root_ = UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = rgba(C.Background),
        children = {
            hudPanel_,
            -- 内容区域（这些面板互斥显示）
            lobbyPanel_,
            charPreSelectPanel_,
            charSelectPanel_,
            hallSelectPanel_,
            collectionPanel_,
            bidPanel_,
            resultPanel_,
            overlayPanel_,
            revealPanel_,
            -- 底部通知区
            toastPanel_,
            passivePanel_,
        },
    }

    -- 初始隐藏所有内容面板
    charPreSelectPanel_:Hide()
    charSelectPanel_:Hide()
    hallSelectPanel_:Hide()
    collectionPanel_:Hide()
    bidPanel_:Hide()
    resultPanel_:Hide()
    overlayPanel_:Hide()
    revealPanel_:Hide()
    toastPanel_:Hide()
    passivePanel_:Hide()
end

-- ====== 大厅面板 ======

-- 大厅额外引用
local lobbySeatDots_ = {}        -- 座位指示圆点 [1..4]
local lobbyBalanceLabel_ = nil   -- 余额显示
local lobbyNameLabel_ = nil      -- 玩家名字

function GameUI._BuildLobbyPanel()
    -- ── 中部：珍宝展柜（展示最贵重藏品） ──
    showcaseCountLabel_ = UI.Label {
        text = "暂无藏品",
        fontSize = 9, fontColor = rgba(C.TextSecondary, 160),
    }
    showcaseListPanel_ = UI.Panel {
        width = "100%", gap = 4,
    }
    -- 空状态提示
    showcaseEmptyLabel_ = UI.Label {
        text = "赢得拍卖，珍品将在此展出",
        fontSize = 11, fontColor = rgba(C.TextSecondary, 120),
        textAlign = "center",
        padding = { 16, 0 },
    }
    showcaseListPanel_:AddChild(showcaseEmptyLabel_)

    -- ── 顶部：玩家信息卡 ──
    lobbyNameLabel_ = UI.Label {
        text = "竞拍者",
        fontSize = 14,
        fontColor = rgba(C.TextPrimary),
        fontWeight = "bold",
    }
    lobbyBalanceLabel_ = UI.Label {
        text = "💰 " .. Helper.FormatMoney(Config.Economy.InitialBalance),
        fontSize = 12,
        fontColor = rgba(C.Accent),
    }
    local playerInfoCard = UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        padding = { 10, 14 },
        gap = 10,
        backgroundColor = rgba(C.Surface, 200),
        borderRadius = 10,
        children = {
            -- 头像占位
            UI.Panel {
                width = 40, height = 40,
                borderRadius = 20,
                backgroundColor = rgba(C.Primary, 80),
                justifyContent = "center", alignItems = "center",
                children = {
                    UI.Label { text = "👤", fontSize = 20, textAlign = "center" },
                },
            },
            -- 名字 + 余额
            UI.Panel {
                flexGrow = 1, gap = 2,
                children = {
                    lobbyNameLabel_,
                    lobbyBalanceLabel_,
                },
            },
            -- 货币图标
            UI.Panel {
                flexDirection = "row", gap = 6, alignItems = "center",
                children = {
                    UI.Label { text = "🪙", fontSize = 14 },
                    UI.Label {
                        text = Helper.FormatMoney(Config.Economy.InitialBalance),
                        fontSize = 12, fontColor = rgba(C.Accent), fontWeight = "bold",
                    },
                },
            },
        },
    }

    -- ── 中部：珍宝展柜（展示最贵重藏品） ──
    local showcaseFrame = UI.Panel {
        width = "100%",
        backgroundColor = rgba({15, 20, 30}, 230),
        borderRadius = 10,
        borderWidth = 1,
        borderColor = rgba(C.Primary, 50),
        padding = { 6, 8 },
        gap = 4,
        children = {
            -- 标题行
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                children = {
                    UI.Label {
                        text = "🏆 珍宝展柜",
                        fontSize = 12, fontColor = rgba(C.Accent, 200),
                        fontWeight = "bold",
                    },
                    showcaseCountLabel_,
                },
            },
            showcaseListPanel_,
        },
    }

    -- ── 模式标签 ──
    local modeSection = UI.Panel {
        width = "100%",
        flexDirection = "row",
        gap = 8,
        justifyContent = "center",
        alignItems = "center",
        padding = { 6, 0 },
        children = {
            UI.Panel {
                paddingHorizontal = 14, paddingVertical = 6,
                backgroundColor = rgba(C.Accent, 40),
                borderRadius = 6,
                borderWidth = 1, borderColor = rgba(C.Accent, 100),
                children = {
                    UI.Label {
                        text = "CLASSIC · MODE",
                        fontSize = 11, fontColor = rgba(C.Accent),
                        fontWeight = "bold", textAlign = "center",
                    },
                },
            },
            UI.Panel {
                paddingHorizontal = 14, paddingVertical = 6,
                backgroundColor = rgba(C.Surface, 120),
                borderRadius = 6,
                borderWidth = 1, borderColor = rgba(C.TextSecondary, 40),
                children = {
                    UI.Label {
                        text = "盲拍 · 暗战",
                        fontSize = 11, fontColor = rgba(C.TextSecondary),
                        textAlign = "center",
                    },
                },
            },
        },
    }

    -- ── 玩家状态：座位指示器 ──
    lobbySeatDots_ = {}
    local seatChildren = {}
    for i = 1, Config.Auction.MaxPlayers do
        local dot = UI.Panel {
            width = 28, height = 28,
            borderRadius = 14,
            backgroundColor = rgba(C.Surface, 180),
            borderWidth = 1.5,
            borderColor = rgba(C.TextSecondary, 60),
            justifyContent = "center", alignItems = "center",
            children = {
                UI.Label {
                    text = tostring(i),
                    fontSize = 11, fontColor = rgba(C.TextSecondary, 120),
                    textAlign = "center",
                },
            },
        }
        lobbySeatDots_[i] = dot
        seatChildren[#seatChildren + 1] = dot
    end

    lobbyCountLabel_ = UI.Label {
        text = "0/4 在线",
        fontSize = 11,
        fontColor = rgba(C.TextSecondary),
    }

    local seatSection = UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = "center",
        alignItems = "center",
        gap = 10,
        padding = { 4, 0 },
        children = {
            UI.Label { text = "竞拍席", fontSize = 11, fontColor = rgba(C.TextSecondary),
                fontWeight = "bold" },
            table.unpack(seatChildren),
        },
    }

    -- ── 底部导航栏 ──
    local navBar = UI.Panel {
        width = "100%",
        flexDirection = "row",
        flexWrap = "wrap",
        gap = 6,
        children = {
            UI.Button {
                text = "🏛️ 收藏馆",
                fontSize = 11,
                variant = "ghost",
                flexGrow = 1,
                height = 36,
                onClick = function()
                    GameUI._ShowCollection()
                end,
            },
            UI.Button {
                text = "🏆 锦标赛",
                fontSize = 11,
                variant = "ghost",
                flexGrow = 1,
                height = 36,
                onClick = function()
                    GameUI._ShowTournament()
                end,
            },
            UI.Button {
                text = "👥 团队战",
                fontSize = 11,
                variant = "ghost",
                flexGrow = 1,
                height = 36,
                onClick = function()
                    GameUI._ShowTeamBattle()
                end,
            },
            UI.Button {
                text = "🛒 市场",
                fontSize = 11,
                variant = "ghost",
                flexGrow = 1,
                height = 36,
                onClick = function()
                    GameUI._ShowTradeMarket()
                end,
            },
            UI.Button {
                text = "🎨 皮肤",
                fontSize = 11,
                variant = "ghost",
                flexGrow = 1,
                height = 36,
                onClick = function()
                    GameUI._ShowSkinShop()
                end,
            },
        },
    }

    -- ── 竞拍按钮（醒目大按钮） ──
    local auctionBtn = UI.Button {
        text = "竞 拍  ➡",
        fontSize = 18,
        fontWeight = "bold",
        variant = "primary",
        width = "100%",
        height = 50,
        borderRadius = 10,
        backgroundColor = rgba(C.Accent),
        onClick = function()
            GameUI._ShowCharPreSelect()
        end,
    }

    -- ── 组装大厅面板 ──
    lobbyPanel_ = UI.Panel {
        width = "100%",
        flexGrow = 1,
        padding = { 10, 14 },
        gap = 8,
        children = {
            playerInfoCard,
            showcaseFrame,
            modeSection,
            seatSection,
            lobbyCountLabel_,
            -- 弹性空间
            UI.Panel { flexGrow = 1 },
            navBar,
            auctionBtn,
        },
    }
end

-- ====== 角色选择面板 (Phase 2) ======
function GameUI._BuildCharSelectPanel()
    charSelectTimerLabel_ = UI.Label {
        text = "15s",
        fontSize = 22,
        fontColor = rgba(C.Danger),
        fontWeight = "bold",
        textAlign = "center",
    }
    charSelectHintLabel_ = UI.Label {
        text = "点击角色卡片选择你的角色",
        fontSize = 12,
        fontColor = rgba(C.TextSecondary),
        textAlign = "center",
    }
    charGridPanel_ = UI.Panel {
        width = "100%",
        flexDirection = "row",
        flexWrap = "wrap",
        justifyContent = "center",
        gap = 8,
        padding = { 4, 8 },
    }
    charSelectPanel_ = UI.Panel {
        width = "100%",
        flexGrow = 1,
        alignItems = "center",
        gap = 10,
        padding = { 12, 8 },
        children = {
            UI.Label {
                text = "选择角色",
                fontSize = 20,
                fontColor = rgba(C.Accent),
                fontWeight = "bold",
                textAlign = "center",
            },
            charSelectTimerLabel_,
            UI.Divider { color = rgba(C.Primary, 40), spacing = 4 },
            charGridPanel_,
            charSelectHintLabel_,
        },
    }
end

-- ====== 角色预选面板（匹配前本地选角） ======
function GameUI._BuildCharPreSelectPanel()
    charPreSelectGrid_ = UI.Panel {
        width = "100%",
        flexDirection = "row",
        flexWrap = "wrap",
        justifyContent = "center",
        gap = 8,
        padding = { 4, 8 },
    }

    -- 用 CharacterData 本地数据填充卡片
    GameUI._RebuildPreSelectCards()

    charPreSelectPanel_ = UI.Panel {
        width = "100%",
        flexGrow = 1,
        alignItems = "center",
        gap = 10,
        padding = { 12, 8 },
        children = {
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                children = {
                    UI.Label {
                        text = "选择角色",
                        fontSize = 20,
                        fontColor = rgba(C.Accent),
                        fontWeight = "bold",
                    },
                    UI.Button {
                        text = "✕",
                        fontSize = 16,
                        variant = "ghost",
                        width = 32, height = 32,
                        onClick = function()
                            GameUI._ShowLobby()
                        end,
                    },
                },
            },
            UI.Divider { color = rgba(C.Primary, 40), spacing = 4 },
            UI.Label {
                text = "选择你的角色后将进入场地选择",
                fontSize = 12,
                fontColor = rgba(C.TextSecondary),
                textAlign = "center",
            },
            charPreSelectGrid_,
        },
    }
end

--- 构建预选角色卡片（本地数据，无占用逻辑）
function GameUI._RebuildPreSelectCards()
    if not charPreSelectGrid_ then return end
    charPreSelectGrid_:ClearChildren()

    for _, c in ipairs(CharacterData.Characters) do
        local charId = c.id
        local isMyPick = (charId == pendingCharId_)

        local cardBg = isMyPick and rgba(C.Primary, 60) or rgba(C.Surface)
        local borderCol = isMyPick and rgba(C.Accent) or rgba(C.Primary, 80)

        -- 技能简述
        local skillDesc = c.activeSkill and c.activeSkill.name or ""
        local passiveDesc = c.passiveSkill and c.passiveSkill.name or ""

        local card = UI.Panel {
            width = "46%",
            padding = 10,
            gap = 4,
            backgroundColor = cardBg,
            borderRadius = 10,
            borderWidth = 2,
            borderColor = borderCol,
            cursor = "pointer",
            onClick = function()
                pendingCharId_ = charId
                pendingCharName_ = c.name
                -- 刷新卡片高亮
                GameUI._RebuildPreSelectCards()
                -- 选角后进入大厅选择
                GameUI._ShowHallSelect()
            end,
            children = {
                UI.Label {
                    text = c.name,
                    fontSize = 15,
                    fontColor = rgba(C.TextPrimary),
                    fontWeight = "bold",
                },
                UI.Label {
                    text = c.title or "",
                    fontSize = 9,
                    fontColor = rgba(C.TextSecondary),
                },
                UI.Divider { color = rgba(C.Primary, 30), spacing = 2 },
                UI.Label {
                    text = "主动: " .. skillDesc,
                    fontSize = 10,
                    fontColor = rgba(C.Secondary),
                },
                UI.Label {
                    text = "被动: " .. passiveDesc,
                    fontSize = 10,
                    fontColor = rgba(C.TextSecondary, 180),
                },
                isMyPick and UI.Label {
                    text = "已选",
                    fontSize = 10,
                    fontColor = rgba(C.Success),
                    fontWeight = "bold",
                    textAlign = "center",
                } or nil,
            },
        }

        charPreSelectGrid_:AddChild(card)
    end
end

-- ====== 出价面板 (参考布局: 左侧拍品信息+技能 | 右侧战利品网格 | 底部出价栏) ======
function GameUI._BuildBidPanel()
    -- ── 顶部轮次标题 ──
    bidTitleLabel_ = UI.Label {
        text = "第 1 轮",
        fontSize = 16,
        fontColor = rgba(C.TextPrimary),
        fontWeight = "bold",
        textAlign = "center",
    }

    -- ── 左侧: 拍卖物品列表 ──
    auctionItemsContainer_ = UI.Panel {
        width = "100%", gap = 4,
    }
    auctionTotalLabel_ = UI.Label {
        text = "",
        fontSize = 11,
        fontColor = rgba(C.Accent),
        fontWeight = "bold",
        textAlign = "center",
    }
    local auctionItemsCard = UI.Panel {
        width = "100%",
        padding = { 8, 10 },
        borderRadius = 8,
        backgroundColor = rgba(C.Surface, 160),
        borderWidth = 1,
        borderColor = rgba(C.Primary, 50),
        gap = 6,
        children = {
            -- 标题
            UI.Panel {
                width = "100%", flexDirection = "row", alignItems = "center", gap = 6,
                children = {
                    UI.Label { text = "🏺", fontSize = 16 },
                    UI.Label {
                        text = "本局拍品",
                        fontSize = 13,
                        fontColor = rgba(C.Accent),
                        fontWeight = "bold",
                    },
                },
            },
            -- 物品列表容器
            auctionItemsContainer_,
        },
    }

    -- ── 左侧: 技能列表 ──
    -- 主动技能卡片
    skillNameLabel_ = UI.Label { text = "", fontSize = 12, fontColor = rgba(C.TextPrimary), fontWeight = "bold" }
    local skillDescLabel_ = UI.Label { text = "", fontSize = 10, fontColor = rgba(C.TextSecondary), whiteSpace = "normal", flexShrink = 1 }
    skillStatusLabel_ = UI.Label { text = "", fontSize = 9, fontColor = rgba(C.TextSecondary) }
    skillResultLabel_ = UI.Label { text = "", fontSize = 10, fontColor = rgba(C.Accent), whiteSpace = "normal" }
    skillUseBtn_ = UI.Button {
        text = "使用",
        variant = "primary",
        width = 52, height = 28, fontSize = 11,
        onClick = function(self) GameUI._OnSkillBtnClick() end,
    }
    targetSection_ = UI.Panel {
        width = "100%", flexDirection = "row", justifyContent = "center", gap = 6, flexWrap = "wrap",
    }

    -- 主动技能行: 图标 + 名称描述 + 按钮
    local activeSkillCard = UI.Panel {
        width = "100%",
        padding = { 8, 10 },
        borderRadius = 8,
        backgroundColor = rgba(C.Surface, 140),
        borderWidth = 1,
        borderColor = rgba(C.Secondary, 50),
        gap = 4,
        children = {
            -- 顶行: 图标+名称+状态+按钮
            UI.Panel {
                width = "100%", flexDirection = "row", alignItems = "center", gap = 8,
                children = {
                    -- 技能图标圆圈
                    UI.Panel {
                        width = 30, height = 30, borderRadius = 15,
                        backgroundColor = rgba(C.Secondary, 60),
                        justifyContent = "center", alignItems = "center",
                        children = { UI.Label { text = "⚔️", fontSize = 14 } },
                    },
                    -- 名称+状态
                    UI.Panel {
                        flexGrow = 1, flexShrink = 1, gap = 1,
                        children = { skillNameLabel_, skillStatusLabel_ },
                    },
                    skillUseBtn_,
                },
            },
            -- 描述
            skillDescLabel_,
            -- 目标选择
            targetSection_,
            -- 结果
            skillResultLabel_,
        },
    }
    -- 保存 skillDescLabel_ 引用以便动态更新
    GameUI._skillDescLabel = skillDescLabel_

    -- 被动技能行
    local passiveIconLabel = UI.Label { text = "🛡️", fontSize = 14 }
    local passiveNameLabel = UI.Label { text = "", fontSize = 12, fontColor = rgba(C.TextPrimary), fontWeight = "bold" }
    local passiveDescLabel = UI.Label { text = "", fontSize = 10, fontColor = rgba(C.TextSecondary), whiteSpace = "normal", flexShrink = 1 }
    GameUI._passiveNameLabel = passiveNameLabel
    GameUI._passiveDescLabel = passiveDescLabel

    local passiveSkillCard = UI.Panel {
        width = "100%",
        padding = { 8, 10 },
        borderRadius = 8,
        backgroundColor = rgba(C.Surface, 100),
        borderWidth = 1,
        borderColor = rgba(C.Surface, 80),
        flexDirection = "row",
        alignItems = "center",
        gap = 8,
        children = {
            UI.Panel {
                width = 30, height = 30, borderRadius = 15,
                backgroundColor = rgba(C.Primary, 40),
                justifyContent = "center", alignItems = "center",
                children = { passiveIconLabel },
            },
            UI.Panel {
                flexGrow = 1, flexShrink = 1, gap = 1,
                children = { passiveNameLabel, passiveDescLabel },
            },
            UI.Label { text = "被动", fontSize = 9, fontColor = rgba(C.TextSecondary, 160) },
        },
    }

    -- 合并为 skillSection_（用于 Show/Hide 控制）
    skillSection_ = UI.Panel {
        width = "100%", gap = 6,
        children = {
            UI.Label { text = "🎯 技能", fontSize = 12, fontColor = rgba(C.TextSecondary), fontWeight = "bold" },
            activeSkillCard,
            passiveSkillCard,
        },
    }

    -- 左列整体
    local leftColumn = UI.Panel {
        flexGrow = 1, flexShrink = 1,
        gap = 8,
        padding = { 0, 6, 0, 2 },
        overflow = "scroll",
        children = {
            auctionItemsCard,
            skillSection_,
            emoteBarPanel_,
        },
    }

    -- ── 右侧: 战利品列表（动态填充） ──
    itemCards_ = {}
    itemGridContainer_ = UI.Panel {
        width = "100%",
        flexDirection = "row",
        flexWrap = "wrap",
        gap = 3,
    }

    itemListPanel_ = UI.Panel {
        width = 150,
        gap = 6,
        padding = { 8, 6 },
        backgroundColor = rgba(C.Surface, 50),
        borderRadius = 8,
        borderWidth = 1,
        borderColor = rgba(C.Primary, 30),
        children = {
            -- 标题行
            UI.Panel {
                width = "100%", flexDirection = "row", justifyContent = "center", alignItems = "center", gap = 4,
                children = {
                    UI.Label { text = "🏆", fontSize = 12 },
                    UI.Label { text = "战利品", fontSize = 13, fontColor = rgba(C.Accent), fontWeight = "bold" },
                },
            },
            -- 列表（动态填充）
            itemGridContainer_,
        },
    }

    -- ── 中间内容区: 左列 + 右列 ──
    local contentRow = UI.Panel {
        width = "100%",
        flexGrow = 1,
        flexShrink = 1,
        flexDirection = "row",
        gap = 6,
        overflow = "hidden",
        children = { leftColumn, itemListPanel_ },
    }

    -- ── 底部出价栏 ──
    bidAmountLabel_ = UI.Label {
        text = "0",
        fontSize = 22,
        fontColor = rgba(C.Accent),
        fontWeight = "bold",
        textAlign = "center",
    }
    bidHintLabel_ = UI.Label {
        text = "拖动滑块设置出价",
        fontSize = 9,
        fontColor = rgba(C.TextSecondary),
        textAlign = "center",
    }
    bidSlider_ = UI.Slider {
        width = "100%",
        value = 0, min = 0, max = 100, step = 100,
        onChange = function(self, val)
            currentBidAmount_ = math.floor(val)
            bidAmountLabel_.text = Helper.FormatMoney(currentBidAmount_)
        end,
    }
    bidConfirmBtn_ = UI.Button {
        text = "出价",
        variant = "primary",
        width = 80, height = 38, fontSize = 14,
        onClick = function(self)
            if client_ and currentBidAmount_ > 0 then
                client_.SendBid(currentBidAmount_)
                bidConfirmBtn_.disabled = true
                bidConfirmBtn_.text = "已出价"
                bidHintLabel_.text = "等待其他玩家..."
            end
        end,
    }

    local bidBar = UI.Panel {
        width = "100%",
        padding = { 8, 10 },
        backgroundColor = rgba(C.Surface, 200),
        borderRadius = 8,
        borderWidth = 1,
        borderColor = rgba(C.Primary, 40),
        gap = 4,
        alignItems = "center",
        children = {
            -- 金额 + 提示
            UI.Panel {
                width = "100%", flexDirection = "row", alignItems = "center", justifyContent = "center", gap = 8,
                children = {
                    UI.Label { text = "💰", fontSize = 16 },
                    bidAmountLabel_,
                },
            },
            -- 滑块行
            UI.Panel {
                width = "100%", padding = { 0, 4 },
                children = {
                    bidSlider_,
                    UI.Panel {
                        width = "100%", flexDirection = "row", justifyContent = "space-between",
                        children = {
                            UI.Label { text = "0", fontSize = 9, fontColor = rgba(C.TextSecondary) },
                            UI.Label { id = "maxBidLabel", text = "--", fontSize = 9, fontColor = rgba(C.TextSecondary) },
                        },
                    },
                },
            },
            -- 按钮行
            UI.Panel {
                width = "100%", flexDirection = "row", justifyContent = "center", gap = 10, alignItems = "center",
                children = { bidConfirmBtn_, bidHintLabel_ },
            },
        },
    }

    -- ── 最终组合 bidPanel_ ──
    -- 标题行：轮次 + 倒计时居中
    local bidTitleRow = UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = "center",
        alignItems = "center",
        gap = 10,
        children = {
            bidTitleLabel_,
            timerLabel_,
        },
    }

    bidPanel_ = UI.Panel {
        width = "100%",
        flexGrow = 1,
        gap = 6,
        padding = { 8, 6 },
        children = {
            bidTitleRow,
            contentRow,
            bidBar,
        },
    }
end

-- ====== 表情快捷栏 (Phase 3) ======
function GameUI._BuildEmoteBar()
    local emoteButtons = {}
    for _, emote in ipairs(Config.Emotes) do
        local btn = UI.Button {
            text = emote.text,
            variant = "outline",
            fontSize = 10,
            height = 30,
            flexGrow = 1,
            flexShrink = 1,
            onClick = function(self)
                if client_ then
                    client_.SendEmote(emote.id)
                end
            end,
        }
        table.insert(emoteButtons, btn)
    end

    local emoteGrid = UI.Panel {
        width = "100%",
        flexDirection = "row",
        flexWrap = "wrap",
        gap = 6,
        padding = { 8, 4 },
        children = emoteButtons,
    }
    emoteGrid:Hide()

    local toggleBtn = UI.Button {
        text = "💬 表情",
        variant = "text",
        fontSize = 11,
        height = 28,
        onClick = function(self)
            emoteBarVisible_ = not emoteBarVisible_
            if emoteBarVisible_ then
                emoteGrid:Show()
                self.text = "💬 收起"
            else
                emoteGrid:Hide()
                self.text = "💬 表情"
            end
        end,
    }

    emoteBarPanel_ = UI.Panel {
        width = "90%",
        alignItems = "center",
        gap = 4,
        children = { toggleBtn, emoteGrid },
    }
end

-- ====== 结果面板 ======
function GameUI._BuildResultPanel()
    resultRankLabel_ = UI.Label {
        text = "",
        fontSize = 32,
        fontColor = rgba(C.Accent),
        fontWeight = "bold",
        textAlign = "center",
    }
    resultHintLabel_ = UI.Label {
        text = "",
        fontSize = 16,
        fontColor = rgba(C.TextPrimary),
        textAlign = "center",
    }
    resultPanel_ = UI.Panel {
        width = "100%",
        flexGrow = 1,
        justifyContent = "center",
        alignItems = "center",
        gap = 16,
        padding = 24,
        children = {
            UI.Label {
                text = "回合结算",
                fontSize = 18,
                fontColor = rgba(C.TextSecondary),
            },
            resultRankLabel_,
            resultHintLabel_,
        },
    }
end

-- ====== 覆盖面板 ======
function GameUI._BuildOverlayPanel()
    overlayTitleLabel_ = UI.Label {
        text = "",
        fontSize = 28,
        fontColor = rgba(C.SpeedWin),
        fontWeight = "bold",
        textAlign = "center",
        textStroke = { width = 2, color = { 0, 0, 0, 120 } },
    }
    overlaySubLabel_ = UI.Label {
        text = "",
        fontSize = 14,
        fontColor = rgba(C.TextPrimary),
        textAlign = "center",
        whiteSpace = "normal",
    }
    overlayPanel_ = UI.Panel {
        width = "100%",
        flexGrow = 1,
        justifyContent = "center",
        alignItems = "center",
        gap = 20,
        padding = 32,
        backgroundColor = rgba(C.Background, 200),
        children = {
            overlayTitleLabel_,
            overlaySubLabel_,
        },
    }
end

-- ====== 揭示面板 ======
function GameUI._BuildRevealPanel()
    revealItemsContainer_ = UI.Panel {
        width = "100%",
        gap = 10,
        alignItems = "center",
    }
    revealTotalLabel_ = UI.Label {
        text = "",
        fontSize = 18,
        fontColor = rgba(C.Accent),
        fontWeight = "bold",
        textAlign = "center",
    }
    revealPanel_ = UI.Panel {
        width = "100%",
        flexGrow = 1,
        justifyContent = "center",
        alignItems = "center",
        gap = 16,
        padding = 24,
        children = {
            UI.Label {
                text = "开箱揭示",
                fontSize = 20,
                fontColor = rgba(C.SpeedWin),
                fontWeight = "bold",
                textAlign = "center",
            },
            UI.Divider { color = rgba(C.SpeedWin, 60), spacing = 6 },
            revealItemsContainer_,
            revealTotalLabel_,
        },
    }
end

-- ============================================================================
-- 面板切换（互斥显示）
-- ============================================================================

function GameUI._HideAllPanels()
    lobbyPanel_:Hide()
    charPreSelectPanel_:Hide()
    charSelectPanel_:Hide()
    hallSelectPanel_:Hide()
    collectionPanel_:Hide()
    bidPanel_:Hide()
    resultPanel_:Hide()
    overlayPanel_:Hide()
    revealPanel_:Hide()
end

function GameUI._ShowLobby()
    GameUI._HideAllPanels()
    lobbyPanel_:Show()
    stateLabel_.text = "等待玩家加入..."
    -- 清除预选角色（回到大厅后需要重新选）
    pendingCharId_ = nil
    pendingCharName_ = nil
end

function GameUI._ShowCharPreSelect()
    GameUI._HideAllPanels()
    charPreSelectPanel_:Show()
    stateLabel_.text = "选择角色..."
    -- 刷新卡片（可能之前选过）
    GameUI._RebuildPreSelectCards()
end

function GameUI._ShowHallSelect()
    GameUI._HideAllPanels()
    hallSelectPanel_:Show()
    stateLabel_.text = "选择拍卖厅..."
end

function GameUI._ShowCollection()
    GameUI._HideAllPanels()
    collectionPanel_:Show()
    stateLabel_.text = "我的收藏馆"
    -- 请求最新藏品数据
    if client_ then
        client_.GetCollection()
    end
end

-- ============================================================================
-- v1.1.0 新增：任务与赛季面板
-- ============================================================================

function GameUI._ShowMissions()
    -- 动态加载系统
    local DailyMission = safeRequire("Game.DailyMissionSystem")
    if not DailyMission then
        GameUI._ShowToast("系统加载中...", "WARNING")
        return
    end

    GameUI._HideAllPanels()

    -- 创建任务面板
    local panel = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = rgba({20, 20, 20}, 220),
        children = {
            -- 标题
            UI.Label {
                text = "📋 每日任务 & 周挑战",
                fontSize = 18, fontColor = rgba(C.TextPrimary),
                marginTop = 20, marginLeft = 20
            },
            -- 每日任务区域
            UI.Label {
                text = "── 每日任务 ──",
                fontSize = 12, fontColor = rgba(C.TextSecondary),
                marginTop = 10, marginLeft = 20
            },
            -- 周任务区域
            UI.Label {
                text = "── 周挑战任务 ──",
                fontSize = 12, fontColor = rgba(C.TextSecondary),
                marginTop = 10, marginLeft = 20
            },
            -- 返回按钮
            UI.Button {
                text = "🔙 返回",
                width = 100, height = 36,
                marginTop = 20, marginLeft = 20,
                onClick = function()
                    GameUI._ShowLobby()
                end
            }
        }
    }

    -- 缓存面板
    if not GameUI._missionsPanel then
        GameUI._missionsPanel = panel
        root_:AddChild(panel)
    else
        panel:Hide()
        GameUI._missionsPanel = panel
        root_:AddChild(panel)
    end

    panel:Show()
    stateLabel_.text = "任务中心"

    -- 获取任务数据
    local playerId = client_ and client_.playerId_ or "default"
    local dailyList = DailyMission.GetDailyMissionList(playerId)
    local weeklyList = DailyMission.GetWeeklyMissionList(playerId)

    GameUI._ShowToast(
        string.format("每日任务: %d/%d | 周任务: %d/%d",
            #dailyList, 4, #weeklyList, 3),
        "INFO"
    )
end

function GameUI._ShowSeason()
    local SeasonSystem = safeRequire("Game.SeasonSystem")
    if not SeasonSystem then
        GameUI._ShowToast("赛季系统加载中...", "WARNING")
        return
    end

    GameUI._HideAllPanels()

    -- 获取赛季状态
    local playerId = client_ and client_.playerId_ or "default"
    local status = SeasonSystem.GetPlayerStatus(playerId)
    local remaining = SeasonSystem.GetSeasonTimeRemaining()

    -- 创建赛季面板
    local panel = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = rgba({20, 20, 20}, 220),
        children = {
            -- 赛季标题
            UI.Label {
                text = "🏆 " .. (status and status.seasonName or "赛季"),
                fontSize = 20, fontColor = rgba(C.Accent),
                marginTop = 20, marginLeft = 20
            },
            -- 等级信息
            UI.Label {
                text = string.format("等级: %d / %d",
                    status and status.level or 1,
                    status and status.maxLevel or 50),
                fontSize = 14, fontColor = rgba(C.TextPrimary),
                marginTop = 10, marginLeft = 20
            },
            -- 进度条
            UI.Panel {
                width = 300, height = 16,
                backgroundColor = rgba({60, 60, 60}, 255),
                borderRadius = 8,
                marginTop = 8, marginLeft = 20,
                children = {
                    UI.Panel {
                        width = (status and status.progressPercent or 0) .. "%",
                        height = "100%",
                        backgroundColor = rgba(C.Accent, 200),
                        borderRadius = 8
                    }
                }
            },
            -- 剩余时间
            UI.Label {
                text = "⏰ 剩余: " .. SeasonSystem.FormatTimeRemaining(remaining),
                fontSize = 12, fontColor = rgba(C.TextSecondary),
                marginTop = 5, marginLeft = 20
            },
            -- 返回按钮
            UI.Button {
                text = "🔙 返回",
                width = 100, height = 36,
                marginTop = 20, marginLeft = 20,
                onClick = function()
                    GameUI._ShowLobby()
                end
            }
        }
    }

    if not GameUI._seasonPanel then
        GameUI._seasonPanel = panel
        root_:AddChild(panel)
    else
        panel:Hide()
        GameUI._seasonPanel = panel
        root_:AddChild(panel)
    end

    panel:Show()
    stateLabel_.text = "赛季中心"
end

function GameUI._ShowFriends()
    local FriendSystem = safeRequire("Game.FriendSystem")
    if not FriendSystem then
        GameUI._ShowToast("好友系统加载中...", "WARNING")
        return
    end

    GameUI._HideAllPanels()

    local playerId = client_ and client_.playerId_ or "default"
    local friends = FriendSystem.GetFriends(playerId)
    local onlineCount = FriendSystem.GetOnlineFriendCount(playerId)
    local totalCount = FriendSystem.GetFriendCount(playerId)

    -- 创建好友面板
    local panel = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = rgba({20, 20, 20}, 220),
        children = {
            -- 标题
            UI.Label {
                text = "👥 好友列表",
                fontSize = 18, fontColor = rgba(C.TextPrimary),
                marginTop = 20, marginLeft = 20
            },
            -- 在线状态
            UI.Label {
                text = string.format("在线: %d / %d", onlineCount, totalCount),
                fontSize = 12, fontColor = rgba({80, 200, 80}),
                marginTop = 5, marginLeft = 20
            },
            -- 好友列表区域
            UI.Label {
                text = "好友功能开发中...",
                fontSize = 12, fontColor = rgba(C.TextSecondary),
                marginTop = 20, marginLeft = 20
            },
            -- 返回按钮
            UI.Button {
                text = "🔙 返回",
                width = 100, height = 36,
                marginTop = 20, marginLeft = 20,
                onClick = function()
                    GameUI._ShowLobby()
                end
            }
        }
    }

    if not GameUI._friendsPanel then
        GameUI._friendsPanel = panel
        root_:AddChild(panel)
    else
        panel:Hide()
        GameUI._friendsPanel = panel
        root_:AddChild(panel)
    end

    panel:Show()
    stateLabel_.text = "好友中心"
end

function GameUI._ShowProfile()
    local ProfileSystem = safeRequire("Game.ProfileSystem")
    if not ProfileSystem then
        GameUI._ShowToast("个人中心加载中...", "WARNING")
        return
    end

    GameUI._HideAllPanels()

    local playerId = client_ and client_.playerId_ or "default"
    local profile = ProfileSystem.GetProfile(playerId)
    local avatars = ProfileSystem.GetAllAvatars(playerId)
    local titles = ProfileSystem.GetAllTitles(playerId)

    -- 创建个人面板
    local panel = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = rgba({20, 20, 20}, 220),
        children = {
            -- 标题
            UI.Label {
                text = "👤 个人中心",
                fontSize = 18, fontColor = rgba(C.TextPrimary),
                marginTop = 20, marginLeft = 20
            },
            -- 昵称
            UI.Label {
                text = "昵称: " .. (profile and profile.nickname or "未设置"),
                fontSize = 14, fontColor = rgba(C.TextPrimary),
                marginTop = 10, marginLeft = 20
            },
            -- 称号
            UI.Label {
                text = "称号: " .. (profile and profile.title and profile.title.name or "无"),
                fontSize = 12, fontColor = rgba(C.TextSecondary),
                marginTop = 5, marginLeft = 20
            },
            -- 头像数
            UI.Label {
                text = string.format("已解锁头像: %d / %d",
                    profile and profile.avatarCount or 1,
                    avatars and #avatars or 6),
                fontSize = 12, fontColor = rgba(C.TextSecondary),
                marginTop = 5, marginLeft = 20
            },
            -- 返回按钮
            UI.Button {
                text = "🔙 返回",
                width = 100, height = 36,
                marginTop = 20, marginLeft = 20,
                onClick = function()
                    GameUI._ShowLobby()
                end
            }
        }
    }

    if not GameUI._profilePanel then
        GameUI._profilePanel = panel
        root_:AddChild(panel)
    else
        panel:Hide()
        GameUI._profilePanel = panel
        root_:AddChild(panel)
    end

    panel:Show()
    stateLabel_.text = "个人中心"
end

-- ============================================================================
-- v1.2.0 新系统面板
-- ============================================================================

function GameUI._ShowTournament()
    local TournamentSystem = safeRequire("Game.TournamentSystem")
    if not TournamentSystem then
        GameUI._ShowToast("锦标赛系统加载中...", "WARNING")
        return
    end

    GameUI._HideAllPanels()

    local playerId = client_ and client_.playerId_ or "default"
    local available = TournamentSystem.GetAvailableTournaments(playerId)
    local history = TournamentSystem.GetPlayerHistory(playerId)

    -- 创建锦标赛面板
    local panel = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = rgba({20, 20, 20}, 220),
        children = {
            -- 标题
            UI.Label {
                text = "🏆 锦标赛",
                fontSize = 20, fontColor = rgba(C.Accent),
                fontWeight = "bold", marginTop = 20, marginLeft = 20
            },
            -- 可参加锦标赛数
            UI.Label {
                text = string.format("可参加: %d 场", #available),
                fontSize = 12, fontColor = rgba(C.TextSecondary),
                marginTop = 5, marginLeft = 20
            },
            -- 分割线
            UI.Divider { color = rgba(C.Primary, 40), spacing = 8, marginTop = 10 },
            -- 锦标赛列表
            UI.Label {
                text = "暂无正在报名的锦标赛",
                fontSize = 12, fontColor = rgba(C.TextSecondary),
                marginTop = 20, marginLeft = 20
            },
            -- 返回按钮
            UI.Button {
                text = "🔙 返回",
                width = 100, height = 36,
                marginTop = 20, marginLeft = 20,
                onClick = function()
                    GameUI._ShowHallSelect()
                end
            }
        }
    }

    if not GameUI._tournamentPanel then
        GameUI._tournamentPanel = panel
        root_:AddChild(panel)
    else
        GameUI._tournamentPanel:Hide()
        GameUI._tournamentPanel = panel
        root_:AddChild(panel)
    end

    panel:Show()
    stateLabel_.text = "锦标赛中心"
end

function GameUI._ShowTeamBattle()
    local TeamBattleSystem = safeRequire("Game.TeamBattleSystem")
    if not TeamBattleSystem then
        GameUI._ShowToast("团队战系统加载中...", "WARNING")
        return
    end

    GameUI._HideAllPanels()

    local playerId = client_ and client_.playerId_ or "default"
    local team = TeamBattleSystem.GetPlayerTeam(playerId)

    -- 创建团队战面板
    local panel = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = rgba({20, 20, 20}, 220),
        children = {
            -- 标题
            UI.Label {
                text = "👥 团队战",
                fontSize = 20, fontColor = rgba(C.Accent),
                fontWeight = "bold", marginTop = 20, marginLeft = 20
            },
            -- 团队状态
            UI.Label {
                text = team and ("团队: " .. team.name) or "未加入团队",
                fontSize = 14, fontColor = rgba(C.TextPrimary),
                marginTop = 5, marginLeft = 20
            },
            -- 分割线
            UI.Divider { color = rgba(C.Primary, 40), spacing = 8, marginTop = 10 },
            -- 团队信息
            UI.Label {
                text = "2v2 组队对战，与队友协作赢得比赛",
                fontSize = 12, fontColor = rgba(C.TextSecondary),
                marginTop = 20, marginLeft = 20
            },
            -- 团队技能说明
            UI.Label {
                text = "团队技能: 团队激励 / 团队护盾 / 团队洞察",
                fontSize = 11, fontColor = rgba(C.Secondary),
                marginTop = 5, marginLeft = 20
            },
            -- 返回按钮
            UI.Button {
                text = "🔙 返回",
                width = 100, height = 36,
                marginTop = 20, marginLeft = 20,
                onClick = function()
                    GameUI._ShowHallSelect()
                end
            }
        }
    }

    if not GameUI._teambattlePanel then
        GameUI._teambattlePanel = panel
        root_:AddChild(panel)
    else
        GameUI._teambattlePanel:Hide()
        GameUI._teambattlePanel = panel
        root_:AddChild(panel)
    end

    panel:Show()
    stateLabel_.text = "团队战中心"
end

function GameUI._ShowTradeMarket()
    local TradeSystem = safeRequire("Game.TradeSystem")
    if not TradeSystem then
        GameUI._ShowToast("交易市场加载中...", "WARNING")
        return
    end

    GameUI._HideAllPanels()

    local stats = TradeSystem.GetMarketStats()

    -- 创建交易市场面板
    local panel = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = rgba({20, 20, 20}, 220),
        children = {
            -- 标题
            UI.Label {
                text = "🛒 交易市场",
                fontSize = 20, fontColor = rgba(C.Accent),
                fontWeight = "bold", marginTop = 20, marginLeft = 20
            },
            -- 市场统计
            UI.Label {
                text = string.format("在售: %d 件 | 今日成交: %d 笔",
                    stats.activeListings, stats.todayTrades),
                fontSize = 12, fontColor = rgba(C.TextSecondary),
                marginTop = 5, marginLeft = 20
            },
            -- 分割线
            UI.Divider { color = rgba(C.Primary, 40), spacing = 8, marginTop = 10 },
            -- 手续费信息
            UI.Label {
                text = string.format("手续费: %.0f%%", TradeSystem.Config.feeRate * 100),
                fontSize = 11, fontColor = rgba(C.Secondary),
                marginTop = 10, marginLeft = 20
            },
            -- 提示
            UI.Label {
                text = "在收藏馆中点击「上架」可将藏品出售到市场",
                fontSize = 11, fontColor = rgba(C.TextSecondary),
                marginTop = 5, marginLeft = 20
            },
            -- 返回按钮
            UI.Button {
                text = "🔙 返回",
                width = 100, height = 36,
                marginTop = 20, marginLeft = 20,
                onClick = function()
                    GameUI._ShowHallSelect()
                end
            }
        }
    }

    if not GameUI._tradePanel then
        GameUI._tradePanel = panel
        root_:AddChild(panel)
    else
        GameUI._tradePanel:Hide()
        GameUI._tradePanel = panel
        root_:AddChild(panel)
    end

    panel:Show()
    stateLabel_.text = "交易市场"
end

function GameUI._ShowSkinShop()
    local SkinSystem = safeRequire("Game.SkinSystem")
    if not SkinSystem then
        GameUI._ShowToast("皮肤系统加载中...", "WARNING")
        return
    end

    GameUI._HideAllPanels()

    local playerId = client_ and client_.playerId_ or "default"
    local stats = SkinSystem.GetPlayerStats(playerId)

    -- 创建皮肤商店面板
    local panel = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = rgba({20, 20, 20}, 220),
        children = {
            -- 标题
            UI.Label {
                text = "🎨 皮肤商店",
                fontSize = 20, fontColor = rgba(C.Accent),
                fontWeight = "bold", marginTop = 20, marginLeft = 20
            },
            -- 皮肤统计
            UI.Label {
                text = string.format("已解锁: %d 个皮肤", stats.totalUnlocked),
                fontSize = 12, fontColor = rgba(C.TextSecondary),
                marginTop = 5, marginLeft = 20
            },
            -- 分割线
            UI.Divider { color = rgba(C.Primary, 40), spacing = 8, marginTop = 10 },
            -- 稀有度说明
            UI.Label {
                text = "稀有度: 普通 → 稀有 → 史诗 → 传说 → 独占",
                fontSize = 11, fontColor = rgba(C.Secondary),
                marginTop = 10, marginLeft = 20
            },
            -- 套装提示
            UI.Label {
                text = "收集完整套装可领取额外奖励",
                fontSize = 11, fontColor = rgba(C.TextSecondary),
                marginTop = 5, marginLeft = 20
            },
            -- 返回按钮
            UI.Button {
                text = "🔙 返回",
                width = 100, height = 36,
                marginTop = 20, marginLeft = 20,
                onClick = function()
                    GameUI._ShowHallSelect()
                end
            }
        }
    }

    if not GameUI._skinPanel then
        GameUI._skinPanel = panel
        root_:AddChild(panel)
    else
        GameUI._skinPanel:Hide()
        GameUI._skinPanel = panel
        root_:AddChild(panel)
    end

    panel:Show()
    stateLabel_.text = "皮肤商店"
end

function GameUI._ShowCharSelect()
    GameUI._HideAllPanels()
    charSelectPanel_:Show()
    stateLabel_.text = "角色选择中..."
end

function GameUI._ShowBid()
    GameUI._HideAllPanels()
    -- 重置表情栏折叠状态
    emoteBarVisible_ = false
    bidPanel_:Show()
end

function GameUI._ShowResult()
    GameUI._HideAllPanels()
    resultPanel_:Show()
end

function GameUI._ShowOverlay()
    GameUI._HideAllPanels()
    overlayPanel_:Show()
end

function GameUI._ShowReveal()
    GameUI._HideAllPanels()
    revealPanel_:Show()
end

-- ============================================================================
-- 状态变化响应
-- ============================================================================

function GameUI._OnStateChanged(key, state)
    -- 连接/座位分配
    if key == "seat" then
        GameUI._UpdateLobby(state)

    -- 拍卖物品列表
    elseif key == "auctionItems" then
        GameUI._OnAuctionItems(state)

    -- 游戏开始
    elseif key == "gameStart" then
        GameUI._OnGameStart(state)

    -- 回合开始
    elseif key == "roundStart" then
        GameUI._OnRoundStart(state)

    -- 出价确认
    elseif key == "bidAck" then
        GameUI._OnBidAck(state)

    -- 回合结果
    elseif key == "roundResult" then
        GameUI._OnRoundResult(state)

    -- 速胜
    elseif key == "speedWin" then
        GameUI._OnSpeedWin(state)

    -- 游戏结束
    elseif key == "gameEnd" then
        GameUI._OnGameEnd(state)

    -- 计时器
    elseif key == "timer" then
        GameUI._UpdateTimer(state)

    -- 开箱开始
    elseif key == "revealStart" then
        GameUI._OnRevealStart(state)

    -- 逐件揭示
    elseif key == "revealItem" then
        GameUI._OnRevealItem(state)

    -- 总价值
    elseif key == "revealTotal" then
        GameUI._OnRevealTotal(state)

    -- 玩家加入/离开
    elseif key == "playerJoin" or key == "playerLeave" then
        GameUI._UpdateLobby(state)

    -- === Phase 2 事件 ===
    elseif key == "charSelectStart" then
        GameUI._OnCharSelectStart(state)

    elseif key == "charSelected" then
        GameUI._OnCharSelected(state)

    elseif key == "charSelectEnd" then
        GameUI._OnCharSelectEnd(state)

    elseif key == "skillResult" then
        GameUI._OnSkillResult(state)

    elseif key == "skillInfo" then
        GameUI._OnSkillInfo(state)

    elseif key == "passiveInfo" then
        GameUI._OnPassiveInfo(state)

    -- === Phase 3 事件 ===
    elseif key == "playerData" then
        GameUI._OnPlayerData(state)

    elseif key == "balanceUpdate" then
        GameUI._OnBalanceUpdate(state)

    elseif key == "reward" then
        GameUI._OnReward(state)

    elseif key == "sellResult" then
        GameUI._OnSellResult(state)

    elseif key == "collectionData" then
        GameUI._OnCollectionData(state)

    elseif key == "emote" then
        GameUI._OnEmoteReceived(state)

    end
end

-- ============================================================================
-- Phase 1 UI 更新逻辑
-- ============================================================================

--- 更新大厅玩家列表（座位指示器 + 玩家信息卡）
function GameUI._UpdateLobby(state)
    local count = 0

    for seatIdx = 1, Config.Auction.MaxPlayers do
        local p = state.players[seatIdx]
        local isSelf = (seatIdx == state.mySeat)
        local dot = lobbySeatDots_[seatIdx]
        if not dot then goto continue end

        if p then
            count = count + 1
            if isSelf then
                -- 自己：金色高亮
                dot:SetStyle {
                    backgroundColor = rgba(C.Accent, 60),
                    borderColor = rgba(C.Accent),
                }
            else
                -- 其他玩家：蓝色
                dot:SetStyle {
                    backgroundColor = rgba(C.Primary, 50),
                    borderColor = rgba(C.Primary, 180),
                }
            end
        else
            -- 空位：暗灰
            dot:SetStyle {
                backgroundColor = rgba(C.Surface, 180),
                borderColor = rgba(C.TextSecondary, 60),
            }
        end
        ::continue::
    end

    lobbyCountLabel_.text = string.format("%d/%d 在线", count, Config.Auction.MaxPlayers)

    -- 更新玩家信息卡（显示自己的名字和余额）
    if state.mySeat and state.players[state.mySeat] then
        local me = state.players[state.mySeat]
        if lobbyNameLabel_ then
            lobbyNameLabel_.text = me.name or "竞拍者"
        end
    end
    if lobbyBalanceLabel_ and state.balance then
        lobbyBalanceLabel_.text = "💰 " .. Helper.FormatMoney(state.balance)
    end
end

--- 游戏开始
function GameUI._OnGameStart(state)
    roundLabel_.text = string.format("第 0/%d 轮", state.totalRounds)
    stateLabel_.text = state.hallName .. " - 游戏即将开始"
end

--- 收到拍卖物品列表（开局时服务端广播）
function GameUI._OnAuctionItems(state)
    local items = state.auctionItems
    if not items or #items == 0 then return end

    -- ── 左侧: 填充 auctionItemsContainer_ ──
    auctionItemsContainer_:ClearChildren()
    for _, item in ipairs(items) do
        local rColor = rarityColor(item.rarity)
        local rName = rarityName(item.rarity)
        local row = UI.Panel {
            width = "100%",
            flexDirection = "row",
            alignItems = "center",
            gap = 6,
            padding = { 4, 6 },
            borderRadius = 6,
            backgroundColor = rgba(C.Surface, 100),
            children = {
                -- 稀有度色点
                UI.Panel {
                    width = 6, height = 6,
                    borderRadius = 3,
                    backgroundColor = rColor,
                },
                -- 名称
                UI.Label {
                    text = item.name,
                    fontSize = 11,
                    fontColor = rgba(C.TextPrimary),
                    fontWeight = "bold",
                    flexGrow = 1, flexShrink = 1,
                },

            },
        }
        auctionItemsContainer_:AddChild(row)
    end


    -- ── 右侧: 重建战利品网格 ──
    itemGridContainer_:ClearChildren()
    itemCards_ = {}
    for i, item in ipairs(items) do
        -- 取第一个完整 UTF-8 字符
        local initial
        local b = string.byte(item.name, 1)
        if b and b >= 0xE0 then
            initial = string.sub(item.name, 1, 3)
        elseif b and b >= 0xC0 then
            initial = string.sub(item.name, 1, 2)
        else
            initial = string.sub(item.name, 1, 1)
        end

        local iconLabel = UI.Label { text = initial, fontSize = 14, fontColor = rgba(C.TextPrimary) }
        local cell = UI.Panel {
            width = 40, height = 40,
            borderRadius = 6,
            borderWidth = 1,
            borderColor = rgba(C.Primary, 60),
            backgroundColor = rgba(C.Surface, 80),
            justifyContent = "center",
            alignItems = "center",
            children = { iconLabel },
        }
        itemCards_[i] = { panel = cell, iconLabel = iconLabel }
        itemGridContainer_:AddChild(cell)
    end



    print(string.format("[GameUI] Displayed %d auction items", #items))
end

--- 回合开始 → 切换到出价面板
function GameUI._OnRoundStart(state)
    roundLabel_.text = string.format("第 %d/%d 轮", state.currentRound, state.totalRounds)

    -- 更新拍品标题
    bidTitleLabel_.text = string.format("第 %d/%d 轮出价", state.currentRound, state.totalRounds)

    -- 更新速胜提示
    if state.speedWinMult > 0 then
        stateLabel_.text = string.format("速胜倍率: %.0f%%", state.speedWinMult * 100)
    else
        stateLabel_.text = "最终轮 - 无速胜"
    end

    -- 重置出价面板
    currentBidAmount_ = 0
    local maxBid = state.funds
    bidSlider_:SetStyle({ max = maxBid, step = math.max(100, math.floor(maxBid / 50)) })
    bidSlider_.value = 0
    bidAmountLabel_.text = "0"
    bidConfirmBtn_.disabled = false
    bidConfirmBtn_.text = "确认出价"
    bidHintLabel_.text = "拖动滑块设置出价金额"

    -- 更新最大值标签
    local maxLabel = bidPanel_:FindById("maxBidLabel")
    if maxLabel then
        maxLabel.text = Helper.FormatMoney(maxBid)
    end

    -- Phase 2: 更新技能区域
    GameUI._UpdateSkillSection(state)

    -- 清除上次技能结果
    skillResultLabel_.text = ""

    GameUI._UpdateTimer(state)
    GameUI._ShowBid()
end

--- 出价确认响应
function GameUI._OnBidAck(state)
    if state.lastBidAccepted then
        bidHintLabel_.text = "出价已锁定，等待其他玩家..."
        bidHintLabel_.fontColor = rgba(C.Success)
    else
        -- 出价被拒绝，重新启用
        bidConfirmBtn_.disabled = false
        bidConfirmBtn_.text = "重新出价"
        bidHintLabel_.text = "出价失败: " .. state.lastBidReason
        bidHintLabel_.fontColor = rgba(C.Danger)
    end
end

--- 回合结果
function GameUI._OnRoundResult(state)
    -- 不再显示回合结算面板，静默更新状态
    stateLabel_.text = "结算中..."
end

--- 速胜
function GameUI._OnSpeedWin(state)
    local isMeWinner = (state.winnerSeat == state.mySeat)
    if isMeWinner then
        overlayTitleLabel_.text = "速胜!"
        overlayTitleLabel_.fontColor = rgba(C.SpeedWin)
        overlaySubLabel_.text = "你以压倒性出价赢得了这场拍卖！"
    else
        overlayTitleLabel_.text = "速胜结束"
        overlayTitleLabel_.fontColor = rgba(C.Danger)
        overlaySubLabel_.text = string.format("玩家 %s 以压倒性出价获胜", state.winnerName)
    end
    stateLabel_.text = "速胜!"
    GameUI._ShowOverlay()
end

--- 游戏结束
function GameUI._OnGameEnd(state)
    -- 不再显示 overlay，等待开箱揭示接管画面
    stateLabel_.text = "比赛结束"
end

--- 更新倒计时显示
function GameUI._UpdateTimer(state)
    local t = math.ceil(state.timeLeft)
    if t > 0 and state.gameState == Config.GameState.BIDDING then
        timerLabel_.text = tostring(t) .. "s"
        if t <= 5 then
            timerLabel_.fontColor = rgba(C.Danger)
        else
            timerLabel_.fontColor = rgba(C.TextPrimary)
        end
    else
        timerLabel_.text = ""
    end

    -- 角色选择阶段也更新面板内计时
    if state.gameState == Config.GameState.CHAR_SELECT then
        charSelectTimerLabel_.text = tostring(t) .. "s"
        if t <= 5 then
            charSelectTimerLabel_.fontColor = rgba(C.Danger)
        else
            charSelectTimerLabel_.fontColor = rgba(C.Accent)
        end
    end
end

--- 开箱开始
function GameUI._OnRevealStart(state)
    revealItemsContainer_:ClearChildren()
    revealTotalLabel_.text = ""
    stateLabel_.text = "开箱揭示..."
    GameUI._ShowReveal()
end

--- 逐件揭示
function GameUI._OnRevealItem(state)
    local items = state.revealItems
    local latest = items[#items]
    if not latest then return end

    local rColor = rarityColor(latest.rarity)
    local rName = rarityName(latest.rarity)
    local catText = latest.category or ""

    local itemCard = UI.Panel {
        width = "85%",
        padding = 12,
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        backgroundColor = rgba(C.Surface),
        borderRadius = 10,
        borderWidth = 2,
        borderColor = rColor,
        children = {
            UI.Panel {
                flexShrink = 1,
                gap = 2,
                children = {
                    UI.Panel {
                        flexDirection = "row",
                        gap = 6,
                        alignItems = "center",
                        children = {
                            UI.Panel {
                                width = 8, height = 8,
                                borderRadius = 4,
                                backgroundColor = rColor,
                            },
                            UI.Label {
                                text = latest.name,
                                fontSize = 14,
                                fontColor = rgba(C.TextPrimary),
                                fontWeight = "bold",
                            },
                        },
                    },
                    -- Phase 2: 分类标签
                    UI.Label {
                        text = catText,
                        fontSize = 9,
                        fontColor = rgba(C.TextSecondary, 150),
                    },
                },
            },
            UI.Panel {
                alignItems = "flex-end",
                children = {
                    UI.Label {
                        text = rName,
                        fontSize = 10,
                        fontColor = rColor,
                    },
                    UI.Label {
                        text = Helper.FormatMoney(latest.value),
                        fontSize = 14,
                        fontColor = rgba(C.Accent),
                        fontWeight = "bold",
                    },
                },
            },
        },
    }
    revealItemsContainer_:AddChild(itemCard)
end

--- 总价值揭晓
function GameUI._OnRevealTotal(state)
    local profitColor
    if state.revealProfit > 0 then
        profitColor = rgba(C.Success)
    elseif state.revealProfit < 0 then
        profitColor = rgba(C.Danger)
    else
        profitColor = rgba(C.TextSecondary)
    end

    local profitSign = state.revealProfit >= 0 and "+" or ""

    revealTotalLabel_.text = string.format(
        "藏品总价: %s | 花费: %s | 盈亏: %s%s",
        Helper.FormatMoney(state.revealTotalValue),
        Helper.FormatMoney(state.revealBidTotal),
        profitSign, Helper.FormatMoney(state.revealProfit)
    )
    revealTotalLabel_.fontColor = profitColor
end

-- ============================================================================
-- Phase 2: 角色选择 UI
-- ============================================================================

--- 角色选择开始
function GameUI._OnCharSelectStart(state)
    -- 如果有预选角色，自动提交选择，不显示面板
    if pendingCharId_ and client_ then
        print(string.format("[GameUI] Auto-submitting pre-selected char: %s", pendingCharId_))
        client_.SelectCharacter(pendingCharId_)
        -- 更新 HUD 角色名
        if pendingCharName_ then
            charNameLabel_.text = "角色: " .. pendingCharName_
        end
        stateLabel_.text = "匹配中..."
        -- 不显示角色选择面板，等待服务端 charSelectEnd 后进入游戏
        return
    end
    -- 无预选 → 走原逻辑，显示角色选择面板
    GameUI._RebuildCharCards(state)
    charSelectHintLabel_.text = "点击角色卡片选择你的角色"
    charSelectHintLabel_.fontColor = rgba(C.TextSecondary)
    GameUI._ShowCharSelect()
end

--- 有人选了角色（更新卡片状态）
function GameUI._OnCharSelected(state)
    -- 自己选了角色？
    if state.myCharId ~= "" then
        charNameLabel_.text = "角色: " .. state.myCharName
        charSelectHintLabel_.text = "已选择: " .. state.myCharName
        charSelectHintLabel_.fontColor = rgba(C.Success)
    end
    -- 重建卡片以反映哪些已被选
    GameUI._RebuildCharCards(state)
end

--- 角色选择结束
function GameUI._OnCharSelectEnd(state)
    if state.myCharName ~= "" then
        charNameLabel_.text = "角色: " .. state.myCharName
    end
    -- 此后由 gameStart 或 roundStart 切换面板
end

--- 重建角色选择卡片
function GameUI._RebuildCharCards(state)
    charGridPanel_:ClearChildren()

    local available = state.availableChars
    if not available or #available == 0 then return end

    -- 已被别人选的角色 id 集合
    local taken = {}
    for seatIdx, sel in pairs(state.selectedChars) do
        if seatIdx ~= state.mySeat then
            taken[sel.charId] = true
        end
    end

    local mySelected = state.myCharId

    for _, c in ipairs(available) do
        local charId = c.id
        local isTaken = taken[charId] or false
        local isMyPick = (charId == mySelected)

        -- 卡片颜色
        local cardBg, borderCol
        if isMyPick then
            cardBg = rgba(C.Primary, 60)
            borderCol = rgba(C.Accent)
        elseif isTaken then
            cardBg = rgba(C.Surface, 80)
            borderCol = rgba(C.TextSecondary, 40)
        else
            cardBg = rgba(C.Surface)
            borderCol = rgba(C.Primary, 80)
        end

        -- 技能简述
        local skillDesc = ""
        if c.activeSkill then
            skillDesc = c.activeSkill.name
        end
        local passiveDesc = ""
        if c.passiveSkill then
            passiveDesc = c.passiveSkill.name
        end

        -- 状态标签
        local statusText = ""
        local statusColor = rgba(C.TextSecondary)
        if isMyPick then
            statusText = "已选"
            statusColor = rgba(C.Success)
        elseif isTaken then
            statusText = "已被选"
            statusColor = rgba(C.Danger, 160)
        end

        local card = UI.Panel {
            width = "46%",
            padding = 10,
            gap = 4,
            backgroundColor = cardBg,
            borderRadius = 10,
            borderWidth = 2,
            borderColor = borderCol,
            opacity = isTaken and 0.5 or 1.0,
            cursor = (isTaken and not isMyPick) and "default" or "pointer",
            onClick = function()
                if not client_ then return end
                -- 实时检查是否已被他人选择（不依赖闭包快照）
                local st = client_.state
                for si, sel in pairs(st.selectedChars) do
                    if sel.charId == charId and si ~= st.mySeat then
                        return -- 已被其他玩家选择
                    end
                end
                client_.SelectCharacter(charId)
            end,
            children = {
                -- 角色名 + 头衔
                UI.Label {
                    text = c.name,
                    fontSize = 15,
                    fontColor = rgba(C.TextPrimary),
                    fontWeight = "bold",
                },
                UI.Label {
                    text = c.title or "",
                    fontSize = 9,
                    fontColor = rgba(C.TextSecondary),
                },
                UI.Divider { color = rgba(C.Primary, 30), spacing = 2 },
                -- 主动技能
                UI.Label {
                    text = "主动: " .. skillDesc,
                    fontSize = 10,
                    fontColor = rgba(C.Secondary),
                },
                -- 被动技能
                UI.Label {
                    text = "被动: " .. passiveDesc,
                    fontSize = 10,
                    fontColor = rgba(C.TextSecondary, 180),
                },
                -- 状态
                statusText ~= "" and UI.Label {
                    text = statusText,
                    fontSize = 10,
                    fontColor = statusColor,
                    fontWeight = "bold",
                    textAlign = "center",
                } or nil,
            },
        }

        charGridPanel_:AddChild(card)
    end
end

-- ============================================================================
-- Phase 2: 技能 UI
-- ============================================================================

--- 更新出价面板中的技能区域
function GameUI._UpdateSkillSection(state)
    -- 没选角色则隐藏技能区
    if not state.myCharData then
        skillSection_:Hide()
        return
    end
    skillSection_:Show()

    -- 主动技能信息
    local skill = state.myCharData.activeSkill
    if skill then
        skillNameLabel_.text = skill.name
        if GameUI._skillDescLabel then
            GameUI._skillDescLabel.text = skill.desc or ""
        end
    else
        skillNameLabel_.text = ""
        if GameUI._skillDescLabel then
            GameUI._skillDescLabel.text = ""
        end
    end

    -- 被动技能信息
    local passive = state.myCharData.passiveSkill
    if passive then
        if GameUI._passiveNameLabel then
            GameUI._passiveNameLabel.text = passive.name or ""
        end
        if GameUI._passiveDescLabel then
            GameUI._passiveDescLabel.text = passive.desc or ""
        end
    else
        if GameUI._passiveNameLabel then
            GameUI._passiveNameLabel.text = ""
        end
        if GameUI._passiveDescLabel then
            GameUI._passiveDescLabel.text = ""
        end
    end

    -- 更新状态（从 skillInfo 获取最新 CD/使用次数）
    GameUI._RefreshSkillStatus(state)

    -- 更新目标选择按钮
    targetSection_:ClearChildren()
    targetSection_:Hide()
end

--- 刷新技能状态标签和按钮
function GameUI._RefreshSkillStatus(state)
    local info = state.skillInfo
    if info then
        local parts = {}
        if info.currentCD and info.currentCD > 0 then
            table.insert(parts, string.format("冷却: %d轮", info.currentCD))
        end
        if info.usesLeft and info.maxUses then
            if info.maxUses > 0 then
                table.insert(parts, string.format("次数: %d/%d", info.usesLeft, info.maxUses))
            else
                table.insert(parts, "次数: 无限")
            end
        end
        skillStatusLabel_.text = table.concat(parts, " | ")

        local canUse = info.canUse
        if canUse then
            skillUseBtn_.disabled = false
            skillUseBtn_.text = "使用技能"
        else
            skillUseBtn_.disabled = true
            if info.currentCD and info.currentCD > 0 then
                skillUseBtn_.text = "冷却中"
            elseif info.usesLeft and info.usesLeft <= 0 then
                skillUseBtn_.text = "已用完"
            else
                skillUseBtn_.text = "不可用"
            end
        end
    else
        skillStatusLabel_.text = "等待技能信息..."
        skillUseBtn_.disabled = true
    end
end

--- 技能按钮点击
function GameUI._OnSkillBtnClick()
    if not client_ then return end
    local state = client_.state

    -- 如果技能需要目标，则展示目标选择
    if state.skillNeedsTarget then
        GameUI._ShowTargetButtons(state)
    else
        -- 不需要目标，直接使用
        client_.UseSkill(nil)
        skillUseBtn_.disabled = true
        skillUseBtn_.text = "已使用"
    end
end

--- 显示目标选择按钮
function GameUI._ShowTargetButtons(state)
    targetSection_:ClearChildren()
    targetSection_:Show()

    -- 添加提示
    targetSection_:AddChild(UI.Label {
        text = "选择目标:",
        fontSize = 11,
        fontColor = rgba(C.Accent),
        width = "100%",
        textAlign = "center",
    })

    -- 为每个其他玩家创建目标按钮
    for seatIdx = 1, Config.Auction.MaxPlayers do
        if seatIdx ~= state.mySeat then
            local p = state.players[seatIdx]
            if p then
                local pName = p.name or ("玩家" .. seatIdx)
                local btn = UI.Button {
                    text = pName,
                    variant = "outline",
                    height = 32,
                    fontSize = 12,
                    onClick = function()
                        if client_ then
                            client_.UseSkill(seatIdx)
                            targetSection_:Hide()
                            skillUseBtn_.disabled = true
                            skillUseBtn_.text = "已使用"
                        end
                    end,
                }
                targetSection_:AddChild(btn)
            end
        end
    end

    -- 取消按钮
    targetSection_:AddChild(UI.Button {
        text = "取消",
        variant = "text",
        height = 28,
        fontSize = 11,
        onClick = function()
            targetSection_:Hide()
        end,
    })
end

--- 技能结果通知
function GameUI._OnSkillResult(state)
    local r = state.lastSkillResult
    if not r then return end

    if r.success then
        local desc = r.resultData and r.resultData.desc or "技能生效"
        skillResultLabel_.text = r.skillName .. ": " .. desc
        skillResultLabel_.fontColor = rgba(C.Success)
    else
        local err = r.resultData and r.resultData.error or "技能失败"
        skillResultLabel_.text = r.skillName .. ": " .. err
        skillResultLabel_.fontColor = rgba(C.Danger)
    end
end

--- 技能信息更新
function GameUI._OnSkillInfo(state)
    GameUI._RefreshSkillStatus(state)
end

-- ============================================================================
-- Phase 2: 被动通知
-- ============================================================================

function GameUI._OnPassiveInfo(state)
    local msgs = state.passiveMessages
    if #msgs == 0 then return end

    -- 显示最新一条被动消息
    local latest = msgs[#msgs]
    passiveLabel_.text = "被动: " .. latest.name .. " - " .. latest.desc
    passivePanel_:Show()
end

-- ============================================================================
-- Phase 3: 大厅选择面板构建
-- ============================================================================

function GameUI._BuildHallSelectPanel()
    hallCardButtons_ = {}

    -- 拍卖厅场景配置：emoji 图标、地图位置（百分比）、主题色
    local hallScenes = {
        { id = "hall_beginner", icon = "🏠", mapX = "15%", mapY = "20%",
          tint = {100, 200, 160} },  -- 青色-新手
        { id = "hall_standard", icon = "🏛️", mapX = "60%", mapY = "15%",
          tint = {80, 160, 255} },   -- 蓝色-雅集
        { id = "hall_premium",  icon = "💎", mapX = "25%", mapY = "60%",
          tint = {180, 80, 255} },   -- 紫色-珍宝
        { id = "hall_legend",   icon = "👑", mapX = "65%", mapY = "55%",
          tint = {255, 180, 30} },   -- 金色-天工
    }

    -- 查找 hall 数据的辅助函数
    local function findHall(id)
        for _, h in ipairs(Config.AuctionHalls) do
            if h.id == id then return h end
        end
    end

    -- ── 左侧导航菜单 ──
    local menuItems = {
        { icon = "🔨", label = "拍卖大厅", active = true },
        { icon = "🏛️", label = "收藏馆",   action = "collection" },
        { icon = "🏆", label = "锦标赛",   action = "tournament" },  -- v1.2.0
        { icon = "👥", label = "团队战",   action = "teambattle" }, -- v1.2.0
        { icon = "🛒", label = "交易市场", action = "trade" },     -- v1.2.0
        { icon = "🎨", label = "皮肤商店", action = "skin" },     -- v1.2.0
        { icon = "📋", label = "每日任务", action = "missions" },  -- v1.1.0
        { icon = "🏆", label = "赛季",     action = "season" },    -- v1.1.0
        { icon = "👥", label = "好友",     action = "friends" },   -- v1.1.0
        { icon = "👤", label = "个人",     action = "profile" },   -- v1.1.0
        { icon = "🔙", label = "返回大厅", action = "lobby" },
    }
    local menuChildren = {}
    for _, item in ipairs(menuItems) do
        menuChildren[#menuChildren + 1] = UI.Panel {
            width = "100%",
            flexDirection = "row",
            alignItems = "center",
            gap = 6,
            padding = { 8, 10 },
            backgroundColor = item.active and rgba(C.Accent, 30) or rgba({0,0,0}, 0),
            borderRadius = 6,
            borderWidth = item.active and 1 or 0,
            borderColor = item.active and rgba(C.Accent, 80) or rgba({0,0,0}, 0),
            cursor = "pointer",
            onClick = function()
                if item.action == "collection" then
                    GameUI._ShowCollection()
                elseif item.action == "tournament" then     -- v1.2.0
                    GameUI._ShowTournament()
                elseif item.action == "teambattle" then    -- v1.2.0
                    GameUI._ShowTeamBattle()
                elseif item.action == "trade" then         -- v1.2.0
                    GameUI._ShowTradeMarket()
                elseif item.action == "skin" then          -- v1.2.0
                    GameUI._ShowSkinShop()
                elseif item.action == "missions" then      -- v1.1.0
                    GameUI._ShowMissions()
                elseif item.action == "season" then        -- v1.1.0
                    GameUI._ShowSeason()
                elseif item.action == "friends" then        -- v1.1.0
                    GameUI._ShowFriends()
                elseif item.action == "profile" then       -- v1.1.0
                    GameUI._ShowProfile()
                elseif item.action == "lobby" then
                    GameUI._ShowLobby()
                end
            end,
            children = {
                UI.Label { text = item.icon, fontSize = 14 },
                UI.Label {
                    text = item.label, fontSize = 11,
                    fontColor = item.active and rgba(C.Accent) or rgba(C.TextSecondary),
                    fontWeight = item.active and "bold" or "normal",
                },
            },
        }
    end

    local leftMenu = UI.Panel {
        width = 100,
        gap = 4,
        padding = { 8, 6 },
        backgroundColor = rgba({10, 14, 22}, 220),
        borderRadius = 8,
        children = menuChildren,
    }

    -- ── 地图区域：场景卡片（绝对定位模拟） ──
    -- 用 flexbox 行列布局模拟散布效果（2 行 × 2 列，间距不均匀）
    local mapPointRows = {}

    -- 第一行：新手厅（左上）+ 雅集厅（右上）
    local row1 = {}
    for _, si in ipairs({1, 2}) do
        local scene = hallScenes[si]
        local hall = findHall(scene.id)
        if hall then
            local feeText = hall.entryFee > 0
                and Helper.FormatMoney(hall.entryFee)
                or "免费"

            local cardPanel = UI.Panel {
                width = "46%",
                padding = 8,
                gap = 4,
                backgroundColor = rgba(C.Surface, 160),
                borderRadius = 10,
                borderWidth = 1.5,
                borderColor = rgba(scene.tint, 100),
                alignItems = "center",
                cursor = "pointer",
                onClick = function()
                    GameUI._OnHallCardClick(hall.id)
                end,
                children = {
                    -- 图标 + 光圈
                    UI.Panel {
                        width = 48, height = 48,
                        borderRadius = 24,
                        backgroundColor = rgba(scene.tint, 30),
                        borderWidth = 1.5,
                        borderColor = rgba(scene.tint, 120),
                        justifyContent = "center", alignItems = "center",
                        children = {
                            UI.Label { text = scene.icon, fontSize = 24, textAlign = "center" },
                        },
                    },
                    -- 名称
                    UI.Label {
                        text = hall.name, fontSize = 13,
                        fontColor = rgba(C.TextPrimary), fontWeight = "bold",
                        textAlign = "center",
                    },
                    -- 描述
                    UI.Label {
                        text = hall.desc, fontSize = 9,
                        fontColor = rgba(C.TextSecondary),
                        textAlign = "center", whiteSpace = "normal",
                    },
                    -- 入场费标签
                    UI.Panel {
                        paddingHorizontal = 8, paddingVertical = 3,
                        backgroundColor = rgba(scene.tint, 25),
                        borderRadius = 4,
                        children = {
                            UI.Label {
                                text = "💰 " .. feeText,
                                fontSize = 9, fontColor = rgba(scene.tint),
                                fontWeight = "bold", textAlign = "center",
                            },
                        },
                    },
                },
            }
            hallCardButtons_[hall.id] = cardPanel
            row1[#row1 + 1] = cardPanel
        end
    end

    -- 第二行：珍宝阁（左下）+ 天工殿（右下）
    local row2 = {}
    for _, si in ipairs({3, 4}) do
        local scene = hallScenes[si]
        local hall = findHall(scene.id)
        if hall then
            local feeText = hall.entryFee > 0
                and Helper.FormatMoney(hall.entryFee)
                or "免费"

            local cardPanel = UI.Panel {
                width = "46%",
                padding = 8,
                gap = 4,
                backgroundColor = rgba(C.Surface, 160),
                borderRadius = 10,
                borderWidth = 1.5,
                borderColor = rgba(scene.tint, 100),
                alignItems = "center",
                cursor = "pointer",
                onClick = function()
                    GameUI._OnHallCardClick(hall.id)
                end,
                children = {
                    -- 图标 + 光圈
                    UI.Panel {
                        width = 48, height = 48,
                        borderRadius = 24,
                        backgroundColor = rgba(scene.tint, 30),
                        borderWidth = 1.5,
                        borderColor = rgba(scene.tint, 120),
                        justifyContent = "center", alignItems = "center",
                        children = {
                            UI.Label { text = scene.icon, fontSize = 24, textAlign = "center" },
                        },
                    },
                    -- 名称
                    UI.Label {
                        text = hall.name, fontSize = 13,
                        fontColor = rgba(C.TextPrimary), fontWeight = "bold",
                        textAlign = "center",
                    },
                    -- 描述
                    UI.Label {
                        text = hall.desc, fontSize = 9,
                        fontColor = rgba(C.TextSecondary),
                        textAlign = "center", whiteSpace = "normal",
                    },
                    -- 入场费标签
                    UI.Panel {
                        paddingHorizontal = 8, paddingVertical = 3,
                        backgroundColor = rgba(scene.tint, 25),
                        borderRadius = 4,
                        children = {
                            UI.Label {
                                text = "💰 " .. feeText,
                                fontSize = 9, fontColor = rgba(scene.tint),
                                fontWeight = "bold", textAlign = "center",
                            },
                        },
                    },
                },
            }
            hallCardButtons_[hall.id] = cardPanel
            row2[#row2 + 1] = cardPanel
        end
    end

    -- 地图面板（深色背景 + 散布场景点）
    local mapArea = UI.Panel {
        flexGrow = 1,
        width = "100%",
        gap = 10,
        padding = { 6, 4 },
        justifyContent = "center",
        children = {
            -- 行 1
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "space-around",
                gap = 8,
                children = row1,
            },
            -- 行 2
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "space-around",
                gap = 8,
                children = row2,
            },
        },
    }

    -- ── 底部信息条 ──
    local bottomInfo = UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        padding = { 6, 10 },
        backgroundColor = rgba({10, 14, 22}, 200),
        borderRadius = 6,
        children = {
            UI.Label {
                text = "📍 选择场地开始竞拍",
                fontSize = 10, fontColor = rgba(C.TextSecondary),
            },
            UI.Label {
                text = "4 个场地可用",
                fontSize = 10, fontColor = rgba(C.Primary),
            },
        },
    }

    -- ── 组装竞拍大厅面板 ──
    hallSelectPanel_ = UI.Panel {
        width = "100%",
        flexGrow = 1,
        backgroundColor = rgba({12, 16, 26}, 255),
        children = {
            -- 顶部标题栏
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                padding = { 8, 12 },
                backgroundColor = rgba({10, 14, 22}, 230),
                children = {
                    UI.Label {
                        text = "⚔️ 竞拍大厅",
                        fontSize = 16, fontColor = rgba(C.TextPrimary),
                        fontWeight = "bold",
                    },
                    UI.Button {
                        text = "✕",
                        fontSize = 16,
                        variant = "ghost",
                        width = 32, height = 32,
                        onClick = function()
                            GameUI._ShowLobby()
                        end,
                    },
                },
            },
            -- 主体：左菜单 + 右地图
            UI.Panel {
                width = "100%",
                flexGrow = 1,
                flexDirection = "row",
                children = {
                    leftMenu,
                    -- 地图区域
                    UI.Panel {
                        flexGrow = 1,
                        padding = 6,
                        gap = 6,
                        children = {
                            mapArea,
                            bottomInfo,
                        },
                    },
                },
            },
        },
    }
end

--- 大厅卡片点击
function GameUI._OnHallCardClick(hallId)
    if not client_ then return end

    -- 检查余额是否足够
    local hall = nil
    for _, h in ipairs(Config.AuctionHalls) do
        if h.id == hallId then
            hall = h
            break
        end
    end
    if not hall then return end

    if client_.state.balance < hall.entryFee then
        GameUI._ShowToast(string.format("余额不足！需要 %s，当前 %s",
            Helper.FormatMoney(hall.entryFee),
            Helper.FormatMoney(client_.state.balance)), C.Danger)
        return
    end

    -- 更新选中卡片高亮
    GameUI._HighlightHallCard(hallId)

    -- 发送选择
    client_.SelectHall(hallId)
    GameUI._ShowToast("已选择: " .. hall.name, C.Success)
end

--- 高亮选中的大厅卡片
function GameUI._HighlightHallCard(hallId)
    for id, card in pairs(hallCardButtons_) do
        if id == hallId then
            card:SetStyle({
                backgroundColor = rgba(C.Primary, 50),
                borderColor = rgba(C.Accent),
                borderWidth = 2,
            })
        else
            card:SetStyle({
                backgroundColor = rgba(C.Surface),
                borderColor = rgba(C.Primary, 60),
                borderWidth = 2,
            })
        end
    end
end

-- ============================================================================
-- Phase 3: 收藏馆面板构建
-- ============================================================================

function GameUI._BuildCollectionPanel()
    collectionStatLabel_ = UI.Label {
        text = "共 0 件藏品 | 总估值 0",
        fontSize = 12,
        fontColor = rgba(C.TextSecondary),
        textAlign = "center",
    }

    collectionListPanel_ = UI.Panel {
        width = "100%",
        gap = 6,
        flexShrink = 1,
    }

    local backBtn = UI.Button {
        text = "返回大厅",
        variant = "text",
        fontSize = 12,
        height = 36,
        onClick = function(self)
            GameUI._ShowHallSelect()
        end,
    }

    -- 标题栏：标题 + 返回按钮，始终可见
    local headerRow = UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        children = {
            UI.Label {
                text = "我的收藏馆",
                fontSize = 20,
                fontColor = rgba(C.Accent),
                fontWeight = "bold",
            },
            backBtn,
        },
    }

    collectionPanel_ = UI.Panel {
        width = "100%",
        flexGrow = 1,
        alignItems = "center",
        gap = 10,
        padding = { 12, 16 },
        children = {
            headerRow,
            collectionStatLabel_,
            UI.Divider { color = rgba(C.Primary, 40), spacing = 4 },
            collectionListPanel_,
        },
    }
end

-- ============================================================================
-- Phase 3: Toast 通知面板构建
-- ============================================================================

function GameUI._BuildToastPanel()
    toastLabel_ = UI.Label {
        text = "",
        fontSize = 12,
        fontColor = rgba(C.TextPrimary),
        textAlign = "center",
        whiteSpace = "normal",
    }
    toastPanel_ = UI.Panel {
        width = "100%",
        padding = { 8, 14 },
        backgroundColor = rgba(C.Surface, 220),
        alignItems = "center",
        borderWidth = 1,
        borderColor = rgba(C.Success, 80),
        children = { toastLabel_ },
    }
end

--- 显示 toast 通知（自动隐藏由 Update 驱动，此处简单显示）
---@param msg string
---@param color table|nil 颜色（默认 Success）
function GameUI._ShowToast(msg, color)
    toastLabel_.text = msg
    toastLabel_.fontColor = rgba(color or C.Success)
    toastPanel_:SetStyle({
        borderColor = rgba(color or C.Success, 80),
    })
    toastPanel_:Show()
    toastClearTimer_ = 3.0  -- 3 秒后自动隐藏
end

-- ============================================================================
-- Phase 3: 事件处理
-- ============================================================================

--- 玩家数据加载完毕（余额、藏品数）
function GameUI._OnPlayerData(state)
    -- 更新余额显示
    balanceLabel_.text = "余额: " .. Helper.FormatMoney(state.balance)

    -- 如果在大厅状态，进入大厅选择
    if state.gameState == Config.GameState.WAITING then
        GameUI._ShowHallSelect()

        -- 自动高亮最高档位能进入的大厅
        local autoHall = nil
        for _, hall in ipairs(Config.AuctionHalls) do
            if state.balance >= hall.entryFee then
                autoHall = hall.id
            end
        end
        if autoHall and state.selectedHallId == "" then
            GameUI._HighlightHallCard(autoHall)
        end
    end

    print(string.format("[GameUI] Player data loaded: balance=%d", state.balance))
end

--- 余额变动（入场费扣除、奖励、出售收入等）
function GameUI._OnBalanceUpdate(state)
    balanceLabel_.text = "余额: " .. Helper.FormatMoney(state.balance)

    -- 显示变动 toast
    local delta = state.lastBalanceDelta
    local reason = state.lastBalanceReason or ""
    local sign = delta >= 0 and "+" or ""
    local color = delta >= 0 and C.Success or C.Danger

    GameUI._ShowToast(string.format("%s%s %s",
        sign, Helper.FormatMoney(delta), reason), color)
end

--- 获胜奖励通知
function GameUI._OnReward(state)
    local items = state.rewardItems
    local totalValue = state.rewardTotalValue

    if #items == 0 then return end

    -- 构造奖励摘要文本
    local names = {}
    for i, item in ipairs(items) do
        if i <= 3 then
            table.insert(names, item.name or "藏品")
        end
    end
    local nameText = table.concat(names, "、")
    if #items > 3 then
        nameText = nameText .. string.format(" 等%d件", #items)
    end

    GameUI._ShowToast(string.format("获得藏品: %s (总价值 %s)",
        nameText, Helper.FormatMoney(totalValue)), C.SpeedWin)
end

--- 出售结果通知
function GameUI._OnSellResult(state)
    local r = state.lastSellResult
    if not r then return end

    if r.success then
        GameUI._ShowToast(string.format("出售 %s，获得 %s",
            r.itemName, Helper.FormatMoney(r.sellPrice)), C.Success)
        -- 出售成功后自动刷新收藏馆数据
        if client_ then
            client_.GetCollection()
        end
    else
        GameUI._ShowToast("出售失败: " .. (r.reason or "未知原因"), C.Danger)
    end
end

--- 珍宝展柜更新（展示最贵重的藏品）
local SHOWCASE_MAX = 5  -- 展柜最多展示 5 件

function GameUI._UpdateShowcase(state)
    if not showcaseListPanel_ then return end

    showcaseListPanel_:ClearChildren()

    local items = state.collection
    if not items or #items == 0 then
        showcaseCountLabel_.text = "暂无藏品"
        showcaseListPanel_:AddChild(showcaseEmptyLabel_)
        return
    end

    -- 按价值降序排列，取前 N 件
    local sorted = {}
    for _, item in ipairs(items) do
        sorted[#sorted + 1] = item
    end
    table.sort(sorted, function(a, b) return a.value > b.value end)

    local count = math.min(#sorted, SHOWCASE_MAX)
    showcaseCountLabel_.text = string.format("TOP %d / %d件", count, #sorted)

    for i = 1, count do
        local item = sorted[i]
        local rColor = rarityColor(item.rarity)
        local rName = rarityName(item.rarity)

        local row = UI.Panel {
            width = "100%",
            flexDirection = "row",
            alignItems = "center",
            padding = { 4, 6 },
            gap = 6,
            backgroundColor = rgba(C.Surface, 140),
            borderRadius = 6,
            borderWidth = 1,
            borderColor = rColor,
            children = {
                -- 排名
                UI.Label {
                    text = tostring(i),
                    fontSize = 11, fontColor = rgba(C.Accent, 180),
                    fontWeight = "bold",
                    width = 14, textAlign = "center",
                },
                -- 稀有度色点
                UI.Panel {
                    width = 6, height = 6,
                    borderRadius = 3,
                    backgroundColor = rColor,
                },
                -- 名称
                UI.Label {
                    text = item.name,
                    fontSize = 10, fontColor = rgba(C.TextPrimary),
                    fontWeight = "bold",
                    flexGrow = 1, flexShrink = 1,
                },
                -- 稀有度
                UI.Label {
                    text = rName,
                    fontSize = 8, fontColor = rColor,
                },
                -- 估值
                UI.Label {
                    text = Helper.FormatMoney(item.value),
                    fontSize = 9, fontColor = rgba(C.Accent),
                    fontWeight = "bold",
                },
            },
        }
        showcaseListPanel_:AddChild(row)
    end
end

--- 藏品数据更新 → 刷新收藏馆面板
function GameUI._OnCollectionData(state)
    if not collectionListPanel_ then return end

    -- 同步更新珍宝展柜
    GameUI._UpdateShowcase(state)

    -- 更新统计
    collectionStatLabel_.text = string.format(
        "共 %d 件藏品 | 总估值 %s",
        state.collectionCount,
        Helper.FormatMoney(state.collectionTotalValue))

    -- 清空列表，重新渲染
    collectionListPanel_:ClearChildren()

    local items = state.collection
    if not items or #items == 0 then
        collectionListPanel_:AddChild(UI.Label {
            text = "暂无藏品，去拍卖厅赢得宝箱吧！",
            fontSize = 13,
            fontColor = rgba(C.TextSecondary),
            textAlign = "center",
            padding = { 30, 0 },
        })
        return
    end

    for _, item in ipairs(items) do
        local rColor = rarityColor(item.rarity)
        local rName = rarityName(item.rarity)
        local sellPrice = math.floor(item.value * Config.Economy.SellPriceRatio)

        local row = UI.Panel {
            width = "100%",
            padding = { 10, 8 },
            flexDirection = "row",
            justifyContent = "space-between",
            alignItems = "center",
            backgroundColor = rgba(C.Surface),
            borderRadius = 8,
            borderWidth = 1,
            borderColor = rColor,
            children = {
                -- 左侧：名称 + 稀有度 + 分类
                UI.Panel {
                    flexShrink = 1,
                    gap = 2,
                    children = {
                        UI.Panel {
                            flexDirection = "row",
                            gap = 6,
                            alignItems = "center",
                            children = {
                                UI.Panel {
                                    width = 8, height = 8,
                                    borderRadius = 4,
                                    backgroundColor = rColor,
                                },
                                UI.Label {
                                    text = item.name,
                                    fontSize = 13,
                                    fontColor = rgba(C.TextPrimary),
                                    fontWeight = "bold",
                                },
                            },
                        },
                        UI.Panel {
                            flexDirection = "row",
                            gap = 6,
                            children = {
                                UI.Label {
                                    text = rName,
                                    fontSize = 9,
                                    fontColor = rColor,
                                },
                                UI.Label {
                                    text = item.category or "",
                                    fontSize = 9,
                                    fontColor = rgba(C.TextSecondary, 140),
                                },
                            },
                        },
                    },
                },
                -- 右侧：估值 + 出售按钮
                UI.Panel {
                    alignItems = "flex-end",
                    gap = 4,
                    children = {
                        UI.Label {
                            text = "估值 " .. Helper.FormatMoney(item.value),
                            fontSize = 10,
                            fontColor = rgba(C.Accent),
                        },
                        UI.Button {
                            text = "出售 " .. Helper.FormatMoney(sellPrice),
                            variant = "outline",
                            fontSize = 10,
                            height = 26,
                            onClick = function(self)
                                if client_ then
                                    client_.SellItem(item.id)
                                end
                            end,
                        },
                    },
                },
            },
        }
        collectionListPanel_:AddChild(row)
    end

    print(string.format("[GameUI] Collection rendered: %d items", #items))
end

--- 收到表情/快捷语
function GameUI._OnEmoteReceived(state)
    local e = state.lastEmote
    if not e then return end

    -- 获取发送者名字
    local senderName = "?"
    local p = state.players[e.seatIdx]
    if p then
        senderName = p.name or ("玩家" .. e.seatIdx)
    end
    if e.seatIdx == state.mySeat then
        senderName = "你"
    end

    GameUI._ShowToast(string.format("%s: %s", senderName, e.emoteText), C.Secondary)
end

-- ============================================================================
-- Phase 3: Update 驱动（toast 自动隐藏）
-- ============================================================================

--- 由外部 Update 调用（Client 可在 HandleUpdate 中调用此函数）
---@param dt number
function GameUI.Update(dt)
    -- 本地倒计时递减（服务端定期 S2C_TIMER_SYNC 校准）
    if client_ and client_.state then
        local st = client_.state
        if st.timeLeft > 0 and (st.gameState == Config.GameState.BIDDING
                or st.gameState == Config.GameState.CHAR_SELECT) then
            st.timeLeft = math.max(0, st.timeLeft - dt)
            GameUI._UpdateTimer(st)
        end
    end

    -- Toast 自动隐藏
    if toastClearTimer_ > 0 then
        toastClearTimer_ = toastClearTimer_ - dt
        if toastClearTimer_ <= 0 then
            toastPanel_:Hide()
            toastClearTimer_ = 0
        end
    end

    -- 被动通知自动隐藏
    if passiveClearTimer_ > 0 then
        passiveClearTimer_ = passiveClearTimer_ - dt
        if passiveClearTimer_ <= 0 then
            passivePanel_:Hide()
            passiveClearTimer_ = 0
        end
    end
end

-- ============================================================================
-- 更新初始化日志
-- ============================================================================

-- (覆盖 Init 末尾的打印)

-- ============================================================================
-- 清理
-- ============================================================================

function GameUI.Shutdown()
    if client_ then
        client_.onStateChanged = nil
    end
    UI.Shutdown()
    print("[GameUI] Shutdown")
end

return GameUI
