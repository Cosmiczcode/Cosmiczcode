--[[
	TreadmillConfig  (ModuleScript -> ReplicatedStorage)

	12 treadmill tiers. Tier 1 is free; each next tier must be bought
	with Cash (in order) and gives more Speed per second while running.
]]

local T = {}

T.Stat = "Speed" -- the stat treadmills train (leaderstats value or Player attribute)
T.CashStat = "Cash" -- what unlocking costs
T.TickSeconds = 1 -- how often Speed is given while running

-- Speed also makes you walk faster: +1 WalkSpeed per 1,000 Speed, max +60
T.BaseWalkSpeed = 16
T.WalkSpeedPerSpeed = 1 / 1000
T.MaxWalkSpeedBonus = 60

T.Tiers = {
	{ Name = "Basic", Skin = "Basic", Price = 0, Gain = 1 },
	{ Name = "Jungle", Skin = "Jungle", Price = 5e3, Gain = 3 },
	{ Name = "Tech", Skin = "Tech", Price = 50e3, Gain = 8 },
	{ Name = "Hacker", Skin = "Hacker", Price = 500e3, Gain = 20 },
	{ Name = "Frost", Skin = "Frost", Price = 5e6, Gain = 50 },
	{ Name = "Toxic", Skin = "Toxic", Price = 50e6, Gain = 120 },
	{ Name = "Candy", Skin = "Candy", Price = 500e6, Gain = 300 },
	{ Name = "Ocean", Skin = "Ocean", Price = 5e9, Gain = 750 },
	{ Name = "Lucky", Skin = "Lucky", Price = 50e9, Gain = 2000 },
	{ Name = "Alien", Skin = "Alien", Price = 500e9, Gain = 5000 },
	{ Name = "Inferno", Skin = "Inferno", Price = 5e12, Gain = 12500 },
	{ Name = "Golden", Skin = "Golden", Price = 50e12, Gain = 30000 },
}

-- Player attributes (set by game passes) that multiply Speed gain
T.Multipliers = {
	{ Attribute = "X2Speed", Mult = 2 },
	{ Attribute = "VIP", Mult = 1.5 },
}
T.AllTreadmillsAttribute = "AllTreadmills" -- game pass: every tier unlocked

local SUFFIX = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }
function T.Format(n)
	n = tonumber(n) or 0
	local neg = n < 0
	n = math.abs(n)
	if n < 1000 then
		return (neg and "-" or "") .. tostring(math.floor(n))
	end
	local i = 1
	while n >= 1000 and i < #SUFFIX do
		n /= 1000
		i += 1
	end
	local s
	if n >= 100 then
		s = tostring(math.floor(n))
	else
		s = string.format("%.1f", math.floor(n * 10) / 10)
		s = (s:gsub("%.0$", ""))
	end
	return (neg and "-" or "") .. s .. SUFFIX[i]
end

return T
