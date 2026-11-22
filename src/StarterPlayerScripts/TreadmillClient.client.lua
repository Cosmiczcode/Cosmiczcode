--[[
	TreadmillClient  (LocalScript -> StarterPlayer > StarterPlayerScripts)

	- Step onto an unlocked treadmill: you snap onto the belt, face the
	  console and auto-run with your run animation. Press Jump to hop off.
	- Signs above every treadmill show tier, Speed/s and unlock price.
	- The next locked treadmill has an "Unlock" prompt (E / tap).
	- "+X Speed" popups while training.
	- Animates every part tagged "TreadFx" (belts, UFOs, candy wheels,
	  lucky blocks, glowing trims, sell booth effects ...).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local TC = require(ReplicatedStorage:WaitForChild("TreadmillConfig"))
local Remotes = ReplicatedStorage:WaitForChild("TreadmillRemotes")

local FONT = Enum.Font.FredokaOne
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function myTier()
	return player:GetAttribute("TreadmillTier") or 1
end

---------------------------------------------------------------------
-- Toast message
---------------------------------------------------------------------
local toastGui = Instance.new("ScreenGui")
toastGui.Name = "TreadmillToast"
toastGui.ResetOnSpawn = false
toastGui.DisplayOrder = 20
toastGui.Parent = player:WaitForChild("PlayerGui")

local toast = Instance.new("TextLabel")
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.fromScale(0.5, 0.16)
toast.Size = UDim2.fromScale(0.6, 0.07)
toast.BackgroundTransparency = 1
toast.Font = FONT
toast.TextScaled = true
toast.TextColor3 = Color3.new(1, 1, 1)
toast.TextTransparency = 1
toast.Parent = toastGui
local toastStroke = Instance.new("UIStroke")
toastStroke.Thickness = 3
toastStroke.Transparency = 1
toastStroke.Parent = toast

local toastId = 0
local function showToast(msg, color)
	toastId += 1
	local id = toastId
	toast.Text = msg
	toast.TextColor3 = color or Color3.new(1, 1, 1)
	toast.TextTransparency = 0
	toastStroke.Transparency = 0
	task.delay(2, function()
		if id == toastId then
			TweenService:Create(toast, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			TweenService:Create(toastStroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end
	end)
end

---------------------------------------------------------------------
-- Signs + unlock prompts
---------------------------------------------------------------------
local signs = {} -- [model] = { Status, Prompt, Tier }

local function refreshSign(model)
	local info = signs[model]
	if not info then
		return
	end
	local tier = info.Tier
	local mine = myTier()
	if tier <= mine then
		info.Status.Text = "✅ UNLOCKED"
		info.Status.TextColor3 = rgb(120, 255, 90)
		info.Prompt.Enabled = false
	elseif tier == mine + 1 then
		info.Status.Text = "🔒 $" .. TC.Format(TC.Tiers[tier].Price)
		info.Status.TextColor3 = rgb(255, 220, 60)
		info.Prompt.Enabled = true
	else
		info.Status.Text = "🔒 LOCKED"
		info.Status.TextColor3 = rgb(255, 80, 90)
		info.Prompt.Enabled = false
	end
end

local function setupTreadmill(model)
	if signs[model] then
		return
	end
	local tier = model:GetAttribute("Tier") or 1
	local tierInfo = TC.Tiers[tier]
	local console = model:WaitForChild("Console", 5)
	local hitbox = model:WaitForChild("Hitbox", 5)
	if not tierInfo or not console or not hitbox then
		return
	end

	local bb = Instance.new("BillboardGui")
	bb.Name = "TierSign"
	bb.Adornee = console
	bb.Size = UDim2.fromScale(9, 3.6)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
	bb.MaxDistance = 140
	bb.LightInfluence = 0
	bb.Parent = model

	local function line(text, y, h, color)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0, y)
		l.Size = UDim2.fromScale(1, h)
		l.Font = FONT
		l.TextScaled = true
		l.Text = text
		l.TextColor3 = color
		local st = Instance.new("UIStroke")
		st.Thickness = 2.5
		st.Parent = l
		l.Parent = bb
		return l
	end
	local title = line("TIER " .. tier .. " • " .. string.upper(tierInfo.Name), 0, 0.38, Color3.new(1, 1, 1))
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, rgb(255, 230, 80)),
		ColorSequenceKeypoint.new(0.5, rgb(255, 120, 220)),
		ColorSequenceKeypoint.new(1, rgb(90, 220, 255)),
	})
	grad.Parent = title
	line("⚡ +" .. TC.Format(tierInfo.Gain) .. " Speed/s", 0.38, 0.3, rgb(110, 230, 255))
	local status = line("", 0.68, 0.32, Color3.new(1, 1, 1))

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Unlock for $" .. TC.Format(tierInfo.Price)
	prompt.ObjectText = tierInfo.Name .. " Treadmill"
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = hitbox
	prompt.Triggered:Connect(function()
		local ok, msg = Remotes.Unlock:InvokeServer(tier)
		if msg then
			showToast(msg, ok and rgb(120, 255, 90) or rgb(255, 90, 90))
		end
	end)

	signs[model] = { Status = status, Prompt = prompt, Tier = tier }
	refreshSign(model)
