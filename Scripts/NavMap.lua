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
	for i = 1, #self.navRegions do
		self.navRegions[i]:SetIndex(i)
	end
end

function NavMap:SetCurRegion(region)
	self.curRegion = region
end

function NavMap:SetActiveIndex(index)
	for i = 1, #self.enemies do
		self.enemies[i]:UpdateFollowPath()
	end
	self.prevIndex = self.activeIndex
	self.activeIndex = index
end

function NavMap:RollbackActiveIndex()
	self.activeIndex = self.prevIndex
end

function NavMap:GetActiveIndex()
	return self.activeIndex
end

function NavMap:GetPathToPlayer(index)
	return self:AStar(index, finalIndex)
end

function NavMap:GetRegionPos(index)
	return self.navRegions[index]:GetWorldPosition()
end

function NavMap:AStar(initialIndex, finalIndex)
	openList = {}
	closedList = {}
	parents = {}

	for i = 1, #self.navRegions do
		parents[i] = nil
	end

	table.insert(openList, {initialIndex, 0})


	while not (next(openList) == nil) do
		
	--[[
		for i = 1, #openList do
			Log.Debug(string.format("%d, %d", openList[i][1], openList[i][2]))
		end
	]]--
		curNode = -1
		minF = inf
		curNodei = -1
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

		neighbors = self.navRegions[curNode]:GetNeighbors()
		for neighbor in neighbors do
			parents[neighbor:GetIndex()] = curNode

			if neighbor:GetIndex() == finalIndex then
				openList = {}
				break
			end

			-- f = g + h
			f =	curF + (self.navRegions[neighbor:GetIndex()]:GetWorldPosition():GetDistance(self.navRegions[finalIndex]:GetWorldPosition()))
			Log.Debug(f)

			addToOpen = true
			for o in openList do
				if o[1] == neighbor:GetIndex() and o[2] < f then
					addToOpen = false
					break
				end
			end

			if addToOpen then
				for c in closedList do
					if c[1] == neighbor:GetIndex() and c[2] < f then
						addToOpen = false
						break
					end
				end
			end

			if addToOpen then
				table.insert(openList, {neighbor:GetIndex(), f})
			end
		end
	end


	reversedpath = {finalIndex}
	parent = parents[finalIndex]
	while not parents[parent] == nil do
		
	end

	finalpath = {}
	for p = #reversedpath, 1 do
		finalpath:insert(reversedpath[i])
	end
	
	return finalpath
end