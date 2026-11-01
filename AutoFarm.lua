local r = game:GetService("ReplicatedStorage")
local result = {}

for _, v in ipairs(r:GetDescendants()) do
    if (v:IsA("RemoteFunction") or v:IsA("RemoteEvent"))
    and (
        v.Name:lower():find("dungeon")
        or v.Name:lower():find("play")
        or v.Name:lower():find("start")
        or v.Name:lower():find("party")
    ) then
        table.insert(result, v:GetFullName().." ["..v.ClassName.."]")
    end
end

local core = game:GetService("CoreGui")
local old = core:FindFirstChild("RemoteScan")
if old then old:Destroy() end

local s = Instance.new("ScreenGui")
s.Name = "RemoteScan"
s.Parent = core

local f = Instance.new("Frame",s)
f.Size = UDim2.new(.9,0,.75,0)
f.Position = UDim2.new(.05,0,.12,0)
f.BackgroundColor3 = Color3.fromRGB(25,25,35)

local title = Instance.new("TextLabel",f)
title.Size = UDim2.new(1,0,0,35)
title.Text = "REMOTE SCANNER: "..#result
title.TextColor3 = Color3.new(1,1,1)
title.BackgroundTransparency = 1
title.TextSize = 18

local copy = Instance.new("TextButton",f)
copy.Size = UDim2.new(.45,0,0,40)
copy.Position = UDim2.new(.025,0,1,-45)
copy.Text = "COPY ALL"
copy.TextSize = 17
copy.BackgroundColor3 = Color3.fromRGB(30,140,70)
copy.TextColor3 = Color3.new(1,1,1)

local close = Instance.new("TextButton",f)
close.Size = UDim2.new(.45,0,0,40)
close.Position = UDim2.new(.525,0,1,-45)
close.Text = "CLOSE"
close.TextSize = 17
close.MouseButton1Click:Connect(function()
    s:Destroy()
end)

local box = Instance.new("TextBox",f)
box.Position = UDim2.new(.025,0,0,40)
box.Size = UDim2.new(.95,0,1,-95)
box.BackgroundColor3 = Color3.fromRGB(15,15,20)
box.TextColor3 = Color3.new(1,1,1)
box.TextSize = 13
box.TextXAlignment = Enum.TextXAlignment.Left
box.TextYAlignment = Enum.TextYAlignment.Top
box.TextWrapped = false
box.MultiLine = true
box.ClearTextOnFocus = false
box.TextEditable = false
box.Text = table.concat(result,"\n")

copy.MouseButton1Click:Connect(function()
    if setclipboard then
        setclipboard(box.Text)
        copy.Text = "COPIED!"
    else
        copy.Text = "SELECT TEXT"
    end
end)



