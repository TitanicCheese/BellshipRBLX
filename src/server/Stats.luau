-- Player stats that persist between sessions. Lifetime wins and bells rung show in the player
-- list; the leaderboards use weekly stats (wins, bells rung, best win streak) that reset every
-- Monday at 00:00 UTC.
--
-- Profiles live in a DataStore, and each weekly stat is mirrored to an OrderedDataStore for that
-- week. If DataStores are unavailable (for example in Studio without API access) stats still work
-- for the session; a profile that failed to load is never saved, so nothing is wiped.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Stats = {}

-- The weekly stats shown on the leaderboards. Each is also set as an attribute on the player so
-- the client can show your own score.
Stats.BOARD_STATS = { "WeekWins", "WeekBells", "WeekBestStreak" }

type Profile = {
	Wins: number,
	BellsRung: number,
	BestStreak: number,
	Streak: number,
	Week: number,
	WeekWins: number,
	WeekBells: number,
	WeekBestStreak: number,
	ChairSkin: string, -- id of the equipped chair skin, "" for the regular chair
}
type Entry = { profile: Profile, loaded: boolean, dirty: boolean, leaderstats: Folder, player: Player }

local VERSION = "v1"
local WEEK = 7 * 24 * 60 * 60
local MONDAY = 4 * 24 * 60 * 60 -- the Unix epoch was a Thursday; weeks start on Monday

-- The current week number, and when it ends (Unix time).
function Stats.week(): (number, number)
	local week = (os.time() - MONDAY) // WEEK
	return week, (week + 1) * WEEK + MONDAY
end

local profiles: DataStore? = nil
do
	local ok = pcall(function()
		profiles = DataStoreService:GetDataStore("BellshipStats_" .. VERSION)
	end)
	if not ok then
		profiles = nil
		warn("[Bellship] DataStores unavailable; stats will not be saved")
	end
end

local orderedCache: { [string]: OrderedDataStore } = {}
local function ordered(stat: string, week: number): OrderedDataStore?
	if not profiles then
		return nil
	end
	local name = string.format("Bellship%s_%s_w%d", stat, VERSION, week)
	if not orderedCache[name] then
		local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, name)
		if not ok then
			return nil
		end
		orderedCache[name] = store
	end
	return orderedCache[name]
end

local entries: { [Player]: Entry } = {}
local changed = Instance.new("BindableEvent")
Stats.Changed = changed.Event

local function newProfile(): Profile
	return {
		Wins = 0,
		BellsRung = 0,
		BestStreak = 0,
		Streak = 0,
		Week = Stats.week(),
		WeekWins = 0,
		WeekBells = 0,
		WeekBestStreak = 0,
		ChairSkin = "",
	}
end

-- Starts a fresh week for a profile from an earlier one.
local function rollWeek(profile: Profile)
	local week = Stats.week()
	if profile.Week ~= week then
		profile.Week = week
		profile.WeekWins = 0
		profile.WeekBells = 0
		profile.WeekBestStreak = 0
	end
end

