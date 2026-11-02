local Core = game:GetService("CoreGui")

pcall(function()
    local old = Core:FindFirstChild("EKeyScan")
    if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "EKeyScan"
gui.ResetOnSpawn = false
gui.Parent = Core

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0.85, 0, 0.65, 0)
frame.Position = UDim2.new(0.075, 0, 0.15, 0)
frame.BackgroundColor3 = Color3.fromRGB(25,25,35)

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1,0,0,35)
title.Text = "СКАНЕР КНОПКИ E"
title.TextColor3 = Color3.new(1,1,1)
title.BackgroundTransparency = 1
title.TextSize = 16

local scroll = Instance.new("ScrollingFrame", frame)
scroll.Position = UDim2.fromOffset(5,40)
scroll.Size = UDim2.new(1,-10,1,-45)
scroll.BackgroundColor3 = Color3.fromRGB(35,35,45)
scroll.ScrollBarThickness = 8
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new(0,0,0,0)

local layout = Instance.new("UIListLayout", scroll)
layout.Padding = UDim.new(0,5)

local count = 0

for _, p in ipairs(workspace:GetDescendants()) do
    if p:IsA("ProximityPrompt")
    and p.KeyboardKeyCode == Enum.KeyCode.E then

        count += 1

        local item = Instance.new("TextLabel", scroll)
        item.Size = UDim2.new(1,-10,0,105)
        item.BackgroundColor3 = Color3.fromRGB(50,50,65)
        item.TextColor3 = Color3.new(1,1,1)
        item.TextSize = 12
        item.TextWrapped = true
        item.TextXAlignment = Enum.TextXAlignment.Left
        item.TextYAlignment = Enum.TextYAlignment.Top

        item.Text =
            "№ " .. count ..
            "\nПУТЬ: " .. p:GetFullName() ..
            "\nACTION: " .. p.ActionText ..
            "\nOBJECT: " .. p.ObjectText ..
            "\nENABLED: " .. tostring(p.Enabled)
    end
end

title.Text = "НАЙДЕНО PROMPT С E: " .. count



