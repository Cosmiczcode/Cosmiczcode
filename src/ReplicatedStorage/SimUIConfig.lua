--[[
	SimUIConfig  (ModuleScript -> ReplicatedStorage)

	Everything you will want to change lives here: item lists, reward
	days, prices, product / game pass IDs, icon images and which
	leaderstats the HUD reads from.
]]

local Config = {}

---------------------------------------------------------------------
-- Icons
-- Paste "rbxassetid://123456" into any of these to use your own
-- uploaded image. While a value is "" the matching emoji is shown.
---------------------------------------------------------------------
Config.Icons = {
	Crate = "",
	MysteryBox = "",
	Book = "",
	Basket = "",
	Pass = "",
	Rebirth = "",
	Calendar = "",
	Gift = "",
	Cash = "",
	Clover = "",
	Shovel = "",
	Verified = "",
	Upgrade = "",
	Robux = "rbxasset://textures/ui/common/robux.png",
}

Config.Emoji = {
	Crate = "📦",
	MysteryBox = "❓",
	Book = "📘",
	Basket = "🧺",
	Pass = "🎫",
	Rebirth = "🔄",
	Calendar = "📅",
	Gift = "🎁",
	Cash = "💵",
	Clover = "🍀",
	Shovel = "🪏",
	Verified = "✅",
	Upgrade = "⏫",
	Robux = "R$",
}

---------------------------------------------------------------------
-- Stats the HUD reads. Each name is looked up in player.leaderstats
-- first, then as an attribute on the Player.
---------------------------------------------------------------------
Config.Stats = {
	Currency = "Cash",
	Rebirths = "Rebirths",
	Level = "Level",
	XP = "XP",
	XPMax = "XPMax", -- XP needed for next level (falls back to 100)
	Multiplier = "Multiplier",
	FriendBoost = "FriendBoost", -- percent number, e.g. 10 -> "+10%"
	CashBoost = "CashBoost", -- bottom-right "X1.1"
	RebirthBoost = "RebirthBoost", -- bottom-right "X1.3"
	VerifiedBoost = "VerifiedBoost", -- bottom-right "N/A"
}

---------------------------------------------------------------------
-- Rarities (Index category buttons, top to bottom)
---------------------------------------------------------------------
Config.Rarities = {
	{ Name = "Common", Top = Color3.fromRGB(240, 240, 240), Bottom = Color3.fromRGB(140, 140, 140) },
	{ Name = "Rare", Top = Color3.fromRGB(110, 215, 255), Bottom = Color3.fromRGB(25, 105, 235) },
	{ Name = "Epic", Top = Color3.fromRGB(215, 100, 255), Bottom = Color3.fromRGB(115, 25, 225) },
	{ Name = "Legendary", Top = Color3.fromRGB(255, 225, 60), Bottom = Color3.fromRGB(255, 120, 15) },
	{ Name = "Mythical", Top = Color3.fromRGB(255, 90, 150), Bottom = Color3.fromRGB(215, 15, 45) },
	{ Name = "Secret", Top = Color3.fromRGB(110, 110, 110), Bottom = Color3.fromRGB(20, 20, 20) },
}

---------------------------------------------------------------------
-- Index items. Image = "rbxassetid://..." (optional), Emoji shown
-- otherwise once the item is discovered. Undiscovered items show the
-- yellow "?" block.
--
-- Mark an item discovered from any server script with:
--   game.ServerStorage.SimUI_DiscoverItem:Fire(player, "Item Name")
---------------------------------------------------------------------
Config.ShowUndiscoveredNames = true -- false = show "???" instead

Config.Items = {
	-- { Name = "Wooden Sword", Rarity = "Common", Image = "", Emoji = "🗡️" },
}

-- Placeholder items so the Index is filled out like the preview.
-- Delete this loop once you've added your real items above.
if #Config.Items == 0 then
	for _, rarity in ipairs(Config.Rarities) do
		for i = 1, 12 do
			table.insert(Config.Items, {
				Name = rarity.Name .. " Item " .. i,
				Rarity = rarity.Name,
				Image = "",
				Emoji = "⭐",
			})
		end
	end
end

---------------------------------------------------------------------
-- Daily rewards (7 days). One new day unlocks per calendar day (UTC)
-- the player logs in. After day 7 is claimed the cycle restarts.
--
-- Reward.Type:
--   "Stat"   -> adds Amount to leaderstats[Stat] (or attribute)
--   "Custom" -> only fires ServerStorage.SimUI_GrantReward(player, reward)
-- Every reward also fires SimUI_GrantReward so you can hook in.
---------------------------------------------------------------------
Config.ResetStreakOnMiss = false -- true = missing a day restarts at Day 1

