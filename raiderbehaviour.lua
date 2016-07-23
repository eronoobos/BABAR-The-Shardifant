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
	self.nearDistance = self.ai.raidhandler:GetPathNodeSize() * 0.25
	self.arrivalRadius = self.range * 0.5
	self.pathingRadius = self.ai.raidhandler:GetPathNodeSize() * 0.67
	self.minPathfinderDistance = self.ai.raidhandler:GetPathNodeSize() * 3
	self.id = self.unit:Internal():ID()
	self.disarmer = raiderDisarms[self.name]
	if self.ai.raiderCount[mtype] == nil then
		self.ai.raiderCount[mtype] = 1
	else
		self.ai.raiderCount[mtype] = self.ai.raiderCount[mtype] + 1
	end
	self.lastGetTargetFrame = 0
	self.lastMovementFrame = 0
	self.lastPathCheckFrame = 0
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
	self:ArrivalCheck()
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
		self.target = cell.pos
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
			self:EchoDebug("is active")
			if self.mtype == "air" then
				if self.unitTarget ~= nil then
					CustomCommand(self.unit:Internal(), CMD_ATTACK, {self.unitTarget.unitID})
				end
			else
				self:EchoDebug("moving near target")
				self:MoveNear(self.target)
			end
		end
		self:EchoDebug("electing behaviour")
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
			self:MoveNear(self.target)
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
			self:GetTarget()
		end
	else
		if self.path and f > self.lastPathCheckFrame + 90 then
			self.lastPathCheckFrame = f
			self:CheckPath()
		end
		self:FindPath()
		if self.moveNextUpdate then
			self.unit:Internal():Move(self.moveNextUpdate)
			self.moveNextUpdate = nil
		elseif f > self.lastMovementFrame + 30 then
			self.lastMovementFrame = f
			-- attack nearby vulnerables immediately
			local unit = self.unit:Internal()
			local attackTarget
			local safe = self.ai.targethandler:IsSafePosition(unit:GetPosition(), unit, 1)
			if safe then
				attackTarget = self.ai.targethandler:NearbyVulnerable(unit)
			end
			if attackTarget then
				CustomCommand(unit, CMD_ATTACK, {attackTarget.unitID})
			else
				if self.target ~= nil then
					self.ai.targethandler:RaiderHere(self)
					self:ArrivalCheck()
					self:UpdatePathProgress()
					-- evade enemies on the way to the target, if possible
					-- local newPos, arrived = self.ai.targethandler:BestAdjacentPosition(unit, self.target)
					-- if newPos then
					-- 	self:EchoDebug(self.name .. " evading")
					-- 	unit:Move(newPos)
					-- 	self.evading = true
					-- 	self.path = nil
					-- 	self.pathStep = nil
					-- 	self.targetNode = nil
					-- 	self:BeginPath(self.target)
					-- elseif arrived then
					-- 	self:EchoDebug(self.name .. " arrived")
					-- 	-- if we're at the target
					-- 	self:MoveNear(self.target)
					-- 	self.evading = false
					-- 	self:GetTarget()
					-- elseif self.evading then
					-- 	self:EchoDebug(self.name .. " setting course to taget")
					-- 	-- return to course to target after evading
					-- 	if self.mtype == "air" then
					-- 		if self.unitTarget ~= nil then
					-- 			CustomCommand(self.unit:Internal(), CMD_ATTACK, {self.unitTarget.unitID})
					-- 		end
					-- 	else
					-- 		self:ResumeCourse()
					-- 	end
					-- 	self.evading = false
					-- else
					-- 	self:ArrivalCheck()
					-- 	self:UpdatePathProgress()
					-- end
				end
			end
		end
	end
end

function RaiderBehaviour:MoveNear(position)
	self.unit:Internal():Move(RandomAway(position, self.nearDistance))
end

function RaiderBehaviour:GetTarget()
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

function RaiderBehaviour:ArrivalCheck()
	if not self.target then return end
	if Distance(self.unit:Internal():GetPosition(), self.target) < self.arrivalRadius then
		self:MoveNear(self.target)
		self:EchoDebug("arrived at target")
		self:GetTarget()
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
	-- need a new path?
	if self.pathedTarget == position and self.pathedOrigin == self.unit:Internal():GetPosition() then
		return
	end
	if Distance(position, self.unit:Internal():GetPosition()) < self.minPathfinderDistance then
		return
	end
	self:EchoDebug("getting new path")
	local graph = self.ai.raidhandler:GetPathGraph(self.mtype)
	local upos = self.unit:Internal():GetPosition()
	local validFunc = self.ai.raidhandler:GetPathValidFunc(self.unit:Internal():Name())
	self.pathTry = graph:PathfinderXYXY(upos.x, upos.z, position.x, position.z, nil, validFunc)
	self.pathedTarget = position
	self.pathedOrigin = self.unit:Internal():GetPosition()
	self:FindPath() -- try once
end

function RaiderBehaviour:FindPath()
	if not self.pathTry then return end
	local path, remaining, maxInvalid = self.pathTry:Find(1)
	-- self:EchoDebug(tostring(remaining) .. " remaining to find path")
	if path then
		self:EchoDebug("got path of", #path, "nodes", maxInvalid, "maximum invalid neighbors")
		self.pathTry = nil
		if maxInvalid == 0 then
			self:EchoDebug("path is entirely clear of danger, not using")
		else
			self:ReceivePath(path)
		end
	elseif remaining == 0 then
		self:EchoDebug("no path found")
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
	self:ResumeCourse()
	-- self.clearShot = true
	-- if #self.path > 2 then
	-- 	for i = 2, #self.path-1 do
	-- 		local node = self.path[i]
	-- 		if node and #node.neighbors < 8 then
	-- 			self:EchoDebug("path is not clear shot")
	-- 			self.clearShot = false
	-- 			self:ResumeCourse()
	-- 			break
	-- 		end
	-- 	end
	-- end
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
			if self.pathStep == #self.path then
				self:MoveNear(self.target)
			else
				self:MoveToNode(self.targetNode)
			end
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
			if self.pathStep == #self.path then
				self:MoveNear(self.target)
			else
				self:MoveToNode(self.targetNode)
			end
		end
	else
		self:EchoDebug("resuming course directly to target")
		self:MoveNear(self.target)
	end
end

function RaiderBehaviour:MoveToNode(node)
	self:EchoDebug("moving to node")
	self:MoveNear(node.position)
end

function RaiderBehaviour:CheckPath()
	if not self.path then return end
	for i = self.pathStep, #self.path do
		local node = self.path[i]
		if not self.ai.targethandler:IsSafePosition(node.position, self.name, 1) then
			self:EchoDebug("unsafe path, get a new one")
			self:ResetPath(true)
			return
		end
	end
end

function RaiderBehaviour:ResetPath(moveToTarget)
	self.path = nil
	self.pathStep = nil
	self.targetNode = nil
	self:BeginPath(self.target)
	-- if moveToTarget then self:MoveNear(self.target) end
	self:MoveToSafety()
end

function RaiderBehaviour:MoveToSafety()
	local upos = self.unit:Internal():GetPosition()
	local graph = self.ai.raidhandler:GetPathGraph(self.mtype)
	local validFunc = self.ai.raidhandler:GetPathValidFunc(self.unit:Internal():Name())
	local node = graph:NearestNode(upos.x, upos.z, validFunc)
	if node then
		self:MoveNear(node.position)
	else
		self:MoveNear(self.target)
	end
end