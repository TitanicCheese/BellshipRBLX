-- The three weekly leaderboards at the spawn: most wins, most bells rung, best win streak.
-- Each is a dark wooden gate with a glowing title sign, a top-10 panel (avatar, name, amount),
-- a bottom row with your own score (filled in by the client), and this week's #1 dancing on a
-- glowing pedestal beside it. Saved scores are fetched every minute; players in the server are
-- merged in live.
local Players = game:GetService("Players")

local Stats = require(script.Parent.Stats)

local Leaderboards = {}

local WOOD = Color3.fromRGB(50, 44, 52)
local WOOD_DARK = Color3.fromRGB(36, 32, 38)
local NAVY = Color3.fromRGB(28, 36, 58)
local ROWS = 10
local PANEL_W, PANEL_H = 13, 14
local PANEL_Y = 2.6 -- bottom of the panel above the ground
local POST_X = PANEL_W / 2 + 1.1
local GATE_H = 22
local PPS = 40 -- SurfaceGui pixels per stud
-- The pedestal stands to the right of the board as you look at it.
Leaderboards.PEDESTAL_X = -(PANEL_W / 2 + 6)

local BOARDS = {
	{
		stat = "WeekWins",
		title = "Weekly Most\nWins",
		icon = "🏆",
		color = Color3.fromRGB(90, 255, 110),
		dance = "rbxassetid://507771019",
	},
	{
		stat = "WeekBells",
		title = "Weekly Most\nBells",
		icon = "🛎️",
		color = Color3.fromRGB(255, 225, 60),
		dance = "rbxassetid://507776043",
	},
	{
		stat = "WeekBestStreak",
		title = "Weekly Best\nStreak",
		icon = "🔥",
		color = Color3.fromRGB(255, 140, 40),
		dance = "rbxassetid://507777268",
	},
}

-- Row colours: gold, silver and bronze for the top three, then alternating navy.
local PODIUM = {
	{ fill = Color3.fromRGB(255, 192, 44), text = Color3.fromRGB(70, 44, 0) },
	{ fill = Color3.fromRGB(206, 213, 226), text = Color3.fromRGB(40, 44, 58) },
	{ fill = Color3.fromRGB(224, 142, 74), text = Color3.fromRGB(66, 32, 10) },
}
local ROW_A, ROW_B = Color3.fromRGB(46, 58, 90), Color3.fromRGB(38, 48, 76)

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

local function wood(name: string, size: Vector3, cf: CFrame, parent: Instance)
	return block(name, size, cf, WOOD, Enum.Material.Wood, parent)
end

-- A square wooden beam from a to b (in world space).
local function beam(a: Vector3, b: Vector3, thickness: number, parent: Instance)
	local length = (b - a).Magnitude
	wood("Brace", Vector3.new(thickness, thickness, length), CFrame.lookAt((a + b) / 2, b), parent)
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

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

type Row = { frame: Frame, rank: TextLabel, avatar: ImageLabel, name: TextLabel, value: TextLabel }

