local DebugEnabled = false


local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("RaiderBehaviour: " .. inStr)
	end
end

local CMD_IDLEMODE = 145
local CMD_MOVE_STATE = 50
local MOVESTATE_ROAM = 2

function IsRaider(unit)
	for i,name in ipairs(raiderList) do
		if name == unit:Internal():Name() then
			return true
		end
	end
	return false
end

RaiderBehaviour = class(Behaviour)

function RaiderBehaviour:Init()
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
end

function RaiderBehaviour:OwnerDead()
	-- game:SendToConsole("raider " .. self.name .. " died")
	if self.target then
		self.ai.targethandler:AddBadPosition(self.target, self.mtype)
	end
	self.ai.raidhandler:NeedLess(self.mtype)
	self.ai.raiderCount[self.mtype] = self.ai.raiderCount[self.mtype] - 1
end

function RaiderBehaviour:OwnerIdle()
	self.target = nil
	self.evading = false
	-- keep planes from landing (i'd rather set land state, but how?)
	if self.mtype == "air" then
		self.moveNextUpdate = RandomAway(self.unit:Internal():GetPosition(), 500)
	end
	self.unit:ElectBehaviour()
end

function RaiderBehaviour:RaidCell(cell)
	EchoDebug(self.name .. " raiding cell...")
	if self.unit == nil then
		EchoDebug("no raider unit to raid cell with!")
		-- self.ai.raidhandler:RemoveRecruit(self)
	elseif self.unit:Internal() == nil then 
		EchoDebug("no raider unit internal to raid cell with!")
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
			EchoDebug("air raid target: " .. tostring(self.unitTarget.unitName))
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
	EchoDebug(self.name .. " active")
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
	EchoDebug(self.name .. " inactive")
	self.active = false
	self.target = nil
end

function RaiderBehaviour:Update()
	local f = game:Frame()

	if not self.active then
		if f % 89 == 0 then
			local unit = self.unit:Internal()
			local bestCell = self.ai.targethandler:GetBestRaidCell(unit)
			self.ai.targethandler:RaiderHere(self)
			if bestCell then
				EchoDebug(self.name .. " got target")
				self:RaidCell(bestCell)
			else
				self.target = nil
				self.unit:ElectBehaviour()
				-- revert to scouting
			end
		end
	else
		self:FindPath()
		self:UpdatePathProgress()
		if self.moveNextUpdate then
			self.unit:Internal():Move(self.moveNextUpdate)
			self.moveNextUpdate = nil
		elseif f % 29 == 0 then
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
						EchoDebug(self.name .. " evading")
						unit:Move(newPos)
						self.evading = true
					elseif arrived then
						EchoDebug(self.name .. " arrived")
						-- if we're at the target
						self.evading = false
					elseif self.evading then
						EchoDebug(self.name .. " setting course to taget")
						-- return to course to target after evading
						if self.mtype == "air" then
							if self.unitTarget ~= nil then
								CustomCommand(self.unit:Internal(), CMD_ATTACK, {self.unitTarget.unitID})
							end
						else
							self.unit:Internal():Move(self.target)
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
		EchoDebug("getting new path")
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
	EchoDebug(tostring(remaining) .. " remaining to find path")
	if path then
		EchoDebug("got path")
		self.pathTry = nil
		self:ReceivePath(path)
	elseif remaining == 0 then
		EchoDebug("no path found?")
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
				EchoDebug("path is not clear shot")
				self.clearShot = false
				break
			end
		end
	end
	if DebugEnabled then
		self.map:EraseLine(nil, nil, {0,1,1}, self.unit:Internal():ID(), true, 3)
		for i = 2, #self.path do
			local p1 = self.path[i-1]
			local p2 = self.path[i]
			local pos1 = api.Position()
			pos1.x, pos1.z = p1.x, p1.y
			local pos2 = api.Position()
			pos2.x, pos2.z = p2.x, p2.y
			self.map:DrawLine(pos1, pos2, {0,1,1}, self.unit:Internal():ID(), true, 3)
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
			EchoDebug("advancing to next step of path " .. self.pathStep)
			self.targetNode = self.path[self.pathStep]
		end
		local move = false
		if self.target.x ~= self.targetNode.x and self.target.z ~= self.targetNode.y then
			move = true
		end
		self.target = api.Position()
		self.target.x = self.targetNode.x
		self.target.z = self.targetNode.y
		if move then
			EchoDebug("moving to target node")
			self.unit:Internal():Move(self.target)
		end
	end
end