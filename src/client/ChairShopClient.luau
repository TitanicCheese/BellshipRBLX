-- The chair shop on this client: spins the chairs on the pedestals, and labels each pedestal's
-- button "Buy $1,500", "Equip" or "Unequip" for you.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RewardsConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RewardsConfig"))

local ChairShopClient = {}

local SPIN = 0.6 -- radians per second

local player = Players.LocalPlayer

function ChairShopClient.start()
	task.spawn(function()
		local shop = workspace:WaitForChild("World"):WaitForChild("ChairShop")

		local function refresh()
			local equipped = player:GetAttribute("ChairSkin")
			local owned = string.split(tostring(player:GetAttribute("OwnedSkins") or ""), ",")
			for _, slot in shop:GetChildren() do
				local base = slot:FindFirstChild("Pedestal")
				local prompt = base and base:FindFirstChildOfClass("ProximityPrompt")
				local id = slot:GetAttribute("SkinId")
				if prompt and id then
					local price = slot:GetAttribute("Price")
					if not table.find(owned, id) then
						prompt.ActionText = "Buy "
							.. RewardsConfig.money(if typeof(price) == "number" then price else 0)
					elseif equipped == id then
						prompt.ActionText = "Unequip"
					else
						prompt.ActionText = "Equip"
					end
				end
			end
		end
		player:GetAttributeChangedSignal("ChairSkin"):Connect(refresh)
		player:GetAttributeChangedSignal("OwnedSkins"):Connect(refresh)
		for _, slot in shop:GetChildren() do
			slot:GetAttributeChangedSignal("SkinId"):Connect(refresh)
		end
		refresh()

		RunService.RenderStepped:Connect(function()
			local angle = CFrame.Angles(0, os.clock() * SPIN % (math.pi * 2), 0)
			for _, slot in shop:GetChildren() do
				local display = slot:FindFirstChild("Display")
				local base = display and display:GetAttribute("Base")
				if display and display:IsA("Model") and typeof(base) == "CFrame" then
					display:PivotTo(base * angle)
				end
			end
		end)
	end)
end

return ChairShopClient
