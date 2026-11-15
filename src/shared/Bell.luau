-- Builds a chrome hotel bell: black base, silver dome, and a plunger on top.
local Bell = {}

Bell.SILVER = Color3.fromRGB(214, 212, 208)
Bell.SHINE = Color3.fromRGB(255, 248, 225)

local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- turns a cylinder's X axis to point up

local function part(
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	parent: Instance
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
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
		Vector3.new(0.34, 1.62, 1.62) * s,
		cf * CFrame.new(0, 0.17 * s, 0) * UPRIGHT,
		Color3.fromRGB(22, 22, 25),
		model
	)
	base.Material = Enum.Material.Plastic
	local dome =
		part("Dome", Enum.PartType.Ball, Vector3.one * 1.46 * s, cf * CFrame.new(0, 0.4 * s, 0), Bell.SILVER, model)
	dome.Reflectance = 0.12
	part(
		"Stem",
		Enum.PartType.Cylinder,
		Vector3.new(0.3, 0.12, 0.12) * s,
		cf * CFrame.new(0, 1.2 * s, 0) * UPRIGHT,
		Bell.SILVER,
		model
	)

	local knob =
		part("Knob", Enum.PartType.Ball, Vector3.one * 0.32 * s, cf * CFrame.new(0, 1.38 * s, 0), Bell.SILVER, model)
	knob.Reflectance = 0.12
	model.PrimaryPart = base
	return model
end

return Bell
