-- ============================================================================
-- Config.lua - 《盲拍暗战》全局配置
-- ============================================================================

local Config = {}

-- 游戏基本信息
Config.Title = "盲拍暗战"
Config.Version = "1.0.0"
Config.ReleaseDate = "2026-06-19"
Config.ScreenOrientation = "landscape"  -- 横屏（移动端更适合竞拍操作）

-- ============================================================================
-- 竞拍规则
-- ============================================================================
Config.Auction = {
    MaxPlayers = 4,           -- 最大玩家数
    TotalRounds = 5,          -- 总回合数
    BidTimeLimit = 15,        -- 每轮出价时限（秒）
    PrepareTime = 3,          -- 轮间准备时间（秒）
    ResultShowTime = 5,       -- 结果展示时间（秒）
    RevealTime = 8,           -- 开箱展示时间（秒）
    MinBid = 0,               -- 最低出价
    InitialFunds = 10000,     -- 初始余额

    -- 速胜倍率（第1-4轮，第一名出价 >= 第二名出价 * 倍率 即速胜）
    SpeedWinMultipliers = {
        [1] = 2.00,   -- 第1轮: 200%
        [2] = 1.60,   -- 第2轮: 160%
        [3] = 1.40,   -- 第3轮: 140%
        [4] = 1.20,   -- 第4轮: 120%
    },
}

-- ============================================================================
-- 模糊信息提示（回合结算时给玩家的排名提示）
-- ============================================================================
Config.HintMessages = {
    [1] = "领先",     -- 第1名
    [2] = "接近",     -- 第2名
    [3] = "落后",     -- 第3名
    [4] = "垫底",     -- 第4名
}

-- ============================================================================
-- 藏品稀有度配置
-- ============================================================================
Config.Rarity = {
    { name = "普通", color = {180, 180, 180}, weight = 50 },
    { name = "稀有", color = {80, 160, 255},  weight = 30 },
    { name = "史诗", color = {180, 80, 255},  weight = 15 },
    { name = "传说", color = {255, 180, 30},  weight = 5  },
}

-- ============================================================================
-- 拍卖厅（4 个主题厅，入场门槛递增）
-- ============================================================================
Config.AuctionHalls = {
    {
        id = "hall_beginner",
        name = "新手厅",
        desc = "适合初学者练手，藏品价值平稳。",
        entryFee = 100,
        fundRange = {8000, 12000},
        itemValueRange = {100, 3000},
        rarityWeights = { 60, 28, 10, 2 },  -- 普通/稀有/史诗/传说
        itemCountPerBox = 5,
    },
    {
        id = "hall_standard",
        name = "雅集厅",
        desc = "文人雅士的聚会，偶有珍品现身。",
        entryFee = 500,
        fundRange = {12000, 18000},
        itemValueRange = {300, 6000},
        rarityWeights = { 45, 32, 17, 6 },
        itemCountPerBox = 5,
    },
    {
        id = "hall_premium",
        name = "珍宝阁",
        desc = "高端拍卖场，常有史诗级藏品亮相。",
        entryFee = 2000,
        fundRange = {20000, 30000},
        itemValueRange = {800, 10000},
        rarityWeights = { 30, 35, 25, 10 },
        itemCountPerBox = 6,
    },
    {
        id = "hall_legend",
        name = "天工殿",
        desc = "传说中的顶级拍卖殿堂，一掷千金。",
        entryFee = 5000,
        fundRange = {40000, 60000},
        itemValueRange = {2000, 14000},
        rarityWeights = { 15, 30, 35, 20 },
        itemCountPerBox = 7,
    },
}

-- ============================================================================
-- UI 配色方案
-- ============================================================================
Config.Colors = {
    Primary     = {70, 130, 240},     -- 主色调（蓝）
    Secondary   = {100, 200, 160},    -- 辅助色（青）
    Accent      = {255, 180, 50},     -- 强调色（金）
    Danger      = {240, 70, 70},      -- 警告色（红）
    Background  = {20, 25, 35},       -- 背景深色
    Surface     = {35, 42, 58},       -- 卡片/面板色
    TextPrimary = {240, 240, 250},    -- 主文字
    TextSecondary = {160, 170, 190},  -- 次要文字
    Success     = {80, 200, 120},     -- 成功色
    SpeedWin    = {255, 215, 0},      -- 速胜金色
}

-- ============================================================================
-- 网络配置
-- ============================================================================
Config.Network = {
    MaxPlayers = 4,
    TickRate = 20,
}

-- ============================================================================
-- 角色技能配置
-- ============================================================================
Config.Skill = {
    SelectTimeLimit = 15,         -- 角色选择时限（秒）
    FogOfWarChance  = 0.30,       -- 赵谜·战争迷雾 被动概率
    FrugalRefund    = 0.05,       -- 方圆·精打细算 返还比例
    BudgetBoost     = 0.15,       -- 方圆·追加预算 临时余额比例
    FortuneRange    = {-0.10, 0.20}, -- 叶星澜·天命一掷 修正范围
    LuckyBoxBonus   = 0.10,       -- 叶星澜·锦鲤体质 稀有度提升
    GapThresholds   = {           -- 苏暮·市井嗅觉 差距档位
        small = 0.10,             -- 差距 <= 10% 总出价 → "小"
        medium = 0.25,            -- 差距 <= 25% → "中"，其余 → "大"
    },
    BoxValueTiers = {             -- 韩笙·趋势嗅觉 价值档位
        low  = 0.33,              -- 总价值在所有可能中的低 33%
        mid  = 0.66,              -- 中 33%~66%
        -- 高 = 66%+
    },
}

