-- Everything about cash (dollars), crates and the Rewards Hub that both the server and the client
-- need: what each tab pays, what skins cost and the crate odds.
local RewardsConfig = {}

-- Fill these in once they exist. While 0, the VIP and group tabs say "coming soon".
RewardsConfig.VIP_GAMEPASS_ID = 0
RewardsConfig.GROUP_ID = 0

-- Dollars for playing.
RewardsConfig.CASH_PER_WIN = 50
RewardsConfig.CASH_PER_BELL = 10

-- Dollar price of each skin rarity in the chair shop.
RewardsConfig.SKIN_PRICES = { Common = 1500, Rare = 3000, Epic = 6000, Legendary = 15000 }

RewardsConfig.RARITIES = { "Common", "Rare", "Epic", "Legendary" }
RewardsConfig.RARITY_COLORS = {
	Common = Color3.fromRGB(190, 200, 212),
	Rare = Color3.fromRGB(70, 160, 255),
	Epic = Color3.fromRGB(190, 100, 255),
	Legendary = Color3.fromRGB(255, 196, 40),
}

-- Crates: one per skin kind (chair, bell, board), each giving a random skin of its kind with
-- the odds shown openly in the hub. They open with a simple reveal (no spinning). Open them with
-- dollars, free crates from rewards, or Robux.
-- After PITY opens of a kind in a row without an Epic or Legendary, the next one is guaranteed
-- to be one. A skin you already own gives back half its rarity's shop price in dollars instead.
-- Skins can't be traded or bet; there is no trading at all.
RewardsConfig.CRATES = {
	-- robuxProductId: a developer product for opening with Robux. While 0 there is no Robux
	-- option. Players whose PolicyService says ArePaidRandomItemsRestricted never see it either.
	Chair = {
		name = "Chair Crate",
		icon = "🪑",
		price = 2500,
		robuxProductId = 0,
		color = Color3.fromRGB(230, 120, 60),
	},
	Bell = {
		name = "Bell Crate",
		icon = "🛎️",
		price = 2000,
		robuxProductId = 0,
		color = Color3.fromRGB(80, 170, 255),
	},
	Board = {
		name = "Board Crate",
		icon = "📋",
		price = 2000,
		robuxProductId = 0,
		color = Color3.fromRGB(120, 210, 90),
	},
}
RewardsConfig.CRATE_ODDS = { Common = 60, Rare = 28, Epic = 10, Legendary = 2 }
RewardsConfig.PITY = 10
RewardsConfig.PITY_RARITIES = { "Epic", "Legendary" }

-- Minutes played today (UTC) -> dollars, and sometimes a free crate. Resets every day.
RewardsConfig.PLAYTIME = {
	{ minutes = 5, cash = 300 },
	{ minutes = 10, cash = 300 },
	{ minutes = 15, cash = 300 },
	{ minutes = 20, cash = 300 },
	{ minutes = 25, cash = 300 },
	{ minutes = 30, cash = 500 },
	{ minutes = 45, cash = 500 },
	{ minutes = 60, cash = 1000, crate = "Chair" },
} :: { { minutes: number, cash: number, crate: string? } }

-- One claim per day; the streak goes back to day 1 if you miss a day, and loops after day 7.
RewardsConfig.DAILY = {
	{ cash = 300 },
	{ cash = 300 },
	{ cash = 500 },
	{ cash = 500 },
	{ cash = 750 },
	{ cash = 750 },
	{ cash = 1500, crate = "Bell" },
} :: { { cash: number, crate: string? } }

-- One claim per week (Monday 00:00 UTC, like the leaderboards).
RewardsConfig.WEEKLY = { cash = 2500, crate = "Board" }

-- One claim per day for VIP game pass owners.
RewardsConfig.VIP_DAILY = 1000

-- For each friend who joins you in a server (once per friend).
RewardsConfig.INVITE = 1000

-- Total Robux spent in the game -> dollars, each claimed once.
RewardsConfig.ROBUX = {
	{ robux = 100, cash = 1500 },
	{ robux = 500, cash = 5000 },
	{ robux = 1000, cash = 10000 },
	{ robux = 5000, cash = 40000 },
}

-- Once, for being in the group.
RewardsConfig.GROUP = 1500

-- The hub's tabs, top to bottom.
RewardsConfig.TABS = {
	{ id = "Crates", title = "Crates", color = Color3.fromRGB(230, 70, 90) },
	{ id = "Skins", title = "My Skins", color = Color3.fromRGB(240, 100, 220) },
	{ id = "Playtime", title = "Playtime\nRewards", color = Color3.fromRGB(40, 170, 255) },
	{ id = "Weekly", title = "Weekly\nRewards", color = Color3.fromRGB(160, 90, 255) },
	{ id = "Vip", title = "VIP Daily\nReward", color = Color3.fromRGB(255, 185, 30) },
	{ id = "Daily", title = "Daily\nRewards", color = Color3.fromRGB(60, 210, 90) },
	{ id = "Invite", title = "Invite\nFriends", color = Color3.fromRGB(255, 90, 170) },
	{ id = "Robux", title = "Robux Spent\nRewards", color = Color3.fromRGB(20, 200, 180) },
	{ id = "Group", title = "Like + Join\nGroup Reward", color = Color3.fromRGB(255, 110, 50) },
}

-- Today's number (UTC days since 1970).
function RewardsConfig.day(): number
	return os.time() // 86400
end

-- Dollars like "$1,500".
function RewardsConfig.money(amount: number): string
	local text = tostring(math.floor(amount))
	local grouped = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1,")))
	return "$" .. (string.gsub(grouped, "^,", ""))
end

return RewardsConfig
