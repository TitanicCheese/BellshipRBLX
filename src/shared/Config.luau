-- Game rules, board layout, and asset ids shared by server and client.
local Config = {}

-- Each player's paper sheet: columns A-C across the top, rows 1-5 down the side.
Config.COLUMNS = 3
Config.ROWS = 5
Config.BELLS = 3
Config.COLUMN_LETTERS = { "A", "B", "C" }

Config.PLACE_TIME = 20 -- seconds to place bells
Config.TURN_TIME = 15 -- seconds per turn before a random square is pressed
Config.STRIKE_PAUSE = 1.6 -- seconds between a strike and the next turn
Config.RESULT_TIME = 6 -- seconds the result shows before the table resets

Config.TABLE_COUNT = 10
Config.TABLE_TOP = 3.2 -- table surface height above the floor
Config.CELL = 2 -- studs per board square
Config.SHEET_X = { 5, -5 } -- centre of each player's sheet; side 1 is on the camera's left

Config.SOUNDS = {
	Kling = "rbxassetid://9125485591", -- desk bell, single ringing ding (ProSoundEffects)
	Thud = "rbxassetid://9126267420", -- dull wood knock (ProSoundEffects)
}

-- "A1".."C5": column letter, then row number.
function Config.key(col: number, row: number): string
	return Config.COLUMN_LETTERS[col] .. tostring(row)
end

-- Returns column, row.
function Config.parse(key: string): (number?, number?)
	local letter, digit = string.match(key, "^([ABC])([1-5])$")
	if not letter then
		return nil, nil
	end
	return table.find(Config.COLUMN_LETTERS, letter), tonumber(digit)
end

function Config.allKeys(): { string }
	local keys = {}
	for row = 1, Config.ROWS do
		for col = 1, Config.COLUMNS do
			table.insert(keys, Config.key(col, row))
		end
	end
	return keys
end

-- Both players sit at +Z facing -Z, towards a fixed camera at -Z, like a video filmed from
-- across the table. The sheets read the right way up for that camera: a 7 x 11 stud sheet with
-- column letters along the edge nearest the players, row numbers down the camera's left side,
-- and row 1 nearest the players. The camera's left is +X.
function Config.gridOrigin(side: number): Vector3
	return Vector3.new(Config.SHEET_X[side] - 0.5, Config.TABLE_TOP + 0.04, -0.5)
end

-- Where a square's surface is, relative to the table's pivot.
function Config.cellOffset(side: number, col: number, row: number): Vector3
	return Config.gridOrigin(side) - Vector3.new((col - 2) * Config.CELL, 0, (row - 3) * Config.CELL)
end

return Config
