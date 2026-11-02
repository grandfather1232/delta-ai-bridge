local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local player = Players.LocalPlayer

pcall(function()
    CoreGui:FindFirstChild("KeyScanner"):Destroy()
end)

local gui = Instance.new("ScreenGui")
gui.Name = "KeyScanner"
gui.Parent = CoreGui

local label = Instance.new("TextLabel")
label.Parent = gui
label.Size = UDim2.fromOffset(350, 220)
label.Position = UDim2.new(0, 15, 0.3, 0)
label.BackgroundColor3 = Color3.fromRGB(25,25,35)
label.TextColor3 = Color3.new(1,1,1)
label.TextSize = 14
label.TextWrapped = true
label.TextYAlignment = Enum.TextYAlignment.Top

while task.wait(0.5) do
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local results = {}

    if root then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj.Name:lower() == "key" then
                local part

                if obj:IsA("BasePart") then
                    part = obj
                elseif obj:IsA("Model") then
                    part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
                end

                if part then
                    local distance = (root.Position - part.Position).Magnitude
                    table.insert(results, {
                        name = obj:GetFullName(),
                        distance = distance
                    })
                end
            end
        end
    end

    table.sort(results, function(a,b)
        return a.distance < b.distance
    end)

    local output = "ПОИСК КЛЮЧА\n\n"

    for i = 1, math.min(8, #results) do
        output = output .. string.format(
            "%d. %.1f studs\n%s\n\n",
            i, results[i].distance, results[i].name
        )
    end

    if #results == 0 then
        output = output .. "Объекты Key не найдены"
    end

    label.Text = output
end
