--[[
	TreadmillSkins  (ModuleScript -> ReplicatedStorage)

	Builds 12 themed treadmill models out of plain Parts (no uploads needed):

	  Basic, Jungle, Tech, Hacker, Inferno, Frost,
	  Golden, Alien, Candy, Lucky, Toxic, Ocean

	EASIEST: paste this into Studio's Command Bar (View > Command Bar):

		require(game.ReplicatedStorage.TreadmillSkins).Install()

	That creates:
	  ServerStorage.TreadmillSkins   - one template model per skin
	  Workspace.TreadmillShowcase    - all 12 on a two-row display

	Other functions:
	  .Build(skinName, cframe?)        -> Model (not parented)
	  .Swap(oldTreadmill, skinName)    -> Model. Replaces an existing treadmill
	                                      in place, keeping its name, attributes
	                                      and any scripts / values / prompts.
	  .SwapAll(folder, skinName)       -> reskins every Model in a folder
	  .Skins                           -> list of skin names in display order

	Each model's PrimaryPart is "Deck" and it has a "Belt" part (the running
	surface) plus an invisible "Hitbox" covering the belt for touch checks.
]]

local CollectionService = game:GetService("CollectionService")

local TreadmillSkins = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local rgb = Color3.fromRGB
local M = Enum.Material

TreadmillSkins.Skins = {
	"Basic", "Jungle", "Tech", "Hacker", "Inferno", "Frost",
	"Golden", "Alien", "Candy", "Lucky", "Toxic", "Ocean",
}

