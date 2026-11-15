-- Builds one game table: a black table with two paper sheets side by side, a divider
-- between them, two chairs on the same side, and a floating sign.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
	local x0 = Config.SHEET_X[side] -- sheet centre; it spans x0-3.5..x0+3.5 and z -5.5..5.5
	local paper = block(
		"Sheet",
		Vector3.new(7, 0.04, 11),
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
				Vector3.new(0.05, 0.01, 11),
				cf * CFrame.new(x0 + x, y, 0),
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
				Vector3.new(7, 0.01, 0.05),
				cf * CFrame.new(x0, y, z),
				LINE,
				Enum.Material.SmoothPlastic,
				parent
			),
			parent
		)
	end
	local _, gui = topCanvas("Labels", Vector2.new(7, 11), cf * CFrame.new(x0, top + 0.06, 0), parent)
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
		Vector3.new(1.4, 5.5, 6),
		cf * CFrame.new(0, top + 2.75, 1.5),
		Color3.fromRGB(122, 74, 150),
		Enum.Material.SmoothPlastic,
		parent
	)
	block(
		"Trim",
		Vector3.new(1.5, 0.35, 6.1),
		cf * CFrame.new(0, top + 5.6, 1.5),
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

local function chair(side: number, cf: CFrame, parent: Instance): Seat
	-- Both chairs sit on the +Z side facing -Z, behind their player's sheet.
	local seatCf = cf * CFrame.new(Config.SHEET_X[side], 1.9, 8.4)
	local seat = Instance.new("Seat")
	seat.Name = "Seat" .. side
	seat.Anchored = true
	seat.Size = Vector3.new(3, 0.5, 2.6)
	seat.CFrame = seatCf
	seat.Color = BLACK
	seat.Material = Enum.Material.SmoothPlastic
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
	seat.Parent = parent
	for _, corner in
		{ Vector3.new(-1.3, 0, -1.1), Vector3.new(1.3, 0, -1.1), Vector3.new(-1.3, 0, 1.1), Vector3.new(1.3, 0, 1.1) }
	do
		block(
			"Leg",
			Vector3.new(0.25, 1.65, 0.25),
			seatCf * CFrame.new(corner.X, -1.07, corner.Z),
			Color3.fromRGB(70, 70, 76),
			Enum.Material.Metal,
			parent
		)
	end
	block(
		"Back",
		Vector3.new(3, 2.6, 0.3),
		seatCf * CFrame.new(0, 1.55, 1.3),
		BLACK,
		Enum.Material.SmoothPlastic,
		parent
	)
	return seat
end

function TableBuilder.build(id: number, cf: CFrame, parent: Instance): Refs
	local model = Instance.new("Model")
	model.Name = "Table" .. id
	local top = Config.TABLE_TOP

	block(
		"Deck",
		Vector3.new(24, 0.2, 24),
		cf * CFrame.new(0, 0.1, 3),
		Color3.fromRGB(196, 158, 112),
		Enum.Material.WoodPlanks,
		model
	)
	local tabletop = block(
		"Top",
		Vector3.new(20, 0.8, 13),
		cf * CFrame.new(0, top - 0.4, 0),
		BLACK,
		Enum.Material.SmoothPlastic,
		model
	)
	tabletop.Material = Enum.Material.Plastic
	for _, x in { -9.2, 9.2 } do
		for _, z in { -5.7, 5.7 } do
			block(
				"Leg",
				Vector3.new(0.7, top - 0.8, 0.7),
				cf * CFrame.new(x, (top - 0.8) / 2, z),
				BLACK,
				Enum.Material.SmoothPlastic,
				model
			)
		end
	end

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
					Vector3.new(1.9, 0.05, 1.9),
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
		cf * CFrame.new(0, top + 9, -1.2),
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
