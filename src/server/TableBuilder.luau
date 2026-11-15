-- Builds one game table: a black table with two paper sheets side by side, a divider
-- between them, two chairs on the same side, and a floating sign.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChairModel = require(script.Parent.ChairModel)
local Config = require(ReplicatedStorage.Shared.Config)

local TableBuilder = {}

export type Refs = {
	id: number,
	model: Model,
	cf: CFrame,
	seats: { Seat },
	tiles: { { [string]: BasePart } },
	markers: Folder,
	title: TextLabel,
	status: TextLabel,
}

local BLACK = Color3.fromRGB(24, 24, 27)
local PAPER = Color3.fromRGB(236, 236, 230)
local LINE = Color3.fromRGB(150, 150, 155)
local HANDWRITING = Font.new("rbxasset://fonts/families/PatrickHand.json", Enum.FontWeight.Regular)

local function block(
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance
): Part
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

local function decal(p: BasePart, parent: Instance)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
end

-- A SurfaceGui on the top of a flat part, turned so its top edge points at the players (+Z)
-- and it reads the right way up from the camera across the table. Returns the gui.
local function topCanvas(name: string, size: Vector2, cf: CFrame, parent: Instance): (Part, SurfaceGui)
	-- The part is turned 90 degrees so the gui's "up" lines up with the table's +Z.
	local p = block(
		name,
		Vector3.new(size.Y, 0.02, size.X),
		cf * CFrame.Angles(0, math.pi / 2, 0),
		PAPER,
		Enum.Material.SmoothPlastic,
		parent
	)
	p.Transparency = 1
	decal(p, parent)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 1
	gui.Parent = p
	return p, gui
end

local function text(parent: Instance, value: string, position: UDim2, size: UDim2, color: Color3)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = position
	label.Size = size
	label.FontFace = HANDWRITING
	label.TextScaled = true
	label.Text = value
	label.TextColor3 = color
	label.Parent = parent
end

-- One player's sheet of paper: grid lines, column letters along the players' edge, row
-- numbers down the camera's left side (see Config.gridOrigin).
local function sheet(side: number, cf: CFrame, parent: Instance)
	local top = Config.TABLE_TOP
	local x0 = Config.SHEET_X[side] -- sheet centre
	local s = Config.BOARD_SCALE -- the layout below is in 2-stud squares, scaled by s
	local paper = block(
		"Sheet",
		Vector3.new(7 * s, 0.04, 11 * s),
		cf * CFrame.new(x0, top + 0.02, 0),
		PAPER,
		Enum.Material.SmoothPlastic,
		parent
	)
	paper.CanQuery = false
	local y = top + 0.045
	for _, x in { 3.5, 2.5, 0.5, -1.5, -3.5 } do
		decal(
			block(
				"Line",
				Vector3.new(0.05, 0.01, 11 * s),
				cf * CFrame.new(x0 + x * s, y, 0),
				LINE,
				Enum.Material.SmoothPlastic,
				parent
			),
			parent
		)
	end
	for _, z in { 5.5, 4.5, 2.5, 0.5, -1.5, -3.5, -5.5 } do
		decal(
			block(
				"Line",
				Vector3.new(7 * s, 0.01, 0.05),
				cf * CFrame.new(x0, y, z * s),
				LINE,
				Enum.Material.SmoothPlastic,
				parent
			),
			parent
		)
	end
	local _, gui = topCanvas("Labels", Vector2.new(7 * s, 11 * s), cf * CFrame.new(x0, top + 0.06, 0), parent)
	local ink = Color3.fromRGB(30, 30, 34)
	for col = 1, Config.COLUMNS do
		-- Column centres sit at 2, 4, 6 studs from the sheet's left edge, as the camera sees it.
		text(
			gui,
			Config.COLUMN_LETTERS[col],
			UDim2.fromScale((col * 2) / 7, 0.5 / 11),
			UDim2.fromScale(1 / 7, 1 / 11),
			ink
		)
	end
	for row = 1, Config.ROWS do
		text(gui, tostring(row), UDim2.fromScale(0.5 / 7, (row * 2) / 11), UDim2.fromScale(1 / 7, 1 / 11), ink)
	end