---------------------------------------------------------------------
-- Part helpers (everything is built around the origin, then pivoted)
---------------------------------------------------------------------
local function P(model, name, size, cframe, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
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
	p.Parent = model
	return p
end

local function wedge(model, name, size, cframe, color, material)
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Anchored = true
	w.CanCollide = false
	w.Size = size
	w.CFrame = cframe
	w.Color = color
	w.Material = material or M.SmoothPlastic
	w.Parent = model
	return w
end

-- vertical cylinder standing on `pos` (pos = bottom centre)
local function cylUp(model, name, pos, height, diameter, color, material)
	return P(model, name, V(height, diameter, diameter), CF(pos + V(0, height / 2, 0)) * ANG(0, 0, rad(90)),
		color, material, { Shape = Enum.PartType.Cylinder })
end

-- disc facing sideways (axis = X), like a wheel
local function disc(model, name, cframe, thickness, diameter, color, material)
	return P(model, name, V(thickness, diameter, diameter), cframe, color, material, { Shape = Enum.PartType.Cylinder })
end

local function ball(model, name, pos, d, color, material, props)
	local t = { Shape = Enum.PartType.Ball }
	if props then
		for k, v in pairs(props) do
			t[k] = v
		end
	end
	return P(model, name, V(d, d, d), CF(pos), color, material, t)
end

local function light(part, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range or 12
	l.Brightness = brightness or 2
	l.Parent = part
	return l
end

local function particles(part, color, opts)
	opts = opts or {}
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.LightEmission = opts.LightEmission or 0.8
	e.Rate = opts.Rate or 6
	e.Lifetime = NumberRange.new(opts.Life or 1.2, (opts.Life or 1.2) * 1.6)
	e.Speed = NumberRange.new(opts.Speed or 1.5, (opts.Speed or 1.5) * 2)
	e.SpreadAngle = Vector2.new(opts.Spread or 180, opts.Spread or 180)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, opts.Size or 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Transparency = NumberSequence.new(0.1, 1)
	e.Acceleration = opts.Accel or V(0, 1, 0)
	if opts.Texture then
		e.Texture = opts.Texture
	end
	e.Parent = part
	return e
end

local function label(part, face, text, color, bg)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 50
	g.LightInfluence = 0
	g.Parent = part
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = bg and 0 or 1
	t.BackgroundColor3 = bg or Color3.new()
	t.Text = text
	t.TextColor3 = color
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextStrokeTransparency = 0
	t.Parent = g
	return g
end

local function allFaces(part, text, color)
	for _, face in ipairs(Enum.NormalId:GetEnumItems()) do
		label(part, face, text, color)
	end
end

local function rng(seed)
	return Random.new(seed)
end

-- Marks a part for the client animator (TreadmillClient):
--   Spin (world Y), Bob, Float (bob+spin), Roll (own X axis), Sway,
--   Pulse (neon glow), Belt (scrolling slats), Orbit (around FxCenter)
local function fx(part, kind, speed, amp, phase)
	part:SetAttribute("Fx", kind)
	part:SetAttribute("FxSpeed", speed or 1)
	part:SetAttribute("FxAmp", amp or 0.5)
	part:SetAttribute("FxPhase", phase or 0)
	CollectionService:AddTag(part, "TreadFx")
	return part
end
TreadmillSkins.fx = fx

---------------------------------------------------------------------
-- The shared treadmill body
--   faces -Z (console end); the runner stands on +Z side of the belt
--   footprint ~6 x 11.5 studs, ~8 studs tall
---------------------------------------------------------------------
local function buildBase(m, t)
	local frameMat, trimMat = t.Material or M.SmoothPlastic, t.TrimMaterial or M.SmoothPlastic

	local deck = P(m, "Deck", V(6, 1, 11), CF(0, 0.5, 0), t.Frame, frameMat, { CanCollide = true })
	P(m, "Belt", V(4.6, 0.3, 10), CF(0, 1.1, 0.35), t.Belt, M.SmoothPlastic, { CanCollide = true })
	-- belt slats
	for i = 0, 7 do
		fx(P(m, "Slat", V(4.6, 0.05, 0.12), CF(0, 1.27, -4.2 + i * 1.1), t.Belt:Lerp(Color3.new(1, 1, 1), 0.15)),
			"Belt", 2.5, 1.1)
	end
	P(m, "RailL", V(0.8, 0.8, 11), CF(-2.7, 1.25, 0), t.Trim, trimMat)
	P(m, "RailR", V(0.8, 0.8, 11), CF(2.7, 1.25, 0), t.Trim, trimMat)
	P(m, "Motor", V(6, 1.6, 1.4), CF(0, 1.2, -5.3), t.Frame, frameMat)
	P(m, "Roller", V(6.2, 0.7, 0.7), CF(0, 0.75, 5.4), t.Trim, trimMat)

	for _, x in ipairs({ -2.6, 2.6 }) do
		P(m, "Post", V(0.75, 5.6, 0.75), CF(x, 4.2, -4.9) * ANG(rad(-8), 0, 0), t.Frame, frameMat)
		P(m, "Handle", V(0.5, 0.5, 3.2), CF(x, 4.9, -3.3), t.Trim, trimMat)
		P(m, "HandleCap", V(0.6, 0.6, 0.6), CF(x, 4.9, -1.75), t.Accent or t.Trim, trimMat)
	end

	local console = P(m, "Console", V(6.2, 2.6, 1), CF(0, 7.2, -5.45) * ANG(rad(-25), 0, 0), t.Frame, frameMat)
	P(m, "ConsoleTrim", V(6.4, 0.35, 1.1), console.CFrame * CF(0, 1.4, 0), t.Trim, trimMat)
	P(m, "ConsoleLip", V(6.4, 0.35, 1.1), console.CFrame * CF(0, -1.4, 0), t.Trim, trimMat)
	-- display buttons (front face is local +Z)
	local small = { rgb(255, 220, 40), rgb(255, 150, 30), rgb(255, 220, 40), rgb(255, 150, 30) }
	for i, c in ipairs(small) do
		fx(P(m, "Button", V(1, 0.5, 0.2), console.CFrame * CF(-1.65 + (i - 1) * 1.1, 0.55, 0.55), c, M.Neon),
			"Pulse", 3, 0.7, i)
	end
	P(m, "BigRed", V(1.5, 0.9, 0.25), console.CFrame * CF(-1.6, -0.45, 0.55), rgb(235, 40, 50), M.SmoothPlastic)
	P(m, "BigGreen", V(1.5, 0.9, 0.25), console.CFrame * CF(1.6, -0.45, 0.55), rgb(60, 220, 60), M.SmoothPlastic)

	if t.Glow then
		fx(P(m, "GlowStripL", V(0.15, 0.2, 10.6), CF(-3.12, 1.25, 0), t.Glow, M.Neon), "Pulse", 2, 0.6)
		fx(P(m, "GlowStripR", V(0.15, 0.2, 10.6), CF(3.12, 1.25, 0), t.Glow, M.Neon), "Pulse", 2, 0.6)
		light(deck, t.Glow, 14, 1.5)
	end

	P(m, "Hitbox", V(4.6, 4, 10), CF(0, 3.2, 0.35), rgb(255, 255, 255), M.SmoothPlastic, {
		Transparency = 1,
		CanTouch = true,
		CanQuery = false,
	})

	m.PrimaryPart = deck
	return console
end

---------------------------------------------------------------------
-- Themes
---------------------------------------------------------------------
local Themes = {}

Themes.Basic = {
	Frame = rgb(205, 185, 235), Trim = rgb(150, 135, 180), Belt = rgb(95, 95, 105),
}

Themes.Jungle = {
	Frame = rgb(255, 150, 30), Trim = rgb(225, 105, 15), Belt = rgb(170, 90, 25), Accent = rgb(70, 210, 50),
	Deco = function(m)
		local vine = rgb(60, 205, 45)
		local r = rng(2)
		-- vines zig-zagging over the deck and up the posts
		for i = 0, 6 do
			local z = -4.5 + i * 1.6
			P(m, "Vine", V(6.6, 0.22, 0.3), CF(0, 1.5, z) * ANG(0, rad(r:NextNumber(-35, 35)), 0), vine, M.Grass)
		end
		for _, x in ipairs({ -2.6, 2.6 }) do
			for j = 0, 4 do
				P(m, "Vine", V(1, 0.25, 0.25), CF(x, 2 + j * 1.1, -4.85) * ANG(0, 0, rad(j % 2 == 0 and 35 or -35)), vine, M.Grass)
			end
		end
		for i = 1, 10 do
			local pos = V(r:NextNumber(-3.2, 3.2), r:NextNumber(1.6, 7.5), r:NextNumber(-5.5, 4))
			fx(P(m, "Leaf", V(0.9, 0.12, 0.55), CF(pos) * ANG(r:NextNumber(0, 6), r:NextNumber(0, 6), 0), vine, M.Grass),
				"Sway", 2, 0.35, i)
		end
	end,
}

Themes.Tech = {
	Frame = rgb(230, 230, 240), Trim = rgb(175, 175, 195), Belt = rgb(115, 115, 125),
	Deco = function(m, console)
		local base = console.CFrame * CF(0, 2.6, -0.3)
		for i = -1, 1 do
			local mon = P(m, "Monitor", V(2.4, 1.6, 0.25), base * CF(i * 2.45, 0, 0) * ANG(0, rad(-i * 15), 0),
				rgb(60, 60, 70))
			fx(P(m, "Screen", V(2.1, 1.3, 0.05), mon.CFrame * CF(0, 0, 0.14), rgb(40, 60, 90), M.Neon), "Pulse", 1.5, 0.4, i)
		end
		P(m, "MonitorStand", V(0.3, 1.6, 0.3), base * CF(0, -1.2, -0.1), rgb(60, 60, 70))
		-- coloured cables down the sides
		local cables = { rgb(40, 140, 255), rgb(60, 220, 90), rgb(255, 80, 200) }
		for i, c in ipairs(cables) do
			for _, x in ipairs({ -3.35, 3.35 }) do
				fx(P(m, "Cable", V(0.18, 4.5, 0.18), CF(x, 3.3, -4.4 + i * 0.35), c, M.Neon), "Pulse", 4, 0.7, i)
				fx(disc(m, "CableLoop", CF(x, 1.3, -1 + i * 1.6) * ANG(0, rad(90), 0), 0.15, 1.1, c, M.Neon), "Roll", 3)
			end
		end
	end,
}

Themes.Hacker = {
	Frame = rgb(70, 225, 60), Trim = rgb(25, 130, 35), Belt = rgb(35, 95, 35), Glow = rgb(80, 255, 80),
	Deco = function(m, console)
		local codes = { "11011\n01010\n10111", "10110\n01101\n11001" }
		for i, x in ipairs({ -1.6, 1.6 }) do
			local sign = P(m, "CodeSign", V(2.8, 2, 0.2), console.CFrame * CF(x, 2.8, -0.3), rgb(15, 25, 15))
			label(sign, Enum.NormalId.Front, codes[i], rgb(90, 255, 90))
			label(sign, Enum.NormalId.Back, codes[i], rgb(90, 255, 90))
		end
		local r = rng(7)
		for i = 1, 6 do
			local pos = V(r:NextNumber(-3.5, 3.5), r:NextNumber(3, 8), r:NextNumber(-5, 3))
			fx(disc(m, "DataRing", CF(pos) * ANG(0, r:NextNumber(0, 6), 0), 0.12, 0.7, rgb(90, 255, 90), M.Neon),
				"Float", 2, 0.6, i)
		end
		local emitter = P(m, "CodeFx", V(5, 0.2, 9), CF(0, 2, 0), rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1 })
		particles(emitter, rgb(90, 255, 90), { Rate = 8, Speed = 1, Accel = V(0, 2, 0), Size = 0.3 })
	end,
}

Themes.Inferno = {
	Frame = rgb(255, 45, 40), Trim = rgb(175, 15, 15), Belt = rgb(120, 20, 20), Glow = rgb(255, 120, 20),
	Deco = function(m, console)
		for _, z in ipairs({ -3, 2 }) do
			local f = Instance.new("Fire")
			f.Heat = 6
			f.Size = 4
			f.Color = rgb(255, 120, 20)
			f.SecondaryColor = rgb(255, 40, 0)
			f.Parent = P(m, "FireSrc", V(1, 0.2, 1), CF(0, 1.4, z), rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1 })
		end
		local cf = Instance.new("Fire")
		cf.Size = 3
		cf.Heat = 4
		cf.Color = rgb(255, 150, 30)
		cf.SecondaryColor = rgb(255, 30, 0)
		cf.Parent = console
		-- lava puddles
		for _, p in ipairs({ V(-3.8, 0.05, -2), V(3.6, 0.05, 1.5), V(-2.5, 0.05, 5.3), V(2, 0.05, -5.8) }) do
			fx(P(m, "Lava", V(0.1, 2.4, 2.4), CF(p) * ANG(0, 0, rad(90)), rgb(255, 90, 0), M.Neon,
				{ Shape = Enum.PartType.Cylinder }), "Pulse", 3, 0.5, p.X)
		end
		-- shadow imps with glowing eyes
		for _, side in ipairs({ -1, 1 }) do
			local base = CF(side * 4.2, 0, 2.5) * ANG(0, rad(side * -90), 0)
			wedge(m, "Imp", V(2, 3.2, 2), base * CF(0, 1.6, 0), rgb(25, 10, 35))
			wedge(m, "ImpEar", V(0.6, 1.2, 0.6), base * CF(-0.6, 3.6, 0.2), rgb(25, 10, 35))
			wedge(m, "ImpEar", V(0.6, 1.2, 0.6), base * CF(0.6, 3.6, 0.2), rgb(25, 10, 35))
			for _, ex in ipairs({ -0.35, 0.35 }) do
				fx(P(m, "Eye", V(0.35, 0.25, 0.1), base * CF(ex, 2.4, -1.05), rgb(255, 220, 40), M.Neon), "Pulse", 5, 0.9, side)
			end
		end
	end,
}

