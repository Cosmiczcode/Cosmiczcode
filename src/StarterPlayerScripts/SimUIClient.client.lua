--[[
	SimUIClient  (LocalScript -> StarterPlayer > StarterPlayerScripts)

	Builds the whole HUD + Shop, Index and Daily Rewards windows in code.
	Layout is drawn on a 1835 x 1032 reference canvas and scaled to fit
	every screen size, so it looks the same on PC, tablet and phone.

	Every HUD button also fires PlayerGui.SimulatorUI.ButtonClicked
	(BindableEvent) with the button name, so you can hook in extra
	behaviour from your own LocalScripts:

		local gui = player.PlayerGui:WaitForChild("SimulatorUI")
		gui.ButtonClicked.Event:Connect(function(name) print(name) end)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("SimUIConfig"))
local Remotes = ReplicatedStorage:WaitForChild("SimUIRemotes")
local S = Config.Stats

---------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------
local REF_W, REF_H = 1835, 1032
local FONT = Font.fromEnum(Enum.Font.FredokaOne)
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.fromRGB(15, 15, 20)

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local STRIPES = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.48, 1),
	NumberSequenceKeypoint.new(0.481, 0.82),
	NumberSequenceKeypoint.new(0.58, 0.82),
	NumberSequenceKeypoint.new(0.581, 1),
	NumberSequenceKeypoint.new(0.64, 1),
	NumberSequenceKeypoint.new(0.641, 0.86),
	NumberSequenceKeypoint.new(0.68, 0.86),
	NumberSequenceKeypoint.new(0.681, 1),
	NumberSequenceKeypoint.new(1, 1),
})

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, rgb(190, 60, 255)),
	ColorSequenceKeypoint.new(0.3, rgb(255, 70, 170)),
	ColorSequenceKeypoint.new(0.55, rgb(255, 210, 60)),
	ColorSequenceKeypoint.new(0.8, rgb(110, 240, 90)),
	ColorSequenceKeypoint.new(1, rgb(70, 200, 255)),
})

---------------------------------------------------------------------
-- Instance helpers
---------------------------------------------------------------------
local function apply(inst, props)
	if props then
		for k, v in pairs(props) do
			if k ~= "Parent" then
				inst[k] = v
			end
		end
		if props.Parent then
			inst.Parent = props.Parent
		end
	end
	return inst
end

local function create(className, props)
	return apply(Instance.new(className), props)
end

local function merge(...)
	local out = {}
	for _, t in ipairs({ ... }) do
		for k, v in pairs(t) do
			out[k] = v
		end
	end
	return out
end

local function tween(inst, goal, time, style, dir)
	local t = TweenService:Create(
		inst,
		TweenInfo.new(time or 0.15, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

-- Rect from top-left coordinates inside a parent (anchor = centre so
-- UIScale pop animations scale from the middle).
local function rect(x, y, w, h)
	return {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x + w / 2, y + h / 2),
		Size = UDim2.fromOffset(w, h),
	}
end

-- Rect on the root canvas, pinned to a screen edge.
-- h = "L" | "C" | "R", v = "T" | "C" | "B"
local function screenRect(h, v, x, y, w, hgt)
	local cx, cy = x + w / 2, y + hgt / 2
	local px = (h == "L" and UDim.new(0, cx)) or (h == "R" and UDim.new(1, cx - REF_W)) or UDim.new(0.5, cx - REF_W / 2)
	local py = (v == "T" and UDim.new(0, cy)) or (v == "B" and UDim.new(1, cy - REF_H)) or UDim.new(0.5, cy - REF_H / 2)
	return {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(px, py),
		Size = UDim2.fromOffset(w, hgt),
	}
end

-- Outlined bubbly text
local function text(str, props, strokeThickness, strokeColor)
	local l = create("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = FONT,
		Text = str,
		TextColor3 = WHITE,
		TextScaled = true,
		RichText = true,
	})
	create("UIStroke", {
		Thickness = strokeThickness or 3,
		Color = strokeColor or BLACK,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = l,
	})
	return apply(l, props)
end

-- Image if an asset id is set in Config.Icons, emoji otherwise
local function icon(key, props, emojiOverride, imageOverride)
	local id = imageOverride
	if id == nil or id == "" then
		id = Config.Icons[key]
	end
	local inst
	if id and id ~= "" then
		inst = create("ImageLabel", {
			BackgroundTransparency = 1,
			Image = id,
			ScaleType = Enum.ScaleType.Fit,
		})
	else
		inst = create("TextLabel", {
			BackgroundTransparency = 1,
			Text = emojiOverride or Config.Emoji[key] or "?",
			TextScaled = true,
			FontFace = FONT,
			TextColor3 = WHITE,
		})
	end
	return apply(inst, props)
end

-- The glossy, outlined, diagonal-striped box every button/panel uses.
-- top may be a Color3 (with bottom) or a full ColorSequence.
local function fancy(className, props, top, bottom, opts)
	opts = opts or {}
	local f = create(className, {
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	})
	if f:IsA("GuiButton") then
		f.AutoButtonColor = false
	end
	if f:IsA("TextButton") then
		f.Text = ""
	end

	create("UIGradient", {
		Color = typeof(top) == "ColorSequence" and top or ColorSequence.new(top, bottom),
		Rotation = opts.Rotation or 90,
		Parent = f,
	})
	create("UICorner", { CornerRadius = UDim.new(0, opts.Corner or 5), Parent = f })
	create("UIStroke", {
		Thickness = opts.Stroke or 4,
		Color = opts.StrokeColor or BLACK,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = f,
	})

	if not opts.NoShine then
		-- top gloss
		local gloss = create("Frame", {
			Name = "Gloss",
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 0.5),
			Parent = f,
		})
		create("UICorner", { CornerRadius = UDim.new(0, opts.Corner or 5), Parent = gloss })
		create("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new(0.72, 0.95),
			Parent = gloss,
		})
		-- diagonal shine stripes
		local stripes = create("Frame", {
			Name = "Stripes",
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Parent = f,
		})
		create("UICorner", { CornerRadius = UDim.new(0, opts.Corner or 5), Parent = stripes })
		create("UIGradient", { Rotation = -60, Transparency = STRIPES, Parent = stripes })
	end

	-- inner light rim
	local rim = create("Frame", {
		Name = "Rim",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 1, -6),
		Parent = f,
	})
	create("UICorner", { CornerRadius = UDim.new(0, math.max((opts.Corner or 5) - 2, 0)), Parent = rim })
	create("UIStroke", {
		Thickness = 2,
		Color = WHITE,
		Transparency = opts.RimTransparency or 0.45,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = rim,
	})

	return apply(f, props)
end

local function setGradient(box, top, bottom)
	local g = box:FindFirstChildOfClass("UIGradient")
	if g then
		g.Color = typeof(top) == "ColorSequence" and top or ColorSequence.new(top, bottom)
	end
end

-- Hover / press bounce + click callback
local function bind(btn, callback)
	local scale = create("UIScale", { Parent = btn })
	btn.MouseEnter:Connect(function()
		tween(scale, { Scale = 1.06 }, 0.12)
	end)
	btn.MouseLeave:Connect(function()
		tween(scale, { Scale = 1 }, 0.12)
	end)
	btn.MouseButton1Down:Connect(function()
		tween(scale, { Scale = 0.93 }, 0.07)
	end)
	btn.MouseButton1Up:Connect(function()
		tween(scale, { Scale = 1.06 }, 0.1)
	end)
	btn.Activated:Connect(callback)
	return btn
