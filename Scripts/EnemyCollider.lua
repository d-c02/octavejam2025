EnemyCollider = {}

function EnemyCollider:Create()
	self.controller = nil
	self:AddTag("Enemy")
end

function EnemyCollider:Start()
	--[[
	for i = 1, self:GetNumChildren() do
		Log.Debug(self:GetChild(i):GetName())
	end
	]]--
	--self.controller = self:FindChild("Controller", true)
	-- self.controller = self:GetChild(1)
	-- Log.Debug(tostring(self.controller))
end

function EnemyCollider:SetController(node)
	self.controller = node
end

function EnemyCollider:SetNavRegionIndex(index)
	Log.Debug("Active Region Index Set 1:")
    Log.Debug(index)
    Log.Debug("---------")
	self.controller:SetNavRegionIndex(index)
end