end

-- An upright board between the two sheets so neither player can peek.
local function divider(cf: CFrame, parent: Instance)
	local top = Config.TABLE_TOP
	local board = block(
		"Divider",
		Vector3.new(0.75, 4, 3.15),
		cf * CFrame.new(0, top + 2, 0.75),
		Color3.fromRGB(122, 74, 150),
		Enum.Material.SmoothPlastic,
		parent
	)
	block(
		"Trim",
		Vector3.new(0.85, 0.3, 3.25),
		cf * CFrame.new(0, top + 4.1, 0.75),
		Color3.fromRGB(230, 200, 120),
		Enum.Material.SmoothPlastic,
		parent
	)
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Front } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 1
		gui.Parent = board
		local logo = Instance.new("TextLabel")
		logo.BackgroundTransparency = 1
		logo.AnchorPoint = Vector2.new(0.5, 0.5)
		logo.Position = UDim2.fromScale(0.5, 0.45)
		logo.Size = UDim2.fromScale(0.85, 0.3)
		logo.Font = Enum.Font.FredokaOne
		logo.TextScaled = true
		logo.Text = if face == Enum.NormalId.Front then "🛎️" else "🛎️ BELLSHIP"
		logo.TextColor3 = Color3.fromRGB(255, 232, 160)
		logo.TextStrokeColor3 = Color3.fromRGB(60, 30, 80)
		logo.TextStrokeTransparency = 0
		logo.Parent = gui
	end
end