end

-- Tag a monetization element so GlistenClient sweeps a shine across it
local function glisten(obj)
	CollectionService:AddTag(obj, "Glisten")
	return obj
end

local function robuxPrice(parent, amount, props, color)
	local holder = create("Frame", merge({ BackgroundTransparency = 1 }, props))
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 4),
		Parent = holder,
	})
	local h = holder.Size.Y.Offset
	local ic = icon("Robux", {
		Size = UDim2.fromOffset(h * 0.85, h * 0.85),
		LayoutOrder = 1,
		Parent = holder,
	})
	if ic:IsA("ImageLabel") then
		ic.ImageColor3 = color or WHITE
	end
	text(tostring(amount), {
		Name = "Amount",
		Size = UDim2.fromOffset(h * 1.6, h),
		AutomaticSize = Enum.AutomaticSize.X,
		TextScaled = false,
		TextSize = h * 0.95,
		TextColor3 = color or WHITE,
		LayoutOrder = 2,
		Parent = holder,
	}, 3)
	holder.Parent = parent
	return holder
end

local function formatNumber(n)
	n = math.floor(tonumber(n) or 0)
	local s = tostring(math.abs(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return (n < 0 and "-" or "") .. out
end

local SUFFIX = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }
local function abbreviate(n)
	n = tonumber(n) or 0
	if math.abs(n) < 1000 then
		return formatNumber(n)
	end
	local i = 1
	while math.abs(n) >= 1000 and i < #SUFFIX do
		n /= 1000
		i += 1
	end
	local str = math.abs(n) >= 100 and tostring(math.floor(n)) or string.format("%.1f", math.floor(n * 10) / 10)
	return (str:gsub("%.0$", "")) .. SUFFIX[i]
end

local function getStat(name)
	if not name then
		return nil
	end
	local ls = player:FindFirstChild("leaderstats")
	local v = ls and ls:FindFirstChild(name)
	if v and v:IsA("ValueBase") then
		return v.Value
	end
	return player:GetAttribute(name)
end

local function promptProduct(id)
	if not id or id == 0 then
		warn("[SimUI] This button has no Developer Product ID yet - set it in SimUIConfig")
		return
	end
	MarketplaceService:PromptProductPurchase(player, id)
end

local function promptPass(id)
	if not id or id == 0 then
		warn("[SimUI] This button has no Game Pass ID yet - set it in SimUIConfig")
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, id)
end

---------------------------------------------------------------------
-- Root canvas
---------------------------------------------------------------------
local playerGui = player:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("SimulatorUI")
if old then
	old:Destroy()
end

local gui = create("ScreenGui", {
	Name = "SimulatorUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ScreenInsets = Enum.ScreenInsets.None,
	Parent = playerGui,
})
local buttonClicked = create("BindableEvent", { Name = "ButtonClicked", Parent = gui })

-- Hide the game's old HUD so the two UIs don't overlap
if Config.HideOldGuis then
	local StarterGui = game:GetService("StarterGui")
	local keep, extra = {}, {}
	for _, n in ipairs(Config.KeepGuis or {}) do
		keep[n] = true
	end
	for _, n in ipairs(Config.ExtraGuisToHide or {}) do
		extra[n] = true
	end
	local function isOld(g)
		if not g:IsA("ScreenGui") or g == gui or keep[g.Name] then
			return false
		end
		return extra[g.Name] or StarterGui:FindFirstChild(g.Name) ~= nil
	end
	local function hide(g)
		if isOld(g) then
			g.Enabled = false
			g:GetPropertyChangedSignal("Enabled"):Connect(function()
				if g.Enabled then
					g.Enabled = false
				end
			end)
			print("[SimUI] Hid old UI:", g.Name, "- add it to Config.KeepGuis to keep it")
		end
	end
	for _, g in ipairs(playerGui:GetChildren()) do
		hide(g)
	end
	playerGui.ChildAdded:Connect(hide)
end

local root = create("Frame", {
	Name = "Root",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Parent = gui,
})
local rootScale = create("UIScale", { Parent = root })

local function rescale()
	local vp = gui.AbsoluteSize
	if vp.X <= 0 or vp.Y <= 0 then
		return
	end
	local s = math.min(vp.X / REF_W, vp.Y / REF_H)
	rootScale.Scale = s
	root.Size = UDim2.fromOffset(vp.X / s, vp.Y / s)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)
rescale()

---------------------------------------------------------------------
-- Window manager
---------------------------------------------------------------------
local windows = {}
local openName = nil

local function closeWindow()
	if openName and windows[openName] then
		windows[openName].Visible = false
	end
	openName = nil
end

local function openWindow(name)
	if openName == name then
		closeWindow()
		return
	end
	closeWindow()
	local w = windows[name]
	if not w then
		return
	end
	local scale = w:FindFirstChild("PopScale")
	scale.Scale = 0.7
	w.Visible = true
	tween(scale, { Scale = 1 }, 0.28, Enum.EasingStyle.Back)
	openName = name
end

local function clicked(name)
	return function()
		if name == "MyBase" then
			closeWindow()
			Remotes:WaitForChild("GoToBase"):FireServer()
		elseif windows[name] then
			openWindow(name)
		end
		buttonClicked:Fire(name)
	end
end

local applyData -- assigned near the bottom

-- Window shell: header bar with icon, title, close X, and a dark body
local function makeWindow(name, h, v, x, y, w, hgt, headTop, headBottom, iconKey, title)
	local win = create("Frame", merge(screenRect(h, v, x, y, w, hgt), {
		Name = name,
		BackgroundColor3 = rgb(40, 44, 40),
		BackgroundTransparency = 0.15,
		Visible = false,
		ZIndex = 5,
		Parent = root,
	}))
	create("UIScale", { Name = "PopScale", Parent = win })
	create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = win })
	create("UIStroke", { Thickness = 5, Color = BLACK, Parent = win })

	local header = fancy("Frame", merge(rect(0, 0, w, 112), { Name = "Header", Parent = win }), headTop, headBottom, {
		Corner = 4,
	})
	-- darker line under header
	create("Frame", {
		BackgroundColor3 = BLACK,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 5),
		Parent = header,
	})

	icon(iconKey, merge(rect(-22, -22, 130, 130), { Rotation = -12, Parent = win }))
	text(title, merge(rect(120, 14, 600, 86), {
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = win,
	}), 5)

	local close = fancy("TextButton", merge(rect(w - 93, 14, 78, 78), { Name = "Close", Parent = win }),
		rgb(255, 80, 85), rgb(200, 15, 30), { Corner = 6 })
	text("X", merge(rect(8, 4, 62, 66), { Parent = close }), 4)
	bind(close, closeWindow)

	windows[name] = win
	return win, close
end

