--[[
	TreadmillServer  (Script -> ServerScriptService)

	- Saves each player's unlocked treadmill tier + Speed
	- Gives Speed every second while the player is running on a treadmill
	  they've unlocked (checked server-side, so it can't be faked)
	- Unlocks the next tier for Cash
	- Speed makes the player walk faster (see TreadmillConfig)

	Treadmills are Models tagged "Treadmill" with a "Tier" attribute and a
	"Hitbox" part (WorldBuilder.Install() sets these up).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")
local CollectionService = game:GetService("CollectionService")
local StarterPlayer = game:GetService("StarterPlayer")

local TC = require(ReplicatedStorage:WaitForChild("TreadmillConfig"))
local MAX_TIER = #TC.Tiers

local remotes = ReplicatedStorage:FindFirstChild("TreadmillRemotes") or Instance.new("Folder")
remotes.Name = "TreadmillRemotes"
remotes.Parent = ReplicatedStorage
local function remote(className, name)
	local r = remotes:FindFirstChild(name) or Instance.new(className)
	r.Name = name
	r.Parent = remotes
	return r
end
local SetRunning = remote("RemoteEvent", "SetRunning")
local Trained = remote("RemoteEvent", "Trained")
local Unlock = remote("RemoteFunction", "Unlock")

local store
pcall(function()
	store = DataStoreService:GetDataStore("Treadmill_v1")
end)

local sessions = {} -- [player] = { Tier = n, Running = model? }

---------------------------------------------------------------------
-- Stats (leaderstats value if present, Player attribute otherwise)
---------------------------------------------------------------------
local function valueObj(player, name)
	local ls = player:FindFirstChild("leaderstats")
	local v = ls and ls:FindFirstChild(name)
	if v and (v:IsA("IntValue") or v:IsA("NumberValue")) then
		return v
	end
	return nil
end

local function getStat(player, name)
	local v = valueObj(player, name)
	if v then
		return v.Value
	end
	return player:GetAttribute(name) or 0
end

local function setStat(player, name, value)
	local v = valueObj(player, name)
	if v then
		v.Value = value
	else
		player:SetAttribute(name, value)
	end
end

local function effectiveTier(player)
	local s = sessions[player]
	if player:GetAttribute(TC.AllTreadmillsAttribute) then
		return MAX_TIER
	end
	return s and s.Tier or 1
end

local function publishTier(player)
	player:SetAttribute("TreadmillTier", effectiveTier(player))
end

local function applyWalkSpeed(player)
	local speed = getStat(player, TC.Stat)
	local bonus = math.min(speed * TC.WalkSpeedPerSpeed, TC.MaxWalkSpeedBonus)
	player:SetAttribute("TreadmillSpeedBonus", bonus)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		local base = StarterPlayer.CharacterWalkSpeed or TC.BaseWalkSpeed
		hum.WalkSpeed = base + bonus + (player:GetAttribute("WalkSpeedBonus") or 0)
	end
end

local function multiplier(player)
	local m = 1
	for _, mult in ipairs(TC.Multipliers) do
		if player:GetAttribute(mult.Attribute) then
			m *= mult.Mult
		end
	end
	return m
end

---------------------------------------------------------------------
-- Save / load
---------------------------------------------------------------------
local function save(player)
	local s = sessions[player]
	if not s or not store then
		return
	end
	local data = { Tier = s.Tier, Speed = getStat(player, TC.Stat) }
	local ok, err = pcall(function()
		store:SetAsync("u" .. player.UserId, data)
	end)
	if not ok then
		warn("[Treadmill] save failed", err)
	end
end

local function onJoin(player)
	local data
	if store then
		local ok, result = pcall(function()
			return store:GetAsync("u" .. player.UserId)
		end)
		if ok then
			data = result
		end
	end
	data = data or {}
	sessions[player] = { Tier = math.clamp(tonumber(data.Tier) or 1, 1, MAX_TIER), Running = nil }

	-- show Speed on the leaderboard if the game uses leaderstats
	local ls = player:WaitForChild("leaderstats", 5)
	if ls and not ls:FindFirstChild(TC.Stat) then
		local v = Instance.new("NumberValue")
		v.Name = TC.Stat
		v.Parent = ls
	end
	setStat(player, TC.Stat, tonumber(data.Speed) or 0)

	publishTier(player)
	player:GetAttributeChangedSignal(TC.AllTreadmillsAttribute):Connect(function()
		publishTier(player)
	end)
	player.CharacterAdded:Connect(function()
		task.wait(0.3)
		applyWalkSpeed(player)
	end)
	applyWalkSpeed(player)
end

Players.PlayerAdded:Connect(onJoin)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onJoin, p)
end

