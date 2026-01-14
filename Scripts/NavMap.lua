NavMap = {}

function NavMap:Create()
	self.navRegions = nil
	self.enemies = nil
	self.curRegion = 0
	self.activeIndex = -1
	self.prevIndex = -1
end

function NavMap:GatherProperties()

    return
    {
        { name = "navRegions", type = DatumType.Node, array = true },
		{name = "enemies", type = DatumType.Node, array = true}
    }

end

function NavMap:Start()
	--[[
	for i = 1, #self.navRegions do
		self.navRegions[i]:SetIndex(i)
	end
	]]--
	Log.Debug("=== A-STAR TEST===")
	local path = self:AStar(4, 11)

	Log.Debug("--Path--")
	tprint(path)

	local colorStart = Vec(1,0,0,1)
	local colorEnd = Vec(0,1,0,1)
	for i = 1, #path do 
		if (path[i+1]) then
			local lineStart = self.navRegions[path[i]]:GetWorldPosition()
			local lineEnd = self.navRegions[path[i+1]]:GetWorldPosition()
			local lineColor = Vector.Lerp(colorStart, colorEnd, (i-1) / (#path - 1))
			local lineTime = 5.0
			Renderer.AddDebugLine(lineStart, lineEnd, lineColor, lineTime)

		end
	end
end

function NavMap:SetCurRegion(region)
	self.curRegion = region
end

function NavMap:SetActiveIndex(index)
	self.prevIndex = self.activeIndex
	self.activeIndex = index
	for i = 1, #self.enemies do
		self.enemies[i]:UpdateFollowPath(self.activeIndex)
	end
end

function NavMap:RollbackActiveIndex()
	-- self.activeIndex = self.prevIndex
end

function NavMap:GetActiveIndex()
	return self.activeIndex
end

function NavMap:GetPathToPlayer(index)
	return self:AStar(index, self.activeIndex)
end

function NavMap:GetRegionPos(index)
	return self.navRegions[index]:GetWorldPosition()
end

function tprint (tbl, indent)
  if not indent then indent = 0 end
  for k, v in pairs(tbl) do
    formatting = string.rep("  ", indent) .. k .. ": "
    if type(v) == "table" then
      Log.Debug(formatting)
      tprint(v, indent+1)
    else
      Log.Debug(formatting .. tostring(v))
    end
  end
end

function NavMap:AStar(initialIndex, finalIndex)
	openList = {}
	closedList = {}
	closedIndices = {}
	parents = {}

	for i = 1, #self.navRegions do
		parents[i] = nil
	end

	-- table.insert(openList, {initialIndex, 0})
	openList[1] = {initialIndex, 0}

	while not (next(openList) == nil) do
		-- minF = inf
		minF = 100000000000
		curNodei = -1
		curNode = -1
		for i = 1, #openList do
			if openList[i][2] < minF then
				curNode = openList[i][1]
				curNodei = i
				minF = openList[i][2]
			end
		end

		curF = minF
		table.remove(openList, curNodei)
		table.insert(closedList, {curNode, curF})
		closedIndices[curNode] = true

		Log.Debug("CurNode = " .. curNode .. ", " .. curF)

		neighbors = self.navRegions[curNode]:GetNeighbors()
		for i = 1, #neighbors do
			--Check that neighbor isn't closed
			if (not closedIndices[neighbors[i]:GetIndex()]) then
				parents[neighbors[i]:GetIndex()] = curNode

				if neighbors[i]:GetIndex() == finalIndex then
					openList = {}
					break
				end

				-- f = g + h
				-- Log.Debug("--Neighbors-- " .. i)
				-- tprint(neighbors)
				-- Log.Debug("--NavRegions--")
				-- tprint(self.navRegions)

				-- Log.Debug("Index = " .. tostring(neighbors[i]:GetIndex()))


				f =	curF + (self.navRegions[neighbors[i]:GetIndex()]:GetWorldPosition():Distance(self.navRegions[finalIndex]:GetWorldPosition()))

				addToOpen = true
				for o = 1, #openList do
					if openList[o][1] == neighbors[i]:GetIndex() and openList[o][2] < f then
						addToOpen = false
						break
					end
				end

				if addToOpen then
					for c = 1, #closedList do
						if closedList[c][1] == neighbors[i]:GetIndex() and closedList[c][2] < f then
							addToOpen = false
							break
						end
					end
				end

				if addToOpen then
					Log.Debug("Add to open: " .. neighbors[i]:GetIndex() .. ", " .. f)
					table.insert(openList, {neighbors[i]:GetIndex(), f})
				end
			end
		end
	end

	Log.Debug("--Parents--")
	tprint(parents)

	Log.Debug("--Closed--")
	tprint(closedList)

	Log.Debug("finalIndex = " .. finalIndex)

	reversedpath = {finalIndex}
	parent = parents[finalIndex]

	Log.Debug("parents[finalIndex] = " .. tostring(parent))

	local maxIter = 500
	while parent ~= nil do
		Log.Debug("Add " .. parent)
		table.insert(reversedpath, parent)
		parent = parents[parent]
		maxIter = maxIter - 1
		if (maxIter <= 0) then break end
	end	

	Log.Debug("--RevPath--")
	tprint(reversedpath)

	

	finalpath = {}
	for p = #reversedpath, 1, -1 do
		table.insert(finalpath, reversedpath[p])
	end
	
	return finalpath
end