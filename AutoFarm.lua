local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local player = Players.LocalPlayer

pcall(function()
    local old = CoreGui:FindFirstChild("NPCScanner")
    if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "NPCScanner"
gui.ResetOnSpawn = false
gui.Parent = CoreGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 330, 0, 400)
frame.Position = UDim2.new(0.5, -165, 0.5, -200)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
frame.Active = true
frame.Draggable = true
frame.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 35)
title.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
title.TextColor3 = Color3.new(1, 1, 1)
title.Text = "NPC SCANNER"
title.TextSize = 16
title.Parent = frame

local close = Instance.new("TextButton")
close.Size = UDim2.new(0, 35, 0, 30)
close.Position = UDim2.new(1, -35, 0, 2)
close.Text = "X"
close.Parent = frame

local scan = Instance.new("TextButton")
scan.Size = UDim2.new(1, -10, 0, 35)
scan.Position = UDim2.new(0, 5, 0, 40)
scan.Text = "ОБНОВИТЬ СПИСОК"
scan.Parent = frame

local output = Instance.new("TextLabel")
output.Size = UDim2.new(1, -10, 1, -85)
output.Position = UDim2.new(0, 5, 0, 80)
output.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
output.TextColor3 = Color3.new(1, 1, 1)
output.TextSize = 12
output.TextXAlignment = Enum.TextXAlignment.Left
output.TextYAlignment = Enum.TextYAlignment.Top
output.TextWrapped = true
output.Font = Enum.Font.Code
output.Parent = frame

local function getPath(obj)
    local names = {}
    local current = obj

    while current and current ~= workspace do
        table.insert(names, 1, current.Name)
        current = current.Parent
    end

    return "Workspace/" .. table.concat(names, "/")
end

local function doScan()
    local groups = {}
    local total = 0

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj ~= player.Character
        and not Players:GetPlayerFromCharacter(obj) then

            local hum = obj:FindFirstChildOfClass("Humanoid")
            local root = obj:FindFirstChild("HumanoidRootPart")

            if hum and root then
                local direct = obj
                while direct.Parent and direct.Parent ~= workspace do
                    direct = direct.Parent
                end

                local folderName = direct.Name

                groups[folderName] = groups[folderName] or {
                    count = 0,
                    models = {}
                }

                groups[folderName].count += 1

                if #groups[folderName].models < 8 then
                    table.insert(
                        groups[folderName].models,
                        obj.Name .. " | " .. getPath(obj)
                    )
                end

                total += 1
            end
        end
    end

    local lines = {
        "Найдено моделей с Humanoid: " .. total,
        ""
    }

    for folder, data in pairs(groups) do
        table.insert(lines, "ПАПКА: " .. folder)
        table.insert(lines, "Количество: " .. data.count)

        for _, name in ipairs(data.models) do
            table.insert(lines, "  " .. name)
        end

        table.insert(lines, "")
    end

    if total == 0 then
        table.insert(lines, "NPC пока не найдены.")
    end

    output.Text = table.concat(lines, "\n")
end

scan.MouseButton1Click:Connect(doScan)
close.MouseButton1Click:Connect(function()
    gui:Destroy()
end)

doScan()
