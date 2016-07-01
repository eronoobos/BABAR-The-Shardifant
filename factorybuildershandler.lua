
FactoryBuildersHandler = class(Module)

function FactoryBuildersHandler:Name()
	return "FactoryBuildersHandler"
end

function FactoryBuildersHandler:internalName()
	return "FactoryBuildersHandler"
end 

function FactoryBuildersHandler:Init()
	self.builderslist = {}
	self.updateRequest = false
	self.DebugEnabled = true
	self.factoryToBuild = false
	self.factoryPosition = false
	self.builderToUse = false
	self.buildersNames ={}
	

end

function FactoryBuildersHandler:Update()
	if ai.factoryUnderConstruction then return end
	if not self.updateRequest then return end
	local f = self.game:Frame()
	if f % 100 == 0 then
		self:EchoDebug('no factory under construction')
		local availableFactories = self:AvailableFactories()
		local factoryBuildable = self:factoryBuildable(availableFactories)
		local factoriesPreCleaned = self:PrePositionFilter(factoryBuildable)
		local builderslist=self:Getbuilders()
		local bestFactoryPosition = self:BestFactoryPosition(factoriesPreCleaned)
		local postPositionedFactories = self:PostPositionFilter(bestFactoryPosition)
		local epuredChoiches = self:ComparingChoiches(postPositionedFactories)
		
	end
end

function FactoryBuildersHandler:Getbuilders()
	for i,v in pairs(self.builderslist) do
		self:EchoDebug(i)
	end
end

function FactoryBuildersHandler:GetFactoryPos(builderID)
	if self.builderToUse == builderID then
		self:EchoDebug('factoryToBuild ' .. self.factoryToBuild ..' self.factoryPosition ' )
		return self.factoryToBuild , self.factoryPosition
	end
end

function FactoryBuildersHandler:updateRequired()
	self.updateRequest = true
	self:EchoDebug('update required')
end
function FactoryBuildersHandler:AvailableFactories()
	local availableFactories = {}
	for name,count  in pairs(self.ai.nameCount) do
		if name and unitTable[name].factoriesCanBuild and count > 0 then
			for id, factoryName in pairs(unitTable[name].factoriesCanBuild) do
				if not availableFactories[factoryName] then
					availableFactories[factoryName] = {}
					availableFactories[factoryName][name] =1
				else
					if not availableFactories[factoryName][name] then
						availableFactories[factoryName][name] = {}
					else
						availableFactories[factoryName][name] = availableFactories[factoryName][name] +1
					end
				end
			end
		end
	end
	for i, v in pairs(availableFactories) do
		for ii,vv in pairs(v) do
			self:EchoDebug(ii..' builders available to build '.. i)
		end
	end
	return availableFactories 
end

function FactoryBuildersHandler:factoryBuildable(availableFactories)
	factoryBuildable = {}
	for index, Name in pairs(ai.factoriesRanking) do
		if availableFactories[Name] then
			table.insert(factoryBuildable,Name)
		end
	end
	for i, v in pairs(factoryBuildable) do
		self:EchoDebug('rank ' .. i .. ' factory '.. v)
	end
	return factoryBuildable

end