---------------------------------------------------------------------
-- HUD: top bar
---------------------------------------------------------------------
do
	local shop = fancy("TextButton", merge(screenRect("C", "T", 500, 8, 248, 87), { Name = "TopShop", Parent = root }),
		rgb(255, 95, 120), rgb(215, 20, 45))
	text("Shop", merge(rect(10, 6, 228, 72), { Parent = shop }), 5)
	bind(shop, clicked("Shop"))

	local base = fancy("TextButton", merge(screenRect("C", "T", 760, 8, 315, 119), { Name = "MyBase", Parent = root }),
		rgb(120, 205, 255), rgb(35, 110, 230))
	local baseText = text("My Base", merge(rect(14, 14, 287, 90), { Parent = base }), 5)
	create("UIGradient", {
		Color = ColorSequence.new(WHITE, rgb(255, 190, 240)),
		Rotation = 90,
		Parent = baseText,
	})
	bind(base, clicked("MyBase"))

	local upgrades = fancy("TextButton", merge(screenRect("C", "T", 1085, 8, 248, 87), { Name = "Upgrades", Parent = root }),
		rgb(190, 255, 90), rgb(60, 185, 30))
	local upText = text("Upgrades", merge(rect(10, 8, 228, 68), { Parent = upgrades }), 5)
	create("UIGradient", {
		Color = ColorSequence.new(WHITE, rgb(225, 255, 170)),
		Rotation = 90,
		Parent = upText,
	})
	bind(upgrades, clicked("Upgrades"))
end

---------------------------------------------------------------------
-- HUD: left buttons
---------------------------------------------------------------------
local dailyBadge
do
	local daily = fancy("TextButton", merge(screenRect("L", "C", 24, 308, 306, 90), { Name = "DailyRewards", Parent = root }),
		ColorSequence.new({
			ColorSequenceKeypoint.new(0, rgb(255, 200, 60)),
			ColorSequenceKeypoint.new(0.5, rgb(170, 240, 70)),
			ColorSequenceKeypoint.new(1, rgb(70, 200, 50)),
		}), nil, { Rotation = 0 })
	text("Daily Rewards", merge(rect(10, 12, 286, 64), { Parent = daily }), 4)
	bind(daily, clicked("DailyRewards"))

	dailyBadge = create("Frame", merge(rect(282, -20, 42, 42), {
		Name = "Badge",
		BackgroundColor3 = rgb(235, 30, 45),
		Visible = false,
		Parent = daily,
	}))
	create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dailyBadge })
	create("UIStroke", { Thickness = 3, Color = WHITE, Parent = dailyBadge })
	text("!", merge(rect(4, 2, 34, 36), { Parent = dailyBadge }), 2)

	local tiles = {
		{ "Shop", "Shop", "Basket", 24, 416, rgb(255, 100, 170), rgb(225, 25, 70) },
		{ "Pass", "Pass", "Pass", 182, 416, rgb(255, 235, 90), rgb(255, 165, 20) },
		{ "Rebirth", "Rebirth", "Rebirth", 24, 578, rgb(225, 110, 255), rgb(130, 35, 230) },
		{ "Index", "Index", "Book", 182, 578, rgb(130, 215, 255), rgb(40, 120, 235) },
	}
	for _, t in ipairs(tiles) do
		local name, label, iconKey, x, y, top, bottom = t[1], t[2], t[3], t[4], t[5], t[6], t[7]
		local tile = fancy("TextButton", merge(screenRect("L", "C", x, y, 148, 150), { Name = "Side" .. name, Parent = root }),
			top, bottom)
		icon(iconKey, merge(rect(14, 4, 120, 105), { Parent = tile }))
		text(label, merge(rect(0, 100, 148, 52), { Parent = tile }), 4)
		bind(tile, clicked(name))
	end
end

---------------------------------------------------------------------
-- HUD: bottom-left stats
---------------------------------------------------------------------
local rebirthText, moneyText, friendText, speedText
do
	icon(nil, merge(screenRect("L", "B", 26, 800, 56, 52), { Parent = root }), "⚡")
	speedText = text("0", merge(screenRect("L", "B", 88, 800, 400, 52), {
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = rgb(90, 220, 255),
		Parent = root,
	}), 4)
	icon("Rebirth", merge(screenRect("L", "B", 26, 858, 56, 56), { Parent = root }))
	rebirthText = text("0", merge(screenRect("L", "B", 88, 860, 200, 54), {
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = rgb(255, 50, 60),
		Parent = root,
	}), 4)

	moneyText = text("$0", merge(screenRect("L", "B", 14, 918, 600, 66), {
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 62,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 66),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 1, 918 + 33 - REF_H),
		TextColor3 = rgb(110, 255, 70),
		Parent = root,
	}), 5)
	create("UIGradient", {
		Color = ColorSequence.new(rgb(170, 255, 110), rgb(40, 200, 40)),
		Rotation = 90,
		Parent = moneyText,
	})

	local plus = fancy("TextButton", {
		Name = "BuyCash",
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(50, 50),
		Parent = root,
	}, rgb(150, 255, 90), rgb(40, 185, 30), { Corner = 4 })
	text("+", merge(rect(6, 2, 38, 44), { Parent = plus }), 3)
	bind(plus, clicked("Shop"))
	local function placePlus()
		local w = moneyText.AbsoluteSize.X / math.max(rootScale.Scale, 0.001)
		plus.Position = UDim2.new(0, 14 + w + 14, 1, 918 + 33 - REF_H)
	end
	moneyText:GetPropertyChangedSignal("AbsoluteSize"):Connect(placePlus)
	placePlus()

	friendText = text("Friend Boost: +0%", merge(screenRect("L", "B", 18, 982, 420, 44), {
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = root,
	}), 4)
end

---------------------------------------------------------------------
-- HUD: bottom-centre level bar
---------------------------------------------------------------------
local multText, levelText, xpText, xpFill
do
	multText = text("x1 Multiplier", merge(screenRect("C", "B", 888, 858, 400, 42), {
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = rgb(255, 205, 40),
		Parent = root,
	}), 4)

	local bar = create("Frame", merge(screenRect("C", "B", 548, 902, 738, 48), {
		Name = "LevelBar",
		BackgroundColor3 = rgb(235, 235, 235),
		BackgroundTransparency = 0.25,
		Parent = root,
	}))
	create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = bar })
	create("UIStroke", { Thickness = 4, Color = BLACK, Parent = bar })
	xpFill = create("Frame", {
		Name = "Fill",
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = bar,
	})
	create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = xpFill })
	create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rgb(255, 225, 60)),
			ColorSequenceKeypoint.new(0.5, rgb(255, 160, 30)),
			ColorSequenceKeypoint.new(1, rgb(240, 110, 20)),
		}),
		Rotation = 90,
		Parent = xpFill,
	})
	create("UIGradient", { Rotation = -60, Transparency = STRIPES, Parent = create("Frame", {
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = xpFill,
	}) })
	levelText = text("Level 1", {
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(0.5, -12, 1, -8),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = bar,
	}, 4)
	xpText = text("0/100 XP", {
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.new(0.5, -12, 1, -8),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = bar,
	}, 4)

	local levelButtons = {
		{ 548, 232, rgb(255, 190, 40) },
		{ 802, 230, rgb(90, 190, 255) },
		{ 1054, 232, rgb(240, 90, 255) },
	}
	for i, info in ipairs(levelButtons) do
		local product = Config.LevelProducts[i]
		if product then
			local b = fancy("TextButton", merge(screenRect("C", "B", info[1], 958, info[2], 66), {
				Name = "Levels" .. product.Levels,
				Parent = root,
			}), rgb(170, 255, 90), rgb(50, 190, 30))
			text("+" .. product.Levels .. " Levels", merge(rect(12, 8, info[2] - 24, 50), {
				TextColor3 = info[3],
				Parent = b,
			}), 4)
			glisten(b)
			bind(b, function()
				promptProduct(product.ProductId)
			end)
		end
	end
