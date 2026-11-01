local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local Core = game:GetService("CoreGui")

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "ClickObjectScanner"
gui.ResetOnSpawn = false
gui.Parent = Core

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(360, 180)
frame.Position = UDim2.fromOffset(20, 100)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
frame.Active = true
frame.Draggable = true
frame.Parent = gui

local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, -12, 1, -12)
label.Position = UDim2.fromOffset(6, 6)
label.BackgroundTransparency = 1
label.TextColor3 = Color3.new(1, 1, 1)
label.TextSize = 14
label.TextWrapped = true
label.TextXAlignment = Enum.TextXAlignment.Left
label.TextYAlignment = Enum.TextYAlignment.Top
label.Text = "Нажми Retry или Start"
label.Parent = frame

local function getText(obj)
    local result = {}

    for _, item in ipairs(obj:GetDescendants()) do
        if item:IsA("TextLabel") or item:IsA("TextButton") then
            if item.Text ~= "" then
                table.insert(result, item.Text)
            end
        end
    end

    return table.concat(result, " | ")
end

UIS.InputBegan:Connect(function(input, processed)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
        return
    end

    local pos = UIS:GetMouseLocation()

    task.defer(function()
        local playerGui = player:FindFirstChildOfClass("PlayerGui")
        if not playerGui then return end

        local objects = playerGui:GetGuiObjectsAtPosition(pos.X, pos.Y)
        local lines = {}

        for _, obj in ipairs(objects) do
            if not obj:IsDescendantOf(gui) then
                table.insert(lines,
                    "Тип: " .. obj.ClassName ..
                    "\nИмя: " .. obj.Name ..
                    "\nПуть: " .. obj:GetFullName() ..
                    "\nТекст: " .. getText(obj)
                )
            end
        end

        if #lines == 0 then
            label.Text = "GUI-объект не найден.\nВозможно, это 3D-кнопка."
        else
            label.Text = table.concat(lines, "\n\n")
            print(label.Text)
        end
    end)
end)



