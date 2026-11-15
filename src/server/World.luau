-- Builds the sky island at runtime: a studded grass platform, trees, clouds, lighting, and the
-- spawn. Returns where the spawn, the game tables and the leaderboards go.
--
-- Layout (looking down, +Z towards the bottom): the tables fill a grid at the back, and the
-- spawn is a strip of open grass along the front edge with the leaderboards behind it, so
-- players spawn facing the tables and seated players face back towards the spawn.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local World = {}
World.TOP = 100 -- height of the island's grass surface
local TOP = World.TOP

local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)

local function part(props: { [string]: any }, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

-- The island's footprint on the ground: X from -WIDTH/2 to WIDTH/2, Z from BACK to FRONT.
World.WIDTH = 240
World.BACK = -120
World.FRONT = 0
local CENTER_Z = (World.BACK + World.FRONT) / 2
local DEPTH = World.FRONT - World.BACK

-- Table grid: 5 per row, rows going back from FIRST_ROW_Z.
local GRID_COLUMNS, GRID_SPACING, FIRST_ROW_Z = 5, 22, -40
-- The spawn strip and the leaderboards behind it, along the front edge.
local BOARD_Z, SPAWN_Z, BOARD_SPACING = World.FRONT - 6, World.FRONT - 11, 18

-- A plain block with classic Roblox studs on top.
local function studded(size: Vector3, pos: Vector3, color: Color3, parent: Instance): Part
	return part({
		Size = size,
		CFrame = CFrame.new(pos),
		Color = color,
		Material = Enum.Material.Plastic,
		TopSurface = Enum.SurfaceType.Studs,
	}, parent)
end

-- A studded grass platform on a stepped base of dirt and rock that narrows downwards.
local function island(parent: Instance, rng: Random)
	local folder = Instance.new("Folder")
	folder.Name = "Island"
	folder.Parent = parent
	local grass = Color3.fromRGB(75, 151, 75)
	local dirt = Color3.fromRGB(124, 92, 70)
	studded(Vector3.new(World.WIDTH, 4, DEPTH), Vector3.new(0, TOP - 2, CENTER_Z), grass, folder)
	part({
		Size = Vector3.new(World.WIDTH, 6, DEPTH),
		CFrame = CFrame.new(0, TOP - 7, CENTER_Z),
		Color = dirt,
		Material = Enum.Material.Plastic,
	}, folder)
	local y = TOP - 10
	for i, layer in { { 0.82, 10 }, { 0.6, 10 }, { 0.38, 10 }, { 0.16, 8 } } do
		local scale, height = layer[1], layer[2]
		local shade = 120 - i * 10
		part({
			Size = Vector3.new(World.WIDTH * scale, height, DEPTH * scale),
			CFrame = CFrame.new(0, y - height / 2, CENTER_Z),
			Color = Color3.fromRGB(shade, shade, shade + 4),
			Material = Enum.Material.Plastic,
		}, folder)
		y -= height
	end
	-- A few small studded islands floating around the big one.
	for _ = 1, 8 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(165, 210)
		local w = math.round(rng:NextNumber(6, 12))
		local pos = Vector3.new(
			math.cos(angle) * radius,
			TOP + rng:NextNumber(-35, 12),
			CENTER_Z + math.sin(angle) * radius * 0.7
		)
		studded(Vector3.new(w, 2, w), pos, grass, folder)
		part({
			Size = Vector3.new(w * 0.7, w * 0.6, w * 0.7),
			CFrame = CFrame.new(pos - Vector3.new(0, 1 + w * 0.3, 0)),
			Color = dirt,
			Material = Enum.Material.Plastic,
		}, folder)
	end
end

-- An invisible spawn strip in front of the leaderboards, facing the tables.
local function spawnStrip(parent: Instance): CFrame
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(BOARD_SPACING * 2 + 8, 1, 4)
	spawn.CFrame = CFrame.lookAt(Vector3.new(0, TOP - 0.4, SPAWN_Z), Vector3.new(0, TOP - 0.4, SPAWN_Z - 1))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = parent
	return spawn.CFrame
end

local function tree(pos: Vector3, rng: Random, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Tree"
	local height = rng:NextNumber(9, 14)
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 1.8, 1.8),
		CFrame = CFrame.new(pos + Vector3.new(0, height / 2, 0)) * UPRIGHT,
		Color = Color3.fromRGB(110, 76, 50),
		Material = Enum.Material.Wood,
	}, model)
	for _ = 1, 3 do
		local size = rng:NextNumber(6, 9)
		part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size,
			Position = pos + Vector3.new(rng:NextNumber(-2, 2), height + rng:NextNumber(-1, 2), rng:NextNumber(-2, 2)),
			Color = Color3.fromRGB(80 + rng:NextInteger(0, 20), 150 + rng:NextInteger(0, 25), 70),
			Material = Enum.Material.Grass,
		}, model)
	end
	model.Parent = parent
