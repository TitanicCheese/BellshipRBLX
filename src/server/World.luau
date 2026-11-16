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
local BOARD_Z, SPAWN_Z, BOARD_SPACING = World.FRONT - 6, World.FRONT - 11, 30
-- Each board has its pedestal on its -X side, so the row is shifted +X to stay centred.
local BOARD_SHIFT = 3

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

-- Voxel trees: stepped roots, a square trunk that forks into branches, and tilted leaf blocks
-- covered in smaller cubes, with dark cubes underneath and light ones catching the sun on top.
local BARK = Color3.fromRGB(104, 72, 48)
local BARK_DARK = Color3.fromRGB(82, 56, 38)
local LEAF = Color3.fromRGB(86, 162, 72)
local LEAF_DARK = Color3.fromRGB(64, 130, 58)
local LEAF_LIGHT = Color3.fromRGB(118, 192, 86)
local LEAF_SHINE = Color3.fromRGB(168, 222, 112)

local function block(size: Vector3, cf: CFrame, color: Color3, parent: Instance): Part
	return part({ Size = size, CFrame = cf, Color = color, Material = Enum.Material.SmoothPlastic }, parent)
end

-- A square beam of the given thickness from a to b.
local function beam(a: Vector3, b: Vector3, thickness: number, color: Color3, parent: Instance)
	local length = (b - a).Magnitude
	block(Vector3.new(thickness, thickness, length + thickness * 0.6), CFrame.lookAt((a + b) / 2, b), color, parent)
end

local function leaves(center: Vector3, size: number, rng: Random, parent: Instance)
	local cf = CFrame.new(center)
		* CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.25, 0.25))
	local main = Vector3.new(size, size * 0.72, size * rng:NextNumber(0.8, 1))
	block(main, cf, LEAF, parent)
	-- A darker block underneath so the canopy has a shaded bottom.
	block(main * Vector3.new(0.86, 0.3, 0.86), cf * CFrame.new(0, -main.Y / 2, 0), LEAF_DARK, parent)

	-- Chunks sticking out of the sides and top.
	local function onSurface(inset: number, top: boolean?): CFrame
		local face = if top then 2 else rng:NextInteger(1, 3)
		local sign = if top then 1 else (if rng:NextNumber() < 0.5 then 1 else -1)
		local offset = Vector3.new(
			rng:NextNumber(-0.45, 0.45) * main.X,
			rng:NextNumber(-0.3, 0.45) * main.Y,
			rng:NextNumber(-0.45, 0.45) * main.Z
		)
		local half = main / 2 - Vector3.one * inset
		if face == 1 then
			offset = Vector3.new(sign * half.X, offset.Y, offset.Z)
		elseif face == 2 then
			offset = Vector3.new(offset.X, sign * half.Y, offset.Z)
		else
			offset = Vector3.new(offset.X, offset.Y, sign * half.Z)
		end
		return cf * CFrame.new(offset)
	end
	for _ = 1, rng:NextInteger(4, 6) do
		local s = size * rng:NextNumber(0.28, 0.45)
		local shade = if rng:NextNumber() < 0.4 then LEAF_LIGHT else LEAF
		block(Vector3.new(s, s * 0.8, s), onSurface(s * 0.2), shade, parent)
	end
	for _ = 1, rng:NextInteger(2, 3) do
		local s = size * rng:NextNumber(0.25, 0.35)
		block(Vector3.new(s, s * 0.6, s), onSurface(s * 0.15, true), LEAF_LIGHT, parent)
	end
	-- Small bright cubes catching the light, and a few dark ones hanging below.
	for _ = 1, rng:NextInteger(7, 11) do
		local s = rng:NextNumber(0.7, 1.3)
		local p = block(Vector3.one * s, onSurface(s * 0.1, rng:NextNumber() < 0.5), LEAF_SHINE, parent)
		p.CanCollide = false
	end
	for _ = 1, rng:NextInteger(2, 4) do
		local s = rng:NextNumber(0.8, 1.4)
		local p = block(
			Vector3.one * s,
			cf
				* CFrame.new(
					rng:NextNumber(-0.4, 0.4) * main.X,
					-main.Y / 2 - s * 0.2,
					rng:NextNumber(-0.4, 0.4) * main.Z
				),
			LEAF_DARK,
			parent
		)
		p.CanCollide = false
	end
end

