-- The three leaderboards at the spawn: most wins, most bells rung, best win streak.
-- Saved scores are fetched every minute; players in the server are merged in live.
local Players = game:GetService("Players")

local Stats = require(script.Parent.Stats)

local Leaderboards = {}

local GOLD = Color3.fromRGB(255, 205, 90)
local PANEL = Color3.fromRGB(28, 24, 34)
local WOOD = Color3.fromRGB(74, 46, 30)
local ROWS = 10
local WIDTH, HEIGHT = 12, 14

local BOARDS = {
	{ stat = "Wins", title = "🏆 Most Wins" },
	{ stat = "BellsRung", title = "🛎️ Bells Rung" },
	{ stat = "BestStreak", title = "🔥 Best Win Streak" },
}

local function block(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, parent: Instance)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
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

type Row = { rank: TextLabel, name: TextLabel, value: TextLabel }

-- One board standing on the ground at cf, its face pointing along cf.LookVector.
local function build(cf: CFrame, title: string, parent: Instance): { Row }
	local model = Instance.new("Model")
	model.Name = "Leaderboard"
	block("Base", Vector3.new(WIDTH + 1, 1, 1.6), cf * CFrame.new(0, 0.5, 0), WOOD, Enum.Material.Wood, model)
	block(
		"Frame",
		Vector3.new(WIDTH + 0.8, HEIGHT + 0.8, 0.8),
		cf * CFrame.new(0, 1 + HEIGHT / 2 + 0.4, 0.15),
		WOOD,
		Enum.Material.Wood,
		model
	)
	local panel = block(
		"Panel",
		Vector3.new(WIDTH, HEIGHT, 0.4),
		cf * CFrame.new(0, 1 + HEIGHT / 2 + 0.4, -0.2),
		PANEL,
		Enum.Material.SmoothPlastic,
		model
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.3
	gui.MaxDistance = 140
	gui.Parent = panel

	local w, h = WIDTH * 40, HEIGHT * 40
	label(gui, title, {
		Position = UDim2.fromOffset(20, 18),
		Size = UDim2.fromOffset(w - 40, 64),
		TextColor3 = GOLD,
	})
	local line = Instance.new("Frame")
	line.BorderSizePixel = 0
	line.BackgroundColor3 = GOLD
	line.Position = UDim2.fromOffset(24, 94)
	line.Size = UDim2.fromOffset(w - 48, 3)
	line.Parent = gui

	local rows = {}
	local top, rowHeight = 112, (h - 132) / ROWS
	for i = 1, ROWS do
		local y = top + (i - 1) * rowHeight
		local shade = Instance.new("Frame")
		shade.BorderSizePixel = 0
		shade.BackgroundColor3 = Color3.new(1, 1, 1)
		shade.BackgroundTransparency = if i % 2 == 0 then 0.94 else 1
		shade.Position = UDim2.fromOffset(16, y)
		shade.Size = UDim2.fromOffset(w - 32, rowHeight)
		shade.Parent = gui
		local color = if i == 1
			then GOLD
			elseif i == 2 then Color3.fromRGB(214, 220, 228)
			elseif i == 3 then Color3.fromRGB(222, 150, 96)
			else Color3.fromRGB(225, 214, 192)
		local pad = 6
		table.insert(rows, {
			rank = label(gui, "", {
				Position = UDim2.fromOffset(26, y + pad),
				Size = UDim2.fromOffset(52, rowHeight - pad * 2),
				TextColor3 = color,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			name = label(gui, "", {
				Position = UDim2.fromOffset(84, y + pad),
				Size = UDim2.fromOffset(w - 84 - 130, rowHeight - pad * 2),
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = Enum.Font.GothamMedium,
			}),
			value = label(gui, "", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromOffset(w - 28, y + pad),
				Size = UDim2.fromOffset(110, rowHeight - pad * 2),
				TextColor3 = color,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
		})
	end
	model.Parent = parent
	return rows
end

local names: { [number]: string } = {}
local function nameOf(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = if ok then name else "Player"
	return names[userId]
end

function Leaderboards.start(places: { CFrame }, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Leaderboards"
	folder.Parent = parent
	local boards = {}
	for i, info in BOARDS do
		boards[i] = { stat = info.stat, rows = build(places[i], info.title, folder), saved = {} }
	end

	local function render()
		for _, board in boards do
			local scores: { [number]: { name: string, value: number } } = {}
			for _, item in board.saved do
				scores[item.userId] = { name = nameOf(item.userId), value = item.value }
			end
			for userId, live in Stats.online(board.stat) do
				names[userId] = live.name
				local saved = scores[userId]
				if not saved or live.value > saved.value then
					scores[userId] = live
				end
			end
			local list = {}
			for _, score in scores do
				if score.value > 0 then
					table.insert(list, score)
				end
			end
			table.sort(list, function(a, b)
				return a.value > b.value
			end)
			for i, row in board.rows do
				local score = list[i]
				row.rank.Text = "#" .. i
				row.name.Text = if score then score.name else "—"
				row.value.Text = if score then tostring(score.value) else ""
				row.name.TextTransparency = if score then 0 else 0.6
			end
		end
	end

	local dirty = true
	Stats.Changed:Connect(function()
		dirty = true
	end)
	task.spawn(function()
		while true do
			for _, board in boards do
				board.saved = Stats.top(board.stat)
			end
			dirty = true
			for _ = 1, 12 do
				if dirty then
					dirty = false
					render()
				end
				task.wait(5)
			end
		end
	end)
end

return Leaderboards
