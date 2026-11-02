local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")
local RS = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local services = RS.ReplicatedStorage.Packages.Knit.Services
local startRemote = services.DungeonService.RF.StartDungeon

local partyService = services:FindFirstChild("PartyService")
local voteRemote = partyService and partyService:FindFirstChild("VoteOn", true)

local startedEvent = services.DungeonService.RE.DungeonStarted

pcall(function()
    local old = CoreGui:FindFirstChild("AutoFarm")
    if old then old:Destroy() end
end)

local running = false
local target = nil
local interacting = false
local keyDone = false
local doorDone = false
local retryBusy = false
local startedCount = 0
local slotBusy = false
local characterVersion = 0

local gui = Instance.new("ScreenGui")
gui.Name = "AutoFarm"
gui.ResetOnSpawn = false
gui.Parent = CoreGui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(190, 110)
frame.Position = UDim2.new(0.5, -95, 0.5, 0)
frame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
frame.Active = true
frame.Draggable = true
frame.Parent = gui

local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, 0, 0, 35)
label.BackgroundTransparency = 1
label.Text = "AUTO FARM: OFF"
label.TextColor3 = Color3.new(1, 1, 1)
label.TextSize = 14
label.Parent = frame

local stop = Instance.new("TextButton")
stop.Size = UDim2.new(1, -10, 0, 45)
stop.Position = UDim2.fromOffset(5, 50)
stop.Text = "STOP"
stop.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
stop.TextColor3 = Color3.new(1, 1, 1)
stop.TextSize = 16
stop.Parent = frame

local function setStatus(text)
    if running then
        label.Text = text
    end
end

local function press(key)
    VIM:SendKeyEvent(true, key, false, game)
    task.wait(0.1)
    VIM:SendKeyEvent(false, key, false, game)
end

local function holdE(duration)
    VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(duration)
    VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

local function getRoot()
    local character = player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function selectSecondSlot(version)
    if slotBusy or not running then return end
    slotBusy = true

    task.wait(1.5)

    if running and version == characterVersion then
        setStatus("SELECTING SLOT 2")
        press(Enum.KeyCode.Two)
        task.wait(0.5)
    end

    slotBusy = false
end

-- АВТОАТАКА: ТОЛЬКО WORKSPACE.MOBS
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

    return humanoid ~= nil
        and root ~= nil
        and humanoid.Health > 0
end

local function findNearest()
    local folder = workspace:FindFirstChild("Mobs")
    local root = getRoot()

    if not folder or not root then return nil end

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

local function autoAttackLoop()
    local lastAttack = 0
    local attackDelay = 1

    while running do
        if not interacting then
            if not validMob(target) then
                target = findNearest()
            end

            if validMob(target) then
                local root = getRoot()
                local enemyRoot = target:FindFirstChild("HumanoidRootPart")

                if root and enemyRoot then
                    setStatus("TARGET: " .. target.Name)

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

                        if running and not interacting then
                            press(Enum.KeyCode.F)
                            press(Enum.KeyCode.C)
                            press(Enum.KeyCode.V)
                        end
                    end
                end
            else
                target = nil
                setStatus("SEARCHING MOBS...")
            end
        end

        task.wait(0.1)
    end
end

local function dungeonComplete()
    local screen = pg:FindFirstChild("DungeonComplete")

    if not screen then return false end

    if screen:IsA("ScreenGui") and not screen.Enabled then
        return false
    end

    local button = screen:FindFirstChild("RetryBtn", true)

    if not button or not button:IsA("GuiObject") then
        return false
    end

    local obj = button

    while obj and obj ~= pg do
        if obj:IsA("GuiObject") and not obj.Visible then
            return false
        end

        if obj:IsA("ScreenGui") and not obj.Enabled then
            return false
        end

        obj = obj.Parent
    end

    return true
end

startedEvent.OnClientEvent:Connect(function()
    startedCount = startedCount + 1
    keyDone = false
    doorDone = false
    target = nil
end)

local function startDungeon()
    setStatus("STARTING DUNGEON")

    local ok = pcall(function()
        startRemote:InvokeServer()
    end)

    if ok then
        setStatus("AUTO FARM ON")
    else
        setStatus("START ERROR")
    end
end

-- RETRY
local function retryLoop()
    while running do
        if dungeonComplete() and not retryBusy then
            retryBusy = true
            setStatus("RETRYING...")

            local before = startedCount
            local ok = false

            if voteRemote and voteRemote:IsA("RemoteFunction") then
                ok = pcall(function()
                    voteRemote:InvokeServer("Retry")
                end)
            end

            if ok then
                local elapsed = 0

                while running and elapsed < 10 do
                    if startedCount > before then break end
                    task.wait(0.5)
                    elapsed = elapsed + 0.5
                end

                if running and startedCount == before then
                    startDungeon()
                end
            end

            while running and dungeonComplete() do
                task.wait(0.5)
            end

            task.wait(2)
            retryBusy = false
        end

        task.wait(0.5)
    end
