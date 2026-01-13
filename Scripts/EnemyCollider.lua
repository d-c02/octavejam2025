EnemyCollider = {}

function EnemyCollider:Create()
	self.controller = nil
end

function EnemyCollider:Start()
	self.controller = self:FindChild("Controller", true)
end

function EnemyCollider:SetNavRegionIndex(index)
	self.controller:SetNavRegionIndex(index)
end