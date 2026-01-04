CameraZone = {}

function CameraZone:Create()
	-- Properties
    self.camera = nil
end

function CameraZone:Start()
    self.camera = self:FindChild("Camera", true)
end

function CameraZone:BeginOverlap(thisNode, otherNode)

    if (otherNode:HasTag("Player")) then
        Engine.GetWorld():SetActiveCamera(self.camera)
    end

end