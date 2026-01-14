-- [Script hierarchy]
--   Root (Primitive3D)
--     Camera (Camera3D)
--     Controller (Node, with this script)
CharacterState = 
{
    idle = "IDLE",
    walkForward = "WALK_F",
    walkBackward = "WALK_B",
    cranking = "WIND"
}

CharacterController = {}

CharacterController.kGroundingDot = 0.9

function CharacterController:Create()

    -- Properties
    self.collider = nil
    self.camera = nil
    self.cameraPivot = nil
    self.mesh = nil
    self.rotationSpeed = 200.0
    self.cameraDistance = 10.0
    self.gravity = -9.8
    self.moveSpeed = 7.0
    self.lookSpeed = 200.0
    self.moveAccel = 100.0
    self.jumpSpeed = 7.0
    self.jumpGravScale = 0.5
    self.moveDrag = 100.0
    self.extDrag = 20.0
    self.airControl = 0.1
    self.vertSlideLimit = 0.35
    self.followCamHeight = 4.0
    self.enableControl = true
    self.enableJump = true
    self.enableFollowCam = false
    self.enableCameraTrace = true
    self.mouseSensitivity = 0.05

    -- Crankage
    self.enableCrankage = false
    self.decayTimer = 100
    self.decayAmount = 0.013
    self.decayCounter = 1
    self.crankage = 1
    self.powEaseValue = 8

    -- Animation State
    self.characterState = CharacterState.idle
    self.inAnim = false
    self.outAnim = false
    self.animation_controller = create_animation_state()

    -- Movement State
    self.moveDir = Vec()
    self.tankRotation = 0.0
    self.rotationDir = 0.0
    self.lookVec = Vec()
    self.jumpTimer = 0.0
    self.isJumping = false
    self.isJumpHeld = false
    self.ignoreGroundingTimer = 0.0
    self.timeSinceGrounded = 0.0
    self.grounded = false
    self.extVelocity = Vec()
    self.moveVelocity = Vec()
    self.meshYaw = 0.0
end

function CharacterController:GatherProperties()

    return
    {
        --{ name = "collider", type = DatumType.Node },
        --{ name = "camera", type = DatumType.Node },
        --{ name = "cameraPivot", type = DatumType.Node },
        --{ name = "mesh", type = DatumType.Node },
        { name = "cameraDistance", type = DatumType.Float },
        { name = "gravity", type = DatumType.Float },
        { name = "moveSpeed", type = DatumType.Float },
        { name = "lookSpeed", type = DatumType.Float },
        { name = "moveAccel", type = DatumType.Float },
        { name = "jumpSpeed", type = DatumType.Float },
        { name = "jumpGravScale", type = DatumType.Float },
        { name = "moveDrag", type = DatumType.Float },
        { name = "extDrag", type = DatumType.Float },
        { name = "airControl", type = DatumType.Float },
        { name = "vertSlideLimit", type = DatumType.Float },
        { name = "followCamHeight", type = DatumType.Float },
        { name = "enableControl", type = DatumType.Bool },
        { name = "enableJump", type = DatumType.Bool },
        { name = "enableFollowCam", type = DatumType.Bool },
        { name = "enableCameraTrace", type = DatumType.Bool },
        { name = "mouseSensitivity", type = DatumType.Float },
        { name = "enableCrankage", type = DatumType.Bool },
        { name = "decayTimer", type = DatumType.Float },
        { name = "decayAmount", type = DatumType.Float },
        { name = "powEaseValue", type = DatumType.Float},
    }

end

function CharacterController:Start()

    self:GetParent():SetPersistent(true)
    -- self:AddTag("Player")

    Input.LockCursor(true)
    Input.TrapCursor(true)
    Input.ShowCursor(false)

    self.collider = self:GetParent()
    self.collider:AddTag("Player")

    -- if (not self.cameraPivot) then
        -- self.cameraPivot = self.camera:GetParent()
    self.cameraPivot = self.collider:FindChild("CameraPivot", true)
    -- end

    -- if (not self.mesh) then
    self.mesh = self.collider:FindChild("Skeletal Mesh", true)
    -- end

    -- self.camera:Detach(true)

