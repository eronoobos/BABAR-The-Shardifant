shard_include "common"

CountBehaviour = class(Behaviour)

local DebugEnabled = true


local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("CountBehaviour: " .. inStr)
	end
end

function CountBehaviour:Init()
	self.finished = false
	self.name = self.unit:Internal():Name()
	self.id = self.unit:Internal():ID()
	local uTn = unitTable[self.name]
	-- game:SendToConsole(self.name .. " " .. self.id .. " init")
	if uTn.isBuilding then
			self.position = self.unit:Internal():GetPosition() -- buildings don't move
		else
			if uTn.buildOptions then
				self.isCon = true
			elseif uTn.isWeapon then
				self.isCombat = true
			end
		end
	self.level = uTn.techLevel
	self.mtypedLv = tostring(uTn.mtype)..self.level
	if uTn.totalEnergyOut > 750 then self.isBigEnergy = true end
	if uTn.extractsMetal > 0 then self.isMex = true end
	if battleList[self.name] then self.isBattle = true end
	if breakthroughList[self.name] then self.isBreakthrough = true end
	if self.isCombat and not battleList[self.name] and not breakthroughList[self.name] then
		self.isSiege = true
	end
	if reclaimerList[self.name] then self.isReclaimer = true end
	if cleanable[self.name] then self.isCleanable = true end
	if assistList[self.name] then self.isAssist = true end
	if ai.nameCount[self.name] == nil then
		ai.nameCount[self.name] = 1
	else
		ai.nameCount[self.name] = ai.nameCount[self.name] + 1
	end
	EchoDebug(ai.nameCount[self.name] .. " " .. self.name .. " created")
	ai.lastNameCreated[self.name] = game:Frame()
	self.unit:ElectBehaviour()
end

function CountBehaviour:UnitCreated(unit)
	if unit.engineID == self.unit.engineID then
		-- game:SendToConsole(self.name .. " " .. self.id .. " created")
	end
end

function CountBehaviour:UnitBuilt(unit)
	if unit.engineID == self.unit.engineID then
		-- game:SendToConsole(self.name .. " " .. self.id .. " built")
		if ai.nameCountFinished[self.name] == nil then
			ai.nameCountFinished[self.name] = 1
		else
			ai.nameCountFinished[self.name] = ai.nameCountFinished[self.name] + 1
		end
		if self.isMex then ai.mexCount = ai.mexCount + 1 end
		if self.isCon then ai.conCount = ai.conCount + 1 end
		if self.isCombat then ai.combatCount = ai.combatCount + 1 end
		if self.isBattle then ai.battleCount = ai.battleCount + 1 end
		if self.isBreakthrough then ai.breakthroughCount = ai.breakthroughCount + 1 end
		if self.isSiege then ai.siegeCount = ai.siegeCount + 1 end
		if self.isReclaimer then ai.reclaimerCount = ai.reclaimerCount + 1 end
		if self.isAssist then ai.assistCount = ai.assistCount + 1 end
		if self.isBigEnergy then ai.bigEnergyCount = ai.bigEnergyCount + 1 end
		if self.isCleanable then ai.cleanable[unit.engineID] = self.position end
		ai.lastNameFinished[self.name] = game:Frame()
		EchoDebug(ai.nameCountFinished[self.name] .. " " .. self.name .. " finished")
		self.finished = true
		--mtyped leveled counters
		if ai[self.mtypedLv] == nil then 
			ai[self.mtypedLv] = 1 
		else
			ai[self.mtypedLv] = ai[self.mtypedLv] + 1
		end
	end
end

function CountBehaviour:UnitIdle(unit)

end

function CountBehaviour:Update()

end

function CountBehaviour:Activate()

end

function CountBehaviour:Deactivate()
end

function CountBehaviour:Priority()
	return 0
end

function CountBehaviour:UnitDead(unit)
	if unit.engineID == self.unit.engineID then
		ai.nameCount[self.name] = ai.nameCount[self.name] - 1
		if self.finished then
			ai.nameCountFinished[self.name] = ai.nameCountFinished[self.name] - 1
			if self.isMex then ai.mexCount = ai.mexCount - 1 end
			if self.isCon then ai.conCount = ai.conCount - 1 end
			if self.isCombat then ai.combatCount = ai.combatCount - 1 end
			if self.isBattle then ai.battleCount = ai.battleCount - 1 end
			if self.isBreakthrough then ai.breakthroughCount = ai.breakthroughCount - 1 end
			if self.isSiege then ai.siegeCount = ai.siegeCount - 1 end
			if self.isReclaimer then ai.reclaimerCount = ai.reclaimerCount - 1 end
			if self.isAssist then ai.assistCount = ai.assistCount - 1 end
			if self.isBigEnergy then ai.bigEnergyCount = ai.bigEnergyCount - 1 end
			if self.isCleanable then ai.cleanable[unit.engineID] = nil end
			ai[self.mtypedLv] = ai[self.mtypedLv] - 1
			
		end
	end
end