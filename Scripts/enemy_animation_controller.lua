-- this is just the function for the animation controller. paste in enemy file.
-- need to init an animation controller object in the character instance variables and call ctrl:on_state_changed() and ctrl:update() where appropriate in Tick()
    -- ctrl:on_state_changed() only called when enemy.current_state changes (so need to track prev_state) too. see character controller for example
    -- ctrl:update() needs to execute every loop in Tick(). make sure to pass a flag to tell controller when the enemy is moving

function create_animation_state()

    --------------------------------------------
    -- ANIMATION CONTROLLER FOR SOLDIER ENEMY --
    --------------------------------------------

    -- REQUIRED BEHAVIORAL STATES TO INTERFACE (NAME SPECIFIC):
    -- BASE STATES:
      -- IDLE
      -- ALERT

    -- SPECIAL STATES:
      -- ATTACK
      -- HURT
      -- DEAD

    -- REQUIRED FLAGS TO INTERFACE (NOT NAME SPECIFIC):
        -- ai.wants_to_move (boolean. flips true when ai is moving, flips false when ai is still. needed for wander behavior animation timing.)
    --------------------------------------------

    -- REQUIRED ANIMATION NAMES TO PLAY:

    -- BASE STATES:
        -- "idle", "idle_to_march", "march", "march_to_idle"
        -- "idle_to_stalk", "march_to_stalk", "stalk", "stalk_to_idle"

    -- SPECIAL STATES:
        -- "swing"
        -- "enemy_hurt"
        -- "enemy_dying"
        -- "enemy_dead"


    local ctrl = {}

    -- unused rn, is more so used as a sanity check for others to know what behavioral states we check for here
    ctrl.valid_states = {
        IDLE = true,
        ALERT = true,
        ATTACK = true,
        HURT = true,
        DEAD = true
    }

    ctrl.current_state = nil -- tracks current behavioral state
    
    ctrl.march_phase = "idle" --"idle", "start", "marching", "stop"
    ctrl.alert_phase = nil -- nil, "alerted", "hunting", "deaggro"

    ctrl.wants_to_move = false -- for tracking movement edges in IDLE


    function ctrl:on_state_changed(new_state, mesh)

        -- set the "current state" to the new state (assumes an actual change happened)
        -- trigger the correct animation sequence based on given edge trigger

        if new_state == "IDLE" then
            self:goto_idle(true, false, false, mesh)
            --Log.Console("goto_idle!", Vec(255,255,0,255))

        elseif new_state == "ALERT" then
            self:goto_alert(mesh)
            --Log.Console("goto_alert!", Vec(0,255,255,255))

        elseif new_state == "ATTACK" then
            self:do_attack(mesh)

        elseif new_state == "HURT" then
            self:do_hurt(mesh)

        elseif new_state == "DEAD" then
            self:goto_dead(mesh)

        else
            error("ctrl:on_state_changed received an invalid state! :" .. tostring(new_state), 2)

        end

        self.current_state = new_state

    end

    function ctrl:update(wanting_to_move, mesh) -- polling... (this is where looping animations are triggered)

        -- polling needs to be the thing that ADVANCES phase when animations are finished, not just tracking them. go figure!

        -- NO QUEUE. WE MUST TRACK OUR OWN TIMING LIKE FOOLS. TRANSITION LOGIC BELOW:
            -- basically, if we're in a specific transition phase but its animation is not playing... 
            -- then it is finished and we must transition to its following looping phase

            -- ...but also because this is an ai and walking isn't determined by controllers, we need to tell it to start/stop walking

        --
        
        -- wandering

        if current_state == "IDLE" then:
            if self.wants_to_move == false and wanting_to_move == true then
                self:goto_idle(false, true, mesh)

            else if self.wants_to_move == true and wanting_to_move == false then
                self:goto_idle(false, false, mesh)

            end
        end


        if self.march_phase == "start" and not mesh:IsAnimationPlaying("idle_to_march") then
            self.march_phase == "marching"
            mesh:PlayAnimation("march", 0, true, 1, 1)
        
        elseif self.march_phase == "stop" and not mesh:IsAnimationPlaying("march_to_idle") then
            self.march_phase == "idle"
            mesh:PlayAnimation("idle", 0, true, 1, 1)
        end


        -- alert

        if self.alert_phase == "start" then
            if not mesh:IsAnimationPlaying("idle_to_stalk") and not mesh:IsAnimationPlaying("march_to_stalk") then
                self.alert_phase == "stalking"
                mesh:PlayAnimation("stalk", 0, true, 1, 1)
            end
            
        elseif self.alert_phase = "stop" and not mesh:IsAnimationPlaying("stalk_to_idle") then
            self.alert_phase == nil
            mesh:PlayAnimation("idle", 0, true, 1, 1)
        end

        if self.current_state == "ATTACK" and not mesh:IsAnimationPlaying("swing") then
            mesh:PlayAnimation("stalk", 0, true, 1, 1)
        end

        if self.current_state == "HURT" and not mesh:IsAnimationPlaying("enemy_hurt") then
            mesh:PlayAnimation("stalk", 0, true, 1, 1)
        end

        -- kill me (literally though. dying)

        if self.current_state == "DEAD" and not mesh:IsAnimationPlaying("enemy_dying") then
            mesh:PlayAnimation("enemy_dead", 1, true, 1, 1)

    end

    -- this is where overall animation SEQUENCES are triggered (aka one shot animations)

    function ctrl:goto_alert(mesh)

        -- should not trigger unless we're currently in the IDLE state (which can be interrupted)
        if self.current_state ~= "IDLE" then
            return
        end

        self.alert_phase = "start"

        -- play the correct animation transition depending on whether we're walking or standing still
        if self.wants_to_move then
            mesh:PlayAnimation("march_to_stalk", 0, false, 1, 1)
        else
            mesh:PlayAnimation("idle_to_stalk", 0, false, 1, 1)

    end

    function ctrl:goto_idle(from_alert, wanting_to_move, mesh)

        -- should not trigger unless we're in self.alert_phase == "stop" or in the IDLE phase (also now handles internal stop/start logic)
        if self.alert_phase ~= "stop" and self.current_state ~= "IDLE" then
            return
        end

        if from_alert then
            self.alert_phase = "stop"
            mesh:PlayAnimation("stalk_to_idle", 0, false, 1, 1)
        else
            if wanting_to_move then
                self.march_phase = "start"
                mesh:PlayAnimation("idle_to_march", 0, false, 1, 1)
            else
                self.march_phase = "stop"
                mesh:PlayAnimation("march_to_idle", 0, false, 1, 1)
            end
        end

    end

    function ctrl:do_attack(mesh)
        mesh:PlayAnimation("swing", 1, false, 1, 1)

    end

    function ctrl:do_hurt(mesh)
        mesh:PlayAnimation("enemy_hurt", 1, false, 1, 1)
    
    end

    function ctrl:goto_dead(mesh)
        mesh:PlayAnimation("enemy_dying", 1, false, 1, 1)

    end

    return ctrl

end