NanoHandler = class(Module)

function NanoHandler:Name()
	return "NanoHandler"
end

function NanoHandler:internalName()
	return "nanohandler"
end

local cellSize = 128
local halfCellSize = cellSize / 2

function NanoHandler:Init()
	self.DebugEnabled = false
	self.densityMap = {}
end

function NanoHandler:UnitBuilt(engineUnit)
	local ut = unitTable[engineUnit:Name()]
	if not ut then return end
	if nanoTurretList[engineUnit:Name()] then
		self:AddNano(engineUnit)
	end
end

function NanoHandler:UnitDead(engineUnit)
	local ut = unitTable[engineUnit:Name()]
	if not ut then return end
	if nanoTurretList[engineUnit:Name()] then
		self:RemoveNano(engineUnit)
	end
end

function NanoHandler:DrawDebug()
	if not self.DebugEnabled then return end
	self.map:EraseAll(2)
	local highestCount = 0
	for cx, czz in pairs(self.densityMap) do
		for cz, count in pairs(czz) do
			if count > highestCount then
				highestCount = count
			end
		end
	end
	for cx, czz in pairs(self.densityMap) do
		for cz, count in pairs(czz) do
			local x = cx * cellSize
			local z = cz * cellSize
			local cellPosMin = api.Position()
			cellPosMin.x = x - halfCellSize
			cellPosMin.z = z - halfCellSize
			local cellPosMax = api.Position()
			cellPosMax.x = x + halfCellSize
			cellPosMax.z = z + halfCellSize
			local green = count / highestCount
			local blue = 1 - green
			self.map:DrawRectangle(cellPosMin, cellPosMax, {0,green,blue}, count, true, 2)
		end
	end
end

function NanoHandler:AddNano(engineUnit)
	self.densityMap = FillCircle(self.densityMap, cellSize, engineUnit:GetPosition(), 400, nil, 1)
	self.cellsNeedSorting = true
	self:DrawDebug()
end

function NanoHandler:RemoveNano(engineUnit)
	self.densityMap = FillCircle(self.densityMap, cellSize, engineUnit:GetPosition(), 400, nil, -1)
	self.cellsNeedSorting = true
	self:DrawDebug()
end

function NanoHandler:SortCells()
	if not self.cellsNeedSorting then return end
	local posByCounts = {}
	for cx, czz in pairs(self.densityMap) do
		for cz, count in pairs(czz) do
			if count > 1 then
				local cellPos = api.Position()
				cellPos.x = cx * cellSize
				cellPos.z = cz * cellSize
				posByCounts[-count] = cellPos
			end
		end
	end
	self.sortedCells = {}
	for negCount, position in pairsByKeys(posByCounts) do
		self:EchoDebug(-negCount, "nanos", "overlap at", position.x, position.z)
		self.sortedCells[#self.sortedCells+1] = position
	end
	self.cellsNeedSorting = false
end

function NanoHandler:GetHotSpots()
	self:SortCells()
	return self.sortedCells
end