function FactoryBuildersHandler:PrePositionFilter(factoryBuildable)
	local factoriesPreCleaned = {}
	for index, factoryName in pairs(factoryBuildable) do
		local buildMe = true
		local utn=unitTable[factoryName]
		local level = utn.techLevel
		local isAdvanced = advFactories[factoryName]
		local isExperimental = expFactories[factoryName] or leadsToExpFactories[factoryName]
		local mtype = factoryMobilities[factoryName][1]

		if ai.needAdvanced and not ai.haveAdvFactory then
			if not isAdvanced then
				self:EchoDebug('not advanced when i need it')
				buildMe = false 
			end
		end
		if ai.needExperimental and not ai.haveExpFactory then
			if not isExperimental then
				self:EchoDebug('not Experimental when i need it')
				buildMe = false 
			end
		end
		if not ai.needExperimental then
			if expFactories[factoryName] then 
				self:EchoDebug('Experimental when i dont need it')
				buildMe = false 
			end
		end
		if isExperimental and ai.Energy.income > 5000 and ai.Metal.income > 100 and ai.Metal.reserves > utn.metalCost / 2 and ai.factoryBuilded['air'][1] > 2 and ai.combatCount > 40 then
			self:EchoDebug('i dont need it but economic situation permitted')
			buildMe = true
		end
		if mtype == 'air' and ai.factoryBuilded['air'][1] >= 1 then
			if utn.needsWater then 
				self:EchoDebug('dont build seaplane if i have normal planes')
				buildMe = false 
			end
		elseif mtype ~= 'air' and ai.haveAdvFactory and 
				ai.factoryBuilded['air'][1] > 0 and ai.factoryBuilded['air'][1] < 3 then
			self:EchoDebug('force build t2 air if you have t1 air and a t2 of another type')
			buildMe = false
		end
		if buildMe then table.insert(factoriesPreCleaned,factoryName) end
		
	end
	for i, v in pairs(factoryBuildable) do
		self:EchoDebug('rank ' .. i .. ' factoryPreCleaned '.. v)
	end
	return factoriesPreCleaned
end



function FactoryBuildersHandler:BestFactoryPosition(factoriesPreCleaned)
	local positionedFactories = {}
	for index, factoryName in pairs(factoriesPreCleaned) do
		local utype = game:GetTypeByName(factoryName)
		local mtype = factoryMobilities[factoryName][1]
		for id, obj in pairs(self.builderslist) do
			local builder = obj.unit:Internal()	
			local builderPos = builder:GetPosition()
			
			local p
			if p == nil then
				--self:EchoDebug("looking next to factory for " .. factoryName)
				local factoryPos = ai.buildsitehandler:ClosestHighestLevelFactory(builderPos, 10000)
				if factoryPos then
					p = ai.buildsitehandler:ClosestBuildSpot(builder, factoryPos, utype)
				end
			end
			if p == nil then
				--self:EchoDebug('builfactory near hotSpot')
				local factoryPos = ai.buildsitehandler:ClosestHighestLevelFactory(builderPos, 10000)
				local place = false
				local distance = 99999
				if factoryPos then
					for index, hotSpot in pairs(ai.hotSpot) do
						if ai.maphandler:MobilityNetworkHere(mtype,hotSpot) then
							
							dist = math.min(distance, Distance(hotSpot,factoryPos))
							if dist < distance then 
								place = hotSpot
								distance  = dist
							end
						end
					end
				end
				if place then
					p = ai.buildsitehandler:ClosestBuildSpot(builder, place, utype)
				end
			end
			if p == nil then
				--self:EchoDebug("looking for most turtled position for " .. factoryName)
				local turtlePosList = ai.turtlehandler:MostTurtled(builder, factoryName)
				if turtlePosList then
					if #turtlePosList ~= 0 then
						for i, turtlePos in ipairs(turtlePosList) do
							p = ai.buildsitehandler:ClosestBuildSpot(builder, turtlePos, utype)
							if p ~= nil then break end
						end
					end
				end
			end
			if p == nil then
				--self:EchoDebug("trying near builder for " .. factoryName)
				p = ai.buildsitehandler:ClosestBuildSpot(builder, builderPos, utype)
			end
			if p then
				if not positionedFactories[factoryName] then
					positionedFactories[factoryName] ={}
					positionedFactories[factoryName][id] = p
				else
					positionedFactories[factoryName][id] = p 
				end
			end
		end
		
	end
	for i,v in pairs(positionedFactories) do
		self:EchoDebug('factory '..i .. ' have position')
		for ii,vv in pairs(v) do
			self:EchoDebug(ii.. ' can build it here: x = ' .. vv.x .. ' y = ' .. vv.y ..' z = ' .. vv.z)
		end
	end
	return  positionedFactories
	
end

