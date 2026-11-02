local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")
local Core = game:GetService("CoreGui")

local player = Players.LocalPlayer
local stopped = false

pcall(function()
    local old = Core:FindFirstChild("AllKeysTest")
    if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "AllKeysTest"
gui.ResetOnSpawn = false
gui.Parent = Core

local label = Instance.new("TextLabel", gui)
label.Size = UDim2.fromOffset(300, 85)
label.Position = UDim2.new(0.5, -150, 0.2, 0)
label.BackgroundColor3 = Color3.fromRGB(25,25,35)
label.TextColor3 = Color3.new(1,1,1)
label.TextSize = 15
label.TextWrapped = true

local stop = Instance.new("TextButton", gui)
stop.Size = UDim2.fromOffset(120,40)
stop.Position = UDim2.new(0.5, -60, 0.2, 90)
stop.Text = "STOP"

stop.MouseButton1Click:Connect(function()
    stopped = true
    label.Text = "Остановлено"
end)

task.spawn(function()
    local keys = {}

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name:lower() == "key" then
            local prompt = obj:FindFirstChildWhichIsA(
                "ProximityPrompt", true
            )
            local part = obj:FindFirstChild("Handle", true)
                or obj:FindFirstChildWhichIsA("BasePart", true)

            if prompt and part and part:IsA("BasePart") then
                table.insert(keys, {
                    object = obj,
                    prompt = prompt,
                    part = part
                })
            end
        end
    end

    label.Text = "Найдено объектов: " .. #keys
    task.wait(1)

    for i, data in ipairs(keys) do
        if stopped then break end

        if data.object:IsDescendantOf(workspace)
        and data.prompt.Enabled then
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")

            if root then
                label.Text = "Проверяю ключ " .. i .. "/" .. #keys

                root.CFrame = data.part.CFrame * CFrame.new(0, 3, 0)
                task.wait(1)

                if stopped then break end

                VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                task.wait(0.3)
                VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)

                task.wait(1)
            end
        end
    end

    if not stopped then
        label.Text = "Перебор завершён"
    end
end)
