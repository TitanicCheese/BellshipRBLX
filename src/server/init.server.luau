-- Bellship server: builds the sky island and the tables, and runs a game at each table.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ChairShop = require(script.ChairShop)
local Leaderboards = require(script.Leaderboards)
local Match = require(script.Match)
local Stats = require(script.Stats)
local TableBuilder = require(script.TableBuilder)
local World = require(script.World)

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local stateEvent = Instance.new("RemoteEvent")
stateEvent.Name = "State" -- server -> client: the table state as that player sees it
stateEvent.Parent = remotes
local actionEvent = Instance.new("RemoteEvent")
actionEvent.Name = "Action" -- client -> server: ("toggle" | "strike", square key)
actionEvent.Parent = remotes
local lobbyEvent = Instance.new("RemoteEvent")
lobbyEvent.Name = "Lobby" -- server -> clients: a table opened up for joining, or closed again
lobbyEvent.Parent = remotes
local joinEvent = Instance.new("RemoteEvent")
joinEvent.Name = "Join" -- client -> server: (tableId) teleport me into the free seat there
joinEvent.Parent = remotes
remotes.Parent = ReplicatedStorage

Stats.start()
local world = World.build()
Leaderboards.start(world.boards, workspace:FindFirstChild("World") :: Instance)
local tablesFolder = Instance.new("Folder")
tablesFolder.Name = "Tables"
tablesFolder.Parent = workspace

-- Tables with one player waiting, as sent to clients: { table, open, userId?, name }.
local openTables: { [number]: { [string]: any } } = {}
local function announce(id: number, waiting: Match.Seated?)
	local info: { [string]: any } = { table = id, open = waiting ~= nil }
	if waiting then
		info.name = waiting.name
		info.userId = if waiting.player then waiting.player.UserId else nil
	end
	openTables[id] = if waiting then info else nil
	lobbyEvent:FireAllClients(info)
end
Players.PlayerAdded:Connect(function(player)
	for _, info in openTables do
		lobbyEvent:FireClient(player, info)
	end
end)

local matches: { Match.Match } = {}
local seats: { Seat } = {}
for id, cf in world.tables do
	matches[id] = Match.new(TableBuilder.build(id, cf, tablesFolder), stateEvent, announce)
	for _, seat in matches[id].refs.seats do
		table.insert(seats, seat)
	end
end
ChairShop.start(world.shop, workspace:FindFirstChild("World") :: Instance, seats)

local function act(player: Player, kind: unknown, key: unknown)
	if typeof(kind) ~= "string" or typeof(key) ~= "string" or not Config.parse(key) then
		return
	end
	for _, match in matches do
		local side = match:sideOf(player)
		if side then
			match:act(side, kind, key)
			return
		end
	end
end
actionEvent.OnServerEvent:Connect(act)

-- Join from the prompt: sit the player in the free seat of a table where someone is waiting.
local lastJoin: { [Player]: number } = {}
joinEvent.OnServerEvent:Connect(function(player: Player, id: unknown)
	local match = if typeof(id) == "number" then matches[id] else nil
	if not match or match.phase ~= "waiting" or os.clock() - (lastJoin[player] or 0) < 1 then
		return
	end
	lastJoin[player] = os.clock()
	for _, other in matches do
		if other:sideOf(player) then
			return -- already playing or waiting somewhere
		end
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return
	end
	for side, seat in match.refs.seats do
		if not seat.Occupant and not match.seats[side] then
			humanoid.Sit = false
			character:PivotTo(seat.CFrame * CFrame.new(0, 3, 0))
			seat:Sit(humanoid)
			return
		end
	end
end)
Players.PlayerRemoving:Connect(function(player)
	lastJoin[player] = nil
end)

-- Anyone who falls off the island is put back at the spawn.
task.spawn(function()
	while true do
		task.wait(0.5)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if character and root and root.Position.Y < World.TOP - 80 then
				root.AssemblyLinearVelocity = Vector3.zero
				character:PivotTo(world.spawn * CFrame.new(0, 4, 0))
			end
		end
	end
end)

-- Studio-only test hooks, so one person can test a match alone:
--   ServerStorage.BellshipDebug:Invoke("bot", tableId, side)   seats a bot that plays randomly
--   ServerStorage.BellshipDebug:Invoke("sit", tableId, side)   seats the first player
--   ServerStorage.BellshipDebug:Invoke("act", "toggle"|"strike", key)   acts as the first player
--   ServerStorage.BellshipDebug:Invoke("state", tableId)
--   ServerStorage.BellshipDebug:Invoke("stat", "won"|"lost"|"rang")   adds to the first player's stats
if RunService:IsStudio() then
	local debug = Instance.new("BindableFunction")
	debug.Name = "BellshipDebug"
	debug.OnInvoke = function(command: string, a: any, b: any): any
		local match = matches[a]
		if command == "bot" then
			local seat = match.refs.seats[b]
			local bot = Players:CreateHumanoidModelFromDescription(
				Instance.new("HumanoidDescription"),
				Enum.HumanoidRigType.R15
			)
			bot.Name = "Bot"
			bot:SetAttribute("Bot", true)
			bot:PivotTo(seat.CFrame * CFrame.new(0, 3, 0))
			bot.Parent = workspace
			seat:Sit(bot:FindFirstChildOfClass("Humanoid") :: Humanoid)
			return "ok"
		elseif command == "sit" then
			local character = Players:GetPlayers()[1].Character :: Model
			local seat = match.refs.seats[b]
			character:PivotTo(seat.CFrame * CFrame.new(0, 3, 0))
			seat:Sit(character:FindFirstChildOfClass("Humanoid") :: Humanoid)
			return "ok"
		elseif command == "act" then
			act(Players:GetPlayers()[1], a, b)
			return "ok"
		elseif command == "stat" then
			local player = Players:GetPlayers()[1]
			if a == "won" then
				Stats.won(player)
			elseif a == "lost" then
				Stats.lost(player)
			elseif a == "rang" then
				Stats.rang(player)
			elseif typeof(a) == "string" and typeof(b) == "number" then
				Stats.debugSet(player, a, b)
			end
			return "ok"
		elseif command == "fake" then
			-- ("fake", stat, { { userId, value } }): pretend these scores were saved this week.
			Leaderboards.debugSaved(a, b)
			return "ok"
		elseif command == "state" then
			return string.format(
				"phase=%s turn=%d alive=%d/%d last=%s",
				match.phase,
				match.turn,
				match:alive(1),
				match:alive(2),
				if match.last then match.last.key else "-"
			)
		end
		return "unknown command"
	end
	debug.Parent = ServerStorage
end