function FactoryBuildersHandler:PostPositionFilter(positionedFactories)
	PostPositionedFactories = {}
	for factoryName , factoryList in pairs(positionedFactories) do
		local mtype = factoryMobilities[factoryName][1]
		for id , p in pairs(factoryList) do
			local network = ai.maphandler:MobilityNetworkHere(mtype,p)
			local buildMe = true
			if ai.factoryBuilded[mtype] == nil or ai.factoryBuilded[mtype][network] == nil then
				self:EchoDebug('area to small for ' .. factoryName)
				return false
			end
			if unitTable[factoryName].techLevel <= ai.factoryBuilded[mtype][network] then
				self:EchoDebug('Not enough tech level for '..factoryName)
				buildMe = false
			end
			if mtype == 'bot' then
				local vehNetwork = ai.factoryBuilded['veh'][ai.maphandler:MobilityNetworkHere('veh',p)]
				if (vehNetwork and vehNetwork > 0) and (vehNetwork < 4 or ai.factoryBuilded['air'][1] < 1) then
					self:EchoDebug('dont build bot where are already veh not on top of tech level')
					buildMe = false
				end
			elseif mtype == 'veh' then
				local botNetwork = ai.factoryBuilded['bot'][ai.maphandler:MobilityNetworkHere('bot',p)]
				if (botNetwork and botNetwork > 0) and (botNetwork < 9 or ai.factoryBuilded['air'][1] < 1) then
					self:EchoDebug('dont build veh where are already bot not on top of tech level')
					buildMe = false
				end
			end
			if buildMe then
				if not PostPositionedFactories[factoryName] then
					PostPositionedFactories[factoryName] ={}
					PostPositionedFactories[factoryName][id] = p
				else
					PostPositionedFactories[factoryName][id] = p 
				end
			end
		end
	end
	for factoryName, factoryList in pairs(PostPositionedFactories) do
		self:EchoDebug(factoryName .. ' pass the post positional filter ' .. factoryName)
		for id,pos in pairs(factoryList) do
			self:EchoDebug(id.. ' can build it here: x = ' .. pos.x .. ' y = ' .. pos.y ..' z = ' .. pos.z)
		end
	end
	return PostPositionedFactories

end

function FactoryBuildersHandler:ComparingChoiches(postPositionedFactories)
	local factoriesChoiche = {}
	for rank, name in pairs(ai.factoriesRanking) do
		factoriesOptions = {}
		for factoryName, factoriesList in pairs(postPositionedFactories) do
			local bestName = nil
			local bestPos = nil
			local bestDist = 999999
			if name == factoryName then
				factoriesChoiche[name] = {}
				for builderID, pos in pairs(factoriesList) do
					factoriesOptions[builderID] = pos
				end
			end
			for builderID, position in pairs(factoriesOptions) do
				
				local builder = self.builderslist[builderID].unit:Internal()
				local builderPos = builder:GetPosition()
				local hiLvFactoryPos = ai.buildsitehandler:ClosestHighestLevelFactory(builderPos, 10000)
				if hiLvFactoryPos then
					local distance = Distance(hiLvFactoryPos,position)
					if distance < bestDist then
						bestDist = distance
						bestPos = position
						bestName = builderID
					end
				elseif #ai.turtlehandler:MostTurtled(builder, factoryName) > 0 then
					local turtlepos = ai.turtlehandler:MostTurtled(builder, factoryName)
					local distance = Distance(turtlepos,position)
					if distance < bestDist then
						bestDist = distance
						bestPos = position
						bestName = builderID
					end

				else
					
					local distance = Distance(builderPos,position)
					if distance < bestDist then
						bestDist = distance
						bestPos = position
						bestName = builderID
					end

				end
				self.factoryToBuild = factoryName
				self.factoryPosition = bestPos
				self.builderToUse = bestName
				self.updateRequest = false
				return

			end
		end

	end
	for i,v in pairs(factoriesChoiche) do
		--self:EchoDebug(i.. 'better to build here '.. v.x ..' '.. v.y ..' '.. v.z)
	end
	
end



-- function FactoryBuildersHandler:ShareFactories(factoriesChoiche)
-- 	for rank, factoryName in pairs(ai.factoriesRanking) do
-- 		if factoriesChoiche[factoryName] then
-- 			
-- 			self.factoryToBuild = factoryName
-- 			self.factoryPosition = 
-- 			self.builderToUse = false
	

					
					
					
					
					
						
					
					
					
				
				
				
	

			
			
