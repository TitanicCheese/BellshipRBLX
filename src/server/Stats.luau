-- Player stats that persist between sessions: wins, bells rung, and the best win streak.
-- Profiles live in a DataStore, and each stat is mirrored to an OrderedDataStore for the
-- leaderboards. If DataStores are unavailable (for example in Studio without API access) stats
-- still work for the session; a profile that failed to load is never saved, so nothing is wiped.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Stats = {}

Stats.BOARD_STATS = { "Wins", "BellsRung", "BestStreak" }

type Profile = {
	Wins: number,
	BellsRung: number,
	BestStreak: number,
	Streak: number,
}
type Entry = { profile: Profile, loaded: boolean, dirty: boolean, leaderstats: Folder }

local VERSION = "v1"
local profiles: DataStore?, ordered: { [string]: OrderedDataStore } = nil, {}
do
	local ok = pcall(function()
		profiles = DataStoreService:GetDataStore("BellshipStats_" .. VERSION)
		for _, stat in Stats.BOARD_STATS do
			ordered[stat] = DataStoreService:GetOrderedDataStore("Bellship" .. stat .. "_" .. VERSION)
		end
	end)
	if not ok then
		profiles = nil
		ordered = {}
		warn("[Bellship] DataStores unavailable; stats will not be saved")
	end
end

local entries: { [Player]: Entry } = {}
local changed = Instance.new("BindableEvent")
Stats.Changed = changed.Event

local function newProfile(): Profile
	return { Wins = 0, BellsRung = 0, BestStreak = 0, Streak = 0 }
end

local function refreshLeaderstats(entry: Entry)
	local folder = entry.leaderstats;
	(folder:FindFirstChild("Wins") :: IntValue).Value = entry.profile.Wins;
	(folder:FindFirstChild("Bells") :: IntValue).Value = entry.profile.BellsRung
end

local function load(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	for _, name in { "Wins", "Bells" } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = folder
	end
	folder.Parent = player
	local entry: Entry = { profile = newProfile(), loaded = false, dirty = false, leaderstats = folder }
	entries[player] = entry

	local store = profiles
	if store then
		local ok, data = pcall(function()
			return store:GetAsync(tostring(player.UserId))
		end)
		if ok then
			if typeof(data) == "table" then
				for key, value in entry.profile do
					local saved = (data :: any)[key]
					if typeof(saved) == "number" then
						-- Add to anything earned while the load was in flight.
						(entry.profile :: any)[key] = value + saved
					end
				end
				entry.profile.BestStreak = math.max(entry.profile.BestStreak, entry.profile.Streak)
			end
			entry.loaded = true
		else
			warn("[Bellship] could not load stats for", player.Name, data)
		end
	end
	refreshLeaderstats(entry)
	changed:Fire()
end

local function save(player: Player)
	local entry = entries[player]
	local store = profiles
	if not entry or not store or not entry.loaded or not entry.dirty then
		return
	end
	entry.dirty = false
	local key = tostring(player.UserId)
	local snapshot = table.clone(entry.profile)
	local ok, err = pcall(function()
		store:SetAsync(key, snapshot, { player.UserId })
		for _, stat in Stats.BOARD_STATS do
			ordered[stat]:SetAsync(key, (snapshot :: any)[stat])
		end
	end)
	if not ok then
		entry.dirty = true
		warn("[Bellship] could not save stats for", player.Name, err)
	end
end

local function update(player: Player?, change: (Profile) -> ())
	local entry = player and entries[player]
	if not entry then
		return
	end
	change(entry.profile)
	entry.profile.BestStreak = math.max(entry.profile.BestStreak, entry.profile.Streak)
	entry.dirty = true
	refreshLeaderstats(entry)
	changed:Fire()
end

function Stats.rang(player: Player?)
	update(player, function(profile)
		profile.BellsRung += 1
	end)
end

function Stats.won(player: Player?)
	update(player, function(profile)
		profile.Wins += 1
		profile.Streak += 1
	end)
end

function Stats.lost(player: Player?)
	update(player, function(profile)
		profile.Streak = 0
	end)
end

-- Current values for everyone in the server, so boards update without waiting for a save.
function Stats.online(stat: string): { [number]: { name: string, value: number } }
	local result = {}
	for player, entry in entries do
		result[player.UserId] = { name = player.Name, value = (entry.profile :: any)[stat] }
	end
	return result
end

-- The saved top 10 for a stat, as { userId, value }. Empty if DataStores are unavailable.
function Stats.top(stat: string): { { userId: number, value: number } }
	local store = ordered[stat]
	local result = {}
	if not store then
		return result
	end
	local ok, err = pcall(function()
		local page = store:GetSortedAsync(false, 10):GetCurrentPage()
		for _, item in page do
			local userId = tonumber(item.key)
			if userId and typeof(item.value) == "number" then
				table.insert(result, { userId = userId, value = item.value })
			end
		end
	end)
	if not ok then
		warn("[Bellship] could not read the", stat, "leaderboard:", err)
	end
	return result
end

function Stats.start()
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		entries[player] = nil
		changed:Fire()
	end)
	game:BindToClose(function()
		local pending = 0
		for player in entries do
			pending += 1
			task.spawn(function()
				save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(120)
			for player in entries do
				task.spawn(save, player)
			end
		end
	end)
end

return Stats