-- One row of the table: rank, round avatar, name, amount.
local function row(parent: Instance, y: number, height: number, width: number): Row
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.Position = UDim2.fromOffset(14, y)
	frame.Size = UDim2.fromOffset(width - 28, height)
	frame.Parent = parent
	corner(frame, 8)
	local pad = 6
	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.BackgroundColor3 = Color3.fromRGB(20, 26, 44)
	avatar.BackgroundTransparency = 0.5
	avatar.Position = UDim2.fromOffset(62, pad / 2)
	avatar.Size = UDim2.fromOffset(height - pad, height - pad)
	avatar.Parent = frame
	corner(avatar, 99)
	return {
		frame = frame,
		rank = label(frame, "", {
			Name = "Rank",
			Position = UDim2.fromOffset(8, pad),
			Size = UDim2.fromOffset(48, height - pad * 2),
		}),
		avatar = avatar,
		name = label(frame, "", {
			Name = "PlayerName",
			Position = UDim2.fromOffset(62 + height, pad),
			Size = UDim2.fromOffset(width - 28 - 62 - height - 150, height - pad * 2),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		value = label(frame, "", {
			Name = "Value",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, pad),
			Size = UDim2.fromOffset(140, height - pad * 2),
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
	}
end

type Board = {
	stat: string,
	icon: string,
	dance: string,
	model: Model,
	rows: { Row },
	timer: TextLabel,
	pedestalTop: CFrame,
	saved: { { userId: number, value: number } },
	fake: { { userId: number, value: number } }, -- test scores set from Studio
	champion: number?, -- user id of the avatar on the pedestal
	dancer: Model?,
}

-- The gate frame: two posts on splayed legs, two crossbeams with upturned ends.
local function gate(cf: CFrame, model: Model)
	for _, side in { -1, 1 } do
		local x = side * POST_X
		wood("Post", Vector3.new(1.4, GATE_H, 1.4), cf * CFrame.new(x, GATE_H / 2, 0), model)
		block("Foot", Vector3.new(2.4, 1, 2.4), cf * CFrame.new(x, 0.5, 0), WOOD_DARK, Enum.Material.Wood, model)
		for _, z in { -2.8, 2.8 } do
			beam(cf * Vector3.new(x, 7, 0), cf * Vector3.new(x, 0.3, z), 0.8, model)
			block("Foot", Vector3.new(1.4, 0.6, 1.4), cf * CFrame.new(x, 0.3, z), WOOD_DARK, Enum.Material.Wood, model)
		end
		-- Upturned beam ends.
		wood(
			"BeamEnd",
			Vector3.new(2.2, 0.9, 1.9),
			cf * CFrame.new(side * (PANEL_W / 2 + 4.4), GATE_H + 0.75, 0) * CFrame.Angles(0, 0, side * 0.25),
			model
		)
	end
	wood("TopBeam", Vector3.new(PANEL_W + 8, 1.3, 1.8), cf * CFrame.new(0, GATE_H + 0.3, 0), model)
	wood("Beam", Vector3.new(PANEL_W + 4.5, 0.9, 1.3), cf * CFrame.new(0, GATE_H - 2.6, 0), model)
	wood("Rail", Vector3.new(PANEL_W + 2.2, 0.8, 1), cf * CFrame.new(0, PANEL_Y - 0.4, 0), model)
end

-- The glowing title sign hanging from the beams.
local function sign(cf: CFrame, info: typeof(BOARDS[1]), model: Model): TextLabel
	local at = cf * CFrame.new(0, GATE_H - 1.3, -1.1)
	local glow = block("SignGlow", Vector3.new(9.4, 4, 0.4), at, info.color, Enum.Material.Neon, model)
	local light = Instance.new("PointLight")
	light.Color = info.color
	light.Range = 12
	light.Brightness = 1.5
	light.Parent = glow
	local face = block(
		"Sign",
		Vector3.new(8.6, 3.2, 0.2),
		at * CFrame.new(0, 0, -0.25),
		Color3.fromRGB(30, 30, 36),
		Enum.Material.SmoothPlastic,
		model
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PPS
	gui.LightInfluence = 0
	gui.MaxDistance = 160
	gui.Parent = face
	label(gui, info.title, {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.fromOffset(8.6 * PPS - 24, 3.2 * PPS * 0.68),
		TextStrokeTransparency = 0.4,
	})
	return label(gui, "", {
		Name = "Timer",
		Position = UDim2.fromOffset(12, 3.2 * PPS * 0.72),
		Size = UDim2.fromOffset(8.6 * PPS - 24, 3.2 * PPS * 0.22),
		TextColor3 = info.color,
		Font = Enum.Font.GothamBold,
	})
end

-- The panel with the header, ten rows and your own row at the bottom.
local function panel(cf: CFrame, model: Model): { Row }
	wood(
		"PanelFrame",
		Vector3.new(PANEL_W + 0.8, PANEL_H + 0.8, 0.6),
		cf * CFrame.new(0, PANEL_Y + PANEL_H / 2, 0),
		model
	)
	local face = block(
		"Panel",
		Vector3.new(PANEL_W, PANEL_H, 0.3),
		cf * CFrame.new(0, PANEL_Y + PANEL_H / 2, -0.35),
		NAVY,
		Enum.Material.SmoothPlastic,
		model
	)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Board"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PPS
	gui.LightInfluence = 0.2
	gui.MaxDistance = 160
	gui.Parent = face

	local w = PANEL_W * PPS
	local header = Color3.fromRGB(170, 186, 222)
	label(gui, "Rank", {
		Position = UDim2.fromOffset(22, 12),
		Size = UDim2.fromOffset(60, 26),
		TextColor3 = header,
	})
	label(gui, "Name", {
		Position = UDim2.fromOffset(22 + 62 + 40, 12),
		Size = UDim2.fromOffset(120, 26),
		TextColor3 = header,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	label(gui, "Amount", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -26, 0, 12),
		Size = UDim2.fromOffset(120, 26),
		TextColor3 = header,
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	local rows = {}
	local height, gap = 40, 4
	for i = 1, ROWS do
		local r = row(gui, 46 + (i - 1) * (height + gap), height, w)
		r.frame.Name = "Row" .. i
		r.rank.Text = tostring(i)
		local podium = PODIUM[i]
		r.frame.BackgroundColor3 = if podium then podium.fill elseif i % 2 == 0 then ROW_A else ROW_B
		for _, text in { r.rank, r.name, r.value } do
			text.TextColor3 = if podium then podium.text else Color3.new(1, 1, 1)
		end
		table.insert(rows, r)
	end

	-- Your own row, filled in by each client.
	local line = Instance.new("Frame")
	line.BorderSizePixel = 0
	line.BackgroundColor3 = header
	line.BackgroundTransparency = 0.6
	line.Position = UDim2.fromOffset(20, 46 + ROWS * (height + gap) + 2)
	line.Size = UDim2.fromOffset(w - 40, 2)
	line.Parent = gui
	local you = row(gui, 46 + ROWS * (height + gap) + 10, height + 4, w)
	you.frame.Name = "You"
	you.frame.BackgroundColor3 = Color3.fromRGB(64, 80, 124)
	local stroke = Instance.new("UIStroke")
	stroke.Color = header
	stroke.Transparency = 0.4
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = you.frame
	return rows
end

-- The glowing pedestal beside the board. Returns where the dancer stands.
local function pedestal(cf: CFrame, color: Color3, model: Model): CFrame
	local at = cf * CFrame.new(Leaderboards.PEDESTAL_X, 0, 0)
	block("Pedestal", Vector3.new(5, 1, 5), at * CFrame.new(0, 0.5, 0), WOOD_DARK, Enum.Material.SmoothPlastic, model)
	local glow =
		block("PedestalGlow", Vector3.new(5.4, 0.4, 5.4), at * CFrame.new(0, 1.2, 0), color, Enum.Material.Neon, model)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 10
	light.Brightness = 1.2
	light.Parent = glow
	return at * CFrame.new(0, 1.4, 0)
end

local function build(cf: CFrame, info: typeof(BOARDS[1]), parent: Instance): Board
	local model = Instance.new("Model")
	model.Name = "Leaderboard"
	model:SetAttribute("Stat", info.stat)
	model:SetAttribute("Icon", info.icon)
	gate(cf, model)
	local timer = sign(cf, info, model)
	local rows = panel(cf, model)
	local top = pedestal(cf, info.color, model)
	model.Parent = parent
	return {
		stat = info.stat,
		icon = info.icon,
		dance = info.dance,
		model = model,
		rows = rows,
		timer = timer,
		pedestalTop = top,
		saved = {},
		fake = {},
		champion = nil,
		dancer = nil,
	}
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

local function headshot(userId: number): string
	return string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48", userId)
end

-- Puts this week's #1 on the pedestal, dancing. Loads the avatar in the background.
local function crown(board: Board, userId: number?)
	if board.champion == userId then
		return
	end
	board.champion = userId
	if board.dancer then
		board.dancer:Destroy()
		board.dancer = nil
	end
	if not userId then
		return
	end
	task.spawn(function()
		local ok, rig = pcall(function()
			local description = Players:GetHumanoidDescriptionFromUserId(userId)
			return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
		end)
		if not ok or board.champion ~= userId then
			if not ok then
				warn("[Bellship] could not load the avatar for", userId, rig)
			end
			return
		end
		local model = rig :: Model
		model.Name = "Champion"
		local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		root.Anchored = true
		model:PivotTo(board.pedestalTop * CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))

		local tag = Instance.new("BillboardGui")
		tag.Size = UDim2.fromScale(7, 1)
		tag.StudsOffset = Vector3.new(0, 3.4, 0)
		tag.MaxDistance = 120
		tag.Parent = root
		label(tag, names[userId] or nameOf(userId), {
			Size = UDim2.fromScale(1, 1),
			TextStrokeTransparency = 0.3,
		})

		model.Parent = board.model
		board.dancer = model
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		local animation = Instance.new("Animation")
		animation.AnimationId = board.dance
		local track = (animator :: Animator):LoadAnimation(animation)
		track.Looped = true
		track:Play()
	end)
end

local function render(board: Board)
	local scores: { [number]: { name: string, value: number } } = {}
	for _, saved in { board.saved, board.fake } do
		for _, item in saved do
			scores[item.userId] = { name = names[item.userId] or nameOf(item.userId), value = item.value }
		end
	end
	for userId, live in Stats.online(board.stat) do
		names[userId] = live.name
		local saved = scores[userId]
		if not saved or live.value > saved.value then
			scores[userId] = live
		end
	end
	local list = {}
	for userId, score in scores do
		if score.value > 0 then
			table.insert(list, { userId = userId, name = score.name, value = score.value })
		end
	end
	table.sort(list, function(a, b)
		return a.value > b.value or (a.value == b.value and a.userId < b.userId)
	end)

	local ids = {}
	for i, r in board.rows do
		local score = list[i]
		r.name.Text = if score then score.name else "—"
		r.value.Text = if score then score.value .. " " .. board.icon else ""
		r.avatar.Image = if score then headshot(score.userId) else ""
		r.name.TextTransparency = if score then 0 else 0.5
		if score then
			table.insert(ids, tostring(score.userId))
		end
	end
	-- The client uses this to show your rank in the bottom row.
	board.model:SetAttribute("TopIds", table.concat(ids, ","))
	crown(board, if list[1] then list[1].userId else nil)
end

local function countdown(): string
	local _, ends = Stats.week()
	local left = math.max(0, ends - os.time())
	local days, hours, minutes = left // 86400, left % 86400 // 3600, left % 3600 // 60
	if days > 0 then
		return string.format("Resets in %dd %dh", days, hours)
	end
	return string.format("Resets in %dh %dm", hours, minutes)
end

local boards: { Board } = {}

-- For testing in Studio: pretend these scores were saved this week.
function Leaderboards.debugSaved(stat: string, saved: { { userId: number, value: number } })
	for _, board in boards do
		if board.stat == stat then
			board.fake = saved
			render(board)
		end
	end
end

function Leaderboards.start(places: { CFrame }, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Leaderboards"
	folder.Parent = parent
	for i, info in BOARDS do
		boards[i] = build(places[i], info, folder)
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
				for _, board in boards do
					board.timer.Text = countdown()
				end
				if dirty then
					dirty = false
					for _, board in boards do
						render(board)
					end
				end
				task.wait(5)
			end
		end
	end)
end

return Leaderboards
