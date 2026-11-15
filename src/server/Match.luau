-- The game at one table: seats, placement, turns, strikes, and the result.
-- Phases: idle (empty) -> waiting (one seated) -> placing -> battle -> over -> back to
-- idle/waiting, or straight into a rematch if both players stay seated.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Bell = require(ReplicatedStorage.Shared.Bell)
local Config = require(ReplicatedStorage.Shared.Config)
local TableBuilder = require(script.Parent.TableBuilder)

type Seated = { player: Player?, humanoid: Humanoid, name: string }
type Strike = { by: number, key: string, hit: boolean }

local Match = {}
Match.__index = Match

export type Match = typeof(setmetatable(
	{} :: {
		refs: TableBuilder.Refs,
		state: RemoteEvent,
		seats: { [number]: Seated? },
		participants: { [number]: Seated }?,
		phase: string,
		bells: { { [string]: boolean } }, -- side -> square -> true while it can still ring
		order: { { string } }, -- placement order, oldest first
		struck: { { [string]: string } }, -- squares each side has pressed: "hit" or "miss"
		turn: number,
		endsAt: number,
		token: number, -- bumped on every phase or turn change; cancels stale timers
		last: Strike?,
		winner: number?,
		reason: string?,
	},
	Match
))

local function now(): number
	return workspace:GetServerTimeNow()
end

local function other(side: number): number
	return 3 - side
end

local function playSound(parent: Instance, id: string, volume: number, speed: number)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = speed
	sound.RollOffMinDistance = 12
	sound.RollOffMaxDistance = 110
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, 7)
end

function Match.new(refs: TableBuilder.Refs, state: RemoteEvent): Match
	local self = setmetatable({
		refs = refs,
		state = state,
		seats = {},
		participants = nil,
		phase = "idle",
		bells = { {}, {} },
		order = { {}, {} },
		struck = { {}, {} },
		turn = 0,
		endsAt = 0,
		token = 0,
		last = nil,
		winner = nil,
		reason = nil,
	}, Match)
	for side, seat in refs.seats do
		seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			self:onOccupant(side)
		end)
	end
	self:updateSign()
	return self
end

function Match.sideOf(self: Match, player: Player): number?
	for side = 1, 2 do
		local seated = self.seats[side]
		if seated and seated.player == player then
			return side
		end
	end
	return nil
end

function Match.alive(self: Match, side: number): number
	local count = 0
	for _, alive in self.bells[side] do
		if alive then
			count += 1
		end
	end
	return count
end

function Match.send(self: Match, player: Player, view: { [string]: any })
	if player.Parent == Players then
		self.state:FireClient(player, view)
	end
end

function Match.onOccupant(self: Match, side: number)
	local humanoid = self.refs.seats[side].Occupant
	local current = self.seats[side]
	if current and current.humanoid == humanoid then
		return
	end
	if current then
		self.seats[side] = nil
		if self.phase == "placing" or self.phase == "battle" then
			self:finish(other(side), "left")
		end
		if current.player then
			self:send(current.player, { phase = "none" })
		end
	end
	-- Newcomers wait for the result screen to end; reset() picks them up.
	if humanoid and self.phase ~= "over" then
		local character = humanoid.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if player or (character and character:GetAttribute("Bot")) then
			self.seats[side] = {
				player = player,
				humanoid = humanoid,
				name = if player then player.DisplayName else "Bot",
			}
		end
	end
	if self.phase == "idle" or self.phase == "waiting" then
		self:evaluate()
	end
end

function Match.evaluate(self: Match)
	if self.seats[1] and self.seats[2] then
		self:startPlacing()
	elseif self.seats[1] or self.seats[2] then
		self.phase = "waiting"
		self:broadcast()
	else
		self.phase = "idle"
		self:broadcast()
	end
end

function Match.clearBoard(self: Match)
	self.refs.markers:ClearAllChildren()
	for side = 1, 2 do
		for _, tile in self.refs.tiles[side] do
			tile.Color = TableBuilder.TILE_COLOR
		end
	end
end

function Match.startPlacing(self: Match)
	self.token += 1
	self.phase = "placing"
	self.participants = { self.seats[1] :: Seated, self.seats[2] :: Seated }
	self.bells = { {}, {} }
	self.order = { {}, {} }
	self.struck = { {}, {} }
	self.turn = 0
	self.last = nil
	self.winner = nil
	self.reason = nil
	self:clearBoard()
	for side = 1, 2 do
		if not (self.seats[side] :: Seated).player then
			self:autofill(side)
		end
	end
	self.endsAt = now() + Config.PLACE_TIME
	self:broadcast()
	local token = self.token
	task.delay(Config.PLACE_TIME, function()
		if self.token == token then
			self:startBattle()
		end
	end)