end

function CharacterController:Stop()

    Input.LockCursor(false)
    Input.TrapCursor(false)
    Input.ShowCursor(true)

end

function CharacterController:Tick(deltaTime)

    self:UpdateInput(deltaTime)
    self:UpdateJump(deltaTime)
    self:UpdateDrag(deltaTime)

    self:UpdateState(deltaTime)
    self.animation_controller:on_state_changed(self.characterState, self.mesh)
    self.animation_controller:update(self.mesh)
    self:UpdateMovement(deltaTime)
    self:UpdateCrankage(deltaTime)
    self:UpdateGrounding(deltaTime)
    --self:UpdateCamera(deltaTime)
    
end

function CharacterController:UpdateInput(deltaTime)

    if (self.enableControl) then

        -- moveDir
        self.moveDir = Vec()
        self.rotationDir = 0.0
        if (Input.IsKeyDown(Key.A)) then
            self.rotationDir = self.rotationDir + 1.0
        end

        if (Input.IsKeyDown(Key.D)) then
            self.rotationDir = self.rotationDir + -1.0
        end

        if (Input.IsKeyDown(Key.W)) then
            self.moveDir.z = self.moveDir.z + -1.0
        end

        if (Input.IsKeyDown(Key.S)) then
            self.moveDir.z = self.moveDir.z + 1.0
        end

        local leftAxisX = Input.GetGamepadAxis(Gamepad.AxisLX)
        local leftAxisY = Input.GetGamepadAxis(Gamepad.AxisLY)

        -- Only add analog stick input beyond a deadzone limit
        if (math.abs(leftAxisX) > 0.1) then
            self.rotationDir = self.rotationDir + leftAxisX
        end

        if (math.abs(leftAxisY) > 0.1) then
            self.moveDir.z = self.moveDir.z + leftAxisY
        end

        -- Ensure length of moveDir is at most 1.0.
        local moveMag = self.moveDir:Magnitude()
        moveMag = math.min(moveMag, 1.0)
        self.moveDir = self.moveDir:Normalize()
        self.moveDir = self.moveDir * moveMag

        -- lookDelta
        self.lookVec.x, self.lookVec.y = Input.GetMouseDelta()
        self.lookVec = self.lookVec * self.mouseSensitivity

        local gamepadLook = Vec()
        local rightAxisX = Input.GetGamepadAxis(Gamepad.AxisRX)
        local rightAxisY = Input.GetGamepadAxis(Gamepad.AxisRY)
        local rightAxisDeadZone = 0.1

        if (math.abs(rightAxisX) > rightAxisDeadZone) then
            gamepadLook.x = rightAxisX
        end

        if (math.abs(rightAxisY) > 0.1) then
            gamepadLook.y = -rightAxisY
        end

        self.lookVec = self.lookVec + gamepadLook

    else
        self.moveDir = Vec()
        self.lookDelta = Vec()
    end
        
end

function CharacterController:UpdateJump(deltaTime)

    local jumpPressed = Input.IsKeyPressed(Key.Space) or Input.IsGamepadPressed(Gamepad.A)

    if (self.isJumpHeld) then
        self.isJumpHeld = Input.IsKeyDown(Key.Space) or Input.IsGamepadDown(Gamepad.A)
    end

    self.jumpTimer = math.max(self.jumpTimer - deltaTime, 0.0)

    if (jumpPressed) then
        self.jumpTimer = 0.2
    end

    if (self.grounded and self.jumpTimer > 0.0) then
        self:Jump()
    end

end

function CharacterController:UpdateDrag(deltaTime)

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