Config.DailyRewards = {
	{ Name = "ITEM NAME!", Reward = { Type = "Stat", Stat = "Cash", Amount = 500 } },
	{ Name = "ITEM NAME!", Reward = { Type = "Stat", Stat = "Cash", Amount = 1000 } },
	{ Name = "ITEM NAME!", Reward = { Type = "Stat", Stat = "Cash", Amount = 2500 } },
	{ Name = "ITEM NAME!", Reward = { Type = "Stat", Stat = "Cash", Amount = 5000 } },
	{ Name = "ITEM NAME!", Reward = { Type = "Stat", Stat = "Cash", Amount = 10000 } },
	{ Name = "ITEM NAME!", Reward = { Type = "Stat", Stat = "Cash", Amount = 25000 } },
	{ Name = "ITEM NAME!", Reward = { Type = "Custom", Id = "Day7Crate" } },
}

---------------------------------------------------------------------
-- Shop. ProductId = your Developer Product ID (Creator Dashboard ->
-- your experience -> Monetization -> Developer Products).
-- Price / OldPrice are only the numbers displayed.
---------------------------------------------------------------------
Config.Shop = {
	ExclusiveCrate = {
		Title = "Exclusive [NAME] Crate!",
		Label = "Exclusive",
		SubLabel = "[NAME] Crate",
		Odds = {
			{ Name = "Name", Chance = "65%", Color = Color3.fromRGB(255, 255, 255) },
			{ Name = "Name", Chance = "45%", Color = Color3.fromRGB(120, 255, 90) },
			{ Name = "Name", Chance = "15%", Color = Color3.fromRGB(255, 220, 60) },
			{ Name = "Name", Chance = "1%", Color = Color3.fromRGB(110, 200, 255) },
			{ Name = "Name", Chance = "0.01%", Color = Color3.fromRGB(255, 120, 230) },
		},
		BuyMany = { ProductId = 0, Price = 55, OldPrice = 87, Label = "3 Crates", Key = "ExclusiveCrate3" },
		BuyOne = { ProductId = 0, Price = 29, Label = "1 Crate", Key = "ExclusiveCrate1" },
	},
	StarterPack = {
		Title = "Limited Starter Pack!",
		CrateRarity = "Epic",
		CrateLabel = "1 [NAME] Crate",
		Contents = {
			{ Icon = "Cash", Count = "x1", Label = "15 min" },
			{ Icon = "Clover", Count = "x1", Label = "15 min" },
			{ Icon = "Shovel", Count = "x1", Label = "Name" },
		},
		ProductId = 0,
		Price = 19,
		OldPrice = 69,
		Key = "StarterPack",
	},
	TreadmillSkip = {
		Title = "Skip to the next Treadmill!",
		Description = "Instantly unlock your next treadmill tier",
		ProductId = 0,
		Price = 49,
		Key = "TreadmillSkip",
	},
	-- Badge = nil | "Good Value" | "Great Value" | "Most Value"
	CashPacks = {
		{ Amount = 297e6, Price = 24, ProductId = 0 },
		{ Amount = 1.78e9, Price = 59, ProductId = 0, Badge = "Good Value" },
		{ Amount = 3.56e9, Price = 79, ProductId = 0, Badge = "Great Value" },
		{ Amount = 10.7e9, Price = 199, ProductId = 0, Badge = "Most Value" },
	},
	SpeedPacks = {
		{ Amount = 5e3, Price = 29, ProductId = 0 },
		{ Amount = 25e3, Price = 79, ProductId = 0, Badge = "Good Value" },
		{ Amount = 100e3, Price = 199, ProductId = 0, Badge = "Most Value" },
	},
}

-- Game passes: used by the right side X2 buttons and the "Pass" window.
-- Owning one sets the Player attribute named in Attribute to true.
Config.GamePasses = {
	X2Money = {
		Order = 1, GamePassId = 0, Price = 99, Attribute = "X2Money",
		Name = "X2 Money", Description = "Double all money you earn", Emoji = "💵",
	},
	X2Luck = {
		Order = 2, GamePassId = 0, Price = 149, Attribute = "X2Luck",
		Name = "X2 Luck", Description = "Double your luck on every roll", Emoji = "🍀",
	},
	X2Speed = {
		Order = 3, GamePassId = 0, Price = 149, Attribute = "X2Speed",
		Name = "X2 Speed", Description = "Double Speed from every treadmill!", Emoji = "⚡",
	},
	VIP = {
		Order = 4, GamePassId = 0, Price = 299, Attribute = "VIP",
		Name = "VIP", Description = "+50% Speed forever and a VIP tag", Emoji = "👑",
	},
	AllTreadmills = {
		Order = 5, GamePassId = 0, Price = 999, Attribute = "AllTreadmills",
		Name = "All Treadmills", Description = "Unlock all 12 treadmill tiers now!", Emoji = "🏃",
	},
}

