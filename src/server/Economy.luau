-- Dollars, skins, crates and the Rewards Hub: what each player owns and has claimed, saved in
-- its own DataStore. Like Stats, a profile that failed to load is never saved, so nothing is wiped.
--
-- Clients ask for their state, claim rewards, open crates and equip skins through the "Rewards"
-- RemoteFunction; the server pushes fresh state (plus a message, and a crate reveal) through the
-- "RewardsState" RemoteEvent.
--
-- Crates follow a few rules: odds are shown openly, a pity counter guarantees an Epic or better
-- after RewardsConfig.PITY opens, they open with dollars earned in game (Robux is optional), and
-- players whose policy has ArePaidRandomItemsRestricted can't open them with Robux. Skins can't
-- be traded or bet.
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChairSkins = require(script.Parent.ChairSkins)
local RewardsConfig = require(ReplicatedStorage.Shared.RewardsConfig)
local Skins = require(ReplicatedStorage.Shared.Skins)
local Stats = require(script.Parent.Stats)

local Economy = {}

type Data = {
	Cash: number,
	OwnedSkins: { string },
	PlayDay: number, -- the day PlaySeconds and PlayClaimed are for
	PlaySeconds: number,
	PlayClaimed: { number }, -- playtime tiers claimed that day
	DailyDay: number, -- last day the daily reward was claimed
	DailyStreak: number,
	WeeklyWeek: number, -- last week the weekly reward was claimed
	VipDay: number,
	InvitedFriends: { number }, -- friends already rewarded for
	PendingInvites: number, -- friends joined but not claimed yet
	RobuxSpent: number,
	RobuxClaimed: { number },
	GroupClaimed: boolean,
	FreeCrates: { [string]: number }, -- unopened free crates from rewards, per kind
	Pity: { [string]: number }, -- opens of each crate kind since the last Epic or better
	EquippedBell: string, -- "" for the regular one; the chair skin lives in Stats
	EquippedBoard: string,
}
-- restricted: PolicyService says paid random items are restricted for this player.
type Entry = { data: Data, loaded: boolean, dirty: boolean, vip: boolean?, restricted: boolean }

local store: DataStore? = nil
pcall(function()
	store = DataStoreService:GetDataStore("BellshipEconomy_v1")
end)

local entries: { [Player]: Entry } = {}
local stateEvent = Instance.new("RemoteEvent")
stateEvent.Name = "RewardsState"
local rewardsFunction = Instance.new("RemoteFunction")
rewardsFunction.Name = "Rewards"

local function newData(): Data
	return {
		Cash = 0,
		OwnedSkins = {},
		PlayDay = RewardsConfig.day(),
		PlaySeconds = 0,
		PlayClaimed = {},
		DailyDay = 0,
		DailyStreak = 0,
		WeeklyWeek = 0,
		VipDay = 0,
		InvitedFriends = {},
		PendingInvites = 0,
		RobuxSpent = 0,
		RobuxClaimed = {},
		GroupClaimed = false,
		FreeCrates = { Chair = 0, Bell = 0, Board = 0 },
		Pity = { Chair = 0, Bell = 0, Board = 0 },
		EquippedBell = "",
		EquippedBoard = "",
	}
end

-- Starts a new day of playtime.
local function rollDay(data: Data)
	local today = RewardsConfig.day()
	if data.PlayDay ~= today then
		data.PlayDay = today
		data.PlaySeconds = 0
		data.PlayClaimed = {}
	end
end

-- The next daily reward's day in the 7-day streak.
local function nextDaily(data: Data): number
	if data.DailyDay == RewardsConfig.day() - 1 then
		return data.DailyStreak % #RewardsConfig.DAILY + 1
	end
	return 1
end

