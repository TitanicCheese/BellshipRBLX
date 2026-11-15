-- Builds the hotel bell model: a dark base, a golden dome, and a plunger on top.
local Bell = {}

Bell.GOLD = Color3.fromRGB(235, 170, 40)
Bell.TARNISH = Color3.fromRGB(128, 116, 98)

local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- turns a cylinder's X axis to point up

local function part(
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- `cf` is the point on the surface the bell stands on. `scale` 1 fits one board square.
function Bell.build(cf: CFrame, scale: number?): Model
	local s = scale or 1
	local model = Instance.new("Model")
	model.Name = "Bell"
	local base = part(
		"Base",
		Enum.PartType.Cylinder,
		Vector3.new(0.22, 1.5, 1.5) * s,
		cf * CFrame.new(0, 0.11 * s, 0) * UPRIGHT,
		Color3.fromRGB(45, 32, 26),
		Enum.Material.Wood,
		model
	)
	local dome = part(
		"Dome",
		Enum.PartType.Ball,
		Vector3.one * 1.25 * s,
		cf * CFrame.new(0, 0.22 * s, 0),
		Bell.GOLD,
		Enum.Material.SmoothPlastic,
		model
	)
	dome.Reflectance = 0.12
	part(
		"Stem",
		Enum.PartType.Cylinder,
		Vector3.new(0.3, 0.12, 0.12) * s,
		cf * CFrame.new(0, 0.95 * s, 0) * UPRIGHT,
		Color3.fromRGB(200, 200, 205),
		Enum.Material.Metal,
		model
	)
	local knob = part(
		"Knob",
		Enum.PartType.Ball,
		Vector3.one * 0.3 * s,
		cf * CFrame.new(0, 1.12 * s, 0),
		Color3.fromRGB(215, 215, 220),
		Enum.Material.SmoothPlastic,
		model
	)
	knob.Reflectance = 0.2
	model.PrimaryPart = base
	return model
end

return Bell
