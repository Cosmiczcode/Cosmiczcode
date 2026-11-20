--[[
	SimUIServer  (Script -> ServerScriptService)

	- Saves daily reward progress + discovered Index items (DataStore)
	- Validates and grants daily reward claims
	- Handles Developer Product receipts for the Shop / Level buttons
	- Sets X2Money / X2Luck attributes for game pass owners

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

local DiscoverItem = make("BindableEvent", "SimUI_DiscoverItem", ServerStorage)
local GrantReward = make("BindableEvent", "SimUI_GrantReward", ServerStorage)
local GetDataHook = make("BindableFunction", "SimUI_GetData", ServerStorage)

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
-- Lifecycle
---------------------------------------------------------------------
local function onJoin(player)
	local data = load(player)
	refreshPasses(player)
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