local function snapshot(player: Player): { [string]: any }?
	local entry = entries[player]
	if not entry then
		return nil
	end
	local data = entry.data
	rollDay(data)
	local today = RewardsConfig.day()
	local week, weekEnds = Stats.week()
	local claimedDaily = data.DailyDay == today
	return {
		cash = data.Cash,
		dayEnds = (today + 1) * 86400,
		weekEnds = weekEnds,
		playSeconds = data.PlaySeconds,
		playClaimed = table.clone(data.PlayClaimed),
		dailyClaimed = claimedDaily,
		-- The streak day you are on: today's (claimed) or the one you can claim next.
		dailyDay = if claimedDaily then data.DailyStreak else nextDaily(data),
		weeklyClaimed = data.WeeklyWeek == week,
		vipConfigured = RewardsConfig.VIP_GAMEPASS_ID ~= 0,
		vipOwned = entry.vip == true,
		vipClaimed = data.VipDay == today,
		invitePending = data.PendingInvites,
		inviteTotal = #data.InvitedFriends,
		robuxSpent = data.RobuxSpent,
		robuxClaimed = table.clone(data.RobuxClaimed),
		groupConfigured = RewardsConfig.GROUP_ID ~= 0,
		groupClaimed = data.GroupClaimed,
		freeCrates = table.clone(data.FreeCrates),
		pity = table.clone(data.Pity),
		-- Robux crates: only when a product exists and paid random items are allowed for you.
		robuxCrates = not entry.restricted,
		owned = table.clone(data.OwnedSkins),
		equipped = { Chair = Stats.chairSkin(player), Bell = data.EquippedBell, Board = data.EquippedBoard },
	}
end

local function push(player: Player, message: string?)
	local entry = entries[player]
	if not entry then
		return
	end
	player:SetAttribute("Cash", entry.data.Cash)
	player:SetAttribute("OwnedSkins", table.concat(entry.data.OwnedSkins, ","))
	player:SetAttribute("EquippedBell", entry.data.EquippedBell)
	player:SetAttribute("EquippedBoard", entry.data.EquippedBoard)
	stateEvent:FireClient(player, snapshot(player), message)
end

local function change(player: Player, apply: (Data) -> ())
	local entry = entries[player]
	if not entry then
		return
	end
	apply(entry.data)
	entry.dirty = true
end

function Economy.cash(player: Player): number
	local entry = entries[player]
	return if entry then entry.data.Cash else 0
end

function Economy.addCash(player: Player?, amount: number)
	if not player or not entries[player] then
		return
	end
	change(player, function(data)
		data.Cash += amount
	end)
	push(player)
end

function Economy.owns(player: Player, skinId: string): boolean
	local entry = entries[player]
	return entry ~= nil and table.find(entry.data.OwnedSkins, skinId) ~= nil
end

-- Buys a skin with dollars. Returns whether it worked, and a message for the player.
function Economy.buy(player: Player, skin: ChairSkins.Skin): (boolean, string)
	local entry = entries[player]
	if not entry then
		return false, "Your data is still loading"
	end
	if Economy.owns(player, skin.id) then
		return true, "You already own " .. skin.name
	end
	local price = RewardsConfig.SKIN_PRICES[skin.rarity]
	if entry.data.Cash < price then
		local message = "You need " .. RewardsConfig.money(price - entry.data.Cash) .. " more"
		push(player, message)
		return false, message
	end
	change(player, function(data)
		data.Cash -= price
		table.insert(data.OwnedSkins, skin.id)
	end)
	push(player, "Bought " .. skin.name .. "!")
	return true, ""
end

-- Records Robux spent, for the Robux Spent Rewards tab.
function Economy.spentRobux(player: Player, amount: number)
	change(player, function(data)
		data.RobuxSpent += amount
	end)
	push(player)
end

local function hasVip(player: Player): boolean
	if RewardsConfig.VIP_GAMEPASS_ID == 0 then
		return false
	end
	local ok, owns = pcall(
		MarketplaceService.UserOwnsGamePassAsync,
		MarketplaceService,
		player.UserId,
		RewardsConfig.VIP_GAMEPASS_ID
	)
	return ok and owns
end

