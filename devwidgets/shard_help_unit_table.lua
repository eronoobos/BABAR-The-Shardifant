function widget:GetInfo()
	return {
		name	= "Shard Help: Unit Table",
		desc	= "from the unitdefs it creates a text file that is a lua table of unit characteristics to augment shard's interface",
		author	= "eronoobos",
		date 	= "November 28, 2013, updated June 2016",
		license	= "whatever",
		layer 	= 0,
		enabled	= false
	}
end

local hoverplatform = {
	armhp = 1,
	armfhp = 1,
	corhp = 1,
	corfhp = 1,
}

local fighter = {
	armfig = 1,
	corveng = 1,
	armhawk = 1,
	corvamp = 1,
}

local function serialize (o, outfile, keylist, level)
	keylist = keylist or ""
	level = level or 0
	if type(o) == "number" then
		outfile:write(o)
	elseif type(o) == "boolean" then
		outfile:write(tostring(o))
	elseif type(o) == "string" then
		outfile:write(string.format("%q", o))
	elseif type(o) == "table" then
		level = level + 1
		outfile:write("{\n")
		for k,v in pairs(o) do
			for i=1,level do outfile:write("  ") end
			outfile:write("[")
			serialize(k, outfile, nil, level)
			outfile:write("] = ")
			local newkeylist
			if type(v) == "table" or type(v) == "userdata" then
				if type(k) == "string" then
					newkeylist = keylist .. "[\""  .. k .. "\"]"
				elseif type(k) == "number" then
					newkeylist = keylist .. "["  .. k .. "]"
				end
			end
			serialize(v, outfile, newkeylist, level)
			outfile:write(",\n")
		end
		if level > 1 then for i=1,level-1 do outfile:write("  ") end end
		outfile:write("}")
	else
		error("cannot serialize a " .. type(o))
	end
end

local function GetLongestWeaponRange(unitDefID, GroundAirSubmerged)
	local weaponRange = 0
	local unitDef = UnitDefs[unitDefID]
	local weapons = unitDef["weapons"]
	for i=1, #weapons do
		local weaponDefID = weapons[i]["weaponDef"]
		local weaponDef = WeaponDefs[weaponDefID]
		-- Spring.Echo(weaponDefID)
		-- Spring.Echo(weaponDef["canAttackGround"])
		-- Spring.Echo(weaponDef["waterWeapon"])
		-- Spring.Echo(weaponDef["range"])
		local wType = 0
		if not weaponDef["canAttackGround"] then
			wType = 1
		elseif weaponDef["waterWeapon"] then
			wType = 2
		else
			wType = 0
		end
		-- Spring.Echo(wType)
		if wType == GroundAirSubmerged then
			if weaponDef["range"] > weaponRange then
				weaponRange = weaponDef["range"]
			end
		end
	end
	return weaponRange
end

function widget:Initialize()
	local unitTable = {}
	local featureTable = {}
	local wrecks = {}
	for unitDefID,unitDef in pairs(UnitDefs) do
		-- Spring.Echo(unitDef.name, "build slope", unitDef.maxHeightDif)
		-- if unitDef.moveDef.maxSlope then
			-- Spring.Echo(unitDef.name, "move slope", unitDef.moveDef.maxSlope)
		-- end
		local utable = {}
		if unitDef["modCategories"]["weapon"] then
			utable.isWeapon = true
		else
			utable.isWeapon = false
		end
		if unitDef["isBuilding"] then
			utable.isBuilding = true
		else
			utable.isBuilding = false
		end
		utable.groundRange = GetLongestWeaponRange(unitDefID, 0)
		utable.airRange = GetLongestWeaponRange(unitDefID, 1)
		utable.submergedRange = GetLongestWeaponRange(unitDefID, 2)
		if fighter[unitDef["name"]] then
			utable.airRange = utable.groundRange
		end
		utable.radarRadius = unitDef["radarRadius"]
		utable.airLosRadius = unitDef["airLosRadius"]
		utable.losRadius = unitDef["losRadius"]
		utable.sonarRadius = unitDef["sonarRadius"]
		utable.jammerRadius = unitDef["jammerRadius"]
		utable.stealth = unitDef["stealth"]
		utable.metalCost = unitDef["metalCost"]
		utable.energyCost = unitDef["energyCost"]
		utable.buildTime = unitDef["buildTime"]
		utable.totalEnergyOut = unitDef["totalEnergyOut"]
		utable.extractsMetal = unitDef["extractsMetal"]
		if unitDef["minWaterDepth"] > 0 then
			utable.needsWater = true
		else
			utable.needsWater = false
		end
		utable.techLevel = unitDef["techLevel"]
		if hoverplatform[unitDef["name"]] then
			utable.techLevel = utable.techLevel - 0.5
		end
		if unitDef["canFly"] then
			utable.mtype = "air"
		elseif unitDef["modCategories"]["underwater"] or (unitDef["isBuilding"] and unitDef["minWaterDepth"] > 0 and unitDef["modCategories"]["surface"] and not unitDef["floatOnWater"]) then
			utable.mtype = "sub"
		elseif unitDef["modCategories"]["ship"] or (unitDef["isBuilding"] and unitDef["minWaterDepth"] > 0 and unitDef["modCategories"]["surface"] and unitDef["floatOnWater"]) then
			utable.mtype = "shp"
		elseif unitDef["modCategories"]["phib"] then
			utable.mtype = "amp"
		elseif unitDef["modCategories"]["hover"] then
			utable.mtype = "hov"
		elseif unitDef["modCategories"]["kbot"] then
			utable.mtype = "bot"
		else
			utable.mtype = "veh"
		end
		if unitDef["isBuilder"] and #unitDef["buildOptions"] > 0 then
			utable.buildOptions = true
			utable.factoriesCanBuild = {}
			for i, oid in pairs (unitDef["buildOptions"]) do
				local buildDef = UnitDefs[oid]
				if #buildDef["buildOptions"] > 0 and buildDef["isBuilding"] then
					-- build option is a factory, add it to factories this unit can build
					table.insert(utable.factoriesCanBuild, buildDef["name"])
				end
			end
		end
		utable.bigExplosion = unitDef["deathExplosion"] == "atomic_blast"
		utable.xsize = unitDef["xsize"]
		utable.zsize = unitDef["zsize"]
		utable.wreckName = unitDef["wreckName"]
		wrecks[unitDef["wreckName"]] = unitDef["name"]
		unitTable[unitDef.name] = utable
	end

	local featureKeysToGet = { "metal" , "energy", "reclaimable", "blocking", }

	-- feature defs
	for featureDefID, featureDef in pairs(FeatureDefs) do
		local ftable = {}
		for i, k in pairs(featureKeysToGet) do
			local v = featureDef[k]
			ftable[k] = v
		end
		if wrecks[featureDef["name"]] then
			ftable.unitName = wrecks[featureDef["name"]]
		end
		featureTable[featureDef.name] = ftable
	end

	local unitFile = io.open('unittable.lua', 'w')
	unitFile:write("unitTable = \n\n")
	serialize(unitTable, unitFile)
	unitFile:close()
	local featureFile = io.open('featuretable.lua', 'w')
	featureFile:write("featureTable = \n\n")
	serialize(featureTable, featureFile)
	featureFile:close()
end