Themes.Frost = {
	Frame = rgb(85, 230, 255), Trim = rgb(225, 250, 255), Belt = rgb(65, 170, 215), Glow = rgb(150, 240, 255),
	Deco = function(m)
		local r = rng(11)
		local spots = {
			V(-3.8, 0, -4), V(-4, 0, -1), V(-3.7, 0, 2.5), V(-3.4, 0, 5.2),
			V(3.8, 0, -4.2), V(4, 0, -0.5), V(3.7, 0, 3), V(3.3, 0, 5.4),
		}
		for _, pos in ipairs(spots) do
			local h = r:NextNumber(2.5, 5)
			P(m, "IceShard", V(0.7, h, 0.7),
				CF(pos + V(0, h / 2 - 0.3, 0)) * ANG(rad(r:NextNumber(-15, 15)), rad(45), rad(r:NextNumber(-20, 20))),
				rgb(140, 235, 255), M.Glass, { Transparency = 0.15, Reflectance = 0.2 })
			fx(m:GetChildren()[#m:GetChildren()], "Pulse", 1.5, 0.35, pos.Z)
		end
		local snow = P(m, "SnowFx", V(7, 0.2, 11), CF(0, 9, 0), rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1 })
		particles(snow, rgb(255, 255, 255), { Rate = 10, Speed = 0.5, Accel = V(0, -2, 0), Size = 0.25, Life = 3 })
	end,
}

Themes.Golden = {
	Frame = rgb(255, 205, 40), Trim = rgb(255, 165, 0), Belt = rgb(220, 165, 40),
	Material = M.Foil, TrimMaterial = M.Foil, Glow = rgb(255, 220, 90),
	Deco = function(m, console)
		local sp = Instance.new("Sparkles")
		sp.SparkleColor = rgb(255, 240, 150)
		sp.Parent = console
		local r = rng(3)
		-- coin piles
		for _, c in ipairs({ V(-3.6, 0, 5), V(3.8, 0, -3.5), V(-4, 0, -4.5) }) do
			for i = 1, 6 do
				local off = V(r:NextNumber(-0.8, 0.8), 0, r:NextNumber(-0.8, 0.8))
				P(m, "Coin", V(0.15, 1, 1), CF(c + off + V(0, 0.1 + i * 0.12, 0)) * ANG(0, r:NextNumber(0, 6), rad(90)),
					rgb(255, 215, 50), M.Foil, { Shape = Enum.PartType.Cylinder })
			end
		end
		P(m, "GoldBar", V(1.2, 0.5, 0.6), CF(3.6, 0.25, 4.5), rgb(255, 200, 40), M.Foil)
		P(m, "GoldBar", V(1.2, 0.5, 0.6), CF(3.6, 0.75, 4.5) * ANG(0, rad(20), 0), rgb(255, 200, 40), M.Foil)
		for i, pos in ipairs({ V(-3.5, 7.5, -2), V(3.5, 6, 1), V(0, 10, -5) }) do
			fx(P(m, "FloatCoin", V(0.25, 1.6, 1.6), CF(pos) * ANG(0, 0, 0), rgb(255, 215, 50), M.Foil,
				{ Shape = Enum.PartType.Cylinder }), "Float", 2.5, 0.6, i)
		end
	end,
}

Themes.Alien = {
	Frame = rgb(230, 45, 255), Trim = rgb(70, 45, 230), Belt = rgb(110, 20, 160), Glow = rgb(200, 80, 255),
	Deco = function(m)
		local function ufo(pos, tilt)
			local cf = CF(pos)
			local phase = pos.X + pos.Z
			fx(P(m, "UFO", V(0.35, 1.8, 1.8), cf * ANG(0, 0, rad(90)), rgb(70, 210, 60), M.SmoothPlastic,
				{ Shape = Enum.PartType.Cylinder }), "Float", 2, 0.7, phase)
			fx(ball(m, "UFODome", (cf * CF(0, 0.3, 0)).Position, 0.9, rgb(170, 255, 255), M.Glass, { Transparency = 0.3 }),
				"Float", 2, 0.7, phase)
			fx(P(m, "UFOLight", V(0.1, 1.9, 1.9), cf * CF(0, -0.15, 0) * ANG(0, 0, rad(90)), rgb(150, 255, 100), M.Neon,
				{ Shape = Enum.PartType.Cylinder }), "Float", 2, 0.7, phase)
		end
		ufo(V(-3.5, 8.5, -3), 15)
		ufo(V(3.8, 7, 1), -12)
		ufo(V(-3, 4, 4.5), 8)
		local r = rng(5)
		for i = 1, 5 do
			fx(P(m, "Cash", V(1, 0.05, 0.5), CF(r:NextNumber(-4, 4), r:NextNumber(2, 8), r:NextNumber(-5, 4))
				* ANG(r:NextNumber(0, 6), r:NextNumber(0, 6), 0), rgb(110, 200, 90)), "Float", 1.5, 0.5, i)
		end
		local fx = P(m, "SpaceFx", V(6, 0.2, 10), CF(0, 3, 0), rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1 })
		particles(fx, rgb(255, 120, 255), { Rate = 8 })
	end,
}