-- ============================================================================
-- Phase 3: 经济系统
-- ============================================================================
Config.Economy = {
    InitialBalance = 5000,        -- 新玩家初始余额
    SellPriceRatio = 0.6,         -- 出售藏品获得价值的 60%
    WinnerBonusRatio = 0.1,       -- 获胜者额外奖励：出价总额的 10% 返现
}

-- ============================================================================
-- Phase 3: 表情/快捷语
-- ============================================================================
Config.Emotes = {
    { id = "e_taunt",    text = "不自量力！" },
    { id = "e_praise",   text = "好眼光！" },
    { id = "e_nervous",  text = "好紧张..." },
    { id = "e_rich",     text = "钱不是问题！" },
    { id = "e_bluff",    text = "这轮我必拿下！" },
    { id = "e_regret",   text = "出价太高了..." },
    { id = "e_laugh",    text = "哈哈哈！" },
    { id = "e_gg",       text = "GG，打得好！" },
}

-- ============================================================================
-- 游戏状态枚举
-- ============================================================================
Config.GameState = {
    WAITING        = "waiting",        -- 等待玩家加入
    CHAR_SELECT    = "char_select",    -- 角色选择阶段
    PREPARING      = "preparing",      -- 回合准备中
    BIDDING        = "bidding",        -- 出价中
    SETTLING       = "settling",       -- 结算中
    REVEALING      = "revealing",      -- 开箱展示
    GAME_OVER      = "game_over",      -- 比赛结束
}

-- ============================================================================
-- v1.0.0 新增：成就系统
-- ============================================================================
Config.Achievements = {
    {
        id = "first_win",
        name = "初次胜利",
        desc = "赢得第一场比赛。",
        reward = 1000,
        checkType = "win_count",
        checkValue = 1,
    },
    {
        id = "ten_wins",
        name = "小有所成",
        desc = "累计获胜10场。",
        reward = 5000,
        checkType = "win_count",
        checkValue = 10,
    },
    {
        id = "speed_win",
        name = "速胜专家",
        desc = "触发一次速胜。",
        reward = 500,
        checkType = "speed_win_count",
        checkValue = 1,
    },
    {
        id = "collect_100",
        name = "收藏家",
        desc = "累计收藏100件藏品。",
        reward = 2000,
        checkType = "collected_items",
        checkValue = 100,
    },
    {
        id = "legend_first",
        name = "传奇首现",
        desc = "首次获得传说级藏品。",
        reward = 3000,
        checkType = "legend_count",
        checkValue = 1,
    },
    {
        id = "bid_master",
        name = "精准出价",
        desc = "单局5次出价均排前2名。",
        reward = 1500,
        checkType = "top2_rounds",
        checkValue = 5,
    },
    {
        id = "frugal",
        name = "精打细算",
        desc = "单局结束时余额大于初始资金。",
        reward = 1000,
        checkType = "positive_gain",
        checkValue = 1,
    },
    {
        id = "hall_master",
        name = "殿堂级藏家",
        desc = "在所有4个拍卖厅都获胜过。",
        reward = 5000,
        checkType = "hall_victory",
        checkValue = 4,
    },
    {
        id = "hundred_games",
        name = "百战不殆",
        desc = "累计参与100局比赛。",
        reward = 8000,
        checkType = "game_count",
        checkValue = 100,
    },
    {
        id = "rich_collector",
        name = "财大气粗",
        desc = "累计收藏藏品总价值超过10万。",
        reward = 10000,
        checkType = "collection_value",
        checkValue = 100000,
    },
}

-- ============================================================================
-- v1.0.0 新增：每日任务系统
-- ============================================================================
Config.DailyMissions = {
    {
        id = "daily_first_win",
        name = "每日首胜",
        desc = "赢得1场比赛。",
        reward = 500,
        checkType = "win_count",
        checkValue = 1,
        refreshDaily = true,
    },
    {
        id = "daily_three_games",
        name = "参与三局",
        desc = "完成3场比赛。",
        reward = 300,
        checkType = "game_count",
        checkValue = 3,
        refreshDaily = true,
    },
    {
        id = "daily_use_skills",
        name = "技能大师",
        desc = "单场使用5次主动技能。",
        reward = 200,
        checkType = "skill_uses",
        checkValue = 5,
        refreshDaily = true,
    },
    {
        id = "daily_legend_item",
        name = "开箱乐趣",
        desc = "获得一件传说级藏品。",
        reward = 800,
        checkType = "legend_count",
        checkValue = 1,
        refreshDaily = true,
    },
}

-- ============================================================================
-- v1.0.0 新增：动画时长统一
-- ============================================================================
Config.Animations = {
    UITransition   = 0.3,    -- UI 过渡动画（秒）
    BidSubmit      = 0.5,    -- 出价提交动画
    RevealItem     = 0.8,    -- 开箱揭示动画
    FadeInOut      = 0.2,    -- 淡入淡出
    ToastDuration  = 2.0,    -- Toast 显示时间
    ToastFast      = 1.0,    -- 快速 Toast
}

return Config
