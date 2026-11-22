--[[
	SimUIServer  (Script -> ServerScriptService)

	- Saves daily reward progress + discovered Index items (DataStore)
	- Validates and grants daily reward claims
	- Handles Developer Product receipts for the Shop / Level buttons
	- Sets X2Money / X2Luck attributes for game pass owners
	- My Base teleport, Upgrades purchases and Rebirths

	Hooks for your own server scripts (created in ServerStorage):
	  SimUI_DiscoverItem  (BindableEvent)  :Fire(player, "Item Name")
	  SimUI_GrantReward   (BindableEvent)  .Event(player, reward)
	      reward = a DailyRewards[n].Reward table, or for purchases
	      { Type = "Product", Key = "ExclusiveCrate3" | "ExclusiveCrate1" | "StarterPack" }
	      { Type = "Levels", Amount = 5 }
	  SimUI_GetData       (BindableFunction) :Invoke(player) -> data table
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("SimUIConfig"))

---------------------------------------------------------------------
-- Remotes / hooks
---------------------------------------------------------------------
local function make(className, name, parent)
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = parent
	return inst
end

local remotes = make("Folder", "SimUIRemotes", ReplicatedStorage)
local GetData = make("RemoteFunction", "GetData", remotes)
local ClaimDaily = make("RemoteFunction", "ClaimDaily", remotes)
local DataUpdated = make("RemoteEvent", "DataUpdated", remotes)
local GoToBase = make("RemoteEvent", "GoToBase", remotes)
local BuyUpgrade = make("RemoteFunction", "BuyUpgrade", remotes)
local RebirthRemote = make("RemoteFunction", "Rebirth", remotes)
local SellFood = make("RemoteFunction", "SellFood", remotes)

local DiscoverItem = make("BindableEvent", "SimUI_DiscoverItem", ServerStorage)
local GrantReward = make("BindableEvent", "SimUI_GrantReward", ServerStorage)
local GetDataHook = make("BindableFunction", "SimUI_GetData", ServerStorage)
local SellRequested = make("BindableEvent", "SimUI_SellRequested", ServerStorage)

---------------------------------------------------------------------
-- Data
---------------------------------------------------------------------
local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("SimUI_v1")
	end)
	if ok then
		store = result
	else
		warn("[SimUI] DataStore unavailable (enable Studio API access to save in Studio):", result)
	end
end

local sessions = {} -- [player] = data
local DAYS = #Config.DailyRewards

local function defaultData()
	return {
		Daily = { Claimed = {}, Unlocked = 0, LastDay = -1 },
		Discovered = {},
		Upgrades = {},
	}
end

local function today()
	return math.floor(os.time() / 86400)
end

local function allClaimed(daily)
	for d = 1, DAYS do
		if not daily.Claimed[tostring(d)] then
			return false
		end
	end
	return true
end

-- Unlock the next day if this is a new calendar day
local function tickDaily(data)
	local daily = data.Daily
	local now = today()
	if daily.LastDay == now then
		return false
	end
	local missed = daily.LastDay ~= -1 and now - daily.LastDay > 1
	if allClaimed(daily) or (missed and Config.ResetStreakOnMiss) then
		daily.Claimed = {}
		daily.Unlocked = 0
	end
	daily.Unlocked = math.min(daily.Unlocked + 1, DAYS)
	daily.LastDay = now
	return true
end

local function save(player)
	local data = sessions[player]
	if not data or not store then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync("u" .. player.UserId, data)
	end)
	if not ok then
		warn("[SimUI] Save failed for", player.Name, err)
	end
end

local function load(player)
	local data
	if store then
		local ok, result = pcall(function()
			return store:GetAsync("u" .. player.UserId)
		end)
		if ok then
			data = result
		else
			warn("[SimUI] Load failed for", player.Name, result)
		end
	end
	data = data or defaultData()
	data.Daily = data.Daily or defaultData().Daily
	data.Daily.Claimed = data.Daily.Claimed or {}
	data.Discovered = data.Discovered or {}
	data.Upgrades = data.Upgrades or {}
	tickDaily(data)
	sessions[player] = data
	return data
end

local function waitForData(player)
	local t = 0
	while not sessions[player] and player.Parent and t < 15 do
		t += task.wait(0.1)
	end
	return sessions[player]
end