end

for _, m in ipairs(CollectionService:GetTagged("Treadmill")) do
	task.spawn(setupTreadmill, m)
end
CollectionService:GetInstanceAddedSignal("Treadmill"):Connect(setupTreadmill)
player:GetAttributeChangedSignal("TreadmillTier"):Connect(function()
	for m in pairs(signs) do
		refreshSign(m)
	end
end)

---------------------------------------------------------------------
-- Auto-run
---------------------------------------------------------------------
local running = nil -- { Model, Track, Conn }
local cooldownModel = nil
local lastLockedToast = 0

local function inside(hitbox, pos)
	local rel = hitbox.CFrame:PointToObjectSpace(pos)
	local half = hitbox.Size / 2
	return math.abs(rel.X) <= half.X and math.abs(rel.Z) <= half.Z and rel.Y >= -half.Y - 2 and rel.Y <= half.Y + 2
end

local function runAnimationId(character, humanoid)
	local animate = character:FindFirstChild("Animate")
	local run = animate and animate:FindFirstChild("run")
	local anim = run and run:FindFirstChildOfClass("Animation")
	if anim and anim.AnimationId ~= "" then
		return anim.AnimationId
	end
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		return "rbxassetid://180426354"
	end
	return "rbxassetid://913376220"
end

local function stopRunning(launch)
	if not running then
		return
	end
	local r = running
	running = nil
	cooldownModel = r.Model
	r.Conn:Disconnect()
	if r.Track then
		r.Track:Stop(0.2)
	end
	Remotes.SetRunning:FireServer(nil)

	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if hum then
		hum.AutoRotate = true
	end
	if launch and root and hum and r.Belt.Parent then
		-- hop off the back of the treadmill
		local back = r.Belt.CFrame * CFrame.new(0, 0, r.Belt.Size.Z / 2 + 2.5)
		root.CFrame = CFrame.lookAt(Vector3.new(back.X, root.Position.Y + 1, back.Z),
			Vector3.new(back.X, root.Position.Y + 1, back.Z) + r.Belt.CFrame.LookVector)
		root.AssemblyLinearVelocity = -r.Belt.CFrame.LookVector * 22 + Vector3.new(0, 38, 0)
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end

local function startRunning(model)
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local belt = model:FindFirstChild("Belt")
	if not hum or not root or not belt or hum.Health <= 0 then
		return
	end

	local tier = model:GetAttribute("Tier") or 1
	if tier > myTier() then
		cooldownModel = model
		if os.clock() - lastLockedToast > 2 then
			lastLockedToast = os.clock()
			local nextTier = myTier() + 1
			if tier == nextTier then
				showToast("🔒 Unlock " .. TC.Tiers[tier].Name .. " for $" .. TC.Format(TC.Tiers[tier].Price),
					rgb(255, 220, 60))
			else
				showToast("🔒 Unlock Tier " .. nextTier .. " first!", rgb(255, 90, 90))
			end
		end
		return
	end

	local top = belt.Position.Y + belt.Size.Y / 2
	local height = hum.RigType == Enum.HumanoidRigType.R6 and 3 or (hum.HipHeight + root.Size.Y / 2)
	local spot = (belt.CFrame * CFrame.new(0, 0, 1.2)).Position
	local pos = Vector3.new(spot.X, top + height, spot.Z)
	local target = CFrame.lookAt(pos, pos + belt.CFrame.LookVector)

	hum.AutoRotate = false
	local track
	local animator = hum:FindFirstChildOfClass("Animator")
	if animator then
		local anim = Instance.new("Animation")
		anim.AnimationId = runAnimationId(character, hum)
		local ok, t = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if ok and t then
			track = t
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = true
			track:Play(0.2)
			track:AdjustSpeed(1.1 + tier * 0.07)
		end
	end

	local conn = RunService.PreSimulation:Connect(function()
		if root.Parent then
			root.CFrame = target
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end)
	running = { Model = model, Belt = belt, Track = track, Conn = conn }
	Remotes.SetRunning:FireServer(model)
	showToast("🏃 Press JUMP to get off", rgb(110, 230, 255))
