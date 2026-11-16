-- The chair shop on this client: spins the chairs on the pedestals, and shows "Unequip" on the
-- pedestal of the skin you have equipped.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ChairShopClient = {}

local SPIN = 0.6 -- radians per second

local player = Players.LocalPlayer

function ChairShopClient.start()
	task.spawn(function()
		local shop = workspace:WaitForChild("World"):WaitForChild("ChairShop")

		local function refresh()
			local equipped = player:GetAttribute("ChairSkin")
			for _, slot in shop:GetChildren() do
				local base = slot:FindFirstChild("Pedestal")
				local prompt = base and base:FindFirstChildOfClass("ProximityPrompt")
				if prompt then
					local mine = equipped ~= nil and equipped ~= "" and slot:GetAttribute("SkinId") == equipped
					prompt.ActionText = if mine then "Unequip" else "Equip"
				end
			end
		end
		player:GetAttributeChangedSignal("ChairSkin"):Connect(refresh)
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
