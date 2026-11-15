-- Game rules, board layout, and asset ids shared by server and client.
local Config = {}

Config.ROWS = 3
Config.COLS = 5
Config.BELLS = 3
Config.ROW_LETTERS = { "A", "B", "C" }

Config.PLACE_TIME = 20 -- seconds to place bells
Config.TURN_TIME = 15 -- seconds per turn before a random square is pressed
Config.STRIKE_PAUSE = 1.4 -- seconds between a strike and the next turn
Config.RESULT_TIME = 6 -- seconds the result shows before the table resets

Config.TABLE_COUNT = 10
Config.TABLE_TOP = 3.2 -- table surface height above the floor
Config.CELL = 2 -- studs per board square

Config.SOUNDS = {
	Kling = "rbxassetid://9125485591", -- desk bell, single ringing ding (ProSoundEffects)
	Thud = "rbxassetid://9126267420", -- dull wood knock (ProSoundEffects)
}

-- "A1".."C5": rows A-C, columns 1-5.
function Config.key(row: number, col: number): string
	return Config.ROW_LETTERS[row] .. tostring(col)
end

function Config.parse(key: string): (number?, number?)
	local letter, digit = string.match(key, "^([ABC])([1-5])$")
	if not letter then
		return nil, nil
	end
	return table.find(Config.ROW_LETTERS, letter), tonumber(digit)
end

function Config.allKeys(): { string }
	local keys = {}
	for row = 1, Config.ROWS do
		for col = 1, Config.COLS do
			table.insert(keys, Config.key(row, col))
		end
	end
	return keys
end

-- Where a square's surface is, relative to the table's pivot. Side 1 sits at +Z, side 2 at -Z.
-- Row A is nearest the middle of the table, column 1 is on the owner's left.
function Config.cellOffset(side: number, row: number, col: number): Vector3
	local s = if side == 1 then 1 else -1
	return Vector3.new(s * (col - 3) * Config.CELL, Config.TABLE_TOP + 0.2, s * (1.5 + (row - 1) * Config.CELL))
end

return Config
