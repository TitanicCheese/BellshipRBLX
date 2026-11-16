-- The Rewards Hub: a gift button and your dollars on the left of the screen, and a big colourful
-- panel with tabs for crates, your skins, and each kind of reward (playtime, weekly, VIP, daily,
-- invites, Robux spent, group). The server decides what can be claimed and what a crate gives;
-- this just shows it. Crates open with a simple reveal, and their odds are listed openly.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")

local RewardsConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RewardsConfig"))
local Skins = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Skins"))

local RewardsHub = {}

local player = Players.LocalPlayer
local money = RewardsConfig.money

local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(24, 16, 40)
local GREEN = Color3.fromRGB(70, 220, 90)
local ORANGE = Color3.fromRGB(255, 120, 20)
local PANEL_W, PANEL_H = 840, 560
local TAB_W = 210

local state: { [string]: any }? = nil
local receivedAt = os.clock()
local activeTab = "Playtime"
local rewardsFunction: RemoteFunction? = nil
local version = 0 -- bumps on every server update
-- Updates for timer texts on the open tab, run every second without rebuilding it.
local tickers: { () -> () } = {}
local function tick(update: () -> ())
	update()
	table.insert(tickers, update)
end

-- UI helpers ---------------------------------------------------------------------------------

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number, contextual: boolean?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = if contextual then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function gradient(parent: Instance, top: Color3, bottom: Color3)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = 90
	g.Parent = parent
end

local function darker(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

local function lighter(color: Color3, amount: number): Color3
	return color:Lerp(WHITE, amount)
end

-- Bold white text with a dark outline, like the reference.
local function text(parent: Instance, value: string, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextColor3 = WHITE
	l.TextScaled = true
	l.Text = value
	for key, v in props do
		if key ~= "StrokeThickness" then -- the outline's thickness, not a TextLabel property
			(l :: any)[key] = v
		end
	end
	stroke(l, INK, props.StrokeThickness or 2, true)
	l.Parent = parent
	return l
end

local function button(parent: Instance, value: string, color: Color3, props: { [string]: any }): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BackgroundColor3 = color
	b.Font = FONT
	b.TextColor3 = WHITE
	b.TextScaled = true
	b.Text = value
	for key, v in props do
		(b :: any)[key] = v
	end
	corner(b, 12)
	gradient(b, WHITE, Color3.fromRGB(200, 200, 200))
	stroke(b, INK, 3)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.18, 0)
	pad.PaddingBottom = UDim.new(0.18, 0)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = b
	local inner = Instance.new("UIStroke")
	inner.Color = INK
	inner.Thickness = 2
	inner.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	inner.Parent = b
	b.Parent = parent
	return b
end

local function dot(parent: Instance): Frame
	local d = Instance.new("Frame")
	d.Name = "Dot"
	d.AnchorPoint = Vector2.new(0.5, 0.5)
	d.Position = UDim2.new(1, -6, 0, 6)
	d.Size = UDim2.fromOffset(20, 20)
	d.BackgroundColor3 = Color3.fromRGB(255, 40, 50)
	d.ZIndex = 5
	d.Visible = false
	d.Parent = parent
	corner(d, 10)
	stroke(d, WHITE, 2)
	return d
end

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h, m, s = seconds // 3600, seconds % 3600 // 60, seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

local function untilTime(timestamp: number): string
	local left = math.max(0, timestamp - workspace:GetServerTimeNow())
	if left >= 86400 then
		return string.format("%dd %dh", left // 86400, left % 86400 // 3600)
	end
	return clock(left)
end

-- Seconds played today, counting up between server updates.
local function playSeconds(): number
	return if state then state.playSeconds + (os.clock() - receivedAt) else 0
end

-- Screen ----------------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "RewardsHub"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 5

-- Left side: your dollars and the gift button.
local side = Instance.new("Frame")
side.BackgroundTransparency = 1
side.AnchorPoint = Vector2.new(0, 0.5)
side.Position = UDim2.new(0, 14, 0.5, 0)
side.Size = UDim2.fromOffset(170, 190)
side.Parent = gui

local cashPill = Instance.new("Frame")
cashPill.Size = UDim2.fromOffset(170, 46)
cashPill.BackgroundColor3 = Color3.fromRGB(60, 200, 80)
cashPill.Parent = side
corner(cashPill, 23)
gradient(cashPill, Color3.fromRGB(120, 255, 120), Color3.fromRGB(40, 170, 60))
stroke(cashPill, INK, 3)
local cashLabel = text(cashPill, "$0", {
	Position = UDim2.fromOffset(12, 6),
	Size = UDim2.new(1, -24, 1, -12),
	StrokeThickness = 2.5,
})

local openButton = Instance.new("TextButton")
openButton.Position = UDim2.fromOffset(25, 60)
openButton.Size = UDim2.fromOffset(120, 120)
openButton.BackgroundColor3 = ORANGE
openButton.Text = ""
openButton.AutoButtonColor = true
openButton.Parent = side
corner(openButton, 24)
gradient(openButton, Color3.fromRGB(255, 200, 70), Color3.fromRGB(255, 90, 20))
stroke(openButton, INK, 4)
text(openButton, "🎁", { Position = UDim2.fromOffset(20, 8), Size = UDim2.fromOffset(80, 70) })
text(openButton, "Rewards", {
	Position = UDim2.fromOffset(6, 80),
	Size = UDim2.fromOffset(108, 32),
	StrokeThickness = 2.5,
})
local openDot = dot(openButton)
openDot.Size = UDim2.fromOffset(28, 28)
corner(openDot, 14)

-- The hub panel.
local holder = Instance.new("Frame")
holder.AnchorPoint = Vector2.new(0.5, 0.5)
holder.Position = UDim2.fromScale(0.5, 0.53)
holder.Size = UDim2.fromOffset(PANEL_W, PANEL_H + 70)
holder.BackgroundTransparency = 1
holder.Visible = false
holder.Parent = gui
local uiScale = Instance.new("UIScale")
uiScale.Parent = holder

local panel = Instance.new("Frame")
panel.Position = UDim2.fromOffset(0, 70)
panel.Size = UDim2.fromOffset(PANEL_W, PANEL_H)
panel.BackgroundColor3 = WHITE
panel.Parent = holder
corner(panel, 22)
local panelGradient = Instance.new("UIGradient")
panelGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(90, 40, 170)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 50, 160)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 90, 170)),
})
panelGradient.Rotation = 35
panelGradient.Parent = panel
stroke(panel, INK, 5)

