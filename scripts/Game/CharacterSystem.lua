-- ============================================================================
-- CharacterSystem.lua - 角色选择 + 技能状态管理（服务端）
-- 管理每个座位的角色选择、技能 CD、使用次数、被动触发
-- ============================================================================

local Config        = require("Config")
local CharacterData = require("Data.CharacterData")

---@class CharacterSystem
local CharacterSystem = {}
CharacterSystem.__index = CharacterSystem

--- 创建角色系统
---@param maxSeats number 最大座位数
---@return CharacterSystem
function CharacterSystem.New(maxSeats)
    local self = setmetatable({}, CharacterSystem)
    self.maxSeats = maxSeats or 4

    -- 每个座位的角色信息
    -- seats[seatIdx] = {
    --   characterId = "lin_jian",
    --   characterData = <CharacterData entry>,
    --   activeCD     = 0,       -- 主动技能当前冷却剩余回合
    --   activeUses   = 0,       -- 主动技能已使用次数
    --   shielded     = false,   -- 本轮是否开启信息屏障
    --   budgetBoost  = false,   -- 本轮是否开启追加预算
    --   fortuneActive = false,  -- 本轮是否开启天命一掷
    --   pressureTarget = nil,   -- 心理施压的目标座位
    --   misinformTarget = nil,  -- 虚假情报的目标座位
    -- }
    self.seats = {}

    -- 已被选择的角色 id 集合（防重复选）
    self.selectedIds = {}

    print("[CharacterSystem] Created, maxSeats=" .. self.maxSeats)
    return self
end

--- 重置所有座位（新一局开始时）
function CharacterSystem:Reset()
    self.seats = {}
    self.selectedIds = {}
    print("[CharacterSystem] Reset")
end

--- 玩家选择角色
---@param seatIdx number
---@param characterId string
---@return boolean success
---@return string|nil errorMsg
function CharacterSystem:SelectCharacter(seatIdx, characterId)
    if seatIdx < 1 or seatIdx > self.maxSeats then
        return false, "无效座位"
    end

    -- 检查是否已被他人选择
    if self.selectedIds[characterId] and self.selectedIds[characterId] ~= seatIdx then
        return false, "该角色已被其他玩家选择"
    end

    -- 查找角色数据
    local charData = CharacterData.GetCharacter(characterId)
    if not charData then
        return false, "角色不存在: " .. tostring(characterId)
    end

    -- 如果该座位之前选了其他角色，释放
    if self.seats[seatIdx] and self.seats[seatIdx].characterId then
        self.selectedIds[self.seats[seatIdx].characterId] = nil
    end

    -- 注册选择
    self.selectedIds[characterId] = seatIdx
    self.seats[seatIdx] = {
        characterId   = characterId,
        characterData = charData,
        activeCD      = 0,
        activeUses    = 0,
        shielded      = false,
        budgetBoost   = false,
        fortuneActive = false,
        pressureTarget  = nil,
        misinformTarget = nil,
    }

    print(string.format("[CharacterSystem] Seat %d selected: %s (%s)",
        seatIdx, charData.name, characterId))
    return true, nil
end

--- AI 自动选角（从剩余角色中随机）
---@param seatIdx number
---@return string|nil characterId 选择的角色 id
function CharacterSystem:AutoSelectForAI(seatIdx)
    local allIds = CharacterData.GetAllIds()
    -- 随机打乱
    for i = #allIds, 2, -1 do
        local j = math.random(1, i)
        allIds[i], allIds[j] = allIds[j], allIds[i]
    end
    -- 选第一个未被占用的
    for _, id in ipairs(allIds) do
        if not self.selectedIds[id] then
            local ok, _ = self:SelectCharacter(seatIdx, id)
            if ok then return id end
        end
    end
    -- 全部被选完不太可能（8 角色 > 4 座位）但保底
    return nil
end

--- 获取座位的角色数据
---@param seatIdx number
---@return table|nil seatInfo
function CharacterSystem:GetSeatInfo(seatIdx)
    return self.seats[seatIdx]
end

--- 获取角色名称
---@param seatIdx number
---@return string
function CharacterSystem:GetCharacterName(seatIdx)
    local info = self.seats[seatIdx]
    if info and info.characterData then
        return info.characterData.name
    end
    return "未知"
end

-- ============================================================================
-- 主动技能
-- ============================================================================

