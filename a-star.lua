-- ======================================================================
-- Copyright (c) 2012 RapidFire Studio Limited 
-- All Rights Reserved. 
-- http://www.rapidfirestudio.com

-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:

-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
-- ======================================================================
-- Modified by eronoobos for use in Cattle and Loveplay, a map for Spring RTS
-- ======================================================================

local astar = {}

----------------------------------------------------------------
-- local variables
----------------------------------------------------------------

local INF = 1/0
local cachedPaths = nil

----------------------------------------------------------------
-- localized functions
----------------------------------------------------------------

local tInsert = table.insert

----------------------------------------------------------------
-- local functions
----------------------------------------------------------------

local function dist ( x1, y1, x2, y2 )
	-- return math.sqrt ( math.pow ( x2 - x1, 2 ) + math.pow ( y2 - y1, 2 ) )
	return (x2-x1)^2 + (y2-y1)^2
	-- return math.abs( (x2-x1) + (y2-y1) )
end

local function dist_between ( nodeA, nodeB )
	return dist ( nodeA.x, nodeA.y, nodeB.x, nodeB.y )
end

local function heuristic_cost_estimate ( nodeA, nodeB )
	return dist ( nodeA.x, nodeA.y, nodeB.x, nodeB.y )
end

local function is_valid_node ( node )
	return true
end

local function is_neighbor_node ( node, neighbor )
	return true
end

local function lowest_f_score ( set, f_score )
	local lowest, bestNode = INF, nil
	for i = 1, #set do
		local node = set[i]
		local score = f_score [ node ]
		if score < lowest then
			lowest, bestNode = score, node
		end
	end
	return bestNode
end