local title = text(holder, "REWARDS HUB 🎁", {
	Position = UDim2.fromOffset(10, 0),
	Size = UDim2.fromOffset(560, 84),
	TextColor3 = ORANGE,
	TextXAlignment = Enum.TextXAlignment.Left,
	StrokeThickness = 6,
	ZIndex = 3,
})
local titleGradient = Instance.new("UIGradient")
titleGradient.Color = ColorSequence.new(Color3.fromRGB(255, 220, 60), Color3.fromRGB(255, 90, 20))
titleGradient.Rotation = 90
titleGradient.Parent = title

local close = button(holder, "X", Color3.fromRGB(240, 50, 60), {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromOffset(PANEL_W - 6, 76),
	Size = UDim2.fromOffset(56, 56),
	ZIndex = 4,
})

-- Tabs down the left.
local tabList = Instance.new("Frame")
tabList.BackgroundTransparency = 1
tabList.Position = UDim2.fromOffset(18, 18)
tabList.Size = UDim2.fromOffset(TAB_W, PANEL_H - 36)
tabList.Parent = panel
local tabLayout = Instance.new("UIListLayout")
tabLayout.Padding = UDim.new(0, 6)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabList

-- The content on the right.
local content = Instance.new("Frame")
content.BackgroundColor3 = Color3.fromRGB(16, 14, 40)
content.BackgroundTransparency = 0.35
content.Position = UDim2.fromOffset(TAB_W + 34, 18)
content.Size = UDim2.fromOffset(PANEL_W - TAB_W - 52, PANEL_H - 36)
content.Parent = panel
corner(content, 16)
local CONTENT_W = PANEL_W - TAB_W - 52

local header = text(content, "", {
	Position = UDim2.fromOffset(16, 10),
	Size = UDim2.fromOffset(CONTENT_W - 32, 44),
	TextColor3 = Color3.fromRGB(120, 255, 110),
	StrokeThickness = 3,
})

local scroll = Instance.new("ScrollingFrame")
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.Position = UDim2.fromOffset(10, 62)
scroll.Size = UDim2.fromOffset(CONTENT_W - 20, PANEL_H - 36 - 72)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new()
scroll.ScrollBarThickness = 8
scroll.ScrollBarImageColor3 = WHITE
scroll.Parent = content
local ROW_W = CONTENT_W - 40

local function clear()
	for _, child in scroll:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 10)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.Parent = scroll

