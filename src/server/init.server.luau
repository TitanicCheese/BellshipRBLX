-- Bellship server: builds the sky island and the tables, and runs a game at each table.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Match = require(script.Match)
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
remotes.Parent = ReplicatedStorage

local world = World.build()
local tablesFolder = Instance.new("Folder")
tablesFolder.Name = "Tables"
tablesFolder.Parent = workspace

local matches: { Match.Match } = {}
for id, cf in world.tables do
	matches[id] = Match.new(TableBuilder.build(id, cf, tablesFolder), stateEvent)
end

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

-- Anyone who falls off the island is put back on the plaza.
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
