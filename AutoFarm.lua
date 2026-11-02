local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer

pcall(function()
    local old = CoreGui:FindFirstChild("AutoAttackTest")
    if old then old:Destroy() end
end)

local running = true
local target = nil
local lastAttack = 0
local attackDelay = 1

local gui = Instance.new("ScreenGui")
gui.Name = "AutoAttackTest"
gui.ResetOnSpawn = false
gui.Parent = CoreGui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(190, 90)
frame.Position = UDim2.new(0.5, -95, 0.5, 0)
frame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
frame.Active = true
frame.Draggable = true
frame.Parent = gui

local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, 0, 0, 30)
label.BackgroundTransparency = 1
label.Text = "AUTO ATTACK: ON"
label.TextColor3 = Color3.new(1, 1, 1)
label.Parent = frame

local stop = Instance.new("TextButton")
stop.Size = UDim2.new(1, -10, 0, 40)
stop.Position = UDim2.fromOffset(5, 40)
stop.Text = "STOP"
stop.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
stop.TextColor3 = Color3.new(1, 1, 1)
stop.Parent = frame

local function getRoot()
    local character = player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function validMob(mob)
    local folder = workspace:FindFirstChild("Mobs")
    if not folder or not mob or not mob:IsA("Model") then
        return false
    end

    if not mob:IsDescendantOf(folder) then
        return false
    end

    local humanoid = mob:FindFirstChildOfClass("Humanoid")
    local root = mob:FindFirstChild("HumanoidRootPart")

    return humanoid ~= nil and root ~= nil and humanoid.Health > 0
end

local function findNearest()
    local folder = workspace:FindFirstChild("Mobs")
    local root = getRoot()

    if not folder or not root then
        return nil
    end

    local nearest = nil
    local shortest = math.huge

    for _, mob in ipairs(folder:GetDescendants()) do
        if validMob(mob) then
            local mobRoot = mob:FindFirstChild("HumanoidRootPart")
            local distance = (root.Position - mobRoot.Position).Magnitude

            if distance < shortest then
                shortest = distance
                nearest = mob
            end
        end
    end

    return nearest
end

local function press(key)
    VIM:SendKeyEvent(true, key, false, game)
    task.wait(0.1)
    VIM:SendKeyEvent(false, key, false, game)
end

local connection = RunService.Heartbeat:Connect(function()
    if not running then return end

    if not validMob(target) then
        target = findNearest()
    end

    if not validMob(target) then
        label.Text = "NO MOBS FOUND"
        return
    end

    local root = getRoot()
    local enemyRoot = target:FindFirstChild("HumanoidRootPart")

    if not root or not enemyRoot then return end

    label.Text = "TARGET: " .. target.Name

    root.CFrame = CFrame.lookAt(
        enemyRoot.Position - Vector3.new(0, 8, 0),
        enemyRoot.Position
    )

    root.AssemblyLinearVelocity = Vector3.zero

    if os.clock() - lastAttack >= attackDelay then
        lastAttack = os.clock()

        VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        task.wait(0.1)
        VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)

        press(Enum.KeyCode.F)
        press(Enum.KeyCode.C)
        press(Enum.KeyCode.V)
    end
end)

stop.MouseButton1Click:Connect(function()
    running = false
    target = nil

    if connection then
        connection:Disconnect()
    end

    VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    VIM:SendKeyEvent(false, Enum.KeyCode.F, false, game)
    VIM:SendKeyEvent(false, Enum.KeyCode.C, false, game)
    VIM:SendKeyEvent(false, Enum.KeyCode.V, false, game)

    label.Text = "AUTO ATTACK: OFF"
    stop.Text = "STOPPED"
end)





