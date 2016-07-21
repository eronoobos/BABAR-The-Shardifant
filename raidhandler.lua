local DebugEnabled = false


local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("RaidHandler: " .. inStr)
	end
end

RaidHandler = class(Module)

function RaidHandler:Name()
	return "RaidHandler"
end

function RaidHandler:internalName()
	return "raidhandler"
end

local mCeil = math.ceil

function RaidHandler:Init()
	self.counter = {}
	self.ai.raiderCount = {}
	self.ai.IDsWeAreRaiding = {}

	self.pathGraphs = {}
	self.pathNeighFuncs = {}
	self.pathValidFuncs = {}
	self.nodeSize = 256
	self.halfNodeSize = self.nodeSize / 2
	self.testSize = self.nodeSize / 6
end

function RaidHandler:NeedMore(mtype, add)
	if add == nil then add = 0.1 end
	if mtype == nil then
		for mtype, count in pairs(self.counter) do
			if self.counter[mtype] == nil then self.counter[mtype] = baseRaidCounter end
			self.counter[mtype] = self.counter[mtype] + add
			self.counter[mtype] = math.min(self.counter[mtype], maxRaidCounter)
			EchoDebug(mtype .. " raid counter: " .. self.counter[mtype])
		end
	else
		if self.counter[mtype] == nil then self.counter[mtype] = baseRaidCounter end
		self.counter[mtype] = self.counter[mtype] + add
		self.counter[mtype] = math.min(self.counter[mtype], maxRaidCounter)
		EchoDebug(mtype .. " raid counter: " .. self.counter[mtype])
	end
end

function RaidHandler:NeedLess(mtype)
	if mtype == nil then
		for mtype, count in pairs(self.counter) do
			if self.counter[mtype] == nil then self.counter[mtype] = baseRaidCounter end
			self.counter[mtype] = self.counter[mtype] - 0.5
			self.counter[mtype] = math.max(self.counter[mtype], minRaidCounter)
			EchoDebug(mtype .. " raid counter: " .. self.counter[mtype])
		end
	else
		if self.counter[mtype] == nil then self.counter[mtype] = baseRaidCounter end
		self.counter[mtype] = self.counter[mtype] - 0.5
		self.counter[mtype] = math.max(self.counter[mtype], minRaidCounter)
		EchoDebug(mtype .. " raid counter: " .. self.counter[mtype])
	end
end

function RaidHandler:GetCounter(mtype)
	if mtype == nil then
		local highestCounter = 0
		for mtype, counter in pairs(self.counter) do
			if counter > highestCounter then highestCounter = counter end
		end
		return highestCounter
	end
	if self.counter[mtype] == nil then
		return baseRaidCounter
	else
		return self.counter[mtype]
	end
end

function RaidHandler:IDsWeAreRaiding(unitIDs, mtype)
	for i, unitID in pairs(unitIDs) do
		self.ai.IDsWeAreRaiding[unitID] = mtype
	end
end

function RaidHandler:IDsWeAreNotRaiding(unitIDs)
	for i, unitID in pairs(unitIDs) do
		self.ai.IDsWeAreRaiding[unitID] = nil
	end
end

function RaidHandler:TargetDied(mtype)
	EchoDebug("target died")
	self:NeedMore(mtype, 0.35)
end

function RaidHandler:GetPathGraph(mtype)
	if self.pathGraphs[mtype] then
		return self.pathGraphs[mtype]
	end
	local graph = {}
	local id = 1
	local sizeX = self.ai.elmoMapSizeX
	local sizeZ = self.ai.elmoMapSizeZ
	local nodeSize = self.nodeSize
	local halfNodeSize = self.halfNodeSize
	local testSize = self.testSize
	local maphand = self.ai.maphandler
	for cx = 0, sizeX-nodeSize, nodeSize do
		local x = cx + halfNodeSize
		for cz = 0, sizeZ-nodeSize, nodeSize do
			local z = cz + halfNodeSize
			local canGo = true
			for tx = cx, cx+nodeSize, testSize do
				for tz = cz, cz+nodeSize, testSize do
					if not maphand:MobilityNetworkHere(mtype, {x=tx, z=tz}) then
						canGo = false
						break
					end
				end
				if not canGo then break end
			end
			if canGo then
				local node = { x = x, y = z, id = id }
				graph[id] = node
				id = id + 1
			end
		end
	end
	self.pathGraphs[mtype] = graph
	return graph
end

function RaidHandler:GetPathNeighborFunc(mtype)
	if self.pathNeighFuncs[mtype] then
		return self.pathNeighFuncs[mtype]
	end
	local nodeSize = self.nodeSize
	local nodeDist = 1+ (2 * (nodeSize^2))
	local neighbor_node_func = function ( node, neighbor ) 
		if astar.distance( node.x, node.y, neighbor.x, neighbor.y) < nodeDist then
			return true
		end
		return false
	end
	self.pathNeighFuncs[mtype] = neighbor_node_func
	return neighbor_node_func
end

function RaidHandler:GetPathValidFunc(unitName)
	if self.pathValidFuncs[unitName] then
		return self.pathValidFuncs[unitName]
	end
	local valid_node_func = function ( node )
		return ai.targethandler:IsSafePosition({x=node.x, z=node.y}, unitName, 1)
	end
	self.pathValidFuncs[unitName] = valid_node_func
	return valid_node_func
end

function RaidHandler:GetPathNodeHere(position, graph)
	local nodeSize = self.nodeSize
	local x, z = ConstrainToMap(position.x, position.z)
	local nx = (x - (x % nodeSize)) + mCeil(nodeSize/2)
	local nz = (z - (z % nodeSize)) + mCeil(nodeSize/2)
	local node = astar.find_node(nx, nz, graph) or astar.nearest_node(nx, nz, graph)
	-- spEcho(x, z, nx, nz, nodeSize, mCeil(nodeSize/2), node)
	return node
end

function RaidHandler:GetPathNodeSize()
	return self.nodeSize
end