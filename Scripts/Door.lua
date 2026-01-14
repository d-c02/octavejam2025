Door = {}

function Door:Create()

    self.nextScene = Property.Create(DatumType.String, nil)
    self.interactHint = Property.Create(DatumType.String, "NEXT_ROOM")

end

function Door:Interact()

    if (self.nextScene) then
        Engine.GetWorld():LoadScene(self.nextScene)
    else
        Log.Warning("No next scene")
    end
end

function Door:GetInteractionHint()
    return self.interactHint
end