end

local function clouds(parent: Instance, rng: Random)
	local folder = Instance.new("Folder")
	folder.Name = "Clouds"
	folder.Parent = parent
	for _ = 1, 34 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(160, 300)
		local center = Vector3.new(
			math.cos(angle) * radius,
			TOP + rng:NextNumber(-90, 25),
			CENTER_Z + math.sin(angle) * radius * 0.8
		)
		for _ = 1, rng:NextInteger(3, 6) do
			part({
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * rng:NextNumber(10, 24),
				Position = center
					+ Vector3.new(rng:NextNumber(-14, 14), rng:NextNumber(-3, 4), rng:NextNumber(-10, 10)),
				Color = Color3.fromRGB(255, 255, 255),
				Material = Enum.Material.SmoothPlastic,
				Transparency = 0.08,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
			}, folder)
		end
	end
end

local function lighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(84, 82, 80)
	Lighting.OutdoorAmbient = Color3.fromRGB(152, 150, 148)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.15
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.12
	atmosphere.Color = Color3.fromRGB(205, 228, 255)
	atmosphere.Decay = Color3.fromRGB(130, 170, 220)
	atmosphere.Glare = 0.25
	atmosphere.Haze = 1.3
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 24
	bloom.Threshold = 2
	bloom.Parent = Lighting
	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.12
	color.Contrast = 0.05
	color.Parent = Lighting
	Instance.new("Sky").Parent = Lighting
end

export type WorldInfo = { spawn: CFrame, tables: { CFrame }, boards: { CFrame } }

function World.build(): WorldInfo
	local rng = Random.new(1337)
	local folder = Instance.new("Folder")
	folder.Name = "World"
	folder.Parent = workspace
	lighting()
	island(folder, rng)
	local spawn = spawnStrip(folder)
	clouds(folder, rng)
	local trees = Instance.new("Folder")
	trees.Name = "Trees"
	trees.Parent = folder

	-- Tables in a grid. A table's chairs are on its +Z side, so turning it around puts the chairs
	-- at the back and seated players look towards the spawn.
	local tables = {}
	local facing = CFrame.Angles(0, math.pi, 0)
	for i = 1, Config.TABLE_COUNT do
		local col = (i - 1) % GRID_COLUMNS
		local row = (i - 1) // GRID_COLUMNS
		local x = (col - (GRID_COLUMNS - 1) / 2) * GRID_SPACING
		table.insert(tables, CFrame.new(x, TOP, FIRST_ROW_Z - row * GRID_SPACING) * facing)
	end

	-- Leaderboards side by side along the front edge, facing the tables.
	local boards = {}
	for i = -1, 1 do
		local pos = Vector3.new(i * BOARD_SPACING, TOP, BOARD_Z)
		table.insert(boards, CFrame.lookAt(pos, pos - Vector3.zAxis))
	end

	-- Trees on the open grass beside the tables, clear of the grid and the spawn.
	local half = World.WIDTH / 2 - 8
	local gridHalf = (GRID_COLUMNS - 1) / 2 * GRID_SPACING + 14
	local placed = 0
	while placed < 18 do
		local pos = Vector3.new(rng:NextNumber(-half, half), TOP, rng:NextNumber(World.BACK + 8, World.FRONT - 8))
		local nearTables = math.abs(pos.X) < gridHalf
		local nearSpawn = math.abs(pos.X) < BOARD_SPACING * 2 + 12 and pos.Z > FIRST_ROW_Z + 8
		if not (nearTables or nearSpawn) then
			tree(pos, rng, trees)
			placed += 1
		end
	end
	return { spawn = spawn, tables = tables, boards = boards }
end

return World