Themes.Candy = {
	Frame = rgb(255, 145, 215), Trim = rgb(255, 95, 185), Belt = rgb(255, 185, 230), Glow = rgb(255, 150, 230),
	Deco = function(m)
		-- peppermint wheels on the sides
		for _, x in ipairs({ -3.6, 3.6 }) do
			for _, z in ipairs({ -3.5, 1.5 }) do
				local wheel = disc(m, "Candy", CF(x, 2.5, z), 0.5, 4.2, rgb(255, 110, 190))
				-- peppermint stripes so the roll is visible
				for k = 0, 2 do
					fx(P(m, "CandyStripe", V(0.55, 4, 0.5), CF(x, 2.5, z) * ANG(rad(k * 60), 0, 0), rgb(255, 255, 255)),
						"Roll", 1.5)
				end
				P(m, "CandyCore", V(0.6, 1.4, 1.4), CF(x + (x > 0 and 0.05 or -0.05), 2.5, z), rgb(255, 60, 140),
					M.SmoothPlastic, { Shape = Enum.PartType.Cylinder })
				fx(wheel, "Roll", 1.5)
			end
		end
		-- cupcakes around the base
		for _, pos in ipairs({ V(-3, 0, 5.8), V(3, 0, 5.8), V(-4.2, 0, 4.5), V(4.3, 0, -5.8) }) do
			cylUp(m, "CupcakeBase", pos, 0.9, 1.2, rgb(80, 220, 240))
			ball(m, "Frosting", pos + V(0, 1.15, 0), 1.3, rgb(255, 170, 220))
			fx(ball(m, "Cherry", pos + V(0, 1.85, 0), 0.4, rgb(230, 30, 50)), "Bob", 4, 0.15, pos.X)
		end
		local fx = P(m, "SweetFx", V(6, 0.2, 10), CF(0, 4, 0), rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1 })
		particles(fx, rgb(255, 200, 240), { Rate = 5 })
	end,
}

