NavRegion = { }

function NavRegion:Create()
	self.navMap = nil
	self.neighbors = nil
	self.index = -1
end

function NavRegion:GatherProperties()

    return
    {
        { name = "neighbors", type = DatumType.Node, array = true },
    }

end

function NavRegion:Start()
	self.navMap = self:GetParent()
end

function NavRegion:SetIndex(index)
	self.index = index
end

function NavRegion:GetIndex()
    return self.index
end

function NavRegion:GetNeighbors()
	return self.neighbors
end

function NavRegion:BeginOverlap(thisNode, otherNode)
    if (otherNode:HasTag("Player")) then
        -- Log.Debug("Player region hit:")
        -- Log.Debug(self.index)
        -- Log.Debug("---")
        self.navMap:SetActiveIndex(self.index)
    end

    if (otherNode:HasTag("Enemy")) then
        -- Log.Debug("Enemy region hit")
        otherNode:SetNavRegionIndex(self.index)
    end

end

function NavRegion:EndOverlap(thisNode, otherNode)

    if (otherNode:HasTag("Player")) then
        if (self.navMap:GetActiveIndex() == self.index) then
            self.navMap:RollbackActiveIndex()
        end
    end

end

function NavRegion:CalculatePath(initialIndex)

end