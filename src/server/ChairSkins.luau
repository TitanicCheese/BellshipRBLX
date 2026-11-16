-- Chair skins: the models for the chair entries of the shared skin catalog (shared/Skins), and
-- swapping a table chair's look to the skin of whoever sits in it. A skin only changes the
-- visible parts; the Seat stays the same.
--
-- To add a real skin, put a build function for its id in BUILDERS that returns a Model with its
-- bottom centre at `cf`, facing -Z with the back at +Z, sized like the regular chair at scale 1
-- (seat top 2.075 studs up). Skins without one are placeholders that build the regular chair.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChairModel = require(script.Parent.ChairModel)
local RewardsConfig = require(ReplicatedStorage.Shared.RewardsConfig)
local Skins = require(ReplicatedStorage.Shared.Skins)

local ChairSkins = {}

export type Rarity = Skins.Rarity
export type Skin = {
	id: string,
	name: string,
	rarity: Rarity,
	build: (cf: CFrame, scale: number) -> Model,
}

ChairSkins.RARITY_COLORS = RewardsConfig.RARITY_COLORS

local function placeholder(cf: CFrame, scale: number): Model
	return ChairModel.build(cf, scale)
end

-- Skin id -> model builder.
local BUILDERS: { [string]: (cf: CFrame, scale: number) -> Model } = {}

ChairSkins.CATALOG = {} :: { Skin }
for _, skin in Skins.ofKind("Chair") do
	table.insert(ChairSkins.CATALOG, {
		id = skin.id,
		name = skin.name,
		rarity = skin.rarity,
		build = BUILDERS[skin.id] or placeholder,
	})
end

function ChairSkins.get(id: string): Skin?
	for _, skin in ChairSkins.CATALOG do
		if skin.id == id then
			return skin
		end
	end
	return nil
end

-- Shows `id`'s skin on a table chair (built by TableBuilder at `scale`), or the regular chair
-- for "" or an unknown id.
function ChairSkins.apply(chair: Model, id: string, scale: number)
	local old = chair:FindFirstChild("Skin")
	if old then
		old:Destroy()
	end
	local skin = ChairSkins.get(id)
	for _, part in chair:GetChildren() do
		if part:IsA("BasePart") and not part:IsA("Seat") then
			local original = part:GetAttribute("Transparency")
			if original == nil then
				original = part.Transparency
				part:SetAttribute("Transparency", original)
			end
			part.Transparency = if skin then 1 else original :: number
			part.CanCollide = skin == nil
		end
	end
	if skin then
		local model = skin.build(chair.WorldPivot, scale)
		model.Name = "Skin"
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
			end
		end
		model.Parent = chair
	end
end

return ChairSkins
