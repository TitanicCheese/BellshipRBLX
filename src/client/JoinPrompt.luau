-- Small cards on the right of the screen for tables where someone is waiting for an opponent:
-- [their avatar] vs [?] and a "Teleport to table" button. Hidden while you are at a table.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local JoinPrompt = {}

local GOLD = Color3.fromRGB(255, 205, 90)
local PANEL = Color3.fromRGB(28, 24, 34)
local SLOT = Color3.fromRGB(50, 42, 56)
local MAX_CARDS = 3
local CARD_W, CARD_H = 230, 150

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "BellshipJoin"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local list = Instance.new("Frame")
list.AnchorPoint = Vector2.new(1, 0.5)
list.Position = UDim2.new(1, -16, 0.5, 0)
list.Size = UDim2.fromOffset(CARD_W, (CARD_H + 10) * MAX_CARDS)
list.BackgroundTransparency = 1
list.Parent = gui
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 10)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Parent = list

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = 0.25
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function label(parent: Instance, text: string, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextScaled = true
	l.Text = text
	for key, value in props do
		(l :: any)[key] = value
	end
	l.Parent = parent
	return l
end

local function slot(parent: Instance, x: number): Frame
	local frame = Instance.new("Frame")
	frame.Position = UDim2.fromOffset(x, 34)
	frame.Size = UDim2.fromOffset(64, 64)
	frame.BackgroundColor3 = SLOT
	frame.Parent = parent
	corner(frame, 10)
	stroke(frame, GOLD, 2)
	return frame
end

local cards: { [number]: Frame } = {}
local dismissed: { [number]: boolean } = {}
local order = 0
local onJoin: (id: number) -> () = function() end

local function remove(id: number)
	local card = cards[id]
	cards[id] = nil
	if card then
		card:Destroy()
	end
end

local function add(info: { [string]: any })
	local id = info.table
	remove(id)
	order -= 1 -- newest on top

	local card = Instance.new("Frame")
	card.Name = "Table" .. id
	card.LayoutOrder = order
	card.Size = UDim2.fromOffset(CARD_W, CARD_H)
	card.BackgroundColor3 = PANEL
	card.BackgroundTransparency = 0.1
	corner(card, 14)
	stroke(card, GOLD, 2)

	label(card, "Table " .. id, {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.fromOffset(CARD_W - 50, 20),
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -8, 0, 6)
	close.Size = UDim2.fromOffset(22, 22)
	close.BackgroundTransparency = 1
	close.Font = Enum.Font.FredokaOne
	close.TextScaled = true
	close.TextColor3 = Color3.fromRGB(200, 190, 210)
	close.Text = "×"
	close.Parent = card
	close.Activated:Connect(function()
		dismissed[id] = true
		remove(id)
	end)

	-- [avatar] vs [?]
	local left = slot(card, 22)
	local avatar = Instance.new("ImageLabel")
	avatar.BackgroundTransparency = 1
	avatar.Size = UDim2.fromScale(1, 1)
	avatar.Image = if info.userId
		then string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", info.userId)
		else ""
	avatar.Parent = left
	corner(avatar, 10)
	if not info.userId then
		label(left, string.sub(info.name or "?", 1, 1), { Size = UDim2.fromScale(1, 1), TextColor3 = GOLD })
	end
	label(card, "vs", {
		Position = UDim2.fromOffset(86, 50),
		Size = UDim2.fromOffset(CARD_W - 2 * 86, 32),
		TextColor3 = GOLD,
	})
	local right = slot(card, CARD_W - 22 - 64)
	label(right, "?", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.7),
		TextColor3 = GOLD,
	})

	local button = Instance.new("TextButton")
	button.Position = UDim2.fromOffset(12, CARD_H - 44)
	button.Size = UDim2.fromOffset(CARD_W - 24, 34)
	button.BackgroundColor3 = Color3.fromRGB(86, 180, 92)
	button.Font = Enum.Font.FredokaOne
	button.TextScaled = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Text = "Teleport to table"
	button.AutoButtonColor = true
	button.Parent = card
	corner(button, 10)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = button
	button.Activated:Connect(function()
		onJoin(id)
	end)

	-- Slide in from the right.
	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = card
	card.Parent = list
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	cards[id] = card

	-- Keep only the newest few.
	local ids = {}
	for other, c in cards do
		table.insert(ids, { id = other, order = c.LayoutOrder })
	end
	table.sort(ids, function(a, b)
		return a.order < b.order
	end)
	for i = MAX_CARDS + 1, #ids do
		remove(ids[i].id)
	end
end

function JoinPrompt.start(lobby: RemoteEvent, join: RemoteEvent)
	onJoin = function(id: number)
		join:FireServer(id)
	end
	lobby.OnClientEvent:Connect(function(info: { [string]: any })
		if typeof(info) ~= "table" or typeof(info.table) ~= "number" then
			return
		end
		if not info.open then
			dismissed[info.table] = nil
			remove(info.table)
		elseif info.userId ~= player.UserId and not dismissed[info.table] then
			add(info)
		end
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
end

-- Hide the cards while you are seated at a table yourself.
function JoinPrompt.setHidden(hidden: boolean)
	list.Visible = not hidden
end

return JoinPrompt