---------------------------------------------------------------------
-- Granting
---------------------------------------------------------------------
local function addStat(player, statName, amount)
	local ls = player:FindFirstChild("leaderstats")
	local v = ls and ls:FindFirstChild(statName)
	if v and (v:IsA("IntValue") or v:IsA("NumberValue")) then
		v.Value += amount
	else
		player:SetAttribute(statName, (player:GetAttribute(statName) or 0) + amount)
	end
end

local function findStat(player, statName)
	local ls = player:FindFirstChild("leaderstats")
	local v = ls and ls:FindFirstChild(statName)
	if v and (v:IsA("IntValue") or v:IsA("NumberValue")) then
		return v
	end
	return nil
end

local function getStat(player, statName)
	local v = findStat(player, statName)
	if v then
		return v.Value
	end
	return player:GetAttribute(statName) or 0
end

local function setStat(player, statName, value)
	local v = findStat(player, statName)
	if v then
		v.Value = value
	else
		player:SetAttribute(statName, value)
	end
end

local function grant(player, reward)
	if reward.Type == "Stat" then
		addStat(player, reward.Stat, reward.Amount)
	elseif reward.Type == "Levels" then
		addStat(player, Config.Stats.Level, reward.Amount)
	end
	GrantReward:Fire(player, reward)
end

---------------------------------------------------------------------
-- Remote handlers
---------------------------------------------------------------------
GetData.OnServerInvoke = function(player)
	local data = waitForData(player)
	if data and tickDaily(data) then
		save(player)
	end
	return data
end

GetDataHook.OnInvoke = function(player)
	return sessions[player]
end

local claimDebounce = {}
ClaimDaily.OnServerInvoke = function(player, which)
	local data = sessions[player]
	if not data or claimDebounce[player] then
		return data
	end
	claimDebounce[player] = true
	tickDaily(data)
	local daily = data.Daily

	local days = {}
	if which == "all" then
		for d = 1, daily.Unlocked do
			table.insert(days, d)
		end
	elseif typeof(which) == "number" and which == math.floor(which) and which >= 1 and which <= daily.Unlocked then
		days = { which }
	end

	local any = false
	for _, d in ipairs(days) do
		local key = tostring(d)
		if not daily.Claimed[key] then
			daily.Claimed[key] = true
			any = true
			local reward = Config.DailyRewards[d] and Config.DailyRewards[d].Reward
			if reward then
				grant(player, reward)
			end
		end
	end
	if any then
		task.spawn(save, player)
	end
	claimDebounce[player] = nil
	return data
end

DiscoverItem.Event:Connect(function(player, itemName)
	local data = sessions[player]
	if data and typeof(itemName) == "string" and not data.Discovered[itemName] then
		data.Discovered[itemName] = true
		DataUpdated:FireClient(player, data)
	end
end)

---------------------------------------------------------------------
-- Purchases
---------------------------------------------------------------------
local products = {}
local function registerProduct(id, info)
	if id and id ~= 0 then
		products[id] = info
	end
end
local shop = Config.Shop
registerProduct(shop.ExclusiveCrate.BuyMany.ProductId, { Type = "Product", Key = shop.ExclusiveCrate.BuyMany.Key })
registerProduct(shop.ExclusiveCrate.BuyOne.ProductId, { Type = "Product", Key = shop.ExclusiveCrate.BuyOne.Key })
registerProduct(shop.StarterPack.ProductId, { Type = "Product", Key = shop.StarterPack.Key })
for _, pack in ipairs(shop.CashPacks or {}) do
	registerProduct(pack.ProductId, { Type = "Stat", Stat = Config.Stats.Currency, Amount = pack.Amount })
end
for _, pack in ipairs(shop.SpeedPacks or {}) do
	registerProduct(pack.ProductId, { Type = "Stat", Stat = "Speed", Amount = pack.Amount })
end
if shop.TreadmillSkip then
	registerProduct(shop.TreadmillSkip.ProductId, { Type = "Product", Key = shop.TreadmillSkip.Key })
end
for _, lp in ipairs(Config.LevelProducts) do
	registerProduct(lp.ProductId, { Type = "Levels", Amount = lp.Levels })
end

if Config.HandleReceipts then
	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		local info = products[receipt.ProductId]
		if not player or not info then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local ok, err = pcall(grant, player, info)
		if not ok then
			warn("[SimUI] Grant failed:", err)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

local function refreshPasses(player)
	for _, pass in pairs(Config.GamePasses) do
		if pass.GamePassId ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.GamePassId)
			end)
			if ok and owns then
				player:SetAttribute(pass.Attribute, true)
			end
		end
	end
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased then
		return
	end
	for _, pass in pairs(Config.GamePasses) do
		if pass.GamePassId == passId then
			player:SetAttribute(pass.Attribute, true)
		end
	end
