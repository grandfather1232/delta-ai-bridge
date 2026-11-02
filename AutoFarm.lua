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

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.fromOffset(260, 110)
frame.Position = UDim2.new(0.5, -130, 0.25, 0)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
frame.Active = true
frame.Draggable = true

local status = Instance.new("TextLabel", frame)
status.Size = UDim2.new(1, 0, 0, 65)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.new(1, 1, 1)
status.TextWrapped = true
status.Text = "Подготовка..."

local stop = Instance.new("TextButton", frame)
stop.Size = UDim2.new(1, -10, 0, 35)
stop.Position = UDim2.fromOffset(5, 70)
stop.Text = "STOP"
stop.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
stop.TextColor3 = Color3.new(1, 1, 1)

stop.MouseButton1Click:Connect(function()
    stopped = true
    status.Text = "Остановлено"
end)

task.spawn(function()
    local keys = {}

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name:lower() == "key" then
            local prompt = obj:FindFirstChildWhichIsA(
                "ProximityPrompt", true
            )

            local part = obj:FindFirstChild("Handle", true)
            if not (part and part:IsA("BasePart")) then
                part = obj:FindFirstChildWhichIsA("BasePart", true)
            end

            if prompt and part then
                table.insert(keys, {
                    object = obj,
                    prompt = prompt,
                    part = part
                })
            end
        end
    end

    status.Text = "Найдено объектов: " .. #keys
    task.wait(1)

    for i, data in ipairs(keys) do
        if stopped then break end

        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")

        if root and data.object:IsDescendantOf(workspace)
        and data.prompt.Enabled then

            status.Text = "Проверяю ключ " .. i .. "/" .. #keys

            root.CFrame = data.part.CFrame * CFrame.new(0, 2, 0)
            task.wait(1)

            if stopped then break end

            VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(0.25)
            VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)

            task.wait(1)

            if not data.object:IsDescendantOf(workspace) then
                status.Text = "Ключ " .. i .. ": объект исчез"
            elseif not data.prompt.Enabled then
                status.Text = "Ключ " .. i .. ": взаимодействие отключено"
            else
                status.Text = "Ключ " .. i .. ": остался на месте"
            end

            task.wait(1)
        end
    end

    if not stopped then
        status.Text = "Проверка завершена"
    end
end)



