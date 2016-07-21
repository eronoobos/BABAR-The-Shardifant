function IsRaider(unit)
	for i,name in ipairs(raiderList) do
		if name == unit:Internal():Name() then
			return true
		end
	end
	return false
end

RaiderBehaviour = class(Behaviour)

function RaiderBehaviour:Name()
	return "RaiderBehaviour"
end

local CMD_IDLEMODE = 145
local CMD_MOVE_STATE = 50
local MOVESTATE_ROAM = 2

function RaiderBehaviour:Init()
	self.DebugEnabled = true

	local mtype, network = self.ai.maphandler:MobilityOfUnit(self.unit:Internal())
	self.mtype = mtype
	self.name = self.unit:Internal():Name()
	local utable = unitTable[self.name]
	if self.mtype == "sub" then
		self.range = utable.submergedRange
	else
		self.range = utable.groundRange
	end
	self.pathingRadius = self.range * 0.33
	self.id = self.unit:Internal():ID()
	self.disarmer = raiderDisarms[self.name]
	if self.ai.raiderCount[mtype] == nil then
		self.ai.raiderCount[mtype] = 1
	else
		self.ai.raiderCount[mtype] = self.ai.raiderCount[mtype] + 1
	end
	self.lastGetTargetFrame = 0
	self.lastMovementFrame = 0
end

function RaiderBehaviour:OwnerDead()
	-- game:SendToConsole("raider " .. self.name .. " died")
	if self.DebugEnabled then
		self.map:EraseLine(nil, nil, {0,1,1}, self.unit:Internal():ID(), true, 8)
	end
	if self.target then
		self.ai.targethandler:AddBadPosition(self.target, self.mtype)
	end
	self.ai.raidhandler:NeedLess(self.mtype)
	self.ai.raiderCount[self.mtype] = self.ai.raiderCount[self.mtype] - 1
end