function CharacterController:UpdateMovement(deltaTime)

    local crankMod = 1

    -- Apply gravity
    if (not self.grounded) then
        local gravity = self.gravity
        if (self.isJumping and self.isJumpHeld) then
            gravity = gravity * self.jumpGravScale
        end
        self.extVelocity.y = self.extVelocity.y + gravity * deltaTime
    end
    
    -- Get crankage modifier
    if (self.enableCrankage) then
        crankMod = 1 - (1-self.crankage)^self.powEaseValue
    else
        crankMod = 1
    end

    --Rotate
    self.tankRotation = self.tankRotation + ((self.rotationSpeed * crankMod) * self.rotationDir * deltaTime)
    
    if self.tankRotation < 0 then
        self.tankRotation = self.tankRotation + 360
    end

    if self.tankRotation >= 360 then
        self.tankRotation = self.tankRotation - 360
    end

    -- Add velocity based on player input vector
    local deltaMoveVel = self.moveDir * self.moveAccel * deltaTime
    -- local yaw = self:GetCameraYaw()
    deltaMoveVel = Vector.Rotate(deltaMoveVel, self.tankRotation, Vec(0,1,0))

    -- Reduce move velocity when in air -- THIS POOPENFARTEN WE NOT NEED
    if (not self.grounded) then
        deltaMoveVel = deltaMoveVel * self.airControl
    end

    self.moveVelocity = self.moveVelocity + deltaMoveVel

    if (self.moveVelocity:Magnitude() > self.moveSpeed) then
        self.moveVelocity = self.moveVelocity:Normalize() * self.moveSpeed
    end

    -- Reduce velocity based on crankage O_o
    if (self.enableCrankage) then
        self.moveVelocity = self.moveVelocity * crankMod
    end

    -- First apply motion based on internal move velocity
    self.moveVelocity = self:Move(self.moveVelocity, deltaTime, self.vertSlideLimit)

    -- Then apply motion based on external velocity (like gravity)
    self.extVelocity = self:Move(self.extVelocity, deltaTime, 0.0)

    -- Update mesh orientation (roation)
    self.mesh:SetRotation(Vec(0, self.tankRotation, 0))

end

function CharacterController:UpdateGrounding(deltaTime)

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


--[[
function CharacterController:UpdateCamera(deltaTime)

    local kFollowMinDistXZ = 4.0

    if (self.enableFollowCam) then

        -- Ensure proper attachment in case follow cam is toggled
        self.camera:Attach(self.world:GetRootNode())

        local colliderPos = self.collider:GetWorldPosition()

        if (Input.IsKeyPressed(Key.Q) or Input.IsGamepadPressed(Gamepad.L1)) then
            -- Move camera behind player
            self.camera:SetWorldPosition(colliderPos - self.mesh:GetForwardVector() * self.cameraDistance)
        end

        local deltaPos = self.camera:GetWorldPosition() - colliderPos
        local deltaPosXZ = Vec(deltaPos.x, 0, deltaPos.z)

        deltaPosXZ.y = 0.0

        local dist = deltaPosXZ:Magnitude()

        if (dist > self.cameraDistance) then
            deltaPosXZ = deltaPosXZ:Normalize() * self.cameraDistance
        elseif (dist < kFollowMinDistXZ) then
            deltaPosXZ = deltaPosXZ:Normalize() * kFollowMinDistXZ
        end

        deltaPos = Vec(deltaPosXZ.x, self.followCamHeight, deltaPosXZ.z)

        local worldPos = colliderPos + deltaPos
        self.camera:SetWorldPosition(worldPos)
        self.camera:LookAt(colliderPos)
    else

        -- Ensure proper attachment in case follow cam is toggled
        self.camera:Attach(self.cameraPivot)
        self.camera:SetRotation(Vec(0,0,0))

        local lookRot = self.lookVec * self.lookSpeed

        -- Adjust rotation of camera pivot based on player input
        local camPivotRot = self.cameraPivot:GetRotation()
        camPivotRot.y = camPivotRot.y - lookRot.x * deltaTime
        camPivotRot.x = camPivotRot.x - lookRot.y * deltaTime
        camPivotRot.x = Math.Clamp(camPivotRot.x, -89.9, 89.9)
        self.cameraPivot:SetRotation(camPivotRot)

        -- Adjust camera distance
        self.camera:SetPosition(Vec(0, 0, self.cameraDistance))
    end

    -- Do camera collision tracing
    if (self.enableCameraTrace) then
        local rayStart = self.collider:GetWorldPosition()
        local rayEnd = self.camera:GetWorldPosition()
        local colMask = 0x02 -- Default collision group for environment
        local res = self.world:RayTest(rayStart, rayEnd, colMask)

        if (res.hitNode) then
            -- The trace hit something, so place the camera at the hit location
            local pos = Vector.Lerp(rayStart, rayEnd, res.hitFraction)
            self.camera:SetWorldPosition(pos)
        end
    end
end
]]--


