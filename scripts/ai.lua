local this = {
    positionFactor = 0.2
}

function this:Load(options)
    self.options = options
    modApi:addNextTurnHook(function(mission)
        if Game:GetTeamTurn() == TEAM_ENEMY then -- 敌人回合开始时清信息
            -- 不能在此处判断单位是否使用 intelAI，因为此处获取不到在生成点中待出现的敌人
            mission.intelAI_enableMap = {}
        else
            local pawns = extract_table(Board:GetPawns(TEAM_ENEMY))
            for _, id in ipairs(pawns) do
                if mission.intelAI_enableMap[id] then
                    local location = Board:GetPawn(id):GetSpace()
                    Board:Ping(location, GL_Color(255, 255, 255, 0))
                    Board:AddAlert(location, "AI+")
                end
            end
        end
    end)
end

function this:LogTargetInfo(target, damageScore, grappleScore, positionScore)
    if self.options.opt_debug.value == "TARGET" or self.options.opt_debug.value == "ALL" then
        local sum1 = damageScore + grappleScore
        local sum2 = sum1 + positionScore
        if sum1 > 0 then
            LOG(string.format("%s->%s: %d + %d + %d = (%d, %d)", Pawn:GetString(), target:GetString(), damageScore,
                grappleScore, positionScore, sum1, sum2))
        end
    end
end

function this:LogPositionInfo(target, pawn, score)
    if self.options.opt_debug.value == "POSITION" or self.options.opt_debug.value == "ALL" then
        if score > 0 then
            LOG(string.format("%s<-%s: %d", target:GetString(), pawn:GetString(), score))
        end
    end
end

function this:GetFactor()
    local factor = self.options.opt_factor.value
    local difficulty = GetDifficulty()
    if difficulty == DIFF_VERY_HARD then
        if self.options.opt_vh_mode.enabled then
            factor = 0.6
        end
    elseif difficulty == DIFF_IMPOSSIBLE then
        if self.options.opt_im_mode.enabled then
            factor = 1.0
        end
    end
    return factor
end

-- 判断是否为特殊建筑
function this:IsSpecialBuilding(point)
    local mission = GetCurrentMission()
    if mission.AssetLoc then
        if point == mission.AssetLoc then
            return true
        end
    end
    if mission.Criticals then
        for _, v in ipairs(mission.Criticals) do
            if point == v then
                return true
            end
        end
    end
    return false
end

-- 判断是否为环境
function this:IsEnvLocation(point)
    local mission = GetCurrentMission()
    if mission and mission.LiveEnvironment then
        local locations = mission.LiveEnvironment.Locations
        if locations then
            for _, v in ipairs(locations) do
                if point == v then
                    return true
                end
            end
        end
    end
    return false
end

function this:Skill_ScoreList(skill, list, queued)
    local score = 0
    local posScore = 0
    for i = 1, list:size() do
        local spaceDamage = list:index(i)
        local target = spaceDamage.loc
        local damage = spaceDamage.iDamage
        local moving = spaceDamage:IsMovement() and spaceDamage:MoveStart() == Pawn:GetSpace()
        if Board:IsValid(target) or moving then
            if spaceDamage:IsMovement() then
                posScore = posScore + ScorePositioning(spaceDamage:MoveEnd(), Pawn)
            else
                score = score + self:Skill_ScoreList_Target(skill, target, damage, false)
                if score > 0 then
                    local space = Pawn:GetSpace()
                    local direction = GetDirection(target - space)
                    local distance = space:Manhattan(target)
                    if distance > 1 then -- Pawn:IsRanged() 不是判断单位是否远程攻击！
                        -- 远程敌人：目标周围 4 格同样贡献分数
                        for _, dir in ipairs({(direction + 1) % 4, (direction + 3) % 4}) do -- 左右
                            local loc = target + DIR_VECTORS[dir]
                            if Board:IsValid(loc) and loc ~= space then
                                score = score + self:Skill_ScoreList_Target(skill, loc, damage, false) * 0.1
                            end
                        end
                        for _, dir in ipairs({direction, (direction + 2) % 4}) do -- 前后
                            local loc = target + DIR_VECTORS[dir]
                            if Board:IsValid(loc) and loc ~= space then
                                score = score + self:Skill_ScoreList_Target(skill, loc, damage, false) * 0.05
                            end
                        end
                    elseif distance == 1 then
                        -- 近战敌人：面向目标左右 2 格同样贡献分数
                        -- 远程敌人贴脸攻击时视为近战，因为无法区分只能这样妥协
                        for _, dir in ipairs({(direction + 1) % 4, (direction + 3) % 4}) do
                            local loc = target + DIR_VECTORS[dir]
                            if Board:IsValid(loc) and loc ~= space then
                                score = score + self:Skill_ScoreList_Target(skill, loc, damage, false) * 0.1
                            end
                        end
                        -- else distance == 0，自伤不额外计算
                    end
                end
            end
            if Board:IsPod(target) and not queued and (damage > 0 or spaceDamage.sPawn ~= "") then
                -- 时间舱只能被误伤！
                return -100
            end
        end
    end
    if posScore <= -50 then
        -- 位置太差时拒绝攻击
        score = posScore
    end
    return score
