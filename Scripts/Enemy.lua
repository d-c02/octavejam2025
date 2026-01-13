Enemy = {}
Enemy.kGroundingDot = 0.9


function Enemy:Create()
	self.navMap = nil
	self.health = 1
	self.pursuing = false
    self.detectionRadius = 5.0
    self.chaseRadius = 5.0
	self.collider = nil
    self.mesh = nil
    self.player = nil
    self.gravity = -9.8
    self.moveSpeed = 3.5
    self.moveAccel = 100.0
    self.moveDrag = 100.0
    self.extDrag = 20.0
    self.vertSlideLimit = 0.35
    self.activeRegionIndex = -1
    self.followPath = nil
    -- self.navRegionFeatherDist = 0.5
    self.navRegionFeatherDist = 5.0
    self.targetIndex = -1
    self.targetPos = Vec()

        -- State
    self.moveDir = Vec()
    self.rotationDir = 0.0
    self.ignoreGroundingTimer = 0.0
    self.timeSinceGrounded = 0.0
    self.grounded = false
    self.extVelocity = Vec()
    self.moveVelocity = Vec()
    self.meshYaw = 0.0
end

function Enemy:GatherProperties()
	return
    {
		{ name = "navMap", type = DatumType.Node},
        { name = "health", type = DatumType.Integer},
	}
end

function Enemy:Start()
    self.collider = self:GetParent()
    -- self.collider:AddTag("Enemy")
    self:AddTag("Enemy")
    
    -- self:AddTag("Enemy")

    self.mesh = self.collider:FindChild("Skeletal Mesh", true)

    self.player = self.collider:GetParent():FindChild("Character", true)
end


function Enemy:Tick(deltaTime)
    self:UpdateDrag(deltaTime)
    self:UpdateTargeting(deltaTime)
    self:UpdateMovement(deltaTime)
    self:UpdateGrounding(deltaTime)
    self:UpdateMesh(deltaTime)
end

function Enemy:UpdateTargeting(deltaTime)

    if self.pursuing then
        if self.collider:GetWorldPosition():Distance(self.player:GetWorldPosition()) < self.chaseRadius or self.activeRegionIndex == self.navMap:GetActiveIndex() then
            self.moveDir = self.player:GetWorldPosition() - self.collider:GetWorldPosition()
            self.moveDir.y = 0
            self.moveDir = self.moveDir:Normalize()

        else
            if (self.collider:GetWorldPosition():Distance(self.navMap:GetRegionPos(self.targetIndex)) <= self.navRegionFeatherDist) then
                self.activeRegionIndex = self.targetIndex
                self.targetIndex = table.remove(self.followPath, 1)
            end

            self.moveDir = self.navMap:GetRegionPos(self.targetIndex) - self.collider:GetWorldPosition()
            self.moveDir.y = 0
            self.moveDir = self.moveDir:Normalize()
        end
    else
        if self.collider:GetWorldPosition():Distance(self.player:GetWorldPosition()) < self.detectionRadius then
            self.pursuing = true
        end
    end
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

function Enemy:UpdateFollowPath(index)
    self.followPath = self.navMap:GetPathToPlayer(self.activeRegionIndex)
    self.targetIndex = table.remove(self.followPath, 1)
end

function Enemy:UpdateDrag(deltaTime)

    -- Update drag
    local function updateDrag(velocity, drag)
        local velXZ = Vec(velocity.x, 0, velocity.z)
        local speed = velXZ:Magnitude()
        local dir = speed > 0.0  and (velXZ / speed) or Vec()
        speed = math.max(speed - drag * deltaTime, 0)
        return dir * speed
    end

    if (self.grounded) then
        -- Only apply move drag when player is not moving
        if (self.moveDir == Vec(0,0,0)) then
            self.moveVelocity = updateDrag(self.moveVelocity, self.moveDrag)
        end
        self.extVelocity = updateDrag(self.extVelocity, self.extDrag)
    end

end

function Enemy:UpdateMovement(deltaTime)

    -- Apply gravity
    if (not self.grounded) then
        local gravity = self.gravity
        self.extVelocity.y = self.extVelocity.y + gravity * deltaTime
    end

    -- Add velocity based on player input vector
    local deltaMoveVel = self.moveDir * self.moveAccel * deltaTime
    
    -- refactor to target the character
    -- deltaMoveVel = Vector.Rotate(deltaMoveVel, self.tankRotation, Vec(0,1,0))

    self.moveVelocity = self.moveVelocity + deltaMoveVel

    if (self.moveVelocity:Magnitude() > self.moveSpeed) then
        self.moveVelocity = self.moveVelocity:Normalize() * self.moveSpeed
    end

    -- First apply motion based on internal move velocity
    self.moveVelocity = self:Move(self.moveVelocity, deltaTime, self.vertSlideLimit)

    -- Then apply motion based on external velocity (like gravity)
    self.extVelocity = self:Move(self.extVelocity, deltaTime, 0.0)

end

function Enemy:Move(velocity, deltaTime, vertSlideNormalLimit)

    local kMaxIterations = 3

    for i = 1, kMaxIterations do
        local startPos = self.collider:GetWorldPosition()
        local endPos = startPos + velocity * deltaTime
        local sweepRes = self.collider:SweepToWorldPosition(endPos)

        if (sweepRes.hitNode) then

            if (sweepRes.hitNormal.y > self.kGroundingDot) then
                self:SetGrounded(true)
            end

            local initialVelocityY = velocity.y

            velocity = velocity - (sweepRes.hitNormal * Vector.Dot(velocity, sweepRes.hitNormal))
            deltaTime = deltaTime * (1.0 - sweepRes.hitFraction)

            if (math.abs(sweepRes.hitNormal.y) < vertSlideNormalLimit) then
                velocity.y = initialVelocityY
            end
        else
            break
        end
    end

    return velocity

end

function Enemy:SetGrounded(grounded)

    -- Don't allow grounding if we are ignoring it temporarily (just began jumping)
    if (grounded and self.ignoreGroundingTimer > 0.0) then
        return
    end

    if (self.grounded ~= grounded) then
        self.grounded = grounded

        if (self.grounded) then
            self.extVelocity.y = 0.0
            self.timeSinceGrounded = 0.0
            self.isJumping = false
        end
    end
end

function Enemy:UpdateGrounding(deltaTime)

    self.ignoreGroundingTimer = math.max(self.ignoreGroundingTimer - deltaTime, 0.0)

    if (self.grounded) then
        -- Sweep to the ground.
        local startPos = self.collider:GetWorldPosition()
        local endPos = startPos + Vec(0, -0.1, 0)
        local sweepRes = self.collider:SweepToWorldPosition(endPos, 0, true)

        if (sweepRes.hitNode and sweepRes.hitNormal.y > self.kGroundingDot) then
            local pos = startPos + sweepRes.hitFraction * (endPos - startPos) + Vec(0, 0.00101, 0)
            self.collider:SetWorldPosition(pos)
            self:SetGrounded(true)
        else
            self.collider:SetWorldPosition(startPos)
            self:SetGrounded(false)
        end
    else
        self.timeSinceGrounded = self.timeSinceGrounded + deltaTime
    end
end

function Enemy:UpdateMesh(deltaTime)
    -- Update mesh orientation
    self.mesh:SetRotation(Vec(0, self.tankRotation, 0))
end

function Enemy:SetNavRegionIndex(index)
    self.activeRegionIndex = index
    Log.Debug("Active Region Index Set 2:")
    Log.Debug(self.activeRegionIndex)
    Log.Debug("---------")
end