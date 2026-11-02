local Players = game:GetService("Players")
local Core = game:GetService("CoreGui")
local player = Players.LocalPlayer

pcall(function()
    local old = Core:FindFirstChild("PromptScan")
    if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "PromptScan"
gui.ResetOnSpawn = false
gui.Parent = Core

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.fromOffset(360, 390)
frame.Position = UDim2.new(0, 10, 0.2, 0)
frame.BackgroundColor3 = Color3.fromRGB(25,25,35)

local label = Instance.new("TextLabel", frame)
label.Size = UDim2.new(1,-10,1,-45)
label.Position = UDim2.fromOffset(5,5)
label.BackgroundTransparency = 1
label.TextColor3 = Color3.new(1,1,1)
label.TextSize = 12
label.TextWrapped = true
label.TextXAlignment = Enum.TextXAlignment.Left
label.TextYAlignment = Enum.TextYAlignment.Top

local button = Instance.new("TextButton", frame)
button.Size = UDim2.new(1,-10,0,35)
button.Position = UDim2.new(0,5,1,-40)
button.Text = "ОБНОВИТЬ"

local function scan()
    local root = player.Character and
        player.Character:FindFirstChild("HumanoidRootPart")

    local results = {}

    for _, p in ipairs(workspace:GetDescendants()) do
        if p:IsA("ProximityPrompt") then
            local parent = p.Parent
            local part = parent:IsA("BasePart") and parent
                or parent:FindFirstChildWhichIsA("BasePart", true)

            local distance = math.huge
            if root and part then
                distance = (root.Position - part.Position).Magnitude
            end

            if p.Enabled and p.ActionText:lower() == "interact" then
                table.insert(results, {
                    distance = distance,
                    info = string.format(
                        "ПУТЬ: %s\nДИСТАНЦИЯ: %.1f\nКНОПКА: %s\nУДЕРЖАНИЕ: %.2f\nLOS: %s\nРОДИТЕЛЬ: %s",
                        p:GetFullName(),
                        distance,
                        p.KeyboardKeyCode.Name,
                        p.HoldDuration,
                        tostring(p.RequiresLineOfSight),
                        parent:GetFullName()
                    )
                })
            end
        end
    end

    table.sort(results, function(a,b)
        return a.distance < b.distance
    end)

    local output = "НАЙДЕНО: " .. #results .. "\n\n"
    for i = 1, math.min(12,#results) do
        output = output .. results[i].info .. "\n\n---\n\n"
    end

    label.Text = output
end

button.MouseButton1Click:Connect(scan)
scan()





