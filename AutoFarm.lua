local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")
local Core = game:GetService("CoreGui")
local me = Players.LocalPlayer

pcall(function()
    local old = Core:FindFirstChild("DoorTest")
    if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "DoorTest"
gui.ResetOnSpawn = false
gui.Parent = Core

local label = Instance.new("TextLabel")
label.Parent = gui
label.Size = UDim2.fromOffset(250, 55)
label.Position = UDim2.new(0.5, -125, 0.2, 0)
label.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
label.TextColor3 = Color3.new(1, 1, 1)
label.TextScaled = true

local function holdE()
    VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(1.5)
    VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

local found = {}

for _, obj in ipairs(workspace:GetDescendants()) do
    if obj.Name:lower() == "keyhole" then
        local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)

        local part = obj:IsA("BasePart") and obj
            or obj:FindFirstChildWhichIsA("BasePart", true)

        if prompt and part and prompt.Enabled then
            table.insert(found, {
                prompt = prompt,
                part = part
            })
        end
    end
end

label.Text = "DOORS FOUND: " .. #found
task.wait(1)

for i, data in ipairs(found) do
    local character = me.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")

    if not root then break end

    label.Text = "DOOR " .. i .. " / " .. #found

    root.CFrame = data.part.CFrame * CFrame.new(0, 0, 2)
    task.wait(2)

    holdE()

    task.wait(3)
end

label.Text = "TEST FINISHED"
