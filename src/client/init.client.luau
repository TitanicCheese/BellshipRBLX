-- Bellship client: camera over the table while playing, clicking squares, your own (hidden)
-- bells, sounds, and the HUD.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bell = require(Shared:WaitForChild("Bell"))
local Config = require(Shared:WaitForChild("Config"))
local Hud = require(script.Hud)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local stateEvent = remotes:WaitForChild("State") :: RemoteEvent
local actionEvent = remotes:WaitForChild("Action") :: RemoteEvent
local tables = workspace:WaitForChild("Tables")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local state: { [string]: any }? = nil
local seatedTable: Model? = nil -- the table whose camera view is active

-- Only this client sees its own bells; the server never tells anyone else where they are.
local myBells = Instance.new("Folder")
myBells.Name = "MyBells"
myBells.Parent = workspace

local hover = Instance.new("SelectionBox")
hover.LineThickness = 0.05
hover.SurfaceTransparency = 0.75
hover.Parent = workspace

local function sound(id: string, volume: number, speed: number): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = speed
	s.Parent = SoundService
	return s
end
local tap = sound(Config.SOUNDS.Thud, 0.35, 1.8)
local fanfare = sound(Config.SOUNDS.Kling, 0.6, 1.25)

local function tableModel(): Model?
	return if state then tables:FindFirstChild("Table" .. state.table) :: Model? else nil
end

local function inGame(): boolean
	return state ~= nil and (state.phase == "placing" or state.phase == "battle" or state.phase == "over")
end

local function setSign(model: Model?, visible: boolean)
	local sign = model and model:FindFirstChild("Sign")
	local billboard = sign and sign:FindFirstChildOfClass("BillboardGui")
	if billboard then
		billboard.Enabled = visible
	end
end

local function updateCamera()
	local model = if inGame() then tableModel() else nil
	if model == seatedTable then
		return
	end
	setSign(seatedTable, true)
	seatedTable = model
	if model and state then
		setSign(model, false)
		local cf = model.WorldPivot
		-- A fixed shot from across the table, like the video: both players and both sheets.
		local eye = cf:PointToWorldSpace(Vector3.new(0, Config.TABLE_TOP + 5.2, -6.6))
		local focus = cf:PointToWorldSpace(Vector3.new(0, Config.TABLE_TOP + 1.3, 1.4))
		camera.CameraType = Enum.CameraType.Scriptable
		TweenService:Create(camera, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
			CFrame = CFrame.lookAt(eye, focus),
		}):Play()
	else
		camera.CameraType = Enum.CameraType.Custom
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

local function renderBells()
	myBells:ClearAllChildren()
	local model = tableModel()
	if not model or not state or (state.phase ~= "placing" and state.phase ~= "battle") then
		return
	end
	for key, alive in state.myBells do
		if alive then
			local col, row = Config.parse(key)
			local cf = model.WorldPivot * CFrame.new(Config.cellOffset(state.side, col :: number, row :: number))
			Bell.build(cf, Config.BELL_SCALE).Parent = myBells
		end
	end
end

-- What clicking this square would do right now: "toggle", "strike", or nil.
local function actionFor(tile: Instance?): string?
	if not tile or not state then
		return nil
	end
	local side, key = tile:GetAttribute("Side"), tile:GetAttribute("Key")
	if tile:GetAttribute("Table") ~= state.table then
		return nil
	end
	if state.phase == "placing" and side == state.side then
		return "toggle"
	end
	if state.phase == "battle" and state.turn == state.side and side ~= state.side and not state.strikes[key] then
		return "strike"
	end
	return nil
end

local function tileAt(position: Vector3 | Vector2): BasePart?
	local model = tableModel()
	if not model or not inGame() then
		return nil
	end
	local ray = camera:ScreenPointToRay(position.X, position.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { model:FindFirstChild("Tiles") :: Instance }
	local result = workspace:Raycast(ray.Origin, ray.Direction * 200, params)
	return if result then result.Instance :: BasePart else nil
end

local function updateHover(position: Vector3 | Vector2)
	local tile = tileAt(position)
	local kind = actionFor(tile)
	hover.Adornee = if kind then tile else nil
	local color = if kind == "strike" then Color3.fromRGB(255, 90, 80) else Color3.fromRGB(255, 205, 90)
	hover.Color3 = color
	hover.SurfaceColor3 = color
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local tile = tileAt(input.Position)
	local kind = actionFor(tile)
	if tile and kind and state then
		if kind == "strike" then
			state.turn = 0 -- no double clicks while the server answers
			hover.Adornee = nil
		end
		tap:Play()
		actionEvent:FireServer(kind, tile:GetAttribute("Key"))
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		updateHover(input.Position)
	end
end)

local function onStrike(previous: { [string]: any }?)
	local last = state and state.last
	local before = previous and previous.last
	if not last or (before and before.key == last.key and before.mine == last.mine) then
		return
	end
	if last.hit then
		Hud.toast(
			if last.mine then "DING! " .. last.key else "Your " .. last.key .. " rang!",
			Color3.fromRGB(255, 205, 90)
		)
	else
		Hud.toast(
			if last.mine then "Miss · " .. last.key else "They missed " .. last.key,
			Color3.fromRGB(200, 215, 235)
		)
	end
end

stateEvent.OnClientEvent:Connect(function(newState: { [string]: any })
	local previous = state
	state = if newState.phase == "none" then nil else newState
	updateCamera()
	renderBells()
	Hud.update(state, Config.BELLS)
	if state and state.phase == "battle" then
		onStrike(previous)
	end
	if state and state.phase == "over" and previous and previous.phase ~= "over" then
		if state.result == "win" then
			Hud.toast("YOU WIN!", Color3.fromRGB(255, 205, 90))
			task.spawn(function()
				for _ = 1, 3 do
					fanfare:Play()
					task.wait(0.18)
				end
			end)
		else
			Hud.toast("You lose", Color3.fromRGB(235, 120, 110))
		end
	end
	if state and state.phase == "battle" and previous and previous.phase == "placing" then
		Hud.toast("Let the ringing begin!", Color3.new(1, 1, 1))
	end
	updateHover(UserInputService:GetMouseLocation() - GuiService:GetGuiInset())
end)

RunService.RenderStepped:Connect(function()
	if state and (state.phase == "placing" or (state.phase == "battle" and state.turn ~= 0)) then
		Hud.setTimer(state.endsAt - workspace:GetServerTimeNow())
	else
		Hud.setTimer(nil)
	end
end)

player.CharacterAdded:Connect(function()
	state = nil
	updateCamera()
	renderBells()
	Hud.update(nil, Config.BELLS)
end)