local function refresh(entry: Entry)
	local folder = entry.leaderstats
	local profile = entry.profile;
	(folder:FindFirstChild("Wins") :: IntValue).Value = profile.Wins;
	(folder:FindFirstChild("Bells") :: IntValue).Value = profile.BellsRung
	for _, stat in Stats.BOARD_STATS do
		entry.player:SetAttribute(stat, (profile :: any)[stat])
	end
	entry.player:SetAttribute("ChairSkin", profile.ChairSkin)
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
	local entry: Entry =
		{ profile = newProfile(), loaded = false, dirty = false, leaderstats = folder, player = player }
	entries[player] = entry
	refresh(entry)

	local store = profiles
	if store then
		local ok, data = pcall(function()
			return store:GetAsync(tostring(player.UserId))
		end)
		if ok then
			if typeof(data) == "table" then
				local profile = entry.profile :: any
				local sameWeek = data.Week == profile.Week
				for _, key in { "Wins", "BellsRung", "BestStreak", "Streak" } do
					if typeof(data[key]) == "number" then
						-- Add to anything earned while the load was in flight.
						profile[key] += data[key]
					end
				end
				if sameWeek then
					for _, key in Stats.BOARD_STATS do
						if typeof(data[key]) == "number" then
							profile[key] += data[key]
						end
					end
				end
				-- Keep a skin equipped while loading; otherwise use the saved one.
				if profile.ChairSkin == "" and typeof(data.ChairSkin) == "string" then
					profile.ChairSkin = data.ChairSkin
				end
				profile.BestStreak = math.max(profile.BestStreak, profile.Streak)
				profile.WeekBestStreak = math.max(profile.WeekBestStreak, profile.Streak)
			end
			entry.loaded = true
		else
			warn("[Bellship] could not load stats for", player.Name, data)
		end
	end
	if entries[player] == entry then
		refresh(entry)
		changed:Fire()
	end
end

local function save(player: Player)
	local entry = entries[player]
	local store = profiles
	if not entry or not store or not entry.loaded or not entry.dirty then
		return
	end
	entry.dirty = false
	rollWeek(entry.profile)
	local key = tostring(player.UserId)
	local snapshot = table.clone(entry.profile)
	local ok, err = pcall(function()
		store:SetAsync(key, snapshot, { player.UserId })
		for _, stat in Stats.BOARD_STATS do
			local board = ordered(stat, snapshot.Week)
			if board then
				board:SetAsync(key, (snapshot :: any)[stat])
			end
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
	local profile = entry.profile
	rollWeek(profile)
	change(profile)
	profile.BestStreak = math.max(profile.BestStreak, profile.Streak)
	profile.WeekBestStreak = math.max(profile.WeekBestStreak, profile.Streak)
	entry.dirty = true
	refresh(entry)
	changed:Fire()
end

function Stats.rang(player: Player?)
	update(player, function(profile)
		profile.BellsRung += 1
		profile.WeekBells += 1
	end)
end

function Stats.won(player: Player?)
	update(player, function(profile)
		profile.Wins += 1
		profile.WeekWins += 1
		profile.Streak += 1
	end)
end

function Stats.lost(player: Player?)
	update(player, function(profile)
		profile.Streak = 0
	end)
end

-- The equipped chair skin ("" for the regular chair).
function Stats.chairSkin(player: Player): string
	local entry = entries[player]
	return if entry then entry.profile.ChairSkin else ""
end

function Stats.setChairSkin(player: Player, id: string)
	update(player, function(profile)
		profile.ChairSkin = id
	end)
end

-- This week's values for everyone in the server, so boards update without waiting for a save.
function Stats.online(stat: string): { [number]: { name: string, value: number } }
	local week = Stats.week()
	local result = {}
	for player, entry in entries do
		local value = if entry.profile.Week == week then (entry.profile :: any)[stat] else 0
		result[player.UserId] = { name = player.DisplayName, value = value }
	end
	return result
end

-- This week's saved top 10 for a stat, as { userId, value }. Empty if DataStores are unavailable.
function Stats.top(stat: string): { { userId: number, value: number } }
	local store = ordered(stat, Stats.week())
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

-- For testing in Studio: set a weekly stat for a player directly.
function Stats.debugSet(player: Player, stat: string, value: number)
	update(player, function(profile)
		(profile :: any)[stat] = value
	end)
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
		local week = Stats.week()
		while true do
			task.wait(60)
			-- Save everyone at least every two minutes, and right away when a new week starts.
			local now = Stats.week()
			if now ~= week then
				week = now
				for _, entry in entries do
					rollWeek(entry.profile)
					refresh(entry)
				end
				changed:Fire()
			end
			for player in entries do
				task.spawn(save, player)
			end
		end
	end)
end

return Stats