-- Tries to claim a reward; returns a message for the player.
local function claim(player: Player, tab: string, index: number?): string
	local entry = entries[player]
	if not entry then
		return "Your data is still loading"
	end
	local data = entry.data
	rollDay(data)
	local today = RewardsConfig.day()
	local amount = 0
	local crate: string? = nil

	if tab == "Playtime" then
		local tier = index and RewardsConfig.PLAYTIME[index]
		if not tier or table.find(data.PlayClaimed, index :: number) then
			return "Already claimed"
		end
		if data.PlaySeconds < tier.minutes * 60 then
			return "Keep playing to unlock this one"
		end
		table.insert(data.PlayClaimed, index :: number)
		amount = tier.cash
		crate = tier.crate
	elseif tab == "Daily" then
		if data.DailyDay == today then
			return "Come back tomorrow"
		end
		local day = nextDaily(data)
		data.DailyDay = today
		data.DailyStreak = day
		amount = RewardsConfig.DAILY[day].cash
		crate = RewardsConfig.DAILY[day].crate
	elseif tab == "Weekly" then
		local week = Stats.week()
		if data.WeeklyWeek == week then
			return "Come back next week"
		end
		data.WeeklyWeek = week
		amount = RewardsConfig.WEEKLY.cash
		crate = RewardsConfig.WEEKLY.crate
	elseif tab == "Vip" then
		if RewardsConfig.VIP_GAMEPASS_ID == 0 then
			return "VIP is coming soon"
		end
		entry.vip = hasVip(player)
		if not entry.vip then
			return "This reward is for VIP owners"
		end
		if data.VipDay == today then
			return "Come back tomorrow"
		end
		data.VipDay = today
		amount = RewardsConfig.VIP_DAILY
	elseif tab == "Invite" then
		if data.PendingInvites <= 0 then
			return "Invite a friend to earn this"
		end
		amount = RewardsConfig.INVITE * data.PendingInvites
		data.PendingInvites = 0
	elseif tab == "Robux" then
		local tier = index and RewardsConfig.ROBUX[index]
		if not tier or table.find(data.RobuxClaimed, index :: number) then
			return "Already claimed"
		end
		if data.RobuxSpent < tier.robux then
			return "Not unlocked yet"
		end
		table.insert(data.RobuxClaimed, index :: number)
		amount = tier.cash
	elseif tab == "Group" then
		if RewardsConfig.GROUP_ID == 0 then
			return "The group is coming soon"
		end
		if data.GroupClaimed then
			return "Already claimed"
		end
		local ok, inGroup = pcall(player.IsInGroup, player, RewardsConfig.GROUP_ID)
		if not ok or not inGroup then
			return "Join the group first, then claim"
		end
		data.GroupClaimed = true
		amount = RewardsConfig.GROUP
	else
		return "Unknown reward"
	end

	data.Cash += amount
	entry.dirty = true
	if crate and data.FreeCrates[crate] then
		data.FreeCrates[crate] += 1
		return "+" .. RewardsConfig.money(amount) .. " and a free " .. RewardsConfig.CRATES[crate].name .. "!"
	end
	return "+" .. RewardsConfig.money(amount) .. "!"
end

-- Crates -------------------------------------------------------------------------------------

export type Reveal = {
	id: string,
	kind: string,
	name: string,
	rarity: string,
	duplicate: boolean,
	refund: number,
	pity: boolean, -- this one came from the pity guarantee
}

local rng = Random.new()

