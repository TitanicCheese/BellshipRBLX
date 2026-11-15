-- Builds the sky island at runtime: a square studded platform, plaza with a giant bell, trees,
-- clouds, lighting, and the spawn. Returns where the game tables go.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bell = require(ReplicatedStorage.Shared.Bell)
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

-- An upright disc (cylinder) of radius r and height h, centred at pos.
local function disc(r: number, h: number, pos: Vector3, color: Color3, material: Enum.Material, parent: Instance): Part
	return part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(h, r * 2, r * 2),
		CFrame = CFrame.new(pos) * UPRIGHT,
		Color = color,
		Material = material,
	}, parent)
end

World.SIZE = 240 -- the island is a square this many studs across

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

-- A square, studded grass platform on a stepped base of dirt and rock that narrows downwards.
local function island(parent: Instance, rng: Random)
	local folder = Instance.new("Folder")
	folder.Name = "Island"
	folder.Parent = parent
	local size = World.SIZE
	local grass = Color3.fromRGB(75, 151, 75)
	local dirt = Color3.fromRGB(124, 92, 70)
	studded(Vector3.new(size, 4, size), Vector3.new(0, TOP - 2, 0), grass, folder)
	part({
		Size = Vector3.new(size, 6, size),
		CFrame = CFrame.new(0, TOP - 7, 0),
		Color = dirt,
		Material = Enum.Material.Plastic,
	}, folder)
	local y = TOP - 10
	for i, layer in { { 0.82, 10 }, { 0.6, 10 }, { 0.38, 10 }, { 0.16, 8 } } do
		local width, height = size * layer[1], layer[2]
		local shade = 120 - i * 10
		part({
			Size = Vector3.new(width, height, width),
			CFrame = CFrame.new(0, y - height / 2, 0),
			Color = Color3.fromRGB(shade, shade, shade + 4),
			Material = Enum.Material.Plastic,
		}, folder)
		y -= height
	end
	-- A few small studded islands floating around the big one.
	for _ = 1, 8 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(180, 230)
		local w = math.round(rng:NextNumber(6, 12))
		local pos = Vector3.new(math.cos(angle) * radius, TOP + rng:NextNumber(-35, 12), math.sin(angle) * radius)
		studded(Vector3.new(w, 2, w), pos, grass, folder)
		part({
			Size = Vector3.new(w * 0.7, w * 0.6, w * 0.7),
			CFrame = CFrame.new(pos - Vector3.new(0, 1 + w * 0.3, 0)),
			Color = dirt,
			Material = Enum.Material.Plastic,
		}, folder)
	end
end

local function plaza(parent: Instance): CFrame
	local folder = Instance.new("Folder")
	folder.Name = "Plaza"
	folder.Parent = parent
	part({
		Size = Vector3.new(44, 0.4, 44),
		CFrame = CFrame.new(0, TOP + 0.2, 0),
		Color = Color3.fromRGB(196, 196, 196),
		Material = Enum.Material.Plastic,
		TopSurface = Enum.SurfaceType.Studs,
	}, folder)
	disc(7, 3, Vector3.new(0, TOP + 1.9, 0), Color3.fromRGB(236, 232, 224), Enum.Material.Marble, folder)
	local statue = Bell.build(CFrame.new(0, TOP + 3.4, 0), 7)
	statue.Name = "GiantBell"
	for _, p in statue:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = true
			p.CanQuery = true
		end
	end
	statue.Parent = folder

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, TOP + 0.1, 14)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = folder
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
		local radius = rng:NextNumber(175, 320)
		local center = Vector3.new(math.cos(angle) * radius, TOP + rng:NextNumber(-90, 25), math.sin(angle) * radius)
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

export type WorldInfo = { spawn: CFrame, tables: { CFrame } }

function World.build(): WorldInfo
	local rng = Random.new(1337)
	local folder = Instance.new("Folder")
	folder.Name = "World"
	folder.Parent = workspace
	lighting()
	island(folder, rng)
	local spawn = plaza(folder)
	clouds(folder, rng)
	local trees = Instance.new("Folder")
	trees.Name = "Trees"
	trees.Parent = folder

	-- Tables in a grid behind the plaza, chairs facing the plaza. The rest of the island stays open.
	local tables = {}
	local columns, spacingX, spacingZ, firstZ = 5, 22, 22, -40
	for i = 1, Config.TABLE_COUNT do
		local col = (i - 1) % columns
		local row = (i - 1) // columns
		local x = (col - (columns - 1) / 2) * spacingX
		table.insert(tables, CFrame.new(x, TOP, firstZ - row * spacingZ))
	end

	-- Trees around the open grass, kept clear of the plaza, the spawn path and the table grid.
	local half = World.SIZE / 2 - 8
	local placed = 0
	while placed < 26 do
		local pos = Vector3.new(rng:NextNumber(-half, half), TOP, rng:NextNumber(-half, half))
		local nearPlaza = math.abs(pos.X) < 30 and math.abs(pos.Z) < 30
		local nearPath = math.abs(pos.X) < 12 and pos.Z > 0
		local nearTables = math.abs(pos.X) < 62 and pos.Z < -24
		if not (nearPlaza or nearPath or nearTables) then
			tree(pos, rng, trees)
			placed += 1
		end
	end
	return { spawn = spawn, tables = tables }
end

return World