--- 尝试使用主动技能
---@param seatIdx number
---@param targetSeat number|nil 部分技能需要指定目标
---@return boolean success
---@return string|nil errorMsg
---@return string|nil serverLogic 技能标识
function CharacterSystem:UseActiveSkill(seatIdx, targetSeat)
    local info = self.seats[seatIdx]
    if not info then return false, "未选择角色", nil end

    local skill = info.characterData.activeSkill

    -- 冷却检查
    if info.activeCD > 0 then
        return false, string.format("技能冷却中（剩余 %d 轮）", info.activeCD), nil
    end

    -- 使用次数检查
    if skill.maxUses > 0 and info.activeUses >= skill.maxUses then
        return false, "技能使用次数已用完", nil
    end

    -- 需要目标的技能检查
    local needsTarget = (skill.serverLogic == "SKILL_SPY"
        or skill.serverLogic == "SKILL_MISINFORM"
        or skill.serverLogic == "SKILL_PRESSURE"
        or skill.serverLogic == "SKILL_MARKET_SCAN")

    if needsTarget and skill.serverLogic ~= "SKILL_MARKET_SCAN" then
        if not targetSeat or targetSeat < 1 or targetSeat > self.maxSeats then
            return false, "需要指定目标玩家", nil
        end
        if targetSeat == seatIdx then
            return false, "不能对自己使用", nil
        end
    end

    -- 消耗
    info.activeUses = info.activeUses + 1
    info.activeCD = skill.cooldown

    -- 设置本轮标记
    if skill.serverLogic == "SKILL_SHIELD" then
        info.shielded = true
    elseif skill.serverLogic == "SKILL_BUDGET_BOOST" then
        info.budgetBoost = true
    elseif skill.serverLogic == "SKILL_FORTUNE" then
        info.fortuneActive = true
    elseif skill.serverLogic == "SKILL_PRESSURE" then
        info.pressureTarget = targetSeat
    elseif skill.serverLogic == "SKILL_MISINFORM" then
        info.misinformTarget = targetSeat
    end

    print(string.format("[CharacterSystem] Seat %d used skill: %s (target=%s)",
        seatIdx, skill.name, tostring(targetSeat)))

    return true, nil, skill.serverLogic
end

--- 每轮结束时更新冷却并清除本轮临时状态
function CharacterSystem:OnRoundEnd()
    for seatIdx, info in pairs(self.seats) do
        if info.activeCD > 0 then
            info.activeCD = info.activeCD - 1
        end
        -- 清除本轮临时状态
        info.shielded = false
        info.budgetBoost = false
        info.fortuneActive = false
        info.pressureTarget = nil
        info.misinformTarget = nil
    end
end

-- ============================================================================
-- 被动技能查询
-- ============================================================================

--- 获取所有应在指定时机触发的被动技能
---@param trigger string "round_start"|"round_end"|"bid_phase"|"reveal"
---@return table[] entries { seatIdx, serverLogic, characterData }
function CharacterSystem:GetPassivesByTrigger(trigger)
    local result = {}
    for seatIdx, info in pairs(self.seats) do
        if info.characterData then
            local passive = info.characterData.passiveSkill
            if passive.trigger == trigger then
                table.insert(result, {
                    seatIdx       = seatIdx,
                    serverLogic   = passive.serverLogic,
                    characterData = info.characterData,
                })
            end
        end
    end
    return result
end

--- 检查目标座位是否有信息屏障
---@param targetSeat number
---@return boolean
function CharacterSystem:IsShielded(targetSeat)
    local info = self.seats[targetSeat]
    return info and info.shielded or false
end

--- 检查目标座位是否有战争迷雾（被动干扰）
---@param targetSeat number
---@return boolean shouldDistort 是否应该扭曲信息
function CharacterSystem:ShouldFogOfWar(targetSeat)
    local info = self.seats[targetSeat]
    if not info or not info.characterData then return false end
    if info.characterData.passiveSkill.serverLogic ~= "PASSIVE_FOG_OF_WAR" then
        return false
    end
    return math.random() < Config.Skill.FogOfWarChance
end

--- 检查是否有追加预算
---@param seatIdx number
---@return boolean
function CharacterSystem:HasBudgetBoost(seatIdx)
    local info = self.seats[seatIdx]
    return info and info.budgetBoost or false
end

--- 检查是否有天命一掷
---@param seatIdx number
---@return boolean
function CharacterSystem:HasFortune(seatIdx)
    local info = self.seats[seatIdx]
    return info and info.fortuneActive or false
end

--- 计算天命一掷的出价修正
---@return number multiplier (如 1.15 表示 +15%)
function CharacterSystem:RollFortune()
    local range = Config.Skill.FortuneRange
    local bonus = range[1] + math.random() * (range[2] - range[1])
    return 1.0 + bonus
end

--- 获取扑克脸偏移（被动：排名显示比实际高一名）
---@param seatIdx number
---@return number offset (0 或 -1)
function CharacterSystem:GetPokerFaceOffset(seatIdx)
    local info = self.seats[seatIdx]
    if not info or not info.characterData then return 0 end
    if info.characterData.passiveSkill.serverLogic == "PASSIVE_POKER_FACE" then
        return -1  -- 排名显示更好（数字更小）
    end
    return 0
end

--- 检查是否有锦鲤体质（用于开箱）
---@param seatIdx number
---@return number bonus 稀有度提升比例（0 表示无）
function CharacterSystem:GetLuckyBonus(seatIdx)
    local info = self.seats[seatIdx]
    if not info or not info.characterData then return 0 end
    if info.characterData.passiveSkill.serverLogic == "PASSIVE_LUCKY_BOX" then
        return Config.Skill.LuckyBoxBonus
    end
    return 0
end

