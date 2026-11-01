local P=game:GetService("Players")
local R=game:GetService("RunService")
local V=game:GetService("VirtualInputManager")
local me=P.LocalPlayer

local on=false
local target
local secondTool
local switching=false

local Core=game:GetService("CoreGui")
pcall(function()
 local old=Core:FindFirstChild("AutoFarm")
 if old then old:Destroy() end
end)

local g=Instance.new("ScreenGui")
g.Name="AutoFarm"
g.ResetOnSpawn=false
g.Parent=Core

local f=Instance.new("Frame",g)
f.Size=UDim2.fromOffset(155,115)
f.Position=UDim2.new(.5,-77,.5,0)
f.BackgroundColor3=Color3.fromRGB(35,35,45)
f.Active=true
f.Draggable=true

local status=Instance.new("TextLabel",f)
status.Size=UDim2.new(1,0,0,25)
status.Text="AUTO FARM OFF"
status.TextColor3=Color3.new(1,1,1)
status.BackgroundTransparency=1

local function btn(txt,y,color)
 local b=Instance.new("TextButton",f)
 b.Size=UDim2.new(1,-10,0,35)
 b.Position=UDim2.fromOffset(5,y)
 b.Text=txt
 b.TextColor3=Color3.new(1,1,1)
 b.BackgroundColor3=color
 return b
end

local start=btn("START",30,Color3.fromRGB(20,140,60))
local stop=btn("STOP",72,Color3.fromRGB(160,40,40))

local function press(k)
 V:SendKeyEvent(true,k,false,game)
 task.wait(.12)
 V:SendKeyEvent(false,k,false,game)
end

local function nearest(r)
 local best,d
 for _,n in ipairs(workspace:GetDescendants()) do
  if n:IsA("Model") and n~=me.Character
  and not P:GetPlayerFromCharacter(n) then
   local h=n:FindFirstChildOfClass("Humanoid")
   local t=n:FindFirstChild("HumanoidRootPart")
   if h and t and h.Health>0 then
    local x=(r.Position-t.Position).Magnitude
    if not d or x<d then best,d=n,x end
   end
  end
 end
 return best
end

local function attack()
 local c=me.Character
 local tool=c and c:FindFirstChildOfClass("Tool")
 local t=target and target:FindFirstChild("HumanoidRootPart")

 if t then
  local cam=workspace.CurrentCamera
  if cam then
   cam.CFrame=CFrame.lookAt(cam.CFrame.Position,t.Position)
  end
 end

 if tool then
  pcall(function()
   tool:Activate()
  end)
 end
end

local follow

start.MouseButton1Click:Connect(function()
 if on then return end
 on=true
 status.Text="AUTO FARM ON"

 task.spawn(function()
  press(Enum.KeyCode.Two)
  task.wait(.3)
  local c=me.Character
  secondTool=c and c:FindFirstChildOfClass("Tool")
 end)

 follow=R.Heartbeat:Connect(function()
  local c=me.Character
  local r=c and c:FindFirstChild("HumanoidRootPart")
  if not r then return end

  local h=target and target:FindFirstChildOfClass("Humanoid")
  local t=target and target:FindFirstChild("HumanoidRootPart")

  if not h or not t or h.Health<=0 then
   target=nearest(r)
   t=target and target:FindFirstChild("HumanoidRootPart")
  end

  if t then
   r.CFrame=CFrame.lookAt(
    t.Position-Vector3.new(0,8,0),t.Position
   )
   r.AssemblyLinearVelocity=Vector3.zero
  end
 end)

 task.spawn(function()
  while on do
   local c=me.Character
   local equipped=c and c:FindFirstChildOfClass("Tool")

   if secondTool and equipped~=secondTool and not switching then
    switching=true
    press(Enum.KeyCode.Two)
    task.wait(.4)
    switching=false
   end

   task.wait(.5)
  end
 end)

 task.spawn(function()
  while on do
   if target and target.Parent then
    attack()
   end
   task.wait(1)
  end
 end)
end)

stop.MouseButton1Click:Connect(function()
 on=false
 target=nil
 secondTool=nil
 status.Text="AUTO FARM OFF"

 if follow then
  follow:Disconnect()
  follow=nil
 end
end)
