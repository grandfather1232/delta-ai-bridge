local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")
local Core = game:GetService("CoreGui")

local player = Players.LocalPlayer

pcall(function()
    local old = Core:FindFirstChild("KeyTest")
    if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "KeyTest"
gui.ResetOnSpawn = false
gui.Parent = Core

local label = Instance.new("TextLabel", gui)
label.Size = UDim2.fromOffset(320, 100)
label.Position = UDim2.new(0.5, -160, 0.3, 0)
label.BackgroundColor3 = Color3.fromRGB(25,25,35)
label.TextColor3 = Color3.new(1,1,1)
label.TextSize = 16
label.TextWrapped = true

local function findKey()
    local map = workspace:FindFirstChild("map")
    local dungeon = map and map:FindFirstChild("halloweendungeon")
    local dungeonMap = dungeon and dungeon:FindFirstChild("map")
    if not dungeonMap then return end

    for _, obj in ipairs(dungeonMap:GetDescendants()) do
        if obj.Name:lower() == "key" then
            local prompt = obj:FindFirstChildWhichIsA(
                "ProximityPrompt", true
            )

            if prompt and prompt.Enabled
            and prompt.KeyboardKeyCode == Enum.KeyCode.E then
                local part = obj:FindFirstChild("Handle", true)
                if part and part:IsA("BasePart") then
                    return obj, prompt, part
                end
            end
        end
    end
end

local key, prompt, part = findKey()

if not key then
    label.Text = "Ключ с кнопкой E не найден"
    return
end

label.Text = "Найден:\n" .. key:GetFullName()

local character = player.Character
local root = character and character:FindFirstChild("HumanoidRootPart")

if not root then
    label.Text = "Персонаж не найден"
    return
end

root.CFrame = CFrame.new(
    part.Position + Vector3.new(0, 3, 0)
)

task.wait(1)

VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
task.wait(0.3)
VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)

task.wait(1)

if not key:IsDescendantOf(workspace) then
    label.Text = "КЛЮЧ ПОДОБРАН!"
else
    label.Text = "Ключ остался.\nПуть: " .. key:GetFullName()
end
