-- ============================================================================
-- CharacterData.lua - 《盲拍暗战》角色与技能数据
-- 8 个角色，每人 1 主动技能 + 1 被动技能
-- ============================================================================
--
-- 技能分类：
--   情报揭示类 — 窥探对手出价 / 预知藏品价值
--   价值标记类 — 标记物品真实价值区间
--   干扰信号类 — 向对手发送虚假信息
--   经济增益类 — 影响余额 / 出价效率
--
-- 主动技能字段：
--   id           唯一标识
--   name         显示名
--   desc         描述
--   category     分类标签
--   cooldown     冷却回合数（使用后需等几轮才能再用）
--   maxUses      整场比赛最多使用次数（-1 = 无限）
--   serverLogic  服务端处理时的标识 key
--
-- 被动技能字段：
--   id, name, desc, category
--   trigger      触发时机（round_start / round_end / bid_phase / reveal）
--   serverLogic  服务端处理时的标识 key
-- ============================================================================

local CharacterData = {}

CharacterData.Characters = {

    -- ================================================================
    -- 1. 林鉴 — 古玩老行家，擅长估价
    -- ================================================================
    {
        id = "lin_jian",
        name = "林鉴",
        title = "古玩鉴定师",
        desc = "家族三代经营古玩铺，一眼便知真伪高低。",
        avatar = "lin_jian",  -- 对应头像资源 key

        activeSkill = {
            id = "appraise",
            name = "精准估价",
            desc = "揭示当前宝箱中一件随机藏品的真实价值区间。",
            category = "价值标记",
            cooldown = 2,
            maxUses = 2,
            serverLogic = "SKILL_APPRAISE",
        },

        passiveSkill = {
            id = "keen_eye",
            name = "慧眼识珠",
            desc = "每轮开始时，自动获知宝箱中最高稀有度藏品的分类。",
            category = "情报揭示",
            trigger = "round_start",
            serverLogic = "PASSIVE_KEEN_EYE",
        },
    },

    -- ================================================================
    -- 2. 苏暮 — 情报贩子，善于刺探
    -- ================================================================
    {
        id = "su_mu",
        name = "苏暮",
        title = "消息灵通人",
        desc = "市井中穿梭的信息掮客，总能打听到别人的底牌。",
        avatar = "su_mu",

        activeSkill = {
            id = "spy",
            name = "窥探底牌",
            desc = "查看一名对手上一轮的出价金额。",
            category = "情报揭示",
            cooldown = 2,
            maxUses = 3,
            serverLogic = "SKILL_SPY",
        },

        passiveSkill = {
            id = "street_smart",
            name = "市井嗅觉",
            desc = "每轮结算时，额外获知自己与第一名的出价差距区间（大/中/小）。",
            category = "情报揭示",
            trigger = "round_end",
            serverLogic = "PASSIVE_STREET_SMART",
        },
    },

    -- ================================================================
    -- 3. 赵谜 — 神秘干扰者，擅长迷惑
    -- ================================================================
    {
        id = "zhao_mi",
        name = "赵谜",
        title = "迷局布局师",
        desc = "没有人知道他说的话哪句是真，哪句是假。",
        avatar = "zhao_mi",

        activeSkill = {
            id = "misinform",
            name = "虚假情报",
            desc = "向一名对手发送伪造的排名信息（如'领先'变成'落后'）。",
            category = "干扰信号",
            cooldown = 2,
            maxUses = 2,
            serverLogic = "SKILL_MISINFORM",
        },

        passiveSkill = {
            id = "fog_of_war",
            name = "战争迷雾",
            desc = "对手的技能如果指向你，有 30% 概率获取到错误信息。",
            category = "干扰信号",
            trigger = "bid_phase",
            serverLogic = "PASSIVE_FOG_OF_WAR",
        },
    },

    -- ================================================================
    -- 4. 方圆 — 理财高手，精打细算
    -- ================================================================
    {
        id = "fang_yuan",
        name = "方圆",
        title = "精算大师",
        desc = "每一文钱都要花在刀刃上，他的账本从不出错。",
        avatar = "fang_yuan",

        activeSkill = {
            id = "budget_boost",
            name = "追加预算",
            desc = "本轮出价时获得额外 15% 的临时余额（不可累加，仅本轮有效）。",
            category = "经济增益",
            cooldown = 3,
            maxUses = 2,
            serverLogic = "SKILL_BUDGET_BOOST",
        },

        passiveSkill = {
            id = "frugal",
            name = "精打细算",
            desc = "每轮结算后，如果你不是最高出价者，返还出价金额的 5%。",
            category = "经济增益",
            trigger = "round_end",
            serverLogic = "PASSIVE_FRUGAL",
        },
    },

    -- ================================================================
    -- 5. 叶星澜 — 直觉型玩家，运气加成
    -- ================================================================
    {
        id = "ye_xinglan",
        name = "叶星澜",
        title = "天命之子",
        desc = "命运似乎总是站在她那边，关键时刻总有奇迹。",
        avatar = "ye_xinglan",

        activeSkill = {
            id = "fortune",
            name = "天命一掷",
            desc = "本轮出价随机获得 -10%~+20% 的出价修正（服务端结算时应用）。",
            category = "经济增益",
            cooldown = 2,
            maxUses = 3,
            serverLogic = "SKILL_FORTUNE",
        },

        passiveSkill = {
            id = "lucky_box",
            name = "锦鲤体质",
            desc = "你赢得的宝箱中，稀有/史诗/传说藏品的出现概率提升 10%。",
            category = "经济增益",
            trigger = "reveal",
            serverLogic = "PASSIVE_LUCKY_BOX",
        },
    },

    -- ================================================================
    -- 6. 陈默 — 沉稳守势型，反情报专家
    -- ================================================================
    {
        id = "chen_mo",
        name = "陈默",
        title = "铁壁防御者",
        desc = "沉默寡言，却让所有试图刺探他的人一无所获。",
        avatar = "chen_mo",

        activeSkill = {
            id = "shield",
            name = "信息屏障",
            desc = "本轮你的出价信息对所有对手技能完全隐藏。",
            category = "干扰信号",
            cooldown = 2,
            maxUses = 2,
            serverLogic = "SKILL_SHIELD",
        },

        passiveSkill = {
            id = "stoic",
            name = "不动如山",
            desc = "你收到的虚假情报会被标记为'可疑'（虽然无法确认真假，但有提示）。",
            category = "干扰信号",
            trigger = "round_end",
            serverLogic = "PASSIVE_STOIC",
        },
    },

    -- ================================================================
    -- 7. 韩笙 — 全场视野型，信息综合分析
    -- ================================================================
    {
        id = "han_sheng",
        name = "韩笙",
        title = "拍场分析师",
        desc = "数据为王，他能从蛛丝马迹中推断出全局走势。",
        avatar = "han_sheng",

        activeSkill = {
            id = "market_scan",
            name = "市场扫描",
            desc = "揭示所有对手当前的剩余余额排名（不显示具体数字）。",
            category = "情报揭示",
            cooldown = 3,
            maxUses = 2,
            serverLogic = "SKILL_MARKET_SCAN",
        },

        passiveSkill = {
            id = "trend_sense",
            name = "趋势嗅觉",
            desc = "每轮开始时，获知本轮宝箱总价值属于'低/中/高'哪个档位。",
            category = "情报揭示",
            trigger = "round_start",
            serverLogic = "PASSIVE_TREND_SENSE",
        },
    },

    -- ================================================================
    -- 8. 阮薇 — 心理战高手，影响对手决策
    -- ================================================================
    {
        id = "ruan_wei",
        name = "阮薇",
        title = "心理博弈家",
        desc = "她的微笑让人捉摸不透，每一句话都是精心设计的陷阱。",
        avatar = "ruan_wei",

        activeSkill = {
            id = "pressure",
            name = "心理施压",
            desc = "选择一名对手，使其下一轮出价时看到一条虚假的'最高出价提示'。",
            category = "干扰信号",
            cooldown = 2,
            maxUses = 2,
            serverLogic = "SKILL_PRESSURE",
        },

        passiveSkill = {
            id = "poker_face",
            name = "扑克脸",
            desc = "你的排名提示对其他玩家的窥探技能显示为比实际高一名。",
            category = "干扰信号",
            trigger = "round_end",
            serverLogic = "PASSIVE_POKER_FACE",
        },
    },
}