end

---------------------------------------------------------------------
-- HUD: right side (Starter Pack, X2 Money, X2 Luck, boosts)
---------------------------------------------------------------------
local boostTexts = {}
do
	local starter = create("TextButton", merge(screenRect("R", "C", 1612, 345, 186, 160), {
		Name = "StarterPack",
		BackgroundTransparency = 1,
		Text = "",
		Parent = root,
	}))
	text("Starter Pack", merge(rect(0, 0, 186, 34), { Parent = starter }), 3)
	icon("Gift", merge(rect(33, 30, 120, 100), { Parent = starter }))
	robuxPrice(starter, Config.Shop.StarterPack.Price, rect(43, 118, 100, 40), rgb(130, 255, 80))
	bind(starter, clicked("Shop"))

	local passes = {
		{ "X2Money", "X2 Money", 532 },
		{ "X2Luck", "X2 Luck", 624 },
	}
	for _, p in ipairs(passes) do
		local cfg = Config.GamePasses[p[1]]
		local b = fancy("TextButton", merge(screenRect("R", "C", 1602, p[3], 214, 66), { Name = p[1], Parent = root }),
			ColorSequence.new({
				ColorSequenceKeypoint.new(0, rgb(240, 90, 255)),
				ColorSequenceKeypoint.new(0.5, rgb(160, 230, 80)),
				ColorSequenceKeypoint.new(1, rgb(240, 90, 255)),
			}), nil, { Rotation = 0 })
		text(p[2], merge(rect(8, 4, 198, 54), { Parent = b }), 4)
		robuxPrice(b, cfg.Price, rect(57, 50, 100, 36), rgb(130, 255, 80))
		glisten(b)
		bind(b, function()
			promptPass(cfg.GamePassId)
		end)
	end

	local boosts = {
		{ "Cash", "CashBoost", 1608, "X1", rgb(110, 255, 70) },
		{ "Rebirth", "RebirthBoost", 1686, "X1", rgb(255, 60, 70) },
		{ "Verified", "VerifiedBoost", 1764, "N/A", rgb(80, 170, 255) },
	}
	for _, b in ipairs(boosts) do
		icon(b[1], merge(screenRect("R", "B", b[3], 954, 60, 52), { Parent = root }))
		boostTexts[b[2]] = {
			Label = text(b[4], merge(screenRect("R", "B", b[3] - 10, 996, 80, 32), {
				TextColor3 = b[5],
				Parent = root,
			}), 3),
			Default = b[4],
		}
	end
end