local function neighbor_nodes ( theNode, nodes )
	if theNode.neighbors then return theNode.neighbors end -- use cached neighbors
	local neighbors = {}
	for i = 1, #nodes do
		local node = nodes[i]
		if theNode ~= node and is_valid_node ( node ) and is_neighbor_node ( theNode, node ) then
			neighbors[#neighbors+1] = node
		end
	end
	theNode.neighbors = neighbors -- cache neighbors
	return neighbors
end

local function not_in ( set, theNode )
	for i = 1, #set do
		local node = set[i]
		if node == theNode then return false end
	end
	return true
end

local function remove_node ( set, theNode )
	for i = 1, #set do
		local node = set[i]
		if node == theNode then 
			set [ i ] = set [ #set ]
			set [ #set ] = nil
			break
		end
	end	
end

local function unwind_path ( flat_path, map, current_node )
	if map [ current_node ] then
		tInsert ( flat_path, 1, map [ current_node ] ) 
		return unwind_path ( flat_path, map, map [ current_node ] )
	else
		return flat_path
	end
end

----------------------------------------------------------------
-- pathfinding functions
----------------------------------------------------------------

local function init_pathtry ( pathTry )
	pathTry.closedset = {}
	pathTry.openset = { pathTry.start }
	pathTry.came_from = {}
	pathTry.g_score = {}
	pathTry.f_score = {}
	pathTry.g_score[pathTry.start] = 0
	pathTry.f_score[pathTry.start] = pathTry.g_score[pathTry.start] + heuristic_cost_estimate(pathTry.start, pathTry.goal)
end

local function work_on_pathtry ( pathTry, iterations )
	local pt = pathTry
	if pt.neighbor_node_func then is_neighbor_node = pt.neighbor_node_func end
	if pt.valid_node_func then is_valid_node = pt.valid_node_func end
	local it = 1
	while #pt.openset > 0 and it <= iterations do
		local current = lowest_f_score ( pt.openset, pt.f_score )
		if current == pt.goal then
			local path = unwind_path ( {}, pt.came_from, pt.goal )
			path[#path+1] = pt.goal
			return path, #pt.openset
		end
		remove_node ( pt.openset, current )		
		pt.closedset[#pt.closedset+1] = current
		local neighbors = neighbor_nodes ( current, pt.nodes )
		for i = 1, #neighbors do
			local neighbor = neighbors[i]
			if not_in ( pt.closedset, neighbor ) then
				local tentative_g_score = pt.g_score [ current ] + dist_between ( current, neighbor )
				if not_in ( pt.openset, neighbor ) or tentative_g_score < pt.g_score [ neighbor ] then 
					pt.came_from[ neighbor ] = current
					pt.g_score 	[ neighbor ] = tentative_g_score
					pt.f_score 	[ neighbor ] = pt.g_score [ neighbor ] + heuristic_cost_estimate ( neighbor, pt.goal )
					if not_in ( pt.openset, neighbor ) then
						pt.openset[#pt.openset+1] = neighbor
					end
				end
			end
		end
		it = it + 1
	end
	return nil, #pt.openset
end

local function a_star ( start, goal, nodes, neighbor_node_func, valid_node_func )

	local closedset = {}
	local openset = { start }
	local came_from = {}

	if neighbor_node_func then is_neighbor_node = neighbor_node_func end
	if valid_node_func then is_valid_node = valid_node_func end

	local g_score, f_score = {}, {}
	g_score [ start ] = 0
	f_score [ start ] = g_score [ start ] + heuristic_cost_estimate ( start, goal )

	while #openset > 0 do
	
		local current = lowest_f_score ( openset, f_score )
		if current == goal then
			local path = unwind_path ( {}, came_from, goal )
			path[#path+1] = goal
			return path
		end

		remove_node ( openset, current )		
		closedset[#closedset+1] = current
		
		local neighbors = neighbor_nodes ( current, nodes )
		for i = 1, #neighbors do
			local neighbor = neighbors[i]
			if not_in ( closedset, neighbor ) then
			
				local tentative_g_score = g_score [ current ] + dist_between ( current, neighbor )
				 
				if not_in ( openset, neighbor ) or tentative_g_score < g_score [ neighbor ] then 
					came_from 	[ neighbor ] = current
					g_score 	[ neighbor ] = tentative_g_score
					f_score 	[ neighbor ] = g_score [ neighbor ] + heuristic_cost_estimate ( neighbor, goal )
					if not_in ( openset, neighbor ) then
						openset[#openset+1] = neighbor
					end
				end
			end
		end
	end
	return nil -- no valid path
end

----------------------------------------------------------------
-- exposed functions
----------------------------------------------------------------

function astar.clear_cached_paths ()
	cachedPaths = nil
end

function astar.clear_cached_neighbors ( nodes )
	for i = 1, #nodes do
		local node = nodes[i]
		node.neighbors = nil	
	end
end

function astar.cache_neighbors( nodes, neighbor_node_func, valid_node_func )
	if neighbor_node_func then is_neighbor_node = neighbor_node_func end
	if valid_node_func then is_valid_node = valid_node_func end
	for i = 1, #nodes do
		local node = nodes[i]
		local neighbors = neighbor_nodes(node, nodes)
	end
end

function astar.distance ( x1, y1, x2, y2 )
	return dist ( x1, y1, x2, y2 )
end

function astar.find_node ( x, y, nodes, valid_node_func )
	if valid_node_func then
		is_valid_node = valid_node_func
	else
		is_valid_node = function() return true end
	end
	for i = 1, #nodes do
		local node = nodes[i]
		if is_valid_node(node) then
			if node.x == x and node.y == y then
				return node
			end
		end
	end
end

function astar.nearest_node( x, y, nodes, nodeDist, valid_node_func )
	if valid_node_func then
		is_valid_node = valid_node_func
	else
		is_valid_node = function() return true end
	end
	local bestDist
	local bestNode
	for i = 1, #nodes do
		local node = nodes[i]
		if is_valid_node(node) then
			local d = dist(x, y, node.x, node.y)
			if not bestDist or d < bestDist then
				bestDist = d
				bestNode = node
				if nodeDist and d < nodeDist then break end
			end
		end
	end
	return bestNode
end

function astar.pathtry( start, goal, nodes, ignore_cache, neighbor_node_func, valid_node_func )
	local pathTry = { start=start, goal=goal, nodes=nodes, ignore_cache=ignore_cache, neighbor_node_func=neighbor_node_func, valid_node_func=valid_node_func }
	init_pathtry(pathTry)
	return pathTry
end

function astar.work_pathtry( pathTry, iterations )
	if not cachedPaths then cachedPaths = {} end
	if not cachedPaths [ pathTry.start ] then
		cachedPaths [ pathTry.start ] = {}
	elseif cachedPaths [ pathTry.start ] [ pathTry.goal ] then
		return cachedPaths [ pathTry.start ] [ pathTry.goal ], 0
	end
	return work_on_pathtry(pathTry, iterations)
end

function astar.path ( start, goal, nodes, ignore_cache, neighbor_node_func, valid_node_func )
	if not cachedPaths then cachedPaths = {} end
	if not cachedPaths [ start ] then
		cachedPaths [ start ] = {}
	elseif cachedPaths [ start ] [ goal ] and not ignore_cache then
		return cachedPaths [ start ] [ goal ]
	end
	
	return a_star ( start, goal, nodes, neighbor_node_func, valid_node_func )
end

return astar