end

-- ПОИСК КЛЮЧА
local function findKey()
    local keys = {}

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name:lower() == "key" then
            local prompt = obj:FindFirstChildWhichIsA(
                "ProximityPrompt", true
            )

            local part = obj:IsA("BasePart") and obj
                or obj:FindFirstChild("Handle", true)
                or obj:FindFirstChildWhichIsA("BasePart", true)

            if prompt and part and part:IsA("BasePart") and prompt.Enabled then
                table.insert(keys, {
                    part = part,
                    prompt = prompt
                })
            end
        end
    end

    return keys[2]
end

-- ПОИСК ДВЕРЕЙ
local function findDoors()
    local doors = {}

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name:lower() == "keyhole" then
            local prompt = obj:FindFirstChildWhichIsA(
                "ProximityPrompt", true
            )

            local part = obj:IsA("BasePart") and obj
                or obj:FindFirstChildWhichIsA("BasePart", true)

            if prompt and part and part:IsA("BasePart") and prompt.Enabled then
                table.insert(doors, {
                    part = part,
                    prompt = prompt
                })
            end
        end
    end

    return doors
end

local function collectKey()
    local key = findKey()
    if not key then return false end

    local root = getRoot()
    if not root then return false end

    interacting = true
    setStatus("GOING TO KEY")

    root.CFrame = key.part.CFrame * CFrame.new(0, 2, 0)
    task.wait(1)

    if running then
        setStatus("PICKING KEY")
        press(Enum.KeyCode.E)
        task.wait(2)
    end

    interacting = false
    return running
end

local function unlockDoors()
    local doors = findDoors()
    if #doors == 0 then return false end

    interacting = true

    for i, door in ipairs(doors) do
        if not running then break end

        local root = getRoot()
        if not root then break end

        setStatus("GOING TO DOOR " .. i)

        root.CFrame = door.part.CFrame * CFrame.new(0, 0, -1)
        root.AssemblyLinearVelocity = Vector3.zero

        local attachment = Instance.new("Attachment")
        attachment.Parent = root

        local velocity = Instance.new("LinearVelocity")
        velocity.Attachment0 = attachment
        velocity.MaxForce = math.huge
        velocity.VectorVelocity = Vector3.zero
        velocity.Parent = root

        task.wait(3)

        if running then
            setStatus("UNLOCKING DOOR " .. i)

            for attempt = 1, 3 do
                if not running then break end
                holdE(1.5)
                task.wait(1)
            end
        end

        velocity:Destroy()
        attachment:Destroy()

        task.wait(2)
    end

    if running then
        doorDone = true
        setStatus("HOLDING 2")

        VIM:SendKeyEvent(true, Enum.KeyCode.Two, false, game)
        task.wait(3)
        VIM:SendKeyEvent(false, Enum.KeyCode.Two, false, game)
    end

    interacting = false
    return running
end

local function keyDoorLoop()
    while running do
        if not keyDone then
            if findKey() then
                if collectKey() and running then
                    keyDone = true
                end
            end

        elseif not doorDone then
            if #findDoors() > 0 then
                unlockDoors()
            end
        end

        task.wait(1)
    end
end

local function startFarm()
    if running then return end

    running = true
    target = nil
    interacting = false
    keyDone = false
    doorDone = false
    retryBusy = false

    label.Text = "AUTO FARM: ON"

    task.spawn(function()
        selectSecondSlot(characterVersion)
    end)

    task.spawn(startDungeon)
    task.spawn(autoAttackLoop)
    task.spawn(retryLoop)
    task.spawn(keyDoorLoop)
end

player.CharacterAdded:Connect(function()
    characterVersion = characterVersion + 1
    target = nil

    if running then
        task.spawn(function()
            selectSecondSlot(characterVersion)
        end)
    end
end)

stop.MouseButton1Click:Connect(function()
    running = false
    interacting = false
    target = nil
    retryBusy = false
    keyDone = false
    doorDone = false

    VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    VIM:SendKeyEvent(false, Enum.KeyCode.Two, false, game)
    VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    VIM:SendKeyEvent(false, Enum.KeyCode.F, false, game)
    VIM:SendKeyEvent(false, Enum.KeyCode.C, false, game)
    VIM:SendKeyEvent(false, Enum.KeyCode.V, false, game)

    label.Text = "AUTO FARM: OFF"
end)

startFarm()