---------------------------------------------------------------------
-- SHOP WINDOW
---------------------------------------------------------------------
local refreshShopPasses = function() end
do
	local win = makeWindow("Shop", "C", "C", 456, 203, 922, 625, rgb(255, 210, 60), rgb(255, 130, 20), "Basket", "Shop")
	local s = Config.Shop

	local scroll = create("ScrollingFrame", {
		Name = "Content",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(18, 128),
		Size = UDim2.fromOffset(890, 485),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = rgb(200, 200, 200),
		Parent = win,
	})
	create("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
	create("UIPadding", {
		PaddingLeft = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		Parent = scroll,
	})

	local function slot(parent, x, y, iconKey, label, emoji)
		local f = fancy("Frame", merge(rect(x, y, 98, 98), { Parent = parent }), rgb(150, 110, 60), rgb(90, 60, 30), {
			Stroke = 3,
			NoShine = true,
			RimTransparency = 0.7,
		})
		icon(iconKey, merge(rect(12, 4, 74, 68), { Parent = f }), emoji)
		text(label, merge(rect(4, 68, 90, 28), { Parent = f }), 3)
		return f
	end

	-- Banner 1: Exclusive crate
	local ex = s.ExclusiveCrate
	local b1 = fancy("Frame", { Name = "ExclusiveCrate", Size = UDim2.fromOffset(868, 272), LayoutOrder = 1, Parent = scroll },
		RAINBOW, nil, { Rotation = 0 })
	icon("Crate", merge(rect(40, 12, 200, 185), { Rotation = -6, Parent = b1 }))
	text("=", merge(rect(250, 100, 50, 60), { Parent = b1 }), 4)
	text(ex.Title, merge(rect(310, 6, 545, 56), { Parent = b1 }), 4)
	text(ex.Label, merge(rect(30, 176, 240, 40), {
		TextColor3 = rgb(255, 200, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = b1,
	}), 3)
	text(ex.SubLabel, merge(rect(30, 212, 260, 44), { TextXAlignment = Enum.TextXAlignment.Left, Parent = b1 }), 3)

	for i, odd in ipairs(ex.Odds) do
		local x = 318 + (i - 1) * 108
		text(odd.Chance, merge(rect(x, 44, 98, 30), { TextColor3 = odd.Color, Parent = b1 }), 3)
		slot(b1, x, 74, "Crate", odd.Name)
	end

	local buyMany = fancy("TextButton", merge(rect(437, 190, 195, 70), { Name = "BuyMany", Parent = b1 }),
		rgb(215, 100, 255), rgb(120, 25, 220))
	robuxPrice(buyMany, ex.BuyMany.Price, rect(20, 6, 155, 42), rgb(110, 255, 70))
	text(ex.BuyMany.Label, merge(rect(20, 46, 155, 22), { Parent = buyMany }), 2)
	if ex.BuyMany.OldPrice then
		local oldPrice = robuxPrice(buyMany, "<s>" .. ex.BuyMany.OldPrice .. "</s>", rect(-14, -16, 70, 26), rgb(255, 40, 60))
		oldPrice.Rotation = -8
	end
	glisten(b1)
	glisten(buyMany)
	bind(buyMany, function()
		promptProduct(ex.BuyMany.ProductId)
	end)

	local buyOne = fancy("TextButton", merge(rect(652, 190, 200, 70), { Name = "BuyOne", Parent = b1 }),
		rgb(180, 255, 90), rgb(55, 190, 30))
	robuxPrice(buyOne, ex.BuyOne.Price, rect(20, 6, 160, 42))
	text(ex.BuyOne.Label, merge(rect(20, 46, 160, 22), { Parent = buyOne }), 2)
	glisten(buyOne)
	bind(buyOne, function()
		promptProduct(ex.BuyOne.ProductId)
	end)

	-- Banner 2: Limited starter pack
	local sp = s.StarterPack
	local b2 = fancy("Frame", { Name = "StarterPack", Size = UDim2.fromOffset(868, 192), LayoutOrder = 2, Parent = scroll },
		ColorSequence.new({
			ColorSequenceKeypoint.new(0, rgb(235, 70, 200)),
			ColorSequenceKeypoint.new(0.5, rgb(170, 60, 240)),
			ColorSequenceKeypoint.new(1, rgb(235, 70, 200)),
		}), nil, { Rotation = 0 })
	icon("Gift", merge(rect(20, 6, 210, 120), { Parent = b2 }))
	icon("Crate", merge(rect(70, 30, 140, 120), { Parent = b2 }))
	text(sp.CrateRarity, merge(rect(30, 112, 200, 40), {
		TextColor3 = rgb(200, 90, 255),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = b2,
	}), 3)
	text(sp.CrateLabel, merge(rect(30, 146, 240, 38), { TextXAlignment = Enum.TextXAlignment.Left, Parent = b2 }), 3)
	text("+", merge(rect(240, 80, 50, 60), { Parent = b2 }), 4)
	text(sp.Title, merge(rect(310, 6, 430, 54), { Parent = b2 }), 4)
	for i, c in ipairs(sp.Contents) do
		local x = 318 + (i - 1) * 110
		text(c.Count, merge(rect(x, 56, 98, 30), { Parent = b2 }), 3)
		slot(b2, x, 86, c.Icon, c.Label)
	end
	text("VALUE!", merge(rect(652, 76, 160, 44), { TextColor3 = rgb(255, 210, 40), Parent = b2 }), 4)
	local buyPack = fancy("TextButton", merge(rect(657, 120, 200, 62), { Name = "BuyStarterPack", Parent = b2 }),
		rgb(180, 255, 90), rgb(55, 190, 30))
	robuxPrice(buyPack, sp.Price, rect(20, 8, 160, 46))
	if sp.OldPrice then
		local oldPrice = robuxPrice(buyPack, "<s>" .. sp.OldPrice .. "</s>", rect(140, -16, 70, 26), rgb(255, 40, 60))
		oldPrice.Rotation = 8
	end
	glisten(b2)
	glisten(buyPack)
	bind(buyPack, function()
		promptProduct(sp.ProductId)
	end)

	local GREEN_TOP, GREEN_BOTTOM = rgb(170, 255, 90), rgb(50, 190, 30)
	local order = 3

	-- Banner 3: skip to next treadmill
	local skip = s.TreadmillSkip
	if skip then
		local b3 = fancy("Frame", { Name = "TreadmillSkip", Size = UDim2.fromOffset(868, 150), LayoutOrder = order,
			Parent = scroll }, ColorSequence.new({
				ColorSequenceKeypoint.new(0, rgb(60, 210, 255)),
				ColorSequenceKeypoint.new(1, rgb(160, 70, 255)),
			}), nil, { Rotation = 0 })
		icon(nil, merge(rect(30, 15, 120, 120), { Parent = b3 }), "🏃")
		text(skip.Title, merge(rect(165, 14, 470, 58), { TextXAlignment = Enum.TextXAlignment.Left, Parent = b3 }), 4)
		text(skip.Description, merge(rect(165, 76, 470, 40), {
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = rgb(235, 240, 255),
			Parent = b3,
		}), 3)
		local btn = fancy("TextButton", merge(rect(652, 40, 200, 70), { Parent = b3 }), GREEN_TOP, GREEN_BOTTOM)
		robuxPrice(btn, skip.Price, rect(20, 10, 160, 50))
		glisten(b3)
		glisten(btn)
		bind(btn, function()
			promptProduct(skip.ProductId)
		end)
	end

	local function divider(title)
		order += 1
		local holder = create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(868, 64), LayoutOrder = order,
			Parent = scroll })
		create("Frame", {
			BackgroundColor3 = rgb(95, 100, 125),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 20, 0.5, 0),
			Size = UDim2.fromOffset(828, 3),
			Parent = holder,
		})
		local pill = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(380, 56),
			BackgroundColor3 = rgb(42, 46, 75),
			Parent = holder,
		})
		create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pill })
		create("UIStroke", { Thickness = 3, Color = BLACK, Parent = pill })
		text(title, merge(rect(24, 7, 332, 42), { Parent = pill }), 3)
	end

	local function cardRow(h)
		order += 1
		local row = create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(868, h), LayoutOrder = order,
			Parent = scroll })
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 14),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = row,
		})
		create("UIPadding", { PaddingTop = UDim.new(0, 10), Parent = row })
		return row
	end

	local BADGES = {
		["Good Value"] = ColorSequence.new(rgb(100, 210, 255), rgb(30, 110, 235)),
		["Great Value"] = ColorSequence.new(rgb(255, 225, 70), rgb(255, 130, 20)),
		["Most Value"] = RAINBOW,
	}

	local function packCard(row, i, pack, top, bottom, emoji, amountText)
		local card = fancy("Frame", { Name = "Pack" .. i, Size = UDim2.fromOffset(202, 262), LayoutOrder = i, Parent = row },
			top, bottom)
		-- light burst
		local glow = create("Frame", merge(rect(31, 40, 140, 120), { BackgroundColor3 = WHITE, BackgroundTransparency = 0.6,
			Parent = card }))
		create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = glow })
		create("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = glow,
		})
		icon(nil, merge(rect(16, 46, 170, 106), { Parent = card }), string.rep(emoji, math.min(i, 3)))
		if pack.Badge then
			local badge = fancy("Frame", merge(rect(10, -10, 182, 44), { Parent = card }),
				BADGES[pack.Badge] or BADGES["Good Value"], nil, { Rotation = 0, Corner = 22, Stroke = 3 })
			text(pack.Badge, merge(rect(10, 5, 162, 34), { Parent = badge }), 3)
		end
		local pill = create("Frame", {
			Position = UDim2.fromOffset(12, 160),
			Size = UDim2.fromOffset(178, 38),
			BackgroundColor3 = rgb(25, 30, 45),
			BackgroundTransparency = 0.3,
			Parent = card,
		})
		create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pill })
		text(amountText, merge(rect(8, 3, 162, 32), { Parent = pill }), 3)
		local btn = fancy("TextButton", merge(rect(12, 204, 178, 50), { Parent = card }), GREEN_TOP, GREEN_BOTTOM)
		robuxPrice(btn, pack.Price, rect(12, 6, 154, 38))
		glisten(card)
		bind(btn, function()
			promptProduct(pack.ProductId)
		end)
	end

	if s.CashPacks and #s.CashPacks > 0 then
		divider("💵 Cash Packs")
		local row = cardRow(272)
		for i, pack in ipairs(s.CashPacks) do
			packCard(row, i, pack, rgb(130, 255, 110), rgb(25, 165, 50), "💵", "+$" .. abbreviate(pack.Amount))
		end
	end
	if s.SpeedPacks and #s.SpeedPacks > 0 then
		divider("⚡ Speed Packs")
		local row = cardRow(272)
		for i, pack in ipairs(s.SpeedPacks) do
			packCard(row, i, pack, rgb(255, 220, 70), rgb(255, 125, 20), "⚡", "+" .. abbreviate(pack.Amount) .. " Speed")
		end
	end

	-- Gamepasses
	local passList = {}
	for key, cfg in pairs(Config.GamePasses) do
		table.insert(passList, { Key = key, Cfg = cfg })
	end
	table.sort(passList, function(a, b)
		return (a.Cfg.Order or 99) < (b.Cfg.Order or 99)
	end)
	local PASS_COLORS = {
		{ rgb(80, 210, 255), rgb(30, 110, 235) },
		{ rgb(200, 120, 255), rgb(110, 40, 225) },
		{ rgb(255, 225, 70), rgb(255, 130, 20) },
		{ rgb(255, 110, 200), rgb(215, 30, 110) },
		{ rgb(130, 255, 120), rgb(30, 165, 60) },
	}
	local passCards = {}
	if #passList > 0 then
		divider("🎟️ Gamepasses")
		local row
		for idx, entry in ipairs(passList) do
			local cfg = entry.Cfg
			if (idx - 1) % 2 == 0 then
				row = cardRow(222)
			end
			local colors = PASS_COLORS[(idx - 1) % #PASS_COLORS + 1]
			local card = fancy("Frame", { Name = entry.Key, Size = UDim2.fromOffset(420, 210), LayoutOrder = idx,
				Parent = row }, colors[1], colors[2], { Rotation = 45 })
			text(cfg.Name or entry.Key, merge(rect(18, 8, 390, 52), { TextXAlignment = Enum.TextXAlignment.Left,
				Parent = card }), 4)
			local circle = create("Frame", merge(rect(18, 66, 124, 124), { BackgroundColor3 = WHITE,
				BackgroundTransparency = 0.6, Parent = card }))
			create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = circle })
			icon(nil, merge(rect(14, 14, 96, 96), { Parent = circle }), cfg.Emoji or "⭐", cfg.Image)
			text(cfg.Description or "", merge(rect(156, 62, 250, 74), { Parent = card }), 3)
			local btn = fancy("TextButton", merge(rect(196, 142, 210, 58), { Parent = card }), GREEN_TOP, GREEN_BOTTOM)
			local price = robuxPrice(btn, cfg.Price, rect(14, 8, 182, 42))
			local owned = text("OWNED", merge(rect(14, 8, 182, 42), { Visible = false, Parent = btn }), 3)
			bind(btn, function()
				if not player:GetAttribute(cfg.Attribute) then
					promptPass(cfg.GamePassId)
				end
			end)
			glisten(card)
			passCards[entry.Key] = { Cfg = cfg, Button = btn, Price = price, Owned = owned }
		end
	end

	refreshShopPasses = function()
		for _, c in pairs(passCards) do
			local has = player:GetAttribute(c.Cfg.Attribute) == true
			c.Price.Visible = not has
			c.Owned.Visible = has
			if has then
				setGradient(c.Button, rgb(220, 220, 220), rgb(130, 130, 130))
			end
		end
	end
