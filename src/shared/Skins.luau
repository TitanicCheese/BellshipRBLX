-- The skin catalog for all three kinds: chairs, bells and boards (the paper sheet you play on).
-- Shared so the hub can list names and odds; the server decides what you own.
--
-- Every skin is a placeholder for now that looks like the regular item. To make a real one,
-- give its entry a `build` function (see each kind below) and change its name and rarity.
-- Skins of a kind come from that kind's crate, and chair skins are also sold in the chair shop.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bell = require(ReplicatedStorage.Shared.Bell)

local Skins = {}

export type Kind = "Chair" | "Bell" | "Board"
export type Rarity = "Common" | "Rare" | "Epic" | "Legendary"
export type Skin = {
	id: string,
	kind: Kind,
	name: string,
	rarity: Rarity,
	-- Bells only: builds the bell like Bell.build, keeping the part names Bell.build uses (Base,
	-- Dome, Stem, Knob) so the ring animation still works. Nil means the regular bell.
	buildBell: ((cf: CFrame, scale: number) -> Model)?,
	-- Boards only: restyles one side's sheet on a table while its player sits there, and returns
	-- a function that puts it back. Nil means the regular sheet.
	styleBoard: ((table: Model, side: number) -> () -> ())?,
}

Skins.KINDS = { "Chair", "Bell", "Board" } :: { Kind }
Skins.KIND_INFO = {
	Chair = { title = "Chair Skins", crate = "Chair Crate", icon = "🪑" },
	Bell = { title = "Bell Skins", crate = "Bell Crate", icon = "🛎️" },
	Board = { title = "Board Skins", crate = "Board Crate", icon = "📋" },
}

local function add(kind: Kind, prefix: string, label: string, rarities: { Rarity })
	for i, rarity in rarities do
		table.insert(Skins.CATALOG, {
			-- Chair skins keep their original ids ("skin1"...) so saved data still matches.
			id = prefix .. i,
			kind = kind,
			name = label .. " " .. i,
			rarity = rarity,
		})
	end
end

Skins.CATALOG = {} :: { Skin }
add(
	"Chair",
	"skin",
	"Chair Skin",
	{ "Common", "Common", "Rare", "Common", "Epic", "Rare", "Common", "Legendary", "Rare", "Epic" }
)
add("Bell", "bell", "Bell Skin", { "Common", "Common", "Rare", "Common", "Rare", "Epic", "Epic", "Legendary" })
add("Board", "board", "Board Skin", { "Common", "Common", "Rare", "Common", "Rare", "Epic", "Epic", "Legendary" })

function Skins.get(id: string): Skin?
	for _, skin in Skins.CATALOG do
		if skin.id == id then
			return skin
		end
	end
	return nil
end

function Skins.ofKind(kind: Kind): { Skin }
	local result = {}
	for _, skin in Skins.CATALOG do
		if skin.kind == kind then
			table.insert(result, skin)
		end
	end
	return result
end

-- A bell in the given bell skin ("" or unknown: the regular bell).
function Skins.buildBell(id: string?, cf: CFrame, scale: number): Model
	local skin = if id then Skins.get(id) else nil
	if skin and skin.kind == "Bell" and skin.buildBell then
		return skin.buildBell(cf, scale)
	end
	return Bell.build(cf, scale)
end

-- Puts one side's sheet in a board skin; returns how to undo it.
function Skins.styleBoard(id: string?, table: Model, side: number): () -> ()
	local skin = if id then Skins.get(id) else nil
	if skin and skin.kind == "Board" and skin.styleBoard then
		return skin.styleBoard(table, side)
	end
	return function() end
end

return Skins