end)

---------------------------------------------------------------------
-- Upgrades
---------------------------------------------------------------------
local upgradesById = {}
for _, up in ipairs(Config.Upgrades or {}) do
	upgradesById[up.Id] = up
end

local function applyUpgrades(player)
	local data = sessions[player]
	if not data then
		return
	end
	for id, up in pairs(upgradesById) do
		local lv = data.Upgrades[id] or 0
		player:SetAttribute("Upgrade_" .. id, lv)
		player:SetAttribute(id .. "Bonus", lv * up.PerLevel)
	end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		for id, up in pairs(upgradesById) do
			local bonus = (data.Upgrades[id] or 0) * up.PerLevel
			if up.Effect == "WalkSpeed" then
				hum.WalkSpeed = game:GetService("StarterPlayer").CharacterWalkSpeed + bonus
					+ (player:GetAttribute("TreadmillSpeedBonus") or 0)
			elseif up.Effect == "JumpPower" then
				hum.UseJumpPower = true
				hum.JumpPower = game:GetService("StarterPlayer").CharacterJumpPower + bonus
			end
		end
	end
end

local busy = {}
BuyUpgrade.OnServerInvoke = function(player, id)
	local data = sessions[player]
	local up = typeof(id) == "string" and upgradesById[id]
	if not data or not up then
		return data, "Error"
	end
	if busy[player] then
		return data, nil
	end
	busy[player] = true
	local lv = data.Upgrades[id] or 0
	local err = nil
	if lv >= up.MaxLevel then
		err = "MAX"
	else
		local cost = Config.UpgradeCost(up, lv)
		local cash = getStat(player, Config.Stats.Currency)
		if cash < cost then
			err = "Need $" .. math.ceil(cost - cash)
		else
			setStat(player, Config.Stats.Currency, cash - cost)
			data.Upgrades[id] = lv + 1
			applyUpgrades(player)
			GrantReward:Fire(player, { Type = "Upgrade", Id = id, Level = lv + 1 })
			task.spawn(save, player)
		end
	end
	busy[player] = nil
	return data, err
end

---------------------------------------------------------------------
-- Rebirth
---------------------------------------------------------------------
RebirthRemote.OnServerInvoke = function(player)
	if not Config.Rebirth.Enabled then
		GrantReward:Fire(player, { Type = "RebirthRequest" })
		return false, nil
	end
	if busy[player] then
		return false, nil
	end
	busy[player] = true
	local rebirths = getStat(player, Config.Stats.Rebirths)
	local cost = Config.RebirthCost(rebirths)
	local ok, err = false, nil
	if getStat(player, Config.Stats.Currency) < cost then
		err = "Need more Cash!"
	else
		for _, statName in ipairs(Config.Rebirth.ResetStats) do
			setStat(player, statName, 0)
		end
		setStat(player, Config.Stats.Rebirths, rebirths + 1)
		GrantReward:Fire(player, { Type = "Rebirth", Rebirths = rebirths + 1 })
		ok = true
	end
	busy[player] = nil
	return ok, err
end

---------------------------------------------------------------------
-- Sell booth
---------------------------------------------------------------------
local CollectionService = game:GetService("CollectionService")
local lastSell = {}

local function nearPad(player, tag)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	for _, pad in ipairs(CollectionService:GetTagged(tag)) do
		if pad:IsA("BasePart") and (pad.Position - root.Position).Magnitude < 14 then
			return true
		end
	end
	return false
end

SellFood.OnServerInvoke = function(player)
	if lastSell[player] and os.clock() - lastSell[player] < 1 then
		return false, nil
	end
	lastSell[player] = os.clock()
	if not nearPad(player, "SellPad") then
		return false, "Stand on the SELL pad!"
	end
	SellRequested:Fire(player)
	local cfg = Config.Sell or {}
	if cfg.UseBuiltIn == false then
		return true, nil
	end

	local value = 0
	local count = 0
	-- numeric food stat
	if cfg.FoodStat then
		local food = getStat(player, cfg.FoodStat)
		if food > 0 then
			value += food * (cfg.CashPerFood or 1)
			count += food
			setStat(player, cfg.FoodStat, 0)
		end
	end
	-- food tools
	local containers = { player:FindFirstChildOfClass("Backpack"), player.Character }
	for _, container in ipairs(containers) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool") then
					local v = tool:GetAttribute(cfg.ToolValueAttribute or "SellValue")
					if v == nil and cfg.FoodTag and CollectionService:HasTag(tool, cfg.FoodTag) then
						v = cfg.CashPerFood or 1
					end
					if typeof(v) == "number" then
						value += v
						count += 1
						tool:Destroy()
					end
				end
			end
		end
	end

	if count == 0 then
		return false, "You have no food to sell!"
	end
	for attr, mult in pairs(cfg.Multipliers or {}) do
		if player:GetAttribute(attr) then
			value *= mult
		end
	end
	value = math.floor(value)
	addStat(player, Config.Stats.Currency, value)
	GrantReward:Fire(player, { Type = "Sold", Amount = value, Count = count })
	return true, value