end

---------------------------------------------------------------------
-- INDEX WINDOW
---------------------------------------------------------------------
local refreshIndex
do
	local win = makeWindow("Index", "C", "C", 366, 203, 922, 625, rgb(120, 205, 255), rgb(35, 110, 230), "Book", "Index")

	local grid = create("ScrollingFrame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(14, 122),
		Size = UDim2.fromOffset(900, 496),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = rgb(200, 200, 200),
		Parent = win,
	})
	create("UIGridLayout", {
		CellSize = UDim2.fromOffset(200, 200),
		CellPadding = UDim2.fromOffset(25, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	create("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		Parent = grid,
	})

	local selected = Config.Rarities[1].Name
	local discovered = {}
	local catButtons = {}

	local function makeCell(item, order, isFound)
		local cell = fancy("Frame", { Name = item.Name, LayoutOrder = order, Parent = grid },
			rgb(55, 75, 55), rgb(25, 35, 25), { Stroke = 4, NoShine = true, RimTransparency = 0.65 })
		-- light burst behind the icon
		local glow = create("Frame", merge(rect(30, 18, 140, 140), {
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.6,
			Parent = cell,
		}))
		create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = glow })
		create("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.3),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = glow,
		})

		if isFound then
			icon(nil, merge(rect(40, 22, 120, 120), { Parent = cell }), item.Emoji or "⭐", item.Image)
		else
			-- yellow "?" lucky block
			local block = fancy("Frame", merge(rect(48, 28, 104, 104), { Rotation = -8, Parent = cell }),
				rgb(255, 235, 90), rgb(245, 160, 20), { Stroke = 4, StrokeColor = rgb(120, 70, 0), Corner = 10 })
			text("?", merge(rect(14, 6, 76, 92), { Parent = block }), 4, rgb(150, 90, 0))
		end

		local name = item.Name
		if not isFound and not Config.ShowUndiscoveredNames then
			name = "???"
		end
		text(name, merge(rect(8, 148, 184, 42), { Parent = cell }), 3)
	end

	refreshIndex = function(newDiscovered)
		if newDiscovered then
			discovered = newDiscovered
		end
		for _, child in ipairs(grid:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local order = 0
		for _, item in ipairs(Config.Items) do
			if item.Rarity == selected then
				order += 1
				makeCell(item, order, discovered[item.Name] == true)
			end
		end
		for rarityName, btn in pairs(catButtons) do
			local isSel = rarityName == selected
			btn:FindFirstChildOfClass("UIStroke").Color = isSel and WHITE or BLACK
		end
		grid.CanvasPosition = Vector2.zero
	end

	-- category column (sits just right of the window)
	for i, r in ipairs(Config.Rarities) do
		local b = fancy("TextButton", merge(rect(936, 112 + (i - 1) * 83, 258, 70), { Name = r.Name, Parent = win }),
			r.Top, r.Bottom)
		text(r.Name, merge(rect(12, 8, 234, 54), { Parent = b }), 4)
		catButtons[r.Name] = b
		bind(b, function()
			selected = r.Name
			refreshIndex()
		end)
	end

	refreshIndex()
end

---------------------------------------------------------------------
-- DAILY REWARDS WINDOW
---------------------------------------------------------------------
local refreshDaily
do
	local win = makeWindow("DailyRewards", "C", "C", 366, 203, 1104, 625, rgb(120, 205, 255), rgb(35, 110, 230),
		"Calendar", "Daily Rewards")

	local claimAll = fancy("TextButton", merge(rect(749, 16, 245, 72), { Name = "ClaimAll", Parent = win }),
		rgb(255, 215, 60), rgb(240, 130, 15))
	text("CLAIM ALL", merge(rect(14, 10, 217, 52), { Parent = claimAll }), 4)

	local dayStyle = {
		{ rgb(140, 220, 255), rgb(40, 140, 240) },
		{ rgb(140, 220, 255), rgb(40, 140, 240) },
		{ rgb(140, 220, 255), rgb(40, 140, 240) },
		{ rgb(220, 110, 255), rgb(140, 35, 230) },
		{ rgb(220, 110, 255), rgb(140, 35, 230) },
		{ rgb(255, 235, 70), rgb(255, 145, 20) },
	}
	local STATE_STYLE = {
		CLAIMED = { rgb(220, 220, 220), rgb(130, 130, 130) },
		CLAIM = { rgb(150, 255, 90), rgb(40, 190, 30) },
		LOCKED = { rgb(255, 80, 95), rgb(205, 15, 40) },
	}

	local cards = {}
	local snapshot = nil

	local function makeCard(day, x, y, w, h, top, bottom, big)
		local reward = Config.DailyRewards[day] or { Name = "ITEM NAME!" }
		local card = fancy("Frame", merge(rect(x, y, w, h), { Name = "Day" .. day, Parent = win }), top, bottom,
			{ Rotation = big and 45 or 90 })
		text("DAY " .. day, merge(rect(10, big and 12 or 4, w - 20, big and 80 or 50), {
			TextColor3 = big and rgb(255, 225, 60) or WHITE,
			Parent = card,
		}), 4)
		if big then
			icon("Crate", merge(rect(20, 110, w - 40, 190), { Parent = card }), nil, reward.Image)
			text(reward.Name, merge(rect(14, 300, w - 28, 90), { Parent = card }), 4)
		else
			icon("Crate", merge(rect(50, 50, w - 100, 92), { Parent = card }), nil, reward.Image)
			text(reward.Name, merge(rect(10, 128, w - 20, 38), { Parent = card }), 3)
		end
		local btnY = big and 392 or 168
		local btn = fancy("TextButton", merge(rect(26, btnY, w - 52, 54), { Name = "Status", Parent = card }),
			STATE_STYLE.LOCKED[1], STATE_STYLE.LOCKED[2])
		local label = text("LOCKED", merge(rect(10, 6, w - 72, 42), { Parent = btn }), 3)
		cards[day] = { Button = btn, Label = label }
		bind(btn, function()
			if snapshot and label.Text == "CLAIM" then
				local result = Remotes.ClaimDaily:InvokeServer(day)
				if result then
					refreshDaily(result)
				end
			end
		end)
		return card
	end

	for day = 1, 6 do
		local col = (day - 1) % 3
		local row = math.floor((day - 1) / 3)
		local st = dayStyle[day]
		makeCard(day, 27 + col * 266, 138 + row * 234, 252, 222, st[1], st[2], false)
	end
	local day7 = makeCard(7, 824, 138, 252, 456, RAINBOW, nil, true)
	-- "OP" sticker
	text("OP", merge(rect(186, -30, 100, 64), {
		Rotation = 22,
		TextColor3 = rgb(255, 40, 90),
		Parent = day7,
	}), 4, WHITE)

	local function stateFor(data, day)
		if data.Claimed[tostring(day)] then
			return "CLAIMED"
		elseif day <= data.Unlocked then
			return "CLAIM"
		end
		return "LOCKED"
	end

	refreshDaily = function(data)
		snapshot = data
		if not data or not data.Daily then
			return
		end
		local anyClaimable = false
		for day, c in pairs(cards) do
			local state = stateFor(data.Daily, day)
			c.Label.Text = state
			local style = STATE_STYLE[state]
			setGradient(c.Button, style[1], style[2])
			if state == "CLAIM" then
				anyClaimable = true
			end
		end
		dailyBadge.Visible = anyClaimable
		claimAll.Visible = anyClaimable
	end

	bind(claimAll, function()
		local result = Remotes.ClaimDaily:InvokeServer("all")
		if result then
			refreshDaily(result)
		end
	end)
end

---------------------------------------------------------------------
-- Shared row builder for list windows (Upgrades, Passes)
---------------------------------------------------------------------
local function listScroll(win)
	local scroll = create("ScrollingFrame", {
		Name = "Content",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(18, 128),
		Size = UDim2.fromOffset(890, 485),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = rgb(200, 200, 200),
		Parent = win,
	})
	create("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
	create("UIPadding", {
		PaddingLeft = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		Parent = scroll,
	})
	return scroll
end

local function listRow(scroll, order, name, description, emoji, image, top, bottom)
	local row = fancy("Frame", { Name = name, Size = UDim2.fromOffset(864, 120), LayoutOrder = order, Parent = scroll },
		rgb(75, 85, 100), rgb(35, 40, 50), { NoShine = true, RimTransparency = 0.7 })
	local box = fancy("Frame", merge(rect(12, 12, 96, 96), { Parent = row }), top, bottom, { Stroke = 3 })
	icon(nil, merge(rect(10, 8, 76, 80), { Parent = box }), emoji, image)
	text(name, merge(rect(124, 8, 460, 48), { TextXAlignment = Enum.TextXAlignment.Left, Parent = row }), 4)
	text(description or "", merge(rect(124, 56, 460, 32), {
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = rgb(215, 215, 215),
		Parent = row,
	}), 3)
	local sub = text("", merge(rect(124, 88, 460, 26), {
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = rgb(255, 205, 40),
		Parent = row,
	}), 3)
	local btn = fancy("TextButton", merge(rect(618, 24, 228, 72), { Name = "Buy", Parent = row }),
		rgb(170, 255, 90), rgb(50, 190, 30))
	local btnText = text("", merge(rect(12, 8, 204, 56), { Parent = btn }), 4)
	return row, sub, btn, btnText
end

local GREEN = { rgb(170, 255, 90), rgb(50, 190, 30) }
local GRAY = { rgb(220, 220, 220), rgb(130, 130, 130) }

local function flash(label, msg, restore)
	label.Text = msg
	task.delay(1.2, restore)
end

---------------------------------------------------------------------
-- UPGRADES WINDOW
---------------------------------------------------------------------
local refreshUpgrades
do
	local win = makeWindow("Upgrades", "C", "C", 456, 203, 922, 625, rgb(190, 255, 90), rgb(60, 185, 30),
		"Upgrade", "Upgrades")
	local scroll = listScroll(win)
	local rows = {}
	local levels = {}

	refreshUpgrades = function(data)
		if data and data.Upgrades then
			levels = data.Upgrades
		end
		for _, up in ipairs(Config.Upgrades) do
			local r = rows[up.Id]
			local lv = levels[up.Id] or 0
			r.Sub.Text = "Level " .. lv .. " / " .. up.MaxLevel
			if lv >= up.MaxLevel then
				r.Text.Text = "MAX"
				setGradient(r.Button, GRAY[1], GRAY[2])
			else
				r.Text.Text = "$" .. formatNumber(Config.UpgradeCost(up, lv))
				setGradient(r.Button, GREEN[1], GREEN[2])
			end
		end
	end

	for i, up in ipairs(Config.Upgrades) do
		local _, sub, btn, btnText = listRow(scroll, i, up.Name, up.Description, up.Emoji, up.Image,
			rgb(190, 255, 90), rgb(60, 185, 30))
		rows[up.Id] = { Sub = sub, Button = btn, Text = btnText }
		bind(btn, function()
			local data, err = Remotes:WaitForChild("BuyUpgrade"):InvokeServer(up.Id)
			if data then
				applyData(data)
			end
			if err then
				flash(btnText, err, function()
					refreshUpgrades()
				end)
			end
		end)
	end
	refreshUpgrades()
end

---------------------------------------------------------------------
-- PASSES WINDOW
---------------------------------------------------------------------
local refreshPasses
do
	local win = makeWindow("Pass", "C", "C", 456, 203, 922, 625, rgb(255, 235, 90), rgb(255, 160, 20), "Pass", "Passes")
	local scroll = listScroll(win)
	local ordered = {}
	for key, cfg in pairs(Config.GamePasses) do
		table.insert(ordered, { Key = key, Cfg = cfg })
	end
	table.sort(ordered, function(a, b)
		return (a.Cfg.Order or 99) < (b.Cfg.Order or 99)
	end)

	local rows = {}
	for i, entry in ipairs(ordered) do
		local cfg = entry.Cfg
		local _, sub, btn, btnText = listRow(scroll, i, cfg.Name or entry.Key, cfg.Description, cfg.Emoji, cfg.Image,
			rgb(255, 235, 90), rgb(255, 160, 20))
		btnText.Visible = false
		local price = robuxPrice(btn, cfg.Price, rect(20, 12, 188, 48))
		glisten(btn)
		sub.Text = "Game Pass"
		rows[entry.Key] = { Button = btn, Text = btnText, Price = price, Cfg = cfg }
		bind(btn, function()
			if not player:GetAttribute(cfg.Attribute) then
				promptPass(cfg.GamePassId)
			end
		end)
	end

	refreshPasses = function()
		for _, r in pairs(rows) do
			local owned = player:GetAttribute(r.Cfg.Attribute) == true
			r.Price.Visible = not owned
			r.Text.Visible = owned
			r.Text.Text = "OWNED"
			local style = owned and GRAY or GREEN
			setGradient(r.Button, style[1], style[2])
		end
	end
	refreshPasses()
end

---------------------------------------------------------------------
-- REBIRTH WINDOW
---------------------------------------------------------------------
local refreshRebirth
do
	local win = makeWindow("Rebirth", "C", "C", 567, 253, 700, 520, rgb(225, 110, 255), rgb(130, 35, 230),
		"Rebirth", "Rebirth")
	local countText = text("", merge(rect(40, 135, 620, 60), { Parent = win }), 4)
	local costText = text("", merge(rect(40, 205, 620, 56), { TextColor3 = rgb(110, 255, 70), Parent = win }), 4)
	text(Config.Rebirth.RewardText, merge(rect(40, 272, 620, 44), { TextColor3 = rgb(255, 205, 40), Parent = win }), 3)
	text(Config.Rebirth.WarningText, merge(rect(40, 322, 620, 38), { TextColor3 = rgb(255, 90, 100), Parent = win }), 3)

	local btn = fancy("TextButton", merge(rect(200, 395, 300, 90), { Name = "DoRebirth", Parent = win }),
		rgb(225, 110, 255), rgb(130, 35, 230))
	local btnText = text("REBIRTH", merge(rect(14, 10, 272, 70), { Parent = btn }), 4)
	bind(btn, function()
		local ok, err = Remotes:WaitForChild("Rebirth"):InvokeServer()
		if ok then
			flash(btnText, "REBIRTHED!", function()
				btnText.Text = "REBIRTH"
			end)
		elseif err then
			flash(btnText, err, function()
				btnText.Text = "REBIRTH"
			end)
		end
	end)

	refreshRebirth = function()
		local r = getStat(S.Rebirths) or 0
		countText.Text = "Rebirths: " .. formatNumber(r)
		costText.Text = "Cost: $" .. formatNumber(Config.RebirthCost(r))
	end
	refreshRebirth()
end

---------------------------------------------------------------------
-- Data from server
---------------------------------------------------------------------
applyData = function(data)
	if not data then
		return
	end
	refreshDaily(data)
	refreshIndex(data.Discovered or {})
	refreshUpgrades(data)
end

Remotes.DataUpdated.OnClientEvent:Connect(applyData)
task.spawn(function()
	local ok, data = pcall(function()
		return Remotes.GetData:InvokeServer()
	end)
	if ok then
		applyData(data)
	end
end)

---------------------------------------------------------------------
-- Live HUD values
---------------------------------------------------------------------
task.spawn(function()
	while gui.Parent do
		rebirthText.Text = formatNumber(getStat(S.Rebirths) or 0)
		moneyText.Text = "$" .. abbreviate(getStat(S.Currency) or 0)
		speedText.Text = abbreviate(getStat("Speed") or 0) .. " Speed"
		friendText.Text = "Friend Boost: +" .. tostring(getStat(S.FriendBoost) or 0) .. "%"
		multText.Text = "x" .. tostring(getStat(S.Multiplier) or 1) .. " Multiplier"

		local level = getStat(S.Level) or 1
		local xp = getStat(S.XP) or 0
		local xpMax = getStat(S.XPMax) or 100
		levelText.Text = "Level " .. formatNumber(level)
		xpText.Text = formatNumber(xp) .. "/" .. formatNumber(xpMax) .. " XP"
		xpFill.Size = UDim2.fromScale(math.clamp(xp / math.max(xpMax, 1), 0, 1), 1)

		for statKey, info in pairs(boostTexts) do
			local v = getStat(S[statKey])
			info.Label.Text = v and ("X" .. tostring(v)) or info.Default
		end
		refreshRebirth()
		refreshPasses()
		refreshShopPasses()
		task.wait(0.25)
	end
end)

---------------------------------------------------------------------
-- Market plaza pads: SHOP pad opens the shop, SELL pad sells your food
---------------------------------------------------------------------
local toast = text("", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0, 190),
	Size = UDim2.fromOffset(900, 70),
	TextTransparency = 1,
	ZIndex = 50,
	Parent = root,
}, 4)
local toastStroke = toast:FindFirstChildOfClass("UIStroke")
toastStroke.Transparency = 1
local toastId = 0
local function showToast(msg, color)
	toastId += 1
	local id = toastId
	toast.Text = msg
	toast.TextColor3 = color or WHITE
	toast.TextTransparency = 0
	toastStroke.Transparency = 0
	local s = toast:FindFirstChild("PopScale") or create("UIScale", { Name = "PopScale", Parent = toast })
	s.Scale = 0.6
	tween(s, { Scale = 1 }, 0.25, Enum.EasingStyle.Back)
	task.delay(2, function()
		if id == toastId then
			tween(toast, { TextTransparency = 1 }, 0.4)
			tween(toastStroke, { Transparency = 1 }, 0.4)
		end
	end)