Themes.Lucky = {
	Frame = rgb(255, 210, 45), Trim = rgb(255, 150, 20), Belt = rgb(205, 150, 45),
	Deco = function(m, console)
		local function block(cf, s)
			local b = P(m, "LuckyBlock", V(s, s, s), cf, rgb(255, 205, 30), M.SmoothPlastic)
			allFaces(b, "?", rgb(255, 255, 255))
			local sel = Instance.new("SelectionBox")
			sel.Adornee = b
			sel.Color3 = rgb(200, 120, 0)
			sel.LineThickness = 0.05
			sel.Parent = b
			return b
		end
		fx(block(console.CFrame * CF(2.4, 2.2, 0) * ANG(0, rad(20), rad(15)), 1.6), "Float", 1.5, 0.5)
		local stacks = { V(-4, 0, -4), V(4, 0, 3.5), V(-4.2, 0, 4.8), V(4.2, 0, -4.8) }
		for i, pos in ipairs(stacks) do
			block(CF(pos + V(0, 0.75, 0)) * ANG(0, rad(i * 17), 0), 1.5)
			if i % 2 == 1 then
				fx(block(CF(pos + V(0.2, 2.4, 0)) * ANG(0, rad(i * 31), 0), 1.4), "Float", 1.2, 0.4, i)
			end
		end
		local sp = Instance.new("Sparkles")
		sp.SparkleColor = rgb(255, 230, 120)
		sp.Parent = console
	end,
}