local function pickRarity(guaranteed: boolean): string
	local pool = if guaranteed then RewardsConfig.PITY_RARITIES else RewardsConfig.RARITIES
	local total = 0
	for _, rarity in pool do
		total += RewardsConfig.CRATE_ODDS[rarity]
	end
	local roll = rng:NextNumber(0, total)
	for _, rarity in pool do
		roll -= RewardsConfig.CRATE_ODDS[rarity]
		if roll <= 0 then
			return rarity
		end
	end
	return pool[#pool]
end

-- Opens one crate of `kind` (already paid for) and gives the skin, or a refund for a duplicate.
local function open(player: Player, kind: string): Reveal?
	local entry = entries[player]
	if not entry then
		return nil
	end
	local data = entry.data
	local guaranteed = data.Pity[kind] >= RewardsConfig.PITY - 1
	local rarity = pickRarity(guaranteed)
	local choices = {}
	for _, skin in Skins.ofKind(kind :: Skins.Kind) do
		if skin.rarity == rarity then
			table.insert(choices, skin)
		end
	end
	if #choices == 0 then
		choices = Skins.ofKind(kind :: Skins.Kind)
	end
	local skin = choices[rng:NextInteger(1, #choices)]
	data.Pity[kind] = if table.find(RewardsConfig.PITY_RARITIES, skin.rarity) then 0 else data.Pity[kind] + 1
	local duplicate = table.find(data.OwnedSkins, skin.id) ~= nil
	local refund = 0
	if duplicate then
		refund = RewardsConfig.SKIN_PRICES[skin.rarity] // 2
		data.Cash += refund
	else
		table.insert(data.OwnedSkins, skin.id)
	end
	entry.dirty = true
	local reveal: Reveal = {
		id = skin.id,
		kind = kind,
		name = skin.name,
		rarity = skin.rarity,
		duplicate = duplicate,
		refund = refund,
		pity = guaranteed,
	}
	stateEvent:FireClient(player, snapshot(player), nil, reveal)
	player:SetAttribute("Cash", data.Cash)
	player:SetAttribute("OwnedSkins", table.concat(data.OwnedSkins, ","))
	return reveal
end

-- Opens a crate with dollars ("cash") or a free crate ("free"); returns a message if it can't.
local function openWith(player: Player, kind: string, how: string): string?
	local entry = entries[player]
	local crate = RewardsConfig.CRATES[kind]
	if not entry or not crate then
		return "Can't open that crate"
	end
	local data = entry.data
	if how == "free" then
		if (data.FreeCrates[kind] or 0) <= 0 then
			return "You have no free " .. crate.name
		end
		data.FreeCrates[kind] -= 1
	elseif how == "cash" then
		if data.Cash < crate.price then
			return "You need " .. RewardsConfig.money(crate.price - data.Cash) .. " more"
		end
		data.Cash -= crate.price
	else
		return "Can't open that crate"
	end
	open(player, kind)
	return nil
end

local equipped = Instance.new("BindableEvent")
-- Fires (player) when someone equips or takes off a skin, so tables can update.
Economy.Equipped = equipped.Event

-- Equips an owned skin, or takes it off if it is already on.
function Economy.equip(player: Player, id: string): string?
	local entry = entries[player]
	local skin = Skins.get(id)
	if not entry or not skin then
		return "Unknown skin"
	end
	if not Economy.owns(player, id) then
		return "You don't own " .. skin.name
	end
	local data = entry.data
	if skin.kind == "Chair" then
		Stats.setChairSkin(player, if Stats.chairSkin(player) == id then "" else id)
	elseif skin.kind == "Bell" then
		data.EquippedBell = if data.EquippedBell == id then "" else id
	else
		data.EquippedBoard = if data.EquippedBoard == id then "" else id
	end
	entry.dirty = true
	equipped:Fire(player)
	return nil
end

function Economy.equippedBell(player: Player?): string
	local entry = player and entries[player]
	return if entry then entry.data.EquippedBell else ""
end

function Economy.equippedBoard(player: Player?): string
	local entry = player and entries[player]
	return if entry then entry.data.EquippedBoard else ""
end

local function load(player: Player)
	local entry: Entry = { data = newData(), loaded = false, dirty = false, restricted = true }
	entries[player] = entry
	local saved = store
	if saved then
		local ok, result = pcall(function()
			return saved:GetAsync(tostring(player.UserId))
		end)
		if ok then
			if typeof(result) == "table" then
				local data = entry.data :: any
				local earned = data.Cash
				for key, value in result do
					if data[key] ~= nil and typeof(value) == typeof(data[key]) then
						data[key] = value
					end
				end
				-- Keep anything earned while the load was in flight.
				data.Cash += earned
				-- Fill in crate kinds added since this profile was saved.
				local fresh = newData()
				for _, key in { "FreeCrates", "Pity" } do
					for kind, value in (fresh :: any)[key] do
						if typeof(data[key][kind]) ~= "number" then
							data[key][kind] = value
						end
					end
				end
			end
			entry.loaded = true
		else
			warn("[Bellship] could not load cash for", player.Name, result)
		end
	end
	if entries[player] ~= entry then
		return
	end
	entry.vip = hasVip(player)
	-- Paid random items (crates for Robux) are off unless the policy check says they're allowed.
	local ok, policy = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	entry.restricted = not ok or policy.ArePaidRandomItemsRestricted ~= false
	push(player)
	equipped:Fire(player)
end

local function save(player: Player)
	local entry = entries[player]
	local saved = store
	if not entry or not saved or not entry.loaded or not entry.dirty then
		return
	end
	entry.dirty = false
	local snapshotData = table.clone(entry.data)
	local ok, err = pcall(function()
		saved:SetAsync(tostring(player.UserId), snapshotData, { player.UserId })
	end)
	if not ok then
		entry.dirty = true
		warn("[Bellship] could not save cash for", player.Name, err)
	end
end

-- Friends joining: everyone already here who is friends with the newcomer earns an invite reward
-- (once per friend).
local function friendJoined(newcomer: Player)
	for _, other in Players:GetPlayers() do
		local entry = entries[other]
		if other ~= newcomer and entry and not table.find(entry.data.InvitedFriends, newcomer.UserId) then
			local ok, friends = pcall(other.IsFriendsWith, other, newcomer.UserId)
			if ok and friends then
				change(other, function(data)
					table.insert(data.InvitedFriends, newcomer.UserId)
					data.PendingInvites += 1
				end)
				push(other, newcomer.DisplayName .. " joined you! Claim your invite reward")
			end
		end
	end
end

function Economy.start(remotes: Folder)
	stateEvent.Parent = remotes
	rewardsFunction.Parent = remotes
	if not store then
		warn("[Bellship] DataStores unavailable; cash will not be saved")
	end
	Players.PlayerAdded:Connect(function(player)
		load(player)
		friendJoined(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		entries[player] = nil
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

	rewardsFunction.OnServerInvoke = function(player: Player, action: unknown, tab: unknown, index: unknown)
		if action == "state" then
			return snapshot(player)
		elseif action == "claim" and typeof(tab) == "string" then
			local message = claim(player, tab, if typeof(index) == "number" then index else nil)
			push(player, message)
			return message
		elseif action == "openCrate" and typeof(tab) == "string" and typeof(index) == "string" then
			local message = openWith(player, tab, index)
			if message then
				push(player, message)
			end
			return message
		elseif action == "equip" and typeof(tab) == "string" then
			local message = Economy.equip(player, tab)
			push(player, message)
			return message
		end
		return nil
	end

	-- Robux spent: game passes bought in game, and developer products. This game has no
	-- developer products yet; when adding some, grant them here before returning PurchaseGranted.
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, passId, Enum.InfoType.GamePass)
		if ok and info and typeof(info.PriceInRobux) == "number" then
			Economy.spentRobux(player, info.PriceInRobux)
		end
		if passId == RewardsConfig.VIP_GAMEPASS_ID and entries[player] then
			entries[player].vip = true
			push(player, "Thanks for getting VIP!")
		end
	end)
	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		local entry = player and entries[player]
		if not player or not entry then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		for kind, crate in RewardsConfig.CRATES do
			if crate.robuxProductId ~= 0 and receipt.ProductId == crate.robuxProductId then
				if entry.restricted then
					-- Should not happen (the button is hidden), but never hand out a paid random
					-- item where it is restricted: give the crate's dollar price instead.
					entry.data.Cash += crate.price
					entry.dirty = true
					push(player, "+" .. RewardsConfig.money(crate.price))
				else
					open(player, kind)
				end
			end
		end
		Economy.spentRobux(player, receipt.CurrencySpent)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- Count playtime, and save everyone every two minutes.
	task.spawn(function()
		local last = os.clock()
		local sinceSave = 0
		while true do
			task.wait(5)
			local elapsed = os.clock() - last
			last = os.clock()
			for player, entry in entries do
				local day = entry.data.PlayDay
				rollDay(entry.data)
				entry.data.PlaySeconds += elapsed
				entry.dirty = true
				if entry.data.PlayDay ~= day then
					push(player) -- a new day: new playtime and daily rewards
				end
			end
			sinceSave += elapsed
			if sinceSave >= 120 then
				sinceSave = 0
				for player in entries do
					task.spawn(save, player)
				end
			end
		end
	end)
end

-- For testing in Studio.
function Economy.debug(player: Player, field: string, value: any)
	change(player, function(data)
		(data :: any)[field] = value
	end)
	push(player)
end

return Economy