-- ============================================================================
-- v1.1.0 新增：角色 9-12（第二波角色）
-- ============================================================================

    -- ================================================================
    -- 9. 神秘收藏家「洞察」- 信息预测型
    -- ================================================================
    {
        id = "mystery_collector",
        name = "神秘收藏家",
        title = "洞察先知",
        desc = "无人知其来历，却总能在关键时刻预见对手的出价。",
        avatar = "mystery_collector",

        activeSkill = {
            id = "price_predict",
            name = "价格预知",
            desc = "预知下一轮对手的平均出价金额（±20% 误差）。",
            category = "情报揭示",
            cooldown = 2,
            maxUses = 3,
            serverLogic = "SKILL_PRICE_PREDICT",
        },

        passiveSkill = {
            id = "timeout_bonus",
            name = "从容不迫",
            desc = "每局首次出价超时（10 秒内未提交）时，自动获得 +5% 的额外余额。",
            category = "经济增益",
            trigger = "round_start",
            serverLogic = "PASSIVE_TIMEOUT_BONUS",
        },
    },

    -- ================================================================
    -- 10. 风险投资人「豪赌」- 高风险高回报型
    -- ================================================================
    {
        id = "venture_investor",
        name = "风险投资人",
        title = "豪赌大师",
        desc = "商场如战场，高风险才有高回报，他深谙此道。",
        avatar = "venture_investor",

        activeSkill = {
            id = "high_stakes",
            name = "孤注一掷",
            desc = "本轮出价效果 ×1.5，但无论胜负，结算时扣除 500 余额。",
            category = "经济增益",
            cooldown = 3,
            maxUses = 2,
            serverLogic = "SKILL_HIGH_STAKES",
        },

        passiveSkill = {
            id = "profit_share",
            name = "利润分成",
            desc = "如果本轮出价排名第 1，结算时额外获得 +300 余额。",
            category = "经济增益",
            trigger = "round_end",
            serverLogic = "PASSIVE_PROFIT_SHARE",
        },
    },

    -- ================================================================
    -- 11. 心理学家「读心」- 心理反制型
    -- ================================================================
    {
        id = "psychologist",
        name = "心理学家",
        title = "读心大师",
        desc = "一眼便能看穿对手的心思，并巧妙地加以利用。",
        avatar = "psychologist",

        activeSkill = {
            id = "mind_read",
            name = "读心术",
            desc = "窥探一名对手当前的剩余余额（±1000 误差）。",
            category = "情报揭示",
            cooldown = 2,
            maxUses = 3,
            serverLogic = "SKILL_MIND_READ",
        },

        passiveSkill = {
            id = "counter_strike",
            name = "反制之盾",
            desc = "被对手技能命中时，有 30% 概率反制成功，使技能效果失效。",
            category = "干扰信号",
            trigger = "bid_phase",
            serverLogic = "PASSIVE_COUNTER_STRIKE",
        },
    },

    -- ================================================================
    -- 12. 时间管理大师「时停」- 时间控制型
    -- ================================================================
    {
        id = "time_master",
        name = "时间管理大师",
        title = "时停先驱",
        desc = "时间是他最忠实的盟友，每一秒都能被精准掌控。",
        avatar = "time_master",

        activeSkill = {
            id = "time_stop",
            name = "时间膨胀",
            desc = "本轮自己的出价时限延长 10 秒（不受其他效果影响）。",
            category = "经济增益",
            cooldown = 2,
            maxUses = 3,
            serverLogic = "SKILL_TIME_STOP",
        },

        passiveSkill = {
            id = "time_rewind",
            name = "时间回溯",
            desc = "每局自动获得 1 次机会：当出价提交后发现决策失误时，可撤回并重新出价（限本轮内）。",
            category = "经济增益",
            trigger = "round_start",
            serverLogic = "PASSIVE_TIME_REWIND",
        },
    },

}

--- 技能 serverLogic → 角色 id 的反查表（运行时构建）
CharacterData._skillToCharacter = nil

--- 获取角色数据
---@param characterId string
---@return table|nil
function CharacterData.GetCharacter(characterId)
    for _, c in ipairs(CharacterData.Characters) do
        if c.id == characterId then return c end
    end
    return nil
end

--- 获取所有角色 id 列表
---@return string[]
function CharacterData.GetAllIds()
    local ids = {}
    for _, c in ipairs(CharacterData.Characters) do
        ids[#ids + 1] = c.id
    end
    return ids
end

--- 根据 serverLogic key 查找对应角色
---@param logicKey string
---@return table|nil character, string|nil skillType ("active"|"passive")
function CharacterData.FindBySkillLogic(logicKey)
    for _, c in ipairs(CharacterData.Characters) do
        if c.activeSkill.serverLogic == logicKey then
            return c, "active"
        end
        if c.passiveSkill.serverLogic == logicKey then
            return c, "passive"
        end
    end
    return nil, nil
end

return CharacterData
