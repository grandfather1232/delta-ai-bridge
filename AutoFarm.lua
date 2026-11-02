local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local running = true

pcall(function()
    local old = CoreGui:FindFirstChild("KeyTest")
    if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "KeyTest"
gui.ResetOnSpawn = false
gui.Parent = CoreGui

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.fromOffset(220, 100)
frame.Position = UDim2.new(0.5, -110, 0.5, 0)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
frame.Active = true
frame.Draggable = true

local status = Instance.new("TextLabel", frame)
status.Size = UDim2.new(1, 0, 0, 55)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.new(1, 1, 1)
status.TextWrapped = true
status.Text = "Поиск ключа..."

local stop = Instance.new("TextButton", frame)
stop.Size = UDim2.new(1, -10, 0, 35)
stop.Position = UDim2.fromOffset(5, 60)
stop.Text = "STOP"
stop.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
stop.TextColor3 = Color3.new(1, 1, 1)

stop.MouseButton1Click:Connect(function()
    running = false
    status.Text = "Остановлено"
end)

local function findKey()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name:lower() == "key" then
            local prompt = obj:FindFirstChildWhichIsA(
                "ProximityPrompt", true
            )

            if prompt and prompt.Enabled then
                local part = prompt.Parent
                if part:IsA("BasePart") then
                    return obj, prompt, part
                end

                local model = obj:IsA("Model") and obj
                local base = model and (
                    model.PrimaryPart or
                    model:FindFirstChildWhichIsA("BasePart", true)
                )

                if base then
                    return obj, prompt, base
                end
            end
        end
    end
end

task.spawn(function()
    while running do
        local key, prompt, part = findKey()

        if not key then
            status.Text = "Активный ключ не найден"
            task.wait(1)
        else
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")

            if root then
                status.Text = "Ключ найден!\nПеремещение..."
                root.CFrame = part.CFrame * CFrame.new(0, 2, 0)
                task.wait(0.7)

                if running then
                    status.Text = "Нажимаю E..."
                    VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                    task.wait(0.3)
                    VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                    task.wait(1)
                end

                if not key:IsDescendantOf(workspace) then
                    status.Text = "Ключ подобран!"
                else
                    status.Text = "Ключ ещё на месте"
                end
            else
                status.Text = "Персонаж не найден"
            end

            task.wait(1)
        end
    end
end)