local function tree(pos: Vector3, rng: Random, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Tree"
	local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)

	-- Stepped roots around a wide base.
	block(Vector3.new(2.6, 1.2, 2.6), CFrame.new(pos + Vector3.new(0, 0.6, 0)) * yaw, BARK_DARK, model)
	for i = 0, 3 do
		local dir = (yaw * CFrame.Angles(0, i * math.pi / 2 + rng:NextNumber(-0.3, 0.3), 0)).LookVector
		local reach = rng:NextNumber(1.6, 2.4)
		block(
			Vector3.new(1, rng:NextNumber(0.5, 0.9), reach),
			CFrame.lookAt(
				pos + dir * (reach / 2 + 0.6) + Vector3.new(0, 0.35, 0),
				pos + dir * 5 + Vector3.new(0, 0.35, 0)
			),
			BARK_DARK,
			model
		)
	end

	-- Trunk up to the fork, leaning slightly.
	local forkHeight = rng:NextNumber(5.5, 7.5)
	local lean = Vector3.new(rng:NextNumber(-0.8, 0.8), 0, rng:NextNumber(-0.8, 0.8))
	local fork = pos + Vector3.new(0, forkHeight, 0) + lean
	beam(pos + Vector3.new(0, 1, 0), fork, 1.6, BARK, model)

	-- Two or three branches, each ending in a leaf cluster.
	local branches = rng:NextInteger(2, 3)
	local start = rng:NextNumber(0, math.pi * 2)
	for i = 1, branches do
		local angle = start + (i - 1) * (math.pi * 2 / branches) + rng:NextNumber(-0.4, 0.4)
		local out = rng:NextNumber(2.5, 4)
		local tip = fork + Vector3.new(math.cos(angle) * out, rng:NextNumber(3.5, 5.5), math.sin(angle) * out)
		beam(fork, tip, rng:NextNumber(0.9, 1.2), BARK, model)
		leaves(tip + Vector3.new(0, 1.5, 0), rng:NextNumber(5.5, 7.5), rng, model)
	end
	model.Parent = parent
end

-- One puffy cartoon cloud: a row of white ellipsoids, biggest in the middle, with a flat-ish
-- underside, lying across the direction it is seen from.
local function cloud(center: Vector3, scale: number, facing: Vector3, rng: Random, parent: Instance)
	local cf = CFrame.lookAt(center, center + facing)
	local puffs = rng:NextInteger(4, 7)
	local width = scale * rng:NextNumber(26, 40)
	for i = 1, puffs do
		local f = (i - 1) / (puffs - 1)
		local bulge = 0.55 + 0.45 * math.sin(f * math.pi)
		local r = scale * rng:NextNumber(7, 10) * bulge
		local x = (f - 0.5) * width
		local blob = part({
			Size = Vector3.new(r * 2.4, r * 1.8, r * 2),
			CFrame = cf * CFrame.new(x, r * 0.55, rng:NextNumber(-0.3, 0.3) * r),
			Color = Color3.fromRGB(255, 255, 255),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		}, parent)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = blob
	end
	-- A wide, flat, slightly blue base so each cloud has a cartoon shaded bottom.
	local base = part({
		Size = Vector3.new(width + scale * 14, scale * 5, scale * 16),
		CFrame = cf,
		Color = Color3.fromRGB(222, 238, 255),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	}, parent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = base
end

-- Rings of clouds all the way around the island at several distances, so they drift past each
-- other as you move, and a sea of clouds far below.
local function clouds(parent: Instance, rng: Random)
	local folder = Instance.new("Folder")
	folder.Name = "Clouds"
	folder.Parent = parent
	local middle = Vector3.new(0, TOP, CENTER_Z)
	local rings = {
		-- count, min radius, max radius, min height, max height, min scale, max scale
		{ 16, 175, 240, -35, 30, 0.7, 1.1 },
		{ 22, 330, 460, -50, 70, 1.6, 2.4 },
		{ 28, 650, 850, -90, 60, 3.2, 4.6 },
	}
	for _, ring in rings do
		local count = ring[1]
		for i = 1, count do
			local angle = (i + rng:NextNumber(-0.35, 0.35)) / count * math.pi * 2
			local radius = rng:NextNumber(ring[2], ring[3])
			local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local center = middle + out * radius + Vector3.new(0, rng:NextNumber(ring[4], ring[5]), 0)
			cloud(center, rng:NextNumber(ring[6], ring[7]), -out, rng, folder)
		end
	end
	-- The cloud sea under the island.
	for _ = 1, 40 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = math.sqrt(rng:NextNumber(0, 1)) * 750
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local center = middle + out * radius + Vector3.new(0, rng:NextNumber(-190, -160), 0)
		cloud(center, rng:NextNumber(3, 5), Vector3.new(-out.Z, 0, out.X), rng, folder)
	end
end

local function lighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(84, 82, 80)
	Lighting.OutdoorAmbient = Color3.fromRGB(152, 150, 148)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.15
	-- Light atmosphere tinted to the sky's horizon colour, so distant things fade into it.
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.22
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(196, 238, 255)
	atmosphere.Decay = Color3.fromRGB(120, 196, 250)
	atmosphere.Glare = 0
	atmosphere.Haze = 0.4
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
	-- A cartoon skybox: a smooth blue gradient (drawn by tools/sky/gen.py); the clouds are parts.
	local sky = Instance.new("Sky")
	local side = "rbxassetid://110171074745610"
	sky.SkyboxBk, sky.SkyboxFt, sky.SkyboxLf, sky.SkyboxRt = side, side, side, side
	sky.SkyboxUp = "rbxassetid://117585785896620"
	sky.SkyboxDn = "rbxassetid://89941321717010"
	sky.StarCount = 0
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 0
	sky.Parent = Lighting
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
	-- Wins first at +X, which is the left side when you face the boards.
	for i = 1, -1, -1 do
		local pos = Vector3.new(i * BOARD_SPACING + BOARD_SHIFT, TOP, BOARD_Z)
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