function RaiderBehaviour:OwnerIdle()
	self.evading = false
	-- keep planes from landing (i'd rather set land state, but how?)
	if self.mtype == "air" then
		self.moveNextUpdate = RandomAway(self.unit:Internal():GetPosition(), 500)
	end
	self.unit:ElectBehaviour()
end

function RaiderBehaviour:RaidCell(cell)
	self:EchoDebug(self.name .. " raiding cell...")
	if self.unit == nil then
		self:EchoDebug("no raider unit to raid cell with!")
		-- self.ai.raidhandler:RemoveRecruit(self)
	elseif self.unit:Internal() == nil then 
		self:EchoDebug("no raider unit internal to raid cell with!")
		-- self.ai.raidhandler:RemoveRecruit(self)
	else
		if self.buildingIDs ~= nil then
			self.ai.raidhandler:IDsWeAreNotRaiding(self.buildingIDs)
		end
		self.ai.raidhandler:IDsWeAreRaiding(cell.buildingIDs, self.mtype)
		self.buildingIDs = cell.buildingIDs
		self.target = RandomAway(cell.pos, self.range * 0.5)
		self:BeginPath(self.target)
		if self.mtype == "air" then
			if self.disarmer then
				self.unitTarget = cell.disarmTarget
			else
				self.unitTarget = cell.targets.air.ground
			end
			self:EchoDebug("air raid target: " .. tostring(self.unitTarget.unitName))
		end
		if self.active then
			if self.mtype == "air" then
				if self.unitTarget ~= nil then
					CustomCommand(self.unit:Internal(), CMD_ATTACK, {self.unitTarget.unitID})
				end
			else
				self.unit:Internal():Move(self.target)
			end
		end
		self.unit:ElectBehaviour()
	end
end

function RaiderBehaviour:Priority()
	if not self.target then
		-- revert to scouting
		return 0
	else
		return 100
	end
end

function RaiderBehaviour:Activate()
	self:EchoDebug("activate")
	self.active = true
	if self.target then
		if self.mtype == "air" then
			if self.unitTarget ~= nil then
				CustomCommand(self.unit:Internal(), CMD_ATTACK, {self.unitTarget.unitID})
			end
		else
			self.unit:Internal():Move(self.target)
		end
	end
end

function RaiderBehaviour:Deactivate()
	self:EchoDebug("deactivate")
	self.active = false
	self.target = nil
	self.pathTry = nil
end

function RaiderBehaviour:Update()
	local f = game:Frame()

	if not self.active then
		if f > self.lastGetTargetFrame + 90 then
			self.lastGetTargetFrame = f
			local unit = self.unit:Internal()
			local bestCell = self.ai.targethandler:GetBestRaidCell(unit)
			self.ai.targethandler:RaiderHere(self)
			if bestCell then
				self:EchoDebug(self.name .. " got target")
				self:RaidCell(bestCell)
			else
				self.target = nil
				self.pathTry = nil
				self.unit:ElectBehaviour()
				-- revert to scouting
			end
		end
	else
		self:FindPath()
		if self.moveNextUpdate then
			self.unit:Internal():Move(self.moveNextUpdate)
			self.moveNextUpdate = nil
		elseif f > self.lastMovementFrame + 30 then
			self:UpdatePathProgress()
			self.lastMovementFrame = f
			-- attack nearby vulnerables immediately
			local unit = self.unit:Internal()
			local attackTarget
			if self.ai.targethandler:IsSafePosition(unit:GetPosition(), unit, 1) then
				attackTarget = self.ai.targethandler:NearbyVulnerable(unit)
			end
			if attackTarget then
				CustomCommand(unit, CMD_ATTACK, {attackTarget.unitID})
			else
				-- evade enemies on the way to the target, if possible
				if self.target ~= nil then
					local newPos, arrived = self.ai.targethandler:BestAdjacentPosition(unit, self.target)
					self.ai.targethandler:RaiderHere(self)
					if newPos then
						self:EchoDebug(self.name .. " evading")
						unit:Move(newPos)
						self.evading = true
						self:BeginPath()
					elseif arrived then
						self:EchoDebug(self.name .. " arrived")
						-- if we're at the target
						self.evading = false
					elseif self.evading then
						self:EchoDebug(self.name .. " setting course to taget")
						-- return to course to target after evading
						if self.mtype == "air" then
							if self.unitTarget ~= nil then
								CustomCommand(self.unit:Internal(), CMD_ATTACK, {self.unitTarget.unitID})
							end
						else
							self:ResumeCourse()
						end
						self.evading = false
					end
				end
			end
		end
	end
end

-- set all raiders to roam
function RaiderBehaviour:SetMoveState()
	local thisUnit = self.unit
	if thisUnit then
		local floats = api.vectorFloat()
		floats:push_back(MOVESTATE_ROAM)
		thisUnit:Internal():ExecuteCustomCommand(CMD_MOVE_STATE, floats)
		if self.mtype == "air" then
			local floats = api.vectorFloat()
			floats:push_back(1)
			thisUnit:Internal():ExecuteCustomCommand(CMD_IDLEMODE, floats)
		end
	end
end

function RaiderBehaviour:BeginPath(position)
	if self.pathed ~= position then
		-- need a new path
		self:EchoDebug("getting new path")
		local graph = self.ai.raidhandler:GetPathGraph(self.mtype)
		local startNode = self.ai.raidhandler:GetPathNodeHere(self.unit:Internal():GetPosition(), graph)
		if startNode then
			local goalNode = self.ai.raidhandler:GetPathNodeHere(position, graph)
			if goalNode and startNode ~= goalNode then
				local neighFunc = self.ai.raidhandler:GetPathNeighborFunc(self.mtype)
				local validFunc = self.ai.raidhandler:GetPathValidFunc(self.unit:Internal():Name())
				self.pathTry = astar.pathtry(startNode, goalNode, graph, true, neighFunc, validFunc)
				self.pathed = position
				self:FindPath() -- try once
			end
		end
	end 
end

function RaiderBehaviour:FindPath()
	if not self.pathTry then return end
	local path, remaining = astar.work_pathtry(self.pathTry, 3)
	self:EchoDebug(tostring(remaining) .. " remaining to find path")
	if path then
		self:EchoDebug("got path")
		self.pathTry = nil
		self:ReceivePath(path)
	elseif remaining == 0 then
		self:EchoDebug("no path found?")
		self.pathTry = nil
	end
end

function RaiderBehaviour:ReceivePath(path)
	if not path then return end
	self.path = path
	if not self.path[2] then
		self.pathStep = 1
	else
		self.pathStep = 2
	end
	self.targetNode = self.path[self.pathStep]
	self.clearShot = true
	if #self.path > 2 then
		for i = 2, #self.path-1 do
			local node = self.path[i]
			if node and #node.neighbors < 8 then
				self:EchoDebug("path is not clear shot")
				self.clearShot = false
				self:ResumeCourse()
				break
			end
		end
	end
	if self.DebugEnabled then
		self.map:EraseLine(nil, nil, {0,1,1}, self.unit:Internal():ID(), true, 8)
		for i = 2, #self.path do
			local p1 = self.path[i-1]
			local p2 = self.path[i]
			local pos1 = api.Position()
			pos1.x, pos1.z = p1.x, p1.y
			local pos2 = api.Position()
			pos2.x, pos2.z = p2.x, p2.y
			self.map:DrawLine(pos1, pos2, {0,1,1}, self.unit:Internal():ID(), true, 8)
		end
	end
end

function RaiderBehaviour:UpdatePathProgress()
	if self.targetNode and not self.clearShot then
		-- have a path and it's not clear
		local myPos = self.unit:Internal():GetPosition()
		local x = myPos.x
		local z = myPos.z
		local r = self.pathingRadius
		local nx, nz = self.targetNode.x, self.targetNode.y
		if nx < x + r and nx > x - r and nz < z + r and nz > z - r and self.pathStep < #self.path then
			-- we're at the targetNode and it's not the last node
			self.pathStep = self.pathStep + 1
			self:EchoDebug("advancing to next step of path " .. self.pathStep)
			self.targetNode = self.path[self.pathStep]
			self:MoveToNode(self.targetNode)
		end
	end
end

function RaiderBehaviour:ResumeCourse()
	if self.path then
		self:EchoDebug("resuming course on path")
		local upos = self.unit:Internal():GetPosition()
		local lowestDist
		local nearestNode
		local nearestStep
		for i = 1, #self.path do
			local node = self.path[i]
			local dx = upos.x - node.x
			local dz = upos.z - node.y
			local distSq = dx*dx + dz*dz
			if not lowestDist or distSq < lowestDist then
				lowestDist = distSq
				nearestNode = node
				nearestStep = i
			end
		end
		if nearestNode then
			self.targetNode = nearestNode
			self.pathStep = nearestStep
			self:MoveToNode(self.targetNode)
		end
	else
		self:EchoDebug("resuming course directly to target")
		self.unit:Internal():Move(self.target)
	end
end

function RaiderBehaviour:MoveToNode(node)
	local movePos = api.Position()
	movePos.x = node.x
	movePos.z = node.y
	self:EchoDebug("moving to node")
	self.unit:Internal():Move(movePos)
end