-- A dark wooden table (Config.TABLE_SIZE): a thick top over an apron, on tapered square legs.
local function woodenTable(cf: CFrame, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "WoodenTable"
	local top = Config.TABLE_TOP
	local wood = Color3.fromRGB(62, 36, 24)
	local w, d = Config.TABLE_SIZE.X, Config.TABLE_SIZE.Y
	block(
		"Top",
		Vector3.new(w, 0.5, d),
		cf * CFrame.new(0, top - 0.25, 0),
		Color3.fromRGB(70, 41, 27),
		Enum.Material.Wood,
		model
	)
	local inset = 0.26
	local apronY = top - 0.5 - 0.35
	block(
		"Apron",
		Vector3.new(w - 2 * inset, 0.7, 0.15),
		cf * CFrame.new(0, apronY, d / 2 - inset),
		wood,
		Enum.Material.Wood,
		model
	)
	block(
		"Apron",
		Vector3.new(w - 2 * inset, 0.7, 0.15),
		cf * CFrame.new(0, apronY, -(d / 2 - inset)),
		wood,
		Enum.Material.Wood,
		model
	)
	block(
		"Apron",
		Vector3.new(0.15, 0.7, d - 2 * inset),
		cf * CFrame.new(w / 2 - inset, apronY, 0),
		wood,
		Enum.Material.Wood,
		model
	)
	block(
		"Apron",
		Vector3.new(0.15, 0.7, d - 2 * inset),
		cf * CFrame.new(-(w / 2 - inset), apronY, 0),
		wood,
		Enum.Material.Wood,
		model
	)
	-- Legs taper from 0.8 studs under the top to 0.45 at the floor, in stacked sections.
	local legHeight = top - 0.5
	local sections = 4
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			local lx, lz = x * (w / 2 - inset - 0.15), z * (d / 2 - inset - 0.15)
			for i = 1, sections do
				local t = (i - 0.5) / sections -- 0 at the top, 1 at the floor
				local width = 0.45 - 0.19 * t
				local h = legHeight / sections
				block(
					"Leg",
					Vector3.new(width, h + 0.01, width),
					cf * CFrame.new(lx, legHeight - (i - 0.5) * h, lz),
					wood,
					Enum.Material.Wood,
					model
				)
			end
		end
	end
	model.Parent = parent
end

-- The wooden chair (see ChairModel), with an invisible Seat over its seat so players can sit.
local function chair(side: number, cf: CFrame, parent: Instance): Seat
	local scale = Config.CHAIR_SCALE
	local place = cf * CFrame.new(Config.SHEET_X[side], 0, Config.CHAIR_Z)
	local model = ChairModel.build(place, scale)
	model.Name = "Chair" .. side
	local seat = Instance.new("Seat")
	seat.Name = "Seat" .. side
	seat.Anchored = true
	seat.Transparency = 1
	seat.Size = Vector3.new(ChairModel.SEAT_SIZE.X * scale - 0.1, 0.2, ChairModel.SEAT_SIZE.Y * scale - 0.1)
	seat.CFrame = place
		* CFrame.new(
			ChairModel.SEAT_OFFSET.X * scale,
			ChairModel.SEAT_HEIGHT * scale - 0.08,
			ChairModel.SEAT_OFFSET.Y * scale
		)
	seat.Parent = model
	model.Parent = parent
	return seat
end

function TableBuilder.build(id: number, cf: CFrame, parent: Instance): Refs
	local model = Instance.new("Model")
	model.Name = "Table" .. id
	local top = Config.TABLE_TOP

	block(
		"Deck",
		Vector3.new(12.75, 0.2, 12.75),
		cf * CFrame.new(0, 0.1, 1.5),
		Color3.fromRGB(196, 158, 112),
		Enum.Material.WoodPlanks,
		model
	)
	woodenTable(cf, model)

	local tilesFolder = Instance.new("Folder")
	tilesFolder.Name = "Tiles"
	tilesFolder.Parent = model
	local tiles = { {}, {} }
	for side = 1, 2 do
		sheet(side, cf, model)
		for row = 1, Config.ROWS do
			for col = 1, Config.COLUMNS do
				local key = Config.key(col, row)
				-- Invisible click targets over each square; the marker gui draws X and O on them.
				local tile = block(
					key,
					Vector3.new(1.9 * Config.BOARD_SCALE, 0.05, 1.9 * Config.BOARD_SCALE),
					cf * CFrame.new(Config.cellOffset(side, col, row) + Vector3.new(0, 0.05, 0)),
					PAPER,
					Enum.Material.SmoothPlastic,
					tilesFolder
				)
				tile.Transparency = 1
				tile.CanCollide = false
				tile.CanTouch = false
				tile:SetAttribute("Table", id)
				tile:SetAttribute("Side", side)
				tile:SetAttribute("Key", key)
				local gui = Instance.new("SurfaceGui")
				gui.Name = "Mark"
				gui.Face = Enum.NormalId.Top
				gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				gui.PixelsPerStud = 50
				gui.LightInfluence = 1
				gui.Parent = tile
				local mark = Instance.new("TextLabel")
				mark.Name = "Text"
				mark.BackgroundTransparency = 1
				mark.AnchorPoint = Vector2.new(0.5, 0.5)
				mark.Position = UDim2.fromScale(0.5, 0.55)
				mark.Size = UDim2.fromScale(1.5, 1.5)
				mark.Font = Enum.Font.PermanentMarker
				mark.TextScaled = true
				mark.Text = ""
				mark.Parent = gui
				tiles[side][key] = tile
			end
		end
	end
	divider(cf, model)

	local markers = Instance.new("Folder")
	markers.Name = "Markers"
	markers.Parent = model

	local seats = { chair(1, cf, model), chair(2, cf, model) }

	local anchor = block(
		"Sign",
		Vector3.new(0.2, 0.2, 0.2),
		cf * CFrame.new(0, top + 7, 0.75),
		BLACK,
		Enum.Material.SmoothPlastic,
		model
	)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(240, 70)
	billboard.MaxDistance = 80
	billboard.Parent = anchor
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.55)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 236, 170)
	title.TextStrokeTransparency = 0.4
	title.Text = "Table " .. id
	title.Parent = billboard
	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromScale(0, 0.55)
	status.Size = UDim2.fromScale(1, 0.4)
	status.Font = Enum.Font.GothamBold
	status.TextScaled = true
	status.TextColor3 = Color3.new(1, 1, 1)
	status.TextStrokeTransparency = 0.4
	status.Parent = billboard

	model.WorldPivot = cf
	model.Parent = parent
	return {
		id = id,
		model = model,
		cf = cf,
		seats = seats,
		tiles = tiles,
		markers = markers,
		title = title,
		status = status,
	}
end

return TableBuilder