local toast = text(gui, "", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 70),
	Size = UDim2.fromOffset(600, 50),
	TextColor3 = Color3.fromRGB(255, 240, 120),
	StrokeThickness = 3,
	Visible = false,
	ZIndex = 10,
})
local toastScale = Instance.new("UIScale")
toastScale.Parent = toast
local toastToken = 0
local function showToast(message: string)
	toastToken += 1
	local token = toastToken
	toast.Text = message
	toast.Visible = true
	toastScale.Scale = 0.5
	TweenService:Create(toastScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(2.5, function()
		if toastToken == token then
			toast.Visible = false
		end
	end)
end

-- The crate reveal: a card that pops up with what you got. No spinning, no flashing.
local reveal = Instance.new("Frame")
reveal.AnchorPoint = Vector2.new(0.5, 0.5)
reveal.Position = UDim2.fromScale(0.5, 0.5)
reveal.Size = UDim2.fromOffset(380, 330)
reveal.BackgroundColor3 = WHITE
reveal.Visible = false
reveal.ZIndex = 20
reveal.Parent = gui
corner(reveal, 22)
stroke(reveal, INK, 5)
local revealGradient = Instance.new("UIGradient")
revealGradient.Rotation = 90
revealGradient.Parent = reveal
local revealScale = Instance.new("UIScale")
revealScale.Parent = reveal
local revealCrate =
	text(reveal, "", { Position = UDim2.fromOffset(20, 14), Size = UDim2.fromOffset(340, 34), ZIndex = 21 })
local revealIcon =
	text(reveal, "", { Position = UDim2.fromOffset(140, 56), Size = UDim2.fromOffset(100, 90), ZIndex = 21 })
local revealName = text(reveal, "", {
	Position = UDim2.fromOffset(20, 150),
	Size = UDim2.fromOffset(340, 44),
	StrokeThickness = 3,
	ZIndex = 21,
})
local revealRarity =
	text(reveal, "", { Position = UDim2.fromOffset(20, 196), Size = UDim2.fromOffset(340, 30), ZIndex = 21 })
local revealNote = text(reveal, "", {
	Position = UDim2.fromOffset(20, 228),
	Size = UDim2.fromOffset(340, 26),
	TextColor3 = Color3.fromRGB(255, 240, 160),
	ZIndex = 21,
})
local revealOk = button(reveal, "Nice!", Color3.fromRGB(60, 210, 80), {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 262),
	Size = UDim2.fromOffset(180, 52),
	ZIndex = 21,
})
revealOk.Activated:Connect(function()
	reveal.Visible = false
end)

local function showReveal(info: { [string]: any })
	local crate = RewardsConfig.CRATES[info.kind]
	local color = RewardsConfig.RARITY_COLORS[info.rarity] or WHITE
	if not crate then
		return
	end
	revealGradient.Color = ColorSequence.new(lighter(crate.color, 0.2), darker(crate.color, 0.45))
	revealCrate.Text = crate.name
	revealIcon.Text = Skins.KIND_INFO[info.kind].icon
	revealName.Text = info.name
	revealName.TextColor3 = lighter(color, 0.3)
	revealRarity.Text = info.rarity .. (if info.pity then " · pity guarantee!" else "")
	revealRarity.TextColor3 = lighter(color, 0.3)
	revealNote.Text = if info.duplicate then "Already owned: +" .. money(info.refund) else "New! Equip it in My Skins"
	reveal.Visible = true
	revealScale.Scale = 0.6
	TweenService:Create(revealScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

-- Rows ----------------------------------------------------------------------------------------

local order = 0
local function row(height: number, color: Color3): Frame
	order += 1
	local r = Instance.new("Frame")
	r.LayoutOrder = order
	r.Size = UDim2.fromOffset(ROW_W, height)
	r.BackgroundColor3 = color
	r.BackgroundTransparency = 0.15
	r.Parent = scroll
	corner(r, 14)
	gradient(r, lighter(color, 0.15), darker(color, 0.25))
	stroke(r, INK, 3)
	return r
end

-- A green dollar tile: big "$" and "+$300".
local function cashTile(parent: Instance, amount: number, x: number, size: number)
	local tile = Instance.new("Frame")
	tile.Position = UDim2.fromOffset(x, 0)
	tile.AnchorPoint = Vector2.new(0, 0.5)
	tile.Position = UDim2.new(0, x, 0.5, 0)
	tile.Size = UDim2.fromOffset(size, size)
	tile.BackgroundColor3 = GREEN
	tile.Parent = parent
	corner(tile, 12)
	gradient(tile, Color3.fromRGB(140, 255, 120), Color3.fromRGB(30, 170, 60))
	stroke(tile, INK, 3)
	text(tile, "💵", { Position = UDim2.fromScale(0.15, 0.06), Size = UDim2.fromScale(0.7, 0.55) })
	text(tile, "+" .. money(amount), {
		Position = UDim2.fromScale(0.04, 0.62),
		Size = UDim2.fromScale(0.92, 0.32),
		StrokeThickness = 2.5,
	})
end

-- A free crate tile, in the crate's colour.
local function crateTile(parent: Instance, kind: string, x: number, size: number)
	local crate = RewardsConfig.CRATES[kind]
	local tile = Instance.new("Frame")
	tile.AnchorPoint = Vector2.new(0, 0.5)
	tile.Position = UDim2.new(0, x, 0.5, 0)
	tile.Size = UDim2.fromOffset(size, size)
	tile.BackgroundColor3 = crate.color
	tile.Parent = parent
	corner(tile, 12)
	gradient(tile, lighter(crate.color, 0.3), darker(crate.color, 0.25))
	stroke(tile, INK, 3)
	text(tile, "📦", { Position = UDim2.fromScale(0.15, 0.04), Size = UDim2.fromScale(0.7, 0.5) })
	text(tile, crate.name, {
		Position = UDim2.fromScale(0.04, 0.56),
		Size = UDim2.fromScale(0.92, 0.38),
		StrokeThickness = 2,
		TextWrapped = true,
	})
end

-- The claim button on the right of a row: ready, claimed, or waiting.
local function claimButton(
	parent: Instance,
	kind: "ready" | "claimed" | "waiting",
	label: string,
	onClaim: (() -> ())?
): TextButton
	local color = if kind == "ready"
		then Color3.fromRGB(60, 210, 80)
		elseif kind == "claimed" then Color3.fromRGB(120, 120, 140)
		else Color3.fromRGB(60, 60, 90)
	local b = button(parent, label, color, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(150, 56),
		AutoButtonColor = kind == "ready",
	})
	if kind == "ready" and onClaim then
		b.Activated:Connect(onClaim)
		local scale = Instance.new("UIScale")
		scale.Parent = b
		TweenService:Create(
			scale,
			TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Scale = 1.07 }
		):Play()
	end
	return b