Themes.Toxic = {
	Frame = rgb(95, 255, 45), Trim = rgb(40, 165, 25), Belt = rgb(45, 120, 35), Glow = rgb(140, 255, 60),
	Deco = function(m)
		for _, pos in ipairs({ V(-4.3, 0, -3.5), V(-4.3, 0, -1.6), V(4.3, 0, 3.8), V(-4.2, 0, 4.5) }) do
			cylUp(m, "Barrel", pos, 2.2, 1.6, rgb(95, 85, 120), M.Metal)
			cylUp(m, "BarrelBand", pos + V(0, 0.6, 0), 0.2, 1.65, rgb(60, 55, 80), M.Metal)
			fx(cylUp(m, "Ooze", pos + V(0, 2.2, 0), 0.1, 1.3, rgb(130, 255, 40), M.Neon), "Pulse", 2.5, 0.6, pos.Z)
		end
		local sign = P(m, "Warning", V(1.4, 1.4, 0.1), CF(4.3, 2.2, -4) * ANG(0, rad(-90), rad(45)), rgb(255, 210, 30))
		label(sign, Enum.NormalId.Front, "!", rgb(20, 20, 20))
		label(sign, Enum.NormalId.Back, "!", rgb(20, 20, 20))
		fx(P(m, "Puddle", V(0.1, 3, 3), CF(0, 0.05, 6.2) * ANG(0, 0, rad(90)), rgb(130, 255, 40), M.Neon,
			{ Shape = Enum.PartType.Cylinder }), "Pulse", 2, 0.5)
		local fx = P(m, "ToxicFx", V(6, 0.2, 10), CF(0, 2, 0), rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1 })
		particles(fx, rgb(140, 255, 60), { Rate = 10, Speed = 0.8, Accel = V(0, 1.5, 0), Size = 0.5 })
	end,
}

