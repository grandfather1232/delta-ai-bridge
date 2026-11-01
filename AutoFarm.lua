local P = game:GetService("Players")
local R = game:GetService("RunService")
local V = game:GetService("VirtualInputManager")
local Core = game:GetService("CoreGui")

local me = P.LocalPlayer
local on = true
local target
local secondTool
local switching = false

-- Удаление старой версии
pcall(function()
    local old = Core:FindFirstChild("AutoFarm")
    if old then old:Destroy() end
end)

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "AutoFarm"
gui.ResetOnSpawn = false
gui.Parent = Core

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.fromOffset(155, 75)
frame.Position = UDim2.new(0.5, -77, 0.5, 0)
frame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
frame.Active = true
frame.Draggable = true

local status = Instance.new("TextLabel", frame)
status.Size = UDim2.new(1, 0, 0, 30)
status.Text = "AUTO FARM ON"
status.TextColor3 = Color3.new(1, 1, 1)
status.BackgroundTransparency = 1

local stop = Instance.new("TextButton", frame)
stop.Size = UDim2.new(1, -10, 0, 35)
stop.Position = UDim2.fromOffset(5, 35)
stop.Text = "STOP"
stop.TextColor3 = Color3.new(1, 1, 1)
stop.BackgroundColor3 = Color3.fromRGB(170, 40, 40)

local function press(key)
    V:SendKeyEvent(true, key, false, game)
    task.wait(0.12)
    V:SendKeyEvent(false, key, false, game)
end

local function clickAt(x, y)
    V:SendMouseButtonEvent(x, y, 0, true, game, 0)
    task.wait(0.05)
    V:SendMouseButtonEvent(x, y, 0, false, game, 0)
end

-- Поиск ближайшего NPC
local function nearest(root)
    local best, distance

    for _, npc in ipairs(workspace:GetDescendants()) do
        if npc:IsA("Model")
        and npc ~= me.Character
        and not P:GetPlayerFromCharacter(npc) then

            local humanoid = npc:FindFirstChildOfClass("Humanoid")
            local part = npc:FindFirstChild("HumanoidRootPart")

            if humanoid and part and humanoid.Health > 0 then
                local d = (root.Position - part.Position).Magnitude

                if not distance or d < distance then
                    best = npc
                    distance = d
                end
            end
        end
    end

    return best
end

-- Атака
local function attack()
    if not on then return end

    local part = target and target:FindFirstChild("HumanoidRootPart")

    if part then
        local camera = workspace.CurrentCamera

        if camera then
            camera.CFrame = CFrame.lookAt(
                camera.CFrame.Position,
                part.Position
            )
        end
    end

    V:SendMouseButtonEvent(0, 0, 0, true, game, 0)
    task.wait(0.05)
    V:SendMouseButtonEvent(0, 0, 0, false, game, 0)

    press(Enum.KeyCode.F)
    press(Enum.KeyCode.C)
    press(Enum.KeyCode.V)
end

-- Остановка
stop.MouseButton1Click:Connect(function()
    on = false
    target = nil
    status.Text = "AUTO FARM OFF"
    gui:Destroy()
end)

-- Выбор второго слота
task.spawn(function()
    press(Enum.KeyCode.Two)
    task.wait(0.3)

    local character = me.Character
    secondTool = character and character:FindFirstChildOfClass("Tool")
end)

-- Автофарм: позиция и поиск NPC
R.Heartbeat:Connect(function()
    if not on then return end

    local character = me.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")

    if not root then return end

    local humanoid = target and target:FindFirstChildOfClass("Humanoid")
    local part = target and target:FindFirstChild("HumanoidRootPart")

    if not humanoid or not part or humanoid.Health <= 0 then
        target = nearest(root)
        part = target and target:FindFirstChild("HumanoidRootPart")
    end

    if part then
        root.CFrame = CFrame.lookAt(
            part.Position - Vector3.new(0, 8, 0),
            part.Position
        )

        root.AssemblyLinearVelocity = Vector3.zero
    end
end)

-- Проверка второго слота
task.spawn(function()
    while on do
        local character = me.Character
        local equipped = character and character:FindFirstChi


ldOfClass("Tool")

        if secondTool and equipped ~= secondTool and not switching then
            switching = true
            press(Enum.KeyCode.Two)
            task.wait(0.2)
            switching = false
        end

        task.wait(0.5)
    end
end)

-- Атаки без паузы 0.5 между комбинациями
task.spawn(function()
    while on do
        if target and target.Parent then
            attack()
        end

        task.wait(0.1)
    end
end)

-- Автонажатия по трём координатам
task.spawn(function()
    while on do
        clickAt(362, 440)
        task.wait(0.1)

        clickAt(544, 497)
        task.wait(0.1)

        clickAt(480, 89)
        task.wait(2)
    end
end)