end

local function invoke(action: string, a: any, b: any)
	local remote = rewardsFunction
	if remote then
		task.spawn(function()
			remote:InvokeServer(action, a, b)
		end)
	end
end

local function claim(tab: string, index: number?)
	invoke("claim", tab, index)
end

-- A big label box on the left of a row, like "10 min".
local function leftLabel(parent: Instance, value: string, width: number?)
	text(parent, value, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(width or 110, 70),
		StrokeThickness = 3,
	})
end

-- One-off reward rows (weekly, VIP, group): label, dollars, button.
local function singleRow(
	color: Color3,
	label: string,
	amount: number,
	crate: string?,
	kind: "ready" | "claimed" | "waiting",
	buttonText: string,
	onClaim: (() -> ())?
)
	local r = row(130, color)
	leftLabel(r, label, 150)
	cashTile(r, amount, 175, 108)
	if crate then
		crateTile(r, crate, 295, 108)
	end
	claimButton(r, kind, buttonText, onClaim)
end

local function note(value: string, color: Color3?): TextLabel
	order += 1
	local l = text(scroll, value, {
		LayoutOrder = order,
		Size = UDim2.fromOffset(ROW_W, 34),
		TextColor3 = color or WHITE,
	})
	l.TextWrapped = true
	return l
end

-- Tabs ---------------------------------------------------------------------------------------

local TAB_COLORS: { [string]: Color3 } = {}
for _, tab in RewardsConfig.TABS do
	TAB_COLORS[tab.id] = tab.color
end

local renderers: { [string]: (s: { [string]: any }) -> () } = {}

renderers.Playtime = function(s)
	local played = playSeconds()
	tick(function()
		header.Text = "You've been online " .. clock(playSeconds()) .. " today!"
	end)
	local claimed = s.playClaimed :: { number }
	for i, tier in RewardsConfig.PLAYTIME do
		local r = row(120, TAB_COLORS.Playtime)
		leftLabel(r, tier.minutes .. "\nmin")
		cashTile(r, tier.cash, 135, 100)
		if tier.crate then
			crateTile(r, tier.crate, 245, 100)
		end
		if table.find(claimed, i) then
			claimButton(r, "claimed", "Claimed ✓")
		elseif played >= tier.minutes * 60 then
			claimButton(r, "ready", "Claim!", function()
				claim("Playtime", i)
			end)
		else
			local b = claimButton(r, "waiting", "")
			tick(function()
				b.Text = clock(tier.minutes * 60 - playSeconds())
			end)
		end
	end
	note("Playtime rewards reset every day.", Color3.fromRGB(200, 220, 255))
end

renderers.Weekly = function(s)
	header.Text = "A big reward every week!"
	if s.weeklyClaimed then
		singleRow(
			TAB_COLORS.Weekly,
			"This\nweek",
			RewardsConfig.WEEKLY.cash,
			RewardsConfig.WEEKLY.crate,
			"claimed",
			"Claimed ✓"
		)
		local l = note("")
		tick(function()
			l.Text = "Next weekly reward in " .. untilTime(s.weekEnds)
		end)
	else
		singleRow(
			TAB_COLORS.Weekly,
			"This\nweek",
			RewardsConfig.WEEKLY.cash,
			RewardsConfig.WEEKLY.crate,
			"ready",
			"Claim!",
			function()
				claim("Weekly")
			end
		)
		note("Resets every Monday.")
	end
