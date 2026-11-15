-- The on-screen HUD: phase banner with timer, bell counts, toasts, and the lobby hint.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Hud = {}

local GOLD = Color3.fromRGB(255, 205, 90)
local PANEL = Color3.fromRGB(28, 24, 34)

local gui = Instance.new("ScreenGui")
gui.Name = "BellshipHud"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = 0.25
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	for key, value in props do
		(l :: any)[key] = value
	end
	l.Parent = parent
	return l
end

-- Banner at the top.
local banner = Instance.new("Frame")
banner.Name = "Banner"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 10)
banner.Size = UDim2.fromOffset(480, 92)
banner.BackgroundColor3 = PANEL
banner.BackgroundTransparency = 0.15
banner.Visible = false
banner.Parent = gui
corner(banner, 16)
stroke(banner, GOLD, 2)
local title = label(
	banner,
	{ Position = UDim2.fromOffset(20, 8), Size = UDim2.new(1, -110, 0, 44), TextXAlignment = Enum.TextXAlignment.Left }
)
local subtitle = label(banner, {
	Position = UDim2.fromOffset(20, 54),
	Size = UDim2.new(1, -110, 0, 26),
	TextXAlignment = Enum.TextXAlignment.Left,
	Font = Enum.Font.GothamMedium,
	TextColor3 = Color3.fromRGB(225, 214, 192),
})
local timer = Instance.new("Frame")
timer.AnchorPoint = Vector2.new(1, 0.5)
timer.Position = UDim2.new(1, -14, 0.5, 0)
timer.Size = UDim2.fromOffset(68, 68)
timer.BackgroundColor3 = Color3.fromRGB(50, 42, 56)
timer.Parent = banner
corner(timer, 34)
stroke(timer, GOLD, 2)
local timerText = label(timer, { Size = UDim2.fromScale(1, 1), Text = "", TextColor3 = GOLD })
local timerPad = Instance.new("UIPadding")
timerPad.PaddingTop = UDim.new(0, 14)
timerPad.PaddingBottom = UDim.new(0, 14)
timerPad.Parent = timerText

-- Bell counts at the bottom.
local score = Instance.new("Frame")
score.Name = "Score"
score.AnchorPoint = Vector2.new(0.5, 1)
score.Position = UDim2.new(0.5, 0, 1, -16)
score.Size = UDim2.fromOffset(480, 58)
score.BackgroundColor3 = PANEL
score.BackgroundTransparency = 0.15
score.Visible = false
score.Parent = gui
corner(score, 14)
stroke(score, GOLD, 2)
local mine = label(score, {
	Position = UDim2.fromOffset(16, 9),
	Size = UDim2.new(0.5, -24, 0, 40),
	TextXAlignment = Enum.TextXAlignment.Left,
	RichText = true,
})
local theirs = label(score, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 9),
	Size = UDim2.new(0.5, -24, 0, 40),
	TextXAlignment = Enum.TextXAlignment.Right,
	RichText = true,
})
label(score, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 14),
	Size = UDim2.fromOffset(40, 30),
	Text = "vs",
	TextColor3 = GOLD,
})

-- Big centre toast for strikes and results.
local toast = label(gui, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0, 160),
	Size = UDim2.fromOffset(600, 90),
	TextTransparency = 1,
	TextStrokeTransparency = 1,
	TextStrokeColor3 = Color3.fromRGB(40, 25, 10),
	ZIndex = 5,
})
local toastScale = Instance.new("UIScale")
toastScale.Parent = toast

-- Lobby hint.
local hint = label(gui, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.fromOffset(520, 34),
	Text = "🛎️ Find a table and sit down to play Bellship",
	TextStrokeTransparency = 0.5,
})

gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local function bells(alive: number, total: number): string
	local text = ""
	for i = 1, total do
		if i <= alive then
			text ..= "🛎️"
		else
			text ..= '<font transparency="0.75">🛎️</font>'
		end
	end
	return text
end

local function escape(text: string): string
	return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

function Hud.toast(text: string, color: Color3)
	toast.Text = text
	toast.TextColor3 = color
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0.2
	toastScale.Scale = 0.6
	TweenService:Create(toastScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	TweenService:Create(toast, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1.1), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
end

function Hud.setTimer(seconds: number?)
	timer.Visible = seconds ~= nil
	if seconds then
		timerText.Text = tostring(math.max(0, math.ceil(seconds)))
		timerText.TextColor3 = if seconds <= 5 then Color3.fromRGB(255, 110, 100) else GOLD
	end
end

function Hud.update(state: { [string]: any }?, total: number)
	local phase = if state then state.phase else "none"
	hint.Visible = phase == "none"
	banner.Visible = phase ~= "none"
	score.Visible = phase == "placing" or phase == "battle" or phase == "over"
	if not state or phase == "none" then
		return
	end
	local opponent = state.opponent or "Opponent"
	if phase == "waiting" then
		title.Text = "Waiting for an opponent…"
		subtitle.Text = "Someone has to sit across from you · jump to leave"
	elseif phase == "placing" then
		title.Text = "Place your bells"
		subtitle.Text = string.format("Click squares on your side · %d/%d placed", state.myAlive, total)
	elseif phase == "battle" then
		if state.turn == state.side then
			title.Text = "Your turn!"
			subtitle.Text = "Press a square on " .. opponent .. "'s side"
		elseif state.turn == 0 then
			local last = state.last
			title.Text = if last and last.hit then "DING!" else "Miss"
			subtitle.Text = if last
				then (if last.mine then "You pressed " else opponent .. " pressed ") .. last.key
				else ""
		else
			title.Text = opponent .. "'s turn"
			subtitle.Text = "Hold your breath…"
		end
	elseif phase == "over" then
		local win = state.result == "win"
		title.Text = if win then "You win! 🛎️" else "You lose"
		if state.reason == "left" then
			subtitle.Text = if win then opponent .. " left the table" else "You left the table"
		else
			subtitle.Text = if win
				then "You rang all of " .. opponent .. "'s bells"
				else opponent .. " rang all of your bells"
			subtitle.Text ..= " · stay seated for a rematch"
		end
	end
	mine.Text = "You  " .. bells(state.myAlive, total)
	theirs.Text = bells(state.theirAlive, total) .. "  " .. escape(opponent)
end

return Hud
