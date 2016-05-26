shard_include "common"

local DebugEnabled = true


local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("CleanerBehaviour: " .. inStr)
	end
end

function IsCleaner(unit)
	local tmpName = unit:Internal():Name()
	return (cleanerList[tmpName] or 0) > 0
end

CleanerBehaviour = class(Behaviour)

function CleanerBehaviour:Init()
	self.name = self.unit:Internal():Name()
	if nanoTurretList[self.name] then
		self.cleaningRadius = 390
	else
		self.cleaningRadius = 250
	end
	self.frameCounter = 0
end

function CleanerBehaviour:Update()
	self.frameCounter = self.frameCounter + 1
	if self.frameCounter == 30 then
		self:UnitIdle(self.unit)
		self.frameCounter = 0
	end
end

function CleanerBehaviour:UnitIdle(unit)
	if unit.engineID ~= self.unit.engineID then
		return
	end
	self:Search()
	self.unit:ElectBehaviour()
end

function CleanerBehaviour:Activate()
	CustomCommand(self.unit:Internal(), CMD_RECLAIM, {self.cleanThis:ID()})
	-- self.ai.cleanhandler:UnitDestroyed(self.cleanThis)
end

function CleanerBehaviour:Priority()
	if self.cleanThis then
		return 101
	else
		return 0
	end
end

function CleanerBehaviour:Search()
	self.cleanThis = nil
	local cleanables = self.ai.cleanhandler:GetCleanables()
	if cleanables and #cleanables > 0 then
		EchoDebug(#cleanables .. " cleanables")
		local myPos = self.unit:Internal():GetPosition()
		for i = 1, #cleanables do
			local engineUnit = cleanables[i]
			local p = engineUnit:GetPosition()
			if p then
				local dist = Distance(myPos, p)
				if dist < self.cleaningRadius then
					self.cleanThis = engineUnit
					return
				end
			end
		end
	end
end