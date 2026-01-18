NoteHook = {}

function NodeHook:Create()
	self.textCount = 0
	self.curText = 0
	self.scrollWidth = 640.0
	self.scrolling = false
end

function NoteHook:Start()

end


function NodeHook:QueueText(text)
	local child = CreateChildNode(Text)

	child:SetText(text)
	child:EnableWordWrap(true)
	child:SetHorizontalJustification(Justification.Center)
	child:SetVerticalJustification(Justification.Center)
	child:SetOffset(-100, -100)
	child:SetSize(200, 200)
end

function NoteHook:Clear()
	self:DestroyAllChildren()
	self.textCount = 0
	self.curText = 0
	self.scrolling = false
end