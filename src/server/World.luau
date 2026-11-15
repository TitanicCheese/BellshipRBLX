-- Builds the sky island at runtime: floating rock, grass, plaza with a giant bell, trees,
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

local function island(parent: Instance, rng: Random)
	local folder = Instance.new("Folder")
	folder.Name = "Island"
	folder.Parent = parent
	disc(75, 4, Vector3.new(0, TOP - 2, 0), Color3.fromRGB(104, 162, 72), Enum.Material.Grass, folder)
	disc(73, 6, Vector3.new(0, TOP - 6.5, 0), Color3.fromRGB(122, 92, 62), Enum.Material.Ground, folder)
	local layers = { { 66, 10 }, { 54, 12 }, { 40, 14 }, { 26, 14 }, { 13, 12 }, { 5, 10 } }
	local y = TOP - 9.5
	for i, layer in layers do
		local r, h = layer[1], layer[2]
		y -= h / 2
		local shade = 112 - i * 6
		local offset = Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
		disc(
			r,
			h,
			Vector3.new(0, y, 0) + offset,
			Color3.fromRGB(shade, shade - 4, shade - 8),
			Enum.Material.Rock,
			folder
		)
		y -= h / 2 - 1
	end
	-- Jagged rocks around the underside so the island does not look like a stack of discs.
	for _ = 1, 26 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local depth = rng:NextNumber(10, 45)
		local radius = math.max(8, 70 - depth * 1.2) * rng:NextNumber(0.8, 1)
		local size = Vector3.new(rng:NextNumber(8, 16), rng:NextNumber(10, 22), rng:NextNumber(8, 16))
		part({
			Size = size,
			CFrame = CFrame.new(math.cos(angle) * radius, TOP - 8 - depth, math.sin(angle) * radius)
				* CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6), rng:NextNumber(-0.5, 0.5)),
			Color = Color3.fromRGB(96, 90, 84),
			Material = Enum.Material.Rock,
		}, folder)
	end
	-- Small floating rocks.
	for _ = 1, 10 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(95, 140)
		local pos = Vector3.new(math.cos(angle) * radius, TOP + rng:NextNumber(-40, 15), math.sin(angle) * radius)
		local r = rng:NextNumber(3, 7)
		disc(r, r * 0.6, pos + Vector3.new(0, r * 0.3, 0), Color3.fromRGB(104, 162, 72), Enum.Material.Grass, folder)
		part({
			Size = Vector3.new(r * 1.6, r * 1.6, r * 1.6),
			CFrame = CFrame.new(pos - Vector3.new(0, r * 0.6, 0)) * CFrame.Angles(0.6, rng:NextNumber(0, 6), 0.6),
			Color = Color3.fromRGB(100, 94, 88),
			Material = Enum.Material.Rock,
		}, folder)
	end
end

local function plaza(parent: Instance): CFrame
	local folder = Instance.new("Folder")
	folder.Name = "Plaza"
	folder.Parent = parent
	disc(22, 0.4, Vector3.new(0, TOP + 0.2, 0), Color3.fromRGB(214, 206, 190), Enum.Material.Slate, folder)
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
		local radius = rng:NextNumber(90, 230)
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
	Lighting.Ambient = Color3.fromRGB(80, 80, 92)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 158, 178)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
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
	bloom.Threshold = 1.4
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

	-- Tables in a ring around the plaza, long side pointing at the centre.
	local tables = {}
	local center = Vector3.new(0, TOP, 0)
	for i = 1, Config.TABLE_COUNT do
		local angle = (i - 1) / Config.TABLE_COUNT * math.pi * 2
		local pos = Vector3.new(math.cos(angle) * 46, TOP, math.sin(angle) * 46)
		table.insert(tables, CFrame.lookAt(pos, center))
		local treeAngle = angle + math.pi / Config.TABLE_COUNT
		tree(Vector3.new(math.cos(treeAngle) * 64, TOP, math.sin(treeAngle) * 64), rng, trees)
	end
	return { spawn = spawn, tables = tables }
end

return World