end

function this:Skill_ScoreList_Target(skill, target, damage, grapple)
    local score = 0
    if Board:GetPawnTeam(target) == Pawn:GetTeam() and damage > 0 then
        if Board:IsFrozen(target) and not Board:IsTargeted(target) then
            -- 大幅降低解冻冰冻友军的分数
            score = skill.ScoreEnemy * 6
        else
            -- 大幅增加攻击友军的负分数，对 AOE 敌人而言虽偶有神效，但这种情况一般都是坑自己人
            score = skill.ScoreFriendlyDamage * 30
        end
    elseif isEnemy(Board:GetPawnTeam(target), Pawn:GetTeam()) then
        local pawn = Board:GetPawn(target)
        if pawn:IsDead() or pawn:IsFrozen() then
            -- 不要攻击已毁坏敌人或被冰冻敌人
            score = skill.ScoreNothing
        else
            if grapple and not pawn:IsIgnoreWeb() then
                -- 缠绕敌人加分，并确保 缠绕 + 攻击 组合倍率与攻击 2 血建筑一致
                score = skill.ScoreEnemy * 15

                local terrain = Board:GetTerrain(target)
                if (not pawn:IsFlying() and terrain == TERRAIN_WATER) or
                    -- 主动追击在水中、烟雾中无法行动的敌人
                    (not pawn:IsIgnoreSmoke() and Board:IsSmoke(target)) then
                    score = score * 2
                else
                    -- 偏好缠绕远程、科学类型敌人
                    local type = pawn:GetType()
                    local clz = _G[type] and _G[type].Class
                    if clz == "Ranged" or clz == "Science" then
                        score = score * 1.05
                    end
                end
            elseif damage > 0 then
                if pawn:GetTeam() == TEAM_PLAYER and not pawn:IsMech() and pawn:GetMoveSpeed() == 0 then
                    -- 不可动的 TEAM_PLAYER 非 Mech 单位是任务单位
                    score = skill.ScoreEnemy * 25
                else
                    -- 降低攻击敌人这一行为的分数
                    score = skill.ScoreEnemy * 5
                end

                if pawn:IsShield() then
                    -- 降低攻击护盾敌人的分数
                    score = score * 0.5
                elseif pawn:IsAcid() then
                    -- 略微增加攻击酸液敌人的分数
                    score = score * 1.25
                elseif pawn:IsArmor() then
                    -- 降低攻击减伤装甲敌人的分数
                    score = score * 0.75
                end
            end
        end
    elseif Board:IsBuilding(target) and Board:IsPowered(target) and damage > 0 then
        local tile = intelAI_modApiExt.board:getTileTable(target)
        if tile and tile.shield then
            -- 降低攻击受护盾保护建筑的分数
            score = skill.ScoreBuilding * 2.5
        else
            if this:IsSpecialBuilding(target) then
                -- 重点对待特殊建筑
                score = skill.ScoreBuilding * 25
            else
                -- 考虑建筑血量
                if damage > 1 and intelAI_modApiExt.board:getTileHealth(target) > 1 then
                    score = skill.ScoreBuilding * 20
                else
                    score = skill.ScoreBuilding * 10
                end
            end
        end
    else
        score = skill.ScoreNothing
    end
    return score
end

