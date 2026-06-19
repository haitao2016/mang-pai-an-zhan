-- ============================================================================
-- Config.lua - 《盲拍暗战》全局配置
-- ============================================================================

local Config = {}

-- 游戏基本信息
Config.Title = "盲拍暗战"
Config.Version = "1.2.0"
Config.ReleaseDate = "2026-08-19"
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

-- ============================================================================
-- v1.1.0 新增：赛季系统配置
-- ============================================================================
Config.Seasons = {
    Name           = "第一赛季·初露锋芒",
    StartDate      = "2026-06-19",
    DurationDays   = 14,       -- 每赛季 14 天
    MaxLevel       = 50,       -- 最高 50 级
    BaseExpPerLevel = 100,     -- 第 1 级升级所需基础经验
    ExpGrowthFactor = 1.2,     -- 每级经验递增系数
    ExpPerWin      = 50,       -- 胜利获得经验
    ExpPerLose     = 20,       -- 失败获得经验
    ExpPerItem     = 10,       -- 获得藏品基础经验
    ExpPerSkill    = 5,        -- 使用技能获得经验

    -- 赛季奖励表（每 5 级一个关键奖励点）
    Rewards = {
        [1]  = { type = "gold",  amount = 100,  name = "新手礼包" },
        [5]  = { type = "gold",  amount = 300,  name = "成长奖励" },
        [10] = { type = "gold",  amount = 500,  name = "小有所成" },
        [15] = { type = "item",  rarity = 2,    name = "稀有藏品" },
        [20] = { type = "gold",  amount = 1000, name = "经验丰富" },
        [25] = { type = "title", id = "T001",   name = "竞拍达人" },
        [30] = { type = "gold",  amount = 2000, name = "精英收藏家" },
        [35] = { type = "item",  rarity = 3,    name = "史诗藏品" },
        [40] = { type = "gold",  amount = 5000, name = "大师级别" },
        [45] = { type = "title", id = "T002",   name = "传奇收藏家" },
        [50] = { type = "item",  rarity = 4,    name = "传说藏品" }
    },

    -- 赛季专属成就（与 AchievementSystem 集成）
    SeasonalAchievements = {
        { id = "season_max_level", name = "赛季满级",   desc = "在任一赛季达到 50 级", reward = 2000 },
        { id = "season_games_20",  name = "赛季活跃",   desc = "在任一赛季参与 20 场", reward = 500 },
        { id = "season_wins_10",   name = "赛季胜利",   desc = "在任一赛季获胜 10 场", reward = 800 }
    }
}

-- ============================================================================
-- v1.1.0 新增：周任务系统配置
-- ============================================================================
Config.WeeklyMissions = {
    RefreshDay     = 1,         -- 每周一刷新（1=周一，7=周日）
    MissionCount   = 3,         -- 每周 3 个任务
    BonusMultiplier = 1.5,      -- 奖励倍率（比每日任务更高）

    Missions = {
        {
            id = "weekly_wins_5",
            name = "周胜场目标",
            desc = "本周累计获得 5 场胜利",
            target = 5,
            reward = 1000,
            trigger = "game_win"
        },
        {
            id = "weekly_items_10",
            name = "收藏家挑战",
            desc = "本周累计获得 10 件藏品",
            target = 10,
            reward = 800,
            trigger = "item_collect"
        },
        {
            id = "weekly_skills_20",
            name = "技能大师",
            desc = "本周累计使用 20 次技能",
            target = 20,
            reward = 500,
            trigger = "skill_use"
        }
    }
}

-- ============================================================================
-- v1.1.0 新增：限时活动模式配置
-- ============================================================================
Config.EventModes = {
    BlindRush = {
        Name         = "极速竞拍",
        Description  = "快节奏的 3 轮暗拍，时间紧迫但奖励丰厚！",
        Rounds       = 3,          -- 仅 3 轮
        BidTimeLimit = 10,         -- 每轮 10 秒出价
        InitialFunds = 5000,       -- 初始资金
        Enabled      = true,
        TimeWindow   = { 20, 22 }, -- 每日 20:00 - 22:00
        RewardBonus  = 2.0,        -- 奖励倍率
        BonusExp     = 100         -- 额外赛季经验
    }
}

-- ============================================================================
-- v1.1.0 新增：好友系统配置
-- ============================================================================
Config.Friends = {
    MaxFriends     = 50,        -- 最大好友数
    OnlineTimeout  = 300,       -- 5 分钟无活动视为离线
    InviteExpire   = 86400,     -- 邀请 24 小时过期
    FriendBonus    = 10         -- 与好友游戏的额外奖励
}