function CharacterController:UpdateState(deltaTime)

    if (self:UpdateCrankage(deltaTime)) then
        
        self.characterState = CharacterState.cranking
        
    elseif (self.moveVelocity:Length2() > 1.0) then

    -- Log.Console(tostring(self.moveDir), Vec(255,255,255,255))

        if (self.moveDir.z < 0) then

            self.characterState = CharacterState.walkForward

        elseif (self.moveDir.z > 0) then

            self.characterState = CharacterState.walkBackward

        else

            -- Log.Console("Ugh not good!", Vec(255,255,255,255))
            self.characterState = CharacterState.idle

        end

    else

        self.characterState = CharacterState.idle

    end
    Log.Console(tostring(self.characterState), Vec(255,255,255,255))

end

function CharacterController:UpdateCrankage(deltaTime)

    -- Refill crankage
    if (Input.IsKeyPressed(Key.R)) then
        self.crankage = Math.Clamp(self.crankage + (self.decayAmount * 2), 0, 1)
        -- do some kind of pause/winding animation        
        return true

    end

    if (self.decayCounter >= self.decayTimer) then

        self.crankage = math.max((self.crankage - self.decayAmount), 0)
        -- Log.Console('Reducing crank -- new crank: ' .. tostring(self.crankage), Vec(255,255,255,255))
        self.decayCounter = 1

    end

    -- Log.Console('Decay counter: ' .. tostring(self.decayCounter), Vec(255,255,0,255))
    self.decayCounter = self.decayCounter + 1
    
    return false

end

function CharacterController:UpdateMesh(deltaTime)

end

function CharacterController:Move(velocity, deltaTime, vertSlideNormalLimit)

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

function CharacterController:Jump()

    if (self.enableJump and self.grounded) then
        self.isJumping = true
        self.isJumpHeld = true
        self.extVelocity.y = self.jumpSpeed
        self:SetGrounded(false)
        self.ignoreGroundingTimer = 0.2

        self.mesh:StopAnimation("Fall")
        self.mesh:PlayAnimation("Jump", 1, false)
        self.mesh:QueueAnimation("Fall", "Jump", 0, true, 1, 1)
    end

end


function CharacterController:SetGrounded(grounded)

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

--[[
function CharacterController:GetCameraYaw()
    return self.enableFollowCam and
        self.camera:GetRotation().y or
        self.cameraPivot:GetRotation().y
end
]]--