end

local onPad = {}
local padAcc = 0
RunService.Heartbeat:Connect(function(dt)
	padAcc += dt
	if padAcc < 0.15 then
		return
	end
	padAcc = 0
	local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end
	for _, tag in ipairs({ "ShopPad", "SellPad" }) do
		for _, pad in ipairs(CollectionService:GetTagged(tag)) do
			if pad:IsA("BasePart") then
				local rel = pad.CFrame:PointToObjectSpace(rootPart.Position)
				local half = pad.Size / 2
				local inside = math.abs(rel.X) <= half.X and math.abs(rel.Z) <= half.Z and math.abs(rel.Y) <= half.Y + 3
				if inside and not onPad[pad] then
					onPad[pad] = true
					if tag == "ShopPad" then
						if openName ~= "Shop" then
							openWindow("Shop")
						end
					else
						task.spawn(function()
							local ok, result = Remotes:WaitForChild("SellFood"):InvokeServer()
							if ok and typeof(result) == "number" then
								showToast("💰 Sold for $" .. abbreviate(result) .. "!", rgb(120, 255, 90))
							elseif typeof(result) == "string" then
								showToast(result, rgb(255, 90, 90))
							end
						end)
					end
				elseif not inside and onPad[pad] then
					onPad[pad] = nil
				end
			end
		end
	end
end)
