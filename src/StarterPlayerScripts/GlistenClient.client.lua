--[[
	GlistenClient  (LocalScript -> StarterPlayer > StarterPlayerScripts)

	Every few seconds a quick diagonal shine sweeps across any GUI
	element tagged "Glisten" (shop cards, buy buttons, game pass buttons...).

	SimUIClient tags its monetization UI automatically. To add the effect
	to your own UI, tag the Frame / Button with "Glisten" in Studio
	(Properties > Tags, or the Tag Editor). Tags on UI in StarterGui carry
	over to the player's copy.
]]

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local MIN_WAIT, MAX_WAIT = 2.5, 5 -- seconds between sweeps
local SWEEP_TIME = 0.55

local SHINE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.4, 1),
	NumberSequenceKeypoint.new(0.47, 0.6),
	NumberSequenceKeypoint.new(0.5, 0.25),
	NumberSequenceKeypoint.new(0.53, 0.6),
	NumberSequenceKeypoint.new(0.6, 1),
	NumberSequenceKeypoint.new(1, 1),
})

local attached = {}

local function attach(obj)
	if attached[obj] or not obj:IsA("GuiObject") or not obj:FindFirstAncestorWhichIsA("PlayerGui") then
		return -- only the player's live copy, not the StarterGui template
	end
	attached[obj] = true

	local shine = Instance.new("Frame")
	shine.Name = "GlistenFx"
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BorderSizePixel = 0
	shine.Size = UDim2.fromScale(1, 1)
	shine.ZIndex = obj.ZIndex + 10
	shine.Active = false
	pcall(function()
		shine.Interactable = false -- never block clicks on the button
	end)
	local corner = obj:FindFirstChildOfClass("UICorner")
	if corner then
		corner:Clone().Parent = shine
	end
	local grad = Instance.new("UIGradient")
	grad.Transparency = SHINE
	grad.Rotation = 25
	grad.Offset = Vector2.new(-1, 0)
	grad.Parent = shine
	shine.Parent = obj

	task.spawn(function()
		task.wait(math.random() * MAX_WAIT) -- stagger so they don't all flash together
		while obj.Parent and shine.Parent do
			if obj.Visible and obj:IsDescendantOf(game) then
				grad.Offset = Vector2.new(-1, 0)
				TweenService:Create(grad, TweenInfo.new(SWEEP_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
					{ Offset = Vector2.new(1, 0) }):Play()
			end
			task.wait(MIN_WAIT + math.random() * (MAX_WAIT - MIN_WAIT))
		end
		attached[obj] = nil
	end)
end

for _, obj in ipairs(CollectionService:GetTagged("Glisten")) do
	attach(obj)
end
CollectionService:GetInstanceAddedSignal("Glisten"):Connect(attach)