---------------------------------------------------------------------
-- Old UI
-- Any ScreenGui that comes from StarterGui is hidden when the new UI
-- loads (popups your scripts create later are left alone). The Output
-- window prints every UI it hides; add a name to KeepGuis to keep it.
---------------------------------------------------------------------
Config.HideOldGuis = true
Config.KeepGuis = { "TouchGui", "Freecam", "BubbleChat", "Chat" }
Config.ExtraGuisToHide = {} -- names of old ScreenGuis made by scripts

---------------------------------------------------------------------
-- My Base button
-- Looks in these Workspace folders for a base owned by the player.
-- A base counts as theirs when it has an attribute or Value child
-- named one of OwnerNames holding the Player, UserId or Name, or when
-- the base itself is named after the player.
---------------------------------------------------------------------
Config.Base = {
	FolderNames = { "Bases", "Plots", "Tycoons", "Tycoon", "Base", "Plot", "Houses" },
	OwnerNames = { "Owner", "OwnerId", "OwnerUserId", "OwnerName", "Player", "PlayerName" },
	TeleportPartNames = { "Spawn", "SpawnPoint", "SpawnLocation", "Teleport", "TeleportPart", "TP", "Floor", "Base" },
	Offset = Vector3.new(0, 4, 0),
	-- Or write your own (server side): return a CFrame, BasePart or Model
	Find = nil, -- function(player) return workspace.Bases[...] end
}

---------------------------------------------------------------------
-- Upgrades window. Bought with the Currency stat and saved.
-- Each sets Player attributes "Upgrade_<Id>" (level) and
-- "<Id>Bonus" (level * PerLevel) for your own scripts to read.
-- Effect "WalkSpeed" / "JumpPower" is applied automatically.
---------------------------------------------------------------------
Config.Upgrades = {
	{ Id = "WalkSpeed", Name = "Walk Speed", Description = "+2 speed per level", Emoji = "👟",
		MaxLevel = 10, BaseCost = 500, CostGrowth = 1.6, PerLevel = 2, Effect = "WalkSpeed" },
	{ Id = "CashMulti", Name = "Cash Multiplier", Description = "+10% money per level", Emoji = "💵",
		MaxLevel = 20, BaseCost = 1000, CostGrowth = 1.5, PerLevel = 0.1 },
	{ Id = "Luck", Name = "Luck", Description = "+5% luck per level", Emoji = "🍀",
		MaxLevel = 10, BaseCost = 2500, CostGrowth = 1.7, PerLevel = 0.05 },
	{ Id = "JumpPower", Name = "Jump Power", Description = "+5 jump per level", Emoji = "🦘",
		MaxLevel = 10, BaseCost = 750, CostGrowth = 1.6, PerLevel = 5, Effect = "JumpPower" },
}

function Config.UpgradeCost(upgrade, level)
	return math.floor(upgrade.BaseCost * upgrade.CostGrowth ^ level)
end

---------------------------------------------------------------------
-- Rebirth window. Set Enabled = false if your game already has its
-- own rebirth system (the button then only fires SimUI_GrantReward
-- with { Type = "RebirthRequest" }).
---------------------------------------------------------------------
Config.Rebirth = {
	Enabled = true,
	BaseCost = 1000000,
	CostGrowth = 2.5,
	ResetStats = { "Cash" }, -- set to 0 on rebirth
	RewardText = "Reward: +1 Rebirth (bigger multiplier!)",
	WarningText = "Resets your Cash",
}

function Config.RebirthCost(rebirths)
	return math.floor(Config.Rebirth.BaseCost * Config.Rebirth.CostGrowth ^ rebirths)
end

-- Bottom "+5 / +10 / +25 Levels" buttons (Developer Product IDs)
Config.LevelProducts = {
	{ Levels = 5, ProductId = 0 },
	{ Levels = 10, ProductId = 0 },
	{ Levels = 25, ProductId = 0 },
}

-- Set false if your game already has its own ProcessReceipt callback
-- (Roblox only allows one). Then grant purchases yourself.
Config.HandleReceipts = true

return Config