function create_animation_state()

    local ctrl = {}

    --unused rn, is more so used as a sanity check for others
    ctrl.valid_states = {
        IDLE = true, 
        WALK_F = true, 
        WALK_B = true, 
        WIND = true 
    }

    ctrl.current_state = nil
    ctrl.locomotion_phase = "idle" --"idle", "start", "walking", "stop"
    ctrl.winding_phase = nil -- "start", "winding", "stop"

    ctrl.is_winding_finished = false -- returns true when the wind_to_idle transition finishes (can use for changing char state. do NOT use button release or it will cut off animation)


    function ctrl:on_state_changed(new_state, mesh)

        -- set the "current state" to the new state
        -- trigger the correct animation sequence

        if new_state ~= self.current_state then

            if new_state == "IDLE" then
                self:goto_idle(new_state, mesh)

            elseif new_state == "WALK_F" then
                self:goto_walk(0, mesh)

            elseif new_state == "WALK_B" then
                self:goto_walk(1, mesh)

            elseif new_state == "WIND" then
                self:goto_wind(mesh)

            else
                error("ctrl:on_state_changed received an invalid state! :" .. tostring(new_state), 2)

            end

            self.current_state = new_state

        end
    end

    function ctrl:update(mesh) -- polling... (i give you hooks, you use them!)

        local previous_winding_phase = self.winding_phase

        -- yeah, yeah, there's duplicates. we'll deal with it for now and reduce redundant stuff
        if mesh:IsAnimationPlaying("walk_f") or mesh:IsAnimationPlaying("walk_b") then
            self.locomotion_phase = "walking"

        elseif mesh:IsAnimationPlaying("idle_to_walk_f") or mesh:IsAnimationPlaying("idle_to_walk_b") then
            self.locomotion_phase = "start"

        elseif mesh:IsAnimationPlaying("walk_f_to_idle") or mesh:IsAnimationPlaying("walk_b_to_idle") then
            self.locomotion_phase = "stop"

        else
            self.locomotion_phase = "idle"
        end


        if mesh:IsAnimationPlaying("wind") then
            self.winding_phase = "winding"
        
        elseif mesh:IsAnimationPlaying("idle_to_wind") then
            self.winding_phase = "start"

        elseif mesh:IsAnimationPlaying("wind_to_idle") then
            self.winding_phase = "stop"

        else
            self.winding_phase = nil

        end

        -- TODO log phase updates to console (debug)

        -- what we definitely do need is to know when wind_to_idle has finished, to trigger the state change out of WIND.
        -- WIND determines not just animations, but also behavior (locomotion disabled). so it's important to get the timing right

        -- i would surmise that this is also where we can create other bools if we need to do more checks on animation transitions/finish rather than state

        if previous_winding_phase == "stop" and self.winding_phase == nil then
            self.is_winding_finished = true
        else
            self.is_winding_finished = false
        end

    end


    -- this is where the actual animation triggering/queue logic happens

    function ctrl:goto_walk(is_backward, mesh)

        -- should not trigger unless we're currently playing the idle animation (this can be interrupted)
        -- use this gate for movement too? :P
        if self.locomotion_phase ~= "idle" then
            return
        end

        self.locomotion_phase = "start"

        local walk_anim = "walk_f"
        local start_transition_anim = "idle_to_walk_f"

        if is_backward then
            walk_anim = "walk_b"
            start_transition_anim = "idle_to_walk_b"

        end

        mesh:PlayAnimation(start_transition_anim, 0, false, 1, 1)
        mesh:QueueAnimation(walk_anim, start_transition_anim, 0, true, 1, 1)

    end

    function ctrl:goto_idle(previous_state, mesh)

        -- should not trigger unless we're in a "walking"/"winding" phase
        if previous_state == "WALK_F" or previous_state == "WALK_B" then
            if self.locomotion_phase ~= "walking" then
                return
            end

            self.locomotion_phase = "stop"

        elseif previous_state == "WIND" then
            if self.winding_phase ~= "winding" then
                return
            end

            self.winding_phase = stop
        end


        if previous_state == "WALK_F" then
            mesh:QueueAnimation("walk_f_to_idle", "walk_f", 0, false, 1, 1)

        elseif previous_state == "WALK_B" then
            mesh:QueueAnimation("walk_b_to_idle", "walk_b", 0, false, 1, 1)

        elseif previous_state == "WIND" then
            mesh:QueueAnimation("wind_to_idle", "wind", 1, false, 1, 1)
    
        end

        mesh:QueueAnimation("idle", nil, 0, true, 1, 1)

    end

    function ctrl:goto_wind(mesh)

        -- wind can interrupt idle, but should not interrupt walking, and should not interrupt itself
        if self.locomotion_phase ~= "idle" or self.winding_phase ~= nil then
            return
        end
        self.winding_phase = "start"

        mesh:PlayAnimation("idle_to_wind", 1, false, 1, 1)
        mesh:QueueAnimation("wind", nil, 1, true, 1, 1)

    end

    return ctrl

end