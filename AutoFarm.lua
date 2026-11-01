local P = game:GetService("Players")
local R = game:GetService("RunService")
local V = game:GetService("VirtualInputManager")
local Core = game:GetService("CoreGui")

local me = P.LocalPlayer

local on = true
local target
local secondTool
local switching = false
local follow

pcall(function()
    local old = Core:FindFirstChild("AutoFarm")
    if old then old:Destroy() end
end)

-- МЕНЮ
local g = Instance.new("ScreenGui")
g.Name = "AutoFarm"
g.ResetOnSpawn = false
g.Parent = Core

local f = Instance.new("Frame", g)
f.Size = UDim2.fromOffset(155, 115)
f.Position = UDim2.new(0.5, -77, 0.5, 0)
f.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
f.Active = true
f.Draggable = true

local status = Instance.new("TextLabel", f)
status.Size = UDim2.new(1, 0, 0, 25)
status.Text = "AUTO FARM ON"
status.TextColor3 = Color3.new(1, 1, 1)
status.BackgroundTransparency = 1

local function btn(txt, y, color)
    local b = Instance.new("TextButton", f)
    b.Size = UDim2.new(1, -10, 0, 35)
    b.Position = UDim2.fromOffset(5, y)
    b.Text = txt
    b.TextColor3 = Color3.new(1, 1, 1)
    b.BackgroundColor3 = color
    return b
end

local start = btn("START", 30, Color3.fromRGB(20, 140, 60))
local stop = btn("STOP", 72, Color3.fromRGB(160, 40, 40))

local function press(k)
    V:SendKeyEvent(true, k, false, game)
    task.wait(0.12)
    V:SendKeyEvent(false, k, false, game)
end

local function clickAt(x, y)
    V:SendMouseButtonEvent(x, y, 0, true, game, 0)
    task.wait(0.05)
    V:SendMouseButtonEvent(x, y, 0, false, game, 0)
end

local function nearest(r)
    local best, d

    for _, n in ipairs(workspace:GetDescendants()) do
        if n:IsA("Model")
        and n ~= me.Character
        and not P:GetPlayerFromCharacter(n) then

            local h = n:FindFirstChildOfClass("Humanoid")
            local t = n:FindFirstChild("HumanoidRootPart")

            if h and t and h.Health > 0 then
                local x = (r.Position - t.Position).Magnitude
                if not d or x < d then
                    best, d = n, x
                end
            end
        end
    end

    return best
end

local function attack()
    local t = target and target:FindFirstChild("HumanoidRootPart")

    if t then
        local cam = workspace.CurrentCamera
        if cam then
            cam.CFrame = CFrame.lookAt(cam.CFrame.Position, t.Position)
        end
    end

    V:SendMouseButtonEvent(0, 0, 0, true, game, 0)
    task.wait(0.05)
    V:SendMouseButtonEvent(0, 0, 0, false, game, 0)

    press(Enum.KeyCode.F)
    press(Enum.KeyCode.C)
    press(Enum.KeyCode.V)
end

-- АВТОФАРМ
local function startFarm()
    if on then return end
    on = true
    status.Text = "AUTO FARM ON"

    task.spawn(function()
        press(Enum.KeyCode.Two)
        task.wait(0.3)

        local c = me.Character
        secondTool = c and c:FindFirstChildOfClass("Tool")
    end)

    follow = R.Heartbeat:Connect(function()
        if not on then return end

        local c = me.Character
        local r = c and c:FindFirstChild("HumanoidRootPart")
        if not r then return end

        local h = target and target:FindFirstChildOfClass("Humanoid")
        local t = target and target:FindFirstChild("HumanoidRootPart")

        if not h or not t or h.Health <= 0 then
            target = nearest(r)
            t = target and target:FindFirstChild("HumanoidRootPart")
        end

        if t then
            r.CFrame = CFrame.lookAt(
                t.Position - Vector3.new(0, 8, 0),
                t.Position
            )
            r.AssemblyLinearVelocity = Vector3.zero
        end
    end)

    task.spawn(function()
        while on do
            local c = me.Character
            local equipped = c and c:FindFirstChildOfClass("Tool")

            if secondTool and equipped ~= secondTool and not switching then
                switching = true
                press(Enum.KeyCode.Two)
                task.wait(0.2)
                switching = false
            end


task.wait(0.5)
        end
    end)

    – АТАКИ
    task.spawn(function()
        while on do
            if target and target.Parent then
                attack()
            end
            task.wait(0.1)
        end
    end)

    – ТРИ КООРДИНАТЫ
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
end

-- КНОПКИ МЕНЮ
start.MouseButton1Click:Connect(function()
    startFarm()
end)

stop.MouseButton1Click:Connect(function()
    on = false
    target = nil
    secondTool = nil
    status.Text = "AUTO FARM OFF"

    if follow then
        follow:Disconnect()
        follow = nil
    end
end)

-- АВТОЗАПУСК ПРИ ЗАПУСКЕ DELTA
startFarm()
