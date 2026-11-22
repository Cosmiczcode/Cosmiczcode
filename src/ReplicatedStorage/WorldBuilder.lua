--[[
	WorldBuilder  (ModuleScript -> ReplicatedStorage)

	Run ONCE in Studio's Command Bar (edit mode, not while playing):

		require(game.ReplicatedStorage.WorldBuilder).Install()

	It builds / changes:
	  1. Workspace.TreadmillGym  - a neon two-tier gym with all 12 tier
	     treadmills, stairs, an arch sign and a glowing back wall.
	     It's one Model: drag it anywhere you like afterwards.
	  2. Sell booth glow-up     - every Model/Part with "sell" in its name
	     gets a pulsing neon ring, orbiting lights, a floating spinning
	     cash stack, money sparkles and a bouncing "SELL" sign
	     (added next to it in Workspace.SellBoothFx, your booth isn't touched).
	  3. Lighting               - bloom, atmosphere, colour boost, sun rays.

	Each part can be re-run on its own:
	  .BuildGym(cframe?)  .DecorateSellBooths()  .Lighting()
	Run .Install() again any time; it replaces what it made before.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Skins = require(ReplicatedStorage:WaitForChild("TreadmillSkins"))
local TC = require(ReplicatedStorage:WaitForChild("TreadmillConfig"))
local fx = Skins.fx

local WB = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local rgb = Color3.fromRGB
local M = Enum.Material

local NAVY = rgb(38, 42, 98)
local NAVY_DARK = rgb(26, 28, 70)
local PINK = rgb(255, 70, 220)
local CYAN = rgb(60, 230, 255)
local YELLOW = rgb(255, 215, 50)

local function P(parent, name, size, cframe, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in pairs(props) do
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function sign(part, face, text, gradient, ppm)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = ppm or 40
	g.LightInfluence = 0
	g.Brightness = 2
	g.Parent = part
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Parent = g
	local st = Instance.new("UIStroke")
	st.Thickness = 6
	st.Color = rgb(20, 10, 40)
	st.Parent = t
	if gradient then
		local gr = Instance.new("UIGradient")
		gr.Color = gradient
		gr.Parent = t
	end
	return g
end

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, rgb(255, 230, 60)),
	ColorSequenceKeypoint.new(0.35, rgb(255, 90, 200)),
	ColorSequenceKeypoint.new(0.7, rgb(120, 110, 255)),
	ColorSequenceKeypoint.new(1, rgb(60, 230, 255)),
})

local function light(part, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = part
end

local function defaultOrigin()
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawn then
		local ground = spawn.Position.Y - spawn.Size.Y / 2
		return CF(spawn.Position.X, ground, spawn.Position.Z - 80)
	end
	return CF(0, 0, -80)
end

---------------------------------------------------------------------
-- 1. Treadmill gym
---------------------------------------------------------------------
function WB.BuildGym(origin)
	origin = origin or defaultOrigin()
	local old = workspace:FindFirstChild("TreadmillGym")
	if old then
		origin = old:GetPivot() -- keep it where you moved it
		old:Destroy()
	end

	local gym = Instance.new("Model")
	gym.Name = "TreadmillGym"

	local spacing = 14
	local width = spacing * 6 + 26
	local backTop = 6.4

	-- floors
	P(gym, "Floor", V(width, 0.8, 18), CF(0, 0, 0), NAVY, M.SmoothPlastic)
	P(gym, "BackStage", V(width, backTop, 16), CF(0, backTop / 2, -17), NAVY_DARK, M.SmoothPlastic)
	-- checker glow tiles on the floor
	for i = 0, 5 do
		local x = -spacing * 2.5 + i * spacing
		fx(P(gym, "Pad", V(8, 0.1, 13), CF(x, 0.45, 0.3), i % 2 == 0 and PINK or CYAN, M.Neon, { CanCollide = false,
			Transparency = 0.55 }), "Pulse", 2, 0.35, i)
		fx(P(gym, "Pad", V(8, 0.1, 13), CF(x, backTop + 0.05, -16.7), i % 2 == 0 and CYAN or PINK, M.Neon, {
			CanCollide = false, Transparency = 0.55 }), "Pulse", 2, 0.35, i + 3)
	end
	-- neon edges
	fx(P(gym, "EdgeFront", V(width, 0.3, 0.3), CF(0, 0.45, 9), CYAN, M.Neon, { CanCollide = false }), "Pulse", 3, 0.5)
	fx(P(gym, "EdgeBack", V(width, 0.3, 0.3), CF(0, backTop + 0.1, -9), PINK, M.Neon, { CanCollide = false }), "Pulse",
		3, 0.5, 1.5)
	for i = 0, 3 do
		fx(P(gym, "StageStripe", V(width, 0.2, 0.2), CF(0, 1.2 + i * 1.4, -8.95), i % 2 == 0 and PINK or CYAN, M.Neon,
			{ CanCollide = false }), "Pulse", 2, 0.6, i)
	end

	-- stairs to the back row on both ends
	for _, sx in ipairs({ -1, 1 }) do
		local x = sx * (width / 2 - 5)
		for k = 1, 6 do
			local h = k * (backTop - 0.4) / 6
			P(gym, "Step", V(8, h, 1.4), CF(x, 0.4 + h / 2, -9 + (6.5 - k) * 1.4), NAVY)
			fx(P(gym, "StepGlow", V(8, 0.12, 0.15), CF(x, 0.4 + h + 0.06, -9 + (6.5 - k) * 1.4 + 0.7), CYAN, M.Neon,
				{ CanCollide = false }), "Pulse", 4, 0.6, k * 0.5)
		end
	end

	-- back wall with title
	local wall = P(gym, "BackWall", V(width, 18, 1), CF(0, backTop + 9, -25.5), NAVY_DARK)
	sign(P(gym, "TitlePanel", V(60, 9, 0.2), CF(0, backTop + 11, -24.9), NAVY_DARK, M.SmoothPlastic,
		{ CanCollide = false }), Enum.NormalId.Front, "⚡ TREADMILLS ⚡", RAINBOW, 20)
	for i = 0, 2 do
		fx(P(gym, "WallStripe", V(width, 0.3, 0.3), CF(0, backTop + 2 + i * 6, -24.95), ({ PINK, CYAN, YELLOW })[i + 1],
			M.Neon, { CanCollide = false }), "Pulse", 2.5, 0.5, i)
	end
	light(wall, PINK, 40, 1.5)

	-- entrance arch
	local archZ = 13
	for _, sx in ipairs({ -1, 1 }) do
		local x = sx * 22
		P(gym, "Pillar", V(3, 20, 3), CF(x, 10, archZ), NAVY)
		for k = 0, 3 do
			fx(P(gym, "PillarRing", V(3.6, 0.5, 3.6), CF(x, 3 + k * 4.5, archZ), k % 2 == 0 and PINK or CYAN, M.Neon,
				{ CanCollide = false }), "Bob", 2, 0.6, k + sx)
		end
		local orb = P(gym, "Orb", V(3.4, 3.4, 3.4), CF(x, 22, archZ), YELLOW, M.Neon,
			{ Shape = Enum.PartType.Ball, CanCollide = false })
		fx(orb, "Bob", 2, 0.8, sx)
		light(orb, YELLOW, 30, 2)
	end
	local beam = P(gym, "ArchSign", V(47, 6, 1.5), CF(0, 21, archZ), NAVY_DARK)
	sign(beam, Enum.NormalId.Back, "TREADMILL GYM", RAINBOW, 30)
	sign(beam, Enum.NormalId.Front, "TREADMILL GYM", RAINBOW, 30)
	fx(P(gym, "ArchTrim", V(47.4, 0.4, 1.9), CF(0, 18, archZ), PINK, M.Neon, { CanCollide = false }), "Pulse", 3, 0.5)
	fx(P(gym, "ArchTrim", V(47.4, 0.4, 1.9), CF(0, 24, archZ), CYAN, M.Neon, { CanCollide = false }), "Pulse", 3, 0.5,
		1.5)

	-- treadmills: tiers 1-6 front row, 7-12 raised back row
	for i, tier in ipairs(TC.Tiers) do
		local row = i <= 6 and 0 or 1
		local col = (i - 1) % 6
		local x = -spacing * 2.5 + col * spacing
		local pos = row == 0 and CF(x, 0.4, 0) or CF(x, backTop, -17)
		local m = Skins.Build(tier.Skin, pos)
		m.Name = string.format("Treadmill%02d_%s", i, tier.Name)
		m:SetAttribute("Tier", i)
		CollectionService:AddTag(m, "Treadmill")
		m.Parent = gym
	end

	gym.PrimaryPart = gym:FindFirstChild("Floor")
	gym:PivotTo(origin)
	gym.Parent = workspace
	return gym
end

---------------------------------------------------------------------
-- 2. Sell booth glow-up
---------------------------------------------------------------------
local function isSell(inst)
	return inst.Name:lower():find("sell") ~= nil
end

function WB.DecorateSellBooths()
	local old = workspace:FindFirstChild("SellBoothFx")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "SellBoothFx"
	folder.Parent = workspace

	local count = 0
	for _, inst in ipairs(workspace:GetDescendants()) do
		if (inst:IsA("Model") or inst:IsA("BasePart")) and isSell(inst) then
			-- only the outermost "sell" object, and never players / our own fx
			local parent = inst.Parent
			local nested = false
			while parent and parent ~= workspace do
				if isSell(parent) or parent:FindFirstChildOfClass("Humanoid") then
					nested = true
					break
				end
				parent = parent.Parent
			end
			if not nested and not inst:FindFirstChildOfClass("Humanoid") then
				count += 1
				local cf, size
				if inst:IsA("Model") then
					cf, size = inst:GetBoundingBox()
				else
					cf, size = inst.CFrame, inst.Size
				end
				local ground = cf.Position.Y - size.Y / 2
				local center = V(cf.Position.X, ground, cf.Position.Z)
				local radius = math.max(size.X, size.Z) / 2 + 4

				local fxModel = Instance.new("Model")
				fxModel.Name = "SellFx_" .. inst.Name
				fxModel.Parent = folder

				-- pulsing neon ring
				local ring = P(fxModel, "Ring", V(0.15, radius * 2, radius * 2), CF(center + V(0, 0.1, 0))
					* ANG(0, 0, rad(90)), rgb(90, 255, 90), M.Neon, { Shape = Enum.PartType.Cylinder, CanCollide = false,
					Transparency = 0.4 })
				fx(ring, "Pulse", 2.5, 0.45)
				local inner = P(fxModel, "RingInner", V(0.16, radius * 2 - 1.2, radius * 2 - 1.2), CF(center + V(0, 0.1, 0))
					* ANG(0, 0, rad(90)), rgb(30, 120, 40), M.SmoothPlastic, { Shape = Enum.PartType.Cylinder,
					CanCollide = false, Transparency = 0.2 })
				inner.Name = "RingInner"

				-- orbiting lights
				for k = 0, 11 do
					local a = k / 12 * math.pi * 2
					local dot = P(fxModel, "OrbitDot", V(1.2, 0.4, 1.2), CF(center + V(math.cos(a) * (radius + 1), 0.4,
						math.sin(a) * (radius + 1))), k % 2 == 0 and YELLOW or rgb(90, 255, 90), M.Neon,
						{ CanCollide = false })
					dot:SetAttribute("FxCenter", center)
					fx(dot, "Orbit", 0.6)
				end

				-- floating spinning cash stack
				local top = ground + size.Y + 3
				for k = 0, 3 do
					fx(P(fxModel, "Cash", V(3, 0.7, 1.6), CF(center + V(0, top - ground + k * 0.75, 0)) * ANG(0, rad(k * 12), 0),
						k % 2 == 0 and rgb(70, 200, 70) or rgb(255, 210, 60), M.SmoothPlastic, { CanCollide = false }),
						"Float", 1.5, 0.8)
				end

				-- bouncing sign
				local signPart = P(fxModel, "SignAnchor", V(1, 1, 1), CF(center + V(0, top - ground + 6, 0)), YELLOW,
					M.SmoothPlastic, { Transparency = 1, CanCollide = false })
				fx(signPart, "Bob", 2.5, 0.8)
				local bb = Instance.new("BillboardGui")
				bb.Size = UDim2.fromScale(14, 4)
				bb.LightInfluence = 0
				bb.MaxDistance = 250
				bb.Parent = signPart
				local t = Instance.new("TextLabel")
				t.Size = UDim2.fromScale(1, 1)
				t.BackgroundTransparency = 1
				t.Font = Enum.Font.FredokaOne
				t.TextScaled = true
				t.Text = "💰 SELL HERE 💰"
				t.TextColor3 = Color3.new(1, 1, 1)
				t.Parent = bb
				local st = Instance.new("UIStroke")
				st.Thickness = 4
				st.Parent = t
				local g = Instance.new("UIGradient")
				g.Color = ColorSequence.new(rgb(255, 240, 90), rgb(80, 255, 90))
				g.Rotation = 90
				g.Parent = t

				-- money sparkles + glow
				local emitter = P(fxModel, "MoneyFx", V(radius * 1.6, 0.2, radius * 1.6), CF(center + V(0, 0.5, 0)),
					YELLOW, M.SmoothPlastic, { Transparency = 1, CanCollide = false })
				local pe = Instance.new("ParticleEmitter")
				pe.Color = ColorSequence.new(rgb(120, 255, 90), rgb(255, 230, 80))
				pe.LightEmission = 0.8
				pe.Rate = 12
				pe.Lifetime = NumberRange.new(1.2, 2)
				pe.Speed = NumberRange.new(3, 6)
				pe.SpreadAngle = Vector2.new(20, 20)
				pe.EmissionDirection = Enum.NormalId.Top
				pe.Size = NumberSequence.new(0.5, 0)
				pe.Parent = emitter
				light(emitter, rgb(110, 255, 110), radius * 2.5, 2)
			end
		end
	end
	print("[WorldBuilder] Decorated " .. count .. " sell booth(s)")
	return count
end

---------------------------------------------------------------------
-- 3. Lighting
---------------------------------------------------------------------
local function getOrMake(className, name)
	local inst = Lighting:FindFirstChildOfClass(className)
	if not inst then
		inst = Instance.new(className)
		inst.Name = name
		inst.Parent = Lighting
	end
	return inst
end

function WB.Lighting()
	Lighting.Brightness = 2.6
	Lighting.ClockTime = 14.5
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.OutdoorAmbient = rgb(150, 150, 175)
	Lighting.Ambient = rgb(90, 90, 110)

	local atmo = getOrMake("Atmosphere", "Atmosphere")
	atmo.Density = 0.27
	atmo.Offset = 0.15
	atmo.Color = rgb(200, 225, 255)
	atmo.Decay = rgb(120, 160, 255)
	atmo.Glare = 0.4
	atmo.Haze = 1.2

	local bloom = getOrMake("BloomEffect", "Bloom")
	bloom.Intensity = 0.7
	bloom.Size = 28
	bloom.Threshold = 1.6

	local cc = getOrMake("ColorCorrectionEffect", "ColorCorrection")
	cc.Saturation = 0.28
	cc.Contrast = 0.12
	cc.Brightness = 0.02
	cc.TintColor = rgb(255, 250, 245)

	local rays = getOrMake("SunRaysEffect", "SunRays")
	rays.Intensity = 0.06
	rays.Spread = 0.6
end

function WB.Install(origin)
	WB.Lighting()
	local gym = WB.BuildGym(origin)
	WB.DecorateSellBooths()
	print("[WorldBuilder] Done! Workspace.TreadmillGym is at " .. tostring(gym:GetPivot().Position)
		.. " - drag it wherever you want it.")
	return gym
end

return WB
