-- Builds one game table: tabletop with two 3x5 boards, two chairs, and a floating sign.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local TableBuilder = {}

TableBuilder.TILE_COLOR = Color3.fromRGB(238, 228, 205)

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

local WOOD = Color3.fromRGB(150, 102, 64)
local DARK = Color3.fromRGB(72, 50, 38)

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

local function chair(side: number, cf: CFrame, parent: Instance): Seat
	local s = if side == 1 then 1 else -1
	-- Side 1 faces -Z (towards the table), side 2 is turned around.
	local seatCf = cf * CFrame.new(0, 1.9, s * 10.2) * CFrame.Angles(0, if side == 1 then 0 else math.pi, 0)
	local seat = Instance.new("Seat")
	seat.Name = "Seat" .. side
	seat.Anchored = true
	seat.Size = Vector3.new(3, 0.5, 2.6)
	seat.CFrame = seatCf
	seat.Color = Color3.fromRGB(178, 124, 80)
	seat.Material = Enum.Material.Wood
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
	seat.Parent = parent
	for _, corner in
		{ Vector3.new(-1.3, 0, -1.1), Vector3.new(1.3, 0, -1.1), Vector3.new(-1.3, 0, 1.1), Vector3.new(1.3, 0, 1.1) }
	do
		block(
			"Leg",
			Vector3.new(0.3, 1.65, 0.3),
			seatCf * CFrame.new(corner.X, -1.07, corner.Z),
			DARK,
			Enum.Material.Wood,
			parent
		)
	end
	block(
		"Back",
		Vector3.new(3, 2.6, 0.3),
		seatCf * CFrame.new(0, 1.55, 1.3),
		Color3.fromRGB(178, 124, 80),
		Enum.Material.Wood,
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
		Vector3.new(16, 0.2, 32),
		cf * CFrame.new(0, 0.1, 0),
		Color3.fromRGB(196, 158, 112),
		Enum.Material.WoodPlanks,
		model
	)
	block("Top", Vector3.new(12, 0.8, 16), cf * CFrame.new(0, top - 0.4, 0), WOOD, Enum.Material.Wood, model)
	for _, x in { -5.2, 5.2 } do
		for _, z in { -7.2, 7.2 } do
			block(
				"Leg",
				Vector3.new(0.8, top - 0.8, 0.8),
				cf * CFrame.new(x, (top - 0.8) / 2, z),
				DARK,
				Enum.Material.Wood,
				model
			)
		end
	end
	block("Divider", Vector3.new(12, 0.35, 0.3), cf * CFrame.new(0, top + 0.175, 0), DARK, Enum.Material.Wood, model)

	local tilesFolder = Instance.new("Folder")
	tilesFolder.Name = "Tiles"
	tilesFolder.Parent = model
	local tiles = { {}, {} }
	for side = 1, 2 do
		local s = if side == 1 then 1 else -1
		block(
			"Board",
			Vector3.new(10.2, 0.1, 6.2),
			cf * CFrame.new(0, top + 0.05, s * 3.5),
			DARK,
			Enum.Material.Wood,
			model
		)
		for row = 1, Config.ROWS do
			for col = 1, Config.COLS do
				local key = Config.key(row, col)
				local tile = block(
					key,
					Vector3.new(1.8, 0.1, 1.8),
					cf * CFrame.new(Config.cellOffset(side, row, col) - Vector3.new(0, 0.05, 0)),
					TableBuilder.TILE_COLOR,
					Enum.Material.SmoothPlastic,
					tilesFolder
				)
				tile:SetAttribute("Table", id)
				tile:SetAttribute("Side", side)
				tile:SetAttribute("Key", key)
				local gui = Instance.new("SurfaceGui")
				gui.Face = Enum.NormalId.Top
				gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				gui.PixelsPerStud = 60
				gui.LightInfluence = 1
				gui.Parent = tile
				local label = Instance.new("TextLabel")
				label.Name = "Label"
				label.BackgroundTransparency = 1
				label.AnchorPoint = Vector2.new(0.5, 0.5)
				label.Position = UDim2.fromScale(0.5, 0.5)
				label.Size = UDim2.fromScale(0.7, 0.7)
				label.Font = Enum.Font.FredokaOne
				label.TextScaled = true
				label.Text = key
				label.Rotation = 90
				label.TextColor3 = Color3.fromRGB(140, 110, 80)
				label.TextTransparency = 0.45
				label.Parent = gui
				tiles[side][key] = tile
			end
		end
	end

	local markers = Instance.new("Folder")
	markers.Name = "Markers"
	markers.Parent = model

	local seats = { chair(1, cf, model), chair(2, cf, model) }

	local anchor = block(
		"Sign",
		Vector3.new(0.2, 0.2, 0.2),
		cf * CFrame.new(0, top + 7.5, 0),
		DARK,
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
