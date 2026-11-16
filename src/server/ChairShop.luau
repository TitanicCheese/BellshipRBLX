-- The chair shop at the front of the island: a wooden arch with a glowing sign and five glowing
-- pedestals. Every three minutes a new set of five skins is picked from the catalog (the same
-- set on every server, since it is picked from the clock). Equip a skin at its pedestal and your
-- chair turns into it whenever you sit at a table.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChairSkins = require(script.Parent.ChairSkins)
local Config = require(ReplicatedStorage.Shared.Config)
local Stats = require(script.Parent.Stats)

local ChairShop = {}

ChairShop.SLOTS = 5
ChairShop.ROTATION = 3 * 60 -- seconds between new sets of skins
ChairShop.SPACING = 12 -- studs between pedestals
ChairShop.WIDTH = (ChairShop.SLOTS - 1) * ChairShop.SPACING + 14 -- the arch's width

local WOOD = Color3.fromRGB(50, 44, 52)
local WOOD_DARK = Color3.fromRGB(36, 32, 38)
local SIGN = Color3.fromRGB(80, 220, 255)
local ARCH_H = 16
local DISPLAY_SCALE = 1.4
local PEDESTAL_TOP = 1.5

local function block(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, parent: Instance)
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

local function label(parent: Instance, text: string, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextScaled = true
	l.Text = text
	for key, value in props do
		(l :: any)[key] = value
	end
	l.Parent = parent
	return l
end

-- The skins on offer during rotation `period`.
function ChairShop.offer(period: number): { ChairSkins.Skin }
	local pool = table.clone(ChairSkins.CATALOG)
	local rng = Random.new(period)
	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local offer = {}
	for i = 1, math.min(ChairShop.SLOTS, #pool) do
		offer[i] = pool[i]
	end
	return offer
end

-- The arch over the row, with the sign and the countdown.
local function arch(cf: CFrame, model: Model): TextLabel
	local half = ChairShop.WIDTH / 2
	for _, side in { -1, 1 } do
		local x = side * half
		block("Post", Vector3.new(1.4, ARCH_H, 1.4), cf * CFrame.new(x, ARCH_H / 2, 0), WOOD, Enum.Material.Wood, model)
		block("Foot", Vector3.new(2.4, 1, 2.4), cf * CFrame.new(x, 0.5, 0), WOOD_DARK, Enum.Material.Wood, model)
		block(
			"BeamEnd",
			Vector3.new(2.2, 0.9, 1.9),
			cf * CFrame.new(side * (half + 2.2), ARCH_H + 0.75, 0) * CFrame.Angles(0, 0, side * 0.25),
			WOOD,
			Enum.Material.Wood,
			model
		)
	end
	block(
		"TopBeam",
		Vector3.new(ChairShop.WIDTH + 4, 1.3, 1.8),
		cf * CFrame.new(0, ARCH_H + 0.3, 0),
		WOOD,
		Enum.Material.Wood,
		model
	)
	block(
		"Beam",
		Vector3.new(ChairShop.WIDTH, 0.9, 1.3),
		cf * CFrame.new(0, ARCH_H - 2.6, 0),
		WOOD,
		Enum.Material.Wood,
		model
	)

	local at = cf * CFrame.new(0, ARCH_H - 1.3, -1.1)
	local glow = block("SignGlow", Vector3.new(12.4, 4, 0.4), at, SIGN, Enum.Material.Neon, model)
	local light = Instance.new("PointLight")
	light.Color = SIGN
	light.Range = 14
	light.Brightness = 1.5
	light.Parent = glow
	local face = block(
		"Sign",
		Vector3.new(11.6, 3.2, 0.2),
		at * CFrame.new(0, 0, -0.25),
		Color3.fromRGB(30, 30, 36),
		Enum.Material.SmoothPlastic,
		model
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.MaxDistance = 160
	gui.Parent = face
	local w, h = 11.6 * 40, 3.2 * 40
	label(gui, "🪑 Chair Shop", {
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.fromOffset(w - 24, h * 0.55),
		TextStrokeTransparency = 0.4,
	})
	return label(gui, "", {
		Name = "Timer",
		Position = UDim2.fromOffset(12, h * 0.66),
		Size = UDim2.fromOffset(w - 24, h * 0.26),
		TextColor3 = SIGN,
		Font = Enum.Font.GothamBold,
	})
end

type Slot = {
	model: Model,
	glow: BasePart,
	light: PointLight,
	prompt: ProximityPrompt,
	name: TextLabel,
	rarity: TextLabel,
	top: CFrame,
	skin: ChairSkins.Skin?,
}

local function pedestal(cf: CFrame, index: number, parent: Instance): Slot
	local model = Instance.new("Model")
	model.Name = "Slot" .. index
	local base = block(
		"Pedestal",
		Vector3.new(6, 1, 6),
		cf * CFrame.new(0, 0.5, 0),
		WOOD_DARK,
		Enum.Material.SmoothPlastic,
		model
	)
	local glow = block("Glow", Vector3.new(6.4, 0.4, 6.4), cf * CFrame.new(0, 1.2, 0), SIGN, Enum.Material.Neon, model)
	block("Top", Vector3.new(5.6, 0.2, 5.6), cf * CFrame.new(0, 1.4, 0), WOOD_DARK, Enum.Material.SmoothPlastic, model)
	local light = Instance.new("PointLight")
	light.Range = 10
	light.Brightness = 1.2
	light.Parent = glow

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Equip"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = base

	local anchor =
		block("TagAnchor", Vector3.one * 0.2, cf * CFrame.new(0, 8.8, 0), WOOD, Enum.Material.SmoothPlastic, model)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromScale(7, 1.8)
	tag.MaxDistance = 90
	tag.Parent = anchor
	local name = label(tag, "", { Size = UDim2.fromScale(1, 0.6), TextStrokeTransparency = 0.3 })
	local rarity = label(tag, "", {
		Position = UDim2.fromScale(0, 0.6),
		Size = UDim2.fromScale(1, 0.4),
		Font = Enum.Font.GothamBold,
		TextStrokeTransparency = 0.4,
	})
	model.Parent = parent
	return {
		model = model,
		glow = glow,
		light = light,
		prompt = prompt,
		name = name,
		rarity = rarity,
		top = cf * CFrame.new(0, PEDESTAL_TOP, 0),
	}
end

-- Shows a skin on a pedestal. The client spins the display chair around its "Base" pivot.
local function show(slot: Slot, skin: ChairSkins.Skin?)
	slot.skin = skin
	local old = slot.model:FindFirstChild("Display")
	if old then
		old:Destroy()
	end
	if not skin then
		slot.name.Text = "Sold out"
		slot.rarity.Text = ""
		slot.prompt.Enabled = false
		slot.model:SetAttribute("SkinId", nil)
		return
	end
	local color = ChairSkins.RARITY_COLORS[skin.rarity]
	slot.glow.Color = color
	slot.light.Color = color
	slot.name.Text = skin.name
	slot.rarity.Text = skin.rarity
	slot.rarity.TextColor3 = color
	slot.prompt.ObjectText = skin.name
	slot.prompt.Enabled = true
	slot.model:SetAttribute("SkinId", skin.id)
	local display = skin.build(slot.top, DISPLAY_SCALE)
	display.Name = "Display"
	for _, part in display:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
		end
	end
	display:SetAttribute("Base", slot.top)
	display.Parent = slot.model
end

local function countdown(): string
	local left = ChairShop.ROTATION - os.time() % ChairShop.ROTATION
	return string.format("New chairs in %d:%02d", left // 60, left % 60)
end

-- Builds the shop with its centre at `cf` (facing where visitors stand), and keeps the chairs at
-- the tables' `seats` dressed in their sitters' skins.
function ChairShop.start(cf: CFrame, parent: Instance, seats: { Seat })
	local model = Instance.new("Model")
	model.Name = "ChairShop"
	local timer = arch(cf, model)
	local slots: { Slot } = {}
	for i = 1, ChairShop.SLOTS do
		local x = (i - (ChairShop.SLOTS + 1) / 2) * ChairShop.SPACING
		slots[i] = pedestal(cf * CFrame.new(x, 0, 0), i, model)
	end
	model.Parent = parent

	-- Which seat each player is in, so equipping while seated updates that chair.
	local seatOf: { [Player]: Seat } = {}
	local function dress(seat: Seat)
		local chair = seat.Parent
		if not chair or not chair:IsA("Model") then
			return
		end
		local humanoid = seat.Occupant
		local player = humanoid and Players:GetPlayerFromCharacter(humanoid.Parent)
		ChairSkins.apply(chair, if player then Stats.chairSkin(player) else "", Config.CHAIR_SCALE)
	end
	for _, seat in seats do
		local sitter: Player? = nil
		seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			if sitter and seatOf[sitter] == seat then
				seatOf[sitter] = nil
			end
			local humanoid = seat.Occupant
			sitter = humanoid and Players:GetPlayerFromCharacter(humanoid.Parent)
			if sitter then
				seatOf[sitter] = seat
			end
			dress(seat)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		seatOf[player] = nil
	end)

	-- Equip from a pedestal; equipping the skin you already have takes it off again.
	for _, slot in slots do
		slot.prompt.Triggered:Connect(function(player)
			local skin = slot.skin
			if not skin then
				return
			end
			Stats.setChairSkin(player, if Stats.chairSkin(player) == skin.id then "" else skin.id)
			local seat = seatOf[player]
			if seat then
				dress(seat)
			end
		end)
	end

	task.spawn(function()
		local period = -1
		while true do
			local now = os.time() // ChairShop.ROTATION
			if now ~= period then
				period = now
				local offer = ChairShop.offer(period)
				for i, slot in slots do
					show(slot, offer[i])
				end
			end
			timer.Text = countdown()
			task.wait(1)
		end
	end)
end

return ChairShop