end

renderers.Vip = function(s)
	header.Text = "VIPs get a bonus every day!"
	local color = TAB_COLORS.Vip
	if not s.vipConfigured then
		singleRow(color, "VIP\n👑", RewardsConfig.VIP_DAILY, nil, "waiting", "Soon!")
		note("VIP is coming soon.")
	elseif not s.vipOwned then
		local r = row(130, color)
		leftLabel(r, "VIP\n👑", 150)
		cashTile(r, RewardsConfig.VIP_DAILY, 175, 108)
		local get = button(r, "Get VIP", Color3.fromRGB(170, 80, 255), {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(150, 56),
		})
		get.Activated:Connect(function()
			MarketplaceService:PromptGamePassPurchase(player, RewardsConfig.VIP_GAMEPASS_ID)
		end)
		note("Buy VIP to claim this every day.")
	elseif s.vipClaimed then
		singleRow(color, "VIP\n👑", RewardsConfig.VIP_DAILY, nil, "claimed", "Claimed ✓")
		local l = note("")
		tick(function()
			l.Text = "Next VIP reward in " .. untilTime(s.dayEnds)
		end)
	else
		singleRow(color, "VIP\n👑", RewardsConfig.VIP_DAILY, nil, "ready", "Claim!", function()
			claim("Vip")
		end)
	end
end

renderers.Daily = function(s)
	local streak = s.dailyDay :: number
	header.Text = if s.dailyClaimed
		then "Day " .. streak .. " claimed! See you tomorrow"
		else "Day " .. streak .. " of your streak!"
	-- A grid of the seven days.
	order += 1
	local grid = Instance.new("Frame")
	grid.LayoutOrder = order
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.fromOffset(ROW_W, 2 * 140 + 12)
	grid.Parent = scroll
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(122, 140)
	layout.CellPadding = UDim2.fromOffset(12, 12)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	for day, reward in RewardsConfig.DAILY do
		local done = day < streak or (day == streak and s.dailyClaimed)
		local today = day == streak and not s.dailyClaimed
		local color = if today then Color3.fromRGB(255, 200, 40) else TAB_COLORS.Daily
		local card = Instance.new("Frame")
		card.LayoutOrder = day
		card.BackgroundColor3 = color
		card.BackgroundTransparency = if done then 0.5 else 0
		card.Parent = grid
		corner(card, 14)
		gradient(card, lighter(color, 0.2), darker(color, 0.2))
		stroke(card, if today then WHITE else INK, if today then 4 else 3)
		text(card, "Day " .. day, { Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(106, 30) })
		text(
			card,
			if done then "✅" elseif reward.crate then "📦" else "💵",
			{ Position = UDim2.fromOffset(31, 40), Size = UDim2.fromOffset(60, 54) }
		)
		text(card, money(reward.cash) .. (if reward.crate then " + crate" else ""), {
			Position = UDim2.fromOffset(8, 100),
			Size = UDim2.fromOffset(106, 30),
		})
	end
	order += 1
	local holderRow = Instance.new("Frame")
	holderRow.LayoutOrder = order
	holderRow.BackgroundTransparency = 1
	holderRow.Size = UDim2.fromOffset(ROW_W, 70)
	holderRow.Parent = scroll
	local b
	if s.dailyClaimed then
		b = button(holderRow, "", Color3.fromRGB(60, 60, 90), {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(260, 60),
			AutoButtonColor = false,
		})
		local next = b
		tick(function()
			next.Text = "Next in " .. untilTime(s.dayEnds)
		end)
	else
		b = button(holderRow, "Claim Day " .. streak .. "!", Color3.fromRGB(60, 210, 80), {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(260, 60),
		})
		b.Activated:Connect(function()
			claim("Daily")
		end)
	end
	note("Miss a day and the streak starts over.", Color3.fromRGB(200, 220, 255))
end

renderers.Invite = function(s)
	header.Text = "Get " .. money(RewardsConfig.INVITE) .. " for every friend who joins you!"
	local r = row(130, TAB_COLORS.Invite)
	leftLabel(r, "Invite\n💌", 150)
	cashTile(r, RewardsConfig.INVITE, 175, 108)
	local invite = button(r, "Invite", Color3.fromRGB(255, 80, 170), {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(150, 56),
	})
	invite.Activated:Connect(function()
		local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		if ok and can then
			pcall(SocialService.PromptGameInvite, SocialService, player)
		else
			showToast("Invites aren't available right now")
		end
	end)
	local pending = s.invitePending :: number
	local claimRow = row(100, TAB_COLORS.Invite)
	leftLabel(claimRow, pending .. " friend" .. (if pending == 1 then "" else "s") .. " joined", 280)
	if pending > 0 then
		claimButton(claimRow, "ready", "Claim " .. money(pending * RewardsConfig.INVITE), function()
			claim("Invite")
		end)
	else
		claimButton(claimRow, "waiting", "Waiting...")
	end
	note("Friends rewarded so far: " .. s.inviteTotal)
