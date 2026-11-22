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

	MAP REVAMP (run in the Command Bar, edit mode):

		require(game.ReplicatedStorage.WorldBuilder).Revamp()

	  - removes treadmills that aren't in the TreadmillGym (e.g. beside the
	    player pens) and the old TreadmillShowcase
	  - builds Workspace.MarketPlaza: a SHOP booth (step on its pad to open
	    the shop) and a SELL booth (step on its pad to sell your food),
	    with a fountain, lamp posts, trees, flowers and balloons
	  - re-applies lighting
	  - lists every sound / script that looks like the "steal" sound

	Then remove the steal sound with:
		require(game.ReplicatedStorage.WorldBuilder).RemoveStealSounds()
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
		if (inst:IsA("Model") or inst:IsA("BasePart")) and isSell(inst) and not inst:GetAttribute("BuiltBy")
			and not inst:FindFirstAncestor("MarketPlaza") then
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

---------------------------------------------------------------------
-- 4. Remove treadmills that aren't part of the gym
---------------------------------------------------------------------
function WB.RemoveStrayTreadmills()
	local gym = workspace:FindFirstChild("TreadmillGym")
	local removed = 0
	local showcase = workspace:FindFirstChild("TreadmillShowcase")
	if showcase then
		showcase:Destroy()
	end
	for _, inst in ipairs(workspace:GetDescendants()) do
		if inst.Parent and inst:IsA("Model") and (gym == nil or not inst:IsDescendantOf(gym)) then
			local isTreadmill = CollectionService:HasTag(inst, "Treadmill") or inst:GetAttribute("Skin") ~= nil
			if isTreadmill then
				print("[WorldBuilder] Removed treadmill:", inst:GetFullName())
				inst:Destroy()
				removed += 1
			end
		end
	end
	print("[WorldBuilder] Removed " .. removed .. " treadmill(s) outside the TreadmillGym")
	return removed
end

---------------------------------------------------------------------
-- 5. Market plaza: Shop booth + Sell booth + decorations
---------------------------------------------------------------------
local WOOD = rgb(176, 120, 66)
local WOOD_DARK = rgb(120, 78, 40)

