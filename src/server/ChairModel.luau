-- The wooden dining chair the user picked from the Creator Store, stored as part data so it is
-- in git. Positions are relative to the bottom centre of the chair, which faces -Z with its
-- back at +Z. Regenerate by dumping the parts of a model the same way if the chair changes.
local ChairModel = {}

ChairModel.SEAT_HEIGHT = 2.075 -- floor to the top of the seat
ChairModel.SEAT_SIZE = Vector2.new(2.15, 1.85) -- seat width (X) and depth (Z)
ChairModel.SEAT_OFFSET = Vector2.new(0, -0.1426) -- seat centre relative to the chair centre

type PartData = {
	class: string,
	size: { number },
	cframe: { number },
	color: { number },
	material: string,
	shape: string?,
	transparency: number?,
	reflectance: number?,
}

local PARTS: { PartData } = {
	{
		class = "Part",
		size = { 0.125, 0.175, 0.175 },
		cframe = { -0.9875, 2.0125, 0.7949, 0, -1, 0, 1, 0, 0, 0, 0, 1 },
		color = { 121, 85, 65 },
		material = "Wood",
		shape = "Cylinder",
	},
	{
		class = "Part",
		size = { 0.125, 0.175, 0.175 },
		cframe = { -0.9875, 2.0125, -1.0801, 0, -1, 0, 1, 0, 0, 0, 0, 1 },
		color = { 121, 85, 65 },
		material = "Wood",
		shape = "Cylinder",
	},
	{
		class = "Part",
		size = { 0.45, 0.15, 0.175 },
		cframe = { -0.9375, 2.1495, 0.8215, 0, 0, -1, -1, 0, 0, 0, 1, 0 },
		color = { 121, 85, 65 },
		material = "Wood",
	},
	{
		class = "Part",
		size = { 1.95, 0.15, 0.1 },
		cframe = { -0.975, 0.975, -1.0426, 0, 0, -1, -1, 0, 0, 0, 1, 0 },
		color = { 121, 85, 65 },
		material = "Wood",
	},
	{
		class = "Part",
		size = { 1.25, 0.15, 0.1 },
		cframe = { -0.875, 1.325, -1.0426, 0, 0, -1, -1, 0, 0, 0, 1, 0 },
		color = { 121, 85, 65 },
		material = "Wood",
	},
	{
		class = "Part",
		size = { 1.6, 0.15, 0.175 },
		cframe = { -0.9375, 3.1633, 0.8915, 0, 0, -1, -0.9962, -0.0872, 0, -0.0872, 0.9962, 0 },
		color = { 121, 85, 65 },
		material = "Wood",
	},
	{
		class = "Part",
		size = { 1.7, 0.15, 0.175 },
		cframe = { -0.9375, 1.0995, 0.8965, 0, 0, -1, -0.9962, 0.0872, 0, 0.0872, 0.9962, 0 },
		color = { 121, 85, 65 },
		material = "Wood",
	},
	{
		class = "WedgePart",
		size = { 0.15, 0.1, 0.7 },
		cframe = { -0.875, 0.35, -1.0426, 0, 1, 0, 0, 0, 1, 1, 0, 0 },
		color = { 121, 85, 65 },
		material = "Wood",
	},
	{
		class = "Part",
		size = { 0.0761, 0.15, 0.175 },
		cframe = { -0.9377, 0.038, 1.0217, 0, 0, -1, -1, 0, 0, 0, 1, 0 },
		color = { 121, 85, 65 },
		material = "Wood",
	},
	{
		class = "Part",
		size = { 0.2271, 0.15, 0.175 },
		cframe = { -0.9375, 0.1647, 0.995, 0, 0, -1, -0.9659, 0.2588, 0, 0.2588, 0.9659, 0 },
		color = { 121, 85, 65 },
		material = "Wood",
	},
	{
		class = "Part",
		size = { 1.875, 0.05, 0.175 },
		cframe = { -0.2339, 3.401, 0.9123, 0.0023, 0, -1, -0.9962, -0.0872, -0.0023, -0.0872, 0.9962, -0.0002 },
		color = { 121, 85, 65 },
		material = "Wood",
	},
	{
		class = "Part",
		size = { 1.875, 0.05, 0.175 },
		cframe = { -0.5589, 3.4003, 0.9122, 0.0023, 0, -1, -0.9962, -0.0872, -0.0023, -0.0872, 0.9962, -0.0002 },
		color = { 121, 85, 65 },
		material = "Wood",
	},
	{
		class = "Part",
		size = { 0.1, 1.95, 0.125 },
		cframe = { 0, 2.0125, 0.8324, 0, 1, 0, 0, 0, -1, -1, 0, 0 },
		color = { 121, 85, 65 },
		material = "Wood",
	},
	{
		class = "Part",
		size = { 0.1, 1.95, 0.125 },
		cframe = { 0, 2.0125, -1.1176, 0, 1, 0, 0, 0, -1, -1, 0, 0 },
		color = { 121, 85, 65 },
		material = "Wood",
	},
	{
		class = "Part",
		size = { 1.85, 2.15, 0.125 },
		cframe = { 0, 2.0125, -0.1426, 0, 1, 0, 0, 0, -1, -1, 0, 0 },
		color = { 121, 85, 65 },
		material = "Wood",
	},
	{
		class = "Part",
		size = { 0.5186, 0.15, 0.175 },
		cframe = { -0.9375, 4.2056, 1.0067, 0, 0, -1, -0.9848, -0.1736, 0, -0.1736, 0.9848, 0 },
		color = { 121, 85, 65 },
		material = "Wood",
	},
	{
		class = "Part",
		size = { 1.95, 1.9, 0.3 },
		cframe = { 0, 1.8, -0.1176, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
		color = { 121, 85, 65 },
		material = "Wood",
	},
	{
		class = "Part",
		size = { 1.875, 0.05, 0.175 },
		cframe = { 0.1661, 3.402, 0.9123, 0.0023, 0, -1, -0.9962, -0.0872, -0.0023, -0.0872, 0.9962, -0.0002 },
		color = { 121, 85, 65 },
		material = "Wood",
	},
	{
		class = "Part",
		size = { 1.75, 0.1, 0.175 },
		cframe = { 0, 2.4536, 0.8293, -1, 0, 0, 0, -0.0872, 0.9962, 0, 0.9962, 0.0872 },
		color = { 121, 85, 65 },
		material = "Wood",
	},
	{
		class = "Part",
		size = { 2.125, 0.2, 0.3186 },
		cframe = { -0.0125, 4.4026, 1.0415, -1, 0, 0, 0, -0.1736, 0.9848, 0, 0.9848, 0.1736 },
		color = { 121, 85, 65 },
		material = "Wood",
	},
	{
		class = "Part",
		size = { 1.875, 0.05, 0.175 },
		cframe = { 0.5411, 3.4028, 0.9124, 0.0023, 0, -1, -0.9962, -0.0872, -0.0023, -0.0872, 0.9962, -0.0002 },
		color = { 121, 85, 65 },
		material = "Wood",
	},
	{
		class = "Part",
		size = { 0.125, 0.175, 0.175 },
		cframe = { 0.9875, 2.0125, 0.7949, 0, -1, 0, 1, 0, 0, 0, 0, 1 },
		color = { 121, 85, 65 },
		material = "Wood",
		shape = "Cylinder",
	},
	{
		class = "Part",
		size = { 0.125, 0.175, 0.175 },
		cframe = { 0.9875, 2.0125, -1.0801, 0, -1, 0, 1, 0, 0, 0, 0, 1 },
		color = { 121, 85, 65 },
		material = "Wood",
		shape = "Cylinder",
	},
	{
		class = "WedgePart",
		size = { 0.15, 0.1, 0.7 },
		cframe = { 0.875, 0.35, -1.0426, 0, -1, 0, 0, 0, 1, -1, 0, 0 },
		color = { 121, 85, 65 },
		material = "Wood",
	},
	{
		class = "Part",
		size = { 0.0761, 0.15, 0.175 },
		cframe = { 0.9373, 0.038, 1.0217, 0, 0, -1, -1, 0, 0, 0, 1, 0 },
		color = { 121, 85, 65 },
		material = "Wood",
	},
	{
		class = "Part",
		size = { 0.2271, 0.15, 0.175 },
		cframe = { 0.9375, 0.1647, 0.995, 0, 0, -1, -0.9659, 0.2588, 0, 0.2588, 0.9659, 0 },
		color = { 121, 85, 65 },
		material = "Wood",
	},
	{
		class = "Part",
		size = { 1.25, 0.15, 0.1 },
		cframe = { 0.875, 1.325, -1.0426, 0, 0, 1, 1, 0, 0, 0, 1, 0 },
		color = { 121, 85, 65 },
		material = "Wood",
	},
	{
		class = "Part",
		size = { 1.95, 0.15, 0.1 },
		cframe = { 0.975, 0.975, -1.0426, 0, 0, 1, 1, 0, 0, 0, 1, 0 },
		color = { 121, 85, 65 },
		material = "Wood",
	},
	{
		class = "Part",
		size = { 1.7, 0.15, 0.175 },
		cframe = { 0.9375, 1.0995, 0.8965, 0, 0, -1, -0.9962, 0.0872, 0, 0.0872, 0.9962, 0 },
		color = { 121, 85, 65 },
		material = "Wood",
	},
	{
		class = "Part",
		size = { 0.45, 0.15, 0.175 },
		cframe = { 0.9125, 2.1495, 0.8215, 0, 0, -1, -1, 0, 0, 0, 1, 0 },
		color = { 121, 85, 65 },
		material = "Wood",
	},
	{
		class = "Part",
		size = { 1.6, 0.15, 0.175 },
		cframe = { 0.9125, 3.1633, 0.8915, 0, 0, -1, -0.9962, -0.0872, 0, -0.0872, 0.9962, 0 },
		color = { 121, 85, 65 },
		material = "Wood",
	},
	{
		class = "Part",
		size = { 0.5186, 0.15, 0.175 },
		cframe = { 0.9125, 4.2056, 1.0067, 0, 0, -1, -0.9848, -0.1736, 0, -0.1736, 0.9848, 0 },
		color = { 121, 85, 65 },
		material = "Wood",
	},
}

-- Builds the chair with its bottom centre at `cf`. All parts are anchored.
function ChairModel.build(cf: CFrame, scale: number?): Model
	local s = scale or 1
	local model = Instance.new("Model")
	model.Name = "Chair"
	for _, data in PARTS do
		local p = Instance.new(data.class) :: BasePart
		p.Anchored = true
		p.Size = Vector3.new(data.size[1], data.size[2], data.size[3]) * s
		local c = data.cframe
		p.CFrame = cf
			* CFrame.new(c[1] * s, c[2] * s, c[3] * s, c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12])
		p.Color = Color3.fromRGB(data.color[1], data.color[2], data.color[3])
		p.Material = (Enum.Material :: any)[data.material]
		p.Transparency = data.transparency or 0
		p.Reflectance = data.reflectance or 0
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if data.shape and p:IsA("Part") then
			p.Shape = (Enum.PartType :: any)[data.shape]
		end
		p.Parent = model
	end
	model.WorldPivot = cf
	return model
end

return ChairModel