-- ============================================================================
-- v1.1.0 新增：本地排行榜配置
-- ============================================================================
Config.Leaderboards = {
    UpdateInterval = 300,       -- 每 5 分钟更新
    MaxEntries     = 100,       -- 每个排行榜最多 100 条

    Boards = {
        { id = "wins",      name = "胜场榜",   desc = "累计胜场数排名" },
        { id = "winrate",   name = "胜率榜",   desc = "游戏胜率排名" },
        { id = "items",     name = "收藏榜",   desc = "获得藏品总价值" },
        { id = "games",     name = "参与榜",   desc = "参与游戏次数" },
        { id = "seasonExp", name = "赛季榜",   desc = "当前赛季经验值" }
    }
}

-- ============================================================================
-- v1.1.0 新增：角色合作被动配置
-- ============================================================================
Config.CharacterSynergies = {
    {
        chars    = { 1, 2 },       -- 角色 1 + 角色 2
        name     = "经典组合",
        desc     = "双方余额 +500",
        effect   = { type = "balance", amount = 500 }
    },
    {
        chars    = { 9, 11 },      -- 神秘收藏家 + 心理学家
        name     = "情报网",
        desc     = "信息精度 +10%",
        effect   = { type = "info_precision", amount = 0.1 }
    },
    {
        chars    = { 3, 5 },
        name     = "策略大师",
        desc     = "每轮额外 +200 余额",
        effect   = { type = "per_round_balance", amount = 200 }
    }
}

-- ============================================================================
-- v1.1.0 新增：玩家头像与个性化配置
-- ============================================================================
Config.Profiles = {
    DefaultAvatar  = "A001",

    Avatars = {
        { id = "A001", name = "新手玩家",   unlocked = true,   image = "default" },
        { id = "A002", name = "竞拍达人",   unlocked = false,  requireAchievement = "ach_first_win" },
        { id = "A003", name = "收藏家",     unlocked = false,  requireAchievement = "collect_items_100" },
        { id = "A004", name = "神秘人",     unlocked = false,  requireSeasonLevel = 10 },
        { id = "A005", name = "传奇猎手",   unlocked = false,  requireSeasonLevel = 30 },
        { id = "A006", name = "大师",       unlocked = false,  requireSeasonLevel = 50 }
    },

    Titles = {
        { id = "T001", name = "竞拍达人",   desc = "赛季达到 25 级" },
        { id = "T002", name = "传奇收藏家", desc = "赛季达到 45 级" },
        { id = "T003", name = "不败神话",   desc = "单场连胜 10 场" },
        { id = "T004", name = "史诗猎人",   desc = "获得 50 件史诗以上藏品" }
    }
}

-- ============================================================================
-- v1.1.0 新增：藏品套装收集配置
-- ============================================================================
Config.ItemSets = {
    {
        id = "set_eastern",
        name = "东方艺术系列",
        description = "集齐东方艺术品系列藏品",
        itemCount = 10,
        reward = { type = "gold", amount = 5000 }
    },
    {
        id = "set_western",
        name = "西洋收藏系列",
        description = "集齐西洋收藏系列藏品",
        itemCount = 10,
        reward = { type = "gold", amount = 5000 }
    },
    {
        id = "set_rare",
        name = "稀有收藏",
        description = "收集 100 件稀有以上（含）藏品",
        itemCount = 100,
        minRarity = 2,
        reward = { type = "title", id = "T005" }
    }
}

-- ============================================================================
-- v1.2.0 版本信息更新
-- ============================================================================
Config.Version = "1.2.0"
Config.ReleaseDate = "2026-08-19"
Config.ReleaseNotes = [=[
v1.2.0 主要更新：
  · 锦标赛系统（单败淘汰制，8/16 人参赛）
  · 2v2 团队战模式（组队对战，团队资金池）
  · 藏品交易市场（玩家自由交易藏品）
  · 角色皮肤系统（12 个角色皮肤，套装效果）
  · 跨平台联机优化
  · UI/UX 进一步优化
]=]