end

renderers.Robux = function(s)
	local spent = s.robuxSpent :: number
	header.Text = "You've spent R$" .. spent .. " in Bellship!"
	local claimed = s.robuxClaimed :: { number }
	for i, tier in RewardsConfig.ROBUX do
		local r = row(120, TAB_COLORS.Robux)
		leftLabel(r, "R$\n" .. tier.robux)
		cashTile(r, tier.cash, 135, 100)
		-- Progress towards this tier.
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0, 0.5)
		bar.Position = UDim2.new(0, 250, 0.5, 0)
		bar.Size = UDim2.fromOffset(ROW_W - 250 - 180, 22)
		bar.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
		bar.Parent = r
		corner(bar, 11)
		stroke(bar, INK, 2)
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(math.clamp(spent / tier.robux, 0, 1), 1)
		fill.BackgroundColor3 = Color3.fromRGB(255, 220, 60)
		fill.Parent = bar
		corner(fill, 11)
		if table.find(claimed, i) then
			claimButton(r, "claimed", "Claimed ✓")
		elseif spent >= tier.robux then
			claimButton(r, "ready", "Claim!", function()
				claim("Robux", i)
			end)
		else
			claimButton(r, "waiting", "R$" .. tier.robux - spent .. " to go")
		end
	end
end

renderers.Group = function(s)
	header.Text = "Like the game + join our group!"
	local color = TAB_COLORS.Group
	if not s.groupConfigured then
		singleRow(color, "👍 + 👥", RewardsConfig.GROUP, nil, "waiting", "Soon!")
		note("The group is coming soon.")
	elseif s.groupClaimed then
		singleRow(color, "👍 + 👥", RewardsConfig.GROUP, nil, "claimed", "Claimed ✓")
		note("Thanks for supporting Bellship!")
	else
		singleRow(color, "👍 + 👥", RewardsConfig.GROUP, nil, "ready", "Claim!", function()
			claim("Group")
		end)
		note("1. Like Bellship   2. Join the group   3. Claim!")
	end
end

