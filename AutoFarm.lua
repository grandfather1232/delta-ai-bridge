local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")
local Core = game:GetService("CoreGui")
local me = Players.LocalPlayer

pcall(function()
    local old = Core:FindFirstChild("KeyDoorTest")
    if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "KeyDoorTest"
gui.ResetOnSpawn = false
gui.Parent = Core

local label = Instance.new("TextLabel")
label.Parent = gui
label.Size = UDim2.fromOffset(260, 55)
label.Position = UDim2.new(0.5, -130, 0.2, 0)
label.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
label.TextColor3 = Color3.new(1, 1, 1)
label.TextScaled = true

local function getRoot()
    local c = me.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function pressE(duration)
    VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(duration)
    VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

-- Поиск ключей
local keys = {}

for _, obj in ipairs(workspace:GetDescendants()) do
    if obj.Name:lower() == "key" then
        local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
        local part = obj:IsA("BasePart") and obj
            or obj:FindFirstChild("Handle", true)
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

label.Text = "KEYS FOUND: " .. #keys
task.wait(1)

-- Подбор второго ключа
local key = keys[2]

if not key then
    label.Text = "SECOND KEY NOT FOUND"
    return
end

local root = getRoot()
if not root then return end

label.Text = "GOING TO KEY"
root.CFrame = key.part.CFrame * CFrame.new(0, 2, 0)
task.wait(1)

label.Text = "PICKING KEY"
pressE(0.25)
task.wait(2)

-- Поиск замочных скважин
local doors = {}

for _, obj in ipairs(workspace:GetDescendants()) do
    if obj.Name:lower() == "keyhole" then
        local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)

        local part = obj:IsA("BasePart") and obj
            or obj:FindFirstChildWhichIsA("BasePart", true)

        if prompt and part and prompt.Enabled then
            table.insert(doors, {
                prompt = prompt,
                part = part
            })
        end
    end
end

label.Text = "DOORS FOUND: " .. #doors
task.wait(1)

-- Телепорт и зависание возле двери
for i, door in ipairs(doors) do
    root = getRoot()
    if not root then break end

    label.Text = "GOING TO DOOR " .. i

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

    label.Text = "UNLOCKING DOOR " .. i

    for attempt = 1, 3 do
        pressE(1.5)
        task.wait(1)
    end

    velocity:Destroy()
    attachment:Destroy()

    task.wait(2)
end

label.Text = "TEST FINISHED"