-- A market stall. Front faces local -Z.
local function booth(parent, cf, opts)
	local m = Instance.new("Model")
	m.Name = opts.Name
	m:SetAttribute("BuiltBy", "WorldBuilder")
	m.Parent = parent
	local function at(x, y, z)
		return cf * CF(x, y, z)
	end

	P(m, "Platform", V(16, 1, 12), at(0, 0.5, 0), WOOD_DARK, M.WoodPlanks)
	P(m, "Counter", V(13, 3.6, 2.6), at(0, 2.8, -3.6), WOOD, M.Wood)
	P(m, "CounterTop", V(13.6, 0.4, 3.2), at(0, 4.8, -3.6), opts.Trim, M.SmoothPlastic)
	P(m, "BackWall", V(14, 9, 1), at(0, 5.5, 5.2), WOOD, M.WoodPlanks)
	for _, x in ipairs({ -7, 7 }) do
		for _, z in ipairs({ -4.6, 5.2 }) do
			P(m, "Post", V(0.9, 10.5, 0.9), at(x, 6, z), WOOD_DARK, M.Wood)
		end
	end
	-- striped awning sloping down to the front
	for i = 0, 8 do
		local x = -7.2 + i * 1.8
		P(m, "Awning", V(1.8, 0.4, 12.4), at(x, 11.2, 0.3) * ANG(rad(12), 0, 0),
			i % 2 == 0 and opts.Awning[1] or opts.Awning[2])
		-- scalloped edge
		P(m, "Scallop", V(1.6, 1.6, 1.6), at(x, 9.8, -5.8), i % 2 == 0 and opts.Awning[1] or opts.Awning[2],
			M.SmoothPlastic, { Shape = Enum.PartType.Ball })
	end

	-- goods on the counter
	local r = Random.new(#opts.Name)
	for i = 1, 7 do
		local c = opts.Goods[(i - 1) % #opts.Goods + 1]
		local g = P(m, "Goods", V(1.1, 1.1, 1.1), at(-5 + i * 1.4, 5.55, -3.6 + r:NextNumber(-0.6, 0.6)), c,
			M.SmoothPlastic, { Shape = opts.GoodsShape or Enum.PartType.Ball, CanCollide = false })
		fx(g, "Bob", 3, 0.12, i)
	end

	-- big sign on the roof
	local signBoard = P(m, "Sign", V(12, 3.6, 0.8), at(0, 14.2, -0.8), opts.Trim, M.SmoothPlastic)
	sign(signBoard, Enum.NormalId.Front, opts.Title, opts.Gradient, 30)
	sign(signBoard, Enum.NormalId.Back, opts.Title, opts.Gradient, 30)
	fx(P(m, "SignTrim", V(12.4, 0.3, 1), at(0, 16.1, -0.8), opts.Neon, M.Neon, { CanCollide = false }), "Pulse", 3, 0.5)
	fx(P(m, "SignTrim", V(12.4, 0.3, 1), at(0, 12.3, -0.8), opts.Neon, M.Neon, { CanCollide = false }), "Pulse", 3, 0.5,
		1.5)

	-- floating bobbing label
	local anchor = P(m, "FloatAnchor", V(1, 1, 1), at(0, 20, -0.8), opts.Neon, M.SmoothPlastic,
		{ Transparency = 1, CanCollide = false })
	fx(anchor, "Bob", 2, 0.8)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(16, 4.5)
	bb.LightInfluence = 0
	bb.MaxDistance = 300
	bb.Parent = anchor
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = opts.Float
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Parent = bb
	local st = Instance.new("UIStroke")
	st.Thickness = 4
	st.Parent = t
	local g = Instance.new("UIGradient")
	g.Color = opts.Gradient
	g.Rotation = 90
	g.Parent = t

	-- step-on pad in front
	local padCenter = at(0, 0, -10)
	local ring = P(m, "PadRing", V(0.2, 10, 10), padCenter * CF(0, 0.1, 0) * ANG(0, 0, rad(90)), opts.Neon, M.Neon,
		{ Shape = Enum.PartType.Cylinder, CanCollide = false, Transparency = 0.3 })
	fx(ring, "Pulse", 3, 0.5)
	P(m, "PadInner", V(0.22, 8.4, 8.4), padCenter * CF(0, 0.1, 0) * ANG(0, 0, rad(90)), opts.Trim, M.SmoothPlastic,
		{ Shape = Enum.PartType.Cylinder, CanCollide = false, Transparency = 0.15 })
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		local center = padCenter.Position
		local dot = P(m, "PadDot", V(0.9, 0.35, 0.9), CF(center + V(math.cos(a) * 5.8, 0.3, math.sin(a) * 5.8)),
			k % 2 == 0 and YELLOW or opts.Neon, M.Neon, { CanCollide = false })
		dot:SetAttribute("FxCenter", center)
		fx(dot, "Orbit", 0.8)
	end
	local pad = P(m, "Pad", V(9, 5, 9), padCenter * CF(0, 2.5, 0), opts.Neon, M.SmoothPlastic,
		{ Transparency = 1, CanCollide = false })
	CollectionService:AddTag(pad, opts.PadTag)

	-- sparkles + light
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(opts.Neon, YELLOW)
	pe.LightEmission = 0.8
	pe.Rate = 10
	pe.Lifetime = NumberRange.new(1, 1.8)
	pe.Speed = NumberRange.new(3, 6)
	pe.SpreadAngle = Vector2.new(25, 25)
	pe.EmissionDirection = Enum.NormalId.Top
	pe.Size = NumberSequence.new(0.45, 0)
	pe.Parent = pad
	light(signBoard, opts.Neon, 30, 2)

	m.PrimaryPart = m:FindFirstChild("Platform")
	return m
end

local function tree(parent, pos, leafColor)
	P(parent, "Trunk", V(1.6, 7, 1.6), CF(pos + V(0, 3.5, 0)), WOOD_DARK, M.Wood)
	for i, off in ipairs({ V(0, 8, 0), V(1.6, 7, 0.8), V(-1.4, 7.2, -0.6), V(0, 9.6, 0) }) do
		fx(P(parent, "Leaves", V(4.5, 4.5, 4.5), CF(pos + off), leafColor, M.Grass, { Shape = Enum.PartType.Ball }),
			"Sway", 1.2, 0.05, pos.X + i)
	end
end

local function lamp(parent, pos, color)
	P(parent, "LampPost", V(0.7, 9, 0.7), CF(pos + V(0, 4.5, 0)), rgb(40, 40, 60), M.Metal)
	local bulb = P(parent, "Bulb", V(1.8, 1.8, 1.8), CF(pos + V(0, 9.6, 0)), color, M.Neon,
		{ Shape = Enum.PartType.Ball, CanCollide = false })
	fx(bulb, "Pulse", 2, 0.3, pos.Z)
	light(bulb, color, 24, 1.6)
end

local function balloons(parent, pos)
	local colors = { PINK, CYAN, YELLOW, rgb(120, 255, 90), rgb(170, 110, 255) }
	for i = 1, 5 do
		local bp = pos + V(math.cos(i * 1.3) * 1.2, 7 + i * 0.6, math.sin(i * 1.3) * 1.2)
		fx(P(parent, "Balloon", V(1.8, 2.2, 1.8), CF(bp), colors[i], M.SmoothPlastic,
			{ Shape = Enum.PartType.Ball, CanCollide = false }), "Bob", 1.5, 0.5, i)
		P(parent, "String", V(0.05, bp.Y - pos.Y - 1, 0.05), CF((bp + pos) / 2 - V(0, 0.5, 0)), rgb(240, 240, 240),
			M.SmoothPlastic, { CanCollide = false })
	end
end

local function fountain(parent, pos)
	P(parent, "FountainBase", V(1.4, 12, 12), CF(pos + V(0, 0.7, 0)) * ANG(0, 0, rad(90)), rgb(200, 205, 225),
		M.Marble, { Shape = Enum.PartType.Cylinder })
	local water = P(parent, "Water", V(0.3, 10.4, 10.4), CF(pos + V(0, 1.4, 0)) * ANG(0, 0, rad(90)),
		rgb(70, 190, 255), M.Glass, { Shape = Enum.PartType.Cylinder, Transparency = 0.25, CanCollide = false })
	fx(water, "Pulse", 1.5, 0.2)
	P(parent, "FountainPillar", V(4, 2, 2), CF(pos + V(0, 3, 0)) * ANG(0, 0, rad(90)), rgb(200, 205, 225), M.Marble,
		{ Shape = Enum.PartType.Cylinder })
	local top = P(parent, "FountainTop", V(0.6, 5, 5), CF(pos + V(0, 5.2, 0)) * ANG(0, 0, rad(90)), rgb(200, 205, 225),
		M.Marble, { Shape = Enum.PartType.Cylinder })
	local spray = Instance.new("ParticleEmitter")
	spray.Color = ColorSequence.new(rgb(200, 240, 255))
	spray.LightEmission = 0.4
	spray.Rate = 40
	spray.Lifetime = NumberRange.new(1, 1.4)
	spray.Speed = NumberRange.new(10, 13)
	spray.SpreadAngle = Vector2.new(18, 18)
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Acceleration = V(0, -25, 0)
	spray.Size = NumberSequence.new(0.5, 0.2)
	spray.Transparency = NumberSequence.new(0.2, 1)
	spray.Parent = top
	light(top, CYAN, 20, 1.5)
end

function WB.BuildPlaza(origin)
	local old = workspace:FindFirstChild("MarketPlaza")
	if old then
		origin = origin or old:GetPivot()
		old:Destroy()
	end
	if not origin then
		local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
		local base = spawn and V(spawn.Position.X, spawn.Position.Y - spawn.Size.Y / 2, spawn.Position.Z) or V(0, 0, 0)
		local pos = base + V(0, 0, 50)
		-- face the spawn so the booth fronts look at new players
		origin = CFrame.lookAt(pos, V(base.X, pos.Y, base.Z))
	end

	local plaza = Instance.new("Model")
	plaza.Name = "MarketPlaza"

	-- colourful tiled floor + neon border
	P(plaza, "PlazaFloor", V(70, 0.6, 44), CF(0, 0.3, 0), rgb(235, 225, 200), M.Slate)
	for i = 0, 6 do
		for j = 0, 3 do
			if (i + j) % 2 == 0 then
				P(plaza, "Tile", V(9.6, 0.05, 10.6), CF(-30 + i * 10, 0.62, -16.5 + j * 11), ({ PINK, CYAN, YELLOW })[(i + j)
					% 3 + 1], M.SmoothPlastic, { Transparency = 0.55, CanCollide = false })
			end
		end
	end
	for _, z in ipairs({ -22, 22 }) do
		fx(P(plaza, "Border", V(70, 0.3, 0.4), CF(0, 0.7, z), CYAN, M.Neon, { CanCollide = false }), "Pulse", 2, 0.5, z)
	end
	for _, x in ipairs({ -35, 35 }) do
		fx(P(plaza, "Border", V(0.4, 0.3, 44), CF(x, 0.7, 0), PINK, M.Neon, { CanCollide = false }), "Pulse", 2, 0.5, x)
	end

	booth(plaza, CF(-20, 0.6, 8), {
		Name = "ShopBooth",
		Title = "SHOP",
		Float = "🛒 SHOP 🛒",
		Awning = { rgb(60, 160, 255), rgb(255, 255, 255) },
		Trim = rgb(40, 110, 230),
		Neon = CYAN,
		Gradient = ColorSequence.new(rgb(140, 230, 255), rgb(60, 120, 255)),
		Goods = { rgb(255, 80, 150), rgb(255, 215, 50), rgb(120, 255, 90), rgb(170, 110, 255) },
		GoodsShape = Enum.PartType.Block,
		PadTag = "ShopPad",
	})
	booth(plaza, CF(20, 0.6, 8), {
		Name = "SellBooth",
		Title = "SELL",
		Float = "💰 SELL FOOD 💰",
		Awning = { rgb(235, 40, 50), rgb(255, 255, 255) },
		Trim = rgb(200, 30, 40),
		Neon = rgb(90, 255, 90),
		Gradient = ColorSequence.new(rgb(255, 240, 90), rgb(80, 255, 90)),
		Goods = { rgb(230, 40, 40), rgb(255, 160, 30), rgb(255, 230, 60), rgb(120, 220, 60) },
		PadTag = "SellPad",
	})

	fountain(plaza, V(0, 0.6, 2))
	for _, x in ipairs({ -32, -10, 10, 32 }) do
		lamp(plaza, V(x, 0.6, -19), x < 0 and PINK or CYAN)
	end
	for _, pos in ipairs({ V(-32, 0.6, 16), V(32, 0.6, 16) }) do
		tree(plaza, pos, rgb(70, 210, 70))
	end
	for _, pos in ipairs({ V(-8, 0.6, 17), V(8, 0.6, 17) }) do
		balloons(plaza, pos)
	end
	-- flower beds
	local flowerColors = { PINK, YELLOW, rgb(255, 255, 255), rgb(170, 110, 255), rgb(255, 120, 60) }
	local r = Random.new(42)
	for _, bed in ipairs({ V(-30, 0.6, -10), V(30, 0.6, -10), V(-4, 0.6, -14), V(4, 0.6, -14) }) do
		P(plaza, "FlowerBed", V(6, 0.8, 4), CF(bed + V(0, 0.4, 0)), rgb(110, 70, 40), M.Ground)
		for k = 1, 8 do
			local fp = bed + V(r:NextNumber(-2.5, 2.5), 1.3, r:NextNumber(-1.6, 1.6))
			P(plaza, "Stem", V(0.15, 0.8, 0.15), CF(fp - V(0, 0.4, 0)), rgb(60, 170, 60), M.Grass, { CanCollide = false })
			fx(P(plaza, "Flower", V(0.6, 0.6, 0.6), CF(fp), flowerColors[k % #flowerColors + 1], M.SmoothPlastic,
				{ Shape = Enum.PartType.Ball, CanCollide = false }), "Sway", 2, 0.15, k)
		end
	end

	plaza.PrimaryPart = plaza:FindFirstChild("PlazaFloor")
	plaza:PivotTo(origin)
	plaza.Parent = workspace
	print("[WorldBuilder] Built Workspace.MarketPlaza - drag it wherever you want it.")
	return plaza
end

---------------------------------------------------------------------
-- 6. Steal sound
---------------------------------------------------------------------
local SOUND_WORDS = { "steal", "stole", "grab", "snatch", "pickup", "pick_up", "collect", "take" }
local REMOVE_WORDS = { "steal", "stole", "snatch", "grab" } -- stricter list used for deleting

local function looksLikeSteal(name, words)
	name = name:lower()
	for _, w in ipairs(words or SOUND_WORDS) do
		if name:find(w, 1, true) then
			return true
		end
	end
	return false
end

local SEARCH_ROOTS = { "Workspace", "ReplicatedStorage", "ServerStorage", "ServerScriptService", "StarterGui",
	"StarterPlayer", "StarterPack", "SoundService" }

-- Prints sounds whose name looks like a steal sound, and every script line
-- that mentions stealing and plays a sound.
function WB.FindStealSounds()
	print("[WorldBuilder] ---- Possible steal sounds ----")
	for _, rootName in ipairs(SEARCH_ROOTS) do
		local root = game:GetService(rootName)
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("Sound") and (looksLikeSteal(d.Name) or (d.Parent and looksLikeSteal(d.Parent.Name))) then
				print("  Sound:", d:GetFullName(), d.SoundId)
			elseif d:IsA("LuaSourceContainer") then
				local ok, src = pcall(function()
					return d.Source
				end)
				if ok and src and src:lower():find("steal") then
					local n = 0
					for line in (src .. "\n"):gmatch("(.-)\n") do
						n += 1
						local l = line:lower()
						if l:find("sound") and (l:find(":play") or l:find("soundid")) then
							print(string.format("  Script line: %s:%d  %s", d:GetFullName(), n, (line:gsub("^%s+", ""))))
						end
					end
				end
			end
		end
	end
end

-- Deletes Sound objects whose name (or parent's name) looks like a steal
-- sound. Sounds created by scripts at runtime are listed by
-- FindStealSounds() so that line can be removed instead.
function WB.RemoveStealSounds()
	local removed = 0
	for _, rootName in ipairs(SEARCH_ROOTS) do
		for _, d in ipairs(game:GetService(rootName):GetDescendants()) do
			if d:IsA("Sound") and d.Parent
				and (looksLikeSteal(d.Name, REMOVE_WORDS) or looksLikeSteal(d.Parent.Name, REMOVE_WORDS)) then
				print("[WorldBuilder] Removed sound:", d:GetFullName())
				d:Destroy()
				removed += 1
			end
		end
	end
	print("[WorldBuilder] Removed " .. removed .. " steal sound(s). If you still hear it, check the script lines "
		.. "printed by FindStealSounds().")
	return removed
end

function WB.Revamp(plazaOrigin)
	WB.RemoveStrayTreadmills()
	WB.Lighting()
	WB.BuildPlaza(plazaOrigin)
	WB.FindStealSounds()
end

return WB