function this:ScorePositioning(point, pawn)
    local score = self:ScorePositioningAvoid(point, pawn)
    if score <= -50 then
        return -100
    end
    if _G[pawn:GetType()].Leader ~= LEADER_NONE then
        return point.x ^ 2 + (7 - point.x) ^ 2 + point.y ^ 2 + (7 - point.y) ^ 2
    end
    for dir = DIR_START, DIR_END do
        local loc = point + DIR_VECTORS[dir]
        if Board:IsValid(loc) then
            -- 累加靠近收益
            score = score + self:ScorePositioningApproach(loc, pawn)
        end
    end

    local custom = pawn:GetCustomPositionScore(point)
    if custom ~= 0 then
        return custom * 10
    end

    local edge1 = point.x == 0 -- 不包括下边缘，否则敌人可能会消极应战
    local edge2 = point.y == 0 or point.y == 7
    if edge1 and edge2 then
        score = score + 50 -- 鼓励到角落
    elseif edge1 or edge2 then
        score = score + 30 -- 鼓励到边缘
    end

    if not pawn:IsRanged() or pawn:IsJumper() or pawn:IsFlying() then
        score = score + (7 - point.x) * 6 -- 越深入建筑区分数越高
    else
        score = score + 20
    end

    local aggregate = false
    local approach = false
    local enemy = (pawn:GetTeam() == TEAM_PLAYER) and TEAM_ENEMY or TEAM_PLAYER
    local friend = (pawn:GetTeam() == TEAM_ENEMY) and TEAM_ENEMY or TEAM_PLAYER
    for i = DIR_START, DIR_END do
        if Board:IsPawnTeam(point + DIR_VECTORS[i], friend) then
            aggregate = true
        end
        if not pawn:IsRanged() then -- 避免当近战法师（虽然 Ranged 并不全是远程）
            -- 尽量靠近更多建筑
            if Board:IsBuilding(point + DIR_VECTORS[i]) then
                score = score + 10
                approach = true
            elseif Board:IsPawnTeam(point + DIR_VECTORS[i], enemy) then
                approach = true
            end
        end
    end
    if aggregate then
        -- 聚集
        score = score - 30
    end
    if approach or pawn:IsRanged() then
        -- 避免消极应战
        score = score + 50
    end

    return score
end

-- 禁止区域
function this:ScorePositioningAvoid(point, pawn)
    -- 数值需从小到大
    local terrain = Board:GetTerrain(point)
    if not pawn:IsFlying() and (terrain == TERRAIN_HOLE or terrain == TERRAIN_WATER) then
        return -100
    elseif Board:IsSmoke(point) then
        return -100
    elseif Board:IsAcid(point) then
        return -100
    elseif Board:IsFire(point) and not pawn:IsFire() then
        return -100
    elseif Board:IsSpawning(point) then
        return -100
    elseif Board:IsDangerous(point) then
        return -100
    elseif Board:IsDangerousItem(point) then
        return -100
    elseif self:IsEnvLocation(point) then
        return -100
    elseif Board:IsPod(point) then
        return -100
    elseif Board:IsTargeted(point) then
        return -50
    end
    return 0
end

-- 靠近区域（收益可正可负）
function this:ScorePositioningApproach(point, pawn)
    local terrain = Board:GetTerrain(point)
    if not pawn:IsFlying() and (terrain == TERRAIN_HOLE or terrain == TERRAIN_WATER) then
        return -30
    elseif Board:IsSpawning(point) then
        return -20
    elseif Board:IsSmoke(point) then
        return -10
    elseif Board:IsFire(point) and not pawn:IsFire() then
        return -10
    elseif Board:IsDangerous(point) then
        return -10
    elseif Board:IsDangerousItem(point) then
        return -10
    elseif self:IsEnvLocation(point) then
        return -10
    elseif Board:IsTargeted(point) then
        return -10
    elseif terrain == TERRAIN_MOUNTAIN then
        return -10
    elseif pawn:IsFlying() and (terrain == TERRAIN_HOLE or terrain == TERRAIN_WATER) then
        return 5
    elseif Board:IsPod(point) then
        return 10
    end
    return 0
end

function this:IsPawnEnableAI(pawn)
    local mission = GetCurrentMission()
    if mission then
        -- 每个回合每个单位判断一次，该单位该回合总是使用 intelAI，或总是不使用 intelAI
        local id = pawn:GetId()
        if mission.intelAI_enableMap[id] == nil then
            mission.intelAI_enableMap[id] = random_int(100) < self:GetFactor() * 100
        end
        if mission.intelAI_enableMap[id] then
            return true
        end
    end
    return false
end

function this:GetPositionScore(point, pawn)
    if self:IsPawnEnableAI(pawn) then
        return ScorePositioning(point, pawn) * this.positionFactor
    end
    return 0
end

local _Skill_ScoreList = Skill.ScoreList
function Skill:ScoreList(list, queued, ...)
    if this:IsPawnEnableAI(Pawn) then
        return this:Skill_ScoreList(self, list, queued)
    end
    return _Skill_ScoreList(self, list, queued, ...)
end

