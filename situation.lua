

Situation = class(Module)

function Situation:Name()
	return "Situation"
end

function Situation:internalName()
	return "situation"
end

function Situation:Init()
	self.DebugEnabled = false

	self.heavyPlasmaLimit = 3
	self.AAUnitPerTypeLimit = 3
	self.nukeLimit = 1
	self.tacticalNukeLimit = 1

	self.lastCheckFrame = 0

	self:StaticEvaluate()
	self:Evaluate()
end

function Situation:Update()
	self:Evaluate()
end

function Situation:Evaluate()
	local f = self.game:Frame()
	if f > self.lastCheckFrame + 240 then
		self.lastCheckFrame = f
		self.ai.haveAdvFactory = self.ai.factoriesAtLevel[3] and #self.ai.factoriesAtLevel[3] ~= 0
		self.ai.haveExpFactory = self.ai.factoriesAtLevel[5] and #self.ai.factoriesAtLevel[5] ~= 0
		
		self.ai.needToReclaim = self.ai.Metal.full < 0.5 and self.ai.wreckCount > 0
		self.AAUnitPerTypeLimit = math.ceil(self.ai.turtlehandler:GetTotalPriority() / 4)
		self.heavyPlasmaLimit = math.ceil(self.ai.combatCount / 10)
		self.nukeLimit = math.ceil(self.ai.combatCount / 50)
		self.tacticalNukeLimit = math.ceil(self.ai.combatCount / 40)

		local attackCounter = self.ai.attackhandler:GetCounter()
		local couldAttack = self.ai.couldAttack >= 1 or self.ai.couldBomb >= 1
		local bombingTooExpensive = self.ai.bomberhandler:GetCounter() == maxBomberCounter
		local attackTooExpensive = attackCounter == maxAttackCounter
		local controlMetalSpots = self.ai.mexCount > #self.ai.mobNetworkMetals["air"][1] * 0.4
		local needUpgrade = couldAttack or bombingTooExpensive or attackTooExpensive
		local lotsOfMetal = self.ai.Metal.income > 25 or controlMetalSpots

		self:EchoDebug(self.ai.totalEnemyThreat .. " " .. self.ai.totalEnemyImmobileThreat .. " " .. self.ai.totalEnemyMobileThreat)
		-- build siege units if the enemy is turtling, if a lot of our attackers are getting destroyed, or if we control over 40% of the metal spots
		self.needSiege = (self.ai.totalEnemyImmobileThreat > self.ai.totalEnemyMobileThreat * 3.5 and self.ai.totalEnemyImmobileThreat > 50000) or attackCounter >= siegeAttackCounter or controlMetalSpots
		self.ai.needAdvanced = (self.ai.Metal.income > 10 or controlMetalSpots) and self.ai.factories > 0 and (needUpgrade or lotsOfMetal)
		self.ai.needExperimental = false
		self.ai.needNukes = false
		if self.ai.Metal.income > 50 and self.ai.haveAdvFactory and needUpgrade and self.ai.enemyBasePosition then
			if not self.ai.haveExpFactory then
				for i, factory in pairs(self.ai.factoriesAtLevel[self.ai.maxFactoryLevel]) do
					if self.ai.maphandler:MobilityNetworkHere("bot", factory.position) == self.ai.maphandler:MobilityNetworkHere("bot", self.ai.enemyBasePosition) then
						self.ai.needExperimental = true
						break
					end
				end
			end
			self.ai.needNukes = true
		end
		self:EchoDebug("need experimental? " .. tostring(self.ai.needExperimental) .. ", need nukes? " .. tostring(self.ai.needNukes) .. ", have advanced? " .. tostring(self.ai.haveAdvFactory) .. ", need upgrade? " .. tostring(needUpgrade) .. ", have enemy base position? " .. tostring(self.ai.enemyBasePosition))
		self:EchoDebug("metal income: " .. self.ai.Metal.income .. "  combat units: " .. self.ai.combatCount)
		self:EchoDebug("have advanced? " .. tostring(self.ai.haveAdvFactory) .. " have experimental? " .. tostring(self.ai.haveExpFactory))
		self:EchoDebug("need advanced? " .. tostring(self.ai.needAdvanced) .. "  need experimental? " .. tostring(self.ai.needExperimental))
		self:EchoDebug("need advanced? " .. tostring(self.ai.needAdvanced) .. ", need upgrade? " .. tostring(needUpgrade) .. ", have attacked enough? " .. tostring(couldAttack) .. " (" .. self.ai.couldAttack .. "), have " .. self.ai.factories .. " factories, " .. math.floor(self.ai.Metal.income) .. " metal income")
	end
end

function Situation:StaticEvaluate()
	self.needAmphibiousCons = self.ai.hasUWSpots and self.ai.mobRating["sub"] > self.ai.mobRating["bot"] * 0.75
end