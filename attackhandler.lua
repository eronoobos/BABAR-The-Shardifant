AttackHandler = class(Module)

function AttackHandler:Name()
	return "AttackHandler"
end

function AttackHandler:internalName()
	return "attackhandler"
end

local floor = math.floor
local ceil = math.ceil

function AttackHandler:Init()
	self.DebugEnabled = false

	self.recruits = {}
	self.count = {}
	self.squads = {}
	self.counter = {}
	self.attackSent = {}
	self.ai.hasAttacked = 0
	self.ai.couldAttack = 0
	self.ai.IDsWeAreAttacking = {}
end

function AttackHandler:Update()
	local f = game:Frame()
	if f % 150 == 0 then
		self:DraftSquads()
	end
	if f % 30 == 0 then
		-- actually retargets each squad every 15 seconds
		-- self:ReTarget()
	end
	for is = #self.squads, 1, -1 do
		local squad = self.squads[is]
		self:SquadPathfind(squad, is)
	end
end

function AttackHandler:DraftSquads()
	-- if self.ai.incomingThreat > 0 then game:SendToConsole(self.ai.incomingThreat .. " " .. (self.ai.battleCount + self.ai.breakthroughCount) * 75) end
	-- if self.ai.incomingThreat > (self.ai.battleCount + self.ai.breakthroughCount) * 75 then
		-- do not attack if we're in trouble
		-- self:EchoDebug("not a good time to attack " .. tostring(self.ai.battleCount+self.ai.breakthroughCount) .. " " .. self.ai.incomingThreat .. " > " .. tostring((self.ai.battleCount+self.ai.breakthroughCount)*75))
		-- return
	-- end
	local needtarget = {}
	local f = game:Frame()
	-- find which mtypes need targets
	for mtype, count in pairs(self.count) do
		if f > self.attackSent[mtype] + 1800 and count >= self.counter[mtype] then
			self:EchoDebug(mtype, "needs target with", count, "units of", self.counter[mtype], "needed")
			table.insert(needtarget, mtype)
		end
	end
	for nothing, mtype in pairs(needtarget) do
		-- prepare a squad
		local squad = { members = {}, notarget = 0, congregating = false, mtype = mtype, lastReTarget = f, lastMovementFrame = 0 }
		local representative, representativeBehaviour
		self:EchoDebug(mtype, #self.recruits[mtype], "recruits")
		for _, attkbhvr in pairs(self.recruits[mtype]) do
			if attkbhvr ~= nil then
				if attkbhvr.unit ~= nil then
					representativeBehaviour = representativeBehaviour or attkbhvr
					representative = representative or attkbhvr.unit:Internal()
					table.insert(squad.members, attkbhvr)
					attkbhvr.squad = squad
				end
			end
		end
		if representative ~= nil then
			self:EchoDebug(mtype, "has representative")
			self.ai.couldAttack = self.ai.couldAttack + 1
			-- don't actually draft the squad unless there's something to attack
			local bestCell = self.ai.targethandler:GetBestAttackCell(representative)
			if bestCell ~= nil then
				self:EchoDebug(mtype, "has target, recruiting squad...")
				squad.target = bestCell.pos
				self:IDsWeAreAttacking(bestCell.buildingIDs, squad.mtype)
				squad.buildingIDs = bestCell.buildingIDs
				self.attackSent[mtype] = f
				table.insert(self.squads, squad)
				self:SquadFormation(squad)
				self:SquadNewPath(squad, representativeBehaviour)
				-- clear recruits
				self.count[mtype] = 0
				self.recruits[mtype] = {}
				self.ai.hasAttacked = self.ai.hasAttacked + 1
				self.counter[mtype] = math.min(maxAttackCounter, self.counter[mtype] + 1)
			end
		end
	end
end

function AttackHandler:ReTarget()
	local f = game:Frame()
	for is = #self.squads, 1, -1 do
		local squad = self.squads[is]
		if f > squad.lastReTarget + 300 then
			self:SquadReTarget(squad, is)
			squad.lastReTarget = f
		end
	end
end

function AttackHandler:SquadReTarget(squad, squadIndex)
	local f = game:Frame()
	-- if not squad.idle and not squad.reachedTarget then
	-- 	return
	-- end
	-- if not squad.idle and f < squad.reachedTarget + 900 then
	-- 	return
	-- end
	local representativeBehaviour
	local representative
	for iu, member in pairs(squad.members) do
		if member ~= nil then
			if member.unit ~= nil then
				representativeBehaviour = member
				representative = member.unit:Internal()
				if representative ~= nil then
					break
				end
			end
		end
	end
	if squad.buildingIDs ~= nil then
		self:IDsWeAreNotAttacking(squad.buildingIDs)
	end
	if representative == nil then
		self.attackSent[squad.mtype] = 0
		table.remove(self.squads, squadIndex)
	else
		-- find a target
		local bestCell = self.ai.targethandler:GetBestAttackCell(representative)
		if bestCell == nil then
			-- squad.notarget = squad.notarget + 1
			-- if squad.target == nil or squad.notarget > 3 then
				-- if no target found initially, or no target for the last three targetting checks, disassemble and recruit the squad
				for iu, member in pairs(squad.members) do
					self:AddRecruit(member)
				end
				self.attackSent[squad.mtype] = 0
				table.remove(self.squads, squadIndex)
			-- end
		else
			squad.target = bestCell.pos
			self:IDsWeAreAttacking(bestCell.buildingIDs, squad.mtype)
			squad.buildingIDs = bestCell.buildingIDs
			squad.notarget = 0
			squad.reachedTarget = nil
			self:SquadNewPath(squad, representativeBehaviour)
		end
	end
end

function AttackHandler:SquadFormation(squad)
	local members = squad.members
	local maxMemberSize
	for i = 1, #members do
		local member = members[i]
		if not maxMemberSize or member.congSize > maxMemberSize then
			maxMemberSize = member.congSize
		end
	end
	local n = 0
	for i = 1, #members do
		local member = members[i]
		local mult = 1
		if i % 2 == 0 then
			n = n + 1
			mult = -1
		end
		local away = n * maxMemberSize * mult
		member.formationDist = away
	end
end

function AttackHandler:SquadNewPath(squad, representativeBehaviour)
	if not squad.target then return end
	representativeBehaviour = representativeBehaviour or squad.members[#squad.members]
	local representative = representativeBehaviour.unit:Internal()
	if self.DebugEnabled then
		self.map:EraseLine(nil, nil, {1,1,0}, squad.mtype, nil, 8)
	end
	local startPos
	if squad.targetNode then
		startPos = squad.targetNode.position
	else
		startPos = self.ai.frontPosition[representativeBehaviour.hits] or representative:GetPosition()
	end
	-- squad.path = nil
	-- squad.pathStep = nil
	-- squad.targetNode = nil
	squad.modifierFunc = squad.modifierFunc or self.ai.targethandler:GetPathModifierFunc(representative:Name())
	if ShardSpringLua then
		local targetModFunc = self.ai.targethandler:GetPathModifierFunc(representative:Name())
		local startHeight = Spring.GetGroundHeight(startPos.x, startPos.z)
		squad.modifierFunc = function(node)
			local hMod = (Spring.GetGroundHeight(node.position.x, node.position.z) - startHeight) / 100
			return targetModFunc(node) + hMod
		end
	end
	squad.graph = squad.graph or self.ai.maphandler:GetPathGraph(squad.mtype)
	squad.pathfinder = squad.graph:PathfinderPosPos(representative:GetPosition(), squad.target, nil, nil, nil, squad.modifierFunc)
end

function AttackHandler:SquadPathfind(squad, squadIndex)
	if not squad.pathfinder then return end
	local path, remaining, maxInvalid = squad.pathfinder:Find(2)
	if path then
		path = SimplifyPath(path)
		squad.path = path
		squad.pathStep = 1
		squad.targetNode = squad.path[1]
		squad.hasMovedOnce = nil
		squad.pathfinder = nil
		self:SquadAdvance(squad)
		if self.DebugEnabled then
			self.map:EraseLine(nil, nil, {1,1,0}, squad.mtype, nil, 8)
			for i = 2, #path do
				local pos1 = path[i-1].position
				local pos2 = path[i].position
				local arrow = i == #path
				self.map:DrawLine(pos1, pos2, {1,1,0}, squad.mtype, arrow, 8)
			end
		end
	elseif remaining == 0 then
		squad.pathfinder = nil
		self:SquadReTarget(squad, squadIndex)
	end
end

function AttackHandler:MemberIdle(attkbhvr)
	local squad = attkbhvr.squad
	if not squad then return end
	squad.idleCount = (squad.idleCount or 0) + 1
	-- self:EchoDebug(squad.idleCount)
	if squad.idleCount > floor(#squad.members * 0.8) then
		self:SquadAdvance(squad)
	end
end

function AttackHandler:SquadAdvance(squad)
	self:EchoDebug("advance")
	squad.idleCount = 0
	if squad.pathStep == #squad.path then
		self:SquadReTarget(squad)
		return
	end
	if squad.hasMovedOnce then
		squad.pathStep = squad.pathStep + 1
		squad.targetNode = squad.path[squad.pathStep]
	end
	local members = squad.members
	local nextPos = squad.targetNode.position
	local nextAngle
	if squad.pathStep == #squad.path then
		nextAngle = AnglePosPos(squad.path[squad.pathStep-1].position, nextPos)
	else
		nextAngle = AnglePosPos(nextPos, squad.path[squad.pathStep+1].position)
	end
	local nextPerpendicularAngle = AngleAdd(nextAngle, halfPi)
	for i = #members, 1, -1 do
		local member = members[i]
		member:Advance(nextPos, nextPerpendicularAngle)
	end
	squad.hasMovedOnce = true
end

function AttackHandler:IDsWeAreAttacking(unitIDs, mtype)
	for i, unitID in pairs(unitIDs) do
		self.ai.IDsWeAreAttacking[unitID] = mtype
	end
end

function AttackHandler:IDsWeAreNotAttacking(unitIDs)
	for i, unitID in pairs(unitIDs) do
		self.ai.IDsWeAreAttacking[unitID] = nil
	end
end

function AttackHandler:TargetDied(mtype)
	self:EchoDebug("target died")
	self:NeedLess(mtype, 0.75)
end

function AttackHandler:RemoveMember(attkbhvr)
	if attkbhvr == nil then return end
	local squad = attkbhvr.squad
	for iu = #squad.members, 1, -1 do
		local member = squad.members[iu]
		if member == attkbhvr then
			table.remove(squad.members, iu)
			if #squad.members == 0 then
				self.attackSent[squad.mtype] = 0
				for is = #self.squads, 1, -1 do
					if squad == self.squads[is] then
						table.remove(self.squads, is)
					end
				end
			else
				self:SquadFormation(squad)
			end
			attkbhvr.squad = nil
			return true
		end
	end
end

function AttackHandler:IsRecruit(attkbhvr)
	if attkbhvr.unit == nil then return false end
	local mtype = self.ai.maphandler:MobilityOfUnit(attkbhvr.unit:Internal())
	if self.recruits[mtype] ~= nil then
		for i,v in pairs(self.recruits[mtype]) do
			if v == attkbhvr then
				return true
			end
		end
	end
	return false
end

function AttackHandler:AddRecruit(attkbhvr)
	if not self:IsRecruit(attkbhvr) then
		if attkbhvr.unit ~= nil then
			-- self:EchoDebug("adding attack recruit")
			local mtype = self.ai.maphandler:MobilityOfUnit(attkbhvr.unit:Internal())
			if self.recruits[mtype] == nil then self.recruits[mtype] = {} end
			if self.counter[mtype] == nil then self.counter[mtype] = baseAttackCounter end
			if self.attackSent[mtype] == nil then self.attackSent[mtype] = 0 end
			if self.count[mtype] == nil then self.count[mtype] = 0 end
			local level = attkbhvr.level
			self.count[mtype] = self.count[mtype] + level
			table.insert(self.recruits[mtype], attkbhvr)
			attkbhvr:SetMoveState()
			attkbhvr:Free()
		else
			self:EchoDebug("unit is nil!")
		end
	end
end

function AttackHandler:RemoveRecruit(attkbhvr)
	for mtype, recruits in pairs(self.recruits) do
		for i,v in ipairs(recruits) do
			if v == attkbhvr then
				local level = attkbhvr.level
				self.count[mtype] = self.count[mtype] - level
				table.remove(self.recruits[mtype], i)
				return true
			end
		end
	end
	return false
end

function AttackHandler:NeedMore(attkbhvr)
	local mtype = attkbhvr.mtype
	local level = attkbhvr.level
	self.counter[mtype] = math.min(maxAttackCounter, self.counter[mtype] + (level * 0.7) ) -- 0.75
	self:EchoDebug(mtype .. " attack counter: " .. self.counter[mtype])
end

function AttackHandler:NeedLess(mtype, subtract)
	if subtract == nil then subtract = 0.1 end
	if mtype == nil then
		for mtype, count in pairs(self.counter) do
			if self.counter[mtype] == nil then self.counter[mtype] = baseAttackCounter end
			self.counter[mtype] = math.max(self.counter[mtype] - subtract, minAttackCounter)
			self:EchoDebug(mtype .. " attack counter: " .. self.counter[mtype])
		end
	else
		if self.counter[mtype] == nil then self.counter[mtype] = baseAttackCounter end
		self.counter[mtype] = math.max(self.counter[mtype] - subtract, minAttackCounter)
		self:EchoDebug(mtype .. " attack counter: " .. self.counter[mtype])
	end
end

function AttackHandler:GetCounter(mtype)
	if mtype == nil then
		local highestCounter = 0
		for mtype, counter in pairs(self.counter) do
			if counter > highestCounter then highestCounter = counter end
		end
		return highestCounter
	end
	if self.counter[mtype] == nil then
		return baseAttackCounter
	else
		return self.counter[mtype]
	end
end