Themes.Ocean = {
	Frame = rgb(125, 205, 255), Trim = rgb(60, 115, 255), Belt = rgb(85, 145, 215), Glow = rgb(80, 190, 255),
	Material = M.SmoothPlastic, TrimMaterial = M.Glass,
	Deco = function(m)
		local r = rng(9)
		local corals = { rgb(255, 140, 60), rgb(255, 90, 180), rgb(150, 90, 255), rgb(60, 140, 255) }
		local spots = { V(-4.2, 0, -4), V(4.3, 0, -4.5), V(-4.4, 0, 3), V(4.2, 0, 2), V(-3, 0, 6), V(3.5, 0, 6) }
		for i, pos in ipairs(spots) do
			local c = corals[(i - 1) % #corals + 1]
			-- branching coral
			fx(P(m, "Coral", V(0.35, 2.4, 0.35), CF(pos + V(0, 1.2, 0)), c), "Sway", 1.5, 0.12, i)
			for b = 1, 3 do
				local ang = rad(r:NextNumber(25, 50)) * (b % 2 == 0 and 1 or -1)
				P(m, "CoralBranch", V(0.25, 1.4, 0.25),
					CF(pos + V(0, 1 + b * 0.5, 0)) * ANG(0, rad(b * 120), ang) * CF(0, 0.6, 0), c)
				ball(m, "CoralTip", (CF(pos + V(0, 1 + b * 0.5, 0)) * ANG(0, rad(b * 120), ang) * CF(0, 1.3, 0)).Position,
					0.35, c)
			end
		end
		for i = 1, 5 do
			local pos = V(r:NextNumber(-3.5, 3.5), 0, r:NextNumber(-6, -4.5))
			local h = r:NextNumber(1.5, 3)
			P(m, "Crystal", V(0.6, h, 0.6), CF(pos + V(0, h / 2, 0)) * ANG(0, rad(45), rad(r:NextNumber(-15, 15))),
				rgb(130, 220, 255), M.Glass, { Transparency = 0.2 })
			fx(m:GetChildren()[#m:GetChildren()], "Pulse", 1.2, 0.3, i)
		end
		local fx = P(m, "BubbleFx", V(6, 0.2, 10), CF(0, 1.5, 0), rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1 })
		particles(fx, rgb(200, 240, 255), { Rate = 8, Speed = 1, Accel = V(0, 3, 0), Size = 0.4, LightEmission = 0.3 })
	end,
}

TreadmillSkins.Themes = Themes

---------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------
function TreadmillSkins.Build(skinName, cframe)
	local t = Themes[skinName]
	assert(t, "Unknown treadmill skin: " .. tostring(skinName))
	local m = Instance.new("Model")
	m.Name = skinName .. "Treadmill"
	m:SetAttribute("Skin", skinName)
	local console = buildBase(m, t)
	if t.Deco then
		t.Deco(m, console)
	end
	if cframe then
		m:PivotTo(cframe)
	end
	return m
end

-- Replace an existing treadmill model with a skinned one, keeping its
-- position, name, attributes and non-visual children (scripts, values,
-- configurations, prompts, sounds, etc.).
function TreadmillSkins.Swap(old, skinName, tier)
	local new = TreadmillSkins.Build(skinName, old:GetPivot())
	if tier then
		new:SetAttribute("Tier", tier)
		CollectionService:AddTag(new, "Treadmill")
	end
	new.Name = old.Name
	for k, v in pairs(old:GetAttributes()) do
		new:SetAttribute(k, v)
	end
	new:SetAttribute("Skin", skinName)
	for _, child in ipairs(old:GetChildren()) do
		if not child:IsA("BasePart") and not child:IsA("Model") and not child:IsA("Folder") then
			child.Parent = new
		end
	end
	-- move prompts / clickdetectors / touch scripts that lived inside parts
	for _, d in ipairs(old:GetDescendants()) do
		if d:IsA("ProximityPrompt") or d:IsA("ClickDetector") or d:IsA("BaseScript") then
			if d.Parent and d.Parent:IsA("BasePart") then
				local target = new:FindFirstChild(d.Parent.Name) or new:FindFirstChild("Hitbox")
				d.Parent = target
			end
		end
	end
	new.Parent = old.Parent
	old:Destroy()
	return new
end

function TreadmillSkins.SwapAll(folder, skinName)
	local out = {}
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") then
			table.insert(out, TreadmillSkins.Swap(child, skinName))
		end
	end
	return out
end

-- Builds templates in ServerStorage and a two-row showcase in Workspace.
function TreadmillSkins.Install(origin)
	origin = origin or CF(0, 0, 0)

	local templates = game:GetService("ServerStorage"):FindFirstChild("TreadmillSkins")
	if templates then
		templates:Destroy()
	end
	templates = Instance.new("Folder")
	templates.Name = "TreadmillSkins"
	templates.Parent = game:GetService("ServerStorage")

	local showcase = workspace:FindFirstChild("TreadmillShowcase")
	if showcase then
		showcase:Destroy()
	end
	showcase = Instance.new("Folder")
	showcase.Name = "TreadmillShowcase"
	showcase.Parent = workspace

	-- two-tier display like a shop shelf: front row low, back row raised
	local spacing = 14
	local platformColor = rgb(40, 50, 95)
	local frontLen = spacing * 6
	P(showcase, "FrontStage", V(frontLen + 6, 1, 18), origin * CF(0, -0.5, 0), platformColor, M.SmoothPlastic,
		{ CanCollide = true })
	P(showcase, "BackStage", V(frontLen + 6, 6, 16), origin * CF(0, 2.5, -17), platformColor, M.SmoothPlastic,
		{ CanCollide = true })
	P(showcase, "FrontEdge", V(frontLen + 6, 0.25, 0.25), origin * CF(0, 0.05, 9), rgb(60, 220, 255), M.Neon)
	P(showcase, "BackEdge", V(frontLen + 6, 0.25, 0.25), origin * CF(0, 5.55, -9), rgb(255, 80, 230), M.Neon)

	for i, name in ipairs(TreadmillSkins.Skins) do
		local template = TreadmillSkins.Build(name)
		template.Parent = templates

		local row = i <= 6 and 0 or 1
		local col = (i - 1) % 6
		local x = -frontLen / 2 + spacing / 2 + col * spacing
		local pos = row == 0 and CF(x, 0, 0) or CF(x, 5.5, -17)
		local display = template:Clone()
		display:PivotTo(origin * pos)
		display.Parent = showcase
	end

	print("[TreadmillSkins] Installed 12 skins: ServerStorage.TreadmillSkins + Workspace.TreadmillShowcase")
	return templates, showcase
end

return TreadmillSkins
