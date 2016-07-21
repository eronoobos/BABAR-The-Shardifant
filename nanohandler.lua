NanoHandler = class(Module)

function NanoHandler:Name()
	return "NanoHandler"
end

function NanoHandler:internalName()
	return "nanohandler"
end

local mSqrt = math.sqrt

local function CircleIntersection(position1, radius1, position2, radius2)
	local dx = position2.x - position1.x
	local dz = position2.z - position1.z
	local distSq = dx*dx + dz*dz
	local dist = mSqrt(distSq)
	if dist > radius1 + radius2 then
		-- too far apart to intersect
		return
	elseif dist < radius1 - radius2 then
		-- circle 1 contains circle 2
		return position2
	elseif dist < radius2 - radius1 then
		-- circle 2 contains circle 1
		return position1
	elseif dist == 0 and radius1 == radius2 then
		-- circles are the same
		return
	else
		-- find center of intersections
		local a = (radius1*radius1 - radius2*radius2 + distSq) / (2 * dist)
		local mult = a / dist
		local xi = position1.x + (dx * mult)
		local zi = position1.z + (dz * mult)
		local intersection = api.Position()
		intersection.x = xi
		intersection.z = zi
		return intersection
	end
end

function NanoHandler:Init()
	self.DebugEnabled = false

	self.factories = {}
	self.nanos = {}
	self.intersections = {}
end

function NanoHandler:UnitBuilt(engineUnit)
	local ut = unitTable[engineUnit:Name()]
	if not ut then return end
	if ut.isBuilding and ut.unitsCanBuild and #ut.unitsCanBuild > 0 then
		self:AddFactory(engineUnit)
	elseif nanoTurretList[engineUnit:Name()] then
		self:AddNano(engineUnit)
	end
end

function NanoHandler:UnitDead(engineUnit)
	local ut = unitTable[engineUnit:Name()]
	if not ut then return end
	if ut.isBuilding and ut.unitsCanBuild and #ut.unitsCanBuild > 0 then
		-- self:RemoveFactory(engineUnit)
	elseif nanoTurretList[engineUnit:Name()] then
		-- self:RemoveNano(engineUnit)
	end
end

function NanoHandler:AddFactory(engineUnit)
	self.factories[#self.factories+1] = engineUnit
end

function NanoHandler:AddNano(engineUnit)
	for i = 1, #self.nanos do
		local nanoUnit = self.nanos[i]
		local intersectPos = CircleIntersection(engineUnit:GetPosition(), 400, nanoUnit:GetPosition(), 400)
		if intersectPos then
			local merged = false
			for ii = i, #self.intersections do
				local intersect = self.intersections[ii]
				if Distance(intersect.position, intersectPos) < 60 then
					-- add to existing intersection
					intersect.count = intersect.count + 1
					self:EchoDebug("existing intersection", intersect.count)
					merged = true
					break
				end
			end
			if not merged then
				self:EchoDebug("new intersection")
				self.intersections[#self.intersections+1] = {position = intersectPos, count = 1}
			end
			self.intersectionsNeedSorting = true
		end
	end
	self.nanos[#self.nanos+1] = engineUnit
end

function NanoHandler:SortIntersections()
	if not self.intersectionsNeedSorting then return end
	local intsByCounts = {}
	for i = 1, #self.intersections do
		local intersection = self.intersections[i]
		intsByCounts[-intersection.count] = intersection.position
	end
	self.sortedIntersections = {}
	for count, position in pairsByKeys(intsByCounts) do
		self.sortedIntersections[#self.sortedIntersections+1] = position
	end
	self.intersectionsNeedSorting = false
end

function NanoHandler:GetHotSpots()
	self:SortIntersections()
	return self.sortedIntersections
end