end

UserInputService.JumpRequest:Connect(function()
	if running then
		stopRunning(true)
	end
end)

player.CharacterAdded:Connect(function(character)
	if running then
		running.Conn:Disconnect()
		running = nil
	end
	cooldownModel = nil
	local hum = character:WaitForChild("Humanoid")
	hum.Died:Connect(function()
		stopRunning(false)
	end)
end)

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.1 then
		return
	end
	acc = 0
	if running then
		if not running.Model.Parent then
			stopRunning(false)
		end
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	for _, model in ipairs(CollectionService:GetTagged("Treadmill")) do
		local hitbox = model:FindFirstChild("Hitbox")
		if hitbox then
			local isIn = inside(hitbox, root.Position)
			if isIn and cooldownModel ~= model then
				startRunning(model)
				break
			elseif not isIn and cooldownModel == model then
				cooldownModel = nil
			end
		end
	end
end)

---------------------------------------------------------------------
-- "+X Speed" popups
---------------------------------------------------------------------
Remotes.Trained.OnClientEvent:Connect(function(gain)
	local head = player.Character and player.Character:FindFirstChild("Head")
	if not head then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Adornee = head
	bb.Size = UDim2.fromScale(5, 1.4)
	bb.StudsOffset = Vector3.new(math.random(-15, 15) / 10, 2.5, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = FONT
	l.TextScaled = true
	l.Text = "+" .. TC.Format(gain) .. " ⚡"
	l.TextColor3 = rgb(110, 230, 255)
	local st = Instance.new("UIStroke")
	st.Thickness = 2.5
	st.Parent = l
	l.Parent = bb
	bb.Parent = head
	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(bb, info, { StudsOffset = bb.StudsOffset + Vector3.new(0, 2.5, 0) }):Play()
	TweenService:Create(l, info, { TextTransparency = 1 }):Play()
	TweenService:Create(st, info, { Transparency = 1 }):Play()
	task.delay(1, function()
		bb:Destroy()
	end)
end)

---------------------------------------------------------------------
-- Effect animator (client-side only, so it's smooth and costs no network)
---------------------------------------------------------------------
local fxParts = {} -- [part] = { Base = CFrame, Transparency = n }

local function addFx(part)
	if part:IsA("BasePart") and not fxParts[part] then
		fxParts[part] = { Base = part.CFrame, Transparency = part.Transparency }
	end
end
for _, p in ipairs(CollectionService:GetTagged("TreadFx")) do
	addFx(p)
end
CollectionService:GetInstanceAddedSignal("TreadFx"):Connect(addFx)
CollectionService:GetInstanceRemovedSignal("TreadFx"):Connect(function(p)
	fxParts[p] = nil
end)

local MAX_DIST = 220
RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	local t = os.clock()
	for part, data in pairs(fxParts) do
		if not part.Parent then
			fxParts[part] = nil
			continue
		end
		local base = data.Base
		if (base.Position - camPos).Magnitude > MAX_DIST then
			continue
		end
		local kind = part:GetAttribute("Fx")
		local speed = part:GetAttribute("FxSpeed") or 1
		local amp = part:GetAttribute("FxAmp") or 0.5
		local phase = part:GetAttribute("FxPhase") or 0
		local w = t * speed + phase
		if kind == "Spin" then
			part.CFrame = CFrame.new(base.Position) * CFrame.Angles(0, w, 0) * (base - base.Position)
		elseif kind == "Bob" then
			part.CFrame = base + Vector3.new(0, math.sin(w) * amp, 0)
		elseif kind == "Float" then
			part.CFrame = CFrame.new(base.Position + Vector3.new(0, math.sin(w) * amp, 0))
				* CFrame.Angles(0, t * speed * 0.8, 0) * (base - base.Position)
		elseif kind == "Roll" then
			part.CFrame = base * CFrame.Angles(t * speed, 0, 0)
		elseif kind == "Sway" then
			part.CFrame = base * CFrame.Angles(math.sin(w) * amp * 0.5, 0, math.cos(w * 0.8) * amp)
		elseif kind == "Pulse" then
			part.Transparency = math.clamp(data.Transparency + (0.5 - 0.5 * math.sin(w)) * amp, 0, 1)
		elseif kind == "Belt" then
			-- slats slide toward the back and wrap around (amp = spacing)
			part.CFrame = base * CFrame.new(0, 0, (t * speed) % amp)
		elseif kind == "Orbit" then
			local center = part:GetAttribute("FxCenter")
			if center then
				part.CFrame = CFrame.new(center) * CFrame.Angles(0, t * speed, 0) * (CFrame.new(-center) * base)
			end
		end
	end
end)
