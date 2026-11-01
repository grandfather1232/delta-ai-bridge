local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

pcall(function()
    local old = CoreGui:FindFirstChild("ButtonScanner")
    if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "ButtonScanner"
gui.ResetOnSpawn = false
gui.Parent = CoreGui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(390, 350)
frame.Position = UDim2.new(0, 20, 0.2, 0)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
frame.Active = true
frame.Draggable = true
frame.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 35)
title.Text = "BUTTON SCANNER"
title.TextColor3 = Color3.new(1, 1, 1)
title.BackgroundTransparency = 1
title.Parent = frame

local output = Instance.new("TextLabel")
output.Size = UDim2.new(1, -10, 1, -45)
output.Position = UDim2.fromOffset(5, 40)
output.BackgroundTransparency = 1
output.TextColor3 = Color3.fromRGB(100, 255, 140)
output.TextSize = 13
output.TextXAlignment = Enum.TextXAlignment.Left
output.TextYAlignment = Enum.TextYAlignment.Top
output.TextWrapped = true
output.Parent = frame

local function scan()
    local lines = {}

    for _, obj in ipairs(playerGui:GetDescendants()) do
        if obj:IsA("GuiButton") or obj:IsA("TextLabel") then
            local txt = ""

            if obj:IsA("TextButton") or obj:IsA("TextLabel") then
                txt = obj.Text
            end

            if obj:IsA("ImageButton") then
                txt = "[IMAGE BUTTON]"
            end

            if obj.Visible and obj.AbsoluteSize.X > 0
            and obj.AbsoluteSize.Y > 0 then
                local path = obj:GetFullName()

                if txt ~= "" or obj:IsA("GuiButton") then
                    table.insert(lines,
                        obj.ClassName .. " | " ..
                        obj.Name .. " | " ..
                        txt .. "\n" .. path
                    )
                end
            end
        end
    end

    output.Text = table.concat(lines, "\n\n")

    if #lines == 0 then
        output.Text = "Видимые кнопки пока не найдены."
    end
end

task.spawn(function()
    while gui.Parent do
        scan()
        task.wait(1)
    end
end)