local _Skill_GetTargetScore = Skill.GetTargetScore
function Skill:GetTargetScore(p1, p2)
    if this:IsPawnEnableAI(Pawn) then
        local fx = self:GetSkillEffect(p1, p2)

        local queued_score = self:ScoreList(fx.q_effect, true)
        local instant_score = self:ScoreList(fx.effect, false)

        if instant_score < -200 then
            return -100 -- don't do anything so horrible if it's instant
        end
        if fx.q_effect:empty() then
            return instant_score
        end

        -- 缠绕应是强加分项
        local grappleScore = 0
        local instant = fx.effect
        local meta = instant:GetMetadata()
        for i = 1, instant:size() do
            local grapple = meta[i] and meta[i].type == "grapple"
            if grapple then
                local target = meta[i].target or Point(-1, -1)
                if Board:IsValid(target) then
                    grappleScore = grappleScore + this:Skill_ScoreList_Target(self, target, 0, true)
                end
            end
        end

        local positionScore = 0
        local total = queued_score + grappleScore
        if total > 0 then
            positionScore = this:GetPositionScore(p1, Pawn)
        end
        this:LogTargetInfo(p2, queued_score, grappleScore, positionScore)
        return total + positionScore
    end
    return _Skill_GetTargetScore(self, p1, p2)
end

local _BlobberAtk1_GetTargetScore = BlobberAtk1.GetTargetScore
function BlobberAtk1:GetTargetScore(p1, p2) -- 炸弹怪的智商太低，重写
    if this:IsPawnEnableAI(Pawn) then
        local pos_score = ScorePositioning(p2, Pawn)
        if pos_score < 0 then
            return pos_score
        end

        local fx = SkillEffect()
        local outerDamage = self.MyPawn == "Blob1" and 1 or 3
        fx:AddQueuedDamage(SpaceDamage(p2, 2))
        for i = DIR_START, DIR_END do
            fx:AddQueuedDamage(SpaceDamage(p2 + DIR_VECTORS[i], outerDamage))
        end
        local score = self:ScoreList(fx.q_effect, true)

        local positionScore = 0
        if score > 0 then
            positionScore = this:GetPositionScore(p1, Pawn)
        end
        this:LogTargetInfo(p2, score, 0, positionScore)
        return score + positionScore
    end
    return _BlobberAtk1_GetTargetScore(self, p1, p2)
end

local _SpiderAtk1_GetTargetScore = SpiderAtk1.GetTargetScore
function SpiderAtk1:GetTargetScore(p1, p2) -- 蜘蛛智商也不行，重写
    if this:IsPawnEnableAI(Pawn) then
        local pos_score = ScorePositioning(p2, Pawn)
        if pos_score < 0 then
            return pos_score
        end

        local score = 0
        for i = DIR_START, DIR_END do
            local target = p2 + DIR_VECTORS[i]
            if isEnemy(Board:GetPawnTeam(target), Pawn:GetTeam()) then
                score = score + this:Skill_ScoreList_Target(self, target, 0, true)
            elseif Board:GetPawnTeam(target) == Pawn:GetTeam() and not Board:IsFrozen(target) then
                score = score + self.ScoreFriendlyDamage * 30
            elseif Board:IsBuilding(target) then
                score = score + self.ScoreBuilding * 5
            end
        end

        local positionScore = 0
        if score > 0 then
            positionScore = this:GetPositionScore(p1, Pawn)
        end
        this:LogTargetInfo(p2, 0, score, positionScore)
        return score + positionScore
    end
    return _SpiderAtk1_GetTargetScore(self, p1, p2)
end

local _CentipedeAtk1_GetTargetScore = CentipedeAtk1.GetTargetScore
function CentipedeAtk1:GetTargetScore(p1, p2)
    if this:IsPawnEnableAI(Pawn) then
        local fx = SkillEffect()
        if Board:GetPawnTeam(p2) == TEAM_ENEMY then
            return -10
        end

        local score = self:ScoreList(self:GetSkillEffect(p1, p2).q_effect, true)
        local positionScore = 0
        if score > 0 then
            positionScore = this:GetPositionScore(p1, Pawn)
        end
        this:LogTargetInfo(p2, score, 0, positionScore)
        return score + positionScore
    end
    return _CentipedeAtk1_GetTargetScore(self, p1, p2)
end

local _ScorePositioning = ScorePositioning
function ScorePositioning(point, pawn, ...)
    if this:IsPawnEnableAI(pawn) then
        local score = this:ScorePositioning(point, pawn)
        this:LogPositionInfo(point, pawn, score)
        return score
    end
    return _ScorePositioning(point, pawn, ...)
end

return this