--- 获取精打细算返还比例
---@param seatIdx number
---@return number refundRate (0 表示无)
function CharacterSystem:GetFrugalRate(seatIdx)
    local info = self.seats[seatIdx]
    if not info or not info.characterData then return 0 end
    if info.characterData.passiveSkill.serverLogic == "PASSIVE_FRUGAL" then
        return Config.Skill.FrugalRefund
    end
    return 0
end

--- 获取心理施压目标
---@param seatIdx number
---@return number|nil targetSeat
function CharacterSystem:GetPressureTarget(seatIdx)
    local info = self.seats[seatIdx]
    return info and info.pressureTarget or nil
end

--- 获取虚假情报目标
---@param seatIdx number
---@return number|nil targetSeat
function CharacterSystem:GetMisinformTarget(seatIdx)
    local info = self.seats[seatIdx]
    return info and info.misinformTarget or nil
end

--- 获取座位的主动技能状态摘要（用于发送给客户端）
---@param seatIdx number
---@return table { skillId, skillName, cd, usesLeft, maxUses }
function CharacterSystem:GetActiveSkillStatus(seatIdx)
    local info = self.seats[seatIdx]
    if not info or not info.characterData then
        return { skillId = "", skillName = "", cd = 0, usesLeft = 0, maxUses = 0 }
    end
    local skill = info.characterData.activeSkill
    local usesLeft = skill.maxUses > 0 and (skill.maxUses - info.activeUses) or -1
    return {
        skillId   = skill.id,
        skillName = skill.name,
        cd        = info.activeCD,
        usesLeft  = usesLeft,
        maxUses   = skill.maxUses,
    }
end

-- ============================================================================
-- v1.1.0 新增：合作被动机制
-- ============================================================================

--- 检测本局激活的合作被动组合
---@param charIds table  所有玩家的角色 ID 列表
---@return table  激活的合作被动列表 { { synergyId, name, desc, effect, char1, char2 } }
function CharacterSystem.GetActiveSynergies(charIds)
    local result = {}
    if not Config.CharacterSynergies then return result end

    for _, synergy in ipairs(Config.CharacterSynergies) do
        local chars = synergy.chars
        local matched = {}

        for _, requiredChar in ipairs(chars) do
            for _, charId in ipairs(charIds) do
                -- 支持按角色 ID 或索引匹配
                local charIndex = CharacterData.GetCharacterIndex(charId)
                if charIndex == requiredChar or charId == requiredChar then
                    table.insert(matched, charId)
                    break
                end
            end
        end

        -- 如果所有要求的角色都存在，则激活
        if #matched == #chars then
            table.insert(result, {
                synergyId = synergy.name,
                name = synergy.name,
                desc = synergy.desc,
                effect = synergy.effect,
                chars = matched,
                isActive = true
            })
        end
    end

    return result
end

--- 应用合作被动的效果（如游戏开始时的余额加成）
---@param charIds table  所有玩家的角色 ID 列表
---@return table  每个玩家的初始加成 { [seatIdx] = { type, amount, source } }
function CharacterSystem.ApplySynergyEffects(charIds)
    local effects = {}
    local synergies = CharacterSystem.GetActiveSynergies(charIds)

    for _, synergy in ipairs(synergies) do
        local effect = synergy.effect
        if effect and effect.type then
            -- 根据效果类型应用到所有参与者
            for seatIdx, charId in ipairs(charIds) do
                for _, requiredChar in ipairs(synergy.chars) do
                    local charIndex = CharacterData.GetCharacterIndex(charId)
                    if charIndex == requiredChar or charId == requiredChar then
                        effects[seatIdx] = effects[seatIdx] or {}
                        if effect.type == "balance" or effect.type == "per_round_balance" then
                            table.insert(effects[seatIdx], {
                                type = effect.type,
                                amount = effect.amount,
                                source = "synergy_" .. synergy.name,
                                trigger = "game_start"  -- 立即触发
                            })
                        end
                    end
                end
            end
        end
    end

    return effects
end

--- 获取合作被动的描述文本
---@param charIds table
---@return table  { synergyName, synergyDesc, synergyIcon }
function CharacterSystem.GetSynergyInfo(charIds)
    local synergies = CharacterSystem.GetActiveSynergies(charIds)
    if #synergies == 0 then
        return nil
    end

    local names = {}
    local descs = {}
    for _, s in ipairs(synergies) do
        table.insert(names, s.name)
        table.insert(descs, s.name .. "：" .. s.desc)
    end

    return {
        synergyName = table.concat(names, " + "),
        synergyDesc = table.concat(descs, "\n"),
        synergyIcon = "synergy_active",
        count = #synergies
    }
end

--- 获取所有可用的合作被动组合配置
---@return table
function CharacterSystem.GetAllSynergyConfigs()
    if not Config.CharacterSynergies then
        return {}
    end
    local result = {}
    for _, s in ipairs(Config.CharacterSynergies) do
        table.insert(result, {
            id = s.name,
            name = s.name,
            desc = s.desc,
            chars = s.chars,
            effect = s.effect
        })
    end
    return result
end

return CharacterSystem