Players.PlayerRemoving:Connect(function(player)
	save(player)
	sessions[player] = nil
end)

game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(save, p)
	end
	task.wait(3)
end)

task.spawn(function()
	while true do
		task.wait(60)
		for _, p in ipairs(Players:GetPlayers()) do
			task.spawn(save, p)
		end
	end
end)

---------------------------------------------------------------------
-- Running
---------------------------------------------------------------------
local function nearTreadmill(player, model)
	local hit = model:FindFirstChild("Hitbox")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return hit and root and (root.Position - hit.Position).Magnitude < 16
end

SetRunning.OnServerEvent:Connect(function(player, model)
	local s = sessions[player]
	if not s then
		return
	end
	if model == nil then
		s.Running = nil
		return
	end
	if typeof(model) ~= "Instance" or not CollectionService:HasTag(model, "Treadmill") then
		return
	end
	local tier = model:GetAttribute("Tier") or 1
	if tier <= effectiveTier(player) and nearTreadmill(player, model) then
		s.Running = model
	end
end)

task.spawn(function()
	while true do
		task.wait(TC.TickSeconds)
		for player, s in pairs(sessions) do
			local model = s.Running
			if model then
				if model.Parent and nearTreadmill(player, model) then
					local tierInfo = TC.Tiers[model:GetAttribute("Tier") or 1] or TC.Tiers[1]
					local gain = tierInfo.Gain * multiplier(player)
					setStat(player, TC.Stat, getStat(player, TC.Stat) + gain)
					applyWalkSpeed(player)
					Trained:FireClient(player, gain)
				else
					s.Running = nil
				end
			end
		end
	end
end)

---------------------------------------------------------------------
-- Unlocking
---------------------------------------------------------------------
local busy = {}
local function unlockNext(player, free)
	local s = sessions[player]
	if not s then
		return false, "Loading..."
	end
	local nextTier = s.Tier + 1
	if nextTier > MAX_TIER then
		return false, "All unlocked!"
	end
	if not free then
		local price = TC.Tiers[nextTier].Price
		local cash = getStat(player, TC.CashStat)
		if cash < price then
			return false, "Need $" .. TC.Format(price - cash) .. " more"
		end
		setStat(player, TC.CashStat, cash - price)
	end
	s.Tier = nextTier
	publishTier(player)
	task.spawn(save, player)
	return true, TC.Tiers[nextTier].Name .. " unlocked!"
end

Unlock.OnServerInvoke = function(player, tier)
	if busy[player] then
		return false, nil
	end
	local s = sessions[player]
	if not s or tier ~= s.Tier + 1 then
		return false, "Unlock the previous treadmill first"
	end
	busy[player] = true
	local ok, msg = unlockNext(player, false)
	busy[player] = nil
	return ok, msg
end

-- "Skip to next treadmill" developer product (granted by SimUIServer)
task.spawn(function()
	local grant = ServerStorage:WaitForChild("SimUI_GrantReward", 30)
	if grant then
		grant.Event:Connect(function(player, reward)
			if type(reward) == "table" and reward.Type == "Product" and reward.Key == "TreadmillSkip" then
				unlockNext(player, true)
			end
		end)
	end
end)
