-- Fills in the bottom "You" row of each leaderboard with your own rank, avatar and weekly score.
-- The server puts the top player ids on each board (TopIds) and your weekly stats on your player.
local Players = game:GetService("Players")

local LeaderboardYou = {}

local player = Players.LocalPlayer

local function update(board: Model)
	local stat = board:GetAttribute("Stat")
	local you = board:FindFirstChild("You", true)
	if typeof(stat) ~= "string" or not you then
		return
	end
	local value = player:GetAttribute(stat)
	local score = if typeof(value) == "number" then value else 0
	local rank = "10+"
	local top = board:GetAttribute("TopIds")
	if typeof(top) == "string" then
		for i, id in string.split(top, ",") do
			if tonumber(id) == player.UserId then
				rank = tostring(i)
			end
		end
	end
	if score <= 0 then
		rank = "—"
	end
	local icon = board:GetAttribute("Icon")
	local rankLabel = you:FindFirstChild("Rank") :: TextLabel
	local nameLabel = you:FindFirstChild("PlayerName") :: TextLabel
	local valueLabel = you:FindFirstChild("Value") :: TextLabel
	local avatar = you:FindFirstChild("Avatar") :: ImageLabel
	rankLabel.Text = rank
	nameLabel.Text = player.DisplayName
	valueLabel.Text = score .. " " .. (if typeof(icon) == "string" then icon else "")
	avatar.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48", player.UserId)
end

local function watch(board: Instance)
	if not board:IsA("Model") then
		return
	end
	-- The panel's parts may still be streaming in.
	board:WaitForChild("Panel", 10)
	update(board)
	board:GetAttributeChangedSignal("TopIds"):Connect(function()
		update(board)
	end)
	local stat = board:GetAttribute("Stat")
	if typeof(stat) == "string" then
		player:GetAttributeChangedSignal(stat):Connect(function()
			update(board)
		end)
	end
end

function LeaderboardYou.start()
	task.spawn(function()
		local world = workspace:WaitForChild("World")
		local folder = world:WaitForChild("Leaderboards")
		folder.ChildAdded:Connect(function(board)
			task.spawn(watch, board)
		end)
		for _, board in folder:GetChildren() do
			task.spawn(watch, board)
		end
	end)
end

return LeaderboardYou
