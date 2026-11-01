local P=game:GetService("Players")
local me=P.LocalPlayer
local R=game:GetService("RunService")
local U=game:GetService("UserInputService")
local on=false
local target

local g=Instance.new("ScreenGui")
g.Name="NPCPanel"
g.ResetOnSpawn=false
g.Parent=game:GetService("CoreGui")

local f=Instance.new("Frame",g)
f.Size=UDim2.fromOffset(145,90)
f.Position=UDim2.new(.5,-72,.5,0)
f.BackgroundColor3=Color3.fromRGB(35,35,45)
f.Active=true
f.Draggable=true

local function button(txt,y,color)
 local b=Instance.new("TextButton",f)
 b.Size=UDim2.new(1,-10,0,32)
 b.Position=UDim2.fromOffset(5,y)
 b.Text=txt
 b.BackgroundColor3=color
 b.TextColor3=Color3.new(1,1,1)
 return b
end

local start=button("START",5,Color3.fromRGB(20,140,60))
local stop=button("STOP",48,Color3.fromRGB(160,40,40))

local conn
start.MouseButton1Click:Connect(function()
 if on then return end
 on=true
 conn=R.Heartbeat:Connect(function()
  local c=me.Character
  local r=c and c:FindFirstChild("HumanoidRootPart")
  if not r then return end
  if not target or not target.Parent then
   local d=math.huge
   for _,n in ipairs(workspace:GetDescendants()) do
    local h=n:IsA("Model") and n:FindFirstChildOfClass("Humanoid")
    local t=n:IsA("Model") and n:FindFirstChild("HumanoidRootPart")
    if h and t and h.Health>0 and not P:GetPlayerFromCharacter(n) then
     local x=(r.Position-t.Position).Magnitude
     if x<d then d=x target=n end
    end
   end
  end
  local t=target and target:FindFirstChild("HumanoidRootPart")
  if t then
   r.CFrame=CFrame.lookAt(t.Position-Vector3.new(0,8,0),t.Position)
   r.AssemblyLinearVelocity=Vector3.zero
  end
 end)
end)

stop.MouseButton1Click:Connect(function()
 on=false
 target=nil
 if conn then conn:Disconnect() conn=nil end
end)