end

function Match.toggle(self: Match, side: number, key: string)
	if self.phase ~= "placing" then
		return
	end
	local bells, order = self.bells[side], self.order[side]
	if bells[key] then
		bells[key] = nil
		table.remove(order, table.find(order, key) :: number)
	else
		-- With all bells out, clicking a new square moves the oldest bell there.
		if #order >= Config.BELLS then
			bells[table.remove(order, 1) :: string] = nil
		end
		bells[key] = true
		table.insert(order, key)
	end
	local seated = self.seats[side]
	if seated and seated.player then
		self:send(seated.player, self:view(side))
	end
end

function Match.autofill(self: Match, side: number)
	local free = {}
	for _, key in Config.allKeys() do
		if not self.bells[side][key] then
			table.insert(free, key)
		end
	end
	while #self.order[side] < Config.BELLS and #free > 0 do
		local key = table.remove(free, math.random(1, #free)) :: string
		self.bells[side][key] = true
		table.insert(self.order[side], key)
	end
end

function Match.startBattle(self: Match)
	self:autofill(1)
	self:autofill(2)
	self.phase = "battle"
	self:nextTurn(math.random(1, 2))
end

function Match.randomTarget(self: Match, side: number): string
	local free = {}
	for _, key in Config.allKeys() do
		if not self.struck[side][key] then
			table.insert(free, key)
		end
	end
	return free[math.random(1, #free)]
end

function Match.nextTurn(self: Match, side: number)
	self.token += 1
	self.turn = side
	self.endsAt = now() + Config.TURN_TIME
	self:broadcast()
	local token = self.token
	local seated = self.seats[side]
	if seated and not seated.player then
		task.delay(math.random(12, 22) / 10, function()
			if self.token == token then
				self:strike(side, self:randomTarget(side))
			end
		end)
	end
	task.delay(Config.TURN_TIME, function()
		if self.token == token then
			self:strike(side, self:randomTarget(side))
		end
	end)
end

function Match.strike(self: Match, side: number, key: string)
	if self.phase ~= "battle" or self.turn ~= side or self.struck[side][key] then
		return
	end
	self.token += 1
	self.turn = 0
	local target = other(side)
	local hit = self.bells[target][key] == true
	if hit then
		self.bells[target][key] = false
	end
	self.struck[side][key] = if hit then "hit" else "miss"
	self.last = { by = side, key = key, hit = hit }
	self:showStrike(target, key, hit)
	self:broadcast()
	local token = self.token
	task.delay(Config.STRIKE_PAUSE, function()
		if self.token ~= token then
			return
		end
		if self:alive(target) == 0 then
			self:finish(side, "bells")
		else
			self:nextTurn(target)
		end
	end)
end

function Match.cellCFrame(self: Match, side: number, key: string): CFrame
	local row, col = Config.parse(key)
	return self.refs.cf * CFrame.new(Config.cellOffset(side, row :: number, col :: number))
end

local function sparkle(parent: BasePart, color: Color3, count: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Speed = NumberRange.new(5, 10)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -12, 0)
	emitter.Rate = 0
	emitter.Parent = parent
	emitter:Emit(count)
	Debris:AddItem(emitter, 2)
end

function Match.showStrike(self: Match, target: number, key: string, hit: boolean)
	local tile = self.refs.tiles[target][key]
	local cf = self:cellCFrame(target, key)
	if hit then
		-- The bell appears, its plunger snaps down, it rings and then goes dull.
		local bell = Bell.build(cf)
		bell.Parent = self.refs.markers
		local dome, stem, knob =
			bell:FindFirstChild("Dome") :: Part,
			bell:FindFirstChild("Stem") :: Part,
			bell:FindFirstChild("Knob") :: Part
		local press = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(stem, press, { CFrame = stem.CFrame - Vector3.new(0, 0.14, 0) }):Play()
		TweenService:Create(knob, press, { CFrame = knob.CFrame - Vector3.new(0, 0.14, 0) }):Play()
		playSound(dome, Config.SOUNDS.Kling, 1, 0.97 + math.random() * 0.06)
		sparkle(dome, Bell.GOLD, 30)
		local light = Instance.new("PointLight")
		light.Color = Bell.GOLD
		light.Brightness = 5
		light.Range = 10
		light.Parent = dome
		local fade = TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.25)
		TweenService:Create(light, fade, { Brightness = 0 }):Play()
		TweenService:Create(dome, fade, { Color = Bell.TARNISH, Reflectance = 0 }):Play()
		TweenService:Create(tile, TweenInfo.new(0.3), { Color = Color3.fromRGB(214, 74, 66) }):Play()
	else
		local disc = Instance.new("Part")
		disc.Name = "Miss"
		disc.Shape = Enum.PartType.Cylinder
		disc.Size = Vector3.new(0.06, 1, 1)
		disc.CFrame = cf * CFrame.new(0, 0.03, 0) * CFrame.Angles(0, 0, math.pi / 2)
		disc.Color = Color3.fromRGB(250, 252, 255)
		disc.Material = Enum.Material.SmoothPlastic
		disc.Anchored = true
		disc.CanCollide = false
		disc.CanQuery = false
		disc.Parent = self.refs.markers
		playSound(disc, Config.SOUNDS.Thud, 0.7, 1.25)
		sparkle(disc, Color3.fromRGB(255, 255, 255), 8)
		TweenService:Create(tile, TweenInfo.new(0.3), { Color = Color3.fromRGB(140, 156, 178) }):Play()
	end
end

function Match.finish(self: Match, winner: number, reason: string)
	self.token += 1
	self.phase = "over"
	self.turn = 0
	self.winner = winner
	self.reason = reason
	-- Show where the winner's surviving bells were.
	for key, alive in self.bells[winner] do
		if alive then
			local bell = Bell.build(self:cellCFrame(winner, key))
			bell.Parent = self.refs.markers
			sparkle(bell:FindFirstChild("Dome") :: Part, Bell.GOLD, 12)
		end
	end
	self.endsAt = now() + Config.RESULT_TIME
	self:broadcast()
	local token = self.token
	task.delay(Config.RESULT_TIME, function()
		if self.token == token then
			self:reset()
		end
	end)
end

function Match.reset(self: Match)
	self.token += 1
	local participants = self.participants or {}
	self.participants = nil
	self.phase = "idle"
	self.seats = {}
	self:clearBoard()
	for _, seated in participants do
		local character = seated.humanoid.Parent
		if not seated.player and character then
			character:Destroy() -- test bots leave after one game
		end
	end
	-- Players who stayed seated get a rematch, or wait for a new opponent.
	for side, seat in self.refs.seats do
		local humanoid = seat.Occupant
		local player = humanoid and Players:GetPlayerFromCharacter(humanoid.Parent)
		if humanoid and player then
			self.seats[side] = { player = player, humanoid = humanoid, name = player.DisplayName }
		end
	end
	self:evaluate()
end

function Match.view(self: Match, side: number): { [string]: any }
	local opponent = self.seats[other(side)] or (self.participants and self.participants[other(side)])
	local last = self.last
	local placing = self.phase == "placing"
	return {
		phase = self.phase,
		table = self.refs.id,
		side = side,
		endsAt = self.endsAt,
		turn = self.turn,
		opponent = if opponent then opponent.name else nil,
		myBells = table.clone(self.bells[side]),
		myAlive = self:alive(side),
		-- During placement, do not reveal how many bells the opponent has put down.
		theirAlive = if placing then Config.BELLS else self:alive(other(side)),
		strikes = table.clone(self.struck[side]),
		last = if last then { mine = last.by == side, key = last.key, hit = last.hit } else nil,
		result = if self.phase == "over" then (if self.winner == side then "win" else "lose") else nil,
		reason = self.reason,
	}
end

function Match.updateSign(self: Match)
	local status = self.refs.status
	local a, b = self.seats[1], self.seats[2]
	local p = self.participants
	if self.phase == "idle" then
		status.Text = "Open · sit down to play"
		status.TextColor3 = Color3.fromRGB(160, 255, 160)
	elseif self.phase == "waiting" then
		status.Text = "1/2 · waiting for an opponent"
		status.TextColor3 = Color3.fromRGB(255, 225, 120)
	elseif self.phase == "over" and p then
		status.Text = p[self.winner :: number].name .. " wins!"
		status.TextColor3 = Color3.fromRGB(255, 225, 120)
	elseif a and b then
		status.Text = string.format("%s %d 🛎️ vs 🛎️ %d %s", a.name, self:alive(1), self:alive(2), b.name)
		if self.phase == "placing" then
			status.Text = a.name .. " vs " .. b.name .. " · placing bells"
		end
		status.TextColor3 = Color3.new(1, 1, 1)
	end
end

function Match.broadcast(self: Match)
	self:updateSign()
	for side = 1, 2 do
		local seated = self.seats[side]
		if seated and seated.player then
			self:send(seated.player, self:view(side))
		end
	end
end

function Match.act(self: Match, side: number, kind: string, key: string)
	if kind == "toggle" then
		self:toggle(side, key)
	elseif kind == "strike" then
		self:strike(side, key)
	end
end

return Match