renderers.Crates = function(s)
	header.Text = "Open crates for new skins!"
	local free = s.freeCrates :: { [string]: number }
	local pity = s.pity :: { [string]: number }
	for _, kind in Skins.KINDS do
		local crate = RewardsConfig.CRATES[kind]
		local r = row(150, crate.color)
		crateTile(r, kind, 12, 118)
		-- How close the pity guarantee is.
		local left = RewardsConfig.PITY - (pity[kind] or 0)
		text(r, "Epic or better guaranteed in " .. left .. (if left == 1 then " open" else " opens"), {
			Position = UDim2.fromOffset(142, 16),
			Size = UDim2.fromOffset(ROW_W - 142 - 180, 26),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local bar = Instance.new("Frame")
		bar.Position = UDim2.fromOffset(142, 50)
		bar.Size = UDim2.fromOffset(ROW_W - 142 - 180, 18)
		bar.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
		bar.Parent = r
		corner(bar, 9)
		stroke(bar, INK, 2)
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(math.clamp((pity[kind] or 0) / RewardsConfig.PITY, 0, 1), 1)
		fill.BackgroundColor3 = RewardsConfig.RARITY_COLORS.Epic
		fill.Parent = bar
		corner(fill, 9)
		text(r, (free[kind] or 0) .. " free " .. crate.name .. (if (free[kind] or 0) == 1 then "" else "s"), {
			Position = UDim2.fromOffset(142, 84),
			Size = UDim2.fromOffset(ROW_W - 142 - 180, 24),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(255, 240, 160),
		})
		-- Open buttons, stacked on the right.
		local buttons = {}
		if (free[kind] or 0) > 0 then
			table.insert(buttons, { label = "Open Free!", color = Color3.fromRGB(255, 80, 170), how = "free" })
		end
		table.insert(
			buttons,
			{ label = "Open " .. money(crate.price), color = Color3.fromRGB(60, 210, 80), how = "cash" }
		)
		if crate.robuxProductId ~= 0 and s.robuxCrates then
			table.insert(buttons, { label = "Open with R$", color = Color3.fromRGB(20, 200, 180), how = "robux" })
		end
		local h = math.min(44, (150 - 16 - (#buttons - 1) * 6) / #buttons)
		for i, info in buttons do
			local b = button(r, info.label, info.color, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(
					1,
					-12,
					0,
					8 + (i - 1) * (h + 6) + (150 - 16 - #buttons * h - (#buttons - 1) * 6) / 2
				),
				Size = UDim2.fromOffset(160, h),
			})
			b.Activated:Connect(function()
				if info.how == "robux" then
					MarketplaceService:PromptProductPurchase(player, crate.robuxProductId)
				else
					invoke("openCrate", kind, info.how)
				end
			end)
		end
	end

	-- The odds, openly.
	note("Drop odds (the same for every crate)", Color3.fromRGB(255, 240, 160))
	local total = 0
	for _, rarity in RewardsConfig.RARITIES do
		total += RewardsConfig.CRATE_ODDS[rarity]
	end
	for _, rarity in RewardsConfig.RARITIES do
		local color = RewardsConfig.RARITY_COLORS[rarity]
		local r = row(46, darker(color, 0.35))
		text(r, rarity, {
			Position = UDim2.fromOffset(16, 8),
			Size = UDim2.fromOffset(160, 30),
			TextColor3 = lighter(color, 0.2),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local counts = {}
		for _, kind in Skins.KINDS do
			local n = 0
			for _, skin in Skins.ofKind(kind) do
				if skin.rarity == rarity then
					n += 1
				end
			end
			table.insert(counts, n .. " " .. string.lower(kind) .. (if n == 1 then "" else "s"))
		end
		text(r, table.concat(counts, " · "), {
			Position = UDim2.fromOffset(180, 11),
			Size = UDim2.fromOffset(ROW_W - 180 - 110, 24),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		text(r, string.format("%g%%", RewardsConfig.CRATE_ODDS[rarity] / total * 100), {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -16, 0, 8),
			Size = UDim2.fromOffset(90, 30),
			TextXAlignment = Enum.TextXAlignment.Right,
		})
	end
	note("Every skin of a rarity is equally likely within its crate.", Color3.fromRGB(200, 220, 255))
	note(
		"After " .. RewardsConfig.PITY .. " opens without an Epic or Legendary, the next one is one.",
		Color3.fromRGB(200, 220, 255)
	)
	note("Already own it? You get half its price back in dollars.", Color3.fromRGB(200, 220, 255))
end

renderers.Skins = function(s)
	header.Text = "Your skins"
	local owned = s.owned :: { string }
	local equippedNow = s.equipped :: { [string]: string }
	for _, kind in Skins.KINDS do
		local info = Skins.KIND_INFO[kind]
		note(info.icon .. " " .. info.title, Color3.fromRGB(255, 240, 160))
		local mine = {}
		for _, skin in Skins.ofKind(kind) do
			if table.find(owned, skin.id) then
				table.insert(mine, skin)
			end
		end
		if #mine == 0 then
			note("None yet. Open a " .. info.crate .. " to get some!")
			continue
		end
		order += 1
		local grid = Instance.new("Frame")
		grid.LayoutOrder = order
		grid.BackgroundTransparency = 1
		grid.Size = UDim2.fromOffset(ROW_W, math.ceil(#mine / 4) * 132)
		grid.Parent = scroll
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.fromOffset(124, 122)
		layout.CellPadding = UDim2.fromOffset(10, 10)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid
		for i, skin in mine do
			local color = RewardsConfig.RARITY_COLORS[skin.rarity]
			local card = Instance.new("Frame")
			card.LayoutOrder = i
			card.BackgroundColor3 = color
			card.Parent = grid
			corner(card, 12)
			gradient(card, lighter(color, 0.15), darker(color, 0.35))
			stroke(card, INK, 3)
			text(
				card,
				skin.name,
				{ Position = UDim2.fromOffset(6, 8), Size = UDim2.fromOffset(112, 28), TextWrapped = true }
			)
			text(card, skin.rarity, {
				Position = UDim2.fromOffset(6, 38),
				Size = UDim2.fromOffset(112, 22),
				TextColor3 = lighter(color, 0.5),
			})
			local on = equippedNow[kind] == skin.id
			local b = button(
				card,
				if on then "Equipped" else "Equip",
				if on then Color3.fromRGB(120, 120, 140) else Color3.fromRGB(60, 210, 80),
				{
					Position = UDim2.fromOffset(8, 70),
					Size = UDim2.fromOffset(108, 42),
				}
			)
			b.Activated:Connect(function()
				invoke("equip", skin.id)
			end)
		end
	end
	note("Press Equipped to take a skin off.", Color3.fromRGB(200, 220, 255))
end

-- Which tabs have something to claim right now.
local function claimable(s: { [string]: any }): { [string]: boolean }
	local played = playSeconds()
	local result: { [string]: boolean } = {}
	for i, tier in RewardsConfig.PLAYTIME do
		if played >= tier.minutes * 60 and not table.find(s.playClaimed, i) then
			result.Playtime = true
		end
	end
	result.Weekly = not s.weeklyClaimed
	result.Vip = s.vipConfigured and s.vipOwned and not s.vipClaimed
	result.Daily = not s.dailyClaimed
	result.Invite = s.invitePending > 0
	for i, tier in RewardsConfig.ROBUX do
		if s.robuxSpent >= tier.robux and not table.find(s.robuxClaimed, i) then
			result.Robux = true
		end
	end
	result.Group = s.groupConfigured and not s.groupClaimed
	for _, count in s.freeCrates do
		if count > 0 then
			result.Crates = true
		end
	end
	return result
end

local tabButtons: { [string]: { button: TextButton, stroke: UIStroke, dot: Frame } } = {}
local built = "" -- what the open tab was last built from

local function render()
	local s = state
	if not s then
		return
	end
	local ready = claimable(s)
	-- Rebuild the tab only when something changed (new data, another tab, a playtime reward
	-- unlocking); otherwise just tick the timers, so buttons are not swapped under the mouse.
	local unlocked = 0
	for _, tier in RewardsConfig.PLAYTIME do
		if playSeconds() >= tier.minutes * 60 then
			unlocked += 1
		end
	end
	local key = string.format("%s|%d|%d|%s", activeTab, version, unlocked, tostring(holder.Visible))
	local any = false
	for id, tab in tabButtons do
		tab.dot.Visible = ready[id] == true
		any = any or ready[id] == true
		local active = id == activeTab
		tab.stroke.Color = if active then WHITE else INK
		tab.stroke.Thickness = if active then 4 else 3
		tab.button.Size = UDim2.fromOffset(if active then TAB_W else TAB_W - 14, 50)
	end
	openDot.Visible = any
	if not holder.Visible then
		built = ""
	elseif key ~= built then
		built = key
		clear()
		order = 0
		tickers = {}
		renderers[activeTab](s)
	else
		for _, update in tickers do
			update()
		end
	end
end

for i, tab in RewardsConfig.TABS do
	local b = button(tabList, tab.title, tab.color, {
		LayoutOrder = i,
		Size = UDim2.fromOffset(TAB_W - 14, 50),
	})
	b.TextScaled = true
	local s = b:FindFirstChildOfClass("UIStroke") :: UIStroke
	tabButtons[tab.id] = { button = b, stroke = s, dot = dot(b) }
	b.Activated:Connect(function()
		activeTab = tab.id
		scroll.CanvasPosition = Vector2.zero
		render()
	end)
end

local function fit()
	local viewport = workspace.CurrentCamera.ViewportSize
	uiScale.Scale = math.min(1, (viewport.Y - 40) / (PANEL_H + 80), (viewport.X - 40) / (PANEL_W + 20))
end

local function setOpen(open: boolean)
	holder.Visible = open
	if open then
		fit()
		local scale = uiScale.Scale
		uiScale.Scale = scale * 0.85
		TweenService:Create(uiScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = scale }):Play()
		render()
	end
end

openButton.Activated:Connect(function()
	setOpen(not holder.Visible)
end)
-- For testing from Studio: set the ScreenGui's "Tab" attribute to open the hub on that tab.
gui:GetAttributeChangedSignal("Tab"):Connect(function()
	local tab = gui:GetAttribute("Tab")
	if typeof(tab) == "string" and renderers[tab] then
		activeTab = tab
		setOpen(true)
	end
end)
close.Activated:Connect(function()
	setOpen(false)
end)

function RewardsHub.start(remote: RemoteFunction, event: RemoteEvent)
	rewardsFunction = remote
	gui.Parent = player:WaitForChild("PlayerGui")
	event.OnClientEvent:Connect(function(snapshot: { [string]: any }?, message: string?, opened: { [string]: any }?)
		if snapshot then
			state = snapshot
			receivedAt = os.clock()
			version += 1
			cashLabel.Text = money(snapshot.cash)
			render()
		end
		if message then
			showToast(message)
		end
		if opened then
			showReveal(opened)
		end
	end)
	task.spawn(function()
		local snapshot = remote:InvokeServer("state")
		if typeof(snapshot) == "table" and not state then
			state = snapshot
			receivedAt = os.clock()
			version += 1
			cashLabel.Text = money(snapshot.cash)
			render()
		end
	end)
	-- Count down timers and playtime once a second.
	task.spawn(function()
		while true do
			task.wait(1)
			render()
		end
	end)
end

-- Hide the button and dollars while you are seated at a table.
function RewardsHub.setHidden(hidden: boolean)
	side.Visible = not hidden
	if hidden then
		holder.Visible = false
	end
end

return RewardsHub