-- ============================================================================
-- v1.2.0 新增：锦标赛系统配置
-- ============================================================================
Config.Tournament = {
    -- 赛制
    Formats = {
        { id = "single_elimination", name = "单败淘汰", teams = 8 },
        { id = "double_elimination", name = "双败淘汰", teams = 8 },
        { id = "swiss", name = "瑞士轮", teams = 8 }
    },

    -- 奖励配置
    Rewards = {
        { place = 1, percent = 50, title = "冠军" },
        { place = 2, percent = 25, title = "亚军" },
        { place = 3, percent = 12, title = "四强" },
        { place = 5, percent = 6, title = "八强" },
        { place = 9, percent = 4, title = "十六强" }
    },

    -- 锦标赛类型
    Types = {
        { id = "daily", name = "每日锦标赛", minPlayers = 8, prize = 5000, fee = 100 },
        { id = "weekly", name = "周末杯赛", minPlayers = 16, prize = 20000, fee = 500 },
        { id = "championship", name = "冠军赛", minPlayers = 64, prize = 100000, fee = 2000 }
    }
}

-- ============================================================================
-- v1.2.0 新增：团队战配置
-- ============================================================================
Config.TeamBattle = {
    MaxTeamSize = 2,
    MatchConfig = {
        rounds = 5,
        bidTimeLimit = 15,
        initialBalance = 10000
    },

    -- 团队技能
    TeamSkills = {
        {
            id = "team_rally",
            name = "团队激励",
            desc = "本回合所有成员出价 +10%",
            cooldown = 2,
            available = true
        },
        {
            id = "team_shield",
            name = "团队护盾",
            desc = "本回合不受对方团队技能影响",
            cooldown = 3,
            available = true
        },
        {
            id = "team_insight",
            name = "团队洞察",
            desc = "本回合可见对方总出价",
            cooldown = 2,
            available = true
        }
    },

    -- 团队成就
    TeamAchievements = {
        { id = "first_blood", name = "首战告捷", desc = "赢得第一场团队战" },
        { id = "team_10_wins", name = "团队新星", desc = "团队累计获得 10 场胜利" },
        { id = "perfect_season", name = "完美赛季", desc = "单赛季团队无败绩" }
    }
}

-- ============================================================================
-- v1.2.0 新增：交易市场配置
-- ============================================================================
Config.Trade = {
    -- 交易费用
    FeeRate = 0.05,           -- 5% 手续费
    MinPrice = 10,            -- 最低挂牌价
    MaxPrice = 1000000,      -- 最高挂牌价

    -- 限制
    MaxListingsPerPlayer = 10,
    MaxBlacklist = 20,
    ListingExpireDays = 7,

    -- 市场分类
    Categories = {
        { id = "all", name = "全部" },
        { id = "eastern", name = "东方艺术" },
        { id = "western", name = "西洋收藏" },
        { id = "rare", name = "稀有专属" }
    },

    -- 排序选项
    SortOptions = {
        { id = "recent", name = "最新" },
        { id = "price_asc", name = "价格升序" },
        { id = "price_desc", name = "价格降序" },
        { id = "rarity", name = "稀有度" }
    }
}

-- ============================================================================
-- v1.2.0 新增：角色皮肤配置
-- ============================================================================
Config.Skins = {
    -- 角色 1 的皮肤
    ["budget_master"] = {
        {
            id = "budget_master_default",
            name = "默认",
            rarity = 1,
            description = "精打细算大师的经典装扮",
            price = 0,
            unlockCondition = "default"
        },
        {
            id = "budget_master_gold",
            name = "金色传说",
            rarity = 4,
            description = "金光闪闪的华丽装扮",
            price = 2000,
            unlockCondition = "purchase",
            previewImage = "skin_preview_gold"
        }
    },

    -- 通用皮肤（所有角色可用）
    universal = {
        {
            id = "skin_holiday",
            name = "节日限定",
            rarity = 5,
            description = "节日特别版皮肤",
            price = 0,
            unlockCondition = "event",
            availableFrom = "2026-12-25",
            availableTo = "2027-01-05"
        },
        {
            id = "skin_season_1",
            name = "第一赛季专属",
            rarity = 5,
            description = "第一赛季限定皮肤",
            price = 0,
            unlockCondition = "season_level",
            requireSeasonLevel = 50
        }
    }
}

-- ============================================================================
-- v1.2.0 新增：皮肤套装配置
-- ============================================================================
Config.SkinSets = {
    {
        id = "set_master",
        name = "大师套装",
        description = "集齐所有角色的大师皮肤",
        skins = { "budget_master_gold", "time_master_gold" },
        reward = { type = "gold", amount = 5000 }
    },
    {
        id = "set_limited",
        name = "限定套装",
        description = "集齐所有限定皮肤",
        skins = { "skin_holiday", "skin_season_1" },
        reward = { type = "title", id = "T100" }
    }
}

return Config
