shard_include "common"

local DebugEnabled = true


local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("CleanHandler: " .. inStr)
	end
end

CleanHandler = class(Module)

function CleanHandler:Name()
	return "CleanHandler"
end

function CleanHandler:internalName()
	return "cleanhandler"
end

function CleanHandler:Init()
	self.cleanables = {}
	self.bigEnergyCount = 0
end

function CleanHandler:UnitBuilt(unit)
	if unit:Team() == self.ai.id then
		if self:IsCleanable(unit) then
			EchoDebug("cleanable " .. unit:Name())
			self.cleanables[#self.cleanables+1] = unit
		elseif self:IsBigEnergy(unit) then
			EchoDebug("big energy " .. unit:Name())
			self.bigEnergyCount = self.bigEnergyCount + 1
		end
	end
end

function CleanHandler:UnitDestroyed(unit)
	if unit:Team() == self.ai.id then
		for i = #self.cleanables, 1, -1 do
			local cleanable = self.cleanables[i]
			if cleanable:ID() == unit:ID() then
				EchoDebug("remove cleanable " .. unit:Name())
				table.remove(self.cleanables, i)
				return
			end
		end
	end
end

function CleanHandler:IsCleanable(unit)
	return cleanable[unit:Name()]
end

function CleanHandler:IsBigEnergy(unit)
	local ut = unitTable[unit:Name()]
	if ut then
		return (ut.totalEnergyOut > 750)
	end
end

function CleanHandler:GetCleanables()
	if self.ai.Metal.full > 0.9 or self.bigEnergyCount < 2 then
		return
	end
	return self.cleanables
end