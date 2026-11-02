local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local player = Players.LocalPlayer

pcall(function()
    local old = CoreGui:FindFirstChild("KeyCompare")
    if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "KeyCompare"
gui.ResetOnSpawn = false
gui.Parent = CoreGui

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 350, 0, 400)
frame.Position = UDim2.new(0, 15, 0.2, 0)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)

local label = Instance.new("TextLabel", frame)
label.Size = UDim2.new(1, -10, 1, -45)
label.Position = UDim2.fromOffset(5, 5)
label.BackgroundTransparency = 1
label.TextColor3 = Color3.new(1, 1, 1)
label.TextSize = 12
label.TextWrapped = true
label.TextXAlignment = Enum.TextXAlignment.Left
label.TextYAlignment = Enum.TextYAlignment.Top

local refresh = Instance.new("TextButton", frame)
refresh.Size = UDim2.new(1, -10, 0, 35)
refresh.Position = UDim2.new(0, 5, 1, -40)
refresh.Text = "ОБНОВИТЬ"

local function scan()
    local root = player.Character and
        player.Character:FindFirstChild("HumanoidRootPart")

    local results = {}

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name:lower() == "key" then
            local prompt = obj:FindFirstChildWhichIsA(
                "ProximityPrompt", true
            )

            local part = obj:IsA("BasePart") and obj
                or obj:FindFirstChildWhichIsA("BasePart", true)

            local distance = "?"
            if root and part then
                distance = string.format(
                    "%.1f", (root.Position - part.Position).Magnitude
                )
            end

            local info = {
                "ПУТЬ: " .. obj:GetFullName(),
                "ТИП: " .. obj.ClassName,
                "ДИСТАНЦИЯ: " .. distance,
                "ДЕТЕЙ: " .. #obj:GetChildren()
            }

            if prompt then
                table.insert(info,
                    "PROMPT: " .. prompt:GetFullName())
                table.insert(info,
                    "ACTION: " .. prompt.ActionText)
                table.insert(info,
                    "HOLD: " .. prompt.HoldDuration)
                table.insert(info,
                    "DISTANCE: " .. prompt.MaxActivationDistance)
                table.insert(info,
                    "ENABLED: " .. tostring(prompt.Enabled))
            else
                table.insert(info, "PROMPT: НЕТ")
            end

            for _, child in ipairs(obj:GetChildren()) do
                table.insert(info,
                    "CHILD: " .. child.Name .. " [" ..
                    child.ClassName .. "]")
            end

            table.insert(results, table.concat(info, "\n"))
        end
    end

    label.Text = #results > 0
        and table.concat(results, "\n\n----------------\n\n")
        or "Объекты Key не найдены"
end

refresh.MouseButton1Click:Connect(scan)
scan()