end

---------------------------------------------------------------------
-- My Base teleport
---------------------------------------------------------------------
local function ownedBy(obj, player)
	if obj.Name == player.Name or obj.Name == player.Name .. "'s Base" or obj.Name == player.Name .. "Base" then
		return true
	end
	local function matches(v)
		return v == player or v == player.UserId or v == player.Name or v == tostring(player.UserId)
			or v == player.DisplayName and v ~= ""
	end
	for _, key in ipairs(Config.Base.OwnerNames) do
		local attr = obj:GetAttribute(key)
		if attr ~= nil and matches(attr) then
			return true
		end
		local child = obj:FindFirstChild(key)
		if child and child:IsA("ValueBase") and matches(child.Value) then
			return true
		end
	end
	return false
end

local function findBase(player)
	if Config.Base.Find then
		local ok, result = pcall(Config.Base.Find, player)
		if ok and result then
			return result
		end
	end
	for _, folderName in ipairs(Config.Base.FolderNames) do
		local folder = workspace:FindFirstChild(folderName)
		if folder then
			if ownedBy(folder, player) then
				return folder
			end
			for _, base in ipairs(folder:GetChildren()) do
				if ownedBy(base, player) then
					return base
				end
			end
		end
	end
	-- last resort: any model in Workspace with a matching owner tag
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("Model") and obj ~= player.Character and not Players:GetPlayerFromCharacter(obj)
			and ownedBy(obj, player) then
			return obj
		end
	end
	return nil
end

local function toCFrame(target)
	if typeof(target) == "CFrame" then
		return target
	end
	if typeof(target) ~= "Instance" then
		return nil
	end
	for _, partName in ipairs(Config.Base.TeleportPartNames) do
		local p = target:FindFirstChild(partName, true)
		if p and p:IsA("BasePart") then
			return p.CFrame
		end
	end
	if target:IsA("BasePart") then
		return target.CFrame
	end
	if target:IsA("Model") or target:IsA("Folder") then
		local ok, cf = pcall(function()
			if target:IsA("Model") then
				return target:GetPivot()
			end
			local any = target:FindFirstChildWhichIsA("BasePart", true)
			return any and any.CFrame
		end)
		if ok then
			return cf
		end
	end
	return nil
end

local lastTeleport = {}
GoToBase.OnServerEvent:Connect(function(player)
	if lastTeleport[player] and os.clock() - lastTeleport[player] < 1 then
		return
	end
	lastTeleport[player] = os.clock()
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then
		return
	end
	local cf = toCFrame(findBase(player))
	if not cf then
		-- fall back to the player's spawn
		local spawn = player.RespawnLocation or workspace:FindFirstChildWhichIsA("SpawnLocation", true)
		cf = spawn and spawn.CFrame
		warn("[SimUI] Couldn't find " .. player.Name .. "'s base - set Config.Base in SimUIConfig. Sent to spawn.")
	end
	if cf then
		char:PivotTo(CFrame.new(cf.Position + Config.Base.Offset))
	end
end)

---------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------
local function onJoin(player)
	local data = load(player)
	refreshPasses(player)
	applyUpgrades(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		applyUpgrades(player)
	end)
	DataUpdated:FireClient(player, data)
end

Players.PlayerAdded:Connect(onJoin)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onJoin, p)
end

Players.PlayerRemoving:Connect(function(player)
	save(player)
	sessions[player] = nil
	claimDebounce[player] = nil
	busy[player] = nil
	lastTeleport[player] = nil
	lastSell[player] = nil
end)

game:BindToClose(function()
	if RunService:IsStudio() and not store then
		return
	end
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(save, p)
	end
	task.wait(3)
end)
