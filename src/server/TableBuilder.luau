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
		Vector3.new(1, 4, 4.2),
		cf * CFrame.new(0, top + 2, 1),
		Color3.fromRGB(122, 74, 150),
		Enum.Material.SmoothPlastic,
		parent
	)
	block(
		"Trim",
		Vector3.new(1.1, 0.3, 4.3),
		cf * CFrame.new(0, top + 4.1, 1),
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
	local inset = 0.35
	local apronY = top - 0.5 - 0.35
	block(
		"Apron",
		Vector3.new(w - 2 * inset, 0.7, 0.2),
		cf * CFrame.new(0, apronY, d / 2 - inset),
		wood,
		Enum.Material.Wood,
		model
	)
	block(
		"Apron",
		Vector3.new(w - 2 * inset, 0.7, 0.2),
		cf * CFrame.new(0, apronY, -(d / 2 - inset)),
		wood,
		Enum.Material.Wood,
		model
	)
	block(
		"Apron",
		Vector3.new(0.2, 0.7, d - 2 * inset),
		cf * CFrame.new(w / 2 - inset, apronY, 0),
		wood,
		Enum.Material.Wood,
		model
	)
	block(
		"Apron",
		Vector3.new(0.2, 0.7, d - 2 * inset),
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
			local lx, lz = x * (w / 2 - inset - 0.2), z * (d / 2 - inset - 0.2)
			for i = 1, sections do
				local t = (i - 0.5) / sections -- 0 at the top, 1 at the floor
				local width = 0.6 - 0.25 * t
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

-- A square stick running from point a to point b (both in world space).
local function beam(
	name: string,
	a: Vector3,
	b: Vector3,
	width: number,
	depth: number,
	color: Color3,
	parent: Instance
): Part
	local p = block(
		name,
		Vector3.new(width, depth, (b - a).Magnitude),
		CFrame.lookAt((a + b) / 2, b),
		color,
		Enum.Material.Wood,
		parent
	)
	return p
end

-- A dark wooden dining chair: tapered legs with stretchers, a seat with a rounded front edge,
-- and a back that leans back, with a curved crest rail over a row of spindles.
-- Built facing -Z with its back at +Z.
local function chair(side: number, cf: CFrame, parent: Instance): Seat
	local model = Instance.new("Model")
	model.Name = "Chair" .. side
	local frame = Color3.fromRGB(78, 42, 24)
	local seatWood = Color3.fromRGB(122, 64, 34)
	local base = cf * CFrame.new(Config.SHEET_X[side], 0, Config.CHAIR_Z) -- floor under the seat centre
	local seatTop = 2.2
	local w, d = 2.3, 2.2 -- seat width and depth
	local function at(x: number, y: number, z: number): Vector3
		return base:PointToWorldSpace(Vector3.new(x, y, z))
	end

	local seat = Instance.new("Seat")
	seat.Name = "Seat" .. side
	seat.Anchored = true
	seat.Size = Vector3.new(w, 0.22, d - 0.2)
	seat.CFrame = base * CFrame.new(0, seatTop - 0.11, 0.1)
	seat.Color = seatWood
	seat.Material = Enum.Material.Wood
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
	seat.Parent = model
	-- Rounded front edge: a cylinder along the seat front.
	local nose = block(
		"SeatEdge",
		Vector3.new(w, 0.22, 0.22),
		base * CFrame.new(0, seatTop - 0.11, -d / 2 + 0.1),
		seatWood,
		Enum.Material.Wood,
		model
	)
	nose.Shape = Enum.PartType.Cylinder

	-- Legs taper towards the floor and splay out a little; back legs kick backwards.
	local lx, lz = w / 2 - 0.14, d / 2 - 0.14
	local legTop = seatTop - 0.22
	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local x, z = corner[1] * lx, corner[2] * lz
		local foot = at(x * 1.06, 0, z + (if corner[2] > 0 then 0.18 else -0.04))
		local knee = at(x, legTop / 2, z + (if corner[2] > 0 then 0.06 else 0))
		beam("Leg", at(x, legTop, z), knee, 0.22, 0.22, frame, model)
		beam("Leg", knee, foot, 0.17, 0.17, frame, model)
	end
	-- Stretchers between the legs, and an apron under the seat edge.
	for _, x in { -lx, lx } do
		beam("Stretcher", at(x * 1.03, 0.65, -lz - 0.02), at(x * 1.03, 0.65, lz + 0.1), 0.1, 0.12, frame, model)
	end
	beam("Stretcher", at(-lx * 1.02, 0.9, -lz), at(lx * 1.02, 0.9, -lz), 0.1, 0.12, frame, model)
	block(
		"Apron",
		Vector3.new(w - 0.3, 0.26, 0.1),
		base * CFrame.new(0, legTop - 0.13, -lz),
		frame,
		Enum.Material.Wood,
		model
	)
	block(
		"Apron",
		Vector3.new(0.1, 0.26, d - 0.3),
		base * CFrame.new(-lx, legTop - 0.13, 0),
		frame,
		Enum.Material.Wood,
		model
	)
	block(
		"Apron",
		Vector3.new(0.1, 0.26, d - 0.3),
		base * CFrame.new(lx, legTop - 0.13, 0),
		frame,
		Enum.Material.Wood,
		model
	)

	-- The back leans 12 degrees. Positions in the back are (x, height above seat, curve depth).
	local lean = math.rad(12)
	local back = base * CFrame.new(0, seatTop, lz) * CFrame.Angles(lean, 0, 0)
	local function onBack(x: number, y: number, z: number): Vector3
		return back:PointToWorldSpace(Vector3.new(x, y, z))
	end
	local height = 2.25
	local function curve(x: number): number
		return 0.16 * (1 - (x / (w / 2)) ^ 2) -- the crest rail bows backwards in the middle
	end
	for _, x in { -lx, lx } do
		beam("Post", at(x, legTop, lz), onBack(x, height + 0.1, 0), 0.2, 0.2, frame, model)
	end
	-- Crest rail in short segments along the curve, taller in the middle.
	local segments = 6
	for i = 1, segments do
		local x1 = -lx + (i - 1) * (2 * lx) / segments
		local x2 = -lx + i * (2 * lx) / segments
		local mid = (x1 + x2) / 2
		local tall = 0.34 + 0.12 * (1 - math.abs(mid) / lx)
		beam(
			"CrestRail",
			onBack(x1, height - tall / 2 + 0.1, curve(x1)),
			onBack(x2, height - tall / 2 + 0.1, curve(x2)),
			tall,
			0.14,
			frame,
			model
		)
	end
	beam("BackRail", onBack(-lx, 0.4, 0), onBack(lx, 0.4, 0), 0.12, 0.12, frame, model)
	local spindles = 9
	for i = 1, spindles do
		local x = -lx + 0.22 + (i - 1) * (2 * lx - 0.44) / (spindles - 1)
		local tall = 0.34 + 0.12 * (1 - math.abs(x) / lx)
		beam("Spindle", onBack(x, 0.45, 0), onBack(x, height - tall + 0.12, curve(x)), 0.07, 0.07, frame, model)
	end

	model.Parent = parent
	return seat
end

function TableBuilder.build(id: number, cf: CFrame, parent: Instance): Refs
	local model = Instance.new("Model")
	model.Name = "Table" .. id
	local top = Config.TABLE_TOP

	block(
		"Deck",
		Vector3.new(17, 0.2, 17),
		cf * CFrame.new(0, 0.1, 2),
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
		cf * CFrame.new(0, top + 7, 1),
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
